# Documentation index

Read in order the first time.

| # | Doc | Purpose |
|---|---|---|
| 01 | [Architecture](01-architecture.md) | End-to-end data flow, component roles, diagrams |
| 02 | [Security](02-security.md) | Threat model, Confluent RBAC, AWS IAM, bucket policy, network |
| 03 | [Producer spec](03-producer-spec.md) | ShadowTraffic, Avro schemas, Schema Registry governance |
| 04 | [Flink spec](04-flink-spec.md) | Cleaning statements, changelog-mode rules |
| 05 | [Tableflow spec](05-tableflow-spec.md) | Enablement, dual format, Glue sync, retention |
| 06 | [Consumer spec](06-consumer-spec.md) | Iceberg via Glue, Delta by path, isolation checks |
| 07 | [Terraform and CI/CD](07-terraform-cicd.md) | Module layout, state, GitHub Actions, OIDC |
| 08 | [Runbook](08-runbook.md) | Phase checklists, verification, troubleshooting |
| 09 | [Open questions](09-open-questions.md) | Claims that need a live smoke test before they go in the README |
| 10 | [Demo script](10-demo-script.md) | 10-minute walkthrough of the running demo |
| ADR | [adr/](adr/) | Decisions and the reasons behind them |

Source docs referenced throughout (verify against these, not memory):

- Tableflow overview: https://docs.confluent.io/cloud/current/topics/tableflow/overview.html
- Storage (BYOS): https://docs.confluent.io/cloud/current/topics/tableflow/concepts/tableflow-storage.html
- Catalog integration: https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/catalog-integration/overview.html
- Glue integration: https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/catalog-integration/integrate-with-aws-glue-catalog.html
- CLI `tableflow topic enable`: https://docs.confluent.io/confluent-cli/current/command-reference/tableflow/topic/confluent_tableflow_topic_enable.html
