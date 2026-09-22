# CLAUDE.md — conventions for Claude Code in this repo

## Ground rules
- Never invent CLI flags, Terraform arguments, or API fields. Verify against the current Confluent docs, the `confluent` CLI `--help`, the Terraform provider registry page, or the ShadowTraffic docs, and cite the URL in the PR description.
- If a doc is ambiguous (see docs/09-open-questions.md), write the smallest possible smoke test, run it, and record the result in that file before building on it.
- Docs are first-class. Any change to behavior updates the matching file in docs/ and the README table in the same PR.
- Mermaid diagrams live inline in docs/*.md. Keep them current.

## Workflow
- One phase per worktree: `claude -w <phase-branch>`. Branch names: `phase-N/<slug>`.
- Every phase ends with a PR that links the prompt file that drove it and ticks the phase checklist in docs/08-runbook.md.
- Terraform: `terraform fmt -check`, `terraform validate`, and a plan output pasted into the PR. Applies run only from GitHub Actions on `main`.
- Secrets never enter the repo. Use GitHub Environments + OIDC for AWS; Confluent Cloud API keys via GitHub secrets consumed by the Terraform provider.

## Tone for docs and copy
- Brief. Clean punctuation. No marketing language.
