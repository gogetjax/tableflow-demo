# Tableflow on orders.clean: BYOS (the lake bucket), both table formats, Glue-synced.
# Argument names verified against provider 2.86.0 docs (docs/09 Q2). The Tableflow API key is
# a sa-terraform-ci key created by hand (like the Cloud key) and passed as TF_VAR_* variables.

variable "tableflow_api_key" {
  type      = string
  sensitive = true
}

variable "tableflow_api_secret" {
  type      = string
  sensitive = true
}

resource "confluent_tableflow_topic" "orders_clean" {
  environment {
    id = confluent_environment.demo.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.demo.id
  }
  display_name = "orders.clean"

  # Q1: dual format expressed as a list on the Terraform resource.
  table_formats = ["ICEBERG", "DELTA"]

  # 7 days of snapshot/version history (docs/05).
  retention_ms = var.topic_retention_ms

  byob_aws {
    bucket_name             = data.terraform_remote_state.aws.outputs.lake_bucket_name
    provider_integration_id = confluent_provider_integration.s3.id
  }

  # Q7: LOG keeps materialization alive and routes bad rows to a DLQ topic.
  error_handling {
    mode       = "LOG"
    log_target = confluent_kafka_topic.orders_tableflow_errors.topic_name
  }

  credentials {
    key    = var.tableflow_api_key
    secret = var.tableflow_api_secret
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "tableflow_orders_clean" {
  description = "Tableflow attributes for orders.clean (Q4: table_path is where the data lands)."
  value = {
    table_path          = confluent_tableflow_topic.orders_clean.table_path
    write_mode          = confluent_tableflow_topic.orders_clean.write_mode
    suspended           = confluent_tableflow_topic.orders_clean.suspended
    enable_compaction   = confluent_tableflow_topic.orders_clean.enable_compaction
    enable_partitioning = confluent_tableflow_topic.orders_clean.enable_partitioning
    bucket_region       = confluent_tableflow_topic.orders_clean.byob_aws[0].bucket_region
  }
}
