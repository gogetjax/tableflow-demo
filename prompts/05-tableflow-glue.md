Enable Tableflow on `orders.clean` in both formats and sync Iceberg metadata to Glue, per docs/05-tableflow-spec.md.

1. Resolve Q1 first. Fetch the registry doc for `confluent_tableflow_topic` at the pinned provider version and the Tableflow REST API reference. Determine how to request both ICEBERG and DELTA. Try Terraform first; if the provider can't express dual format, use the REST API from a script in `tableflow/` and document the call. Write the outcome in docs/09-open-questions.md Q1 with the exact syntax that worked and the provider version.
2. Add `terraform/confluent/tableflow.tf` (BYOS, bucket from AWS remote state, PI from Phase 2, retention default, error handling per docs/05 — resolve Q7 while you're in the registry docs) and `terraform/confluent/catalog.tf` for the Glue integration.
3. Plan, paste, open PR "Phase 5: Tableflow dual format + Glue sync". After I merge and apply:
4. Verify: Tableflow status Running with both formats; `aws s3 ls --recursive` shows Iceberg `metadata/` and `_delta_log/`; Glue database (name = cluster ID) contains the table; `aws glue get-table` shows `metadata_location`.
5. Resolve Q3 (Glue table name) and Q4 (S3 layout, shared vs duplicated data files, Delta root path). Write results into docs/09 and update the "What lands in S3" block in docs/05 with the real layout.
6. Update the README status table.

Do not touch any object in the bucket. Do not enable Glue table optimizers.
