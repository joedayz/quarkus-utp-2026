# Script para eliminar los recursos desplegados en ECS
# Uso: .\undeploy-all.ps1 [-DeleteAll]
#   -DeleteAll: También elimina cluster ECS, repos ECR, SG, namespace, y logs

param(
    [switch]$DeleteAll
)

$rootDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "ecs-config.ps1"

# Cargar configuración si existe
if (Test-Path $configFile) {
    . $configFile
}

if (-not $AWS_ACCOUNT_ID -or -not $AWS_REGION -or -not $CLUSTER_NAME) {
    Write-Host "Error: Variables de configuración incompletas." -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts-windows\ecs-setup.ps1"
    exit 1
}

Write-Host "=== Undeploying from ECS ===" -ForegroundColor Cyan

# Eliminar servicios ECS
foreach ($svc in @("expense-client", "expense-service")) {
    $svcStatus = aws ecs describe-services `
        --cluster $CLUSTER_NAME `
        --services $svc `
        --region $AWS_REGION `
        --query "services[?status=='ACTIVE'].serviceName" --output text 2>$null

    if ($svcStatus -and $svcStatus -ne "None") {
        Write-Host "Deteniendo servicio '$svc'..." -ForegroundColor Yellow
        aws ecs update-service `
            --cluster $CLUSTER_NAME `
            --service $svc `
            --desired-count 0 `
            --region $AWS_REGION > $null

        Write-Host "Eliminando servicio '$svc'..."
        aws ecs delete-service `
            --cluster $CLUSTER_NAME `
            --service $svc `
            --force `
            --region $AWS_REGION > $null
        Write-Host "Servicio '$svc' eliminado." -ForegroundColor Green
    } else {
        Write-Host "Servicio '$svc' no existe o ya fue eliminado." -ForegroundColor Yellow
    }
}
Write-Host ""

# Desregistrar task definitions
foreach ($family in @("expense-service", "expense-client")) {
    $taskDefs = aws ecs list-task-definitions `
        --family-prefix $family `
        --region $AWS_REGION `
        --query 'taskDefinitionArns[]' --output text 2>$null

    if ($taskDefs -and $taskDefs -ne "None") {
        foreach ($td in $taskDefs.Split("`t")) {
            Write-Host "Desregistrando task definition: $td"
            aws ecs deregister-task-definition --task-definition $td --region $AWS_REGION > $null 2>&1
        }
    }
}
Write-Host ""

Write-Host "Servicios y task definitions de ECS eliminados." -ForegroundColor Green

if ($DeleteAll) {
    Write-Host ""
    Write-Host "=== Eliminando recursos de AWS ===" -ForegroundColor Cyan

    # Eliminar Service Discovery
    if ($NAMESPACE_ID) {
        $discSvcs = aws servicediscovery list-services `
            --filters "Name=NAMESPACE_ID,Values=$NAMESPACE_ID" `
            --region $AWS_REGION `
            --query 'Services[].Id' --output text 2>$null

        if ($discSvcs -and $discSvcs -ne "None") {
            foreach ($discSvc in $discSvcs.Split("`t")) {
                Write-Host "Eliminando servicio de discovery: $discSvc"
                aws servicediscovery delete-service --id $discSvc --region $AWS_REGION 2>$null
            }
        }

        Write-Host "Eliminando namespace de Cloud Map..." -ForegroundColor Yellow
        aws servicediscovery delete-namespace --id $NAMESPACE_ID --region $AWS_REGION 2>$null
    }

    # Eliminar cluster ECS
    $activeCluster = aws ecs describe-clusters `
        --clusters $CLUSTER_NAME `
        --region $AWS_REGION `
        --query "clusters[?status=='ACTIVE'].clusterName" --output text 2>$null

    if ($activeCluster -and $activeCluster -ne "None") {
        Write-Host "Eliminando cluster ECS '$CLUSTER_NAME'..." -ForegroundColor Yellow
        aws ecs delete-cluster --cluster $CLUSTER_NAME --region $AWS_REGION > $null
        Write-Host "Cluster ECS eliminado." -ForegroundColor Green
    } else {
        Write-Host "Cluster ECS '$CLUSTER_NAME' no existe o ya fue eliminado." -ForegroundColor Yellow
    }

    # Eliminar repositorios ECR
    foreach ($repo in @("expense-service", "expense-client")) {
        $repoExists = aws ecr describe-repositories --repository-names $repo --region $AWS_REGION 2>$null
        if ($repoExists) {
            Write-Host "Eliminando repositorio ECR '$repo'..." -ForegroundColor Yellow
            aws ecr delete-repository --repository-name $repo --region $AWS_REGION --force > $null
            Write-Host "Repositorio ECR '$repo' eliminado." -ForegroundColor Green
        } else {
            Write-Host "Repositorio ECR '$repo' no existe o ya fue eliminado." -ForegroundColor Yellow
        }
    }

    # Eliminar Security Group
    if ($SG_ID) {
        Write-Host "Eliminando Security Group '$SG_ID'..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "No se pudo eliminar el SG (puede que las ENIs aún estén activas). Intenta de nuevo en unos minutos." -ForegroundColor Yellow
        } else {
            Write-Host "Security Group eliminado." -ForegroundColor Green
        }
    }

    # Eliminar Log Group
    if ($LOG_GROUP) {
        Write-Host "Eliminando Log Group '$LOG_GROUP'..." -ForegroundColor Yellow
        aws logs delete-log-group --log-group-name $LOG_GROUP --region $AWS_REGION 2>$null
    }

    Write-Host ""
    Write-Host "Recursos de AWS eliminados." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Nota: Los recursos de AWS (ECS cluster, ECR repos, SG, etc.) NO se eliminaron." -ForegroundColor Yellow
    Write-Host "Para eliminarlos también, ejecuta:"
    Write-Host "  .\scripts-windows\undeploy-all.ps1 -DeleteAll"
}
