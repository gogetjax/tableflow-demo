# consumers/delta

Delta consumer by S3 path with no catalog: `deltalake_read.py` (delta-rs, prints version, schema, row count), `duckdb_read.sql` (`delta_scan`), and `databricks.sql` (external table, not run in CI). Runs under the `consumer-delta` role from the isolated subnet. The Delta root path is recorded in `.env.example` once resolved. Populated in Phase 6. Spec: [docs/06-consumer-spec.md](../../docs/06-consumer-spec.md).
