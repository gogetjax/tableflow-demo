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

Confluent announced dual format GA in October 2025: one topic can be materialized as both Iceberg and Delta. Resolved in Phase 5 (09-Q1): the Terraform provider takes `table_formats = ["ICEBERG", "DELTA"]` and that is how `orders.clean` is enabled. The CLI (`confluent tableflow topic enable --table-formats`, checked with `--help` on CLI v4.37.0) still documents the flag as a single string "one of DELTA or ICEBERG" with no `--error-handling` flag either, so the CLI is not used for enablement here.

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
| Error handling | `LOG` with `log_target` = `orders_tableflow_errors` (underscores: the Tableflow API rejects periods in `log_target`; the docs originally said `orders.tableflow-errors`) | Keeps materialization alive and makes rejected rows visible. `SUSPEND` is safer for prod but hides the demo's error path. Provider 2.86.0 has `error_handling { mode, log_target }` (09-Q7). |
| Metadata column naming | `DEFAULT` unless a consumer engine chokes on Tableflow's internal column names; then `PORTABLE`. | Test with DuckDB. |

## Glue catalog sync

- Created at the **cluster** level. One Glue integration per cluster.
- Tableflow creates the Glue database named after the cluster ID (`lkc-q2zqngd`) and one table per Tableflow-enabled topic named after the topic: the Glue table is literally `orders.clean`, dot included (09-Q3). `table_type = iceberg`, `metadata_location` and `current_snapshot_id` in the table parameters. Athena needs the name double-quoted.
- Do **not** enable Glue table optimizers (compaction, snapshot retention, orphan file deletion) on these tables. Tableflow owns maintenance.
- Sync stays `pending` until at least one topic is materialized. Expect a lag after first enable.
- Catalog sync can fail independently of materialization. Monitor per-topic catalog sync status in the Console; a failed sync means Glue shows a stale table, not an error.

## What lands in S3 (observed, 09-Q4)

One table root per topic. Tableflow reports it as `table_path` (Terraform attribute, CLI `describe`); it is also the Glue table's `Location` and the Delta root:

```
s3://tableflow-demo-lake-706193894984/1100000/11101001/cfd75085-a017-4113-81ff-f34b6f2d2a87/env-876zz7/lkc-q2zqngd/v1/5839772c-c3b9-46e6-8dea-137d2269d7af/
  data/          <uuid>.parquet                 # ONE set of Parquet files, referenced by both formats
  metadata/      NNNNN-<uuid>.metadata.json     # Iceberg table metadata (current one = Glue metadata_location)
                 snap-<id>-1-<uuid>.avro        # manifest lists
                 <uuid>-m0.avro                 # manifests
  _delta_log/    0000000000000000000N.json      # Delta commits (engineInfo "Kernel-4.2.2/Tableflow")
```

**Iceberg and Delta share the Parquet data files under one table root; nothing is written twice.** Observed after the first commits (~5 minutes after `RUNNING`): 6 Parquet files (one per topic partition), 6 Iceberg metadata versions, 6 Delta log entries, and the same 6 `data/*.parquet` paths listed as `add` actions in `_delta_log` and as data files in the current Iceberg snapshot (`total-data-files` 6, `total-records` 20,505). **Iceberg and Delta share the data files; nothing is duplicated.** The Delta table uses `delta.columnMapping.mode = id`, which readers must support (delta-rs and DuckDB's delta extension do).

The path prefix (`1100000/11101001/<org-id>/<env-id>/<cluster-id>/v1/<table-uuid>`) is Tableflow's; treat `table_path` as the only stable handle.

Both tables carry Tableflow's metadata columns after the topic columns: `$$topic`, `$$partition`, `$$headers`, `$$leader-epoch`, `$$offset`, `$$timestamp`, `$$timestamp-type`, `$$raw-key`, `$$raw-value` (naming scheme `DEFAULT`).

## Acceptance

- Console shows `orders.clean` Tableflow status `Running` with both formats.
- S3 shows both an Iceberg `metadata/` tree and a `_delta_log/`.
- Glue database exists with the `orders.clean` table; its `metadata_location` property advances after each commit.
- Metrics (rows written, bytes compacted, rows rejected) are non-zero and sane.

### Observed, 2026-09-22

`confluent tableflow topic describe orders.clean`: `phase: RUNNING`, `table_formats: DELTAICEBERG`, `storage_type: BYOS`, `record_failure_strategy: LOG`, `retention_ms: 604800000`, `enable_compaction: true`, `enable_partitioning: true`. Catalog integration `cjackson-tableflow-glue` (`tci-q2zqngdA`): `CONNECTED`. Glue `lkc-q2zqngd.orders.clean` present with `metadata_location` at `metadata/00005-...` and `current_snapshot_id` set. Three failed enablements preceded the working one; each is in docs/02 or 09: DLQ name with a period (400), DLQ write permission for the enabling account, the bucket policy `IfExists` bug, and a locally reverted trust policy (applied without the PI variables; `~/.config/.../tf-aws.sh` now exports them).
