Create the GitHub repository `gogetjax/tableflow-demo` (private for now) with `gh`, protect `main` (PR required, one approval, linear history), and commit the design set that lives in this worktree: README.md, CLAUDE.md, docs/, prompts/.

Then:

1. Add `.gitignore` for Terraform, Python, and ShadowTraffic license files. Add `.github/CODEOWNERS` with me as owner of `terraform/**` and `docs/**`.
2. Create empty scaffolds with a README.md in each: `terraform/aws`, `terraform/confluent`, `schemas`, `shadowtraffic`, `flink`, `tableflow`, `consumers/iceberg`, `consumers/delta`, `.github/workflows`. Each README says what the directory will hold and links to the matching `docs/` file.
3. Add a `.github/workflows/docs-lint.yml` that runs markdownlint and validates every Mermaid block (use `@mermaid-js/mermaid-cli` `mmdc --validate` or equivalent; verify the flag). It must pass on this PR.
4. Read every file in `docs/` and fix internal links, table alignment, and anything that references a directory that doesn't exist yet.
5. Open a PR titled "Phase 0: bootstrap repo and design docs". In the description, link `prompts/00-bootstrap.md` and paste the Phase 0 checklist from `docs/08-runbook.md` with boxes ticked.

Do not create any cloud resources. Do not add Terraform code yet.
