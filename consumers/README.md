# consumers

Read-only consumers that hold AWS credentials only and never reach Confluent. `iceberg/` reads through the Glue Data Catalog; `delta/` reads by S3 path. Spec and comparison table: [docs/06-consumer-spec.md](../docs/06-consumer-spec.md). Why they are isolated: [docs/adr/0003-consumer-isolation.md](../docs/adr/0003-consumer-isolation.md).

## Isolation contract

- Runs under `consumer-iceberg` or `consumer-delta` (IAM roles from `terraform/aws`).
- Environment: `AWS_REGION` plus the table locator (`GLUE_DATABASE`/`GLUE_TABLE` or `DELTA_TABLE_URI`). Nothing else. `consumers-check.yml` fails CI if anything under `consumers/` mentions Confluent, Schema Registry, or bootstrap servers outside a comment.
- In the demo the readers run on an SSM-managed instance in a subnet with no internet route (S3 gateway endpoint + Glue/STS/SSM/Athena interface endpoints only). If they work there, isolation is proven, not assumed.

## Assume a role locally

Your principal must be listed in `consumer_trusted_principal_arns` (AWS root variable).

```bash
export AWS_REGION=us-east-1
eval "$(aws sts assume-role --role-arn arn:aws:iam::706193894984:role/consumer-iceberg \
  --role-session-name me --query 'Credentials' --output json | \
  jq -r '"export AWS_ACCESS_KEY_ID=\(.AccessKeyId) AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey) AWS_SESSION_TOKEN=\(.SessionToken)"')"
```

## Run

```bash
pip install -r consumers/requirements.txt

# Iceberg via Glue
GLUE_DATABASE=lkc-q2zqngd GLUE_TABLE=orders.clean python3 consumers/iceberg/pyiceberg_read.py
# Iceberg via Athena (workgroup tableflow-demo-consumers)
./consumers/iceberg/athena_run.sh
# Delta by path: Spark + Delta Lake (needs a JDK 17; pulls the Delta/Hadoop-AWS jars from Maven
# unless SPARK_JARS points at local copies)
DELTA_TABLE_URI=s3://tableflow-demo-lake-706193894984/<table_path> python3 consumers/delta/spark_read.py
# both, side by side (needs sts:AssumeRole on both consumer roles)
CONSUMER_ICEBERG_ROLE_ARN=... CONSUMER_DELTA_ROLE_ARN=... ./consumers/compare.sh
```

Flags: `--snapshot-only` / `--version-only` print just the current pointer; `--count-only` just the row count.

`delta/deltalake_read.py` (delta-rs) and `delta/duckdb_read.sql` are kept as probes: neither reads Tableflow's Delta table today (reader features `typeWidening`, `deletionVectors`, column mapping `id`). Details in [docs/06-consumer-spec.md](../docs/06-consumer-spec.md) and docs/09 Q11.

## On the isolated runner

`runner/run.sh` sends `runner/bootstrap.sh` to the instance through SSM. On the instance it pulls the scripts, a Python 3.9 wheelhouse, the Spark/Delta jars and a JDK from the tooling bucket through the S3 gateway endpoint (no PyPI or Maven reachable), proves there is no internet route, runs both readers under their consumer roles, and prints the side-by-side table. See `terraform/aws/consumers-runtime.tf`.

```bash
INSTANCE_ID=$(terraform -chdir=terraform/aws output -raw consumer_runner_instance_id) \
TOOLING_BUCKET=$(terraform -chdir=terraform/aws output -raw tooling_bucket_name) \
GLUE_DATABASE=lkc-q2zqngd GLUE_TABLE=orders.clean DELTA_TABLE_URI=<table_path> \
CONSUMER_ICEBERG_ROLE_ARN=... CONSUMER_DELTA_ROLE_ARN=... ./consumers/runner/run.sh
```

Refresh the tooling bucket after changing anything under `consumers/`: `aws s3 sync consumers/ s3://<tooling-bucket>/consumers/ --exclude '*.md'`.

## Anti-pattern, on purpose not shipped

Catalog-less Iceberg (`StaticTable` on a hand-picked `metadata.json`) is not a supported consumer here: no discovery, a race with ~5-minute commits, Tableflow expires old snapshots, and Athena/BI tools cannot take a path. Reasons in [docs/adr/0002-catalog-strategy.md](../docs/adr/0002-catalog-strategy.md).
