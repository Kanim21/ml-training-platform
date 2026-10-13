#!/usr/bin/env python3
"""Phase 2 smoke test for the MLflow tracking server.

    mlflow_smoke.py log           -> logs params, metrics and an artifact; prints the run ID
    mlflow_smoke.py check RUN_ID  -> re-reads that run and verifies all three survived

Requires mlflow-skinny and MLFLOW_TRACKING_URI (for example a port-forward to
svc/mlflow). Artifacts go through the server's artifact proxy, so the client
needs no S3 credentials.
"""
import sys
import tempfile
from pathlib import Path

import mlflow
from mlflow.tracking import MlflowClient

EXPERIMENT = "phase2-smoke"
PARAMS = {"lr": "0.01", "batch_size": "32"}
METRICS = {"loss": [0.9, 0.5, 0.3]}
ARTIFACT_NAME = "hello.txt"
ARTIFACT_BODY = "phase 2 artifact\n"


def log() -> None:
    mlflow.set_experiment(EXPERIMENT)
    with mlflow.start_run() as run:
        mlflow.log_params(PARAMS)
        for step, value in enumerate(METRICS["loss"]):
            mlflow.log_metric("loss", value, step=step)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / ARTIFACT_NAME
            path.write_text(ARTIFACT_BODY)
            mlflow.log_artifact(str(path))
    print(run.info.run_id)


def check(run_id: str) -> None:
    client = MlflowClient()
    run = client.get_run(run_id)
    errors = []
    if run.data.params != PARAMS:
        errors.append(f"params {run.data.params} != {PARAMS}")
    history = [m.value for m in client.get_metric_history(run_id, "loss")]
    if history != METRICS["loss"]:
        errors.append(f"loss history {history} != {METRICS['loss']}")
    with tempfile.TemporaryDirectory() as tmp:
        local = client.download_artifacts(run_id, ARTIFACT_NAME, tmp)
        body = Path(local).read_text()
    if body != ARTIFACT_BODY:
        errors.append(f"artifact body {body!r} != {ARTIFACT_BODY!r}")
    if errors:
        sys.exit("FAIL: " + "; ".join(errors))
    print(f"OK: run {run_id} has params, {len(history)} metric points and {ARTIFACT_NAME}")


if __name__ == "__main__":
    if sys.argv[1:2] == ["log"]:
        log()
    elif sys.argv[1:2] == ["check"] and len(sys.argv) == 3:
        check(sys.argv[2])
    else:
        sys.exit(__doc__)
