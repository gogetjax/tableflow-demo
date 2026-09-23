#!/usr/bin/env bash
# Run consumers/runner/bootstrap.sh on the isolated instance through SSM and print its output.
# Needs ssm:SendCommand on the instance (an admin, or CI later). Env with defaults from the
# Terraform outputs of both roots:
#   INSTANCE_ID, TOOLING_BUCKET, GLUE_DATABASE, GLUE_TABLE, DELTA_TABLE_URI,
#   CONSUMER_ICEBERG_ROLE_ARN, CONSUMER_DELTA_ROLE_ARN, AWS_REGION
set -euo pipefail
: "${INSTANCE_ID:?}" "${TOOLING_BUCKET:?}" "${GLUE_DATABASE:?}" "${GLUE_TABLE:?}" "${DELTA_TABLE_URI:?}"
: "${CONSUMER_ICEBERG_ROLE_ARN:?}" "${CONSUMER_DELTA_ROLE_ARN:?}"
REGION="${AWS_REGION:-us-east-1}"

env_line="export TOOLING_BUCKET='$TOOLING_BUCKET' GLUE_DATABASE='$GLUE_DATABASE' GLUE_TABLE='$GLUE_TABLE' DELTA_TABLE_URI='$DELTA_TABLE_URI' CONSUMER_ICEBERG_ROLE_ARN='$CONSUMER_ICEBERG_ROLE_ARN' CONSUMER_DELTA_ROLE_ARN='$CONSUMER_DELTA_ROLE_ARN' AWS_REGION='$REGION'"
params=$(jq -cn --arg e "$env_line" --arg b "$TOOLING_BUCKET" '{commands: [$e, "aws s3 cp s3://\($b)/consumers/runner/bootstrap.sh /tmp/bootstrap.sh --only-show-errors", "bash /tmp/bootstrap.sh"]}')

cmd_id=$(aws ssm send-command --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript --comment "tableflow-demo consumers" \
  --timeout-seconds 1800 --parameters "$params" --query 'Command.CommandId' --output text)
echo "command $cmd_id"
for _ in $(seq 1 120); do
  st=$(aws ssm get-command-invocation --region "$REGION" --command-id "$cmd_id" --instance-id "$INSTANCE_ID" --query Status --output text 2>/dev/null || echo Pending)
  case "$st" in Success|Failed|Cancelled|TimedOut) break;; esac
  sleep 15
done
echo "status $st"
aws ssm get-command-invocation --region "$REGION" --command-id "$cmd_id" --instance-id "$INSTANCE_ID" --query StandardOutputContent --output text
echo "--- stderr (tail)"
aws ssm get-command-invocation --region "$REGION" --command-id "$cmd_id" --instance-id "$INSTANCE_ID" --query StandardErrorContent --output text | tail -20
[[ "$st" == "Success" ]]
