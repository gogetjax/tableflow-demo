#!/usr/bin/env bash
# Run consumers/iceberg/athena.sql in the tableflow-demo-consumers workgroup and print the result.
# Needs the consumer-iceberg role (or an admin). Env: AWS_REGION (default us-east-1).
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL=$(grep -v '^--' "$DIR/athena.sql")
qid=$(aws athena start-query-execution --region "$REGION" --work-group tableflow-demo-consumers \
  --query-string "$SQL" --query QueryExecutionId --output text)
for _ in $(seq 1 60); do
  st=$(aws athena get-query-execution --region "$REGION" --query-execution-id "$qid" --query 'QueryExecution.Status.State' --output text)
  case "$st" in SUCCEEDED|FAILED|CANCELLED) break;; esac
  sleep 3
done
echo "athena $st"
if [[ "$st" != "SUCCEEDED" ]]; then
  aws athena get-query-execution --region "$REGION" --query-execution-id "$qid" --query 'QueryExecution.Status.StateChangeReason' --output text
  exit 1
fi
aws athena get-query-results --region "$REGION" --query-execution-id "$qid" --query 'ResultSet.Rows[].Data[].VarCharValue' --output text
