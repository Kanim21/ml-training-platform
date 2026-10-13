#!/usr/bin/env bash
# Phase 1 "Done when" check: every inventory node Ready, agents labelled as
# workers, and every ArgoCD Application Synced + Healthy. Polls until TIMEOUT
# seconds. Node count comes from the Ansible inventory unless EXPECTED_NODES
# is set.
# Requires: kubectl, ansible-inventory, KUBECONFIG pointing at the cluster.
set -euo pipefail

timeout="${TIMEOUT:-600}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${EXPECTED_NODES:-}" ]]; then
  EXPECTED_NODES="$(ansible-inventory -i "${repo_root}/ansible/inventory/hosts.ini" --list \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("_meta",{}).get("hostvars",{})))')"
fi
expected_nodes="${EXPECTED_NODES}"
deadline=$(( $(date +%s) + timeout ))

until_ok() {
  local desc="$1"; shift
  until "$@"; do
    if (( $(date +%s) > deadline )); then
      echo "FAIL: ${desc} (timed out after ${timeout}s)" >&2
      return 1
    fi
    sleep 10
  done
  echo "OK:   ${desc}"
}

nodes_ready() {
  local ready
  ready="$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c '^True$' || true)"
  [[ "${ready}" -eq "${expected_nodes}" ]]
}

workers_labelled() {
  local n
  n="$(kubectl get nodes -l ml-platform/role=worker --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  [[ "${n}" -eq $(( expected_nodes - 1 )) ]]
}

apps_synced_healthy() {
  local out
  out="$(kubectl -n argocd get applications.argoproj.io \
    -o jsonpath='{range .items[*]}{.metadata.name} {.status.sync.status} {.status.health.status}{"\n"}{end}' 2>/dev/null)" || return 1
  [[ -n "${out}" ]] || return 1
  ! grep -v ' Synced Healthy$' <<<"${out}" | grep -q .
}

until_ok "${expected_nodes} nodes Ready" nodes_ready
until_ok "$(( expected_nodes - 1 )) agent(s) labelled ml-platform/role=worker" workers_labelled
until_ok "all ArgoCD Applications Synced + Healthy" apps_synced_healthy

kubectl get nodes -o wide
kubectl -n argocd get applications.argoproj.io
