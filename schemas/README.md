# schemas

Avro schemas (`*.avsc`) that are the source of truth for Schema Registry subjects. Terraform registers them; producers never auto-register. Phase 2 adds `orders.raw-key.avsc` and `orders.raw-value.avsc`; the `orders.clean-*` subjects are created by Flink in Phase 4. Field table and governance rules: [docs/03-producer-spec.md](../docs/03-producer-spec.md).
