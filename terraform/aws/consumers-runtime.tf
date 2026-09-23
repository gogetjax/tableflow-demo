# Phase 6: where the consumers actually run, and the extra read paths.
#
# - Athena workgroup + results bucket for the Iceberg-via-Glue consumer.
# - SSM interface endpoints so an instance in the isolated subnet is reachable without any
#   internet route (the proof of isolation). All interface endpoints and the instance's running
#   state are gated by var.idle (default true = off).
# - A "tooling" bucket reachable through the S3 gateway endpoint that carries the consumer
#   scripts and a Python wheelhouse, because the subnet has no route to PyPI.
# - The runner instance (Amazon Linux 2023, SSM-managed) with an instance profile that can
#   assume only the two consumer roles.

# --- Athena ------------------------------------------------------------------------

resource "aws_s3_bucket" "athena_results" {
  bucket        = "tableflow-demo-athena-results-${local.account_id}"
  force_destroy = true # demo only
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_athena_workgroup" "consumers" {
  name          = "tableflow-demo-consumers"
  force_destroy = true
  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}

# consumer-iceberg: Athena on the dedicated workgroup + its results bucket (docs/02).
data "aws_iam_policy_document" "consumer_iceberg_athena" {
  statement {
    sid    = "AthenaQueries"
    effect = "Allow"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
      "athena:GetWorkGroup",
      "athena:ListQueryExecutions",
    ]
    resources = [aws_athena_workgroup.consumers.arn]
  }
  statement {
    sid       = "AthenaResultsBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.athena_results.arn]
  }
  statement {
    sid       = "AthenaResultsObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload"]
    resources = ["${aws_s3_bucket.athena_results.arn}/*"]
  }
}

resource "aws_iam_policy" "consumer_iceberg_athena" {
  name   = "tableflow-demo-consumer-iceberg-athena"
  policy = data.aws_iam_policy_document.consumer_iceberg_athena.json
}

resource "aws_iam_role_policy_attachment" "consumer_iceberg_athena" {
  role       = aws_iam_role.consumer_iceberg.name
  policy_arn = aws_iam_policy.consumer_iceberg_athena.arn
}

# --- SSM endpoints (no internet route in the subnet) ------------------------------

resource "aws_vpc_endpoint" "ssm" {
  for_each            = var.idle ? toset([]) : toset(["ssm", "ssmmessages", "ec2messages"])
  vpc_id              = aws_vpc.consumers.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.consumers_private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "tableflow-demo-${each.key}" }
}

# STS is needed for the instance to assume the consumer roles from inside the subnet.
resource "aws_vpc_endpoint" "sts" {
  count               = var.idle ? 0 : 1
  vpc_id              = aws_vpc.consumers.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.consumers_private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "tableflow-demo-sts" }
}

# Athena runs on its own interface endpoint as well.
resource "aws_vpc_endpoint" "athena" {
  count               = var.idle ? 0 : 1
  vpc_id              = aws_vpc.consumers.id
  service_name        = "com.amazonaws.${var.region}.athena"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.consumers_private.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "tableflow-demo-athena" }
}

# --- tooling bucket: scripts + wheelhouse, read via the S3 gateway endpoint ----------

resource "aws_s3_bucket" "tooling" {
  bucket        = "tableflow-demo-tooling-${local.account_id}"
  force_destroy = true # demo only
}

resource "aws_s3_bucket_public_access_block" "tooling" {
  bucket                  = aws_s3_bucket.tooling.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- runner instance ----------------------------------------------------------------

data "aws_iam_policy_document" "runner_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "consumer_runner" {
  name               = "tableflow-demo-consumer-runner"
  description        = "Instance role for the isolated consumer runner. Can only assume the consumer roles and read the tooling bucket."
  assume_role_policy = data.aws_iam_policy_document.runner_trust.json
}

data "aws_iam_policy_document" "consumer_runner" {
  statement {
    sid       = "AssumeConsumerRoles"
    effect    = "Allow"
    actions   = ["sts:AssumeRole", "sts:TagSession"]
    resources = [aws_iam_role.consumer_iceberg.arn, aws_iam_role.consumer_delta.arn]
  }
  statement {
    sid       = "ToolingRead"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetObject"]
    resources = [aws_s3_bucket.tooling.arn, "${aws_s3_bucket.tooling.arn}/*"]
  }
}

resource "aws_iam_policy" "consumer_runner" {
  name   = "tableflow-demo-consumer-runner"
  policy = data.aws_iam_policy_document.consumer_runner.json
}

resource "aws_iam_role_policy_attachment" "consumer_runner" {
  role       = aws_iam_role.consumer_runner.name
  policy_arn = aws_iam_policy.consumer_runner.arn
}

resource "aws_iam_role_policy_attachment" "consumer_runner_ssm" {
  role       = aws_iam_role.consumer_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "consumer_runner" {
  name = "tableflow-demo-consumer-runner"
  role = aws_iam_role.consumer_runner.name
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "consumer_runner" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = "t3.large" # Spark local mode for the Delta reader needs ~2 GB heap
  subnet_id                   = aws_subnet.consumers_private.id
  vpc_security_group_ids      = [aws_security_group.consumers.id]
  iam_instance_profile        = aws_iam_instance_profile.consumer_runner.name
  associate_public_ip_address = false
  metadata_options {
    http_tokens = "required"
  }
  root_block_device {
    volume_size = 16
    encrypted   = true
  }
  tags = { Name = "tableflow-demo-consumer-runner" }
}

# Running state follows var.idle. The instance itself stays defined (and its EBS volume with
# the venv/JDK/jars survives) in both states.
resource "aws_ec2_instance_state" "consumer_runner" {
  instance_id = aws_instance.consumer_runner.id
  state       = var.idle ? "stopped" : "running"
}

output "consumer_runner_instance_id" {
  value = aws_instance.consumer_runner.id
}

output "tooling_bucket_name" {
  value = aws_s3_bucket.tooling.bucket
}

output "athena_workgroup" {
  value = aws_athena_workgroup.consumers.name
}
