# flink

Confluent Cloud Flink SQL statements, one per file, applied in file order: sink table definitions for `orders.rejected` and `orders.clean`, the invalid-row router, and the normalize-and-dedup statement. Also holds `apply.sh`, which applies each file as a named statement and skips ones that already exist. Populated in Phase 4 by [prompts/04-flink.md](../prompts/04-flink.md). Changelog-mode rules and acceptance checks: [docs/04-flink-spec.md](../docs/04-flink-spec.md).
