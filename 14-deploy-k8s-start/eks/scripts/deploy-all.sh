#!/bin/sh
set -euo pipefail

# Script para desplegar en EKS
# Requiere: eks-setup.sh y build-and-push-all.sh ejecutados previamente

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/eks-config.env"
APP_MANIFEST="${ROOT_DIR}/k8s/expenses-all.yaml"

# Cargar configuración si existe
if [ -f "${CONFIG_FILE}" ]; then
  echo "Cargando configuración desde ${CONFIG_FILE}..."
  . "${CONFIG_FILE}"
fi

# Verificar variables requeridas
if [ -z "${AWS_ACCOUNT_ID:-}" ] || [ -z "${AWS_REGION:-}" ]; then
  echo "Error: AWS_ACCOUNT_ID o AWS_REGION no están configurados."
  echo "Ejecuta primero: ./scripts/eks-setup.sh"
  exit 1
fi

# Verificar conexión con EKS
if ! kubectl cluster-info &> /dev/null; then
  echo "Error: No hay conexión con el cluster de Kubernetes."
  echo "Ejecuta primero: ./scripts/eks-setup.sh"
  exit 1
fi

echo "=== Deploying to EKS ==="
echo "ECR: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ""

# Reemplazar variables en el manifest
TEMP_MANIFEST=$(mktemp)
sed -e "s/\${AWS_ACCOUNT_ID}/${AWS_ACCOUNT_ID}/g" \
    -e "s/\${AWS_REGION}/${AWS_REGION}/g" \
    "${APP_MANIFEST}" > "${TEMP_MANIFEST}"

# Aplicar manifest
kubectl apply -f "${TEMP_MANIFEST}"
rm "${TEMP_MANIFEST}"

# Esperar a que los deployments estén listos
echo ""
echo "Esperando a que los deployments estén listos..."
if ! kubectl rollout status deployment/expense-service -w --timeout=5m; then
  echo ""
  echo "*** expense-service no quedó listo a tiempo. Posibles causas:"
  echo "  - Probes: la app debe exponer /q/health/live y /q/health/ready (añade quarkus-smallrye-health en pom.xml)"
  echo "  - Imagen: ejecuta ./scripts/build-and-push-all.sh y vuelve a desplegar"
  echo "  - Diagnóstico: ./scripts/diagnose.sh"
  echo "  - Ver pod: kubectl get pods -l app=expense-service && kubectl describe pod -l app=expense-service"
  exit 1
fi
if ! kubectl rollout status deployment/expense-client -w --timeout=5m; then
  echo ""
  echo "*** expense-client no quedó listo a tiempo. Ejecuta: ./scripts/diagnose.sh"
  exit 1
fi

echo ""
echo "=== Despliegue completado ==="
echo ""
echo "Esperando que el servicio LoadBalancer esté disponible..."
sleep 15

# Obtener información del servicio
SERVICE_HOSTNAME=$(kubectl get svc expense-client -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
SERVICE_IP=$(kubectl get svc expense-client -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
SERVICE_PORT=$(kubectl get svc expense-client -o jsonpath='{.spec.ports[0].port}')

echo ""
echo "=== Estado de los servicios ==="
kubectl get pods
kubectl get svc expense-service expense-client

echo ""
if [ -n "${SERVICE_HOSTNAME}" ]; then
  echo "✓ Client disponible en: http://${SERVICE_HOSTNAME}:${SERVICE_PORT}"
  echo ""
  echo "Nota: El DNS del ELB puede tardar 1-2 minutos en propagarse."
elif [ -n "${SERVICE_IP}" ]; then
  echo "✓ Client disponible en: http://${SERVICE_IP}:${SERVICE_PORT}"
else
  echo "El servicio LoadBalancer está configurándose..."
  echo "Obtén el hostname con:"
  echo "  kubectl get svc expense-client"
  echo ""
  echo "O usa port-forward para acceso local:"
  echo "  kubectl port-forward svc/expense-client 8081:8080"
  echo "Luego accede en http://localhost:8081"
fi
