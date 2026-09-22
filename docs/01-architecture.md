# 01 — Architecture

## Goal

One Kafka topic, cleaned by Flink, materialized by Tableflow into Iceberg **and** Delta in a customer-owned S3 bucket. Two consumers read it — one Iceberg-native, one Delta-native — using only AWS credentials.

## Data flow

```mermaid
flowchart LR
  subgraph gen[Data generation]
    ST[ShadowTraffic]
  end
  subgraph cc[Confluent Cloud — us-east-1]
    SR[(Schema Registry<br/>Avro)]
    RAW[[topic: orders.raw]]
    FL[Flink SQL<br/>cleaning statements]
    CLEAN[[topic: orders.clean]]
    TF[Tableflow<br/>BYOS · ICEBERG + DELTA]
  end
  subgraph aws[Customer AWS account — us-east-1]
    S3[(S3 bucket<br/>tableflow-demo-lake)]
    GLUE[(Glue Data Catalog<br/>db = cluster id)]
    IC[Iceberg consumer<br/>PyIceberg / Athena]
    DC[Delta consumer<br/>delta-rs / DuckDB / Databricks]
  end
  ST -- Avro + SR --> RAW
  ST -. register/lookup .-> SR
  RAW --> FL --> CLEAN
  CLEAN --> TF
  TF -- Parquet + Iceberg metadata --> S3
  TF -- Parquet + _delta_log --> S3
  TF -- Iceberg table metadata --> GLUE
  GLUE --> IC
  S3 --> IC
  S3 --> DC
```

## Trust boundaries

```mermaid
flowchart TB
  subgraph confluent[Confluent-side trust zone]
    P[Producer SA] --> K[Kafka + SR]
    K --> F[Flink SA]
    F --> K
    K --> T[Tableflow]
  end
  subgraph awszone[AWS trust zone]
    B[(S3)]
    G[(Glue)]
    C1[Iceberg consumer role]
    C2[Delta consumer role]
  end
  T -- AssumeRole via provider integration<br/>outbound from Confluent only --> B
  T -- AssumeRole via provider integration --> G
  C1 --> G
  C1 --> B
  C2 --> B
```

The only link between zones is Confluent assuming an IAM role in the AWS account. Nothing in the AWS zone initiates a connection to Confluent.

## Components

| Component | Role | Owner |
|---|---|---|
| ShadowTraffic | Generates `orders.raw` events as Avro with deliberate dirty rows | `shadowtraffic/` |
| Schema Registry | Source of truth for table schemas. Avro subjects pre-registered by Terraform | `schemas/`, `terraform/confluent` |
| Flink SQL | Filters, normalizes, deduplicates into `orders.clean` (append-only) | `flink/` |
| Tableflow | Materializes `orders.clean` to Iceberg + Delta in S3; syncs Iceberg metadata to Glue | `tableflow/`, `terraform/confluent` |
| S3 bucket | Empty at enablement, same region as cluster, Tableflow-managed prefixes never touched by humans | `terraform/aws` |
| Glue Data Catalog | Iceberg pointer store for consumers. Database name = Kafka cluster ID, table name = topic name | `terraform/aws` |
| Consumers | Read-only. AWS creds only | `consumers/` |

## Why this shape

- **Delta forces BYOS.** Tableflow Delta tables support only Bring Your Own Storage. That decision cascades into everything else.
- **Iceberg needs a catalog; Delta doesn't.** Iceberg's current-metadata pointer lives in a catalog. Delta's `_delta_log` is self-describing. See ADR-0002.
- **Consumers can't reach Confluent.** Rules out the built-in Iceberg REST catalog on the read side. Glue is the only catalog Tableflow can push to that lives inside the AWS account. See ADR-0003.
- **Flink before Tableflow.** Cleaning happens once, upstream, instead of in every consumer. Tableflow only accepts append or upsert changelogs, which shapes the SQL (see 04).

## Naming

| Thing | Value |
|---|---|
| Region | `us-east-1` (cluster and bucket must match) |
| Confluent env | `tableflow-demo` |
| Kafka cluster | `tableflow-demo` (confirm Tableflow availability for the chosen SKU and region) |
| Topics | `orders.raw`, `orders.clean`, `orders.rejected` |
| SR subjects | `orders.raw-key`, `orders.raw-value`, `orders.clean-key`, `orders.clean-value` |
| S3 bucket | `tableflow-demo-lake-<account-id>` |
| Glue database | created by Tableflow, named after the cluster ID. Do not pre-create with a different name. |
