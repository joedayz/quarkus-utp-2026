# Script para desplegar en EKS
# Requiere: eks-setup.ps1 y build-and-push-all.ps1 ejecutados previamente

$rootDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "eks-config.ps1"
$appManifest = Join-Path (Split-Path $PSScriptRoot -Parent) "k8s\expenses-all.yaml"

# Cargar configuración si existe
if (Test-Path $configFile) {
    Write-Host "Cargando configuración desde $configFile..." -ForegroundColor Cyan
    . $configFile
}

# Verificar variables requeridas
if (-not $AWS_ACCOUNT_ID -or -not $AWS_REGION) {
    Write-Host "Error: AWS_ACCOUNT_ID o AWS_REGION no están configurados." -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts-windows\eks-setup.ps1"
    exit 1
}

# Verificar conexión con EKS
$clusterInfo = kubectl cluster-info 2>$null
if (-not $clusterInfo) {
    Write-Host "Error: No hay conexión con el cluster de Kubernetes." -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts-windows\eks-setup.ps1"
    exit 1
}

Write-Host "=== Deploying to EKS ===" -ForegroundColor Cyan
Write-Host "ECR: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
Write-Host ""

# Reemplazar variables en el manifest
$tempManifest = [System.IO.Path]::GetTempFileName()
(Get-Content $appManifest) `
    -replace '\$\{AWS_ACCOUNT_ID\}', $AWS_ACCOUNT_ID `
    -replace '\$\{AWS_REGION\}', $AWS_REGION | Set-Content $tempManifest

# Aplicar manifest
kubectl apply -f $tempManifest
Remove-Item $tempManifest

# Esperar a que los deployments estén listos
Write-Host ""
Write-Host "Esperando a que los deployments estén listos..." -ForegroundColor Cyan
kubectl rollout status deployment/expense-service -w --timeout=5m
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "*** expense-service no quedó listo a tiempo. Posibles causas:" -ForegroundColor Red
    Write-Host "  - Probes: la app debe exponer /q/health/live y /q/health/ready"
    Write-Host "  - Imagen: ejecuta .\scripts-windows\build-and-push-all.ps1 y vuelve a desplegar"
    Write-Host "  - Diagnóstico: .\scripts-windows\diagnose.ps1"
    exit 1
}
kubectl rollout status deployment/expense-client -w --timeout=5m
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "*** expense-client no quedó listo a tiempo. Ejecuta: .\scripts-windows\diagnose.ps1" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Despliegue completado ===" -ForegroundColor Green
Write-Host ""
Write-Host "Esperando que el servicio LoadBalancer esté disponible..." -ForegroundColor Cyan
Start-Sleep -Seconds 15

# Obtener información del servicio
$serviceHostname = kubectl get svc expense-client -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
$serviceIp = kubectl get svc expense-client -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
$servicePort = kubectl get svc expense-client -o jsonpath='{.spec.ports[0].port}'

Write-Host ""
Write-Host "=== Estado de los servicios ===" -ForegroundColor Cyan
kubectl get pods
kubectl get svc expense-service expense-client

Write-Host ""
if ($serviceHostname) {
    Write-Host "✓ Client disponible en: http://$serviceHostname`:$servicePort" -ForegroundColor Green
    Write-Host ""
    Write-Host "Nota: El DNS del ELB puede tardar 1-2 minutos en propagarse." -ForegroundColor Yellow
} elseif ($serviceIp) {
    Write-Host "✓ Client disponible en: http://$serviceIp`:$servicePort" -ForegroundColor Green
} else {
    Write-Host "El servicio LoadBalancer está configurándose..." -ForegroundColor Yellow
    Write-Host "Obtén el hostname con:"
    Write-Host "  kubectl get svc expense-client"
    Write-Host ""
    Write-Host "O usa port-forward para acceso local:"
    Write-Host "  kubectl port-forward svc/expense-client 8081:8080"
    Write-Host "Luego accede en http://localhost:8081"
}
