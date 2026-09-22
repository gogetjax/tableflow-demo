terraform {
  required_version = ">= 1.9"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.86.0"
    }
  }

  backend "s3" {
    bucket         = "tableflow-demo-tfstate-706193894984"
    key            = "confluent/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tableflow-demo-tflock"
    encrypt        = true
  }
}

# Auth: CONFLUENT_CLOUD_API_KEY / CONFLUENT_CLOUD_API_SECRET from the environment.
# Locally (bootstrap): a Cloud API key for the human admin, exported in the shell only.
# In CI: the sa-terraform-ci Cloud API key from the `prod` GitHub Environment.
provider "confluent" {}

# AWS root outputs: writer role ARNs and bucket name.
data "terraform_remote_state" "aws" {
  backend = "s3"
  config = {
    bucket = "tableflow-demo-tfstate-706193894984"
    key    = "aws/terraform.tfstate"
    region = "us-east-1"
  }
}
