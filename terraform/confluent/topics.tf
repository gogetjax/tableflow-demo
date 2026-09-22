# Topics. Managed with the sa-terraform-ci Kafka key (CloudClusterAdmin via EnvironmentAdmin).

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

resource "confluent_kafka_topic" "orders_clean" {
  kafka_cluster {
    id = confluent_kafka_cluster.demo.id
  }
  topic_name       = "orders.clean"
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

resource "confluent_kafka_topic" "orders_rejected" {
  kafka_cluster {
    id = confluent_kafka_cluster.demo.id
  }
  topic_name       = "orders.rejected"
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
