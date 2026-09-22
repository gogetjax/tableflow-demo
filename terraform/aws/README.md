# terraform/aws

Root module for the customer AWS account. Applied in Phase 1. See [../README.md](../README.md) for the bootstrap order and the two-pass trust commands.

| File | Holds |
|---|---|
| `main.tf` | Lake bucket `tableflow-demo-lake-<account>`: versioning, SSE-S3, Block Public Access, bucket-owner-enforced, `force_destroy` (demo only), no lifecycle rules, bucket policy from [docs/02-security.md](../../docs/02-security.md) |
| `iam-writer.tf` | `tableflow-writer` (S3) and `tableflow-glue-writer` (Glue). Deny-all trust until `confluent_pi_principal_arn` / `confluent_pi_external_id` are set |
| `iam-consumers.tf` | `consumer-iceberg` (Glue read + S3 read), `consumer-delta` (S3 read) |
| `iam-github.tf` | `github-actions-terraform` (environment:prod), `github-actions-consumers` (environment:consumers). References the account's existing GitHub OIDC provider |
| `network.tf` | VPC `10.42.0.0/16`, one private subnet, no IGW/NAT, S3 gateway endpoint, Glue interface endpoint, consumer SG |

Glue: Tableflow creates the database named after the Kafka cluster ID. This root never creates it; policies reference `database/${kafka_cluster_id}`, which defaults to `*` until Phase 2 supplies the ID.

Design: [docs/07-terraform-cicd.md](../../docs/07-terraform-cicd.md). IAM requirements: [docs/02-security.md](../../docs/02-security.md).
