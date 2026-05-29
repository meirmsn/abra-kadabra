### Tests findings

- (none)

Notes:
- 5 new tests added in kit/tests/util-ak-merge-devshop.bats § Section G2 (tests 69-73), all passing. Full file: 103 ok / 0 not ok.
- Coverage maps 1:1 to the four guard sub-behaviors plus the rationale prose:
  1. "resolves $BATS_CWD to an absolute path when WORKTREE_PATH is set" — asserts `cd "$WORKTREE_PATH" && pwd -P` (guard half 1: no implicit `--show-toplevel` re-resolution).
  2. "pins EXPECTED_SHA to the $BRANCH squash commit" — asserts `EXPECTED_SHA=$(git -C "$BATS_CWD" rev-parse "$BRANCH")` (guard half 2: ref-resolved, checkout-independent).
  3. "asserts HEAD == EXPECTED_SHA BEFORE the suite" — verifies positional ordering (before-check above the bats invocation) rather than mere presence, so a future refactor that moves the check below the run would fail the test. Good positional rigor.
  4. "re-asserts HEAD == EXPECTED_SHA AFTER the suite (mid-flow flip)" — verifies the after-check is positioned below the bats invocation AND asserts the halt-message text ("HEAD moved during the suite" / "verdict untrustworthy"). Covers the largest-race-window case.
  5. "documents the parallel-merge HEAD-flip race rationale" — asserts the prose names the race + cites 1d343bf or the calibration-and-task-phases mirror.
- Test style matches the file's established §-section + `awk '/^## Phase 2\.5:/,/^## Phase 3:/'` section-scoping convention; the section delimiters exist in SKILL.md (lines 1017, 1146), so the awk range is valid (confirmed empirically — tests pass, not vacuously).
- The positional-ordering assertions (tests 3,4) are notably stronger than presence-only greps: they would catch a regression that keeps the strings but reorders them relative to the suite run. No suggested additions.
- Behavior tests (running the LLM end-to-end) are correctly declared out-of-scope per spec.md § Out of scope and the test file's stated scope: the skill is a pure markdown prompt, so grep-on-prose IS the appropriate contract test. Consistent with how every existing Phase 2.5/Phase 3 guard is tested.

### Bypass trailer audit

- (none)
