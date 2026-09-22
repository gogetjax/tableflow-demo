# 05 — Tableflow spec

## What we enable

| Topic | Storage | Formats | Catalog sync |
|---|---|---|---|
| `orders.clean` | BYOS, S3 `tableflow-demo-lake-<acct>` | ICEBERG + DELTA | AWS Glue (Iceberg only) |
| `orders.raw` | none in Phase 1 | — | — |
| `orders.rejected` | none in Phase 1 | — | — |

Later phases may enable `orders.raw` to show a bronze/silver comparison.

## Prerequisites (from Confluent docs)

- Provider integration at the **environment** level pointing at `tableflow-writer` (see 02). Multiple topics share one.
- Bucket in the same region as the cluster. Bucket **empty** at first enablement. Never modify Tableflow-written objects.
- Key and value schemas present in Schema Registry for the topic.
- Cluster type and region support Tableflow (not Google Cloud; not Confluent Platform).
- Catalog sync only works for BYOS topics — fine, everything here is BYOS.

## Dual format

Confluent announced dual format GA in October 2025: one topic can be materialized as both Iceberg and Delta. The CLI reference for `confluent tableflow topic enable --table-formats` currently reads "one of DELTA or ICEBERG" while the flag name and the REST API field are plural/array. **Open question 09-Q1**: verify how to pass both in the CLI, the REST API (`table_formats: ["ICEBERG","DELTA"]`), and the Terraform provider before writing the enablement script. If the CLI genuinely accepts only one, enable via Terraform or the API.

## Enablement — Terraform first

Terraform provider resources involved (names known; **verify current argument names on the registry page for the pinned provider version** — open question 09-Q2):

- `confluent_provider_integration` — AWS, `customer_role_arn` = `tableflow-writer` ARN. Applied in Phase 2 (two of them: `cspi-jj1d8` for S3, `cspi-rn930` for Glue).
- `confluent_tableflow_topic` — `byob_aws { bucket_name, provider_integration_id }` (note **byob**, not byos), `table_formats = ["ICEBERG", "DELTA"]`, `retention_ms`, `error_handling { mode, log_target }`. Needs a Tableflow API key (`credentials` block or provider-level `tableflow_api_key`).
- `confluent_catalog_integration` — `aws_glue { provider_integration_id }` referencing the Glue provider integration. Also needs the Tableflow API key.

Argument names above verified against provider 2.86.0 docs (Q2).

Chicken-and-egg: the provider integration must exist before the IAM trust policy can be finalized (Confluent hands back the principal and external ID). Sequence in 07.

## Settings

| Setting | Value | Reason |
|---|---|---|
| Retention (`retention_ms`) | 7 days (default `604800000`) | Snapshot/version expiration. Tableflow keeps 10–100 snapshots regardless; not configurable. |
| Error handling | `LOG` with `log_target` = `orders.tableflow-errors` | Keeps materialization alive and makes rejected rows visible. `SUSPEND` is safer for prod but hides the demo's error path. Verify the flag/argument exists for your provider version. |
| Metadata column naming | `DEFAULT` unless a consumer engine chokes on Tableflow's internal column names; then `PORTABLE`. | Test with DuckDB. |

## Glue catalog sync

- Created at the **cluster** level. One Glue integration per cluster.
- Tableflow creates the Glue database named after the cluster ID and one table per Tableflow-enabled topic named after the topic. Note the dot in `orders.clean`; check what Glue table name Tableflow produces (09-Q3) — Glue allows dots but some engines don't.
- Do **not** enable Glue table optimizers (compaction, snapshot retention, orphan file deletion) on these tables. Tableflow owns maintenance.
- Sync stays `pending` until at least one topic is materialized. Expect a lag after first enable.
- Catalog sync can fail independently of materialization. Monitor per-topic catalog sync status in the Console; a failed sync means Glue shows a stale table, not an error.

## What lands in S3 (expected layout — confirm in 09-Q4)

```
s3://tableflow-demo-lake-<acct>/
  <tableflow-managed prefix>/
    <cluster-id>/orders.clean/        # naming may differ; do not depend on it
      data/           *.parquet       # shared by both formats? or duplicated? → 09-Q4
      metadata/       *.metadata.json, snap-*.avro, *.avro   # Iceberg
      _delta_log/     *.json, *.checkpoint.parquet           # Delta
```

Whether Iceberg and Delta share Parquet files or Tableflow writes two copies affects storage cost and is worth stating in the README once observed.

## Acceptance

- Console shows `orders.clean` Tableflow status `Running` with both formats.
- S3 shows both an Iceberg `metadata/` tree and a `_delta_log/`.
- Glue database exists with the `orders.clean` table; its `metadata_location` property advances after each commit.
- Metrics (rows written, bytes compacted, rows rejected) are non-zero and sane.
