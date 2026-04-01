#!/bin/sh
set -euo pipefail

# Script para configurar AWS: crear repositorios ECR, cluster ECS, VPC, y roles IAM
# Uso: ./ecs-setup.sh [CLUSTER_NAME] [AWS_REGION]

CLUSTER_NAME="${1:-expense-ecs}"
AWS_REGION="${2:-us-east-1}"

echo "=== AWS ECS Setup ==="
echo "Cluster: ${CLUSTER_NAME}"
echo "Region:  ${AWS_REGION}"
echo ""

# Verificar que AWS CLI está instalado
if ! command -v aws &> /dev/null; then
  echo "Error: AWS CLI no está instalado."
  echo "Instala desde: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
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

# Crear rol de ejecución de ECS si no existe
echo "=== Creando rol IAM para ECS ==="
ECS_EXECUTION_ROLE="ecsTaskExecutionRole"
if aws iam get-role --role-name "${ECS_EXECUTION_ROLE}" &> /dev/null; then
  echo "Rol '${ECS_EXECUTION_ROLE}' ya existe."
else
  echo "Creando rol '${ECS_EXECUTION_ROLE}'..."
  aws iam create-role \
    --role-name "${ECS_EXECUTION_ROLE}" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ecs-tasks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }'
  aws iam attach-role-policy \
    --role-name "${ECS_EXECUTION_ROLE}" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
fi
EXECUTION_ROLE_ARN=$(aws iam get-role --role-name "${ECS_EXECUTION_ROLE}" --query 'Role.Arn' --output text)
echo "Execution Role ARN: ${EXECUTION_ROLE_ARN}"
echo ""

# Obtener VPC default y subnets
echo "=== Obteniendo VPC y Subnets ==="
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --region "${AWS_REGION}" --query 'Vpcs[0].VpcId' --output text)
if [ "${DEFAULT_VPC_ID}" = "None" ] || [ -z "${DEFAULT_VPC_ID}" ]; then
  echo "Error: No se encontró una VPC default en la región ${AWS_REGION}."
  echo "Crea una VPC o especifica una existente."
  exit 1
fi
echo "VPC: ${DEFAULT_VPC_ID}"

SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=${DEFAULT_VPC_ID}" \
  --region "${AWS_REGION}" \
  --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')
echo "Subnets: ${SUBNET_IDS}"
echo ""

# Crear Security Group para ECS
echo "=== Creando Security Group ==="
SG_NAME="expense-ecs-sg"
EXISTING_SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=${SG_NAME}" "Name=vpc-id,Values=${DEFAULT_VPC_ID}" \
  --region "${AWS_REGION}" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")

if [ "${EXISTING_SG}" != "None" ] && [ -n "${EXISTING_SG}" ]; then
  SG_ID="${EXISTING_SG}"
  echo "Security Group '${SG_NAME}' ya existe: ${SG_ID}"
else
  echo "Creando Security Group '${SG_NAME}'..."
  SG_ID=$(aws ec2 create-security-group \
    --group-name "${SG_NAME}" \
    --description "Security group for ECS expense services" \
    --vpc-id "${DEFAULT_VPC_ID}" \
    --region "${AWS_REGION}" \
    --query 'GroupId' --output text)

  # Permitir tráfico HTTP en puerto 8080
  aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp --port 8080 --cidr 0.0.0.0/0 \
    --region "${AWS_REGION}"

  # Permitir tráfico interno entre tareas del SG
  aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp --port 0-65535 --source-group "${SG_ID}" \
    --region "${AWS_REGION}"
fi
echo "Security Group: ${SG_ID}"
echo ""

# Crear cluster ECS si no existe
echo "=== Creando cluster ECS ==="
if aws ecs describe-clusters --clusters "${CLUSTER_NAME}" --region "${AWS_REGION}" \
   --query 'clusters[?status==`ACTIVE`].clusterName' --output text | grep -q "${CLUSTER_NAME}"; then
  echo "Cluster ECS '${CLUSTER_NAME}' ya existe."
else
  echo "Creando cluster ECS '${CLUSTER_NAME}'..."
  aws ecs create-cluster \
    --cluster-name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --capacity-providers FARGATE \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
fi
echo ""

# Crear namespace de Cloud Map para service discovery
echo "=== Configurando Service Discovery (Cloud Map) ==="
NAMESPACE_NAME="expense.local"
EXISTING_NS=$(aws servicediscovery list-namespaces \
  --filters "Name=TYPE,Values=DNS_PRIVATE" \
  --region "${AWS_REGION}" \
  --query "Namespaces[?Name=='${NAMESPACE_NAME}'].Id" --output text 2>/dev/null || echo "")

if [ -n "${EXISTING_NS}" ] && [ "${EXISTING_NS}" != "None" ]; then
  NAMESPACE_ID="${EXISTING_NS}"
  echo "Namespace '${NAMESPACE_NAME}' ya existe: ${NAMESPACE_ID}"
else
  echo "Creando namespace '${NAMESPACE_NAME}'..."
  OPERATION_ID=$(aws servicediscovery create-private-dns-namespace \
    --name "${NAMESPACE_NAME}" \
    --vpc "${DEFAULT_VPC_ID}" \
    --region "${AWS_REGION}" \
    --query 'OperationId' --output text)

  echo "Esperando a que el namespace se cree..."
  for i in $(seq 1 30); do
    NS_STATUS=$(aws servicediscovery get-operation \
      --operation-id "${OPERATION_ID}" \
      --region "${AWS_REGION}" \
      --query 'Operation.Status' --output text 2>/dev/null || echo "PENDING")
    if [ "${NS_STATUS}" = "SUCCESS" ]; then
      break
    fi
    sleep 2
  done

  NAMESPACE_ID=$(aws servicediscovery get-operation \
    --operation-id "${OPERATION_ID}" \
    --region "${AWS_REGION}" \
    --query 'Operation.Targets.NAMESPACE' --output text)
fi
echo "Namespace ID: ${NAMESPACE_ID}"
echo ""

# Crear CloudWatch Log Group
echo "=== Creando Log Group ==="
LOG_GROUP="/ecs/${CLUSTER_NAME}"
aws logs create-log-group --log-group-name "${LOG_GROUP}" --region "${AWS_REGION}" 2>/dev/null || echo "Log Group '${LOG_GROUP}' ya existe."
echo "Log Group: ${LOG_GROUP}"
echo ""

# Guardar configuración
CONFIG_FILE="$(cd "$(dirname "$0")/.." && pwd)/ecs-config.env"
cat > "${CONFIG_FILE}" <<EOF
export CLUSTER_NAME="${CLUSTER_NAME}"
export AWS_REGION="${AWS_REGION}"
export AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
export EXECUTION_ROLE_ARN="${EXECUTION_ROLE_ARN}"
export DEFAULT_VPC_ID="${DEFAULT_VPC_ID}"
export SUBNET_IDS="${SUBNET_IDS}"
export SG_ID="${SG_ID}"
export NAMESPACE_ID="${NAMESPACE_ID}"
export LOG_GROUP="${LOG_GROUP}"
EOF

echo "=== Configuración completada ==="
echo "Configuración guardada en: ${CONFIG_FILE}"
echo ""
echo "Variables de entorno:"
echo "  CLUSTER_NAME=${CLUSTER_NAME}"
echo "  AWS_REGION=${AWS_REGION}"
echo "  AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
echo "  ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "  EXECUTION_ROLE_ARN=${EXECUTION_ROLE_ARN}"
echo "  VPC=${DEFAULT_VPC_ID}"
echo "  SUBNETS=${SUBNET_IDS}"
echo "  SG=${SG_ID}"
echo "  NAMESPACE_ID=${NAMESPACE_ID}"
echo ""
echo "Para usar estas variables en otros scripts, ejecuta:"
echo "  source ${CONFIG_FILE}"
