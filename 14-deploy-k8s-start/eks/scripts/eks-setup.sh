#!/bin/sh
set -euo pipefail

# Script para configurar AWS: crear repositorios ECR y cluster EKS
# Uso: ./eks-setup.sh [CLUSTER_NAME] [AWS_REGION]

CLUSTER_NAME="${1:-expense-eks}"
AWS_REGION="${2:-us-east-1}"

echo "=== AWS EKS Setup ==="
echo "Cluster: ${CLUSTER_NAME}"
echo "Region:  ${AWS_REGION}"
echo ""

# Verificar que AWS CLI está instalado
if ! command -v aws &> /dev/null; then
  echo "Error: AWS CLI no está instalado."
  echo "Instala desde: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  exit 1
fi

# Verificar que eksctl está instalado
if ! command -v eksctl &> /dev/null; then
  echo "Error: eksctl no está instalado."
  echo "Instala desde: https://eksctl.io/installation/"
  exit 1
fi

# Verificar que kubectl está instalado
if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl no está instalado."
  echo "Instala desde: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi

# Verificar credenciales de AWS
echo "=== Verificando credenciales de AWS ==="
if ! aws sts get-caller-identity &> /dev/null; then
  echo "Error: No estás autenticado en AWS."
  echo "Ejecuta: aws configure"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: ${AWS_ACCOUNT_ID}"
echo "Region:     ${AWS_REGION}"
echo ""

# Crear repositorios ECR si no existen
echo "=== Creando repositorios ECR ==="
for REPO in expense-service expense-client; do
  if aws ecr describe-repositories --repository-names "${REPO}" --region "${AWS_REGION}" &> /dev/null; then
    echo "Repositorio ECR '${REPO}' ya existe."
  else
    echo "Creando repositorio ECR '${REPO}'..."
    aws ecr create-repository \
      --repository-name "${REPO}" \
      --region "${AWS_REGION}" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256
  fi
done
echo ""

# Crear cluster EKS si no existe
echo "=== Creando cluster EKS ==="
if eksctl get cluster --name "${CLUSTER_NAME}" --region "${AWS_REGION}" &> /dev/null; then
  echo "Cluster EKS '${CLUSTER_NAME}' ya existe."
else
  echo "Creando cluster EKS '${CLUSTER_NAME}'..."
  echo "Esto puede tardar 15-20 minutos..."
  eksctl create cluster \
    --name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --nodegroup-name expense-nodes \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 1 \
    --nodes-max 3 \
    --managed
fi
echo ""

# Actualizar kubeconfig
echo "=== Configurando kubectl ==="
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
echo ""

# Verificar conexión
echo "=== Verificando conexión con EKS ==="
kubectl cluster-info
kubectl get nodes
echo ""

# Guardar configuración
CONFIG_FILE="$(cd "$(dirname "$0")/.." && pwd)/eks-config.env"
cat > "${CONFIG_FILE}" <<EOF
export CLUSTER_NAME="${CLUSTER_NAME}"
export AWS_REGION="${AWS_REGION}"
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
EOF

echo "=== Configuración completada ==="
echo "Configuración guardada en: ${CONFIG_FILE}"
echo ""
echo "Variables de entorno:"
echo "  CLUSTER_NAME=${CLUSTER_NAME}"
echo "  AWS_REGION=${AWS_REGION}"
echo "  AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
echo "  ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo ""
echo "Para usar estas variables en otros scripts, ejecuta:"
echo "  source ${CONFIG_FILE}"
