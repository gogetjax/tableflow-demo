data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "tableflow-demo-lake-${local.account_id}"

  # Tableflow creates the Glue database itself, named after the Kafka cluster ID.
  # Terraform never creates it; it only grants permissions on the ARN pattern.
  # Until Phase 2 supplies kafka_cluster_id, the pattern is a wildcard so policies validate.
  glue_catalog_arn  = "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:catalog"
  glue_database_arn = "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:database/${var.kafka_cluster_id}"
  glue_table_arn    = "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:table/${var.kafka_cluster_id}/*"
}

# ---------------------------------------------------------------------------
# Lake bucket. Empty at Tableflow enablement; Tableflow owns every object.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "lake" {
  bucket = local.bucket_name

  # DEMO ONLY. Lets `terraform destroy` empty the bucket. Remove for anything real.
  force_destroy = true

  # No lifecycle rules by design: Tableflow manages snapshot expiry and compaction.
  # A lifecycle rule would delete files still referenced by table metadata.
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = false
  }
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bucket policy per docs/02-security.md "Bucket policy".
data "aws_iam_policy_document" "lake" {
  # 1. Only the Tableflow writer (and Terraform, for teardown) may write or delete.
  statement {
    sid    = "DenyWritesExceptTableflowAndTerraform"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${aws_s3_bucket.lake.arn}/*"]
    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values = [
        aws_iam_role.tableflow_writer.arn,
        aws_iam_role.github_actions_terraform.arn,
      ]
    }
  }

  # 2. TLS only.
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.lake.arn, "${aws_s3_bucket.lake.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # 3. Reject any explicit request for an encryption mode other than SSE-S3 / SSE-KMS.
  #    Requests with no header fall through to bucket default encryption (AES256). Tableflow
  #    sends no header, so the two conditions below (ANDed) deny only when the header is
  #    present AND not an allowed value. Note: "StringNotEqualsIfExists" alone evaluates to
  #    TRUE when the key is absent and denied every Tableflow write (Phase 5 finding).
  statement {
    sid    = "DenyUnencryptedPutHeader"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.lake.arn}/*"]
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["false"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256", "aws:kms"]
    }
  }

  # 4. Read access for the two consumer roles.
  statement {
    sid    = "AllowConsumerRead"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.consumer_iceberg.arn,
        aws_iam_role.consumer_delta.arn,
      ]
    }
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.lake.arn, "${aws_s3_bucket.lake.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "lake" {
  bucket = aws_s3_bucket.lake.id
  policy = data.aws_iam_policy_document.lake.json

  depends_on = [aws_s3_bucket_public_access_block.lake]
}
