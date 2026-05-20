# Audit 2 — Tests Review

**Range**: `900c572d29c79a1be873ab02d5007dc5f17d889c..HEAD` (HEAD `e236ae0`)
**Commits**: 3 (`9796b71`, `eb68bb6`, `e236ae0`)
**Test-surface change**: `kit/tests/util-ak-merge-devshop.bats` (1 file, Phase 4.2 assertion rewrite in `9796b71`); `eb68bb6` and `e236ae0` are docs-only.

## Summary

`high=0 medium=0 low=1`

## Findings

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/util-ak-merge-devshop.bats:440-445`
**What**: The Phase 4.2 narrative assertion uses a loose 3-way OR (`grep -qiE 'false-positive|separate.*Bash.*tool call|do not chain'`) followed by an unscoped sub-grep (`grep -qE 'push-force-short'`). The OR passes when ANY one of the three keywords appears in the block, and the sub-grep only requires the literal `push-force-short` substring somewhere inside the Phase 4.2 range — both greps would still pass if the narrative were partially correct (e.g. rule name present but separation-of-Bash-calls guidance dropped, or vice versa).
**Why**: A future doc edit that weakens the contract (e.g. removes the "do not chain" instruction while leaving the rule name and "false-positive" word in place) would not trip the assertion. The test passes 70/70 today because the diff's narrative says all three things in full, but the contract under test is the conjunction "rule name AND separation guidance AND false-positive framing" — encoded here as a near-disjunction.
**Fix**: Optional tightening — split into three `grep -q` calls (one per dimension) so any single missing dimension fails the test:

```bash
awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" | grep -qE 'push-force-short'      # rule named
awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" | grep -qiE 'false-positive'       # framing
awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" | grep -qiE 'separate.*Bash.*tool call|do not chain'  # separation rule
```

Low because the current shape is consistent with the pre-existing pattern in the same file (e.g. line 426-428's `per-worktree submodule registry|safety check.*independently of` OR) and the narrative under test does say all three things explicitly. Not a regression; an opportunity.

## Coverage of new behavior (Section A)

- **`9796b71` SKILL.md Phase 4.2 narrative rewrite** — covered by the updated `util-ak-merge-devshop.bats:431-446` test. The rewrite replaced the "DCG pattern-match" framing with the correct "push-force-short false-positive" framing, and the test was updated in lockstep — replacing the old `'DCG.*pattern-match|...'` grep with `'false-positive|...'` AND adding a new sub-grep pinning the literal `push-force-short` rule name. Direct coverage of the new contract.
- **`9796b71` `kit/docs/guide/hooks.md` (+1 line, env hatch register)** — pure doc cross-reference; no behavior surface requiring a bats spec.
- **`9796b71` `kit/docs/guide/workflow.md` (1 line edit)** — pure doc reference; no behavior surface.
- **`eb68bb6` / `e236ae0`** — gate artifacts (`audit-1-docs.md`, `audit-1-tests.md`) + `review.md` SHA stamp typo fix. Zero source surface; no test pairing required.

Devshop rubric (`kit/scripts/`, `kit/hooks/`, new `.claude/skills/devshop/**/SKILL.md`): no new files in range.

## Test quality (Section B)

- **Weak assertions**: none introduced beyond the low finding above.
- **Missing error/invalid-input tests**: N/A — the modified test is a doc-content grep, not a function under test.
- **Untested auth boundaries (RLS)**: N/A — no database surface in range.
- **Implementation-detail coupling**: N/A — doc-content assertion.
- **Missing boundary conditions**: N/A.
- **Shape-only assertions**: N/A — bats spec over markdown, no DOM rendering surface.
- **WebKit form-state hydration race**: N/A — no Playwright / E2E surface in range.
- **Realtime publication migration**: N/A — no subscription surface.
- **Wrapper API lifecycle events**: N/A — no `packages/core/src/api/` surface in range.
- **`routeWebSocket` after initial subscribe**: N/A.
- **Runtime validation at LLM / edge-function boundaries**: N/A.
- **Skipped tests audit**: scanned diff for `\b(test|describe|it)\.(skip|only)\b` patterns — none introduced. (Bats uses `@test` syntax; no bats `skip` introduced either.)

## Bypass trailer audit (Section C)

Harvest command returned zero rows. No `Tests-Coverage-Bypass:` trailers in the range — expected (bypass trailer mechanic activates in PR-C; forward-compatible).

## Verdict

`high=0 medium=0 low=1` — auto-advance. One low-severity assertion-tightening opportunity noted above; the modified test correctly mirrors the SKILL.md Phase 4.2 narrative rewrite and 70/70 of `util-ak-merge-devshop.bats` pass post-change per orchestrator context.
