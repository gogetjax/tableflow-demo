# 03 — Producer spec (ShadowTraffic + Avro + Schema Registry)

## Requirements

- Format: Avro with Confluent Schema Registry wire format. Both **key and value** must have schemas; Tableflow does not support schemaless topics.
- Schemas are pre-registered by Terraform from `schemas/*.avsc`. The producer must not auto-register.
- Data must include deliberate dirty rows so the Flink cleaning step has something to do.
- Throughput: low. A few events per second is enough; Tableflow commits roughly every 5 minutes or when enough data accumulates.

## Schemas

`schemas/orders.raw-key.avsc` — string key wrapper (Avro `record` with one field `order_id: string`, or a primitive `string` schema; pick one and keep it for `orders.clean`).

`schemas/orders.raw-value.avsc` (sketch — finalize in Phase 3):

| Field | Type | Dirty variants injected |
|---|---|---|
| `order_id` | string | duplicated ~5% |
| `customer_id` | string | null ~2% |
| `product_id` | string | — |
| `quantity` | int | negative or zero ~3% |
| `unit_price_cents` | long | — |
| `currency` | string | lowercase `usd` ~5% |
| `ordered_at` | long (`timestamp-millis`) | far-future timestamp ~1% |
| `status` | enum {PLACED, PAID, SHIPPED, CANCELLED} | — |
| `source` | string | — |

Avro logical types matter: Tableflow maps Avro → Parquet → Iceberg/Delta types. Use `timestamp-millis` for time, `decimal` only if you have tested its mapping (see 09).

## Schema Registry governance

- Subject naming: TopicNameStrategy (`<topic>-key`, `<topic>-value`).
- Compatibility: `BACKWARD` at subject level for `orders.*`. Tableflow evolves tables on add-column, drop-column, widen-type. Anything Schema Registry rejects, Tableflow never sees.
- Producer config: `auto.register.schemas=false`, `use.latest.version=true`. A schema change is a PR to `schemas/`, applied by Terraform, then a producer redeploy.
- **Observed (Phase 3):** ShadowTraffic 2.1.4 calls Schema Registry *register* for its key and value schemas at startup regardless of the serializer settings, and fails hard when refused (`User is denied operation Write on Subject: orders.raw-key`). Registering a byte-identical schema returns the existing ID and creates no version, so `sa-shadowtraffic` was granted `DeveloperWrite` on `orders.raw-*` subjects in addition to `DeveloperRead`. The `avroSchemaHint` loads the same `.avsc` files Terraform registered, which is what keeps the call idempotent. The governance check is therefore "subject version count stays 1", not "no register calls".

## ShadowTraffic configuration

Location: `shadowtraffic/orders-raw.json`. Shape, not final syntax — Phase 3 verifies against https://docs.shadowtraffic.io (Kafka connection, Avro serializer, Schema Registry auth):

- One `kafka` connection: bootstrap from Confluent, SASL_SSL/PLAIN with `sa-shadowtraffic` key, `KafkaAvroSerializer` for key and value, `schema.registry.url` + basic auth with the SR key, `auto.register.schemas=false`. `producerConfigs` values must be plain strings (a generator object there is a config error), so the JAAS line and `key:secret` are assembled in the env file and pulled in with `{"_gen":"env"}`.
- One generator for topic `orders.raw`:
  - `order_id`: UUID, with a `fork`/lookup or stateful pattern that re-emits a previous ID ~5% of the time to produce duplicates
  - `customer_id`: weighted choice including `null`
  - `quantity`: weighted distribution with a small tail at `0` and `-1`
  - `currency`: weighted `USD` / `usd`
  - `ordered_at`: now ± jitter, with a rare far-future value
  - throttle to ~2–5 events/s
- If ShadowTraffic needs an Avro schema hint to serialize, point it at the same `.avsc` files under `schemas/` so there is one source of truth.

Run: Docker, license key from env, config mounted read-only. Document the exact `docker run` in `shadowtraffic/README.md` after it works.

## Acceptance

- `orders.raw` shows Avro-decoded messages in Confluent Cloud Console with schema ID from the Terraform-registered subject.
- `orders.raw-key` and `orders.raw-value` stay at version 1 after the producer runs (ShadowTraffic registers an identical schema; see governance note above).
- A sample of 1,000 events contains each dirty variant at roughly the target rate.

### Observed, 2026-09-22 (ShadowTraffic 2.1.4, 1,000 consecutive events from offset 0)

| Variant | Count | Observed | Target |
|---|---|---|---|
| duplicate `order_id` | 50 | 5.0% | ~5% |
| null `customer_id` | 23 | 2.3% | ~2% |
| `quantity` ≤ 0 | 32 | 3.2% | ~3% |
| lowercase `currency` | 59 | 5.9% | ~5% |
| far-future `ordered_at` | 12 | 1.2% | ~1% |

Key `order_id` equalled value `order_id` in 1,000/1,000 events. Subject versions after the run: `orders.raw-key` [1], `orders.raw-value` [1]. Throughput ~3.3 events/s at `throttleMs: 300`.
