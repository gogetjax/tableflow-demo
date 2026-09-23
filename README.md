# tableflow-demo

Confluent Tableflow materializing one cleaned Kafka topic into **both Apache Iceberg and Delta Lake** in a customer-owned S3 bucket, with consumers that never talk to Confluent.

```
ShadowTraffic ──Avro──▶ Kafka (raw) ──Flink SQL──▶ Kafka (clean) ──Tableflow──▶ S3 (Iceberg + Delta)
                                                                                     │
                                                          Glue Data Catalog ◀────────┤ (Iceberg metadata only)
                                                                                     │
                                                    Iceberg consumer ◀── Glue + S3   │
                                                    Delta consumer   ◀── S3 path ────┘
```

## What this demonstrates

| Capability | Where |
|---|---|
| Dual-format materialization (Iceberg + Delta) from one topic, one shared set of Parquet files | `terraform/confluent/tableflow.tf`, `tableflow/verify.sh`, [docs/05-tableflow-spec.md](docs/05-tableflow-spec.md) |
| Bring Your Own Storage (S3) with least-privilege IAM | `terraform/aws`, [docs/02-security.md](docs/02-security.md) |
| Schema Registry governance with Avro end to end | [docs/03-producer-spec.md](docs/03-producer-spec.md) |
| Shift-left cleaning with Confluent Cloud Flink SQL | `flink/`, [docs/04-flink-spec.md](docs/04-flink-spec.md) |
| Catalog strategy: Glue for Iceberg, path-based for Delta | [docs/adr/0002-catalog-strategy.md](docs/adr/0002-catalog-strategy.md) |
| Consumer isolation: zero Confluent credentials or network path on the read side, proven from a no-internet subnet with CloudTrail evidence | `consumers/`, [docs/06-consumer-spec.md](docs/06-consumer-spec.md), [docs/adr/0003-consumer-isolation.md](docs/adr/0003-consumer-isolation.md) |
| Iceberg read via Glue (PyIceberg, Athena); Delta read by path (Spark + Delta Lake) | `consumers/iceberg`, `consumers/delta` |
| Everything provisioned by Terraform through GitHub Actions | [docs/07-terraform-cicd.md](docs/07-terraform-cicd.md) |

## Repository layout

```
.
├── README.md
├── CLAUDE.md                  # repo conventions for Claude Code
├── docs/                      # design, security, specs, runbook, ADRs
├── prompts/                   # Claude Code prompts that drive each phase
├── terraform/
│   ├── aws/                   # S3, IAM roles, Glue database, VPC endpoints
│   └── confluent/             # env, cluster, SR, topics, RBAC, Flink, Tableflow, Glue sync
├── schemas/                   # Avro schemas (source of truth for SR subjects)
├── shadowtraffic/             # generator configs
├── flink/                     # SQL statements, applied in order
├── tableflow/                 # enablement + verification scripts
├── consumers/
│   ├── iceberg/               # PyIceberg via Glue, Athena examples
│   └── delta/                 # delta-rs and DuckDB by S3 path
└── .github/workflows/         # terraform plan/apply, lint, consumer smoke tests
```

## Quick start

1. Read [docs/00-index.md](docs/00-index.md) for the reading order.
2. Provision AWS, then Confluent: see [docs/07-terraform-cicd.md](docs/07-terraform-cicd.md).
3. Start ShadowTraffic: `shadowtraffic/README.md`.
4. Apply Flink statements in order: `flink/README.md`.
5. Enable Tableflow on the clean topic in both formats: `tableflow/README.md`.
6. Run a consumer from an isolated AWS principal: `consumers/README.md`.
7. Give the demo: [docs/10-demo-script.md](docs/10-demo-script.md).

## Status

| Phase | State |
|---|---|
| 0 Design and docs | done |
| 1 AWS foundation (`terraform/aws`) | applied: lake bucket, 6 IAM roles, isolated consumer VPC |
| 2 Confluent foundation (`terraform/confluent`) | applied: env, Standard cluster, SR subjects, 3 SAs + RBAC, 5 CFU pool, 2 provider integrations; AWS trust finalized |
| 3 Producer (`shadowtraffic/`) | verified: Avro via SR, dirty-row rates observed on 1,000 events |
| 4 Flink (`flink/`) | running: 2 DDL + 2 INSERT statements as `sa-flink`; acceptance checks in docs/04 |
| 5 Tableflow + Glue (`terraform/confluent/tableflow.tf`, `catalog.tf`) | running: `orders.clean` BYOS, ICEBERG + DELTA, Glue sync |
| 6 Consumers (`consumers/`) | verified from the isolated subnet: PyIceberg via Glue, Spark + Delta by path; counts agree |
| 7 CI polish | done: `consumers-smoke.yml` (6-hourly), `flink-apply.yml` (manual, REST), Renovate config, [docs/10-demo-script.md](docs/10-demo-script.md) |

Every row in [docs/09-open-questions.md](docs/09-open-questions.md) has a recorded result.

## Known gaps

- **Delta readers.** Tableflow's Delta tables carry reader features `typeWidening`, `deletionVectors` and column mapping `id`. Spark 3.5 + Delta 3.3 (and Databricks) read them; delta-rs 1.6 and DuckDB's delta extension do not (docs/09 Q11). The Delta consumer is Spark-based.
- **Databricks path read** is written (`consumers/delta/databricks.sql`) but was not executed; no workspace was available (Q10).
- **Glue IAM verbs** for `tableflow-glue-writer` are a working superset, not the Console-generated minimum (Q8).
- **ShadowTraffic registers its schema** on start even with `auto.register.schemas=false`; the producer service account needs subject write, and governance is enforced by the schema being identical (docs/03).
- **Renovate** config is in the repo but the app must be enabled on the repo/org to open PRs.

## Key constraints (read before changing anything)

- Delta output requires BYOS. No Confluent Managed Storage anywhere in this repo.
- Bucket must be in the same region as the Kafka cluster; start empty; never modify Tableflow-written objects.
- Flink outputs feeding Tableflow must be append or upsert changelog mode. Retract mode is not supported by Tableflow.
- Consumers hold AWS credentials only. No Confluent API key, no Tableflow REST catalog endpoint, no Kafka bootstrap on the consumer side.
- Tableflow's Delta tables need a Delta-Kernel-class reader (Spark / Databricks). delta-rs and DuckDB cannot read them today (docs/09 Q11).
