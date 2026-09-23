#!/usr/bin/env bash
# Side-by-side comparison from docs/06: Iceberg via Glue vs Delta via S3 path.
# Assumes the caller can assume both consumer roles (github-actions-consumers, the runner
# instance, or an admin listed in consumer_trusted_principal_arns).
# Env: AWS_REGION, GLUE_DATABASE, GLUE_TABLE, DELTA_TABLE_URI,
#      CONSUMER_ICEBERG_ROLE_ARN, CONSUMER_DELTA_ROLE_ARN; PYTHON (default python3);
#      SPARK_JARS (offline runner) is passed through to spark_read.py.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${PYTHON:-python3}"

assume() { # assume <role-arn> <session> → exports temporary creds in this subshell
  local out
  out=$(aws sts assume-role --role-arn "$1" --role-session-name "$2" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
  export AWS_ACCESS_KEY_ID=$(cut -f1 <<<"$out") AWS_SECRET_ACCESS_KEY=$(cut -f2 <<<"$out") AWS_SESSION_TOKEN=$(cut -f3 <<<"$out")
}

( assume "$CONSUMER_ICEBERG_ROLE_ARN" compare-iceberg
  echo "$("$PY" "$DIR/iceberg/pyiceberg_read.py" --count-only) $("$PY" "$DIR/iceberg/pyiceberg_read.py" --snapshot-only)" ) > /tmp/iceberg.out
( assume "$CONSUMER_DELTA_ROLE_ARN" compare-delta
  echo "$("$PY" "$DIR/delta/spark_read.py" --count-only) $("$PY" "$DIR/delta/spark_read.py" --version-only)" ) > /tmp/delta.out

read -r ICE_N ICE_SNAP < /tmp/iceberg.out
read -r DEL_N DEL_VER < /tmp/delta.out

cat <<EOF
|                         | Iceberg consumer                  | Delta consumer                    |
|-------------------------|-----------------------------------|-----------------------------------|
| Discovery               | Glue catalog                      | S3 path                           |
| AWS permissions         | Glue read + S3 read               | S3 read                           |
| Confluent permissions   | none                              | none                              |
| Reader                  | PyIceberg                         | Spark + Delta Lake                |
| Current-version pointer | snapshot $ICE_SNAP | _delta_log version $DEL_VER |
| Row count now           | $ICE_N | $DEL_N |
EOF
