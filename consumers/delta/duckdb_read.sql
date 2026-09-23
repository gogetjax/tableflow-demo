-- DuckDB, Delta by S3 path. Credentials from the AWS default chain; no catalog, no Confluent.
-- Run:  duckdb < consumers/delta/duckdb_read.sql   (set DELTA_TABLE_URI first)
--
-- STATUS (2026-09-22, DuckDB 1.5.5 and 2.0.0-dev nightly, delta extension): count(*) is right
-- but every column comes back NULL. Tableflow's Delta table uses column mapping mode `id`
-- (physical names col_N, resolved through Parquet field IDs) and DuckDB resolves by physical
-- name. Kept as the probe for that gap; see docs/06 and docs/09 Q11.
INSTALL delta; LOAD delta;
INSTALL httpfs; LOAD httpfs;
CREATE OR REPLACE SECRET aws (TYPE s3, PROVIDER credential_chain, REGION 'us-east-1');

SELECT count(*) AS row_count, max(ordered_at) AS latest_order
FROM delta_scan(getenv('DELTA_TABLE_URI'));
