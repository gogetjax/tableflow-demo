terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.66.0"
    }
  }

  backend "s3" {
    bucket         = "tableflow-demo-tfstate-706193894984"
    key            = "aws/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tableflow-demo-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = "tableflow-demo"
      managed = "terraform"
      root    = "aws"
    }
  }
}
