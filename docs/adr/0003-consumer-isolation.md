# ADR-0003 — Consumers never communicate with Confluent

**Status:** accepted

**Context.** Security requirement: readers of S3 data have no network path to and hold no credentials for the Confluent environment.

**Decision.**
- Consumers use AWS IAM roles only (`consumer-iceberg`, `consumer-delta`).
- The only cross-boundary link is Confluent assuming `tableflow-writer` / `tableflow-glue-writer` via provider integration, outbound from Confluent.
- Consumers run in a subnet with S3 and Glue endpoints and no internet route during the demo, so isolation is verifiable.
- Built-in Tableflow REST catalog is not used on the read side (ADR-0002).

**Consequences.**
- Glue becomes the Iceberg catalog. Athena becomes a free extra consumer.
- Consumer code contains no Confluent configuration of any kind; CI greps for it.
- CloudTrail data events on the bucket are the audit evidence.
