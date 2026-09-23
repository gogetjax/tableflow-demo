#!/usr/bin/env python3
"""CI variant of flink/apply.sh: same files, same names, same idempotency, but through the Flink
REST API, because the Confluent CLI has no API-key login for Confluent Cloud (only email/password
or SSO). Used by .github/workflows/flink-apply.yml with a Flink API key owned by sa-terraform-ci,
which holds Assigner on sa-flink so statements can run as sa-flink.

API: https://docs.confluent.io/cloud/current/api.html#tag/Statements-(sqlv1)
Env: FLINK_API_KEY, FLINK_API_SECRET, CONFLUENT_ORG_ID, CONFLUENT_ENV_ID, FLINK_COMPUTE_POOL_ID,
     KAFKA_CLUSTER_ID, FLINK_SA_ID, CONFLUENT_ENV_NAME (catalog name), FLINK_REGION (us-east-1)
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def env(name: str) -> str:
    v = os.environ.get(name)
    if not v:
        print(f"missing env {name}", file=sys.stderr)
        sys.exit(2)
    return v


KEY, SECRET = env("FLINK_API_KEY"), env("FLINK_API_SECRET")
ORG, ENV_ID, POOL = env("CONFLUENT_ORG_ID"), env("CONFLUENT_ENV_ID"), env("FLINK_COMPUTE_POOL_ID")
CLUSTER, SA, CATALOG = env("KAFKA_CLUSTER_ID"), env("FLINK_SA_ID"), env("CONFLUENT_ENV_NAME")
REGION = os.environ.get("FLINK_REGION", "us-east-1")
BASE = f"https://flink.{REGION}.aws.confluent.cloud/sql/v1/organizations/{ORG}/environments/{ENV_ID}/statements"
AUTH = "Basic " + base64.b64encode(f"{KEY}:{SECRET}".encode()).decode()


def call(method: str, url: str, body: dict | None = None) -> dict | None:
    req = urllib.request.Request(url, method=method, headers={"Authorization": AUTH, "Content-Type": "application/json"})
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urllib.request.urlopen(req, data=data, timeout=60) as r:
            txt = r.read().decode()
            return json.loads(txt) if txt else None
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        print(f"{method} {url} -> {e.code} {e.read().decode()[:300]}", file=sys.stderr)
        raise


def status(name: str) -> str | None:
    s = call("GET", f"{BASE}/{name}")
    return s["status"]["phase"] if s else None


def main() -> int:
    rc = 0
    for f in sorted(Path(__file__).resolve().parent.glob("[0-9][0-9]-*.sql")):
        name = f"tableflow-demo-{f.stem}"
        st = status(name)
        if st and st != "FAILED":
            print(f"skip  {name} ({st})")
            continue
        if st == "FAILED":
            print(f"retry {name} (deleting FAILED statement)")
            call("DELETE", f"{BASE}/{name}")
            time.sleep(3)
        print(f"apply {name}")
        call("POST", BASE, {
            "name": name,
            "organization_id": ORG,
            "environment_id": ENV_ID,
            "spec": {
                "statement": f.read_text(),
                "compute_pool_id": POOL,
                "principal": SA,
                "properties": {"sql.current-catalog": CATALOG, "sql.current-database": CLUSTER},
                "stopped": False,
            },
        })
        for _ in range(60):
            time.sleep(5)
            s = call("GET", f"{BASE}/{name}")
            phase = s["status"]["phase"]
            if phase in ("RUNNING", "COMPLETED", "FAILED"):
                break
        print(f"      status={phase} {s['status'].get('detail', '')}")
        if phase not in ("RUNNING", "COMPLETED"):
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
