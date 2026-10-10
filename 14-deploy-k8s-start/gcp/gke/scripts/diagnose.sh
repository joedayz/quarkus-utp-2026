#!/usr/bin/env bash
set -uo pipefail

# Diagnóstico del despliegue en GKE

echo "=== Pods ==="; kubectl get pods -o wide
echo; echo "=== Servicios ==="; kubectl get svc
echo; echo "=== Describe expense-client (svc) ==="; kubectl describe svc expense-client
for app in expense-client expense-service; do
  echo; echo "=== Logs ${app} (últimas 20) ==="
  kubectl logs -l app="${app}" --tail=20 2>&1 || true
done
echo; echo "=== Pods no listos (describe) ==="
kubectl describe pods | grep -E "^Name:|Warning|Failed|BackOff|Unschedulable" || true
echo; echo "=== Conectividad client -> service ==="
POD=$(kubectl get pods -l app=expense-client -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
[ -n "${POD}" ] && kubectl exec "${POD}" -- sh -c 'curl -s http://expense-service:8080/expenses || wget -q -O- http://expense-service:8080/expenses' 2>&1 || echo "No se pudo probar"
echo; echo "=== Eventos ==="; kubectl get events --sort-by='.lastTimestamp' | tail -15
