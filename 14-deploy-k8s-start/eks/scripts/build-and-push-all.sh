#!/bin/sh
set -euo pipefail

# Script para construir y subir imágenes a Amazon ECR
# Requiere: eks-setup.sh ejecutado previamente o variables de entorno configuradas

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIG_FILE="$(cd "$(dirname "$0")/.." && pwd)/eks-config.env"

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

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=== Build and Push to ECR ==="
echo "ECR: ${ECR_REGISTRY}"
echo ""

# Verificar que AWS CLI está instalado y autenticado
if ! command -v aws &> /dev/null; then
  echo "Error: AWS CLI no está instalado."
  exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
  echo "Error: No estás autenticado en AWS."
  echo "Ejecuta: aws configure"
  exit 1
fi

# Detectar si usar podman o docker
CONTAINER_CMD=""
if command -v podman &> /dev/null; then
  CONTAINER_CMD="podman"
  echo "Detectado: Podman"
elif command -v docker &> /dev/null; then
  CONTAINER_CMD="docker"
  echo "Detectado: Docker"
else
  echo "Error: No se encontró ni podman ni docker instalado."
  exit 1
fi

# Login a ECR
echo "=== Login a ECR ==="
ECR_PASSWORD=$(aws ecr get-login-password --region "${AWS_REGION}")
echo "${ECR_PASSWORD}" | "${CONTAINER_CMD}" login --username AWS --password-stdin "${ECR_REGISTRY}"
echo "Login exitoso."
echo ""

build_and_push() {
  local dir="$1"
  local name="$2"
  local dockerfile="$3"

  echo "=== Building ${name} in ${dir} ==="
  cd "${ROOT_DIR}/${dir}"
  
  # Construir con Maven
  mvn -q package
  
  # Construir imagen para arquitectura AMD64 (requerida por EKS con nodos x86)
  local image_tag="${ECR_REGISTRY}/${name}:latest"
  
  if [ "${CONTAINER_CMD}" = "podman" ]; then
    echo "Construyendo imagen para plataforma linux/amd64..."
    "${CONTAINER_CMD}" build --platform linux/amd64 -f "${dockerfile}" -t "${image_tag}" .
  elif [ "${CONTAINER_CMD}" = "docker" ]; then
    if docker buildx version &> /dev/null; then
      echo "Usando buildx para construir imagen multi-arch (linux/amd64)..."
      docker buildx build --platform linux/amd64 -f "${dockerfile}" -t "${image_tag}" --load .
    else
      echo "Construyendo imagen para plataforma linux/amd64..."
      docker build --platform linux/amd64 -f "${dockerfile}" -t "${image_tag}" .
    fi
  fi
  
  echo "=== Pushing ${image_tag} to ECR ==="
  "${CONTAINER_CMD}" push "${image_tag}"
  
  echo "Imagen ${image_tag} construida y subida exitosamente."
  echo ""
}

build_and_push expense-service expense-service src/main/docker/Dockerfile.jvm
build_and_push expense-client expense-client src/main/docker/Dockerfile.jvm

echo "=== Todas las imágenes construidas y subidas a ECR ==="
echo "ECR: ${ECR_REGISTRY}"
