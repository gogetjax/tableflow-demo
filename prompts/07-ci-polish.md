Finish CI and docs.

1. `.github/workflows/consumers-smoke.yml`: schedule every 6 hours and on PRs touching `consumers/**`. Assume `github-actions-consumers` via OIDC, then each consumer role; run both readers; assert counts > 0 and equal within one commit window's worth of rows (define tolerance from observed commit size in Q4).
2. `flink-apply.yml` manual workflow wrapping `flink/apply.sh`.
3. Renovate config for Terraform provider pins, plan-only.
4. Walk docs/09-open-questions.md. Every row must have a Result. Move anything still open to a "Known gaps" section in README.
5. Regenerate the README status table and the capability table. Check every Mermaid diagram still matches what was built; fix drift.
6. Write `docs/10-demo-script.md`: a 10-minute walkthrough — start ShadowTraffic, show rejected rows in Flink, watch a Tableflow commit, run both consumers side by side from the isolated subnet, show the CloudTrail evidence.

Open PR "Phase 7: CI, verification, demo script".
