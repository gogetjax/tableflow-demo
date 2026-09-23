# 10 — Demo script (10 minutes)

One topic, cleaned by Flink, materialized by Tableflow into Iceberg and Delta in a customer bucket, read by two consumers that cannot reach Confluent. Every command below is read-only against the running demo except starting the producer.

IDs used throughout: environment `env-876zz7`, cluster `lkc-q2zqngd`, pool `lfcp-o3z7jop`, bucket `tableflow-demo-lake-706193894984`, table path `s3://tableflow-demo-lake-706193894984/1100000/11101001/cfd75085-a017-4113-81ff-f34b6f2d2a87/env-876zz7/lkc-q2zqngd/v1/5839772c-c3b9-46e6-8dea-137d2269d7af`.

## 0. Before the demo (5 minutes, not on the clock)

- Docker Desktop running; license and connection env files in `~/.config/` (shadowtraffic/README.md).
- Flink statements `RUNNING`: `confluent flink statement list --cloud aws --region us-east-1 --environment env-876zz7 --compute-pool lfcp-o3z7jop`.
- Tableflow `RUNNING`: `confluent tableflow topic describe orders.clean --cluster lkc-q2zqngd --environment env-876zz7`.
- Runner instance `Online` in SSM (it can be stopped between demos; start it 3 minutes before).

## 1. Start the producer (1 minute)

```bash
docker run --rm --name shadowtraffic-orders \
  --env-file ~/.config/shadowtraffic/license.env --env-file ~/.config/tableflow-demo/shadowtraffic.env \
  -v "$PWD/shadowtraffic/orders-raw.json:/home/config.json:ro" -v "$PWD/schemas:/home/schemas:ro" \
  shadowtraffic/shadowtraffic:latest --config /home/config.json
```

Say: Avro key and value through Schema Registry, schemas pre-registered by Terraform, ~3 events/s with 5% duplicates, 2% null customers, 3% bad quantities, 5% lowercase currency, 1% future timestamps. Show `confluent schema-registry subject describe orders.raw-value --environment env-876zz7`: still version 1.

## 2. Show the rejects in Flink (2 minutes)

Open the Flink SQL workspace (or `confluent flink shell --compute-pool lfcp-o3z7jop --environment env-876zz7`) and run:

```sql
SELECT reject_reason, COUNT(*) AS c
FROM `orders.rejected` /*+ OPTIONS('scan.bounded.mode'='latest-offset') */
GROUP BY reject_reason;
```

Then the clean side:

```sql
SELECT COUNT(*) AS rows_total, COUNT(DISTINCT order_id) AS distinct_ids,
       SUM(CASE WHEN currency <> UPPER(currency) THEN 1 ELSE 0 END) AS lowercase
FROM `orders.clean` /*+ OPTIONS('scan.bounded.mode'='latest-offset') */;
```

Say: append-only sink with a primary key, `value.fields-include = 'all'` so the key column is in the table, first-seen dedup on `$rowtime`. Point at `flink/03-normalize-and-dedup.sql`.

## 3. Watch a Tableflow commit (2 minutes)

```bash
CONFLUENT_ENV_ID=env-876zz7 KAFKA_CLUSTER_ID=lkc-q2zqngd LAKE_BUCKET=tableflow-demo-lake-706193894984 ./tableflow/verify.sh
```

Say: one table root, `data/` shared by both formats, `metadata/` for Iceberg, `_delta_log/` for Delta; Glue holds the Iceberg pointer (`metadata_location`); Delta needs no catalog. Run it again after a minute if a commit lands: the Glue pointer and `_delta_log` version advance together. Show `docs/05-tableflow-spec.md` "What lands in S3" for the file-sharing proof.

## 4. Both consumers from the isolated subnet (3 minutes)

```bash
INSTANCE_ID=$(terraform -chdir=terraform/aws output -raw consumer_runner_instance_id) \
TOOLING_BUCKET=$(terraform -chdir=terraform/aws output -raw tooling_bucket_name) \
GLUE_DATABASE=lkc-q2zqngd GLUE_TABLE=orders.clean \
DELTA_TABLE_URI=<table path above> \
CONSUMER_ICEBERG_ROLE_ARN=arn:aws:iam::706193894984:role/consumer-iceberg \
CONSUMER_DELTA_ROLE_ARN=arn:aws:iam::706193894984:role/consumer-delta \
./consumers/runner/run.sh
```

Say, as the output scrolls: the instance has no route to the internet (the `curl docs.confluent.io` line must time out); PyIceberg finds the table through Glue; Spark opens the Delta table by path; the roles hold Glue/S3 read only; the side-by-side table at the end shows the same row count from both formats. Mention Athena as the "free" Iceberg consumer: `./consumers/iceberg/athena_run.sh`.

If someone asks about delta-rs or DuckDB: `docs/09-open-questions.md` Q11. Tableflow's Delta tables use column mapping `id`, type widening and deletion vectors; today that needs a Spark/Databricks-class reader.

## 5. The audit evidence (1 minute)

```bash
CLOUDTRAIL_BUCKET=tableflow-demo-cloudtrail-706193894984 LAKE_BUCKET=tableflow-demo-lake-706193894984 ./consumers/cloudtrail_report.sh
```

Say: the only principal that has ever written to the bucket is `tableflow-writer`, assumed by Confluent through the provider integration with an external ID; reads come from the consumer roles (and whoever ran verification). No human `PutObject`. The bucket policy denies writes from anyone else, and `docs/02-security.md` lists the RBAC and IAM in full.

## 6. Close (30 seconds)

- Consumers: AWS credentials only. `consumers-check.yml` fails CI on any Confluent connection material under `consumers/`.
- Everything is Terraform through GitHub Actions with OIDC; `docs/07-terraform-cicd.md`.
- Open questions and their live results: `docs/09-open-questions.md`.

Stop the producer: `docker stop shadowtraffic-orders`.
