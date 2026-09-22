# Roles assumed by Confluent through the provider integration.
#
# Two-pass trust: on the first apply confluent_pi_principal_arn is empty and the roles get a
# deny-all placeholder (the shape Confluent's own guide uses:
# https://docs.confluent.io/cloud/current/integrations/provider-integrations/create-provider-integration-aws.html).
# After the provider integration exists, re-apply with the principal ARN and external ID.

locals {
  glue_pi_principal_arn = var.confluent_glue_pi_principal_arn != "" ? var.confluent_glue_pi_principal_arn : var.confluent_pi_principal_arn
  glue_pi_external_id   = var.confluent_glue_pi_external_id != "" ? var.confluent_glue_pi_external_id : var.confluent_pi_external_id

  pi_trust_ready = var.confluent_pi_principal_arn != "" && var.confluent_pi_external_id != ""

  # Trust documents rendered as JSON. Shape from the Confluent provider-integration guide:
  # AssumeRole with sts:ExternalId, plus TagSession for the same principal.
  pi_trust_placeholder = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Principal = { AWS = "*" }
      Action    = "sts:AssumeRole"
    }]
  })

  pi_trust_s3 = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = var.confluent_pi_principal_arn }
        Action    = "sts:AssumeRole"
        Condition = { StringEquals = { "sts:ExternalId" = var.confluent_pi_external_id } }
      },
      {
        Effect    = "Allow"
        Principal = { AWS = var.confluent_pi_principal_arn }
        Action    = "sts:TagSession"
      },
    ]
  })

  pi_trust_glue = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = local.glue_pi_principal_arn }
        Action    = "sts:AssumeRole"
        Condition = { StringEquals = { "sts:ExternalId" = local.glue_pi_external_id } }
      },
      {
        Effect    = "Allow"
        Principal = { AWS = local.glue_pi_principal_arn }
        Action    = "sts:TagSession"
      },
    ]
  })

  writer_trust_json      = local.pi_trust_ready ? local.pi_trust_s3 : local.pi_trust_placeholder
  glue_writer_trust_json = local.pi_trust_ready ? local.pi_trust_glue : local.pi_trust_placeholder
}

# --- tableflow-writer: S3 only ------------------------------------------------
# Verbs copied from Confluent "Configure Storage for Tableflow", Amazon S3 section
# (https://docs.confluent.io/cloud/current/topics/tableflow/how-to-guides/configure-storage.html).
# Recorded under docs/09-open-questions.md Q8.

resource "aws_iam_role" "tableflow_writer" {
  name               = "tableflow-writer"
  description        = "Assumed by Confluent Tableflow via provider integration. S3 write to the lake bucket only."
  assume_role_policy = local.writer_trust_json
}

data "aws_iam_policy_document" "tableflow_writer" {
  statement {
    sid    = "BucketLevel"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.lake.arn]
  }
  statement {
    sid    = "ObjectLevel"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.lake.arn}/*"]
  }
}

resource "aws_iam_policy" "tableflow_writer" {
  name   = "tableflow-demo-tableflow-writer"
  policy = data.aws_iam_policy_document.tableflow_writer.json
}

resource "aws_iam_role_policy_attachment" "tableflow_writer" {
  role       = aws_iam_role.tableflow_writer.name
  policy_arn = aws_iam_policy.tableflow_writer.arn
}

# --- tableflow-glue-writer: Glue only -----------------------------------------
# Confluent does not publish the Glue verb list; the Console generates a policy template
# per catalog integration. This set is the superset from docs/02-security.md and is
# diffed against the Console template in Phase 5 (Q8).

resource "aws_iam_role" "tableflow_glue_writer" {
  name               = "tableflow-glue-writer"
  description        = "Assumed by Confluent Tableflow via provider integration. Glue catalog sync only."
  assume_role_policy = local.glue_writer_trust_json
}

data "aws_iam_policy_document" "tableflow_glue_writer" {
  statement {
    sid    = "GlueCatalogSync"
    effect = "Allow"
    actions = [
      "glue:CreateDatabase",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:CreateTable",
      "glue:GetTable",
      "glue:GetTables",
      "glue:UpdateTable",
      "glue:DeleteTable",
    ]
    resources = [
      local.glue_catalog_arn,
      local.glue_database_arn,
      local.glue_table_arn,
    ]
  }
}

resource "aws_iam_policy" "tableflow_glue_writer" {
  name   = "tableflow-demo-tableflow-glue-writer"
  policy = data.aws_iam_policy_document.tableflow_glue_writer.json
}

resource "aws_iam_role_policy_attachment" "tableflow_glue_writer" {
  role       = aws_iam_role.tableflow_glue_writer.name
  policy_arn = aws_iam_policy.tableflow_glue_writer.arn
}
