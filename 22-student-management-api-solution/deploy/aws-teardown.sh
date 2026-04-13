#!/usr/bin/env bash
# Borra la demo Student Management API en AWS (ECS, ECR, RDS, SGs, log group, task definitions).
# Destructivo: RDS sin snapshot final. Requiere AWS CLI v2 y permisos amplios.
#
# Windows (PowerShell): deploy\aws-teardown.ps1 con los mismos flags (-Yes, -IamToo, -CleanLocal).
#
# Uso (desde la carpeta 22-student-management-api-solution):
#   ./deploy/aws-teardown.sh              # Muestra qué se borrará y sale (modo seguro)
#   ./deploy/aws-teardown.sh --yes        # Ejecuta el borrado
#   ./deploy/aws-teardown.sh --yes --iam-too   # Además intenta borrar el rol ecsTaskExecutionRole (¡cuidado si lo usan otros proyectos!)
#   ./deploy/aws-teardown.sh --yes --clean-local  # También borra deploy/rds-credentials.env y deploy/github-variables-snippet.env si existen
#
# Variables de entorno (mismas que aws-bootstrap.sh):
#   AWS_REGION, CLUSTER_NAME, SERVICE_NAME, ECR_REPOSITORY, VPC_ID (opcional),
#   RDS_INSTANCE_IDENTIFIER (default student-mgmt-pg-${CLUSTER_NAME} en minúsculas)
#
# Task definition family fija del lab: student-management-api

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-student-management-api}"
SERVICE_NAME="${SERVICE_NAME:-student-management-api-svc}"
ECR_NAME="${ECR_REPOSITORY:-student-management-api}"
SG_NAME="student-mgmt-ecs-${CLUSTER_NAME}"
TASKDEF_FAMILY="student-management-api"

YES=0
IAM_TOO=0
CLEAN_LOCAL=0
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    --iam-too) IAM_TOO=1 ;;
    --clean-local) CLEAN_LOCAL=1 ;;
    -h|--help)
      grep '^#' "$0" | grep -v '^#!/' | sed 's/^# //'
      exit 0
      ;;
  esac
done

command -v aws >/dev/null 2>&1 || { echo "Instala AWS CLI v2: https://aws.amazon.com/cli/"; exit 1; }

export AWS_DEFAULT_REGION="${REGION}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
RDS_ID="${RDS_INSTANCE_IDENTIFIER:-student-mgmt-pg-${CLUSTER_NAME}}"
RDS_ID="$(echo "$RDS_ID" | tr '[:upper:]' '[:lower:]')"
DB_SUBNET_GROUP="student-mgmt-db-${CLUSTER_NAME}"
RDS_SG_NAME="student-mgmt-rds-${CLUSTER_NAME}"

echo "=== Teardown demo | Cuenta ${ACCOUNT_ID} | Región ${REGION} ==="
echo "Cluster ECS:     ${CLUSTER_NAME}"
echo "Servicio ECS:    ${SERVICE_NAME}"
echo "ECR:             ${ECR_NAME}"
echo "RDS instance:    ${RDS_ID}"
echo "Log group:       /ecs/student-management-api"
echo "Task def family: ${TASKDEF_FAMILY}"
echo "Security groups: ${SG_NAME}, ${RDS_SG_NAME}"
echo ""

if [[ "$YES" -ne 1 ]]; then
  echo "Este script ELIMINA recursos y datos de demo (RDS sin snapshot final)."
  echo "Para ejecutar de verdad:  ./deploy/aws-teardown.sh --yes"
  echo "Opciones: --iam-too (borra rol ecsTaskExecutionRole), --clean-local (borra *.env generados en deploy/)"
  exit 1
fi

read -r -p "Escribe YES en mayúsculas para continuar: " confirm
[[ "$confirm" == "YES" ]] || { echo "Cancelado."; exit 1; }

resolve_vpc() {
  if [[ -n "${VPC_ID:-}" ]]; then
    VPC="$VPC_ID"
  else
    VPC="$(aws ec2 describe-vpcs --filters '[{"Name":"isDefault","Values":["true"]}]' --query 'Vpcs[0].VpcId' --output text)"
    if [[ "$VPC" == "None" || -z "$VPC" ]]; then
      echo "No hay VPC por defecto; define VPC_ID para localizar security groups."
      VPC=""
    fi
  fi
}

sg_id_by_name() {
  local name="$1"
  [[ -n "$VPC" ]] || return 1
  aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=${VPC}" "Name=group-name,Values=${name}" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true
}

wait_no_enis_for_sg() {
  local sg="$1"
  [[ -n "$sg" && "$sg" != "None" ]] || return 0
  local n i
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    n="$(aws ec2 describe-network-interfaces --filters "Name=group-id,Values=${sg}" --query 'length(NetworkInterfaces)' --output text 2>/dev/null || echo 99)"
    if [[ "$n" == "0" ]]; then
      return 0
    fi
    echo "  Esperando ENIs en ${sg} (${n})… (${i}/12, ~15s)"
    sleep 15
  done
  echo "::warning::Siguen existiendo ENIs en ${sg}; el borrado del SG puede fallar. Revisa consola EC2/ECS."
}

echo ">>> 1/8 ECS: bajar servicio y eliminarlo"
if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query 'services[0].status' --output text 2>/dev/null | grep -qE '^(ACTIVE|DRAINING)$'; then
  aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count 0 --region "$REGION" >/dev/null 2>&1 || true
  echo "  delete-service --force…"
  aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --force --region "$REGION" >/dev/null
  echo "  Esperando a que el servicio desaparezca…"
  aws ecs wait services-inactive --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$REGION" 2>/dev/null || sleep 30
else
  echo "  (servicio no existe o ya borrado)"
fi

echo ">>> 2/8 ECS: eliminar cluster"
if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --query 'clusters[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
  aws ecs delete-cluster --cluster "$CLUSTER_NAME" --region "$REGION" >/dev/null
  echo "  Cluster ${CLUSTER_NAME} eliminado."
else
  echo "  (cluster no existe)"
fi

echo ">>> 3/8 ECS: desregistrar revisiones de task definition ${TASKDEF_FAMILY}"
while read -r arn; do
  [[ -z "$arn" || "$arn" == "None" ]] && continue
  echo "  deregister ${arn}"
  aws ecs deregister-task-definition --task-definition "$arn" --region "$REGION" >/dev/null
done < <(aws ecs list-task-definitions --family-prefix "$TASKDEF_FAMILY" --region "$REGION" --query 'taskDefinitionArns[]' --output text 2>/dev/null | tr '\t' '\n' || true)

echo ">>> 4/8 ECR: eliminar repositorio (todas las imágenes)"
if aws ecr describe-repositories --repository-names "$ECR_NAME" --region "$REGION" &>/dev/null; then
  aws ecr delete-repository --repository-name "$ECR_NAME" --force --region "$REGION" >/dev/null
  echo "  ECR ${ECR_NAME} eliminado."
else
  echo "  (repositorio ECR no existe)"
fi

echo ">>> 5/8 RDS: eliminar instancia (sin snapshot final)"
if aws rds describe-db-instances --db-instance-identifier "$RDS_ID" &>/dev/null; then
  aws rds delete-db-instance \
    --db-instance-identifier "$RDS_ID" \
    --skip-final-snapshot \
    --delete-automated-backups \
    >/dev/null
  echo "  Esperando a que RDS ${RDS_ID} desaparezca (puede tardar varios minutos)…"
  aws rds wait db-instance-deleted --db-instance-identifier "$RDS_ID" 2>/dev/null || true
else
  echo "  (instancia RDS no existe)"
fi

echo ">>> 6/8 RDS: eliminar DB subnet group"
if aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET_GROUP" &>/dev/null; then
  aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP" >/dev/null
  echo "  ${DB_SUBNET_GROUP} eliminado."
else
  echo "  (DB subnet group no existe)"
fi

resolve_vpc
ECS_SG="$(sg_id_by_name "$SG_NAME")"
RDS_SG="$(sg_id_by_name "$RDS_SG_NAME")"

echo ">>> 7/8 EC2: security groups (VPC=${VPC:-?})"
if [[ -n "$RDS_SG" && "$RDS_SG" != "None" ]]; then
  wait_no_enis_for_sg "$RDS_SG"
  aws ec2 delete-security-group --group-id "$RDS_SG" 2>/dev/null && echo "  Eliminado ${RDS_SG} (${RDS_SG_NAME})" || echo "  No se pudo borrar ${RDS_SG} (revisa dependencias en consola)"
else
  echo "  (SG RDS no encontrado)"
fi

if [[ -n "$ECS_SG" && "$ECS_SG" != "None" ]]; then
  wait_no_enis_for_sg "$ECS_SG"
  aws ec2 delete-security-group --group-id "$ECS_SG" 2>/dev/null && echo "  Eliminado ${ECS_SG} (${SG_NAME})" || echo "  No se pudo borrar ${ECS_SG} (revisa dependencias en consola)"
else
  echo "  (SG ECS no encontrado)"
fi

echo ">>> 8/8 Logs: log group /ecs/student-management-api"
aws logs delete-log-group --log-group-name "/ecs/student-management-api" --region "$REGION" 2>/dev/null && echo "  Log group eliminado." || echo "  (log group no existe o sin permiso)"

if [[ "$IAM_TOO" -eq 1 ]]; then
  echo ">>> IAM (--iam-too): rol ecsTaskExecutionRole"
  role="ecsTaskExecutionRole"
  if aws iam get-role --role-name "$role" &>/dev/null; then
    aws iam detach-role-policy --role-name "$role" --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true
    aws iam delete-role --role-name "$role" 2>/dev/null && echo "  Rol ${role} eliminado." || echo "  No se pudo borrar el rol (puede tener políticas adjuntas extra)."
  else
    echo "  (rol no existe)"
  fi
else
  echo ">>> IAM: no se toca ecsTaskExecutionRole (usa --iam-too si quieres borrarlo)."
fi

if [[ "$CLEAN_LOCAL" -eq 1 ]]; then
  echo ">>> Local (--clean-local)"
  rm -f "${SCRIPT_DIR}/rds-credentials.env" "${SCRIPT_DIR}/github-variables-snippet.env"
  echo "  Eliminados rds-credentials.env / github-variables-snippet.env si existían."
fi

echo ""
echo "=== Teardown terminado ==="
echo "Revisa la consola AWS por si quedan ENIs, snapshots manuales u otros recursos con prefijo student-mgmt / student-management."
