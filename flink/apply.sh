#!/usr/bin/env bash
# Apply flink/*.sql in file order as named statements running under sa-flink.
# Idempotent: a file is skipped when a statement with its name already exists and is not
# FAILED. A FAILED statement of the same name is deleted and re-created.
#
# Uses the Confluent CLI (verified with `confluent flink statement create --help`):
#   confluent flink statement create <name> --sql ... --compute-pool ... --service-account ...
#                                    --database <kafka cluster id> --environment ... --wait
# `create` takes no --cloud/--region; `list`/`delete` do. The caller needs Assigner on
# sa-flink (sa-terraform-ci has it; so does an org admin).
#
# Env (required): CONFLUENT_ENV_ID, FLINK_COMPUTE_POOL_ID, KAFKA_CLUSTER_ID, FLINK_SA_ID
#                 FLINK_REGION defaults to us-east-1
set -euo pipefail

: "${CONFLUENT_ENV_ID:?}" "${FLINK_COMPUTE_POOL_ID:?}" "${KAFKA_CLUSTER_ID:?}" "${FLINK_SA_ID:?}"
FLINK_REGION="${FLINK_REGION:-us-east-1}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The CLI prints an informational "No Flink endpoint is specified..." line before its JSON.
json_only() { sed -n '/^[[{]/,$p'; }

existing=$(confluent flink statement list --cloud aws --region "$FLINK_REGION" \
  --environment "$CONFLUENT_ENV_ID" --compute-pool "$FLINK_COMPUTE_POOL_ID" -o json 2>/dev/null \
  | json_only | jq -r '.[] | "\(.name) \(.status)"')

rc=0
for f in "$DIR"/[0-9][0-9]-*.sql; do
  name="tableflow-demo-$(basename "$f" .sql)"
  status=$(awk -v n="$name" '$1==n {print $2}' <<<"$existing")
  if [[ -n "$status" && "$status" != "FAILED" ]]; then
    echo "skip  $name ($status)"
    continue
  fi
  if [[ "$status" == "FAILED" ]]; then
    echo "retry $name (deleting FAILED statement)"
    confluent flink statement delete "$name" --cloud aws --region "$FLINK_REGION" \
      --environment "$CONFLUENT_ENV_ID" --force >/dev/null 2>&1
  fi
  echo "apply $name"
  out=$(confluent flink statement create "$name" \
    --sql "$(cat "$f")" \
    --environment "$CONFLUENT_ENV_ID" \
    --compute-pool "$FLINK_COMPUTE_POOL_ID" \
    --database "$KAFKA_CLUSTER_ID" \
    --service-account "$FLINK_SA_ID" \
    --wait -o json 2>&1 | json_only)
  st=$(jq -r '.status' <<<"$out" 2>/dev/null || echo "UNKNOWN")
  echo "      status=$st $(jq -r '.status_detail // ""' <<<"$out" 2>/dev/null)"
  [[ "$st" == "RUNNING" || "$st" == "COMPLETED" ]] || rc=1
done
exit $rc
