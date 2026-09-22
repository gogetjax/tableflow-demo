# .github/workflows

GitHub Actions workflows. Phase 0 adds `docs-lint.yml` (markdownlint plus a Mermaid render check on every diagram). Phase 1 adds `tf-plan.yml` (plan for both roots on PRs touching Terraform or schemas, posted as comments) and `tf-apply-aws.yml` (apply on push to `main`). Phase 2 adds `tf-apply-confluent.yml`. Later phases add `flink-apply.yml` and `consumers-smoke.yml`. AWS access uses OIDC only; Confluent Cloud keys live in the `prod` GitHub Environment. Workflow table and auth model: [docs/07-terraform-cicd.md](../../docs/07-terraform-cicd.md).
