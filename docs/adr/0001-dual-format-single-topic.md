# ADR-0001 — Materialize one topic in both Iceberg and Delta

**Status:** accepted

**Context.** The demo must serve an Iceberg-expecting consumer and a Delta-expecting consumer. Options: two topics (one per format), or one topic with dual format.

**Decision.** One topic, `orders.clean`, with both formats enabled. Confluent supports dual format per topic (GA Oct 2025).

**Consequences.**
- Delta requires BYOS, so the whole pipeline uses the customer S3 bucket. Confluent Managed Storage is out.
- One Flink cleaning pipeline, one Schema Registry subject pair, one source of truth.
- Storage cost depends on whether data files are shared or duplicated (09-Q4).
- Enablement syntax for dual format must be verified (09-Q1).
