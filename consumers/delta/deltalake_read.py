#!/usr/bin/env python3
"""Delta consumer by S3 path with delta-rs (the `deltalake` package). No catalog, no Confluent.

STATUS (2026-09-22, deltalake 1.6.5): does NOT read Tableflow's Delta table. Tableflow enables the
`typeWidening`, `deletionVectors`, and `columnMapping` reader features (protocol reader version 3)
and delta-rs raises DeltaProtocolError / "Unsupported table features required: [TypeWidening]"
for both the pyarrow and the DataFusion (QueryBuilder) paths. Kept as the probe for that gap; the
working path-based reader is spark_read.py. See docs/06 and docs/09 Q11.

Env:
  AWS_REGION      bucket region (default us-east-1)
  DELTA_TABLE_URI s3://<bucket>/<table_path> (docs/09 Q4)
Flags: --version-only  print the current Delta version and exit (this part works)
       --count-only    print the row count and exit
"""
import argparse
import os
import sys

from deltalake import DeltaTable, QueryBuilder


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version-only", action="store_true")
    ap.add_argument("--count-only", action="store_true")
    args = ap.parse_args()

    uri = os.environ["DELTA_TABLE_URI"]
    region = os.environ.get("AWS_REGION", "us-east-1")

    # Credentials come from the default chain (role, env, profile). Region is the only option.
    dt = DeltaTable(uri, storage_options={"AWS_REGION": region})
    if args.version_only:
        print(dt.version())
        return 0

    print(f"table:        {uri}")
    print(f"version       {dt.version()}")
    print(f"protocol      {dt.protocol()}")
    try:
        qb = QueryBuilder().register("t", dt)
        n = qb.execute("select count(*) as n from t").read_all().to_pylist()[0]["n"]
    except Exception as e:  # DeltaProtocolError / DeltaError on unsupported reader features
        print(f"delta-rs cannot scan this table: {type(e).__name__}: {e}")
        print("use consumers/delta/spark_read.py (Spark + Delta Lake) for this table")
        return 3
    if args.count_only:
        print(n)
        return 0
    print(f"row count     {n}")
    print(qb.execute("select * from t limit 5").read_all().to_pandas().to_string(index=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
