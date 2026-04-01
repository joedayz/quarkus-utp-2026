# Script para configurar AWS: crear repositorios ECR, cluster ECS, VPC, y roles IAM
# Uso: .\ecs-setup.ps1 [ClusterName] [AwsRegion]

param(
    [string]$ClusterName = "expense-ecs",
    [string]$AwsRegion = "us-east-1"
)

Write-Host "=== AWS ECS Setup ===" -ForegroundColor Cyan
Write-Host "Cluster: $ClusterName"
Write-Host "Region:  $AwsRegion"
Write-Host ""

# Verificar que AWS CLI está instalado
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Error: AWS CLI no está instalado." -ForegroundColor Red
    Write-Host "Instala desde: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
}

# Verificar credenciales de AWS
Write-Host "=== Verificando credenciales de AWS ===" -ForegroundColor Cyan
$callerIdentity = aws sts get-caller-identity 2>$null
if (-not $callerIdentity) {
    Write-Host "Error: No estás autenticado en AWS." -ForegroundColor Red
    Write-Host "Ejecuta: aws configure"
    exit 1
}

$AwsAccountId = aws sts get-caller-identity --query Account --output text
Write-Host "Account ID: $AwsAccountId"
Write-Host "Region:     $AwsRegion"
Write-Host ""

# Crear repositorios ECR si no existen
Write-Host "=== Creando repositorios ECR ===" -ForegroundColor Cyan
foreach ($repo in @("expense-service", "expense-client")) {
    $repoExists = aws ecr describe-repositories --repository-names $repo --region $AwsRegion 2>$null
    if ($repoExists) {
        Write-Host "Repositorio ECR '$repo' ya existe."
    } else {
        Write-Host "Creando repositorio ECR '$repo'..."
        aws ecr create-repository `
            --repository-name $repo `
            --region $AwsRegion `
            --image-scanning-configuration scanOnPush=true `
            --encryption-configuration encryptionType=AES256
    }
}
Write-Host ""

# Crear rol de ejecución de ECS si no existe
Write-Host "=== Creando rol IAM para ECS ===" -ForegroundColor Cyan
$ecsExecutionRole = "ecsTaskExecutionRole"
$roleExists = aws iam get-role --role-name $ecsExecutionRole 2>$null
if ($roleExists) {
    Write-Host "Rol '$ecsExecutionRole' ya existe."
} else {
    Write-Host "Creando rol '$ecsExecutionRole'..."
    $trustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@
    $trustPolicyFile = [System.IO.Path]::GetTempFileName()
    $trustPolicy | Out-File -FilePath $trustPolicyFile -Encoding utf8
    aws iam create-role `
        --role-name $ecsExecutionRole `
        --assume-role-policy-document "file://$trustPolicyFile"
    Remove-Item $trustPolicyFile
    aws iam attach-role-policy `
        --role-name $ecsExecutionRole `
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
}
$executionRoleArn = aws iam get-role --role-name $ecsExecutionRole --query 'Role.Arn' --output text
Write-Host "Execution Role ARN: $executionRoleArn"
Write-Host ""

# Obtener VPC default y subnets
Write-Host "=== Obteniendo VPC y Subnets ===" -ForegroundColor Cyan
$defaultVpcId = aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region $AwsRegion --query 'Vpcs[0].VpcId' --output text
if (-not $defaultVpcId -or $defaultVpcId -eq "None") {
    Write-Host "Error: No se encontró una VPC default en la región $AwsRegion." -ForegroundColor Red
    Write-Host "Crea una VPC o especifica una existente."
    exit 1
}
Write-Host "VPC: $defaultVpcId"

$subnetIds = aws ec2 describe-subnets `
    --filters "Name=vpc-id,Values=$defaultVpcId" `
    --region $AwsRegion `
    --query 'Subnets[*].SubnetId' --output text
$subnetIdsCsv = $subnetIds -replace "`t", ","
Write-Host "Subnets: $subnetIdsCsv"
Write-Host ""

# Crear Security Group para ECS
Write-Host "=== Creando Security Group ===" -ForegroundColor Cyan
$sgName = "expense-ecs-sg"
$existingSg = aws ec2 describe-security-groups `
    --filters "Name=group-name,Values=$sgName" "Name=vpc-id,Values=$defaultVpcId" `
    --region $AwsRegion `
    --query 'SecurityGroups[0].GroupId' --output text 2>$null

if ($existingSg -and $existingSg -ne "None") {
    $sgId = $existingSg
    Write-Host "Security Group '$sgName' ya existe: $sgId"
} else {
    Write-Host "Creando Security Group '$sgName'..."
    $sgId = aws ec2 create-security-group `
        --group-name $sgName `
        --description "Security group for ECS expense services" `
        --vpc-id $defaultVpcId `
        --region $AwsRegion `
        --query 'GroupId' --output text

    # Permitir tráfico HTTP en puerto 8080
    aws ec2 authorize-security-group-ingress `
        --group-id $sgId `
        --protocol tcp --port 8080 --cidr 0.0.0.0/0 `
        --region $AwsRegion

    # Permitir tráfico interno entre tareas del SG
    aws ec2 authorize-security-group-ingress `
        --group-id $sgId `
        --protocol tcp --port 0-65535 --source-group $sgId `
        --region $AwsRegion
}
Write-Host "Security Group: $sgId"
Write-Host ""

# Crear cluster ECS si no existe
Write-Host "=== Creando cluster ECS ===" -ForegroundColor Cyan
$activeCluster = aws ecs describe-clusters --clusters $ClusterName --region $AwsRegion `
    --query "clusters[?status=='ACTIVE'].clusterName" --output text 2>$null

if ($activeCluster -and $activeCluster -ne "None") {
    Write-Host "Cluster ECS '$ClusterName' ya existe."
} else {
    Write-Host "Creando cluster ECS '$ClusterName'..."
    aws ecs create-cluster `
        --cluster-name $ClusterName `
        --region $AwsRegion `
        --capacity-providers FARGATE `
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
}
Write-Host ""

# Crear namespace de Cloud Map para service discovery
Write-Host "=== Configurando Service Discovery (Cloud Map) ===" -ForegroundColor Cyan
$namespaceName = "expense.local"
$existingNs = aws servicediscovery list-namespaces `
    --filters "Name=TYPE,Values=DNS_PRIVATE" `
    --region $AwsRegion `
    --query "Namespaces[?Name=='$namespaceName'].Id" --output text 2>$null

if ($existingNs -and $existingNs -ne "None") {
    $namespaceId = $existingNs
    Write-Host "Namespace '$namespaceName' ya existe: $namespaceId"
} else {
    Write-Host "Creando namespace '$namespaceName'..."
    $operationId = aws servicediscovery create-private-dns-namespace `
        --name $namespaceName `
        --vpc $defaultVpcId `
        --region $AwsRegion `
        --query 'OperationId' --output text

    Write-Host "Esperando a que el namespace se cree..."
    for ($i = 1; $i -le 30; $i++) {
        $nsStatus = aws servicediscovery get-operation `
            --operation-id $operationId `
            --region $AwsRegion `
            --query 'Operation.Status' --output text 2>$null
        if ($nsStatus -eq "SUCCESS") {
            break
        }
        Start-Sleep -Seconds 2
    }

    $namespaceId = aws servicediscovery get-operation `
        --operation-id $operationId `
        --region $AwsRegion `
        --query 'Operation.Targets.NAMESPACE' --output text
}
Write-Host "Namespace ID: $namespaceId"
Write-Host ""

# Crear CloudWatch Log Group
Write-Host "=== Creando Log Group ===" -ForegroundColor Cyan
$logGroup = "/ecs/$ClusterName"
aws logs create-log-group --log-group-name $logGroup --region $AwsRegion 2>$null
Write-Host "Log Group: $logGroup"
Write-Host ""

# Guardar configuración
$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "ecs-config.ps1"
@"
`$CLUSTER_NAME = "$ClusterName"
`$AWS_REGION = "$AwsRegion"
`$AWS_ACCOUNT_ID = "$AwsAccountId"
`$ECR_REGISTRY = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
`$EXECUTION_ROLE_ARN = "$executionRoleArn"
`$DEFAULT_VPC_ID = "$defaultVpcId"
`$SUBNET_IDS = "$subnetIdsCsv"
`$SG_ID = "$sgId"
`$NAMESPACE_ID = "$namespaceId"
`$LOG_GROUP = "$logGroup"
"@ | Out-File -FilePath $configFile -Encoding utf8

Write-Host "=== Configuración completada ===" -ForegroundColor Green
Write-Host "Configuración guardada en: $configFile"
Write-Host ""
Write-Host "Variables de entorno:"
Write-Host "  CLUSTER_NAME=$ClusterName"
Write-Host "  AWS_REGION=$AwsRegion"
Write-Host "  AWS_ACCOUNT_ID=$AwsAccountId"
Write-Host "  ECR_REGISTRY=$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
Write-Host "  EXECUTION_ROLE_ARN=$executionRoleArn"
Write-Host "  VPC=$defaultVpcId"
Write-Host "  SUBNETS=$subnetIdsCsv"
Write-Host "  SG=$sgId"
Write-Host "  NAMESPACE_ID=$namespaceId"
Write-Host ""
Write-Host "Para usar estas variables en otros scripts, ejecuta:"
Write-Host "  . $configFile"
