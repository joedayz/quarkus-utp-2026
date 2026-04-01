#!/bin/sh
set -euo pipefail

# Script para desplegar en ECS Fargate
# Requiere: ecs-setup.sh y build-and-push-all.sh ejecutados previamente

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/ecs-config.env"

# Cargar configuración si existe
if [ -f "${CONFIG_FILE}" ]; then
  echo "Cargando configuración desde ${CONFIG_FILE}..."
  . "${CONFIG_FILE}"
fi

# Verificar variables requeridas
for VAR in AWS_ACCOUNT_ID AWS_REGION CLUSTER_NAME EXECUTION_ROLE_ARN SUBNET_IDS SG_ID NAMESPACE_ID LOG_GROUP; do
  if [ -z "$(eval echo \${${VAR}:-})" ]; then
    echo "Error: ${VAR} no está configurado."
    echo "Ejecuta primero: ./scripts/ecs-setup.sh"
    exit 1
  fi
done

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=== Deploying to ECS Fargate ==="
echo "Cluster: ${CLUSTER_NAME}"
echo "ECR:     ${ECR_REGISTRY}"
echo ""

# --- 1. REGISTRAR SERVICE DISCOVERY para expense-service ---
echo "=== Registrando Service Discovery para expense-service ==="
EXISTING_SVC_DISC=$(aws servicediscovery list-services \
  --filters "Name=NAMESPACE_ID,Values=${NAMESPACE_ID}" \
  --region "${AWS_REGION}" \
  --query "Services[?Name=='expense-service'].Id" --output text 2>/dev/null || echo "")

if [ -n "${EXISTING_SVC_DISC}" ] && [ "${EXISTING_SVC_DISC}" != "None" ]; then
  SVC_DISCOVERY_ARN=$(aws servicediscovery get-service \
    --id "${EXISTING_SVC_DISC}" \
    --region "${AWS_REGION}" \
    --query 'Service.Arn' --output text)
  echo "Service Discovery ya existe: ${EXISTING_SVC_DISC}"
else
  SVC_DISCOVERY_ARN=$(aws servicediscovery create-service \
    --name "expense-service" \
    --namespace-id "${NAMESPACE_ID}" \
    --dns-config "NamespaceId=${NAMESPACE_ID},DnsRecords=[{Type=A,TTL=10}]" \
    --health-check-custom-config FailureThreshold=1 \
    --region "${AWS_REGION}" \
    --query 'Service.Arn' --output text)
  echo "Service Discovery creado: ${SVC_DISCOVERY_ARN}"
fi
echo ""

# --- 2. REGISTRAR TASK DEFINITION: expense-service ---
echo "=== Registrando Task Definition: expense-service ==="
cat > /tmp/expense-service-task.json <<TASKDEF
{
  "family": "expense-service",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "${EXECUTION_ROLE_ARN}",
  "containerDefinitions": [
    {
      "name": "expense-service",
      "image": "${ECR_REGISTRY}/expense-service:latest",
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
          "awslogs-group": "${LOG_GROUP}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "expense-service"
        }
      }
    }
  ]
}
TASKDEF

aws ecs register-task-definition \
  --cli-input-json file:///tmp/expense-service-task.json \
  --region "${AWS_REGION}" > /dev/null
echo "Task definition 'expense-service' registrada."
echo ""

# --- 3. REGISTRAR TASK DEFINITION: expense-client ---
echo "=== Registrando Task Definition: expense-client ==="
cat > /tmp/expense-client-task.json <<TASKDEF
{
  "family": "expense-client",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "${EXECUTION_ROLE_ARN}",
  "containerDefinitions": [
    {
      "name": "expense-client",
      "image": "${ECR_REGISTRY}/expense-client:latest",
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
          "awslogs-group": "${LOG_GROUP}",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "expense-client"
        }
      }
    }
  ]
}
TASKDEF

aws ecs register-task-definition \
  --cli-input-json file:///tmp/expense-client-task.json \
  --region "${AWS_REGION}" > /dev/null
echo "Task definition 'expense-client' registrada."
echo ""

# Convertir SUBNET_IDS a formato con comas (ya debería tener comas)
SUBNETS_CSV=$(echo "${SUBNET_IDS}" | tr ' ' ',')

# --- 4. CREAR/ACTUALIZAR SERVICIO: expense-service ---
echo "=== Desplegando servicio expense-service ==="
EXISTING_SVC=$(aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "expense-service" \
  --region "${AWS_REGION}" \
  --query 'services[?status==`ACTIVE`].serviceName' --output text 2>/dev/null || echo "")

if [ -n "${EXISTING_SVC}" ] && [ "${EXISTING_SVC}" != "None" ]; then
  echo "Actualizando servicio expense-service..."
  aws ecs update-service \
    --cluster "${CLUSTER_NAME}" \
    --service "expense-service" \
    --task-definition "expense-service" \
    --force-new-deployment \
    --region "${AWS_REGION}" > /dev/null
else
  echo "Creando servicio expense-service..."
  aws ecs create-service \
    --cluster "${CLUSTER_NAME}" \
    --service-name "expense-service" \
    --task-definition "expense-service" \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS_CSV}],securityGroups=[${SG_ID}],assignPublicIp=ENABLED}" \
    --service-registries "registryArn=${SVC_DISCOVERY_ARN}" \
    --region "${AWS_REGION}" > /dev/null
fi
echo "Servicio expense-service desplegado."
echo ""

# --- 5. CREAR/ACTUALIZAR SERVICIO: expense-client ---
echo "=== Desplegando servicio expense-client ==="
EXISTING_CLIENT=$(aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "expense-client" \
  --region "${AWS_REGION}" \
  --query 'services[?status==`ACTIVE`].serviceName' --output text 2>/dev/null || echo "")

if [ -n "${EXISTING_CLIENT}" ] && [ "${EXISTING_CLIENT}" != "None" ]; then
  echo "Actualizando servicio expense-client..."
  aws ecs update-service \
    --cluster "${CLUSTER_NAME}" \
    --service "expense-client" \
    --task-definition "expense-client" \
    --force-new-deployment \
    --region "${AWS_REGION}" > /dev/null
else
  echo "Creando servicio expense-client..."
  aws ecs create-service \
    --cluster "${CLUSTER_NAME}" \
    --service-name "expense-client" \
    --task-definition "expense-client" \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS_CSV}],securityGroups=[${SG_ID}],assignPublicIp=ENABLED}" \
    --region "${AWS_REGION}" > /dev/null
fi
echo "Servicio expense-client desplegado."
echo ""

# --- 6. ESPERAR Y MOSTRAR RESULTADO ---
echo "=== Esperando a que los servicios estén estables ==="
echo "Esto puede tardar 2-3 minutos..."
aws ecs wait services-stable \
  --cluster "${CLUSTER_NAME}" \
  --services "expense-service" "expense-client" \
  --region "${AWS_REGION}" 2>/dev/null || echo "Timeout esperando servicios (puede seguir inicializándose)"
echo ""

echo "=== Estado del despliegue ==="
echo ""
echo "Servicios:"
aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "expense-service" "expense-client" \
  --region "${AWS_REGION}" \
  --query 'services[].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' \
  --output table

echo ""
echo "Tareas en ejecución:"
TASK_ARNS=$(aws ecs list-tasks --cluster "${CLUSTER_NAME}" --region "${AWS_REGION}" --query 'taskArns[]' --output text)
if [ -n "${TASK_ARNS}" ] && [ "${TASK_ARNS}" != "None" ]; then
  aws ecs describe-tasks \
    --cluster "${CLUSTER_NAME}" \
    --tasks ${TASK_ARNS} \
    --region "${AWS_REGION}" \
    --query 'tasks[].{Task:taskDefinitionArn,Status:lastStatus,Health:healthStatus,IP:containers[0].networkInterfaces[0].privateIpv4Address}' \
    --output table
fi

# Obtener IP pública del expense-client
echo ""
CLIENT_TASK=$(aws ecs list-tasks \
  --cluster "${CLUSTER_NAME}" \
  --service-name "expense-client" \
  --region "${AWS_REGION}" \
  --query 'taskArns[0]' --output text 2>/dev/null || echo "")

if [ -n "${CLIENT_TASK}" ] && [ "${CLIENT_TASK}" != "None" ]; then
  ENI_ID=$(aws ecs describe-tasks \
    --cluster "${CLUSTER_NAME}" \
    --tasks "${CLIENT_TASK}" \
    --region "${AWS_REGION}" \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text 2>/dev/null || echo "")

  if [ -n "${ENI_ID}" ] && [ "${ENI_ID}" != "None" ]; then
    PUBLIC_IP=$(aws ec2 describe-network-interfaces \
      --network-interface-ids "${ENI_ID}" \
      --region "${AWS_REGION}" \
      --query 'NetworkInterfaces[0].Association.PublicIp' --output text 2>/dev/null || echo "")

    if [ -n "${PUBLIC_IP}" ] && [ "${PUBLIC_IP}" != "None" ]; then
      echo "✓ expense-client disponible en: http://${PUBLIC_IP}:8080"
      echo ""
      echo "Prueba con:"
      echo "  curl http://${PUBLIC_IP}:8080/expenses"
    else
      echo "La tarea no tiene IP pública aún. Espera unos segundos e intenta:"
      echo "  ./scripts/diagnose.sh"
    fi
  fi
else
  echo "No se encontró tarea de expense-client en ejecución."
  echo "Ejecuta: ./scripts/diagnose.sh"
fi

# Limpiar archivos temporales
rm -f /tmp/expense-service-task.json /tmp/expense-client-task.json
