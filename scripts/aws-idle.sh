#!/usr/bin/env bash
# Put the AWS side of the demo into its idle (cheapest) state without losing anything:
#   1. stop the consumer runner instance (EBS kept, so the venv/JDK/jars survive)
#   2. destroy the interface VPC endpoints (the only AWS resources with an hourly charge)
# Left in place: S3 gateway endpoint, VPC/subnet/SGs, IAM, buckets, Glue, CloudTrail, DynamoDB.
# Idempotent: a stopped instance and absent endpoints are fine. Confluent is untouched.
#
# Needs: AWS credentials for the demo account, the terraform/aws root initialized, and the
# provider-integration variables exported (TF_VAR_confluent_pi_* / TF_VAR_kafka_cluster_id, or
# the tf-aws.sh wrapper) so the targeted destroy does not touch anything else.
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform/aws" && pwd)"
TF=(terraform "-chdir=$ROOT")

echo "== runner instance"
iid=$("${TF[@]}" output -raw consumer_runner_instance_id 2>/dev/null || true)
if [[ -n "$iid" ]]; then
  state=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$iid" --query 'Reservations[0].Instances[0].State.Name' --output text)
  echo "$iid is $state"
  if [[ "$state" == "running" || "$state" == "pending" ]]; then
    aws ec2 stop-instances --region "$REGION" --instance-ids "$iid" >/dev/null
    aws ec2 wait instance-stopped --region "$REGION" --instance-ids "$iid"
    echo "$iid stopped"
  fi
else
  echo "no runner instance in state"
fi

echo "== interface endpoints"
# Derive the target list from state: every aws_vpc_endpoint except the S3 gateway.
mapfile -t targets < <("${TF[@]}" state list 2>/dev/null | grep -E '^aws_vpc_endpoint\.' | grep -v '^aws_vpc_endpoint\.s3$')
if [[ ${#targets[@]} -eq 0 ]]; then
  echo "no interface endpoints in state; nothing to destroy"
else
  args=()
  for t in "${targets[@]}"; do args+=("-target=$t"); done
  printf '  %s\n' "${targets[@]}"
  "${TF[@]}" destroy -input=false -auto-approve -no-color "${args[@]}"
fi

cat <<EOF

== idle state
Stopped: runner instance (EBS 16 GB gp3 ≈ \$1.30/month). Destroyed: interface endpoints.
What still bills on AWS:
  S3 storage in the lake / tooling / CloudTrail / state buckets (≈ \$0.023 per GB-month; well under \$1/month at demo volume)
  CloudTrail data events on the lake bucket (\$0.10 per 100k events; ≈ \$0 while the producer is stopped)
  S3 requests from Tableflow if it keeps committing (it does not while the producer is stopped)
Nothing else in this account meters while idle. Confluent resources are untouched (see docs/08).
Resume with scripts/aws-resume.sh.
EOF
