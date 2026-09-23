# GitHub Actions OIDC roles.
#
# The account already has the token.actions.githubusercontent.com OIDC provider
# (created outside this repo), so it is referenced, not created.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_arn = data.aws_iam_openid_connect_provider.github.arn
  state_bucket    = "tableflow-demo-tfstate-${local.account_id}"
  lock_table      = "tableflow-demo-tflock"
}

# --- github-actions-terraform: environment:prod ---------------------------------

data "aws_iam_policy_document" "github_terraform_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:environment:prod",
        "repo:${var.github_repo_immutable}:environment:prod",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_terraform" {
  name               = "github-actions-terraform"
  description        = "Terraform plan/apply from GitHub Actions (environment: prod)."
  assume_role_policy = data.aws_iam_policy_document.github_terraform_trust.json
}

data "aws_iam_policy_document" "github_terraform" {
  # Remote state.
  statement {
    sid       = "StateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${local.state_bucket}"]
  }
  statement {
    sid       = "StateObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/*"]
  }
  statement {
    sid       = "StateLock"
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:DescribeTable"]
    resources = ["arn:aws:dynamodb:${var.region}:${local.account_id}:table/${local.lock_table}"]
  }

  # Lake bucket: full management (create, policy, teardown). Data-plane writes are
  # still blocked for everyone but the writer by the bucket policy, except delete for teardown.
  statement {
    sid       = "LakeBucket"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${local.bucket_name}", "arn:aws:s3:::${local.bucket_name}/*"]
  }
  statement {
    sid       = "ListAllBuckets"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  # Phase 6 buckets: Athena results, tooling, CloudTrail logs (all named tableflow-demo-*).
  statement {
    sid     = "DemoSupportBuckets"
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::tableflow-demo-athena-results-${local.account_id}",
      "arn:aws:s3:::tableflow-demo-athena-results-${local.account_id}/*",
      "arn:aws:s3:::tableflow-demo-tooling-${local.account_id}",
      "arn:aws:s3:::tableflow-demo-tooling-${local.account_id}/*",
      "arn:aws:s3:::tableflow-demo-cloudtrail-${local.account_id}",
      "arn:aws:s3:::tableflow-demo-cloudtrail-${local.account_id}/*",
    ]
  }

  # Phase 6 runtime: Athena workgroup, the public AL2023 AMI parameter, the lake trail,
  # and passing the runner instance role to EC2.
  statement {
    sid       = "AthenaWorkgroup"
    effect    = "Allow"
    actions   = ["athena:*WorkGroup*", "athena:ListWorkGroups", "athena:TagResource", "athena:UntagResource", "athena:ListTagsForResource"]
    resources = ["arn:aws:athena:${var.region}:${local.account_id}:workgroup/tableflow-demo-*"]
  }
  statement {
    sid       = "AmiParameter"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.region}::parameter/aws/service/ami-amazon-linux-latest/*"]
  }
  statement {
    sid       = "LakeTrail"
    effect    = "Allow"
    actions   = ["cloudtrail:*"]
    resources = ["arn:aws:cloudtrail:${var.region}:${local.account_id}:trail/tableflow-demo-*"]
  }
  statement {
    # DescribeTrails / ListTrails do not support resource-level permissions.
    sid       = "TrailRead"
    effect    = "Allow"
    actions   = ["cloudtrail:DescribeTrails", "cloudtrail:ListTrails", "cloudtrail:GetTrailStatus", "cloudtrail:GetEventSelectors", "cloudtrail:ListTags"]
    resources = ["*"]
  }
  statement {
    sid       = "PassRunnerRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/tableflow-demo-consumer-runner"]
  }

  # IAM: only the roles and policies this root manages.
  statement {
    sid     = "IamRoles"
    effect  = "Allow"
    actions = ["iam:*Role*", "iam:*RolePolic*", "iam:ListInstanceProfilesForRole", "iam:TagRole", "iam:UntagRole"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/tableflow-writer",
      "arn:aws:iam::${local.account_id}:role/tableflow-glue-writer",
      "arn:aws:iam::${local.account_id}:role/consumer-iceberg",
      "arn:aws:iam::${local.account_id}:role/consumer-delta",
      "arn:aws:iam::${local.account_id}:role/github-actions-terraform",
      "arn:aws:iam::${local.account_id}:role/github-actions-consumers",
      "arn:aws:iam::${local.account_id}:role/tableflow-demo-*",
    ]
  }
  statement {
    sid       = "IamPolicies"
    effect    = "Allow"
    actions   = ["iam:*Policy*", "iam:TagPolicy", "iam:UntagPolicy"]
    resources = ["arn:aws:iam::${local.account_id}:policy/tableflow-demo-*"]
  }
  statement {
    sid       = "IamInstanceProfiles"
    effect    = "Allow"
    actions   = ["iam:*InstanceProfile*"]
    resources = ["arn:aws:iam::${local.account_id}:instance-profile/tableflow-demo-*"]
  }
  statement {
    sid       = "IamRead"
    effect    = "Allow"
    actions   = ["iam:GetOpenIDConnectProvider", "iam:ListOpenIDConnectProviders", "iam:GetPolicyVersion", "iam:ListPolicyVersions"]
    resources = ["*"]
  }

  # Network: VPC, subnet, endpoints, SG. EC2 resource-level scoping is impractical for a
  # VPC lifecycle in a demo account; accepted and documented in docs/02-security.md.
  statement {
    sid       = "Network"
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  # Glue: read only, for verification steps. Tableflow owns the database.
  statement {
    sid       = "GlueRead"
    effect    = "Allow"
    actions   = ["glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables"]
    resources = [local.glue_catalog_arn, local.glue_database_arn, local.glue_table_arn]
  }

  # Never allowed to read data as a consumer.
  statement {
    sid     = "DenyAssumeConsumerRoles"
    effect  = "Deny"
    actions = ["sts:AssumeRole"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/consumer-iceberg",
      "arn:aws:iam::${local.account_id}:role/consumer-delta",
    ]
  }
}

resource "aws_iam_policy" "github_actions_terraform" {
  name   = "tableflow-demo-github-actions-terraform"
  policy = data.aws_iam_policy_document.github_terraform.json
}

resource "aws_iam_role_policy_attachment" "github_actions_terraform" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.github_actions_terraform.arn
}

# --- github-actions-consumers: environment:consumers ----------------------------
# Can only assume the two consumer roles. Separate trust condition so the Terraform
# role cannot read data and this role cannot touch infrastructure.

data "aws_iam_policy_document" "github_consumers_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:environment:consumers",
        "repo:${var.github_repo_immutable}:environment:consumers",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_consumers" {
  name               = "github-actions-consumers"
  description        = "Consumer smoke tests from GitHub Actions (environment: consumers). Assumes consumer roles only."
  assume_role_policy = data.aws_iam_policy_document.github_consumers_trust.json
}

data "aws_iam_policy_document" "github_consumers" {
  statement {
    sid     = "AssumeConsumerRoles"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/consumer-iceberg",
      "arn:aws:iam::${local.account_id}:role/consumer-delta",
    ]
  }
}

resource "aws_iam_policy" "github_actions_consumers" {
  name   = "tableflow-demo-github-actions-consumers"
  policy = data.aws_iam_policy_document.github_consumers.json
}

resource "aws_iam_role_policy_attachment" "github_actions_consumers" {
  role       = aws_iam_role.github_actions_consumers.name
  policy_arn = aws_iam_policy.github_actions_consumers.arn
}
