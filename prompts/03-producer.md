Implement `shadowtraffic/` per docs/03-producer-spec.md.

1. Read https://docs.shadowtraffic.io for: Kafka connection config, Avro serialization with Confluent Schema Registry, how to reference an external Avro schema file, throttling, and the generator functions needed for weighted choices, nulls, UUIDs, timestamps with jitter, and re-emitting previous values to create duplicates. Cite each page you relied on in the PR.
2. Write `shadowtraffic/orders-raw.json` producing to `orders.raw` with the dirty-row rates in docs/03. Both key and value must be Avro through Schema Registry, `auto.register.schemas=false`, `use.latest.version=true`. Point the schema at `../schemas/orders.raw-value.avsc` if ShadowTraffic supports file references; if it needs the schema inline, generate the inline copy from the `.avsc` with a `make shadowtraffic-config` target so `schemas/` stays the source of truth.
3. Write `shadowtraffic/README.md` with the exact `docker run` command, the env vars it needs (bootstrap, Kafka key/secret, SR URL and key/secret, license), and a `.env.example`.
4. Run it against the live cluster for two minutes. Consume 1,000 messages with the `confluent` CLI (or a small Python consumer) and report the observed rate of each dirty variant in the PR. Confirm in Schema Registry that no new schema versions were registered by `sa-shadowtraffic`.
5. Update docs/03-producer-spec.md acceptance section with actual observed numbers.

Open PR "Phase 3: ShadowTraffic Avro producer".
