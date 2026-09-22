Implement `terraform/aws` per docs/07-terraform-cicd.md and docs/02-security.md.

Constraints:
- Region `us-east-1`. Provider `hashicorp/aws` pinned to an exact version; Terraform `required_version >= 1.9`.
- Remote state: S3 backend with a DynamoDB lock table. Bootstrap those two with a tiny separate root at `terraform/bootstrap` that uses local state, documented in `terraform/README.md`.
- Resources: bucket `tableflow-demo-lake-${account_id}` (versioning on, Block Public Access all, bucket-owner-enforced, SSE-S3 for now, `force_destroy = true` with a comment that this is demo-only, **no lifecycle rules**); roles `tableflow-writer`, `tableflow-glue-writer` with a placeholder trust policy that trusts nothing (`Deny` or an empty principal pattern that validates) and a `var.confluent_pi_principal_arn` / `var.confluent_pi_external_id` pair that, when set, produces the real trust; roles `consumer-iceberg`, `consumer-delta` with the exact permission sets in docs/02-security.md; OIDC provider and role `github-actions-terraform` trusting `repo:gogetjax/tableflow-demo:environment:prod`; a second OIDC role `github-actions-consumers` trusting `environment:consumers` that can assume only the two consumer roles; bucket policy with the deny statements from docs/02-security.md; a VPC with one private subnet, no IGW, no NAT, S3 gateway endpoint, Glue interface endpoint, and a security group for consumer runs.
- Glue: do not create the database. Reference it by the ARN pattern `arn:aws:glue:us-east-1:${account_id}:database/${var.kafka_cluster_id}` with `kafka_cluster_id` as a variable defaulting to `"*"` until Phase 2 supplies the real ID. Explain this in a comment.
- Outputs: every role ARN, bucket name, subnet and SG IDs.

Before writing IAM policies for `tableflow-writer` and `tableflow-glue-writer`, open the Confluent BYOS S3 quick start and the Glue integration page (URLs in docs/00-index.md) and copy the verbs they list. Record the URLs and the verb list in docs/09-open-questions.md under Q8.

Add `.github/workflows/tf-plan.yml` and `tf-apply-aws.yml` per docs/07. Run `terraform fmt -check`, `validate`, and a plan locally (AWS creds are in my environment); paste the plan summary in the PR. Do not apply locally. Open PR "Phase 1: AWS foundation".
