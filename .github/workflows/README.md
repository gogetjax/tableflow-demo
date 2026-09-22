# .github/workflows

GitHub Actions workflows. Phase 0 adds `docs-lint.yml` (markdownlint plus a Mermaid render check on every diagram). Later phases add `tf-plan.yml`, `tf-apply-aws.yml`, `tf-apply-confluent.yml`, `flink-apply.yml`, and `consumers-smoke.yml`. AWS access uses OIDC only; Confluent Cloud keys live in the `prod` GitHub Environment. Workflow table and auth model: [docs/07-terraform-cicd.md](../../docs/07-terraform-cicd.md).
