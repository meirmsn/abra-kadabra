## Gate 6: /review

**Scope**: `git diff origin/main...HEAD` — 8 commits, 9 files changed (+456 / -34). Core changes: `.husky/pre-commit` (Claude branch guard), `kit/tests/guard-husky-branch.bats` (new), `kit/tests/guard-branch-not-main.bats` (extended), docs updates (CLAUDE.md, OVERVIEW.md, hooks.md), TODOS.md cleanup.

### 1. Correctness

**Guard logic** (`.husky/pre-commit` lines 7-21): Correctly gates on `$CLAUDECODE=1` only. Uses `${CLAUDECODE:-}` for safe empty-default (bash-safe, runs after the dash-to-bash re-exec shim). Checks `_current_branch` against both `main` and `master`. Exits 1 on match, which is the correct husky convention (nonzero = abort commit). `_current_branch` is computed early (line 7, moved up from its previous position after lint-staged) so both the guard and the later bats-suite block reference the same value. No functional change to the bats-suite block.

**Edge cases covered**: Detached HEAD produces empty `_current_branch` (verified) — passes through correctly. `CLAUDECODE=""` and `CLAUDECODE=0` — both pass through (tested). Feature branches — pass through (tested).

**TOCTOU closure**: The guard runs inside git's commit process (husky hook), so there is no window between "check branch" and "execute commit" — the race between PreToolUse check and `git commit` execution is closed.

### 2. Conditional side effects

The guard is early-exit only. When `CLAUDECODE` is unset or not `"1"`, or when the branch is not main/master, the guard block falls through silently with no side effects. The `_current_branch` variable was already being computed (just moved earlier). No new global state, no file I/O, no network calls.

### 3. Test quality

**`guard-husky-branch.bats` (8 tests)**: Tests a fixture script that mirrors the production guard logic. The Claude x branch matrix is complete: Claude+main (blocked), Claude+master (blocked), Claude+feature (allowed), human+main (allowed), human+feature (allowed). Edge cases cover `CLAUDECODE=""` and `CLAUDECODE=0`. The parity test (`sed` extraction from production `.husky/pre-commit` vs fixture) catches drift.

**Parity test robustness**: The `sed -n '/^_current_branch=.*git branch --show-current/,/^fi$/p'` range matches from the `_current_branch` assignment to the first unindented `fi`. The inner `fi` on line 20 is indented (`  fi`) so it does NOT match `^fi$`. The outer `fi` on line 21 matches, ending the range at the correct spot. The `head -16` is calibrated to the 15-line guard block + trailing newline. Verified by running the tests — all pass. However, the parity test is **fragile to structural changes**: if someone adds a new unindented `fi` anywhere between the `_current_branch` assignment and the guard's closing `fi` (unlikely but possible), the `sed` extraction would break. Acceptable risk given the guard's small size and stability.

**`guard-branch-not-main.bats` (2 new regression-anchor tests)**: Lock in the exact command forms from the 2026-05-20 incident. Tests exercise the existing PreToolUse hook (not the new husky guard) — confirming the hook was never the bug, the race was. Good regression anchors.

**False-positive risk**: Low. Tests use real git repos (`create_test_repo`), real branch operations, and real `env` commands. No mocking of git internals.

### 4. Security / bypass analysis

- **`CLAUDECODE` is set by the Claude Code harness**, not by us. Claude could theoretically craft `CLAUDECODE= git commit ...` to bypass the husky guard. However, the PreToolUse hook (`check-branch-not-main.sh`) runs independently of `CLAUDECODE` and would still block. The two layers are defense-in-depth. The spec explicitly documents this fail-open posture (Gotcha #3). Not a vulnerability — it matches the documented threat model.
- **`HUSKY=0` bypass**: A separate feature (`batsSkipReason` adversarial bypass) already exists on this branch. The `HUSKY=0` env var would skip all husky hooks including this guard, but the PreToolUse layer would still fire. This is pre-existing behavior, not introduced by this change.
- **`--no-verify` bypass**: Already blocked by `check-hook-bypass.sh` PreToolUse hook. Not a gap.

### 5. Documentation accuracy

**hooks.md**: Step numbering updated correctly (2a-2f, 6 steps). Table entry added. Backstop relationship to PreToolUse explained.

**CLAUDE.md**: Known Footgun entry expanded with two-layer defense explanation, worked incident reference. Accurate.

### Findings

**Finding 1 (low severity — documentation inaccuracy)**:

`kit/docs/OVERVIEW.md` lines 96 and 107 changed "5-step" to "6-step" for the *project* repo's pre-commit chain, but the Claude branch guard was only added to the devshop's `.husky/pre-commit`, not to the project template (`template/.husky/pre-commit` still has 5 steps: symlinks + lint-staged + typecheck + gitleaks + guards). The "6-step" count is wrong in the project file-tree context. The event-flow diagram at line 142 correctly says "7 steps" for the devshop flow.

**Fix**: Revert lines 96 and 107 to "5-step chain + 4 guards" — or add a parenthetical noting the devshop adds the Claude guard as step 0.

**File**: `kit/docs/OVERVIEW.md`
**Lines**: 96, 107

## Dismissals

None

---

**Verdict: findings (1) pending** — 1 low-severity documentation inaccuracy.
