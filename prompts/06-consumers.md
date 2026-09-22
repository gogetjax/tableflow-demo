Implement `consumers/` per docs/06-consumer-spec.md.

1. `consumers/iceberg/pyiceberg_read.py`: PyIceberg Glue catalog, table `<cluster-id>.<glue-table-name>` from Q3. Print schema, current snapshot ID, row count, 5 rows. Flags `--snapshot-only`. Use the default AWS credential chain; no hardcoded keys.
2. `consumers/iceberg/athena.sql`: count and max(ordered_at). Add the Athena workgroup + results bucket to `terraform/aws` and the permissions to `consumer-iceberg` per docs/02.
3. `consumers/delta/deltalake_read.py`: delta-rs against the Delta root path from Q4. Print version, schema, row count, 5 rows. Flag `--version-only`.
4. `consumers/delta/duckdb_read.sql` with `delta_scan`. `consumers/delta/databricks.sql` with `CREATE TABLE ... USING DELTA LOCATION`; not executed in CI.
5. `consumers/README.md`: how to assume each role, the isolation contract, and a `compare.sh` that prints the side-by-side table from docs/06.
6. Prove isolation: run both readers from the private subnet in `terraform/aws` (an SSM-managed instance or a Lambda in that subnet — pick the simpler; add it to Terraform). Paste the successful output and the CloudTrail query from docs/02 showing only expected principals.
7. Add a CI step that fails if `grep -riE "confluent|schema.registry|bootstrap.servers" consumers/` matches anything outside comments.
8. Resolve Q9 (optional) and Q10 in docs/09.

Open PR "Phase 6: isolated Iceberg and Delta consumers".
