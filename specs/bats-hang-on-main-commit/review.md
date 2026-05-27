# Review — bats-hang-on-main-commit

## Audit 1: manual (2026-05-26)

<!-- audited-at: d6f943c2fd971a3b00a0aa19ab02b0a6724852d6 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=7 low=3

### Docs findings

- [medium] kit/hooks/bats-format-progress + .husky/pre-commit — new file under `kit/hooks/` and rewritten bats invocation shape without updating `hooks.md` step 5
- [medium] a78640f, 7a132f8, ca42f4d — three commits touch propagation-relevant surfaces without `**Existing projects:**` blocks in commit bodies
- [medium] .claude/skills/devshop/build/SKILL.md:533 — stale forward-reference to "Phase 7 ready-for-review comment" within the same file that removed it
- [medium] kit/docs/guide/workflow.md:297 — describes Phase 7 as posting a "ready-for-review comment" that no longer exists
- [medium] kit/docs/guide/workflow.md:285 — routing chain references removed ready-for-review comment
- [medium] kit/docs/guide/conventions.md:441,493 — Product update routing table lists "Phase 7 ready-for-review comment" surface that was removed
- [low] kit/docs/guide/workflow.md:312 — `/ak-go-live` pre-flight references stale comment headings (`## Pre-ship audit trail` → `## Pre-ship audit`, `## Ready for review` removed)

### Tests findings

- [medium] kit/scripts/preship/supabase-bootstrap.sh:148-164 — GoTrue admin API fallback (paths 2 and 3 in `verify_seed_fixtures()`) has no test coverage
- [low] kit/hooks/bats-format-progress — new formatter has no bats smoke test
- [low] kit/tests/util-build-phase58-audit-parser.bats:130 — `grep -q 'Audit 2'` assertion too loose (matches any occurrence, not co-occurrence with `/ak-check-docs-and-tests`)

### Bypass trailer audit

- a78640f Docs-Coverage-Bypass: "guide/hooks.md (no hook contract change)" — ESCALATE (commit adds new file + rewrites bats invocation shape)
- 7a132f8 Docs-Coverage-Bypass: "architecture.md already documents scaffold-once lifecycle" — VERIFIED (missing Existing projects block is separate finding)
- ca42f4d Docs-Coverage-Bypass: "ops.md references output shapes not internal strategy" — VERIFIED
- c4db7c4 Docs-Coverage-Bypass: "guide/workflow.md does not reference these sections" — DEFER (workflow.md DOES reference ready-for-review; captured in Section C)
- 195c2df Docs-Coverage-Bypass: "mechanical gate; no guide doc references grep patterns" — VERIFIED
- e14fd42 Docs-Coverage-Bypass: "kit/tests/ only" — VERIFIED
