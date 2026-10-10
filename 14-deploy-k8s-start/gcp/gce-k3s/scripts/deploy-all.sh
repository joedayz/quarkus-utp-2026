#!/usr/bin/env bash
set -euo pipefail

# Despliega la aplicación en K3s sobre Compute Engine.
# Las imágenes se transfieren por SSH (docker/podman save -> ctr import), sin credenciales de registro
# en la VM. Requiere haber ejecutado ../../scripts/build-and-push-all.sh (deja las imágenes en local).

source "$(dirname "$0")/../../scripts/lib.sh"
load_config
detect_container_cmd
. "${GCP_DIR}/gce-k3s/k3s-config.env" 2> /dev/null || { echo "Ejecuta primero: ./scripts/k3s-setup.sh"; exit 1; }

SSH=(gcloud compute ssh "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" --quiet)

echo "=== Importando imágenes en K3s ==="
for name in expense-service expense-client; do
  image="${IMAGE_REGISTRY}/${name}:latest"
  echo "Transfiriendo ${image}..."
  "${CONTAINER_CMD}" save "${image}" | gzip | "${SSH[@]}" --command "gunzip | sudo k3s ctr images import -"
done

echo "=== Aplicando manifiestos ==="
# Las imágenes ya están en la VM: IfNotPresent evita intentar autenticarse contra Artifact Registry
render_manifest | sed 's/imagePullPolicy: Always/imagePullPolicy: IfNotPresent/' \
  | "${SSH[@]}" --command "sudo k3s kubectl apply -f -"

for d in expense-service expense-client; do
  "${SSH[@]}" --command "sudo k3s kubectl rollout status deployment/${d} --timeout=5m"
done

EXTERNAL_IP=$(gcloud compute instances describe "${VM_NAME}" --zone "${ZONE}" --project "${PROJECT_ID}" \
  --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
echo ""
echo "✓ Client disponible en: http://${EXTERNAL_IP}:8080/expenses"
