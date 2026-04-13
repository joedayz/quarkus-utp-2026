#!/usr/bin/env bash
# Aprovisiona infra mínima en AWS para la demo Student Management API + ECS Fargate.
# Requisitos: AWS CLI v2 configurado (aws configure), permisos IAM amplios en la cuenta de demo.
#
# Uso:
#   ./deploy/aws-bootstrap.sh                 # Crea infra; si ya existe imagen :latest en ECR, registra task definition y crea el servicio ECS
#   ./deploy/aws-bootstrap.sh --infra-only    # Solo IAM, ECR, log group, cluster, security group y subnets (sin servicio ECS)
#   ./deploy/aws-bootstrap.sh --with-rds      # Además: RDS PostgreSQL (demo, ~10–20 min), SG 5432←ECS, archivo deploy/rds-credentials.env
#   ./deploy/aws-bootstrap.sh --deploy-service # Tras publicar la imagen (p. ej. GitHub Action «Solo ECR»), registra task y crea/verifica el servicio
#
# Variables de entorno opcionales:
#   AWS_REGION, CLUSTER_NAME, SERVICE_NAME, ECR_REPOSITORY, VPC_ID (si no se usa la VPC por defecto)
#   RDS_INSTANCE_IDENTIFIER, RDS_INSTANCE_CLASS (default db.t4g.micro; si falla, prueba db.t3.micro), RDS_MASTER_USERNAME (default student)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TASKDEF_TEMPLATE="${SCRIPT_DIR}/ecs-task-definition.json"

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-student-management-api}"
SERVICE_NAME="${SERVICE_NAME:-student-management-api-svc}"
ECR_NAME="${ECR_REPOSITORY:-student-management-api}"
SG_NAME="student-mgmt-ecs-${CLUSTER_NAME}"

INFRA_ONLY=0
DEPLOY_SERVICE_ONLY=0
WITH_RDS=0
for arg in "$@"; do
  case "$arg" in
    --infra-only) INFRA_ONLY=1 ;;
    --deploy-service) DEPLOY_SERVICE_ONLY=1 ;;
    --with-rds) WITH_RDS=1 ;;
    -h|--help)
      grep '^#' "$0" | grep -v '^#!/' | sed 's/^# //'
      exit 0
      ;;
  esac
done

command -v aws >/dev/null 2>&1 || { echo "Instala AWS CLI v2: https://aws.amazon.com/cli/"; exit 1; }

export AWS_DEFAULT_REGION="${REGION}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_NAME}"

echo "=== Cuenta ${ACCOUNT_ID} | Región ${REGION} ==="

ensure_execution_role() {
  local role_name="ecsTaskExecutionRole"
  if aws iam get-role --role-name "$role_name" &>/dev/null; then
    echo "Rol IAM ya existe: ${role_name}"
    return 0
  fi
  echo "Creando rol ${role_name}..."
  aws iam create-role --role-name "$role_name" \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "ecs-tasks.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }' >/dev/null
  aws iam attach-role-policy --role-name "$role_name" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
  echo "Esperando propagación IAM (~10s)..."
  sleep 10
}

ensure_ecr() {
  if aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$REGION" &>/dev/null; then
    echo "Repositorio ECR ya existe: ${ECR_NAME}"
  else
    echo "Creando repositorio ECR: ${ECR_NAME}"
    aws ecr create-repository --repository-name "$ECR_NAME" --region "$REGION" >/dev/null
  fi
}

ensure_log_group() {
  local lg="/ecs/student-management-api"
  echo "Asegurando log group: ${lg}"
  aws logs create-log-group --log-group-name "$lg" --region "$REGION" 2>/dev/null || echo "(log group ya existía o sin permiso crear; continuar)"
}

ensure_cluster() {
  if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --query 'clusters[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
    echo "Cluster ECS ya existe: ${CLUSTER_NAME}"
  else
    echo "Creando cluster ECS: ${CLUSTER_NAME}"
    aws ecs create-cluster --cluster-name "$CLUSTER_NAME" --region "$REGION" >/dev/null
  fi
}

resolve_vpc_and_subnets() {
  if [[ -n "${VPC_ID:-}" ]]; then
    VPC="$VPC_ID"
  else
    VPC="$(aws ec2 describe-vpcs --filters '[{"Name":"isDefault","Values":["true"]}]' --query 'Vpcs[0].VpcId' --output text)"
    if [[ "$VPC" == "None" || -z "$VPC" ]]; then
      echo "No hay VPC por defecto. Define VPC_ID en el entorno."
      exit 1
    fi
  fi
  echo "VPC: ${VPC}"
  local raw sid az az1 list
  raw="$(aws ec2 describe-subnets --filters "[{\"Name\":\"vpc-id\",\"Values\":[\"${VPC}\"]}]" \
    --query 'Subnets[].[SubnetId,AvailabilityZone]' --output text)"
  SUBNET1=""
  SUBNET2=""
  if [[ "$WITH_RDS" -eq 1 ]]; then
    az1=""
    while read -r sid az; do
      [[ -z "$sid" ]] && continue
      if [[ -z "$SUBNET1" ]]; then
        SUBNET1="$sid"
        az1="$az"
        continue
      fi
      if [[ "$az" != "$az1" ]]; then
        SUBNET2="$sid"
        break
      fi
    done <<< "$raw"
    if [[ -z "$SUBNET1" || -z "$SUBNET2" ]]; then
      echo "Con --with-rds se necesitan al menos 2 subnets en distintas zonas de disponibilidad."
      exit 1
    fi
    echo "Subnets (2 AZ): ${SUBNET1} ${SUBNET2}"
    return
  fi
  list="$(aws ec2 describe-subnets --filters "[{\"Name\":\"vpc-id\",\"Values\":[\"${VPC}\"]}]" \
    --query 'Subnets[*].SubnetId' --output text)"
  SUBNET1="$(echo "$list" | awk '{print $1}')"
  SUBNET2="$(echo "$list" | awk '{print $2}')"
  if [[ -z "$SUBNET1" || -z "$SUBNET2" ]]; then
    echo "Se necesitan al menos 2 subnets en la VPC."
    exit 1
  fi
  echo "Subnets: ${SUBNET1} ${SUBNET2}"
}

ensure_security_group() {
  local existing
  existing="$(aws ec2 describe-security-groups --filters "[{\"Name\":\"vpc-id\",\"Values\":[\"${VPC}\"]},{\"Name\":\"group-name\",\"Values\":[\"${SG_NAME}\"]}]" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
  if [[ -n "$existing" && "$existing" != "None" ]]; then
    SG_ID="$existing"
    echo "Security group ya existe: ${SG_ID} (${SG_NAME})"
  else
    echo "Creando security group: ${SG_NAME}"
    SG_ID="$(aws ec2 create-security-group --group-name "$SG_NAME" --description "ECS Fargate student-mgmt demo" --vpc-id "$VPC" \
      --query 'GroupId' --output text)"
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 8080 --cidr 0.0.0.0/0 >/dev/null
    echo "Ingress 8080 desde 0.0.0.0/0 (solo demo). Restringe en producción."
  fi
  echo "Security group tareas ECS: ${SG_ID}"
}

ensure_rds_stack() {
  local db_subnet_name="student-mgmt-db-${CLUSTER_NAME}"
  local rds_sg_name="student-mgmt-rds-${CLUSTER_NAME}"
  local id="${RDS_INSTANCE_IDENTIFIER:-student-mgmt-pg-${CLUSTER_NAME}}"
  id="$(echo "$id" | tr '[:upper:]' '[:lower:]')"
  local rds_class="${RDS_INSTANCE_CLASS:-db.t4g.micro}"
  local db_user="${RDS_MASTER_USERNAME:-student}"

  if aws rds describe-db-subnet-groups --db-subnet-group-name "$db_subnet_name" &>/dev/null; then
    echo "DB subnet group ya existe: ${db_subnet_name}"
  else
    echo "Creando DB subnet group ${db_subnet_name} (subnets en 2 AZ)..."
    aws rds create-db-subnet-group \
      --db-subnet-group-name "$db_subnet_name" \
      --db-subnet-group-description "student-management-api demo" \
      --subnet-ids "$SUBNET1" "$SUBNET2" >/dev/null
  fi

  local rds_sg_existing
  rds_sg_existing="$(aws ec2 describe-security-groups --filters "[{\"Name\":\"vpc-id\",\"Values\":[\"${VPC}\"]},{\"Name\":\"group-name\",\"Values\":[\"${rds_sg_name}\"]}]" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
  if [[ -n "$rds_sg_existing" && "$rds_sg_existing" != "None" ]]; then
    RDS_SG_ID="$rds_sg_existing"
    echo "Security group RDS ya existe: ${RDS_SG_ID} (${rds_sg_name})"
  else
    echo "Creando security group RDS: ${rds_sg_name}"
    RDS_SG_ID="$(aws ec2 create-security-group --group-name "$rds_sg_name" --description "PostgreSQL student-mgmt demo" --vpc-id "$VPC" \
      --query 'GroupId' --output text)"
    echo "RDS: entrada 5432 desde el security group de tareas ECS (${SG_ID})."
  fi
  aws ec2 authorize-security-group-ingress --group-id "$RDS_SG_ID" --protocol tcp --port 5432 --source-group "$SG_ID" 2>/dev/null \
    || true

  local status
  status="$(aws rds describe-db-instances --db-instance-identifier "$id" --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null || true)"
  if [[ -n "$status" && "$status" != "None" ]]; then
    echo "Instancia RDS ya existe: ${id} (estado: ${status})"
    if [[ "$status" != "available" ]]; then
      echo "Esperando a que RDS esté disponible (puede tardar varios minutos)..."
      aws rds wait db-instance-available --db-instance-identifier "$id"
    fi
    RDS_ENDPOINT="$(aws rds describe-db-instances --db-instance-identifier "$id" --query 'DBInstances[0].Endpoint.Address' --output text)"
    MASTER_PASSWORD=""
    write_rds_credentials_file "$db_user"
    echo "RDS endpoint: ${RDS_ENDPOINT}"
    return 0
  fi

  MASTER_PASSWORD="$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c 24)"
  echo "Creando instancia RDS PostgreSQL ${id} (clase ${rds_class}; genera coste en la cuenta de demo)..."
  aws rds create-db-instance \
    --db-instance-identifier "$id" \
    --db-instance-class "$rds_class" \
    --engine postgres \
    --master-username "$db_user" \
    --master-user-password "$MASTER_PASSWORD" \
    --allocated-storage 20 \
    --db-name studentdb \
    --vpc-security-group-ids "$RDS_SG_ID" \
    --db-subnet-group-name "$db_subnet_name" \
    --backup-retention-period 1 \
    --no-publicly-accessible \
    --no-multi-az \
    --storage-type gp3 >/dev/null

  echo "Esperando a que RDS esté disponible (suele tardar 10–20 minutos)..."
  aws rds wait db-instance-available --db-instance-identifier "$id"
  RDS_ENDPOINT="$(aws rds describe-db-instances --db-instance-identifier "$id" --query 'DBInstances[0].Endpoint.Address' --output text)"
  write_rds_credentials_file "$db_user"
  echo "RDS listo. Endpoint: ${RDS_ENDPOINT}"
}

write_rds_credentials_file() {
  local db_user="${1:-student}"
  local out="${SCRIPT_DIR}/rds-credentials.env"
  local url="jdbc:postgresql://${RDS_ENDPOINT}:5432/studentdb"
  umask 077
  {
    echo "# NO subir a Git (.gitignore). Para GitHub Actions: Variable QUARKUS_DATASOURCE_JDBC_URL y Secret STUDENT_DB_PASSWORD"
    echo "QUARKUS_DATASOURCE_JDBC_URL=${url}"
    echo "QUARKUS_DATASOURCE_USERNAME=${db_user}"
    if [[ -n "${MASTER_PASSWORD:-}" ]]; then
      echo "STUDENT_DB_PASSWORD=${MASTER_PASSWORD}"
    else
      echo "# STUDENT_DB_PASSWORD=  (instancia ya existía; usa tu contraseña o «Modify» en RDS)"
    fi
  } >"$out"
  echo "JDBC local guardado en: ${out}"
}

write_github_snippet() {
  local out="${SCRIPT_DIR}/github-variables-snippet.env"
  cat >"$out" <<EOF
# Copiar como Variables en GitHub → Settings → Secrets and variables → Actions → Variables
ECS_CLUSTER=${CLUSTER_NAME}
ECS_SERVICE=${SERVICE_NAME}
AWS_REGION=${REGION}
ECR_REPOSITORY=${ECR_NAME}
EOF
  if [[ "$WITH_RDS" -eq 1 && -f "${SCRIPT_DIR}/rds-credentials.env" ]]; then
    {
      echo ""
      echo "# Tras --with-rds: copia QUARKUS_DATASOURCE_JDBC_URL y QUARKUS_DATASOURCE_USERNAME desde deploy/rds-credentials.env → Variables de Actions."
      echo "# STUDENT_DB_PASSWORD → Secret de Actions (mismo valor que en rds-credentials.env si acabas de crear la instancia)."
    } >>"$out"
  fi
  echo "Variables sugeridas guardadas en: ${out}"
}

merge_rds_env_into_taskdef() {
  local json_path="$1"
  local creds="${SCRIPT_DIR}/rds-credentials.env"
  local merger="${SCRIPT_DIR}/merge_rds_into_taskdef.py"
  [[ -f "$creds" ]] || return 0
  command -v python3 >/dev/null 2>&1 || {
    echo "(python3 no encontrado; no se fusionan variables RDS en la task definition. Añádelas a mano o instala python3.)"
    return 0
  }
  python3 "$merger" "$json_path" "$creds"
}

ecr_image_exists() {
  aws ecr describe-images --repository-name "$ECR_NAME" --region "$REGION" --image-ids imageTag=latest &>/dev/null
}

register_task_and_create_service() {
  if [[ ! -f "$TASKDEF_TEMPLATE" ]]; then
    echo "No se encuentra ${TASKDEF_TEMPLATE}"
    exit 1
  fi

  local tmp
  tmp="$(mktemp)"
  sed -e "s/__AWS_ACCOUNT_ID__/${ACCOUNT_ID}/g" \
      -e "s/__AWS_REGION__/${REGION}/g" \
      -e "s|\"image\": \"public.ecr.aws/docker/library/busybox:1.36\"|\"image\": \"${ECR_URI}:latest\"|" \
      "$TASKDEF_TEMPLATE" >"$tmp"
  merge_rds_env_into_taskdef "$tmp"

  echo "Registrando task definition family student-management-api..."
  REV_ARN="$(aws ecs register-task-definition --cli-input-json "file://${tmp}" --query 'taskDefinition.taskDefinitionArn' --output text)"
  rm -f "$tmp"
  echo "Revisión registrada: ${REV_ARN}"

  local svc_status
  svc_status="$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$REGION" \
    --query 'services[0].status' --output text 2>/dev/null || echo "MISSING")"

  if [[ "$svc_status" == "ACTIVE" ]]; then
    echo "El servicio ${SERVICE_NAME} ya existe. Las siguientes ejecuciones de GitHub Actions lo actualizarán."
    return 0
  fi

  echo "Creando servicio ECS ${SERVICE_NAME} (desired-count=1, Fargate, IP pública)..."
  aws ecs create-service \
    --cluster "$CLUSTER_NAME" \
    --service-name "$SERVICE_NAME" \
    --task-definition student-management-api \
    --desired-count 1 \
    --launch-type FARGATE \
    --platform-version LATEST \
    --network-configuration "awsvpcConfiguration={subnets=[${SUBNET1},${SUBNET2}],securityGroups=[${SG_ID}],assignPublicIp=ENABLED}" \
    --region "$REGION" >/dev/null

  echo "Servicio creado. Obtén la IP pública de la tarea con la consola ECS o:"
  echo "  aws ecs list-tasks --cluster ${CLUSTER_NAME} --service-name ${SERVICE_NAME}"
  echo "  aws ecs describe-tasks --cluster ${CLUSTER_NAME} --tasks <task-arn>"
}

# --- flujo principal ---

if [[ "$DEPLOY_SERVICE_ONLY" -eq 1 ]]; then
  if [[ "$WITH_RDS" -eq 1 ]]; then
    echo "Usa --with-rds junto a --infra-only o al flujo completo, no con --deploy-service."
    exit 1
  fi
  resolve_vpc_and_subnets
  ensure_security_group
  if ! ecr_image_exists; then
    echo "No hay imagen ${ECR_NAME}:latest en ECR. Ejecuta primero GitHub Actions con «Solo ECR» o publica la imagen."
    exit 1
  fi
  register_task_and_create_service
  exit 0
fi

ensure_execution_role
ensure_ecr
ensure_log_group
ensure_cluster
resolve_vpc_and_subnets
ensure_security_group
if [[ "$WITH_RDS" -eq 1 ]]; then
  echo ""
  echo ">>> --with-rds: se creará RDS PostgreSQL (coste y espera). Asegúrate de permisos rds:* y ec2:* en esta cuenta."
  echo ""
  ensure_rds_stack
fi
write_github_snippet

echo ""
if [[ "$WITH_RDS" -eq 1 ]]; then
  echo ">>> JDBC está en deploy/rds-credentials.env. Para GitHub: Variables QUARKUS_DATASOURCE_JDBC_URL + QUARKUS_DATASOURCE_USERNAME"
  echo "    y Secret STUDENT_DB_PASSWORD (ver github-variables-snippet.env). Opcional: commit sin contraseña y solo variables en GitHub."
else
  echo ">>> Añade en deploy/ecs-task-definition.json (y commit) las variables QUARKUS_DATASOURCE_* para RDS,"
  echo "    o usa --with-rds y luego variables/secret en GitHub (ver README)."
fi
echo "    Sin JDBC válido el health check fallará."
echo ""

if [[ "$INFRA_ONLY" -eq 1 ]]; then
  echo "Modo --infra-only: no se crea el servicio ECS."
  echo "Siguientes pasos:"
  if [[ "$WITH_RDS" -ne 1 ]]; then
    echo "  1. Configura JDBC en ecs-task-definition.json y RDS SG para permitir ${SG_ID}:5432"
  else
    echo "  1. Copia JDBC desde rds-credentials.env a GitHub (Variables + Secret) o fusiona en task definition (sin subir secretos)"
  fi
  echo "  2. En GitHub: Secrets AWS + Variables (ver github-variables-snippet.env)"
  echo "  3. Ejecuta el workflow con «Solo ECR» para subir la imagen"
  echo "  4. ./deploy/aws-bootstrap.sh --deploy-service"
  exit 0
fi

if ecr_image_exists; then
  register_task_and_create_service
else
  echo "No hay imagen :latest en ECR todavía."
  echo "Siguientes pasos:"
  echo "  1. Configura GitHub (Secrets + Variables desde github-variables-snippet.env)"
  echo "  2. Completa JDBC en ecs-task-definition.json y abre el SG de RDS al grupo ${SG_ID}"
  echo "  3. Ejecuta GitHub Actions con «Solo ECR»"
  echo "  4. Ejecuta de nuevo: ./deploy/aws-bootstrap.sh --deploy-service"
fi

exit 0
