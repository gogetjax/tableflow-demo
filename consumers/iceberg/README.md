# consumers/iceberg

Iceberg consumer via the Glue Data Catalog: `pyiceberg_read.py` (PyIceberg with a Glue catalog, prints schema, snapshot ID, row count) and `athena.sql`. Runs under the `consumer-iceberg` role from the isolated subnet. Populated in Phase 6. Spec: [docs/06-consumer-spec.md](../../docs/06-consumer-spec.md). Catalog decision: [docs/adr/0002-catalog-strategy.md](../../docs/adr/0002-catalog-strategy.md).
