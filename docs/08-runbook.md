# 08 — Runbook

## Phase checklists

Each phase is one Claude Code worktree and one PR. Tick boxes in the PR, not here.

### Phase 0 — Repo and docs
- [ ] Repo `gogetjax/tableflow-demo` created, `main` protected, PR required
- [ ] This docs set, README, CLAUDE.md, prompts committed
- [ ] Mermaid renders on GitHub for every diagram

### Phase 1 — AWS foundation
- [ ] Bucket, consumer roles, OIDC role, writer roles (placeholder trust)
- [ ] Bucket policy denies writes from all but writer
- [ ] `tf-plan.yml` green on PR; `tf-apply-aws.yml` applied

### Phase 2 — Confluent foundation
- [ ] Env, cluster (region = bucket region), SR, topics, subjects, compatibility
- [ ] Service accounts, role bindings, API keys → GitHub secrets
- [ ] Flink compute pool
- [ ] Provider integration created; outputs captured
- [ ] AWS re-apply with real trust policies

### Phase 3 — Producer
- [ ] ShadowTraffic config verified against ShadowTraffic docs
- [ ] Avro via SR, `auto.register.schemas=false`
- [ ] Dirty-row rates observed in a 1,000-event sample

### Phase 4 — Flink
- [ ] Sink tables created with key + value avro-registry, append mode
- [ ] Statements applied in order, running
- [ ] Acceptance checks in 04 pass

### Phase 5 — Tableflow + Glue
- [ ] 09-Q1 resolved (dual-format syntax)
- [ ] `orders.clean` enabled: BYOS, ICEBERG + DELTA
- [ ] Glue catalog integration `Connected`, table visible
- [ ] 09-Q3, 09-Q4 resolved and recorded

### Phase 6 — Consumers
- [ ] PyIceberg via Glue reads rows from isolated subnet
- [ ] delta-rs by path reads rows from isolated subnet
- [ ] Row counts agree
- [ ] CloudTrail check from 02 passes

### Phase 7 — CI polish
- [ ] `consumers-smoke.yml` scheduled and green
- [ ] README status updated; open questions closed or carried

## AWS idle cost

Confluent resources stay running by design (cluster, Flink pool and statements, Tableflow, integrations); only AWS is paused between demos.

| Resource | Idle behaviour |
|---|---|
| Runner instance `tableflow-demo-consumer-runner` (t3.large) | **stopped** by `scripts/aws-idle.sh`; EBS volume kept (~$1.30/month) so the venv, JDK and jars survive |
| Interface VPC endpoints (Glue, SSM ×3, STS, Athena; ~$0.01/h each) | **destroyed** by `aws-idle.sh` (`terraform destroy -target`, targets derived from `terraform state list`); recreated by `scripts/aws-resume.sh` |
| S3 gateway endpoint, VPC, subnet, security groups | kept; free |
| IAM roles, Glue database/table, DynamoDB lock table | kept; free |
| S3 buckets (lake, tooling, Athena results, CloudTrail, state) | kept; storage only (~$0.023/GB-month, well under $1/month at demo volume) |
| CloudTrail data events on the lake bucket | kept; $0.10 per 100k events, ~0 while the producer is stopped |

`aws-resume.sh` runs `terraform apply` (endpoints back in about a minute), starts the instance, and waits for SSM to report it Online (with one reboot; 5–6 minutes end to end). Both scripts are idempotent. Note that the endpoints are still in the Terraform configuration: any `tf-apply-aws.yml` run on `main` (a merged change under `terraform/aws/`) recreates them, so run `aws-idle.sh` again after such a merge. The full teardown order for retiring the demo is in [docs/07-terraform-cicd.md](07-terraform-cicd.md).

Open runbook item: derive the Console-generated Glue IAM template for the catalog integration and tighten `tableflow-glue-writer` to it (docs/02, docs/09 Q8).

## Verification commands (fill in as phases complete)

| Check | Command |
|---|---|
| Tableflow status | `confluent tableflow topic describe orders.clean --cluster lkc-q2zqngd --environment env-876zz7` |
| Everything at once | `CONFLUENT_ENV_ID=env-876zz7 KAFKA_CLUSTER_ID=lkc-q2zqngd LAKE_BUCKET=tableflow-demo-lake-706193894984 ./tableflow/verify.sh` |
| Glue table pointer | `aws glue get-table --database-name lkc-q2zqngd --name orders.clean --query Table.Parameters.metadata_location` |
| Delta version | `DELTA_TABLE_URI=<table_path> python consumers/delta/spark_read.py --version-only` (delta-rs `--version-only` also works; its scan does not) |
| Iceberg snapshot | `GLUE_DATABASE=lkc-q2zqngd GLUE_TABLE=orders.clean python consumers/iceberg/pyiceberg_read.py --snapshot-only` |
| Flink statements | `confluent flink statement list --cloud aws --region us-east-1 --environment env-876zz7 --compute-pool lfcp-o3z7jop` |
| Isolated consumer run | `consumers/runner/run.sh` (see consumers/README.md) |
| Who touched the bucket | `CLOUDTRAIL_BUCKET=tableflow-demo-cloudtrail-706193894984 LAKE_BUCKET=tableflow-demo-lake-706193894984 ./consumers/cloudtrail_report.sh` |

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Tableflow suspended right after enable | bucket not empty, region mismatch, missing key schema, KMS permission | check each prerequisite in 05 |
| Glue integration stuck `pending` | no materialized topic yet | wait for first commit (~5 min) |
| Glue shows table but consumer sees old data | catalog sync failing while materialization continues | Console → per-topic catalog sync status |
| Flink statement rejected: changelog mode | retract-producing query | rewrite per 04 hard rule |
| Producer fails with schema not found | `auto.register.schemas=false` and Terraform hasn't applied `schemas/` | apply Confluent root |
| Consumer works with NAT, fails without | missing Glue or S3 VPC endpoint | add endpoint; do not add NAT |
| Tableflow `FAILED`: "unable to set up the DLQ topic" | Tableflow API key owner lacks write on the `log_target` topic, or the name has a period | grant `DeveloperWrite`; use underscores |
| Tableflow `FAILED`: "cannot write to the S3 bucket" | bucket policy deny (check with `aws iam simulate-principal-policy` and the writer role) or trust policy reverted | fix the policy; re-apply AWS root with the PI variables (`tf-aws.sh`) |
| Tableflow `FAILED`: "Unable to assume the IAM role" | writer trust policy is the deny-all placeholder | re-apply `terraform/aws` with `TF_VAR_confluent_*` set |
| Flink `CREATE TABLE`: "already exists in Catalog" | topic pre-created by Terraform | delete the topic; let the DDL create it |
| Flink INSERT: "Transactional Id authorization failed" | `sa-flink` lacks transactional-id bindings | see docs/02 RBAC table |
| Delta reader errors on `TypeWidening` / NULL columns | delta-rs / DuckDB cannot read Tableflow's Delta protocol | use `consumers/delta/spark_read.py` (docs/09 Q11) |
