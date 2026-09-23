#!/usr/bin/env bash
# docs/02 audit check: who touched the lake bucket, by principal and S3 API call.
# Reads the data-event trail delivered to the CloudTrail bucket (terraform/aws/cloudtrail.tf).
#   env: CLOUDTRAIL_BUCKET, LAKE_BUCKET, AWS_REGION (default us-east-1); ACCOUNT_ID optional
set -euo pipefail
: "${CLOUDTRAIL_BUCKET:?}" "${LAKE_BUCKET:?}"
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
TMP=$(mktemp -d)
aws s3 sync "s3://$CLOUDTRAIL_BUCKET/AWSLogs/$ACCOUNT_ID/CloudTrail/$REGION/" "$TMP" --only-show-errors
n=$(find "$TMP" -name '*.json.gz' | wc -l)
echo "log files: $n"
find "$TMP" -name '*.json.gz' -print0 | xargs -0 -r zcat \
  | jq -r --arg b "$LAKE_BUCKET" '
      .Records[]
      | select(.requestParameters.bucketName == $b)
      | [
          (.userIdentity.sessionContext.sessionIssuer.arn // .userIdentity.arn // .userIdentity.type),
          .eventName
        ] | @tsv' \
  | sort | uniq -c | sort -rn
rm -rf "$TMP"
