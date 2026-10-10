#!/usr/bin/env bash
set -euo pipefail

# Elimina la aplicación del cluster.
# Uso: ./undeploy-all.sh [--delete-all]
#   --delete-all: también elimina el cluster GKE (el registro se borra con ../../scripts/delete-registry.sh)

source "$(dirname "$0")/../../scripts/lib.sh"
load_config
[ -f "${GCP_DIR}/gke/gke-config.env" ] && . "${GCP_DIR}/gke/gke-config.env"

if kubectl cluster-info &> /dev/null; then
  render_manifest | kubectl delete -f - --ignore-not-found=true
  echo "Recursos de Kubernetes eliminados."
else
  echo "Sin conexión al cluster; se omite la eliminación de recursos K8s."
fi

if [ "${1:-}" = "--delete-all" ]; then
  if [ -z "${CLUSTER_NAME:-}" ]; then
    echo "Error: no se encontró gke-config.env; elimina el cluster manualmente."
    exit 1
  fi
  echo "Eliminando cluster ${CLUSTER_NAME}..."
  gcloud container clusters delete "${CLUSTER_NAME}" "${LOCATION_FLAG}" "${LOCATION}" --project "${PROJECT_ID}" --quiet
  rm -f "${GCP_DIR}/gke/gke-config.env"
  echo "Cluster eliminado."
else
  echo "El cluster NO se eliminó (sigue generando costo). Usa: ./scripts/undeploy-all.sh --delete-all"
fi
