#!/bin/sh
set -euo pipefail

# Script para eliminar los recursos desplegados en ECS
# Uso: ./undeploy-all.sh [--delete-all]
#   --delete-all: También elimina cluster ECS, repos ECR, SG, namespace, y logs

DELETE_AWS_RESOURCES=false
if [ "${1:-}" = "--delete-all" ]; then
  DELETE_AWS_RESOURCES=true
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/ecs-config.env"

# Cargar configuración si existe
if [ -f "${CONFIG_FILE}" ]; then
  . "${CONFIG_FILE}"
fi

if [ -z "${AWS_ACCOUNT_ID:-}" ] || [ -z "${AWS_REGION:-}" ] || [ -z "${CLUSTER_NAME:-}" ]; then
  echo "Error: Variables de configuración incompletas."
  echo "Ejecuta primero: ./scripts/ecs-setup.sh"
  exit 1
fi

echo "=== Undeploying from ECS ==="

# Eliminar servicios ECS
for SVC in expense-client expense-service; do
  SVC_STATUS=$(aws ecs describe-services \
    --cluster "${CLUSTER_NAME}" \
    --services "${SVC}" \
    --region "${AWS_REGION}" \
    --query 'services[?status==`ACTIVE`].serviceName' --output text 2>/dev/null || echo "")

  if [ -n "${SVC_STATUS}" ] && [ "${SVC_STATUS}" != "None" ]; then
    echo "Deteniendo servicio '${SVC}'..."
    aws ecs update-service \
      --cluster "${CLUSTER_NAME}" \
      --service "${SVC}" \
      --desired-count 0 \
      --region "${AWS_REGION}" > /dev/null

    echo "Eliminando servicio '${SVC}'..."
    aws ecs delete-service \
      --cluster "${CLUSTER_NAME}" \
      --service "${SVC}" \
      --force \
      --region "${AWS_REGION}" > /dev/null
    echo "Servicio '${SVC}' eliminado."
  else
    echo "Servicio '${SVC}' no existe o ya fue eliminado."
  fi
done
echo ""

# Desregistrar task definitions
for FAMILY in expense-service expense-client; do
  TASK_DEFS=$(aws ecs list-task-definitions \
    --family-prefix "${FAMILY}" \
    --region "${AWS_REGION}" \
    --query 'taskDefinitionArns[]' --output text 2>/dev/null || echo "")

  if [ -n "${TASK_DEFS}" ] && [ "${TASK_DEFS}" != "None" ]; then
    for TD in ${TASK_DEFS}; do
      echo "Desregistrando task definition: ${TD}"
      aws ecs deregister-task-definition --task-definition "${TD}" --region "${AWS_REGION}" > /dev/null 2>&1 || true
    done
  fi
done
echo ""

echo "Servicios y task definitions de ECS eliminados."

if [ "${DELETE_AWS_RESOURCES}" = "true" ]; then
  echo ""
  echo "=== Eliminando recursos de AWS ==="

  # Eliminar Service Discovery
  if [ -n "${NAMESPACE_ID:-}" ]; then
    # Primero eliminar los servicios de discovery
    DISC_SVCS=$(aws servicediscovery list-services \
      --filters "Name=NAMESPACE_ID,Values=${NAMESPACE_ID}" \
      --region "${AWS_REGION}" \
      --query 'Services[].Id' --output text 2>/dev/null || echo "")

    for DISC_SVC in ${DISC_SVCS}; do
      if [ -n "${DISC_SVC}" ] && [ "${DISC_SVC}" != "None" ]; then
        echo "Eliminando servicio de discovery: ${DISC_SVC}"
        aws servicediscovery delete-service --id "${DISC_SVC}" --region "${AWS_REGION}" 2>/dev/null || true
      fi
    done

    echo "Eliminando namespace de Cloud Map..."
    aws servicediscovery delete-namespace --id "${NAMESPACE_ID}" --region "${AWS_REGION}" 2>/dev/null || echo "No se pudo eliminar namespace"
  fi

  # Eliminar cluster ECS
  ACTIVE_CLUSTER=$(aws ecs describe-clusters \
    --clusters "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --query 'clusters[?status==`ACTIVE`].clusterName' --output text 2>/dev/null || echo "")

  if [ -n "${ACTIVE_CLUSTER}" ] && [ "${ACTIVE_CLUSTER}" != "None" ]; then
    echo "Eliminando cluster ECS '${CLUSTER_NAME}'..."
    aws ecs delete-cluster --cluster "${CLUSTER_NAME}" --region "${AWS_REGION}" > /dev/null
    echo "Cluster ECS eliminado."
  else
    echo "Cluster ECS '${CLUSTER_NAME}' no existe o ya fue eliminado."
  fi

  # Eliminar repositorios ECR
  for REPO in expense-service expense-client; do
    if aws ecr describe-repositories --repository-names "${REPO}" --region "${AWS_REGION}" &> /dev/null; then
      echo "Eliminando repositorio ECR '${REPO}'..."
      aws ecr delete-repository --repository-name "${REPO}" --region "${AWS_REGION}" --force > /dev/null
      echo "Repositorio ECR '${REPO}' eliminado."
    else
      echo "Repositorio ECR '${REPO}' no existe o ya fue eliminado."
    fi
  done

  # Eliminar Security Group
  if [ -n "${SG_ID:-}" ]; then
    echo "Eliminando Security Group '${SG_ID}'..."
    # Puede fallar si las ENIs aún no se liberaron. Reintentar.
    sleep 5
    aws ec2 delete-security-group --group-id "${SG_ID}" --region "${AWS_REGION}" 2>/dev/null \
      || echo "No se pudo eliminar el SG (puede que las ENIs aún estén activas). Intenta de nuevo en unos minutos."
  fi

  # Eliminar Log Group
  if [ -n "${LOG_GROUP:-}" ]; then
    echo "Eliminando Log Group '${LOG_GROUP}'..."
    aws logs delete-log-group --log-group-name "${LOG_GROUP}" --region "${AWS_REGION}" 2>/dev/null || true
  fi

  echo ""
  echo "Recursos de AWS eliminados."
else
  echo ""
  echo "Nota: Los recursos de AWS (ECS cluster, ECR repos, SG, etc.) NO se eliminaron."
  echo "Para eliminarlos también, ejecuta:"
  echo "  ./scripts/undeploy-all.sh --delete-all"
fi
