# tableflow

Enablement and verification scripts for Tableflow on `orders.clean`: dual-format (Iceberg + Delta) enablement if the Terraform provider cannot express it, and checks for Tableflow status, S3 layout, and the Glue table pointer. Populated in Phase 5 by [prompts/05-tableflow-glue.md](../prompts/05-tableflow-glue.md). Spec, settings, and expected S3 layout: [docs/05-tableflow-spec.md](../docs/05-tableflow-spec.md).
