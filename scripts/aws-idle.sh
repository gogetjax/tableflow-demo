#!/usr/bin/env bash
# Put the AWS side into its idle (cheapest) state: terraform apply with var.idle = true (the
# default). That removes the interface VPC endpoints (the only hourly AWS charge) and sets the
# runner instance to stopped (EBS kept, so the venv/JDK/jars survive). Everything else stays.
# Idempotent. Confluent is untouched.
#
# Needs: AWS credentials for the demo account, terraform/aws initialized, and the
# provider-integration variables exported (TF_VAR_confluent_pi_* / TF_VAR_kafka_cluster_id)
# so the apply does not revert the writer roles' trust policies.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform/aws" && pwd)"

echo "== terraform apply -var idle=true"
terraform -chdir="$ROOT" apply -input=false -auto-approve -no-color -var idle=true \
  | grep -E '^(Apply complete|Error)|Destruction complete|Modifications complete|Creation complete' || true

cat <<EOF

== idle state
Interface endpoints: removed. Runner instance: stopped (EBS 16 GB gp3 ≈ \$1.30/month).
What still bills on AWS:
  S3 storage in the lake / tooling / CloudTrail / state buckets (≈ \$0.023 per GB-month; well under \$1/month at demo volume)
  CloudTrail data events on the lake bucket (\$0.10 per 100k events; ≈ \$0 while the producer is stopped)
Nothing else in this account meters while idle. Confluent resources are untouched (docs/08).
Resume with scripts/aws-resume.sh.
EOF
