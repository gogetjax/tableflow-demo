# Topics owned by Terraform: orders.raw (producer source) and orders.tableflow-errors (Tableflow DLQ).
# Managed with the sa-terraform-ci Kafka key (CloudClusterAdmin via EnvironmentAdmin).

locals {
  topic_config = {
    "retention.ms"   = var.topic_retention_ms
    "cleanup.policy" = "delete"
  }
}

resource "confluent_kafka_topic" "orders_raw" {
  kafka_cluster {
    id = confluent_kafka_cluster.demo.id
  }
  topic_name       = "orders.raw"
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.demo.rest_endpoint
  config           = local.topic_config
  credentials {
    key    = confluent_api_key.terraform_ci_kafka.id
    secret = confluent_api_key.terraform_ci_kafka.secret
  }
  lifecycle {
    prevent_destroy = true
  }
}

# orders.clean and orders.rejected are NOT created here. Confluent Cloud Flink auto-infers a
# table for any existing topic, and CREATE TABLE then fails with "already exists"; the topics
# must be created by the Flink DDL in flink/00-*.sql and flink/01-*.sql so they get the
# deliberate key schema, changelog mode, and formats. See docs/04-flink-spec.md.

resource "confluent_kafka_topic" "orders_tableflow_errors" {
  kafka_cluster {
    id = confluent_kafka_cluster.demo.id
  }
  topic_name       = "orders.tableflow-errors"
  partitions_count = var.topic_partitions
  rest_endpoint    = confluent_kafka_cluster.demo.rest_endpoint
  config           = local.topic_config
  credentials {
    key    = confluent_api_key.terraform_ci_kafka.id
    secret = confluent_api_key.terraform_ci_kafka.secret
  }
  lifecycle {
    prevent_destroy = true
  }
}
