# Review — ci-rollback-explain-marker-loud

## Audit 1: manual (2026-05-19)

<!-- audited-at: 606aa59af9eee1541b6e7559bfafb6a0b253e199 -->
<!-- range: 94de8d72e71d5a654fd72abc72e6f0d2f6d02d42..606aa59af9eee1541b6e7559bfafb6a0b253e199 -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] kit/docs/guide/workflow.md:260 — Gate 2e bullet predates this PR's marker-mandate tightening: text says "round-trips each migration's `-- ROLLBACK:` block" (markered-only iteration) but is silent about markerless migrations now surfacing as findings + the `-- noop: forward is idempotent` escape hatch. workflow.md is the high-traffic operator-facing gauntlet doc; operators should learn the gate's contract from that anchor, not have to dig into `conventions.md § ci-rollback-explain.sh`. Fix: append one sentence to the Gate 2e bullet describing the marker mandate + noop hatch. Low because existing text isn't wrong (just under-describes); canonical entry IS updated this PR.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
