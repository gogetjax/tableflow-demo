# shadowtraffic

ShadowTraffic generator for `orders.raw`: Avro key and value through Schema Registry, with deliberate dirty rows for the Flink cleaning step. Spec and target rates: [docs/03-producer-spec.md](../docs/03-producer-spec.md).

## Files

| File | Purpose |
|---|---|
| `orders-raw.json` | The generator + Kafka connection. Schemas are loaded from `../schemas/*.avsc` at start (`loadJsonFile`), so `schemas/` stays the single source of truth. |
| `.env.example` | Connection variables. Real values live outside the repo. |

## Run

Two env files, both outside the repo:

- `~/.config/shadowtraffic/license.env` with `LICENSE_ID`, `LICENSE_EMAIL`, `LICENSE_ORGANIZATION`, `LICENSE_EDITION`, `LICENSE_EXPIRATION`, `LICENSE_SIGNATURE`
- `~/.config/tableflow-demo/shadowtraffic.env` with the variables from `.env.example`, filled from `terraform -chdir=terraform/confluent output -json shadowtraffic_kafka_api_key` / `shadowtraffic_sr_api_key`, `kafka_bootstrap_endpoint`, `schema_registry_rest_endpoint`

From the repo root:

```bash
docker run --rm \
  --env-file ~/.config/shadowtraffic/license.env \
  --env-file ~/.config/tableflow-demo/shadowtraffic.env \
  -v "$PWD/shadowtraffic/orders-raw.json:/home/config.json:ro" \
  -v "$PWD/schemas:/home/schemas:ro" \
  shadowtraffic/shadowtraffic:latest --config /home/config.json
```

Dry run (no Kafka, prints 10 events): append `--sample 10 --stdout`.

Stop with Ctrl-C (or `docker stop`). For a bounded run add `globalConfigs.maxMs` to the config.

On WSL without Docker Desktop's WSL integration enabled, the Windows CLI works with translated paths: `docker.exe run ... -v "$(wslpath -w "$PWD/shadowtraffic/orders-raw.json"):/home/config.json:ro"` and `--env-file "$(wslpath -w ~/.config/...)"`.

## How the dirty rows are made

| Field | Mechanism |
|---|---|
| `order_id` duplicate ~5% | `vars.orderId` is `weightedOneOf` 95% `uuid`, 5% `lookup` into this generator's own history (`path: ["key","order_id"]`). Key and value both reference the var, so they always agree. |
| `customer_id` null ~2% | `weightedOneOf` with a `null` choice; the Avro type is `["null","string"]` |
| `quantity` ≤ 0 ~3% | `weightedOneOf`: 97% uniform 1–5, 2% `0`, 1% `-1` |
| `currency` lowercase ~5% | `weightedOneOf` `USD` / `usd` |
| `ordered_at` far future ~1% | `add(now, +1 year)`; otherwise `add(now, uniform(-60 s, 0))` |

Throttle: `throttleMs: 300` (~3 events/s).

## Schema Registry governance

`producerConfigs` sets `auto.register.schemas=false` and `use.latest.version=true` for the Confluent Avro serializer, and the `avroSchemaHint` is the same `.avsc` Terraform registered. ShadowTraffic itself still calls *register* on start and aborts if refused, so `sa-shadowtraffic` also holds `DeveloperWrite` on `orders.raw-*`; because the schema is identical, no new version is created. Check: `orders.raw-value` stays at version 1.

## Verify

```bash
# 1,000 messages, Avro-decoded (uses your logged-in CLI identity)
confluent kafka topic consume orders.raw --cluster lkc-q2zqngd --environment env-876zz7 \
  --from-beginning --value-format avro --key-format avro --print-key --delimiter '|' 2>/dev/null | head -1000 > /tmp/sample.txt
# no new schema versions
confluent schema-registry subject describe orders.raw-value --environment env-876zz7
```

Observed rates from the Phase 3 acceptance run are recorded in [docs/03-producer-spec.md](../docs/03-producer-spec.md).
