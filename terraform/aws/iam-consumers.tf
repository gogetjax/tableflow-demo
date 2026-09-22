# Consumer roles per docs/02-security.md. AWS-only; nothing here references Confluent.

data "aws_iam_policy_document" "consumer_trust" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = concat(
        [aws_iam_role.github_actions_consumers.arn],
        var.consumer_trusted_principal_arns,
      )
    }
    actions = ["sts:AssumeRole", "sts:TagSession"]
  }
}

# --- consumer-iceberg: Glue read + S3 read -------------------------------------

resource "aws_iam_role" "consumer_iceberg" {
  name               = "consumer-iceberg"
  description        = "Reads the Tableflow Iceberg table through Glue Data Catalog and S3."
  assume_role_policy = data.aws_iam_policy_document.consumer_trust.json
}

data "aws_iam_policy_document" "consumer_iceberg" {
  statement {
    sid    = "GlueRead"
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartitions",
    ]
    resources = [
      local.glue_catalog_arn,
      local.glue_database_arn,
      local.glue_table_arn,
    ]
  }
  statement {
    sid       = "S3List"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.lake.arn]
  }
  statement {
    sid       = "S3Read"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.lake.arn}/*"]
  }
}

resource "aws_iam_policy" "consumer_iceberg" {
  name   = "tableflow-demo-consumer-iceberg"
  policy = data.aws_iam_policy_document.consumer_iceberg.json
}

resource "aws_iam_role_policy_attachment" "consumer_iceberg" {
  role       = aws_iam_role.consumer_iceberg.name
  policy_arn = aws_iam_policy.consumer_iceberg.arn
}

# --- consumer-delta: S3 read only ----------------------------------------------
# The proof that Delta needs no catalog.

resource "aws_iam_role" "consumer_delta" {
  name               = "consumer-delta"
  description        = "Reads the Tableflow Delta table by S3 path. No catalog access."
  assume_role_policy = data.aws_iam_policy_document.consumer_trust.json
}

data "aws_iam_policy_document" "consumer_delta" {
  statement {
    sid       = "S3List"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.lake.arn]
  }
  statement {
    sid       = "S3Read"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.lake.arn}/*"]
  }
}

resource "aws_iam_policy" "consumer_delta" {
  name   = "tableflow-demo-consumer-delta"
  policy = data.aws_iam_policy_document.consumer_delta.json
}

resource "aws_iam_role_policy_attachment" "consumer_delta" {
  role       = aws_iam_role.consumer_delta.name
  policy_arn = aws_iam_policy.consumer_delta.arn
}
