# terraform

Three root modules. Apply in this order the first time.

| Root | State | Purpose |
|---|---|---|
| `bootstrap/` | local | State bucket + DynamoDB lock table. Run once by a human. |
| `aws/` | S3 `aws/terraform.tfstate` | Lake bucket, IAM roles, VPC, endpoints. |
| `confluent/` | S3 `confluent/terraform.tfstate` | Environment, cluster, SR, topics, RBAC, Flink, provider integration, Tableflow. |

## Bootstrap (once)

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

Creates `tableflow-demo-tfstate-<account-id>` (versioned, encrypted, public access blocked) and DynamoDB table `tableflow-demo-tflock`. State for this root stays local and is gitignored; the two resources are trivial to re-import if the local state is lost.

## AWS root

```bash
cd terraform/aws
terraform init
terraform plan
```

Applies run from GitHub Actions on `main` (`tf-apply-aws.yml`) once the `github-actions-terraform` role exists. The very first apply is local because that role is created by it.

## Two-pass trust bootstrap (AWS → Confluent → AWS)

The Confluent provider integrations need the writer role ARNs to exist, and the roles' trust policies need each integration's IAM principal and external ID. So:

1. `terraform/aws` apply with default variables. Writer roles get a deny-all placeholder trust policy.
2. `terraform/confluent` apply. Creates two provider integrations (S3, Glue) and outputs their `*_iam_role_arn` and `*_external_id`.
3. `terraform/aws` re-apply with the real trust:

```bash
cd terraform/aws
terraform apply \
  -var="confluent_pi_principal_arn=$(terraform -chdir=../confluent output -raw provider_integration_s3_iam_role_arn)" \
  -var="confluent_pi_external_id=$(terraform -chdir=../confluent output -raw provider_integration_s3_external_id)" \
  -var="confluent_glue_pi_principal_arn=$(terraform -chdir=../confluent output -raw provider_integration_glue_iam_role_arn)" \
  -var="confluent_glue_pi_external_id=$(terraform -chdir=../confluent output -raw provider_integration_glue_external_id)" \
  -var="kafka_cluster_id=$(terraform -chdir=../confluent output -raw kafka_cluster_id)"
```

In CI those five values are `TF_VAR_*` variables on the `prod` environment (set in Phase 2), so step 3 is the normal `tf-apply-aws.yml` run.

## Confluent root

```bash
cd terraform/confluent
export CONFLUENT_CLOUD_API_KEY=... CONFLUENT_CLOUD_API_SECRET=...   # never in a file inside the repo
terraform init && terraform plan
```

Applies run from `tf-apply-confluent.yml` with the `sa-terraform-ci` key. Sensitive outputs (`terraform output -json <name>`) are the source for the GitHub Environment secrets.

## Provider pins

- `hashicorp/aws` 6.66.0
- `confluentinc/confluent` 2.86.0 (registry docs: https://registry.terraform.io/providers/confluentinc/confluent/2.86.0/docs)
- Terraform `>= 1.9`

## Pausing and resuming the AWS side

The AWS root has a boolean variable `idle` (default `true`). `scripts/aws-idle.sh` applies with `idle=true` (no interface VPC endpoints, runner instance stopped via `aws_ec2_instance_state`); `scripts/aws-resume.sh` applies with `idle=false` and waits for SSM. Both need the same `TF_VAR_confluent_*` / `TF_VAR_kafka_cluster_id` values as any AWS apply (from the Confluent root's outputs), or the writer trust policies would be reverted to the placeholder. Confluent resources are never touched. Details in docs/08 "AWS idle cost".
