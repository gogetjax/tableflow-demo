# ADR-0002 — Glue for Iceberg, path-based for Delta

**Status:** accepted

**Context.** We wanted the built-in Tableflow Iceberg REST catalog. It works with BYOS (no credential vending; consumers bring AWS creds). But consumers may not communicate with Confluent, and the REST endpoint *is* Confluent. Iceberg has no self-describing current-version pointer on disk; the catalog holds it. Delta's `_delta_log` is self-describing.

**Decision.**
- Iceberg: Tableflow syncs metadata to AWS Glue Data Catalog. Consumers read Glue + S3.
- Delta: consumers read the S3 path directly. No catalog. Unity Catalog is optional and Databricks-side only.
- The catalog-less Iceberg path (`StaticTable` on a chosen `metadata.json`) is documented as an anti-pattern, not shipped.

**Why not catalog-less Iceberg.** No discovery; consumer must list `metadata/` and pick newest; race with ~5-minute commits; Tableflow expires snapshots (10–100 kept, not configurable) so pinned metadata files disappear; Athena/Redshift/BI tools can't take a path; schema evolution invisible until re-resolve.

**Glue costs.** One more IAM policy; sync can fail independently of materialization (stale table, not error); one Glue integration per cluster; tables must be treated read-only and Glue optimizers left off.

**Consequences.** Tableflow's Glue integration is Iceberg-only; it never registers Delta tables. Tableflow has no built-in Delta catalog. The demo states the asymmetry plainly: Iceberg needs a catalog, Delta doesn't — a property of the formats, not of Tableflow.
