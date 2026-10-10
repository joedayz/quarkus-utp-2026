#!/usr/bin/env bash
set -euo pipefail

# Despliega expense-service y expense-client en el cluster GKE activo.
# Requiere: gke-setup.sh y ../../scripts/build-and-push-all.sh ejecutados.

source "$(dirname "$0")/../../scripts/lib.sh"
load_config
require_cmd kubectl "Instala desde: https://kubernetes.io/docs/tasks/tools/"

if ! kubectl cluster-info &> /dev/null; then
  echo "Error: no hay conexión con el cluster. Ejecuta: ./scripts/gke-setup.sh"
  exit 1
fi

echo "=== Deploying to GKE ==="
echo "Contexto: $(kubectl config current-context)"
echo "Registro: ${IMAGE_REGISTRY}"

render_manifest | kubectl apply -f -

echo "Esperando a los deployments (en Autopilot puede tardar más mientras se aprovisionan nodos)..."
for d in expense-service expense-client; do
  if ! kubectl rollout status "deployment/${d}" --timeout=10m; then
    echo "*** ${d} no quedó listo. Ejecuta: ./scripts/diagnose.sh"
    exit 1
  fi
done

echo ""
kubectl get pods
kubectl get svc expense-service expense-client

echo ""
echo "Esperando IP del LoadBalancer..."
for _ in $(seq 1 30); do
  IP=$(kubectl get svc expense-client -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -n "${IP}" ] && break
  sleep 10
done

if [ -n "${IP:-}" ]; then
  echo "✓ Client disponible en: http://${IP}:8080/expenses"
else
  echo "La IP aún no está asignada. Revisa: kubectl get svc expense-client"
  echo "O usa: kubectl port-forward svc/expense-client 8081:8080"
fi
