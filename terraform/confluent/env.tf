# Environment, Schema Registry (auto-provisioned by stream_governance), Kafka cluster.
#
# Cluster type: Standard. Tableflow is supported on every cluster type in AWS us-east-1
# (https://docs.confluent.io/cloud/current/topics/tableflow/operate/cloud-regions.html).
# Basic is cheaper but rejects topic-scoped RBAC roles ("Basic Clusters can not use
# resource roles"), which the docs/02 least-privilege model depends on.

data "confluent_organization" "current" {}

resource "confluent_environment" "demo" {
  display_name = "${var.name_prefix}-tableflow-demo"

  stream_governance {
    package = "ESSENTIALS"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "confluent_schema_registry_cluster" "sr" {
  environment {
    id = confluent_environment.demo.id
  }
  depends_on = [confluent_environment.demo]
}

resource "confluent_kafka_cluster" "demo" {
  display_name = "${var.name_prefix}-tableflow-demo"
  availability = "SINGLE_ZONE"
  cloud        = "AWS"
  region       = var.region
  standard {}

  environment {
    id = confluent_environment.demo.id
  }

  lifecycle {
    prevent_destroy = true
  }
}
