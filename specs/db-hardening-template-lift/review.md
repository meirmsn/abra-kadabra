# Review — db-hardening-template-lift

## Audit 1: manual (2026-05-20)

<!-- audited-at: 7f68b4046fe6f93c25492fddc739e85552405e27 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=5 low=6

### Docs findings

- [medium] kit/docs/guide/hooks.md — new `advisorBypassReason` check-type missing from hooks.md (model-routing table, surface inventory, bypass-flag list)
- [medium] kit/docs/guide/hooks.md:421 — "only adversarial check-type whose surface isn't a git hook" claim contradicted by `advisorBypassReason` firing from `/ak-pre-ship` Gate 2g
- [medium] kit/docs/guide/hooks.md:385 — Sonnet 4.6 model-routing row omits `advisorBypassReason` though the script routes it to Sonnet
- [low] kit/docs/guide/security.md:5-20 — `## Contents` TOC missing new `## DB hardening` H2 entry
- [low] kit/docs/guide/README.md:140 — `security.md` alphabetical-list summary doesn't mention DB hardening conventions
- [low] kit/docs/guide/README.md:34 — Data routing row for `supabase/migrations/**` doesn't point at `security.md § DB hardening` directly

### Tests findings

- [medium] kit/scripts/adversarial-review.sh:413-449 — new `advisorBypassReason` check-type lacks dedicated `util-adversarial-review-advisorBypassReason.bats` spec; existing test paths skip the reviewer
- [medium] template/scripts/advisor-probe.mjs:71-323 — 9 pg_catalog SQL queries never exercised against real Postgres (bats are source-greps; pre-ship gate stubs both psql + pnpm)
- [low] kit/tests/template-advisor-probe.bats:21-25 — `9 lints` count test greps function declarations only, doesn't verify all 9 are in the driver's `lints` array
- [low] kit/tests/template-advisor-probe.bats:43-49 — ADVISOR-EXEMPT marker test is source-grep, doesn't behavior-test `loadExemptions()`
- [low] kit/tests/preship-advisor-clean.bats:207-218 — exit-2 routing test asserts prefix only, doesn't pin the probe-error excerpt formatting

### Bypass trailer audit

- (none)
