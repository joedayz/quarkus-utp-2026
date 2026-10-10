#!/usr/bin/env bash
set -euo pipefail

# Prepara el proyecto GCP: habilita APIs y crea el repositorio de Artifact Registry.
# Uso: ./gcp-setup.sh [PROJECT_ID] [REGION]

source "$(dirname "$0")/lib.sh"

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${2:-us-central1}"
REPO_NAME="expense"

require_cmd gcloud "Instala desde: https://cloud.google.com/sdk/docs/install"

if [ -z "${PROJECT_ID}" ]; then
  echo "Error: indica el proyecto: ./gcp-setup.sh <PROJECT_ID> [REGION]"
  echo "O configúralo con: gcloud config set project <PROJECT_ID>"
  exit 1
fi

echo "=== GCP Setup ==="
echo "Proyecto: ${PROJECT_ID}"
echo "Región:   ${REGION}"
echo ""

ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format='value(account)')
if [ -z "${ACCOUNT}" ]; then
  echo "Error: no hay sesión activa. Ejecuta: gcloud auth login"
  exit 1
fi
echo "Cuenta activa: ${ACCOUNT}"

if [ "$(gcloud billing projects describe "${PROJECT_ID}" --format='value(billingEnabled)')" != "True" ]; then
  echo "Error: el proyecto ${PROJECT_ID} no tiene facturación habilitada."
  echo "Vincula una cuenta de facturación en la consola de Billing."
  exit 1
fi

echo "=== Habilitando APIs ==="
gcloud services enable \
  artifactregistry.googleapis.com \
  container.googleapis.com \
  run.googleapis.com \
  compute.googleapis.com \
  --project "${PROJECT_ID}"

echo "=== Artifact Registry ==="
if gcloud artifacts repositories describe "${REPO_NAME}" --location "${REGION}" --project "${PROJECT_ID}" &> /dev/null; then
  echo "Repositorio '${REPO_NAME}' ya existe."
else
  gcloud artifacts repositories create "${REPO_NAME}" \
    --repository-format=docker \
    --location "${REGION}" \
    --description="Imágenes de expense-service y expense-client" \
    --project "${PROJECT_ID}"
fi

gcloud config set project "${PROJECT_ID}" &> /dev/null
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

IMAGE_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"
cat > "${CONFIG_FILE}" <<EOT
export PROJECT_ID="${PROJECT_ID}"
export REGION="${REGION}"
export REPO_NAME="${REPO_NAME}"
export IMAGE_REGISTRY="${IMAGE_REGISTRY}"
EOT

echo ""
echo "=== Configuración completada ==="
echo "Configuración guardada en: ${CONFIG_FILE}"
echo "IMAGE_REGISTRY=${IMAGE_REGISTRY}"
