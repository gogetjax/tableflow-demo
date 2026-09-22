# 07 — Terraform and CI/CD

## Layout

```
terraform/
  aws/                     # state: s3 backend, key aws/terraform.tfstate
    main.tf                # bucket, KMS (optional), Glue db placeholder (see note), VPC endpoints
    iam-writer.tf          # tableflow-writer, tableflow-glue-writer (trust from Confluent PI)
    iam-consumers.tf       # consumer-iceberg, consumer-delta
    iam-github.tf          # OIDC role for Actions
    outputs.tf             # role ARNs, bucket name
  confluent/               # state: s3 backend, key confluent/terraform.tfstate
    env.tf                 # environment, SR (Essentials), cluster
    topics.tf              # orders.raw, orders.clean, orders.rejected, orders.tableflow-errors
    schemas.tf             # SR subjects from ../../schemas/*.avsc, compatibility
    rbac.tf                # service accounts, role bindings, API keys → outputs (sensitive)
    flink.tf               # compute pool
    provider-integration.tf# confluent_provider_integration (AWS)
    tableflow.tf           # confluent_tableflow_topic for orders.clean
    catalog.tf             # confluent_catalog_integration (Glue)
```

Two root modules, two states. AWS first, Confluent second, then one AWS re-apply to finalize trust policies.

Glue note: Tableflow creates the database itself. Terraform does not create it; it only grants permissions on the expected ARN pattern. If you want Terraform to "own" it for teardown, import after first sync.

## Bootstrap order

```mermaid
flowchart TD
  A[1. aws apply<br/>bucket, consumer roles, OIDC role,<br/>writer roles with placeholder trust] --> B[2. confluent apply<br/>env, cluster, SR, topics, schemas, RBAC, pool,<br/>provider integration]
  B --> C[3. aws apply<br/>writer roles trust = PI principal + external ID]
  C --> D[4. confluent apply<br/>tableflow topic + Glue catalog integration]
  D --> E[5. shadowtraffic + flink statements]
  E --> F[6. consumers smoke test]
```

Steps 1–4 are `terraform apply` runs in GitHub Actions gated by environment approval. Step 5 is scripted. Step 6 is a workflow.

## GitHub Actions

| Workflow | Trigger | Does |
|---|---|---|
| `tf-plan.yml` | PR touching `terraform/**` or `schemas/**` | fmt, validate, plan for both roots, plan posted as PR comment |
| `tf-apply-aws.yml` | push to `main`, path `terraform/aws/**` | apply with `environment: prod` approval |
| `tf-apply-confluent.yml` | push to `main`, path `terraform/confluent/**` or `schemas/**` | apply with approval |
| `flink-apply.yml` | manual | applies `flink/*.sql` in order, idempotent (skip if statement name exists) |
| `consumers-smoke.yml` | schedule + PR on `consumers/**` | assumes consumer roles via OIDC, runs reads, asserts |

Auth:
- AWS: OIDC to `github-actions-terraform`. No static keys.
- Confluent: `CONFLUENT_CLOUD_API_KEY/SECRET` for `sa-terraform-ci` in the `prod` GitHub Environment.
- Consumer roles: separate OIDC trust conditions (`environment:consumers`) so the Terraform role can't be used to read data and vice versa.

## Pins

- Terraform ≥ 1.9, `confluentinc/confluent` provider pinned to an exact version; record the registry doc URL for that version in `terraform/confluent/README.md`.
- `hashicorp/aws` pinned.
- Renovate or Dependabot on provider versions with plan-only PRs.

## Teardown

Order matters: disable Tableflow on the topic (tables delete asynchronously per retention), wait, then Confluent destroy, then AWS destroy. Bucket has `force_destroy = true` only in the demo.
