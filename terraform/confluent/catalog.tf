# AWS Glue catalog integration (cluster level, one per cluster). Publishes Iceberg metadata
# pointers for every Tableflow-enabled topic into a Glue database named after the cluster ID.
# Delta tables are not registered (Glue sync is Iceberg-only; docs/adr/0002).

resource "confluent_catalog_integration" "glue" {
  environment {
    id = confluent_environment.demo.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.demo.id
  }
  display_name = "${var.name_prefix}-tableflow-glue"

  aws_glue {
    provider_integration_id = confluent_provider_integration.glue.id
  }

  credentials {
    key    = var.tableflow_api_key
    secret = var.tableflow_api_secret
  }

  depends_on = [confluent_tableflow_topic.orders_clean]

  lifecycle {
    prevent_destroy = true
  }
}

output "catalog_integration_glue" {
  value = {
    id        = confluent_catalog_integration.glue.id
    suspended = confluent_catalog_integration.glue.suspended
  }
}
