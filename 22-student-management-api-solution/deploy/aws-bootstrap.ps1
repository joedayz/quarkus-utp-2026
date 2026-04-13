# Aprovisiona infra minima en AWS para la demo Student Management API + ECS Fargate.
# Requisitos: AWS CLI v2 instalado y perfil/credenciales configurados (aws configure).
#
# Uso (desde la carpeta 22-student-management-api-solution):
#   .\deploy\aws-bootstrap.ps1
#   .\deploy\aws-bootstrap.ps1 -InfraOnly
#   .\deploy\aws-bootstrap.ps1 -InfraOnly -WithRds
#   .\deploy\aws-bootstrap.ps1 -DeployService
#
# Variables de entorno opcionales: AWS_REGION, CLUSTER_NAME, SERVICE_NAME, ECR_REPOSITORY, VPC_ID,
#   RDS_INSTANCE_IDENTIFIER, RDS_INSTANCE_CLASS, RDS_MASTER_USERNAME

[CmdletBinding()]
param(
    [switch] $InfraOnly,
    [switch] $DeployService,
    [switch] $WithRds,
    [switch] $Help
)

if ($Help) {
    Get-Content $PSCommandPath | Where-Object { $_ -match '^\s*#' -and $_ -notmatch '#!/' } | ForEach-Object { $_ -replace '^\s*#\s?', '' }
    exit 0
}

$ErrorActionPreference = 'Stop'

$Region = if ($env:AWS_REGION) { $env:AWS_REGION } else { 'us-east-1' }
$ClusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { 'student-management-api' }
$ServiceName = if ($env:SERVICE_NAME) { $env:SERVICE_NAME } else { 'student-management-api-svc' }
$EcrName = if ($env:ECR_REPOSITORY) { $env:ECR_REPOSITORY } else { 'student-management-api' }
$SgName = "student-mgmt-ecs-$ClusterName"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$TaskDefTemplate = Join-Path $ScriptDir 'ecs-task-definition.json'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'Instala AWS CLI v2: https://aws.amazon.com/cli/'
}

$env:AWS_DEFAULT_REGION = $Region
$AccountId = aws sts get-caller-identity --query Account --output text
$EcrUri = "$AccountId.dkr.ecr.$Region.amazonaws.com/$EcrName"

Write-Host "=== Cuenta $AccountId | Region $Region ==="

function Ensure-ExecutionRole {
    $roleName = 'ecsTaskExecutionRole'
    aws iam get-role --role-name $roleName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Rol IAM ya existe: $roleName"
        return
    }
    $trust = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    Write-Host "Creando rol IAM $roleName..."
    aws iam create-role --role-name $roleName --assume-role-policy-document $trust | Out-Null
    aws iam attach-role-policy --role-name $roleName --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
    Write-Host 'Esperando propagacion IAM (~10s)...'
    Start-Sleep -Seconds 10
}

function Ensure-Ecr {
    aws ecr describe-repositories --repository-names $EcrName --region $Region 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repositorio ECR ya existe: $EcrName"
        return
    }
    Write-Host "Creando repositorio ECR: $EcrName"
    aws ecr create-repository --repository-name $EcrName --region $Region | Out-Null
}

function Ensure-LogGroup {
    Write-Host 'Asegurando log group: /ecs/student-management-api'
    aws logs create-log-group --log-group-name '/ecs/student-management-api' --region $Region 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '(log group ya existia o aviso ignorado)'
    }
}

function Ensure-Cluster {
    $status = aws ecs describe-clusters --clusters $ClusterName --region $Region --query 'clusters[0].status' --output text 2>$null
    if ($status -eq 'ACTIVE') {
        Write-Host "Cluster ECS ya existe: $ClusterName"
    } else {
        Write-Host "Creando cluster ECS: $ClusterName"
        aws ecs create-cluster --cluster-name $ClusterName --region $Region | Out-Null
    }
}

function Resolve-VpcAndSubnets {
    param([string]$VpcIdEnv)
    if ($VpcIdEnv) {
        $script:Vpc = $VpcIdEnv
    } else {
        $script:Vpc = aws ec2 describe-vpcs --filters '[{"Name":"isDefault","Values":["true"]}]' --query 'Vpcs[0].VpcId' --output text
        if (-not $script:Vpc -or $script:Vpc -eq 'None') {
            Write-Error 'No hay VPC por defecto. Define la variable de entorno VPC_ID.'
        }
    }
    Write-Host "VPC: $script:Vpc"
    $subnetFilter = '[{"Name":"vpc-id","Values":["' + $script:Vpc + '"]}]'
    $script:Subnet1 = $null
    $script:Subnet2 = $null
    if ($WithRds) {
        $raw = aws ec2 describe-subnets --filters $subnetFilter --query 'Subnets[].[SubnetId,AvailabilityZone]' --output text
        $lines = @($raw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        $az1 = $null
        foreach ($line in $lines) {
            $tok = $line -split '\s+', 2
            if ($tok.Count -lt 2) { continue }
            $sid, $az = $tok[0], $tok[1]
            if (-not $script:Subnet1) {
                $script:Subnet1 = $sid
                $az1 = $az
                continue
            }
            if ($az -ne $az1) {
                $script:Subnet2 = $sid
                break
            }
        }
        if (-not $script:Subnet1 -or -not $script:Subnet2) {
            Write-Error 'Con -WithRds se necesitan al menos 2 subnets en distintas zonas de disponibilidad.'
        }
        Write-Host "Subnets (2 AZ): $script:Subnet1 $script:Subnet2"
        return
    }
    $list = aws ec2 describe-subnets --filters $subnetFilter --query 'Subnets[*].SubnetId' --output text
    $parts = @($list -split '\s+' | Where-Object { $_ })
    if ($parts.Count -lt 2) {
        Write-Error 'Se necesitan al menos 2 subnets en la VPC.'
    }
    $script:Subnet1 = $parts[0]
    $script:Subnet2 = $parts[1]
    Write-Host "Subnets: $script:Subnet1 $script:Subnet2"
}

function Ensure-SecurityGroup {
    $sgFilter = '[{"Name":"vpc-id","Values":["' + $script:Vpc + '"]},{"Name":"group-name","Values":["' + $SgName + '"]}]'
    $existing = aws ec2 describe-security-groups --filters $sgFilter --query 'SecurityGroups[0].GroupId' --output text 2>$null
    if ($existing -and $existing -ne 'None') {
        $script:SgId = $existing
        Write-Host "Security group ya existe: $script:SgId ($SgName)"
    } else {
        Write-Host "Creando security group: $SgName"
        $script:SgId = aws ec2 create-security-group --group-name $SgName --description 'ECS Fargate student-mgmt demo' --vpc-id $script:Vpc --query GroupId --output text
        aws ec2 authorize-security-group-ingress --group-id $script:SgId --protocol tcp --port 8080 --cidr 0.0.0.0/0 | Out-Null
        Write-Host 'Ingress 8080 desde 0.0.0.0/0 (solo demo).'
    }
    Write-Host "Security group tareas ECS: $script:SgId"
}

function New-RdsMasterPassword {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    -join ((1..24) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function Write-RdsCredentialsFile {
    param([string] $DbUser)
    $out = Join-Path $ScriptDir 'rds-credentials.env'
    $url = "jdbc:postgresql://$($script:RdsEndpoint):5432/studentdb"
    $lines = @(
        '# NO subir a Git (.gitignore). GitHub: Variable QUARKUS_DATASOURCE_JDBC_URL y Secret STUDENT_DB_PASSWORD',
        "QUARKUS_DATASOURCE_JDBC_URL=$url",
        "QUARKUS_DATASOURCE_USERNAME=$DbUser"
    )
    if ($script:MasterPassword) {
        $lines += "STUDENT_DB_PASSWORD=$($script:MasterPassword)"
    } else {
        $lines += '# STUDENT_DB_PASSWORD=  (instancia ya existia; usa tu password o Modify en RDS)'
    }
    Set-Content -Path $out -Value $lines -Encoding utf8
    Write-Host "JDBC local guardado en: $out"
}

function Ensure-RdsStack {
    $dbSubnetName = "student-mgmt-db-$ClusterName"
    $rdsSgName = "student-mgmt-rds-$ClusterName"
    $id = if ($env:RDS_INSTANCE_IDENTIFIER) { $env:RDS_INSTANCE_IDENTIFIER } else { "student-mgmt-pg-$ClusterName" }
    $id = $id.ToLowerInvariant()
    $rdsClass = if ($env:RDS_INSTANCE_CLASS) { $env:RDS_INSTANCE_CLASS } else { 'db.t4g.micro' }
    $dbUser = if ($env:RDS_MASTER_USERNAME) { $env:RDS_MASTER_USERNAME } else { 'student' }

    aws rds describe-db-subnet-groups --db-subnet-group-name $dbSubnetName 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "DB subnet group ya existe: $dbSubnetName"
    } else {
        Write-Host "Creando DB subnet group $dbSubnetName..."
        aws rds create-db-subnet-group --db-subnet-group-name $dbSubnetName `
            --db-subnet-group-description 'student-management-api demo' `
            --subnet-ids $script:Subnet1 $script:Subnet2 | Out-Null
    }

    $rdsSgFilter = '[{"Name":"vpc-id","Values":["' + $script:Vpc + '"]},{"Name":"group-name","Values":["' + $rdsSgName + '"]}]'
    $rdsSgExisting = aws ec2 describe-security-groups --filters $rdsSgFilter --query 'SecurityGroups[0].GroupId' --output text 2>$null
    if ($rdsSgExisting -and $rdsSgExisting -ne 'None') {
        $script:RdsSgId = $rdsSgExisting
        Write-Host "Security group RDS ya existe: $script:RdsSgId ($rdsSgName)"
    } else {
        Write-Host "Creando security group RDS: $rdsSgName"
        $script:RdsSgId = aws ec2 create-security-group --group-name $rdsSgName --description 'PostgreSQL student-mgmt demo' `
            --vpc-id $script:Vpc --query GroupId --output text
        Write-Host "RDS: entrada 5432 desde security group de tareas ECS ($($script:SgId))."
    }
    aws ec2 authorize-security-group-ingress --group-id $script:RdsSgId --protocol tcp --port 5432 --source-group $script:SgId 2>$null | Out-Null

    $status = aws rds describe-db-instances --db-instance-identifier $id --query 'DBInstances[0].DBInstanceStatus' --output text 2>$null
    if ($status -and $status -ne 'None') {
        Write-Host "Instancia RDS ya existe: $id (estado: $status)"
        if ($status -ne 'available') {
            Write-Host 'Esperando a que RDS este disponible...'
            aws rds wait db-instance-available --db-instance-identifier $id
        }
        $script:RdsEndpoint = aws rds describe-db-instances --db-instance-identifier $id --query 'DBInstances[0].Endpoint.Address' --output text
        $script:MasterPassword = $null
        Write-RdsCredentialsFile -DbUser $dbUser
        Write-Host "RDS endpoint: $($script:RdsEndpoint)"
        return
    }

    $script:MasterPassword = New-RdsMasterPassword
    Write-Host "Creando instancia RDS PostgreSQL $id (clase $rdsClass; genera coste)..."
    aws rds create-db-instance `
        --db-instance-identifier $id `
        --db-instance-class $rdsClass `
        --engine postgres `
        --master-username $dbUser `
        --master-user-password $script:MasterPassword `
        --allocated-storage 20 `
        --db-name studentdb `
        --vpc-security-group-ids $script:RdsSgId `
        --db-subnet-group-name $dbSubnetName `
        --backup-retention-period 1 `
        --no-publicly-accessible `
        --no-multi-az `
        --storage-type gp3 | Out-Null

    Write-Host 'Esperando a que RDS este disponible (10-20 min)...'
    aws rds wait db-instance-available --db-instance-identifier $id
    $script:RdsEndpoint = aws rds describe-db-instances --db-instance-identifier $id --query 'DBInstances[0].Endpoint.Address' --output text
    Write-RdsCredentialsFile -DbUser $dbUser
    Write-Host "RDS listo. Endpoint: $($script:RdsEndpoint)"
}

function Write-GitHubSnippet {
    $out = Join-Path $ScriptDir 'github-variables-snippet.env'
    $base = @"
# Copiar como Variables en GitHub -> Settings -> Secrets and variables -> Actions -> Variables
ECS_CLUSTER=$ClusterName
ECS_SERVICE=$ServiceName
AWS_REGION=$Region
ECR_REPOSITORY=$EcrName
"@
    if ($WithRds -and (Test-Path (Join-Path $ScriptDir 'rds-credentials.env'))) {
        $base += @"

# Tras -WithRds: copia QUARKUS_DATASOURCE_JDBC_URL y QUARKUS_DATASOURCE_USERNAME desde deploy/rds-credentials.env -> Variables.
# STUDENT_DB_PASSWORD -> Secret (mismo valor que en rds-credentials.env si acabas de crear la instancia).
"@
    }
    Set-Content -Path $out -Value $base -Encoding utf8
    Write-Host "Variables sugeridas guardadas en: $out"
}

function Test-EcrImageExists {
    aws ecr describe-images --repository-name $EcrName --region $Region --image-ids imageTag=latest 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Register-TaskAndCreateService {
    if (-not (Test-Path $TaskDefTemplate)) {
        Write-Error "No se encuentra $TaskDefTemplate"
    }
    $json = Get-Content -Path $TaskDefTemplate -Raw -Encoding UTF8
    $json = $json.Replace('__AWS_ACCOUNT_ID__', $AccountId).Replace('__AWS_REGION__', $Region)
    $json = $json.Replace('"image": "public.ecr.aws/docker/library/busybox:1.36"', "`"image`": `"${EcrUri}:latest`"")
    $tmp = [System.IO.Path]::GetTempFileName()
    Set-Content -Path $tmp -Value $json -Encoding UTF8 -NoNewline
    $merger = Join-Path $ScriptDir 'merge_rds_into_taskdef.py'
    $creds = Join-Path $ScriptDir 'rds-credentials.env'
    if ((Test-Path $creds) -and (Get-Command python3 -ErrorAction SilentlyContinue)) {
        python3 $merger $tmp $creds
    } elseif (Test-Path $creds) {
        Write-Host '(python3 no encontrado; no se fusionan variables RDS en la task definition.)'
    }
    $tmpUri = "file://" + ($tmp -replace '\\', '/')

    Write-Host 'Registrando task definition family student-management-api...'
    $revArn = aws ecs register-task-definition --cli-input-json $tmpUri --query 'taskDefinition.taskDefinitionArn' --output text
    Remove-Item $tmp -Force
    Write-Host "Revision registrada: $revArn"

    $svcStatus = aws ecs describe-services --cluster $ClusterName --services $ServiceName --region $Region --query 'services[0].status' --output text 2>$null
    if ($svcStatus -eq 'ACTIVE') {
        Write-Host "El servicio $ServiceName ya existe. GitHub Actions lo actualizara en siguientes corridas."
        return
    }

    Write-Host "Creando servicio ECS $ServiceName (desired-count=1, Fargate, IP publica)..."
    $net = "awsvpcConfiguration={subnets=[$($script:Subnet1),$($script:Subnet2)],securityGroups=[$($script:SgId)],assignPublicIp=ENABLED}"
    aws ecs create-service `
        --cluster $ClusterName `
        --service-name $ServiceName `
        --task-definition student-management-api `
        --desired-count 1 `
        --launch-type FARGATE `
        --platform-version LATEST `
        --network-configuration $net `
        --region $Region | Out-Null

    Write-Host 'Servicio creado. IP publica: consola ECS o aws ecs describe-tasks...'
}

# --- main ---

if ($DeployService) {
    if ($WithRds) {
        Write-Error 'Usa -WithRds con -InfraOnly o sin -DeployService, no junto con -DeployService.'
    }
    Resolve-VpcAndSubnets -VpcIdEnv $env:VPC_ID
    Ensure-SecurityGroup
    if (-not (Test-EcrImageExists)) {
        Write-Error 'No hay imagen :latest en ECR. Ejecuta primero GitHub Actions con Solo ECR.'
    }
    Register-TaskAndCreateService
    exit 0
}

Ensure-ExecutionRole
Ensure-Ecr
Ensure-LogGroup
Ensure-Cluster
Resolve-VpcAndSubnets -VpcIdEnv $env:VPC_ID
Ensure-SecurityGroup
if ($WithRds) {
    Write-Host ''
    Write-Host '>>> -WithRds: RDS PostgreSQL (coste y espera). Requiere permisos rds:* y ec2:*.'
    Write-Host ''
    Ensure-RdsStack
}
Write-GitHubSnippet

Write-Host ''
if ($WithRds) {
    Write-Host '>>> JDBC en deploy/rds-credentials.env. GitHub: Variables QUARKUS_DATASOURCE_JDBC_URL + QUARKUS_DATASOURCE_USERNAME'
    Write-Host '    y Secret STUDENT_DB_PASSWORD (ver github-variables-snippet.env).'
} else {
    Write-Host '>>> Anade QUARKUS_DATASOURCE_* en deploy/ecs-task-definition.json o usa -WithRds + variables en GitHub.'
    Write-Host '    Security group tareas ECS:' $script:SgId
}
Write-Host '    Sin JDBC valido el health check fallara.'
Write-Host ''

if ($InfraOnly) {
    Write-Host 'Modo -InfraOnly: no se crea el servicio ECS.'
    if (-not $WithRds) {
        Write-Host 'Pasos: 1) JDBC en JSON + SG RDS  2) GitHub Secrets/Variables (github-variables-snippet.env)'
    } else {
        Write-Host 'Pasos: 1) Copia JDBC de rds-credentials.env a GitHub Variables + Secret'
    }
    Write-Host '       2) GitHub AWS keys + Variables  3) Workflow Solo ECR  4) .\deploy\aws-bootstrap.ps1 -DeployService'
    exit 0
}

if (Test-EcrImageExists) {
    Register-TaskAndCreateService
} else {
    Write-Host 'No hay imagen :latest en ECR todavia.'
    Write-Host 'Pasos: 1) GitHub Secrets + Variables (y JDBC: JSON o Variables/Secret si usaste -WithRds)'
    Write-Host '       2) Workflow Solo ECR  3) .\deploy\aws-bootstrap.ps1 -DeployService'
}
