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

The Confluent provider integration needs the `tableflow-writer` role ARN to exist, and the role's trust policy needs the provider integration's IAM principal and external ID. So:

1. `terraform/aws` apply with default variables. Writer roles get a deny-all placeholder trust policy.
2. `terraform/confluent` apply. Creates the provider integration and outputs `provider_integration_iam_role_arn` and `provider_integration_external_id`.
3. `terraform/aws` re-apply with the real trust:

```bash
cd terraform/aws
terraform apply \
  -var="confluent_pi_principal_arn=$(terraform -chdir=../confluent output -raw provider_integration_iam_role_arn)" \
  -var="confluent_pi_external_id=$(terraform -chdir=../confluent output -raw provider_integration_external_id)" \
  -var="kafka_cluster_id=$(terraform -chdir=../confluent output -raw kafka_cluster_id)"
```

In CI those three values are set as `TF_VAR_*` variables on the `prod` environment after step 2, so step 3 is a normal apply.

## Provider pins

- `hashicorp/aws` 6.66.0
- `confluentinc/confluent` 2.86.0 (registry docs: https://registry.terraform.io/providers/confluentinc/confluent/2.86.0/docs)
- Terraform `>= 1.9`
