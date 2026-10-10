#!/usr/bin/env bash
# Funciones compartidas por los scripts de GCP (se usa con: source lib.sh)

GCP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DIR="$(cd "${GCP_DIR}/.." && pwd)"
CONFIG_FILE="${GCP_DIR}/gcp-config.env"

require_cmd() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: '$1' no está instalado. $2"
    exit 1
  fi
}

load_config() {
  if [ -f "${CONFIG_FILE}" ]; then
    . "${CONFIG_FILE}"
  fi
  if [ -z "${PROJECT_ID:-}" ] || [ -z "${REGION:-}" ] || [ -z "${IMAGE_REGISTRY:-}" ]; then
    echo "Error: faltan PROJECT_ID, REGION o IMAGE_REGISTRY."
    echo "Ejecuta primero: ${GCP_DIR}/scripts/gcp-setup.sh"
    exit 1
  fi
}

detect_container_cmd() {
  if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
  elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
  else
    echo "Error: no se encontró ni podman ni docker."
    exit 1
  fi
}

# Sustituye ${IMAGE_REGISTRY} en el manifiesto y escribe el resultado en stdout
render_manifest() {
  sed -e "s|\${IMAGE_REGISTRY}|${IMAGE_REGISTRY}|g" "${GCP_DIR}/k8s/expenses-all.yaml"
}
