# 09 — Open questions

Claims below are plausible from docs but unverified. Each gets a smoke test in its phase; record the result here and only then let the README state it as fact.

| ID | Question | Phase | How to verify | Result |
|---|---|---|---|---|
| Q1 | How is dual format (ICEBERG + DELTA) expressed in the CLI, REST API, and Terraform provider? CLI doc says "one of". | 5 | Try Terraform `table_formats = ["ICEBERG","DELTA"]`; fall back to REST `PATCH`/`POST` with array; then CLI. Record which worked and the provider version. | |
| Q2 | Exact argument names for `confluent_tableflow_topic`, `confluent_catalog_integration`, `confluent_provider_integration` at the pinned provider version. | 2, 5 | Registry docs page for the pinned version; `terraform validate`. | |
| Q3 | What Glue table name does Tableflow produce for topic `orders.clean` (dot in name)? | 5 | `aws glue get-tables --database-name <cluster-id>` | |
| Q4 | S3 layout for a dual-format topic: are Parquet data files shared between Iceberg and Delta or duplicated? Where is the Delta root path? | 5 | `aws s3 ls --recursive` after two commits; compare data file counts referenced by Iceberg manifest vs `_delta_log`. | |
| Q5 | Does a Flink-created sink table with `PRIMARY KEY ... NOT ENFORCED` and `changelog.mode='append'` produce a key schema Tableflow accepts? | 4–5 | Enable Tableflow on `orders.clean`; check status. | |
| Q6 | Avro `decimal` logical type mapping through Tableflow to both formats. | 3 | Only if a decimal column is added; otherwise keep `long` cents. | skipped by design |
| Q7 | Does the `LOG` error-handling strategy exist in the pinned Terraform provider? | 5 | Registry docs; else use `SKIP` and note it. | |
| Q8 | Minimum IAM verbs for `tableflow-writer` per the current BYOS quick start. | 1–2 | Copy from the Confluent-generated policy in the Console during PI setup; diff against 02. | |
| Q9 | Can `consumer-iceberg` read via Glue's Iceberg REST endpoint from DuckDB with SigV4, from the isolated subnet? Optional. | 6 | Try; if it needs Lake Formation, document and skip. | |
| Q10 | Databricks path-based read of a Tableflow Delta table (no Unity integration). The catalog doc says Delta tables are "available only through Unity Catalog integration"; the overview and the private-network workaround imply path reads work. | 6 | `CREATE TABLE ... USING DELTA LOCATION` in any workspace, or delta-rs as proxy. | |
