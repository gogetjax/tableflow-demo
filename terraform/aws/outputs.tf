output "account_id" {
  value = local.account_id
}

output "region" {
  value = var.region
}

output "lake_bucket_name" {
  value = aws_s3_bucket.lake.bucket
}

output "lake_bucket_arn" {
  value = aws_s3_bucket.lake.arn
}

output "tableflow_writer_role_arn" {
  value = aws_iam_role.tableflow_writer.arn
}

output "tableflow_glue_writer_role_arn" {
  value = aws_iam_role.tableflow_glue_writer.arn
}

output "consumer_iceberg_role_arn" {
  value = aws_iam_role.consumer_iceberg.arn
}

output "consumer_delta_role_arn" {
  value = aws_iam_role.consumer_delta.arn
}

output "github_actions_terraform_role_arn" {
  value = aws_iam_role.github_actions_terraform.arn
}

output "github_actions_consumers_role_arn" {
  value = aws_iam_role.github_actions_consumers.arn
}

output "consumer_vpc_id" {
  value = aws_vpc.consumers.id
}

output "consumer_subnet_id" {
  value = aws_subnet.consumers_private.id
}

output "consumer_security_group_id" {
  value = aws_security_group.consumers.id
}

output "glue_database_arn_pattern" {
  value = local.glue_database_arn
}

output "writer_trust_is_real" {
  description = "false until the Confluent provider integration principal and external ID are supplied."
  value       = local.pi_trust_ready
}
