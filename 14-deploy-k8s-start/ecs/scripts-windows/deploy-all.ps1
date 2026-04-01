# Script para desplegar en ECS Fargate
# Requiere: ecs-setup.ps1 y build-and-push-all.ps1 ejecutados previamente

$rootDir = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "ecs-config.ps1"

# Cargar configuración si existe
if (Test-Path $configFile) {
    Write-Host "Cargando configuración desde $configFile..." -ForegroundColor Cyan
    . $configFile
}

# Verificar variables requeridas
$requiredVars = @("AWS_ACCOUNT_ID", "AWS_REGION", "CLUSTER_NAME", "EXECUTION_ROLE_ARN", "SUBNET_IDS", "SG_ID", "NAMESPACE_ID", "LOG_GROUP")
foreach ($var in $requiredVars) {
    if (-not (Get-Variable -Name $var -ValueOnly -ErrorAction SilentlyContinue)) {
        Write-Host "Error: $var no está configurado." -ForegroundColor Red
        Write-Host "Ejecuta primero: .\scripts-windows\ecs-setup.ps1"
        exit 1
    }
}

$ecrRegistry = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

Write-Host "=== Deploying to ECS Fargate ===" -ForegroundColor Cyan
Write-Host "Cluster: $CLUSTER_NAME"
Write-Host "ECR:     $ecrRegistry"
Write-Host ""

# --- 1. REGISTRAR SERVICE DISCOVERY para expense-service ---
Write-Host "=== Registrando Service Discovery para expense-service ===" -ForegroundColor Cyan
$existingSvcDisc = aws servicediscovery list-services `
    --filters "Name=NAMESPACE_ID,Values=$NAMESPACE_ID" `
    --region $AWS_REGION `
    --query "Services[?Name=='expense-service'].Id" --output text 2>$null

if ($existingSvcDisc -and $existingSvcDisc -ne "None") {
    $svcDiscoveryArn = aws servicediscovery get-service `
        --id $existingSvcDisc `
        --region $AWS_REGION `
        --query 'Service.Arn' --output text
    Write-Host "Service Discovery ya existe: $existingSvcDisc"
} else {
    $svcDiscoveryArn = aws servicediscovery create-service `
        --name "expense-service" `
        --namespace-id $NAMESPACE_ID `
        --dns-config "NamespaceId=$NAMESPACE_ID,DnsRecords=[{Type=A,TTL=10}]" `
        --health-check-custom-config FailureThreshold=1 `
        --region $AWS_REGION `
        --query 'Service.Arn' --output text
    Write-Host "Service Discovery creado: $svcDiscoveryArn"
}
Write-Host ""

# --- 2. REGISTRAR TASK DEFINITION: expense-service ---
Write-Host "=== Registrando Task Definition: expense-service ===" -ForegroundColor Cyan
$serviceTaskDef = @"
{
  "family": "expense-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "expense-service",
      "image": "$ecrRegistry/expense-service:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "healthCheck": {
"command": ["CMD-SHELL", "curl -sf http://localhost:8080/q/health/live || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "$LOG_GROUP",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "expense-service"
        }
      }
    }
  ]
}
"@

$serviceTaskFile = [System.IO.Path]::GetTempFileName()
$serviceTaskDef | Out-File -FilePath $serviceTaskFile -Encoding utf8

aws ecs register-task-definition `
    --cli-input-json "file://$serviceTaskFile" `
    --region $AWS_REGION > $null
Remove-Item $serviceTaskFile
Write-Host "Task definition 'expense-service' registrada." -ForegroundColor Green
Write-Host ""

# --- 3. REGISTRAR TASK DEFINITION: expense-client ---
Write-Host "=== Registrando Task Definition: expense-client ===" -ForegroundColor Cyan
$clientTaskDef = @"
{
  "family": "expense-client",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "expense-client",
      "image": "$ecrRegistry/expense-client:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "EXPENSE_SVC",
          "value": "http://expense-service.expense.local:8080"
        }
      ],
      "healthCheck": {
"command": ["CMD-SHELL", "curl -sf http://localhost:8080/q/health/live || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "$LOG_GROUP",
          "awslogs-region": "$AWS_REGION",
          "awslogs-stream-prefix": "expense-client"
        }
      }
    }
  ]
}
"@

$clientTaskFile = [System.IO.Path]::GetTempFileName()
$clientTaskDef | Out-File -FilePath $clientTaskFile -Encoding utf8

aws ecs register-task-definition `
    --cli-input-json "file://$clientTaskFile" `
    --region $AWS_REGION > $null
Remove-Item $clientTaskFile
Write-Host "Task definition 'expense-client' registrada." -ForegroundColor Green
Write-Host ""

# --- 4. CREAR/ACTUALIZAR SERVICIO: expense-service ---
Write-Host "=== Desplegando servicio expense-service ===" -ForegroundColor Cyan
$existingSvc = aws ecs describe-services `
    --cluster $CLUSTER_NAME `
    --services "expense-service" `
    --region $AWS_REGION `
    --query "services[?status=='ACTIVE'].serviceName" --output text 2>$null

if ($existingSvc -and $existingSvc -ne "None") {
    Write-Host "Actualizando servicio expense-service..."
    aws ecs update-service `
        --cluster $CLUSTER_NAME `
        --service "expense-service" `
        --task-definition "expense-service" `
        --force-new-deployment `
        --region $AWS_REGION > $null
} else {
    Write-Host "Creando servicio expense-service..."
    aws ecs create-service `
        --cluster $CLUSTER_NAME `
        --service-name "expense-service" `
        --task-definition "expense-service" `
        --desired-count 1 `
        --launch-type FARGATE `
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" `
        --service-registries "registryArn=$svcDiscoveryArn" `
        --region $AWS_REGION > $null
}
Write-Host "Servicio expense-service desplegado." -ForegroundColor Green
Write-Host ""

# --- 5. CREAR/ACTUALIZAR SERVICIO: expense-client ---
Write-Host "=== Desplegando servicio expense-client ===" -ForegroundColor Cyan
$existingClient = aws ecs describe-services `
    --cluster $CLUSTER_NAME `
    --services "expense-client" `
    --region $AWS_REGION `
    --query "services[?status=='ACTIVE'].serviceName" --output text 2>$null

if ($existingClient -and $existingClient -ne "None") {
    Write-Host "Actualizando servicio expense-client..."
    aws ecs update-service `
        --cluster $CLUSTER_NAME `
        --service "expense-client" `
        --task-definition "expense-client" `
        --force-new-deployment `
        --region $AWS_REGION > $null
} else {
    Write-Host "Creando servicio expense-client..."
    aws ecs create-service `
        --cluster $CLUSTER_NAME `
        --service-name "expense-client" `
        --task-definition "expense-client" `
        --desired-count 1 `
        --launch-type FARGATE `
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_IDS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}" `
        --region $AWS_REGION > $null
}
Write-Host "Servicio expense-client desplegado." -ForegroundColor Green
Write-Host ""

# --- 6. ESPERAR Y MOSTRAR RESULTADO ---
Write-Host "=== Esperando a que los servicios estén estables ===" -ForegroundColor Cyan
Write-Host "Esto puede tardar 2-3 minutos..."
aws ecs wait services-stable `
    --cluster $CLUSTER_NAME `
    --services "expense-service" "expense-client" `
    --region $AWS_REGION 2>$null
Write-Host ""

Write-Host "=== Estado del despliegue ===" -ForegroundColor Green
Write-Host ""
Write-Host "Servicios:" -ForegroundColor Yellow
aws ecs describe-services `
    --cluster $CLUSTER_NAME `
    --services "expense-service" "expense-client" `
    --region $AWS_REGION `
    --query 'services[].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' `
    --output table

Write-Host ""
Write-Host "Tareas en ejecución:" -ForegroundColor Yellow
$taskArns = aws ecs list-tasks --cluster $CLUSTER_NAME --region $AWS_REGION --query 'taskArns[]' --output text
if ($taskArns -and $taskArns -ne "None") {
    aws ecs describe-tasks `
        --cluster $CLUSTER_NAME `
        --tasks $taskArns.Split("`t") `
        --region $AWS_REGION `
        --query 'tasks[].{Task:taskDefinitionArn,Status:lastStatus,Health:healthStatus}' `
        --output table
}

# Obtener IP pública del expense-client
Write-Host ""
$clientTask = aws ecs list-tasks `
    --cluster $CLUSTER_NAME `
    --service-name "expense-client" `
    --region $AWS_REGION `
    --query 'taskArns[0]' --output text 2>$null

if ($clientTask -and $clientTask -ne "None") {
    $eniId = aws ecs describe-tasks `
        --cluster $CLUSTER_NAME `
        --tasks $clientTask `
        --region $AWS_REGION `
        --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text 2>$null

    if ($eniId -and $eniId -ne "None") {
        $publicIp = aws ec2 describe-network-interfaces `
            --network-interface-ids $eniId `
            --region $AWS_REGION `
            --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>$null

        if ($publicIp -and $publicIp -ne "None") {
            Write-Host "✓ expense-client disponible en: http://$publicIp`:8080" -ForegroundColor Green
            Write-Host ""
            Write-Host "Prueba con:"
            Write-Host "  curl http://$publicIp`:8080/expenses"
        } else {
            Write-Host "La tarea no tiene IP pública aún. Espera unos segundos e intenta:" -ForegroundColor Yellow
            Write-Host "  .\scripts-windows\diagnose.ps1"
        }
    }
} else {
    Write-Host "No se encontró tarea de expense-client en ejecución." -ForegroundColor Yellow
    Write-Host "Ejecuta: .\scripts-windows\diagnose.ps1"
}
