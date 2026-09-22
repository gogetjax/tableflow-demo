# consumers

Read-only consumers that hold AWS credentials only and never reach Confluent. `iceberg/` reads through the Glue Data Catalog; `delta/` reads by S3 path. A `compare.sh` prints both row counts side by side. Populated in Phase 6 by [prompts/06-consumers.md](../prompts/06-consumers.md). Isolation contract and comparison table: [docs/06-consumer-spec.md](../docs/06-consumer-spec.md). Why consumers are isolated: [docs/adr/0003-consumer-isolation.md](../docs/adr/0003-consumer-isolation.md).
