#!/usr/bin/env bash
# Bring the AWS side back for a demo: terraform apply with var.idle = false, which creates the
# interface VPC endpoints and sets the runner instance to running. Then wait for SSM.
# Idempotent. Confluent is untouched. Same credential/variable needs as aws-idle.sh.
#
# Observed: on every cold start the SSM agent stays silent (it starts before endpoint DNS is
# usable and backs off), so after 2 minutes the script reboots the instance once; it reports
# Online ~40 s later. Expect 5–6 minutes end to end.
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform/aws" && pwd)"

echo "== terraform apply -var idle=false (endpoints + instance running; ~1-2 minutes)"
terraform -chdir="$ROOT" apply -input=false -auto-approve -no-color -var idle=false \
  | grep -E '^(Apply complete|Error)|Creation complete|Modifications complete' || true

iid=$(terraform -chdir="$ROOT" output -raw consumer_runner_instance_id)
aws ec2 wait instance-running --region "$REGION" --instance-ids "$iid"
echo "$iid running"

wait_ssm() { # wait_ssm <seconds>
  local i
  for i in $(seq 1 $(( $1 / 10 ))); do
    ping=$(aws ssm describe-instance-information --region "$REGION" --filters "Key=InstanceIds,Values=$iid" \
           --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)
    if [[ "$ping" == "Online" ]]; then echo "SSM Online after $((i*10))s"; return 0; fi
    sleep 10
  done
  return 1
}

echo "== waiting for SSM"
if ! wait_ssm 120; then
  echo "SSM silent after 2 minutes; rebooting the instance once so the agent reconnects"
  aws ec2 reboot-instances --region "$REGION" --instance-ids "$iid"
  wait_ssm 600 || { echo "SSM did not report Online"; exit 1; }
fi
echo "ready: run consumers/runner/run.sh"
