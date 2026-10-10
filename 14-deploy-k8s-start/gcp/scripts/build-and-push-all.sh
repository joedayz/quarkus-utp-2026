#!/usr/bin/env bash
set -euo pipefail

# Compila con Maven, construye imágenes linux/amd64 y las sube a Artifact Registry.
# Requiere: gcp-setup.sh ejecutado previamente.

source "$(dirname "$0")/lib.sh"
load_config
require_cmd gcloud "Instala desde: https://cloud.google.com/sdk/docs/install"
require_cmd mvn "Instala Maven."
detect_container_cmd

echo "=== Build and Push a Artifact Registry ==="
echo "Registro: ${IMAGE_REGISTRY}  (${CONTAINER_CMD})"

gcloud auth print-access-token | "${CONTAINER_CMD}" login -u oauth2accesstoken --password-stdin "${REGION}-docker.pkg.dev"

build_and_push() {
  local name="$1"
  local image_tag="${IMAGE_REGISTRY}/${name}:latest"

  echo "=== Building ${name} ==="
  (cd "${ROOT_DIR}/${name}" && mvn -q package)

  if [ "${CONTAINER_CMD}" = "docker" ] && docker buildx version &> /dev/null; then
    (cd "${ROOT_DIR}/${name}" && docker buildx build --platform linux/amd64 -f src/main/docker/Dockerfile.jvm -t "${image_tag}" --load .)
  else
    (cd "${ROOT_DIR}/${name}" && "${CONTAINER_CMD}" build --platform linux/amd64 -f src/main/docker/Dockerfile.jvm -t "${image_tag}" .)
  fi

  "${CONTAINER_CMD}" push "${image_tag}"
  echo ""
}

build_and_push expense-service
build_and_push expense-client

echo "=== Imágenes subidas a ${IMAGE_REGISTRY} ==="
