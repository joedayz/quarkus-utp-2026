#!/bin/sh
set -euo pipefail

# Script para mostrar información del cluster EKS

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/eks-config.env"

# Cargar configuración si existe
if [ -f "${CONFIG_FILE}" ]; then
  . "${CONFIG_FILE}"
fi

echo "=== Información del cluster EKS ==="
echo ""

if [ -n "${CLUSTER_NAME:-}" ]; then
  echo "Cluster: ${CLUSTER_NAME}"
  echo "Region:  ${AWS_REGION}"
  echo "Account: ${AWS_ACCOUNT_ID}"
  echo ""
fi

echo "Cluster Info:"
kubectl cluster-info
echo ""

echo "Nodos:"
kubectl get nodes -o wide
echo ""

echo "Pods:"
kubectl get pods -o wide
echo ""

echo "Servicios:"
kubectl get svc
echo ""

echo "Repositorios ECR:"
if [ -n "${AWS_REGION:-}" ]; then
  aws ecr describe-repositories --region "${AWS_REGION}" --query 'repositories[].repositoryName' --output table 2>/dev/null || echo "No se pudieron listar los repositorios ECR"
else
  echo "AWS_REGION no configurado"
fi
