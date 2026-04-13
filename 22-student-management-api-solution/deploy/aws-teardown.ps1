# Borra la demo Student Management API en AWS (ECS, ECR, RDS, SGs, log group, task definitions).
# Destructivo: RDS sin snapshot final. Requiere AWS CLI v2.
#
# Uso (desde la carpeta 22-student-management-api-solution):
#   .\deploy\aws-teardown.ps1
#   .\deploy\aws-teardown.ps1 -Yes
#   .\deploy\aws-teardown.ps1 -Yes -IamToo
#   .\deploy\aws-teardown.ps1 -Yes -CleanLocal
#
# Variables de entorno (mismas que aws-bootstrap.ps1):
#   AWS_REGION, CLUSTER_NAME, SERVICE_NAME, ECR_REPOSITORY, VPC_ID, RDS_INSTANCE_IDENTIFIER
#
# Task definition family del lab: student-management-api

[CmdletBinding()]
param(
    [switch] $Yes,
    [switch] $IamToo,
    [switch] $CleanLocal,
    [switch] $Help
)

if ($Help) {
    Get-Content $PSCommandPath | Where-Object { $_ -match '^\s*#' -and $_ -notmatch '#!/' } | ForEach-Object { $_ -replace '^\s*#\s?', '' }
    exit 0
}

$ErrorActionPreference = 'Continue'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'Instala AWS CLI v2: https://aws.amazon.com/cli/'
}

$Region = if ($env:AWS_REGION) { $env:AWS_REGION } else { 'us-east-1' }
$ClusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { 'student-management-api' }
$ServiceName = if ($env:SERVICE_NAME) { $env:SERVICE_NAME } else { 'student-management-api-svc' }
$EcrName = if ($env:ECR_REPOSITORY) { $env:ECR_REPOSITORY } else { 'student-management-api' }
$SgName = "student-mgmt-ecs-$ClusterName"
$TaskDefFamily = 'student-management-api'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$env:AWS_DEFAULT_REGION = $Region
$AccountId = aws sts get-caller-identity --query Account --output text
$RdsId = if ($env:RDS_INSTANCE_IDENTIFIER) { $env:RDS_INSTANCE_IDENTIFIER } else { "student-mgmt-pg-$ClusterName" }
$RdsId = $RdsId.ToLowerInvariant()
$DbSubnetGroup = "student-mgmt-db-$ClusterName"
$RdsSgName = "student-mgmt-rds-$ClusterName"

Write-Host "=== Teardown demo | Cuenta $AccountId | Region $Region ==="
Write-Host "Cluster ECS:     $ClusterName"
Write-Host "Servicio ECS:    $ServiceName"
Write-Host "ECR:             $EcrName"
Write-Host "RDS instance:    $RdsId"
Write-Host "Log group:       /ecs/student-management-api"
Write-Host "Task def family: $TaskDefFamily"
Write-Host "Security groups: $SgName, $RdsSgName"
Write-Host ''

if (-not $Yes) {
    Write-Host 'Este script ELIMINA recursos y datos de demo (RDS sin snapshot final).'
    Write-Host 'Para ejecutar:  .\deploy\aws-teardown.ps1 -Yes'
    Write-Host 'Opciones: -IamToo (borra ecsTaskExecutionRole), -CleanLocal (borra *.env en deploy\)'
    exit 1
}

$confirm = Read-Host 'Escribe YES en mayusculas para continuar'
if ($confirm -ne 'YES') {
    Write-Host 'Cancelado.'
    exit 1
}

function Resolve-Vpc {
    param([string] $VpcIdEnv)
    if ($VpcIdEnv) {
        return $VpcIdEnv
    }
    $v = aws ec2 describe-vpcs --filters 'Name=isDefault,Values=true' --query 'Vpcs[0].VpcId' --output text 2>$null
    if (-not $v -or $v -eq 'None') {
        Write-Host 'No hay VPC por defecto; define VPC_ID para localizar security groups.'
        return ''
    }
    return $v
}

function Get-SecurityGroupIdByName {
    param([string] $VpcId, [string] $GroupName)
    if (-not $VpcId) { return '' }
    $id = aws ec2 describe-security-groups `
        --filters "Name=vpc-id,Values=$VpcId" "Name=group-name,Values=$GroupName" `
        --query 'SecurityGroups[0].GroupId' --output text 2>$null
    if (-not $id -or $id -eq 'None') { return '' }
    return $id
}

function Wait-NoEnisForSecurityGroup {
    param([string] $SgId)
    if (-not $SgId -or $SgId -eq 'None') { return }
    for ($i = 1; $i -le 12; $i++) {
        $n = aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SgId" --query 'length(NetworkInterfaces)' --output text 2>$null
        if ($n -eq '0') { return }
        Write-Host "  Esperando ENIs en $SgId ($n)… ($i/12, ~15s)"
        Start-Sleep -Seconds 15
    }
    Write-Host '::warning:: Siguen ENIs en el SG; el borrado puede fallar. Revisa EC2/ECS.'
}

Write-Host '>>> 1/8 ECS: bajar servicio y eliminarlo'
$svcStatus = aws ecs describe-services --cluster $ClusterName --services $ServiceName --query 'services[0].status' --output text 2>$null
if ($svcStatus -match '^(ACTIVE|DRAINING)$') {
    aws ecs update-service --cluster $ClusterName --service $ServiceName --desired-count 0 --region $Region 2>$null | Out-Null
    Write-Host '  delete-service --force…'
    aws ecs delete-service --cluster $ClusterName --service $ServiceName --force --region $Region 2>$null | Out-Null
    Write-Host '  Esperando a que el servicio desaparezca…'
    aws ecs wait services-inactive --cluster $ClusterName --services $ServiceName --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) { Start-Sleep -Seconds 30 }
} else {
    Write-Host '  (servicio no existe o ya borrado)'
}

Write-Host '>>> 2/8 ECS: eliminar cluster'
$cl = aws ecs describe-clusters --clusters $ClusterName --query 'clusters[0].status' --output text 2>$null
if ($cl -eq 'ACTIVE') {
    aws ecs delete-cluster --cluster $ClusterName --region $Region 2>$null | Out-Null
    Write-Host "  Cluster $ClusterName eliminado."
} else {
    Write-Host '  (cluster no existe)'
}

Write-Host ">>> 3/8 ECS: desregistrar revisiones $TaskDefFamily"
$arnLine = aws ecs list-task-definitions --family-prefix $TaskDefFamily --region $Region --query 'taskDefinitionArns[]' --output text 2>$null
if ($arnLine) {
    foreach ($arn in ($arnLine -split "`t")) {
        if (-not $arn -or $arn -eq 'None') { continue }
        Write-Host "  deregister $arn"
        aws ecs deregister-task-definition --task-definition $arn --region $Region 2>$null | Out-Null
    }
}

Write-Host '>>> 4/8 ECR: eliminar repositorio (todas las imagenes)'
$ecrOk = aws ecr describe-repositories --repository-names $EcrName --region $Region 2>$null
if ($LASTEXITCODE -eq 0) {
    aws ecr delete-repository --repository-name $EcrName --force --region $Region 2>$null | Out-Null
    Write-Host "  ECR $EcrName eliminado."
} else {
    Write-Host '  (repositorio ECR no existe)'
}

Write-Host '>>> 5/8 RDS: eliminar instancia (sin snapshot final)'
$rdsExists = aws rds describe-db-instances --db-instance-identifier $RdsId 2>$null
if ($LASTEXITCODE -eq 0) {
    aws rds delete-db-instance `
        --db-instance-identifier $RdsId `
        --skip-final-snapshot `
        --delete-automated-backups 2>$null | Out-Null
    Write-Host "  Esperando a que RDS $RdsId desaparezca (puede tardar varios minutos)…"
    aws rds wait db-instance-deleted --db-instance-identifier $RdsId 2>$null
} else {
    Write-Host '  (instancia RDS no existe)'
}

Write-Host '>>> 6/8 RDS: eliminar DB subnet group'
$subOk = aws rds describe-db-subnet-groups --db-subnet-group-name $DbSubnetGroup 2>$null
if ($LASTEXITCODE -eq 0) {
    aws rds delete-db-subnet-group --db-subnet-group-name $DbSubnetGroup 2>$null | Out-Null
    Write-Host "  $DbSubnetGroup eliminado."
} else {
    Write-Host '  (DB subnet group no existe)'
}

$Vpc = Resolve-Vpc -VpcIdEnv $env:VPC_ID
$EcsSg = Get-SecurityGroupIdByName -VpcId $Vpc -GroupName $SgName
$RdsSg = Get-SecurityGroupIdByName -VpcId $Vpc -GroupName $RdsSgName

Write-Host ">>> 7/8 EC2: security groups (VPC=$Vpc)"
if ($RdsSg) {
    Wait-NoEnisForSecurityGroup -SgId $RdsSg
    aws ec2 delete-security-group --group-id $RdsSg 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "  Eliminado $RdsSg ($RdsSgName)" } else { Write-Host "  No se pudo borrar $RdsSg (dependencias en consola)" }
} else {
    Write-Host '  (SG RDS no encontrado)'
}

if ($EcsSg) {
    Wait-NoEnisForSecurityGroup -SgId $EcsSg
    aws ec2 delete-security-group --group-id $EcsSg 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "  Eliminado $EcsSg ($SgName)" } else { Write-Host "  No se pudo borrar $EcsSg (dependencias en consola)" }
} else {
    Write-Host '  (SG ECS no encontrado)'
}

Write-Host '>>> 8/8 Logs: log group /ecs/student-management-api'
aws logs delete-log-group --log-group-name '/ecs/student-management-api' --region $Region 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Host '  Log group eliminado.' } else { Write-Host '  (log group no existe o sin permiso)' }

if ($IamToo) {
    Write-Host '>>> IAM (-IamToo): rol ecsTaskExecutionRole'
    $role = 'ecsTaskExecutionRole'
    aws iam get-role --role-name $role 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        aws iam detach-role-policy --role-name $role --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>$null | Out-Null
        aws iam delete-role --role-name $role 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "  Rol $role eliminado." } else { Write-Host '  No se pudo borrar el rol (politicas extra?).' }
    } else {
        Write-Host '  (rol no existe)'
    }
} else {
    Write-Host '>>> IAM: no se toca ecsTaskExecutionRole (usa -IamToo si quieres borrarlo).'
}

if ($CleanLocal) {
    Write-Host '>>> Local (-CleanLocal)'
    $p1 = Join-Path $ScriptDir 'rds-credentials.env'
    $p2 = Join-Path $ScriptDir 'github-variables-snippet.env'
    if (Test-Path $p1) { Remove-Item $p1 -Force }
    if (Test-Path $p2) { Remove-Item $p2 -Force }
    Write-Host '  Eliminados rds-credentials.env / github-variables-snippet.env si existian.'
}

Write-Host ''
Write-Host '=== Teardown terminado ==='
Write-Host 'Revisa la consola AWS por si quedan ENIs, snapshots u otros recursos student-mgmt / student-management.'
