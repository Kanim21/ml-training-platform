# ADR 0005: SeaweedFS instead of MinIO for object storage

**Status:** Accepted (deviation from the blueprint)

## Context

The blueprint names MinIO for datasets, checkpoints and MLflow artifacts. At
build time (2026-10) the `minio/minio` GitHub repository is archived, its last
release is from 2025-10, and the community container images are no longer
published. Building and running an unmaintained server would mean a storage
layer with no security fixes.

## Decision

Use SeaweedFS (Apache-2.0, actively released) through its S3 API:

- A single `weed mini` process (master, volume, filer and S3 gateway) as a
  one-replica StatefulSet on a 5Gi `local-path` PVC. WebDAV, the admin UI and
  the Iceberg catalog are turned off.
- The S3 identity comes from the sealed `s3-credentials` Secret, via the
  `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` env vars. The `mlflow`,
  `checkpoints` and `datasets` buckets are created on startup if missing, so
  there is no manual setup step and no bootstrap Job.
- Clients use the in-cluster endpoint `http://seaweedfs.storage.svc:8333`.
  Anything written against "S3" (boto3, MLflow, torch checkpoint code)
  carries over unchanged, so the blueprint's architecture still holds with
  "MinIO" read as "the S3 store".

## Consequences

- MLflow 3.x with an S3 artifact store tells clients to download artifacts
  directly from S3 via presigned URLs. Those URLs point at the in-cluster
  service name, so clients **outside** the cluster must set
  `MLFLOW_ENABLE_PROXY_MULTIPART_DOWNLOAD=false` (and `..._UPLOAD=false`) to
  stay on the proxied path. In-cluster trainers are unaffected.
- A single replica on node-local storage: losing the node loses the store
  until it returns. Drill 6 (full rebuild) needs a backup of this volume.
  Backup is not implemented yet.

## Alternatives considered

- **Garage.** Lightweight, but AGPL. It also needs a cluster-layout step and
  a key-creation step after install, which here would mean a Job.
- **RustFS.** The closest drop-in for MinIO, but younger, with less
  operational track record.
- **MinIO built from the last source release.** Matches the blueprint's
  wording, but it is unmaintained.
