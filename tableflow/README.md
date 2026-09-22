# tableflow

Tableflow on `orders.clean` is enabled by Terraform (`terraform/confluent/tableflow.tf`: BYOS on the lake bucket, `table_formats = ["ICEBERG", "DELTA"]`, `LOG` error handling to `orders.tableflow-errors`) and the Glue catalog integration by `terraform/confluent/catalog.tf`. No enablement script was needed: the provider expresses dual format directly (docs/09 Q1).

`verify.sh` is the read-only check used in Phase 5 and the demo: Tableflow status via the CLI, the S3 layout under the bucket, and the Glue table's `metadata_location`.

```bash
CONFLUENT_ENV_ID=env-876zz7 KAFKA_CLUSTER_ID=lkc-q2zqngd \
LAKE_BUCKET=tableflow-demo-lake-706193894984 ./tableflow/verify.sh
```

Spec, settings, and the observed S3 layout: [docs/05-tableflow-spec.md](../docs/05-tableflow-spec.md). Never write to the bucket by hand; never turn on Glue table optimizers for these tables.
