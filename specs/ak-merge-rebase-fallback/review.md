# Review — ak-merge-rebase-fallback

## Audit 1: manual (2026-05-19)

<!-- audited-at: 303ccec299104d2afa781e7b37a8a57c57275d9d -->
<!-- range: 9fbbe5fa393a3eb2db52aa058889974c944a601e..303ccec299104d2afa781e7b37a8a57c57275d9d -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] kit/TODOS.md cross-ref to `kit/docs/guide/architecture.md § Docker Desktop / virtiofs` — that exact named § header doesn't exist; architecture.md mentions Docker Desktop + fakeowner virtiofs inline (line 95, in the `init-prod-url.sh` paragraph) but not as a dedicated section anchor. Reader can grep `virtiofs` to find related context. Severity low — cross-ref is aspirational rather than broken (grep-recoverable), and the TODO entry's primary cross-ref to `SKILL.md § Phantom ...` is precise + verified.

### Tests findings

- (none) — docs-only diff, no test surface changed. The TODO entry mentions a future bats test "against a mocked rebase-failure scenario" but that's scoped to the eventual mechanization, not this commit.

### Bypass trailer audit

- (none) — no `Docs-Coverage-Bypass:`, `Tests-Coverage-Bypass:`, or `CLAUDE-MD-Bypass:` trailers in the range.

### Notes on coverage rubric

The `.claude/skills/**/SKILL.md` rubric calls for a paired `kit/docs/guide/workflow.md` OR `CLAUDE.md` edit. Neither was touched. Defensible exemption: the SKILL.md change is purely procedural prose within Phase 2 (documenting an operator-facing fallback) — it doesn't change the skill's contract surface or introduce a new convention that workflow.md / CLAUDE.md would need to mirror. The new prose is implementation-internal to the skill and consumed by anyone reading the skill itself.
