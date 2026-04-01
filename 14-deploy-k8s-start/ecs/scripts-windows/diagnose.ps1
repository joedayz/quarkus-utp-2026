# Script de diagnóstico para problemas de despliegue en ECS Fargate

$configFile = Join-Path (Split-Path $PSScriptRoot -Parent) "ecs-config.ps1"

# Cargar configuración si existe
if (Test-Path $configFile) {
    . $configFile
}

if (-not $CLUSTER_NAME -or -not $AWS_REGION) {
    Write-Host "Error: CLUSTER_NAME o AWS_REGION no están configurados." -ForegroundColor Red
    Write-Host "Ejecuta primero: .\scripts-windows\ecs-setup.ps1"
    exit 1
}

Write-Host "=== Diagnóstico del despliegue en ECS ===" -ForegroundColor Cyan
Write-Host "Cluster: $CLUSTER_NAME"
Write-Host "Region:  $AWS_REGION"
Write-Host ""

Write-Host "1. Estado de los servicios:" -ForegroundColor Yellow
Write-Host "---"
aws ecs describe-services `
    --cluster $CLUSTER_NAME `
    --services "expense-service" "expense-client" `
    --region $AWS_REGION `
    --query 'services[].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' `
    --output table 2>$null
Write-Host ""

Write-Host "2. Tareas en ejecución:" -ForegroundColor Yellow
Write-Host "---"
$taskArns = aws ecs list-tasks --cluster $CLUSTER_NAME --region $AWS_REGION --query 'taskArns[]' --output text 2>$null
if ($taskArns -and $taskArns -ne "None") {
    aws ecs describe-tasks `
        --cluster $CLUSTER_NAME `
        --tasks $taskArns.Split("`t") `
        --region $AWS_REGION `
        --query 'tasks[].{TaskDef:taskDefinitionArn,Status:lastStatus,Health:healthStatus,StopReason:stoppedReason}' `
        --output table
} else {
    Write-Host "No hay tareas en ejecución" -ForegroundColor Red
}
Write-Host ""

Write-Host "3. Tareas detenidas recientemente:" -ForegroundColor Yellow
Write-Host "---"
foreach ($svc in @("expense-service", "expense-client")) {
    $stoppedTasks = aws ecs list-tasks `
        --cluster $CLUSTER_NAME `
        --service-name $svc `
        --desired-status STOPPED `
        --region $AWS_REGION `
        --query 'taskArns[]' --output text 2>$null

    if ($stoppedTasks -and $stoppedTasks -ne "None") {
        Write-Host "Tareas detenidas de $svc`:"
        aws ecs describe-tasks `
            --cluster $CLUSTER_NAME `
            --tasks $stoppedTasks.Split("`t") `
            --region $AWS_REGION `
            --query 'tasks[].{Status:lastStatus,StopCode:stopCode,StopReason:stoppedReason}' `
            --output table
    }
}
Write-Host ""

Write-Host "4. Eventos recientes del servicio expense-service:" -ForegroundColor Yellow
Write-Host "---"
aws ecs describe-services `
    --cluster $CLUSTER_NAME `
    --services "expense-service" `
    --region $AWS_REGION `
    --query 'services[0].events[:5].{Time:createdAt,Message:message}' `
    --output table 2>$null
Write-Host ""

Write-Host "5. Eventos recientes del servicio expense-client:" -ForegroundColor Yellow
Write-Host "---"
aws ecs describe-services `
    --cluster $CLUSTER_NAME `
    --services "expense-client" `
    --region $AWS_REGION `
    --query 'services[0].events[:5].{Time:createdAt,Message:message}' `
    --output table 2>$null
Write-Host ""

Write-Host "6. Logs recientes de expense-service:" -ForegroundColor Yellow
Write-Host "---"
$logGroup = if ($LOG_GROUP) { $LOG_GROUP } else { "/ecs/$CLUSTER_NAME" }
aws logs tail $logGroup --filter-pattern "expense-service" --since 30m --region $AWS_REGION 2>$null | Select-Object -Last 20
Write-Host ""

Write-Host "7. Logs recientes de expense-client:" -ForegroundColor Yellow
Write-Host "---"
aws logs tail $logGroup --filter-pattern "expense-client" --since 30m --region $AWS_REGION 2>$null | Select-Object -Last 20
Write-Host ""

Write-Host "8. IP pública del expense-client:" -ForegroundColor Yellow
Write-Host "---"
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
            Write-Host "✓ expense-client: http://$publicIp`:8080" -ForegroundColor Green
        } else {
            Write-Host "Sin IP pública asignada" -ForegroundColor Red
        }
    } else {
        Write-Host "Sin ENI encontrada" -ForegroundColor Red
    }
} else {
    Write-Host "No hay tarea de expense-client en ejecución" -ForegroundColor Red
}
Write-Host ""

Write-Host "9. Imágenes en ECR:" -ForegroundColor Yellow
Write-Host "---"
foreach ($repo in @("expense-service", "expense-client")) {
    Write-Host "$repo`:"
    aws ecr list-images --repository-name $repo --region $AWS_REGION `
        --query 'imageIds[].imageTag' --output text 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Sin imágenes" -ForegroundColor Yellow
    }
}
Write-Host ""

Write-Host "=== Fin del diagnóstico ===" -ForegroundColor Cyan
