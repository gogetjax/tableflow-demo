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
| Dual-format materialization (Iceberg + Delta) from one topic | `tableflow/`, [docs/05-tableflow-spec.md](docs/05-tableflow-spec.md) |
| Bring Your Own Storage (S3) with least-privilege IAM | `terraform/aws`, [docs/02-security.md](docs/02-security.md) |
| Schema Registry governance with Avro end to end | [docs/03-producer-spec.md](docs/03-producer-spec.md) |
| Shift-left cleaning with Confluent Cloud Flink SQL | `flink/`, [docs/04-flink-spec.md](docs/04-flink-spec.md) |
| Catalog strategy: Glue for Iceberg, path-based for Delta | [docs/adr/0002-catalog-strategy.md](docs/adr/0002-catalog-strategy.md) |
| Consumer isolation: zero Confluent credentials or network path on the read side | [docs/adr/0003-consumer-isolation.md](docs/adr/0003-consumer-isolation.md) |
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

## Status

| Phase | State |
|---|---|
| 0 Design and docs | done |
| 1 AWS foundation (`terraform/aws`) | applied: lake bucket, 6 IAM roles, isolated consumer VPC |
| 2 Confluent foundation (`terraform/confluent`) | applied: env, Standard cluster, SR subjects, 3 SAs + RBAC, 5 CFU pool, 2 provider integrations; AWS trust finalized |
| 3 Producer (`shadowtraffic/`) | verified: Avro via SR, dirty-row rates observed on 1,000 events |
| 4 Flink (`flink/`) | running: 2 DDL + 2 INSERT statements as `sa-flink`; acceptance checks in docs/04 |
| 5 Tableflow + Glue | pending |
| 6 Consumers | pending |
| 7 CI polish | pending |

See [docs/09-open-questions.md](docs/09-open-questions.md) for items that must be verified against live Confluent Cloud before the README claims them.

## Key constraints (read before changing anything)

- Delta output requires BYOS. No Confluent Managed Storage anywhere in this repo.
- Bucket must be in the same region as the Kafka cluster; start empty; never modify Tableflow-written objects.
- Flink outputs feeding Tableflow must be append or upsert changelog mode. Retract mode is not supported by Tableflow.
- Consumers hold AWS credentials only. No Confluent API key, no Tableflow REST catalog endpoint, no Kafka bootstrap on the consumer side.
