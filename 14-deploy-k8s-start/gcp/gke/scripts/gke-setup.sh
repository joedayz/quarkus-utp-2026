#!/usr/bin/env bash
set -euo pipefail

# Crea un cluster GKE (Autopilot o Standard) y configura kubectl.
# Uso: ./gke-setup.sh [autopilot|standard] [CLUSTER_NAME]
# Requiere: ../../scripts/gcp-setup.sh ejecutado previamente.

source "$(dirname "$0")/../../scripts/lib.sh"
load_config

MODE="${1:-autopilot}"
case "${MODE}" in
  autopilot|standard) ;;
  *) echo "Modo inválido '${MODE}'. Usa: autopilot | standard"; exit 1 ;;
esac
CLUSTER_NAME="${2:-expense-gke-${MODE}}"
GKE_CONFIG_FILE="${GCP_DIR}/gke/gke-config.env"

require_cmd gcloud "Instala desde: https://cloud.google.com/sdk/docs/install"
require_cmd kubectl "Instala desde: https://kubernetes.io/docs/tasks/tools/"
if ! command -v gke-gcloud-auth-plugin &> /dev/null; then
  echo "Error: falta gke-gcloud-auth-plugin."
  echo "Instala con: gcloud components install gke-gcloud-auth-plugin"
  exit 1
fi

# Autopilot es siempre regional; Standard se crea zonal para reducir costo
if [ "${MODE}" = "autopilot" ]; then
  LOCATION_FLAG="--region"
  LOCATION="${REGION}"
else
  LOCATION_FLAG="--zone"
  LOCATION="${REGION}-a"
fi

echo "=== GKE Setup (${MODE}) ==="
echo "Proyecto: ${PROJECT_ID}"
echo "Cluster:  ${CLUSTER_NAME}"
echo "Ubicación: ${LOCATION}"
echo ""

if gcloud container clusters describe "${CLUSTER_NAME}" "${LOCATION_FLAG}" "${LOCATION}" --project "${PROJECT_ID}" &> /dev/null; then
  echo "Cluster '${CLUSTER_NAME}' ya existe."
else
  echo "Creando cluster (puede tardar 5-15 minutos)..."
  if [ "${MODE}" = "autopilot" ]; then
    gcloud container clusters create-auto "${CLUSTER_NAME}" \
      --region "${LOCATION}" --project "${PROJECT_ID}"
  else
    gcloud container clusters create "${CLUSTER_NAME}" \
      --zone "${LOCATION}" --project "${PROJECT_ID}" \
      --machine-type e2-medium --num-nodes 2 \
      --enable-autoscaling --min-nodes 1 --max-nodes 3
  fi
fi

gcloud container clusters get-credentials "${CLUSTER_NAME}" \
  "${LOCATION_FLAG}" "${LOCATION}" --project "${PROJECT_ID}"

kubectl cluster-info
kubectl get nodes

cat > "${GKE_CONFIG_FILE}" <<EOT
export GKE_MODE="${MODE}"
export CLUSTER_NAME="${CLUSTER_NAME}"
export LOCATION_FLAG="${LOCATION_FLAG}"
export LOCATION="${LOCATION}"
EOT

echo ""
echo "=== Cluster listo. Configuración en: ${GKE_CONFIG_FILE} ==="
