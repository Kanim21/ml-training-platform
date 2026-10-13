# ml-training-platform

A GitOps-managed platform for running ML training on a self-hosted K3s
cluster. It's a platform engineering project. The model is deliberately
small and CPU-only, because the platform is the point.

**What it proves, in order of weight:**

1. Training jobs survive node loss and resume from checkpoint, shown in a recorded drill.
2. Every model in the registry traces back to a git SHA, an image digest and a dataset hash.
3. A model reaches serving only after passing a data gate and a regression gate, enforced in the pipeline and deployed via GitOps.
4. The whole platform is rebuilt from the repo with one bootstrap command.

**What it doesn't claim:** enterprise scale, GPU training, cost savings, or ML modelling skill.

See [BLUEPRINT.md](BLUEPRINT.md) for the full scope, architecture and drill list.

## Status

| Phase | What | State |
| --- | --- | --- |
| 1 | Cluster and GitOps foundation (Rocky Linux, K3s, Ansible, ArgoCD) | Running on a **single node** (see below); 3-node layout supported but not yet run |
| 2 | Tracking and storage (SeaweedFS S3, CloudNativePG, MLflow, Sealed Secrets) | Done: `scripts/verify-mlflow.sh` logs a run, deletes the MLflow pod, and the run survives. MinIO swapped for SeaweedFS ([ADR 0005](docs/adr/0005-seaweedfs-instead-of-minio.md)) |
| 3 | Resilient training (`torchrun`, checkpoint/resume, lineage) | Not started |
| 4 | Pipeline and gates (Argo Workflows, Pandera, regression gate) | Not started |
| 5 | Serving and observability (latency gate, Grafana) | Not started |

### Current lab: single node (deviation from the blueprint)

The blueprint calls for 1 server + 2 agents. The lab currently runs **one**
Rocky Linux 10.1 VM in VirtualBox on an 8 GB Mac, because three VMs don't fit
in that host's RAM and disk alongside real workloads. The VM uses NAT, and
SSH and the API are reached through port-forwards
(`ansible/inventory/hosts.ini.single-node.example`). Drill 1 (node loss)
needs at least one agent, so agents get added before phase 3. That's an
inventory change; the roles already handle it.

The VM has 4 GB of RAM. With phase 2 running, the node had about 790 MB
available, measured with `free -m` on 2026-10-13. MLflow (about 400 MiB) and
the ArgoCD application controller (about 310 MiB) are the largest pods. To
fit, ArgoCD's Dex and notifications controllers are scaled to zero, and
MLflow runs one worker with its GenAI job runner disabled.

## Failure drills

Write-ups go in [`docs/drills/`](docs/drills/) as each drill is run. None have run yet.

## Bootstrap

### Prerequisites

- Three fresh **Rocky Linux 9 or 10** VMs (1 server, 2 agents) with SELinux
  enforcing, reachable over SSH with key auth as a sudo-capable user.
  [docs/vms.md](docs/vms.md) covers sizing and networking.
- On the control machine: `ansible-core`, `kubectl`, `make`.
- This repo pushed to the URL in `gitops/bootstrap/root-app.yaml` (ArgoCD
  syncs from there, not from your working copy).

### Run

```bash
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini   # or hosts.ini.single-node.example
$EDITOR ansible/inventory/hosts.ini     # set the three VM IPs and SSH user
make bootstrap
```

`make bootstrap` runs three steps, and each one can also run on its own:

| Target | Does |
| --- | --- |
| `make cluster` | Ansible: hardens the nodes (firewalld, sshd, swap off, SELinux checked as enforcing, security auto-updates), installs the pinned K3s server, joins the agents, writes `./kubeconfig` |
| `make argocd` | Installs ArgoCD and applies the root app-of-apps. This is the repo's only direct `kubectl apply`. |
| `make verify` | Waits until there are 3 Ready nodes, 2 labelled workers, and every ArgoCD Application is Synced and Healthy |

After that, every change to the cluster is a Git commit. Other targets:
`make argocd-ui`, `make argocd-password`, `make reset`, `make lint`
(`make help` lists them all).

## Layout

```
ansible/            Rocky Linux hardening + K3s install (roles: rocky_base, k3s_server, k3s_agent, kubeconfig)
gitops/bootstrap/   ArgoCD install (argocd/), root app, child apps (apps/)
gitops/platform/    sealed-secrets, cnpg-operator, seaweedfs (S3), mlflow (+ Postgres); later Argo Workflows, monitoring
gitops/serving/     phase 5: model server, version pinned here
pipelines/          phase 4: Argo WorkflowTemplates
trainer/            phase 3: Dockerfile, train.py, validate.py
loadtest/           phase 5: k6 script + p99 threshold
docs/adr/           design decisions
docs/drills/        failure drill write-ups
```
