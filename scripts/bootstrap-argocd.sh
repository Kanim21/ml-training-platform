#!/usr/bin/env bash
# Installs ArgoCD from gitops/bootstrap/argocd and applies the root
# app-of-apps. This is the only direct `kubectl apply` in the repo; after it,
# ArgoCD manages itself and everything else from Git.
# Requires: kubectl, KUBECONFIG pointing at the cluster (make sets it).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Installing ArgoCD"
# Server-side apply: ArgoCD's CRDs exceed the client-side annotation limit.
kubectl apply --server-side --force-conflicts -k "${repo_root}/gitops/bootstrap/argocd"

echo "==> Waiting for ArgoCD components"
kubectl -n argocd wait --for=condition=Established crd/applications.argoproj.io --timeout=120s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

echo "==> Applying root app-of-apps"
kubectl apply -f "${repo_root}/gitops/bootstrap/root-app.yaml"
