#!/usr/bin/env bash
# Phase 5 verification: Tableflow status, S3 layout, Glue pointer. Read-only.
#   env: CONFLUENT_ENV_ID, KAFKA_CLUSTER_ID, LAKE_BUCKET, AWS_REGION (default us-east-1)
set -uo pipefail
: "${CONFLUENT_ENV_ID:?}" "${KAFKA_CLUSTER_ID:?}" "${LAKE_BUCKET:?}"
export AWS_REGION="${AWS_REGION:-us-east-1}"

echo "== Tableflow topic (confluent tableflow topic describe)"
confluent tableflow topic describe orders.clean --cluster "$KAFKA_CLUSTER_ID" --environment "$CONFLUENT_ENV_ID" -o json 2>/dev/null | sed -n '/^{/,$p'

echo; echo "== Catalog integrations"
confluent tableflow catalog-integration list --cluster "$KAFKA_CLUSTER_ID" --environment "$CONFLUENT_ENV_ID" -o json 2>/dev/null | sed -n '/^\[/,$p'

echo; echo "== S3 layout (top 60 keys)"
aws s3 ls "s3://$LAKE_BUCKET/" --recursive | head -60
echo "-- counts"
aws s3 ls "s3://$LAKE_BUCKET/" --recursive | awk '{print $4}' | awk -F/ '
  /\/metadata\//   {ice++}
  /\/_delta_log\// {delta++}
  /\/data\//       {data++}
  END {printf "iceberg metadata files: %d\ndelta log files: %d\ndata files: %d\n", ice, delta, data}'

echo; echo "== Glue"
aws glue get-tables --database-name "$KAFKA_CLUSTER_ID" --query 'TableList[].{name:Name,type:Parameters.table_type,metadata_location:Parameters.metadata_location}' --output table 2>&1 | head -20
