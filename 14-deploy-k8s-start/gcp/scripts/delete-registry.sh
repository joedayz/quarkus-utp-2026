#!/usr/bin/env bash
set -euo pipefail

# Elimina el repositorio de Artifact Registry (y todas las imágenes).

source "$(dirname "$0")/lib.sh"
load_config
require_cmd gcloud "Instala desde: https://cloud.google.com/sdk/docs/install"

if gcloud artifacts repositories describe "${REPO_NAME:-expense}" --location "${REGION}" --project "${PROJECT_ID}" &> /dev/null; then
  gcloud artifacts repositories delete "${REPO_NAME:-expense}" --location "${REGION}" --project "${PROJECT_ID}" --quiet
  echo "Repositorio eliminado."
else
  echo "El repositorio no existe o ya fue eliminado."
fi
