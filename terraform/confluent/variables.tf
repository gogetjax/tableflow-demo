variable "name_prefix" {
  description = "Prefix for every Confluent resource display name (org is shared; keeps the demo identifiable)."
  type        = string
  default     = "cjackson"
}

variable "region" {
  description = "Must equal the lake bucket region."
  type        = string
  default     = "us-east-1"
}

variable "topic_partitions" {
  type    = number
  default = 6
}

variable "topic_retention_ms" {
  description = "7 days."
  type        = string
  default     = "604800000"
}

variable "flink_max_cfu" {
  type    = number
  default = 5
}
