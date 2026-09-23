# flink

Confluent Cloud Flink SQL statements, one per file, applied in file order: sink table definitions for `orders.rejected` and `orders.clean` (these create the topics and their Schema Registry subjects), the invalid-row router, and the normalize-and-dedup statement. `apply.sh` applies each file as a named statement running as `sa-flink`, skips names that already exist, and re-creates `FAILED` ones. Changelog-mode rules and acceptance results: [docs/04-flink-spec.md](../docs/04-flink-spec.md).

```bash
CONFLUENT_ENV_ID=env-876zz7 FLINK_COMPUTE_POOL_ID=lfcp-o3z7jop \
KAFKA_CLUSTER_ID=lkc-q2zqngd FLINK_SA_ID=sa-09o09v9 ./flink/apply.sh
```

The caller needs `Assigner` on `sa-flink` (an org admin, or `sa-terraform-ci`). Statement names: `tableflow-demo-<file-basename>`.

`apply_rest.py` is the same logic over the Flink REST API, used by `.github/workflows/flink-apply.yml` with a Flink API key owned by `sa-terraform-ci` (the Confluent CLI has no API-key login for Confluent Cloud, only email/password or SSO).
