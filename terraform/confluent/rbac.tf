# Service accounts, role bindings (docs/02-security.md table), and API keys.
#
# Display names carry the name_prefix; the docs refer to them by their unprefixed role
# (sa-shadowtraffic, sa-flink, sa-terraform-ci).

locals {
  kafka_crn = "${confluent_kafka_cluster.demo.rbac_crn}/kafka=${confluent_kafka_cluster.demo.id}"
  sr_crn    = data.confluent_schema_registry_cluster.sr.resource_name
}

# --- service accounts ----------------------------------------------------------

resource "confluent_service_account" "shadowtraffic" {
  display_name = "${var.name_prefix}-sa-shadowtraffic"
  description  = "tableflow-demo: ShadowTraffic producer for orders.raw"
}

resource "confluent_service_account" "flink" {
  display_name = "${var.name_prefix}-sa-flink"
  description  = "tableflow-demo: runs the Flink cleaning statements"
}

resource "confluent_service_account" "terraform_ci" {
  display_name = "${var.name_prefix}-sa-terraform-ci"
  description  = "tableflow-demo: Terraform from GitHub Actions"
}

# --- sa-shadowtraffic ------------------------------------------------------------

resource "confluent_role_binding" "shadowtraffic_write_raw" {
  principal   = "User:${confluent_service_account.shadowtraffic.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.kafka_crn}/topic=${confluent_kafka_topic.orders_raw.topic_name}"
}

resource "confluent_role_binding" "shadowtraffic_read_raw_subjects" {
  principal   = "User:${confluent_service_account.shadowtraffic.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.sr_crn}/subject=orders.raw-*"
}

# ShadowTraffic (2.1.4) always calls Schema Registry "register" for the schema it will
# produce with, even when the subject exists and the serializer has auto.register.schemas=false.
# Registering a byte-identical schema returns the existing ID and creates no new version, but
# the call itself needs Write. Terraform stays the source of truth: the avroSchemaHint loads the
# same .avsc Terraform registered, and the Phase 3 acceptance check is "still version 1".
resource "confluent_role_binding" "shadowtraffic_write_raw_subjects" {
  principal   = "User:${confluent_service_account.shadowtraffic.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.sr_crn}/subject=orders.raw-*"
}

# --- sa-flink ------------------------------------------------------------------------

resource "confluent_role_binding" "flink_developer" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_environment.demo.resource_name
}

resource "confluent_role_binding" "flink_read_raw" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.kafka_crn}/topic=${confluent_kafka_topic.orders_raw.topic_name}"
}

# Flink CREATE TABLE creates the sink topics, which needs DeveloperManage on the topic name
# ("Permission denied to CREATE on Kafka topic" otherwise).
resource "confluent_role_binding" "flink_manage_clean" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperManage"
  crn_pattern = "${local.kafka_crn}/topic=orders.clean"
}

resource "confluent_role_binding" "flink_manage_rejected" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperManage"
  crn_pattern = "${local.kafka_crn}/topic=orders.rejected"
}

# Read on the sink topics so verification queries (and any later downstream statement) can
# run as sa-flink; Flink refuses to read a table without it ("enable 'read' access mode").
resource "confluent_role_binding" "flink_read_clean" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.kafka_crn}/topic=orders.clean"
}

resource "confluent_role_binding" "flink_read_rejected" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.kafka_crn}/topic=orders.rejected"
}

resource "confluent_role_binding" "flink_write_clean" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.kafka_crn}/topic=orders.clean"
}

resource "confluent_role_binding" "flink_write_rejected" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.kafka_crn}/topic=orders.rejected"
}

# Flink writes with Kafka transactions (exactly-once). Required per
# https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html
# ("Transactional Id authorization failed" otherwise).
resource "confluent_role_binding" "flink_txn_read" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.kafka_crn}/transactional-id=_confluent-flink_*"
}

resource "confluent_role_binding" "flink_txn_write" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.kafka_crn}/transactional-id=_confluent-flink_*"
}

resource "confluent_role_binding" "flink_read_raw_subjects" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${local.sr_crn}/subject=orders.raw-*"
}

resource "confluent_role_binding" "flink_write_clean_subjects" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.sr_crn}/subject=orders.clean-*"
}

resource "confluent_role_binding" "flink_write_rejected_subjects" {
  principal   = "User:${confluent_service_account.flink.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${local.sr_crn}/subject=orders.rejected-*"
}

# --- sa-terraform-ci -----------------------------------------------------------------

resource "confluent_role_binding" "terraform_ci_env_admin" {
  principal   = "User:${confluent_service_account.terraform_ci.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.demo.resource_name
}

# Lets CI submit Flink statements that run as sa-flink (Phase 4).
resource "confluent_role_binding" "terraform_ci_assigner_flink_sa" {
  principal   = "User:${confluent_service_account.terraform_ci.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.current.resource_name}/service-account=${confluent_service_account.flink.id}"
}

# --- API keys ---------------------------------------------------------------------------
# Secrets live in Terraform state (encrypted S3) and in sensitive outputs. They are copied
# to GitHub Environment secrets by the phase runbook and never written to the repo.

# The sa-terraform-ci Cloud API key is NOT managed here. A service account cannot read
# Cloud API keys through the API (only cluster-scoped ones), so when CI runs as that SA
# Terraform sees the key as missing and tries to recreate it (403). Create it once by hand:
#   confluent api-key create --resource cloud --service-account <sa-terraform-ci id>
# and store it in the prod GitHub Environment (terraform/README.md).

# Kafka + SR keys for CI, used by topic/schema resources in this root.
resource "confluent_api_key" "terraform_ci_kafka" {
  display_name = "${var.name_prefix}-sa-terraform-ci-kafka"
  description  = "tableflow-demo: Kafka API key for Terraform topic management"
  owner {
    id          = confluent_service_account.terraform_ci.id
    api_version = confluent_service_account.terraform_ci.api_version
    kind        = confluent_service_account.terraform_ci.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.demo.id
    api_version = confluent_kafka_cluster.demo.api_version
    kind        = confluent_kafka_cluster.demo.kind
    environment {
      id = confluent_environment.demo.id
    }
  }
  depends_on = [confluent_role_binding.terraform_ci_env_admin]
}

resource "confluent_api_key" "terraform_ci_sr" {
  display_name = "${var.name_prefix}-sa-terraform-ci-sr"
  description  = "tableflow-demo: Schema Registry API key for Terraform subject management"
  owner {
    id          = confluent_service_account.terraform_ci.id
    api_version = confluent_service_account.terraform_ci.api_version
    kind        = confluent_service_account.terraform_ci.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.demo.id
    }
  }
  depends_on = [confluent_role_binding.terraform_ci_env_admin]
}

# Producer keys.
resource "confluent_api_key" "shadowtraffic_kafka" {
  display_name = "${var.name_prefix}-sa-shadowtraffic-kafka"
  description  = "tableflow-demo: ShadowTraffic Kafka key"
  owner {
    id          = confluent_service_account.shadowtraffic.id
    api_version = confluent_service_account.shadowtraffic.api_version
    kind        = confluent_service_account.shadowtraffic.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.demo.id
    api_version = confluent_kafka_cluster.demo.api_version
    kind        = confluent_kafka_cluster.demo.kind
    environment {
      id = confluent_environment.demo.id
    }
  }
}

resource "confluent_api_key" "shadowtraffic_sr" {
  display_name = "${var.name_prefix}-sa-shadowtraffic-sr"
  description  = "tableflow-demo: ShadowTraffic Schema Registry key (lookup only)"
  owner {
    id          = confluent_service_account.shadowtraffic.id
    api_version = confluent_service_account.shadowtraffic.api_version
    kind        = confluent_service_account.shadowtraffic.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.demo.id
    }
  }
}

# Flink SA keys (Kafka + SR), for verification tooling. The Flink API key itself is
# created in Phase 4 once the statement-submission path is chosen.
resource "confluent_api_key" "flink_kafka" {
  display_name = "${var.name_prefix}-sa-flink-kafka"
  description  = "tableflow-demo: sa-flink Kafka key"
  owner {
    id          = confluent_service_account.flink.id
    api_version = confluent_service_account.flink.api_version
    kind        = confluent_service_account.flink.kind
  }
  managed_resource {
    id          = confluent_kafka_cluster.demo.id
    api_version = confluent_kafka_cluster.demo.api_version
    kind        = confluent_kafka_cluster.demo.kind
    environment {
      id = confluent_environment.demo.id
    }
  }
}

resource "confluent_api_key" "flink_sr" {
  display_name = "${var.name_prefix}-sa-flink-sr"
  description  = "tableflow-demo: sa-flink Schema Registry key"
  owner {
    id          = confluent_service_account.flink.id
    api_version = confluent_service_account.flink.api_version
    kind        = confluent_service_account.flink.kind
  }
  managed_resource {
    id          = data.confluent_schema_registry_cluster.sr.id
    api_version = data.confluent_schema_registry_cluster.sr.api_version
    kind        = data.confluent_schema_registry_cluster.sr.kind
    environment {
      id = confluent_environment.demo.id
    }
  }
}
