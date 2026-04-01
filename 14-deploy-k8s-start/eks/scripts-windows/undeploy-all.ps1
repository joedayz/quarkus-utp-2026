# Script para eliminar los recursos desplegados en EKS
# Uso: .\undeploy-all.ps1 [-DeleteAll]
#   -DeleteAll: También elimina el cluster EKS y los repos ECR

param(
    [switch]$DeleteAll
)

$rootDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$appManifest = Join-Path (Split-Path $PSScriptRoot -Parent) "k8s\expenses-all.yaml"
$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "eks-config.ps1"

# Cargar configuración si existe
if (Test-Path $configFile) {
    . $configFile
}

if (-not $AWS_ACCOUNT_ID -or -not $AWS_REGION) {
    Write-Host "Error: AWS_ACCOUNT_ID o AWS_REGION no están configurados." -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts-windows\eks-setup.ps1"
    exit 1
}

Write-Host "=== Undeploying from EKS ===" -ForegroundColor Cyan

# Reemplazar variables en el manifest
$tempManifest = [System.IO.Path]::GetTempFileName()
(Get-Content $appManifest) `
    -replace '\$\{AWS_ACCOUNT_ID\}', $AWS_ACCOUNT_ID `
    -replace '\$\{AWS_REGION\}', $AWS_REGION | Set-Content $tempManifest

# Eliminar recursos de Kubernetes
kubectl delete -f $tempManifest --ignore-not-found=true
Remove-Item $tempManifest

Write-Host ""
Write-Host "Recursos de Kubernetes eliminados." -ForegroundColor Green

# Eliminar recursos de AWS si se solicita
if ($DeleteAll) {
    Write-Host ""
    Write-Host "=== Eliminando recursos de AWS ===" -ForegroundColor Cyan

    $clusterName = if ($CLUSTER_NAME) { $CLUSTER_NAME } else { "expense-eks" }

    # Verificar que AWS CLI está instalado
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Host "Error: AWS CLI no está instalado." -ForegroundColor Red
        exit 1
    }

    $callerIdentity = aws sts get-caller-identity 2>$null
    if (-not $callerIdentity) {
        Write-Host "Error: No estás autenticado en AWS." -ForegroundColor Red
        Write-Host "Ejecuta: aws configure"
        exit 1
    }

    # Eliminar cluster EKS
    if (Get-Command eksctl -ErrorAction SilentlyContinue) {
        $eksExists = eksctl get cluster --name $clusterName --region $AWS_REGION 2>$null
        if ($eksExists) {
            Write-Host "Eliminando cluster EKS '$clusterName'..." -ForegroundColor Yellow
            Write-Host "Esto puede tardar varios minutos..."
            eksctl delete cluster --name $clusterName --region $AWS_REGION --wait
            Write-Host "Cluster EKS '$clusterName' eliminado." -ForegroundColor Green
        } else {
            Write-Host "Cluster EKS '$clusterName' no existe o ya fue eliminado." -ForegroundColor Yellow
        }
    } else {
        Write-Host "eksctl no está instalado. Elimina el cluster manualmente:" -ForegroundColor Yellow
        Write-Host "  eksctl delete cluster --name $clusterName --region $AWS_REGION"
    }

    # Eliminar repositorios ECR
    foreach ($repo in @("expense-service", "expense-client")) {
        $repoExists = aws ecr describe-repositories --repository-names $repo --region $AWS_REGION 2>$null
        if ($repoExists) {
            Write-Host "Eliminando repositorio ECR '$repo'..." -ForegroundColor Yellow
            aws ecr delete-repository --repository-name $repo --region $AWS_REGION --force
            Write-Host "Repositorio ECR '$repo' eliminado." -ForegroundColor Green
        } else {
            Write-Host "Repositorio ECR '$repo' no existe o ya fue eliminado." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Recursos de AWS eliminados." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Nota: Los recursos de AWS (EKS, ECR) NO se eliminaron." -ForegroundColor Yellow
    Write-Host "Para eliminarlos también, ejecuta:"
    Write-Host "  .\scripts-windows\undeploy-all.ps1 -DeleteAll"
}
