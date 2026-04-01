#!/bin/sh
set -euo pipefail

# Script para eliminar los recursos desplegados en EKS
# Uso: ./undeploy-all.sh [--delete-all]
#   --delete-all: También elimina el cluster EKS y los repos ECR

DELETE_AWS_RESOURCES=false
if [ "${1:-}" = "--delete-all" ]; then
  DELETE_AWS_RESOURCES=true
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_MANIFEST="${ROOT_DIR}/k8s/expenses-all.yaml"
CONFIG_FILE="${ROOT_DIR}/eks-config.env"

# Cargar configuración si existe
if [ -f "${CONFIG_FILE}" ]; then
  . "${CONFIG_FILE}"
fi

if [ -z "${AWS_ACCOUNT_ID:-}" ] || [ -z "${AWS_REGION:-}" ]; then
  echo "Error: AWS_ACCOUNT_ID o AWS_REGION no están configurados."
  echo "Ejecuta primero: ./scripts/eks-setup.sh"
  exit 1
fi

echo "=== Undeploying from EKS ==="

# Reemplazar variables en el manifest
TEMP_MANIFEST=$(mktemp)
sed -e "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" \
    -e "s/\${AWS_REGION}/${AWS_REGION}/g" \
    "${APP_MANIFEST}" > "${TEMP_MANIFEST}"

# Eliminar recursos de Kubernetes
kubectl delete -f "${TEMP_MANIFEST}" --ignore-not-found=true
rm "${TEMP_MANIFEST}"

echo ""
echo "Recursos de Kubernetes eliminados."

# Eliminar recursos de AWS si se solicita
if [ "${DELETE_AWS_RESOURCES}" = "true" ]; then
  echo ""
  echo "=== Eliminando recursos de AWS ==="

  CLUSTER_NAME="${CLUSTER_NAME:-expense-eks}"

  # Verificar que AWS CLI está instalado
  if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI no está instalado."
    exit 1
  fi

  if ! aws sts get-caller-identity &> /dev/null; then
    echo "Error: No estás autenticado en AWS."
    echo "Ejecuta: aws configure"
    exit 1
  fi

  # Eliminar cluster EKS
  if command -v eksctl &> /dev/null; then
    if eksctl get cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" &> /dev/null; then
      echo "Eliminando cluster EKS '${CLUSTER_NAME}'..."
      echo "Esto puede tardar varios minutos..."
      eksctl delete cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" --wait
      echo "Cluster EKS '${CLUSTER_NAME}' eliminado."
    else
      echo "Cluster EKS '${CLUSTER_NAME}' no existe o ya fue eliminado."
    fi
  else
    echo "eksctl no está instalado. Elimina el cluster manualmente:"
    echo "  eksctl delete cluster --name ${CLUSTER_NAME} --region ${AWS_REGION}"
  fi

  # Eliminar repositorios ECR
  for REPO in expense-service expense-client; do
    if aws ecr describe-repositories --repository-names "${REPO}" --region "${AWS_REGION}" &> /dev/null; then
      echo "Eliminando repositorio ECR '${REPO}'..."
      aws ecr delete-repository --repository-name "${REPO}" --region "${AWS_REGION}" --force
      echo "Repositorio ECR '${REPO}' eliminado."
    else
      echo "Repositorio ECR '${REPO}' no existe o ya fue eliminado."
    fi
  done

  echo ""
  echo "Recursos de AWS eliminados."
else
  echo ""
  echo "Nota: Los recursos de AWS (EKS, ECR) NO se eliminaron."
  echo "Para eliminarlos también, ejecuta:"
  echo "  ./scripts/undeploy-all.sh --delete-all"
fi
