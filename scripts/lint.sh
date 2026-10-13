#!/usr/bin/env bash
# Lints YAML, Ansible and rendered Kubernetes manifests. Same checks as CI.
# Requires: yamllint, ansible-lint, kubectl (for kustomize), kubeconform.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

echo "==> yamllint"
yamllint -s .

echo "==> ansible-lint"
(cd ansible && ansible-lint site.yml reset.yml)

echo "==> kubeconform (rendered kustomizations)"
# CRD objects themselves have no published schema; their instances are checked.
schemas=(
  -skip CustomResourceDefinition
  -schema-location default
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
)
while IFS= read -r k; do
  dir="$(dirname "${k}")"
  echo "    ${dir}"
  kubectl kustomize "${dir}" | kubeconform -strict -summary "${schemas[@]}" -
done < <(find gitops -name kustomization.yaml | sort)

echo "    gitops/bootstrap/root-app.yaml"
kubeconform -strict -summary "${schemas[@]}" gitops/bootstrap/root-app.yaml
