output "environment_id" {
  value = confluent_environment.demo.id
}

output "kafka_cluster_id" {
  value = confluent_kafka_cluster.demo.id
}

output "kafka_bootstrap_endpoint" {
  value = confluent_kafka_cluster.demo.bootstrap_endpoint
}

output "kafka_rest_endpoint" {
  value = confluent_kafka_cluster.demo.rest_endpoint
}

output "schema_registry_id" {
  value = data.confluent_schema_registry_cluster.sr.id
}

output "schema_registry_rest_endpoint" {
  value = data.confluent_schema_registry_cluster.sr.rest_endpoint
}

output "flink_compute_pool_id" {
  value = confluent_flink_compute_pool.demo.id
}

output "service_account_ids" {
  value = {
    shadowtraffic = confluent_service_account.shadowtraffic.id
    flink         = confluent_service_account.flink.id
    terraform_ci  = confluent_service_account.terraform_ci.id
  }
}

# Provider integration handshake values for the AWS root (step 3 of the bootstrap).
output "provider_integration_s3_id" {
  value = confluent_provider_integration.s3.id
}

output "provider_integration_s3_iam_role_arn" {
  value = confluent_provider_integration.s3.aws[0].iam_role_arn
}

output "provider_integration_s3_external_id" {
  value = confluent_provider_integration.s3.aws[0].external_id
}

output "provider_integration_glue_id" {
  value = confluent_provider_integration.glue.id
}

output "provider_integration_glue_iam_role_arn" {
  value = confluent_provider_integration.glue.aws[0].iam_role_arn
}

output "provider_integration_glue_external_id" {
  value = confluent_provider_integration.glue.aws[0].external_id
}

# --- sensitive: API keys. Copied to GitHub Environment secrets, never to the repo. -----

output "shadowtraffic_kafka_api_key" {
  value     = { key = confluent_api_key.shadowtraffic_kafka.id, secret = confluent_api_key.shadowtraffic_kafka.secret }
  sensitive = true
}

output "shadowtraffic_sr_api_key" {
  value     = { key = confluent_api_key.shadowtraffic_sr.id, secret = confluent_api_key.shadowtraffic_sr.secret }
  sensitive = true
}

output "flink_kafka_api_key" {
  value     = { key = confluent_api_key.flink_kafka.id, secret = confluent_api_key.flink_kafka.secret }
  sensitive = true
}

output "flink_sr_api_key" {
  value     = { key = confluent_api_key.flink_sr.id, secret = confluent_api_key.flink_sr.secret }
  sensitive = true
}
