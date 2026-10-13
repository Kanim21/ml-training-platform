# ADR 0002: ArgoCD app-of-apps, with a single bootstrap apply

**Status:** Accepted

## Context

The cluster should be disposable. Everything in it needs to be reproducible
from Git, with no undocumented manual `kubectl` steps.

## Decision

- `make argocd` does exactly two direct applies: the ArgoCD install
  (`gitops/bootstrap/argocd`, upstream manifests pinned to a release tag) and
  the `root` Application.
- `root` syncs `gitops/bootstrap/apps/`. That directory holds an `argocd`
  Application, so ArgoCD manages its own install and upgrades are a version
  bump commit. It also holds the `ml-platform` AppProject, which restricts
  source repos to this one. Later phases add one Application per component
  there.
- Automated sync with self-heal is on everywhere. Pruning is on for `root`
  and off for the self-managed `argocd` app, so a bad commit can't delete
  ArgoCD's own CRDs.
- Server-side apply, because ArgoCD's CRDs are too large for the client-side
  last-applied annotation.

## Alternatives considered

- **ApplicationSet with a git directory generator.** Less YAML per component,
  but each app's sync policy and wave is less explicit. Worth revisiting if
  the component count grows.
- **Flux.** Equally valid. ArgoCD was picked for its UI, which gives visual
  evidence in the drill write-ups.
