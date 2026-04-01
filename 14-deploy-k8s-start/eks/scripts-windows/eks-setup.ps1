# Script para configurar AWS: crear repositorios ECR y cluster EKS
# Uso: .\eks-setup.ps1 [ClusterName] [AwsRegion]

param(
    [string]$ClusterName = "expense-eks",
    [string]$AwsRegion = "us-east-1"
)

Write-Host "=== AWS EKS Setup ===" -ForegroundColor Cyan
Write-Host "Cluster: $ClusterName"
Write-Host "Region:  $AwsRegion"
Write-Host ""

# Verificar que AWS CLI está instalado
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "Error: AWS CLI no está instalado." -ForegroundColor Red
    Write-Host "Instala desde: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
}

# Verificar que eksctl está instalado
if (-not (Get-Command eksctl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: eksctl no está instalado." -ForegroundColor Red
    Write-Host "Instala desde: https://eksctl.io/installation/"
    exit 1
}

# Verificar que kubectl está instalado
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl no está instalado." -ForegroundColor Red
    Write-Host "Instala desde: https://kubernetes.io/docs/tasks/tools/"
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

# Crear cluster EKS si no existe
Write-Host "=== Creando cluster EKS ===" -ForegroundColor Cyan
$eksExists = eksctl get cluster --name $ClusterName --region $AwsRegion 2>$null
if ($eksExists) {
    Write-Host "Cluster EKS '$ClusterName' ya existe."
} else {
    Write-Host "Creando cluster EKS '$ClusterName'..."
    Write-Host "Esto puede tardar 15-20 minutos..."
    eksctl create cluster `
        --name $ClusterName `
        --region $AwsRegion `
        --nodegroup-name expense-nodes `
        --node-type t3.medium `
        --nodes 2 `
        --nodes-min 1 `
        --nodes-max 3 `
        --managed
}
Write-Host ""

# Actualizar kubeconfig
Write-Host "=== Configurando kubectl ===" -ForegroundColor Cyan
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion
Write-Host ""

# Verificar conexión
Write-Host "=== Verificando conexión con EKS ===" -ForegroundColor Cyan
kubectl cluster-info
kubectl get nodes
Write-Host ""

# Guardar configuración
$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "eks-config.ps1"
@"
`$CLUSTER_NAME = "$ClusterName"
`$AWS_REGION = "$AwsRegion"
`$AWS_ACCOUNT_ID = "$AwsAccountId"
`$ECR_REGISTRY = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
"@ | Out-File -FilePath $configFile -Encoding utf8

Write-Host "=== Configuración completada ===" -ForegroundColor Green
Write-Host "Configuración guardada en: $configFile"
Write-Host ""
Write-Host "Variables de entorno:"
Write-Host "  CLUSTER_NAME=$ClusterName"
Write-Host "  AWS_REGION=$AwsRegion"
Write-Host "  AWS_ACCOUNT_ID=$AwsAccountId"
Write-Host "  ECR_REGISTRY=$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"
Write-Host ""
Write-Host "Para usar estas variables en otros scripts, ejecuta:"
Write-Host "  . $configFile"
