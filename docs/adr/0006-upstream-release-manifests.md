# ADR 0006: Upstream operators as pinned release manifests, not Helm

**Status:** Accepted

## Context

Sealed Secrets and CloudNativePG both publish Helm charts and plain
release manifests. ArgoCD can render either.

## Decision

Reference each operator's versioned release manifest as a remote
kustomize resource, for example
`.../cloudnative-pg/releases/download/v1.30.1/cnpg-1.30.1.yaml`. Local
tweaks, such as resource limits on the Sealed Secrets controller, are
kustomize patches. Our own workloads (SeaweedFS, MLflow) are plain manifests.

- The `ml-platform` AppProject can keep a single source repo (this one).
  Helm repos would each need adding to `sourceRepos`.
- Version bumps are a one-line diff, and `kubectl kustomize` renders exactly
  what ArgoCD applies. `scripts/lint.sh` schema-checks that output, including
  the CRs (SealedSecret, CNPG Cluster), against the CRDs catalog.
- Operator apps use server-side apply (the CRDs are too large for client-side
  apply) and prune disabled, so a bad commit can't delete CRDs and, with
  them, every database.

## Consequences

The Postgres cluster itself is a `Cluster` CR next to MLflow. On a fresh
cluster, the mlflow app may sync before the CNPG CRDs exist, so it uses
`SkipDryRunOnMissingResource` and a retry backoff instead of relying on
sync waves between Applications.
