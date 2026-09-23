#!/usr/bin/env bash
# Runs on the isolated consumer instance via SSM. No internet: everything comes from the
# tooling bucket through the S3 gateway endpoint (scripts, a Python wheelhouse, Spark/Delta
# jars, and a JDK for the Spark-based Delta reader).
#   env: TOOLING_BUCKET, GLUE_DATABASE, GLUE_TABLE, DELTA_TABLE_URI,
#        CONSUMER_ICEBERG_ROLE_ARN, CONSUMER_DELTA_ROLE_ARN, AWS_REGION
set -euo pipefail
: "${TOOLING_BUCKET:?}" "${GLUE_DATABASE:?}" "${GLUE_TABLE:?}" "${DELTA_TABLE_URI:?}"
: "${CONSUMER_ICEBERG_ROLE_ARN:?}" "${CONSUMER_DELTA_ROLE_ARN:?}"
export AWS_REGION="${AWS_REGION:-us-east-1}" AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"

W=/opt/tableflow-demo
mkdir -p "$W" && cd "$W"
aws s3 sync "s3://$TOOLING_BUCKET/consumers/"  ./consumers/  --only-show-errors
aws s3 sync "s3://$TOOLING_BUCKET/wheelhouse/" ./wheelhouse/ --only-show-errors
aws s3 sync "s3://$TOOLING_BUCKET/jars/"       ./jars/       --only-show-errors
aws s3 sync "s3://$TOOLING_BUCKET/jre/"        ./jre/        --only-show-errors

if [[ ! -f venv/.installed ]]; then
  rm -rf venv && python3 -m venv venv
  venv/bin/python -m pip install --no-index --find-links ./wheelhouse -r consumers/requirements.txt -q
  touch venv/.installed
fi
if [[ ! -d jdk ]]; then
  mkdir -p jdk && tar xzf jre/amazon-corretto-17-x64-linux-jdk.tar.gz -C jdk --strip-components=1
fi
export PATH="$W/venv/bin:$W/jdk/bin:$PATH" JAVA_HOME="$W/jdk"
export SPARK_JARS=$(ls "$W"/jars/*.jar | paste -sd,)

echo "== egress check (must fail: no route to the internet)"
if curl -sS -m 5 https://docs.confluent.io -o /dev/null; then echo "UNEXPECTED: internet reachable"; exit 2; else echo "ok: no internet"; fi

assume() { # assume <role-arn> <session> → exports temporary creds in this subshell
  local out
  out=$(aws sts assume-role --role-arn "$1" --role-session-name "$2" --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
  export AWS_ACCESS_KEY_ID=$(cut -f1 <<<"$out") AWS_SECRET_ACCESS_KEY=$(cut -f2 <<<"$out") AWS_SESSION_TOKEN=$(cut -f3 <<<"$out")
}

echo "== iceberg via Glue (consumer-iceberg)"
( assume "$CONSUMER_ICEBERG_ROLE_ARN" runner-iceberg; python consumers/iceberg/pyiceberg_read.py )

echo "== delta by path, Spark + Delta Lake (consumer-delta)"
( assume "$CONSUMER_DELTA_ROLE_ARN" runner-delta; python consumers/delta/spark_read.py )

echo "== side by side"
CONSUMER_ICEBERG_ROLE_ARN="$CONSUMER_ICEBERG_ROLE_ARN" CONSUMER_DELTA_ROLE_ARN="$CONSUMER_DELTA_ROLE_ARN" bash consumers/compare.sh
