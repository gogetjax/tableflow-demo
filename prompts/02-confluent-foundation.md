Implement `terraform/confluent` per docs/07-terraform-cicd.md, docs/02-security.md, and docs/03-producer-spec.md.

Before writing any resource, fetch the Terraform registry docs for `confluentinc/confluent` at the latest stable version, pin that version, and record the docs URL in `terraform/confluent/README.md`. Use argument names exactly as documented. If a resource in docs/07 doesn't exist under that name, stop and tell me rather than guessing.

Resources:
- Environment `tableflow-demo` with Stream Governance Essentials; Kafka cluster in `us-east-1` on AWS; pick the cheapest cluster type that supports Tableflow (check the Tableflow regions/availability page and cite it).
- Topics: `orders.raw`, `orders.clean`, `orders.rejected`, `orders.tableflow-errors`. 6 partitions each, 7-day retention.
- Schema Registry subjects for `orders.raw-key`, `orders.raw-value` from `schemas/*.avsc`. Write those two Avro files now from the field table in docs/03-producer-spec.md (key: a record with `order_id: string`). Set subject compatibility `BACKWARD`. `orders.clean-*` subjects are created by Flink in Phase 4; do not create them here.
- Service accounts `sa-shadowtraffic`, `sa-flink`, `sa-terraform-ci` with role bindings exactly per the table in docs/02-security.md. Kafka and SR API keys for `sa-shadowtraffic` and `sa-flink` as sensitive outputs.
- Flink compute pool, 5 CFU, same region.
- `confluent_provider_integration` for AWS pointing at the `tableflow-writer` role ARN from the AWS root's outputs (read via `terraform_remote_state`). Output the PI's IAM principal ARN and external ID.
- No Tableflow topic or catalog integration yet.

Workflows: `tf-apply-confluent.yml` per docs/07, using `CONFLUENT_CLOUD_API_KEY/SECRET` from the `prod` environment. Extend `tf-plan.yml` to plan this root too.

Add a short doc section to `terraform/README.md` describing the two-pass bootstrap (AWS → Confluent → AWS trust update) with the exact `terraform apply -var=...` commands for step 3.

Plan locally, paste summary, open PR "Phase 2: Confluent foundation". After I merge and apply, remind me to run the AWS trust update and to set `kafka_cluster_id` in the AWS root.
