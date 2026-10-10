#!/usr/bin/env bash
set -euo pipefail

# Crea una VM de Compute Engine con K3s (Kubernetes ligero) y abre el puerto 8080.
# Uso: ./k3s-setup.sh [VM_NAME] [SOURCE_RANGE]
#   SOURCE_RANGE: CIDR autorizado a acceder al puerto 8080 (por defecto tu IP pública /32)

source "$(dirname "$0")/../../scripts/lib.sh"
load_config
require_cmd gcloud "Instala desde: https://cloud.google.com/sdk/docs/install"

VM_NAME="${1:-expense-k3s}"
ZONE="${REGION}-a"
TAG="expense-k3s"
FIREWALL_RULE="${VM_NAME}-allow-8080"
K3S_CONFIG_FILE="${GCP_DIR}/gce-k3s/k3s-config.env"

SOURCE_RANGE="${2:-}"
if [ -z "${SOURCE_RANGE}" ]; then
  MY_IP=$(curl -s --max-time 10 https://api.ipify.org || true)
  if [ -z "${MY_IP}" ]; then
    echo "Error: no se pudo detectar tu IP. Indica el rango: ./k3s-setup.sh ${VM_NAME} <CIDR>"
    exit 1
  fi
  SOURCE_RANGE="${MY_IP}/32"
fi

echo "=== GCE + K3s Setup ==="
echo "VM: ${VM_NAME}  Zona: ${ZONE}  Acceso 8080 desde: ${SOURCE_RANGE}"

if gcloud compute instances describe "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" &> /dev/null; then
  echo "VM '${VM_NAME}' ya existe."
else
  gcloud compute instances create "${VM_NAME}" \
    --project "${PROJECT_ID}" --zone "${ZONE}" \
    --machine-type e2-medium \
    --image-family debian-12 --image-project debian-cloud \
    --boot-disk-size 30GB \
    --tags "${TAG}" \
    --metadata startup-script='#!/bin/bash
command -v k3s >/dev/null || curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik --write-kubeconfig-mode 644" sh -'
fi

if gcloud compute firewall-rules describe "${FIREWALL_RULE}" --project "${PROJECT_ID}" &> /dev/null; then
  gcloud compute firewall-rules update "${FIREWALL_RULE}" --source-ranges "${SOURCE_RANGE}" --project "${PROJECT_ID}" --quiet
else
  gcloud compute firewall-rules create "${FIREWALL_RULE}" \
    --project "${PROJECT_ID}" --network default \
    --allow tcp:8080 --target-tags "${TAG}" --source-ranges "${SOURCE_RANGE}"
fi

echo "Esperando a que K3s esté listo (instalación en la VM)..."
for _ in $(seq 1 40); do
  if gcloud compute ssh "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" --quiet \
      --command "sudo k3s kubectl get nodes 2>/dev/null | grep -q ' Ready'" &> /dev/null; then
    READY=true
    break
  fi
  sleep 15
done
if [ "${READY:-false}" != "true" ]; then
  echo "K3s no quedó listo. Revisa: gcloud compute ssh ${VM_NAME} --zone ${ZONE} -- sudo journalctl -u google-startup-scripts"
  exit 1
fi

EXTERNAL_IP=$(gcloud compute instances describe "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)')

cat > "${K3S_CONFIG_FILE}" <<EOT
export VM_NAME="${VM_NAME}"
export ZONE="${ZONE}"
export FIREWALL_RULE="${FIREWALL_RULE}"
EOT

echo "✓ K3s listo en ${VM_NAME} (${EXTERNAL_IP}). Configuración en: ${K3S_CONFIG_FILE}"
