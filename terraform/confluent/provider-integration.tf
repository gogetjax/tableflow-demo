# Provider integrations (Confluent -> AWS AssumeRole).
#
# customer_role_arn must be unique per environment, and the demo splits S3 and Glue into
# two roles (docs/02), so there are two integrations. Each hands back its own IAM principal
# and external ID; both pairs go into the AWS root's trust policies (terraform/README.md).

resource "confluent_provider_integration" "s3" {
  display_name = "${var.name_prefix}-tableflow-s3"
  environment {
    id = confluent_environment.demo.id
  }
  aws {
    customer_role_arn = data.terraform_remote_state.aws.outputs.tableflow_writer_role_arn
  }
}

resource "confluent_provider_integration" "glue" {
  display_name = "${var.name_prefix}-tableflow-glue"
  environment {
    id = confluent_environment.demo.id
  }
  aws {
    customer_role_arn = data.terraform_remote_state.aws.outputs.tableflow_glue_writer_role_arn
  }
}
