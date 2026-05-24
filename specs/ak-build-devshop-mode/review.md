# Review — ak-build-devshop-mode

## Audit 1: manual (2026-05-24)

<!-- audited-at: 4e7354f8b8de15bb65f2d24743e6260cf38e78c0 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=6 low=1

### Docs findings

- [medium] `kit/docs/guide/workflow.md:362` — Stale gate count "7 of 19 gates" in workflow.md; should be 6 of 19 per the authoritative matrix
- [medium] `kit/docs/guide/workflow.md:362,464` — Path reference `build/devshop-mode.md` is ambiguous from workflow.md's location; should be repo-root-relative `.claude/skills/devshop/build/devshop-mode.md`
- [medium] `.claude/skills/devshop/build/SKILL.md:622` vs `.claude/skills/devshop/build/devshop-mode.md:15,321` — Phase numbering mismatch: SKILL.md calls the staleness check "0.6" while devshop-mode.md calls it "Phase 0.5"
- [low] `.claude/skills/devshop/build/devshop-mode.md:42` — Resume-check rung reference says "Rungs 3–7" but SKILL.md uses "rungs 2–6"

### Tests findings

- [medium] `.claude/skills/devshop/build/devshop-mode.md` — New skill sub-file has no corresponding bats test coverage for structural invariants (gate counts, phase headers, tracker hierarchy)
- [medium] `.claude/skills/devshop/build/SKILL.md:88-103` — Mode-detection bash block not covered by content-validation test
- [medium] `kit/tests/util-build-preship-gate-consistency.bats` — Cross-skill gate consistency test not extended for devshop-mode matrix

### Bypass trailer audit

- (none)
