# Script para construir y subir imágenes a Amazon ECR (para ECS)
# Requiere: ecs-setup.ps1 ejecutado previamente o variables configuradas

$rootDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "ecs-config.ps1"

# Cargar configuración si existe
if (Test-Path $configFile) {
    Write-Host "Cargando configuración desde $configFile..." -ForegroundColor Cyan
    . $configFile
}

# Verificar variables requeridas
if (-not $AWS_ACCOUNT_ID -or -not $AWS_REGION) {
    Write-Host "Error: AWS_ACCOUNT_ID o AWS_REGION no están configurados." -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts-windows\ecs-setup.ps1"
    exit 1
}

$ecrRegistry = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

Write-Host "=== Build and Push to ECR ===" -ForegroundColor Cyan
Write-Host "ECR: $ecrRegistry"
Write-Host ""

# Verificar que AWS CLI está instalado y autenticado
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

# Detectar si usar podman o docker
$containerCmd = $null
if (Get-Command podman -ErrorAction SilentlyContinue) {
    $containerCmd = "podman"
    Write-Host "Detectado: Podman" -ForegroundColor Cyan
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $containerCmd = "docker"
    Write-Host "Detectado: Docker" -ForegroundColor Cyan
} else {
    Write-Host "Error: No se encontró ni podman ni docker instalado." -ForegroundColor Red
    exit 1
}

# Login a ECR
Write-Host "=== Login a ECR ===" -ForegroundColor Cyan
$ecrPassword = aws ecr get-login-password --region $AWS_REGION
$ecrPassword | & $containerCmd login --username AWS --password-stdin $ecrRegistry
Write-Host "Login exitoso." -ForegroundColor Green
Write-Host ""

function Build-AndPush {
    param(
        [string]$Dir,
        [string]$Name,
        [string]$Dockerfile
    )

    Write-Host "=== Building $Name in $Dir ===" -ForegroundColor Cyan
    Push-Location "$rootDir\$Dir"
    
    # Construir con Maven
    mvn -q package
    
    # Construir imagen para arquitectura AMD64
    $imageTag = "$ecrRegistry/${Name}:latest"
    
    if ($containerCmd -eq "podman") {
        Write-Host "Construyendo imagen para plataforma linux/amd64..." -ForegroundColor Cyan
        & $containerCmd build --platform linux/amd64 -f $Dockerfile -t $imageTag .
    } elseif ($containerCmd -eq "docker") {
        $buildxAvailable = docker buildx version 2>$null
        if ($buildxAvailable) {
            Write-Host "Usando buildx para construir imagen multi-arch (linux/amd64)..." -ForegroundColor Cyan
            docker buildx build --platform linux/amd64 -f $Dockerfile -t $imageTag --load .
        } else {
            Write-Host "Construyendo imagen para plataforma linux/amd64..." -ForegroundColor Cyan
            docker build --platform linux/amd64 -f $Dockerfile -t $imageTag .
        }
    }
    
    Write-Host "=== Pushing $imageTag to ECR ===" -ForegroundColor Cyan
    & $containerCmd push $imageTag
    
    Write-Host "Imagen $imageTag construida y subida exitosamente." -ForegroundColor Green
    Write-Host ""
    
    Pop-Location
}

Build-AndPush -Dir "expense-service" -Name "expense-service" -Dockerfile "src/main/docker/Dockerfile.jvm"
Build-AndPush -Dir "expense-client" -Name "expense-client" -Dockerfile "src/main/docker/Dockerfile.jvm"

Write-Host "=== Todas las imágenes construidas y subidas a ECR ===" -ForegroundColor Green
Write-Host "ECR: $ecrRegistry"
