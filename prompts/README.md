# Claude Code prompts

One prompt per phase. Start each in its own worktree, paste the prompt, review the PR.

```bash
claude -w phase-0/bootstrap       # then paste 00-bootstrap.md
claude -w phase-1/aws-foundation  # 01-aws-foundation.md
claude -w phase-2/confluent       # 02-confluent-foundation.md
claude -w phase-3/producer        # 03-producer.md
claude -w phase-4/flink           # 04-flink.md
claude -w phase-5/tableflow       # 05-tableflow-glue.md
claude -w phase-6/consumers       # 06-consumers.md
claude -w phase-7/ci-polish       # 07-ci-polish.md
```

Every prompt inherits `CLAUDE.md`. The recurring guardrail is the same: verify syntax against a URL, cite it in the PR, and record smoke-test results in `docs/09-open-questions.md`.
