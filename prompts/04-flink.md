Implement `flink/` per docs/04-flink-spec.md.

1. Open the Confluent Cloud Flink SQL reference for `CREATE TABLE` `WITH` options (`changelog.mode`, `key.format`, `value.format`, `kafka.retention.time`), `DISTRIBUTED BY`, `PRIMARY KEY ... NOT ENFORCED`, and deduplication (`ROW_NUMBER`) semantics. Cite pages in the PR. Do not use open-source Flink Kafka connector options.
2. Write in order: `flink/00-create-orders-rejected.sql`, `flink/01-create-orders-clean.sql`, `flink/02-route-invalid.sql`, `flink/03-normalize-and-dedup.sql`. Sinks must be `changelog.mode = 'append'`, key and value `avro-registry`, primary key `order_id`.
3. Write `flink/apply.sh` that applies each file as a named statement under `sa-flink` using the `confluent flink statement create` CLI (check `--help` for flag names) and skips files whose statement name already exists. Alternatively use `confluent_flink_statement` in Terraform — pick one, state why in the PR, and don't do both.
4. Apply against the live pool. Run the acceptance checks in docs/04: sample 10 minutes of `orders.clean`, assert no duplicate `order_id`, no null `customer_id`, no `quantity <= 0`, all `currency` uppercase; confirm `orders.rejected` receives rows. Paste `SHOW CREATE TABLE orders.clean` output in the PR and confirm changelog mode is append.
5. Record the Q5 result (key schema present for `orders.clean`) in docs/09-open-questions.md.

Open PR "Phase 4: Flink cleaning pipeline".
