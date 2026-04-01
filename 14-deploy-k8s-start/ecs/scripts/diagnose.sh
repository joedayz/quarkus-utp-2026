#!/bin/sh
set -euo pipefail

# Script de diagnóstico para problemas de despliegue en ECS Fargate

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/ecs-config.env"

# Cargar configuración si existe
if [ -f "${CONFIG_FILE}" ]; then
  . "${CONFIG_FILE}"
fi

if [ -z "${CLUSTER_NAME:-}" ] || [ -z "${AWS_REGION:-}" ]; then
  echo "Error: CLUSTER_NAME o AWS_REGION no están configurados."
  echo "Ejecuta primero: ./scripts/ecs-setup.sh"
  exit 1
fi

echo "=== Diagnóstico del despliegue en ECS ==="
echo "Cluster: ${CLUSTER_NAME}"
echo "Region:  ${AWS_REGION}"
echo ""

echo "1. Estado de los servicios:"
echo "---"
aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "expense-service" "expense-client" \
  --region "${AWS_REGION}" \
  --query 'services[].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount,Pending:pendingCount}' \
  --output table 2>/dev/null || echo "No se pudieron obtener servicios"
echo ""

echo "2. Tareas en ejecución:"
echo "---"
TASK_ARNS=$(aws ecs list-tasks --cluster "${CLUSTER_NAME}" --region "${AWS_REGION}" --query 'taskArns[]' --output text 2>/dev/null || echo "")
if [ -n "${TASK_ARNS}" ] && [ "${TASK_ARNS}" != "None" ]; then
  aws ecs describe-tasks \
    --cluster "${CLUSTER_NAME}" \
    --tasks ${TASK_ARNS} \
    --region "${AWS_REGION}" \
    --query 'tasks[].{TaskDef:taskDefinitionArn,Status:lastStatus,Health:healthStatus,StopReason:stoppedReason,IP:containers[0].networkInterfaces[0].privateIpv4Address}' \
    --output table
else
  echo "No hay tareas en ejecución"
fi
echo ""

echo "3. Tareas detenidas recientemente:"
echo "---"
for SVC in expense-service expense-client; do
  STOPPED_TASKS=$(aws ecs list-tasks \
    --cluster "${CLUSTER_NAME}" \
    --service-name "${SVC}" \
    --desired-status STOPPED \
    --region "${AWS_REGION}" \
    --query 'taskArns[]' --output text 2>/dev/null || echo "")

  if [ -n "${STOPPED_TASKS}" ] && [ "${STOPPED_TASKS}" != "None" ]; then
    echo "Tareas detenidas de ${SVC}:"
    aws ecs describe-tasks \
      --cluster "${CLUSTER_NAME}" \
      --tasks ${STOPPED_TASKS} \
      --region "${AWS_REGION}" \
      --query 'tasks[].{Status:lastStatus,StopCode:stopCode,StopReason:stoppedReason}' \
      --output table
  fi
done
echo ""

echo "4. Eventos recientes del servicio expense-service:"
echo "---"
aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "expense-service" \
  --region "${AWS_REGION}" \
  --query 'services[0].events[:5].{Time:createdAt,Message:message}' \
  --output table 2>/dev/null || echo "Sin eventos"
echo ""

echo "5. Eventos recientes del servicio expense-client:"
echo "---"
aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "expense-client" \
  --region "${AWS_REGION}" \
  --query 'services[0].events[:5].{Time:createdAt,Message:message}' \
  --output table 2>/dev/null || echo "Sin eventos"
echo ""

echo "6. Logs recientes de expense-service:"
echo "---"
LOG_GROUP="${LOG_GROUP:-/ecs/${CLUSTER_NAME}}"
aws logs tail "${LOG_GROUP}" --filter-pattern "expense-service" --since 30m --region "${AWS_REGION}" 2>/dev/null | tail -20 || echo "Sin logs recientes"
echo ""

echo "7. Logs recientes de expense-client:"
echo "---"
aws logs tail "${LOG_GROUP}" --filter-pattern "expense-client" --since 30m --region "${AWS_REGION}" 2>/dev/null | tail -20 || echo "Sin logs recientes"
echo ""

echo "8. IP pública del expense-client:"
echo "---"
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
      echo "✓ expense-client: http://${PUBLIC_IP}:8080"
    else
      echo "Sin IP pública asignada"
    fi
  else
    echo "Sin ENI encontrada"
  fi
else
  echo "No hay tarea de expense-client en ejecución"
fi
echo ""

echo "9. Imágenes en ECR:"
echo "---"
for REPO in expense-service expense-client; do
  echo "${REPO}:"
  aws ecr list-images --repository-name "${REPO}" --region "${AWS_REGION}" \
    --query 'imageIds[].imageTag' --output text 2>/dev/null || echo "  Sin imágenes"
done
echo ""

echo "=== Fin del diagnóstico ==="
