# ADR 0003: CPU only, small model, public dataset

**Status:** Accepted

## Context

This project is about running stateful, failure-prone workloads on
Kubernetes, not about model quality. GPUs would add cost and driver/operator
complexity, and would make the lab harder to rebuild. None of that adds
evidence for the platform claims.

## Decision

Train a small model on a public dataset on CPU, using `torchrun` elastic.
Checkpoint/resume, rendezvous and node-loss behaviour work the same way on
CPU as on GPU. The Prometheus GPU exporter and Triton are cut accordingly
(see BLUEPRINT.md scope table).

## Consequences

- No claims about GPU training or throughput at scale.
- Training-time numbers in drills describe this lab only and are reported as
  measured, never extrapolated.
