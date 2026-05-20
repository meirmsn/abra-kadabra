# Review — ak-merge-devshop-hardening

## Audit 1: manual (2026-05-20)

<!-- audited-at: 900c572d29c79a1be873ab02d5007dc5f17d889c -->
<!-- range: origin/main..HEAD -->

findings: high=1 medium=1 low=1

### Docs findings

- [high] `.claude/skills/devshop/merge-devshop/SKILL.md:934-942` — Phase 4.2 "DCG `-f` pattern-match constraint" paragraph asserted `core.git:push-force-short` matches generic `-f`/`--force` substrings; empirically false. Verified via `dcg test`: the rule false-positives on compound commands containing BOTH `git push` (any variant) AND a separate `-f` flag elsewhere (`rm -f`, `submodule deinit -f`, etc.) — NOT on generic `-f` substrings. Fix in commit 9796b71 (Audit 2).
- [medium] `kit/docs/guide/workflow.md:477` — skill-map row for `/ak-merge-devshop` still described Phase 2 as `git rebase origin/main` literal; did not reflect anchor-selection, Phase 1 medium-halt, or Phase 4.2 split-teardown. Fix in commit 9796b71.
- [low] `.claude/skills/devshop/merge-devshop/SKILL.md:644-647` — Phase 1 medium-halt referenced `DEVSHOP_AUDIT_MEDIUM_POLICY=proceed` without registering it in `kit/docs/guide/hooks.md § Bypass flags + env hatches` inventory. Fix in commit 9796b71.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-20)

<!-- audited-at: e236ae01cbcfd6d236698876415213e4a76172bd -->
<!-- range: 900c572d29c79a1be873ab02d5007dc5f17d889c..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- (none — all 3 Audit 1 findings verified closed by polish commit `9796b71`)

### Tests findings

- [low] `kit/tests/util-ak-merge-devshop.bats:431-446` — Phase 4.2 narrative assertion uses a loose 3-way OR (`grep -qiE 'false-positive|separate.*Bash.*tool call|do not chain'`) plus an unscoped sub-grep. Optional tightening: split into 3 separate `grep -q` calls so any single missing dimension fails the test. Current shape consistent with sibling patterns in the same file; noted as polish opportunity, not regression.

### Bypass trailer audit

- (none)

