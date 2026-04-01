# Script para mostrar información del cluster EKS

$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "eks-config.ps1"

# Cargar configuración si existe
if (Test-Path $configFile) {
    . $configFile
}

Write-Host "=== Información del cluster EKS ===" -ForegroundColor Cyan
Write-Host ""

if ($CLUSTER_NAME) {
    Write-Host "Cluster: $CLUSTER_NAME"
    Write-Host "Region:  $AWS_REGION"
    Write-Host "Account: $AWS_ACCOUNT_ID"
    Write-Host ""
}

Write-Host "Cluster Info:" -ForegroundColor Yellow
kubectl cluster-info
Write-Host ""

Write-Host "Nodos:" -ForegroundColor Yellow
kubectl get nodes -o wide
Write-Host ""

Write-Host "Pods:" -ForegroundColor Yellow
kubectl get pods -o wide
Write-Host ""

Write-Host "Servicios:" -ForegroundColor Yellow
kubectl get svc
Write-Host ""

Write-Host "Repositorios ECR:" -ForegroundColor Yellow
if ($AWS_REGION) {
    aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output table 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "No se pudieron listar los repositorios ECR" -ForegroundColor Red
    }
} else {
    Write-Host "AWS_REGION no configurado" -ForegroundColor Red
}
