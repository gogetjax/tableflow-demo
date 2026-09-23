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

variable "github_repo_immutable" {
  description = <<-EOT
    The repo's immutable OIDC subject prefix, owner@id/repo@id. GitHub emits this form when
    "use_immutable_subject" is on (GET /repos/{o}/{r}/actions/oidc/customization/sub).
    Both this and the plain form are accepted in the trust policies.
  EOT
  type        = string
  default     = "gogetjax@180248147/tableflow-demo@1382245757"
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

variable "confluent_glue_pi_principal_arn" {
  description = "IAM principal of the second provider integration (Glue). Falls back to confluent_pi_principal_arn when empty."
  type        = string
  default     = ""
}

variable "confluent_glue_pi_external_id" {
  description = "External ID of the second provider integration (Glue). Falls back to confluent_pi_external_id when empty."
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

variable "idle" {
  description = <<-EOT
    true (default) keeps the billable demo pieces off: no interface VPC endpoints and the
    consumer runner instance stopped. scripts/aws-resume.sh applies with -var idle=false;
    scripts/aws-idle.sh applies with the default. A fresh CI apply therefore never turns
    anything on. Everything else (VPC, S3 gateway endpoint, IAM, buckets, Glue, CloudTrail)
    exists in both states.
  EOT
  type        = bool
  default     = true
}
