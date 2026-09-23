#!/usr/bin/env python3
"""Iceberg consumer via AWS Glue Data Catalog.

Holds AWS credentials only (default credential chain). No Confluent configuration of any kind:
Glue is the catalog, S3 holds the files. Env:
  AWS_REGION            region of Glue + bucket (default us-east-1)
  GLUE_DATABASE         Tableflow's Glue database = Kafka cluster id (e.g. lkc-xxxxx)
  GLUE_TABLE            Glue table name for the topic (docs/09 Q3)
Flags: --snapshot-only  print the current snapshot id and exit
       --count-only     print the row count and exit
"""
import argparse
import os
import sys

from pyiceberg.catalog import load_catalog


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot-only", action="store_true")
    ap.add_argument("--count-only", action="store_true")
    args = ap.parse_args()

    region = os.environ.get("AWS_REGION", "us-east-1")
    db = os.environ["GLUE_DATABASE"]
    tbl = os.environ["GLUE_TABLE"]

    catalog = load_catalog("glue", **{"type": "glue", "glue.region": region, "s3.region": region})
    table = catalog.load_table((db, tbl))  # tuple identifier: the table name contains a dot
    snap = table.current_snapshot()
    snapshot_id = snap.snapshot_id if snap else None

    if args.snapshot_only:
        print(snapshot_id)
        return 0

    arrow = table.scan().to_arrow()
    if args.count_only:
        print(arrow.num_rows)
        return 0

    print(f"table:            {db}.{tbl}")
    print(f"metadata_location {table.metadata_location}")
    print(f"current snapshot  {snapshot_id}")
    print(f"schema:\n{table.schema()}")
    print(f"row count         {arrow.num_rows}")
    print("first 5 rows:")
    print(arrow.slice(0, 5).to_pandas().to_string(index=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
