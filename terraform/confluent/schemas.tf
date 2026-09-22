# Schema Registry subjects for orders.raw, from ../../schemas/*.avsc (source of truth).
# orders.clean-* and orders.rejected-* are registered by Flink in Phase 4.

locals {
  sr_credentials = {
    key    = confluent_api_key.terraform_ci_sr.id
    secret = confluent_api_key.terraform_ci_sr.secret
  }
}

resource "confluent_schema" "orders_raw_key" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.sr.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.sr.rest_endpoint
  subject_name  = "orders.raw-key"
  format        = "AVRO"
  schema        = file("${path.module}/../../schemas/orders.raw-key.avsc")
  credentials {
    key    = local.sr_credentials.key
    secret = local.sr_credentials.secret
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_schema" "orders_raw_value" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.sr.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.sr.rest_endpoint
  subject_name  = "orders.raw-value"
  format        = "AVRO"
  schema        = file("${path.module}/../../schemas/orders.raw-value.avsc")
  credentials {
    key    = local.sr_credentials.key
    secret = local.sr_credentials.secret
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "confluent_subject_config" "orders_raw_key" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.sr.id
  }
  rest_endpoint       = data.confluent_schema_registry_cluster.sr.rest_endpoint
  subject_name        = confluent_schema.orders_raw_key.subject_name
  compatibility_level = "BACKWARD"
  credentials {
    key    = local.sr_credentials.key
    secret = local.sr_credentials.secret
  }
}

resource "confluent_subject_config" "orders_raw_value" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.sr.id
  }
  rest_endpoint       = data.confluent_schema_registry_cluster.sr.rest_endpoint
  subject_name        = confluent_schema.orders_raw_value.subject_name
  compatibility_level = "BACKWARD"
  credentials {
    key    = local.sr_credentials.key
    secret = local.sr_credentials.secret
  }
}
