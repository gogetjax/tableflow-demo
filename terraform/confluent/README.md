# terraform/confluent

Root module for Confluent Cloud. Applied in Phase 2. Auth is `CONFLUENT_CLOUD_API_KEY/SECRET` from the environment (locally a temporary admin key; in CI the `sa-terraform-ci` key from the `prod` GitHub Environment).

Provider: `confluentinc/confluent` **2.86.0**. Registry docs for this version: https://registry.terraform.io/providers/confluentinc/confluent/2.86.0/docs (source: the provider repo's `docs/` directory at tag `v2.86.0`).

| File | Holds |
|---|---|
| `versions.tf` | pins, S3 backend, remote-state read of the AWS root |
| `env.tf` | environment (Stream Governance Essentials), Schema Registry data source, Standard Kafka cluster |
| `topics.tf` | `orders.raw`, `orders_tableflow_errors` (6 partitions, 7-day retention). `orders.clean` and `orders.rejected` are created by the Flink DDL. |
| `schemas.tf` | `orders.raw-key` / `orders.raw-value` from `../../schemas/*.avsc`, compatibility `BACKWARD` |
| `rbac.tf` | service accounts, role bindings per [docs/02-security.md](../../docs/02-security.md), API keys (sensitive outputs) |
| `flink.tf` | 5 CFU compute pool |
| `provider-integration.tf` | two AWS provider integrations (S3 role, Glue role) |
| `tableflow.tf`, `catalog.tf` | Phase 5 |

Every display name is prefixed with `var.name_prefix` (`cjackson`) because the Confluent org is shared. The cluster is Standard, not Basic: Basic rejects topic-scoped RBAC roles.

Design: [docs/07-terraform-cicd.md](../../docs/07-terraform-cicd.md). Tableflow resources: [docs/05-tableflow-spec.md](../../docs/05-tableflow-spec.md).
