#!/usr/bin/env bash
# Phase 2 "done when": log a run with params, metrics and an artifact, delete
# the MLflow pod, wait for its replacement, then check the run is intact.
# Requires: kubectl (KUBECONFIG), python3 with mlflow-skinny installed.
set -euo pipefail

cd "$(dirname "$0")/.."
PORT="${MLFLOW_PORT:-5000}"
PYTHON="${PYTHON:-python3}"
export MLFLOW_TRACKING_URI="http://127.0.0.1:${PORT}"
# With an S3 artifact store the server tells clients to fetch artifacts
# straight from S3 via presigned URLs, which point at the in-cluster
# seaweedfs.storage.svc. From outside the cluster, keep everything proxied.
export MLFLOW_ENABLE_PROXY_MULTIPART_DOWNLOAD=false
export MLFLOW_ENABLE_PROXY_MULTIPART_UPLOAD=false
export MLFLOW_DISABLE_AGENT_HINT=1

pf_pid=""
start_port_forward() {
  kubectl -n mlflow port-forward svc/mlflow "${PORT}:5000" >/dev/null &
  pf_pid=$!
  for _ in $(seq 1 30); do
    curl -fsS "${MLFLOW_TRACKING_URI}/health" >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "MLflow did not answer on ${MLFLOW_TRACKING_URI}" >&2
  return 1
}
stop_port_forward() {
  [[ -n "${pf_pid}" ]] || return 0
  kill "${pf_pid}" 2>/dev/null || true
  wait "${pf_pid}" 2>/dev/null || true
  pf_pid=""
}
trap stop_port_forward EXIT

start_port_forward
run_id="$("${PYTHON}" scripts/mlflow_smoke.py log | tail -1)"
echo "logged run ${run_id}"
stop_port_forward

old_pod="$(kubectl -n mlflow get pod -l app.kubernetes.io/name=mlflow -o name)"
echo "deleting ${old_pod}"
kubectl -n mlflow delete "${old_pod}" --wait=true
kubectl -n mlflow wait --for=condition=Ready pod -l app.kubernetes.io/name=mlflow --timeout=300s
echo "replacement: $(kubectl -n mlflow get pod -l app.kubernetes.io/name=mlflow -o name)"

start_port_forward
"${PYTHON}" scripts/mlflow_smoke.py check "${run_id}"
