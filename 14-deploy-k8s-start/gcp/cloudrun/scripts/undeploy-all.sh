#!/usr/bin/env bash
set -euo pipefail

# Elimina los servicios de Cloud Run (el registro se borra con ../../scripts/delete-registry.sh)

source "$(dirname "$0")/../../scripts/lib.sh"
load_config

for s in expense-client expense-service; do
  if gcloud run services describe "${s}" --region "${REGION}" --project "${PROJECT_ID}" &> /dev/null; then
    gcloud run services delete "${s}" --region "${REGION}" --project "${PROJECT_ID}" --quiet
  else
    echo "Servicio ${s} no existe."
  fi
done
