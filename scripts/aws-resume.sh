#!/usr/bin/env bash
# Bring the AWS side back for a demo:
#   1. terraform apply on terraform/aws (recreates the interface endpoints; no-op otherwise)
#   2. start the consumer runner instance and wait for SSM to report it Online
# Idempotent. Confluent is untouched. Same credential/variable needs as aws-idle.sh.
#
# Observed timing: endpoints are "available" ~45 s after apply starts, private DNS usable
# ~1 minute later. If the SSM agent starts before that it backs off for a long time, so the
# script waits after creating endpoints and reboots the instance once if SSM stays silent.
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform/aws" && pwd)"
TF=(terraform "-chdir=$ROOT")

echo "== terraform apply (recreates interface endpoints; usually 1-2 minutes)"
out=$("${TF[@]}" apply -input=false -auto-approve -no-color)
echo "$out" | grep -E '^(Apply complete|Error)|Creation complete' || true
if echo "$out" | grep -q 'aws_vpc_endpoint.*Creation complete'; then
  echo "endpoints created; waiting 60 s for private DNS"; sleep 60
fi

echo "== runner instance"
iid=$("${TF[@]}" output -raw consumer_runner_instance_id)
state=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$iid" --query 'Reservations[0].Instances[0].State.Name' --output text)
echo "$iid is $state"
if [[ "$state" != "running" ]]; then
  aws ec2 start-instances --region "$REGION" --instance-ids "$iid" >/dev/null
  aws ec2 wait instance-running --region "$REGION" --instance-ids "$iid"
  echo "$iid running"
fi

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
  echo "SSM silent after 2 minutes; rebooting the instance once so the agent reconnects (observed: needed on every cold start, Online ~40 s after)"
  aws ec2 reboot-instances --region "$REGION" --instance-ids "$iid"
  wait_ssm 600 || { echo "SSM did not report Online"; exit 1; }
fi
echo "ready: run consumers/runner/run.sh"
