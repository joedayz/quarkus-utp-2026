#!/usr/bin/env bash
set -euo pipefail

# Elimina la aplicación de K3s.
# Uso: ./undeploy-all.sh [--delete-all]
#   --delete-all: elimina también la VM y la regla de firewall

source "$(dirname "$0")/../../scripts/lib.sh"
load_config
. "${GCP_DIR}/gce-k3s/k3s-config.env" 2> /dev/null || { echo "No hay k3s-config.env; nada que eliminar."; exit 0; }

if [ "${1:-}" = "--delete-all" ]; then
  gcloud compute instances delete "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" --quiet || true
  gcloud compute firewall-rules delete "${FIREWALL_RULE}" --project "${PROJECT_ID}" --quiet || true
  rm -f "${GCP_DIR}/gce-k3s/k3s-config.env"
  echo "VM y firewall eliminados."
else
  render_manifest | gcloud compute ssh "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" --quiet \
    --command "sudo k3s kubectl delete --ignore-not-found -f -"
  echo "La VM NO se eliminó (sigue generando costo). Usa: ./scripts/undeploy-all.sh --delete-all"
fi
