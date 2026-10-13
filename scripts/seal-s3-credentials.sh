#!/usr/bin/env bash
# Generates a fresh S3 access key pair and writes it as SealedSecrets for the
# SeaweedFS server (storage ns) and its clients (mlflow ns). Plaintext never
# touches disk; only the sealed output is written, ready to commit.
# Requires: kubeseal, openssl, and KUBECONFIG pointing at the cluster whose
# sealed-secrets controller should be able to decrypt the result.
set -euo pipefail

cd "$(dirname "$0")/.."

access_key="$(openssl rand -hex 10)"
secret_key="$(openssl rand -base64 30 | tr -d '/+=' | cut -c1-40)"

for target in "storage:gitops/platform/seaweedfs" "mlflow:gitops/platform/mlflow"; do
  ns="${target%%:*}"
  dir="${target#*:}"
  mkdir -p "${dir}"
  kubectl create secret generic s3-credentials \
    --namespace "${ns}" \
    --from-literal=AWS_ACCESS_KEY_ID="${access_key}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${secret_key}" \
    --dry-run=client -o yaml \
    | kubeseal --format yaml > "${dir}/s3-credentials.sealed.yaml"
  echo "wrote ${dir}/s3-credentials.sealed.yaml"
done
