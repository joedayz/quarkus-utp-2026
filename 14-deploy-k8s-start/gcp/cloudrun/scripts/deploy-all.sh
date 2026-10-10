#!/usr/bin/env bash
set -euo pipefail

# Despliega expense-service y expense-client en Cloud Run.
# Uso: ./deploy-all.sh [--public-backend]
#   Por defecto el backend solo acepta tráfico interno (ingress=internal) y el cliente
#   sale por la VPC 'default' (Direct VPC egress). Requiere la red 'default' y Private Google Access.
#   --public-backend: el backend queda accesible públicamente (más simple, menos seguro).
# Requiere: ../../scripts/gcp-setup.sh y ../../scripts/build-and-push-all.sh ejecutados.

source "$(dirname "$0")/../../scripts/lib.sh"
load_config
require_cmd gcloud "Instala desde: https://cloud.google.com/sdk/docs/install"

PUBLIC_BACKEND=false
[ "${1:-}" = "--public-backend" ] && PUBLIC_BACKEND=true

COMMON_FLAGS=(--project "${PROJECT_ID}" --region "${REGION}" --port 8080
  --memory 512Mi --cpu 1 --cpu-boost --min-instances 0 --max-instances 3 --quiet)

echo "=== Deploying to Cloud Run ==="
echo "Proyecto: ${PROJECT_ID}  Región: ${REGION}"

if [ "${PUBLIC_BACKEND}" = "true" ]; then
  BACKEND_FLAGS=(--ingress all)
  CLIENT_NET_FLAGS=()
else
  if ! gcloud compute networks describe default --project "${PROJECT_ID}" &> /dev/null; then
    echo "Error: no existe la red 'default'. Usa --public-backend o crea una VPC/subred y ajusta el script."
    exit 1
  fi
  gcloud compute networks subnets update default --region "${REGION}" \
    --enable-private-ip-google-access --project "${PROJECT_ID}" --quiet
  BACKEND_FLAGS=(--ingress internal)
  CLIENT_NET_FLAGS=(--network default --subnet default --vpc-egress all-traffic)
fi

# El backend no usa IAM propia: la restricción se aplica a nivel de red (ingress)
gcloud run deploy expense-service \
  --image "${IMAGE_REGISTRY}/expense-service:latest" \
  --allow-unauthenticated "${BACKEND_FLAGS[@]}" "${COMMON_FLAGS[@]}"

SERVICE_URL=$(gcloud run services describe expense-service --region "${REGION}" --project "${PROJECT_ID}" --format='value(status.url)')
echo "expense-service: ${SERVICE_URL}"

gcloud run deploy expense-client \
  --image "${IMAGE_REGISTRY}/expense-client:latest" \
  --set-env-vars "EXPENSE_SVC=${SERVICE_URL}" \
  --allow-unauthenticated ${CLIENT_NET_FLAGS[@]+"${CLIENT_NET_FLAGS[@]}"} "${COMMON_FLAGS[@]}"

CLIENT_URL=$(gcloud run services describe expense-client --region "${REGION}" --project "${PROJECT_ID}" --format='value(status.url)')
echo ""
echo "✓ Client disponible en: ${CLIENT_URL}/expenses"
