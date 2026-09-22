variable "region" {
  description = "Must match the Confluent Kafka cluster region. Tableflow requires bucket and cluster in the same region."
  type        = string
  default     = "us-east-1"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the OIDC roles, as owner/name."
  type        = string
  default     = "gogetjax/tableflow-demo"
}

variable "confluent_pi_principal_arn" {
  description = <<-EOT
    IAM role ARN Confluent hands back after the provider integration is created
    (aws.iam_role_arn on confluent_provider_integration). Empty on the first apply,
    which installs a deny-all placeholder trust policy on the writer roles.
  EOT
  type        = string
  default     = ""
}

variable "confluent_pi_external_id" {
  description = "External ID from the provider integration (aws.external_id). Empty on the first apply."
  type        = string
  default     = ""
}

variable "kafka_cluster_id" {
  description = <<-EOT
    Confluent Kafka cluster ID (lkc-xxxxx). Tableflow names the Glue database after it.
    Defaults to "*" so Glue policies validate before the cluster exists (Phase 2 supplies the real ID).
  EOT
  type        = string
  default     = "*"
}

variable "consumer_trusted_principal_arns" {
  description = <<-EOT
    Extra IAM principals allowed to assume the consumer roles, in addition to the
    github-actions-consumers role. Used for local verification runs.
  EOT
  type        = list(string)
  default     = []
}
