<!-- audited-at: da6216cb6c1bbee769cf89eeaa66bf3a808106d1 -->

## Gate 1: docs-check

- Result: findings (2) fixed
- F1 (medium): hooks.md missing Claude branch guard in diagram + table → fixed in f8a8f26
- F2 (low): OVERVIEW.md step counts stale → fixed in f8a8f26

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass (1393/1393 bats tests pass)
- Runner: `kit/tests/lib/bats-core/bin/bats kit/tests/`

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

**Scope**: `.husky/pre-commit` (Claude branch guard), `kit/tests/guard-branch-not-main.bats` (2 regression tests), `kit/tests/guard-husky-branch.bats` (8 tests + parity check).

**Findings**: 0

The implementation is already minimal:
- Guard logic is 6 functional lines (variable assignment, two `if` checks, four `echo` lines, `exit 1`).
- `_current_branch` hoisted to top of `.husky/pre-commit` serves both the new Claude guard and the existing bats-on-main block -- no duplication.
- Test fixture + parity test is the correct pattern for testing logic embedded in a larger script that can't be sourced independently.
- No dead code, no redundant checks, no over-engineering.

**Correctness review**: No bugs found. The `sed` range extraction in the parity test (`/^_current_branch=.*git branch --show-current/,/^fi$/`) correctly terminates at line 21 (the unindented `fi` closing the outer CLAUDECODE `if`), not at line 20 (the indented `fi` closing the inner branch check). The `head -16` safety cap exceeds the 15-line block size.

**Tests**: 33/33 pass (25 guard-branch-not-main + 8 guard-husky-branch).

**Result**: pass

## Dismissals

None

<!-- audited-at: f8a8f26579c1386145fa260d24b73c049e7b3a8d -->

## Gate 5: docs-and-tests-review

**Scope:** `origin/main..HEAD` (8 commits). Feature commits: a3e2c3b, f766b22, 8aaf8c3, f31b4b2, f8a8f26. Spec/task commits: ac32ffd, c2a14cb. Out-of-scope squash: 0755aca (merge-devshop-rename-detect, unrelated feature).

**Verdict: findings (3) pending** -- 1 medium, 2 low

---

### Docs Review

#### Finding D1 (medium): hooks.md diagram step count and range reference stale after renumbering

`kit/docs/guide/hooks.md` line 50 says "runs 6 steps sequentially" and lists 2a-2f, but the production `.husky/pre-commit` has 7 distinct steps (the `bats kit/tests/` step is missing from the numbered diagram). The correct count is 7: Claude branch guard, symlinks, lint-staged, typecheck, gitleaks, bats, devshop guards.

Additionally, line 106 says "Steps 2a-2d and 4 are all blocking" -- this range was correct on origin/main (2a=symlinks through 2d=gitleaks) but the renumbering shifted indices: 2d is now typecheck and gitleaks is 2e. The range should be "Steps 2a-2e and 4".

Note: the missing bats step in the diagram is a pre-existing bug (origin/main said "5 steps" and also omitted bats). This branch incremented from 5 to 6 but didn't fix the pre-existing gap.

**Files:** `kit/docs/guide/hooks.md` lines 50, 106

#### Finding D2 (low): OVERVIEW.md workspace layout says "6-step" but event flow says "7 steps"

`kit/docs/OVERVIEW.md` has two references to step count in the workspace layout section:
- Line 97: `.husky/pre-commit ... (6-step chain + 4 guards)`
- Line 107: `hooks/pre-commit.sh  Orchestrates the 6-step + 4-guard chain`

Both say "6-step" but the event flow diagram immediately below (line 143) correctly says "7 steps + devshop guards" and lists all 7. The workspace layout should say "7-step" to match.

Pre-existing: origin/main had "5-step" in the layout and "6 steps" in the event flow. The branch incremented both by 1, preserving the off-by-one.

**Files:** `kit/docs/OVERVIEW.md` lines 97, 107

#### Docs coverage: what is accurate

- `CLAUDE.md` Known Footgun "Never commit directly to main" -- correctly documents both layers (PreToolUse + husky), the TOCTOU race explanation, the worked incident (`ef6db18`), and the fail-open posture for humans. Matches the implementation exactly.
- `hooks.md` table (section 2, "Husky pre-commit") -- Claude branch guard row is correct: describes it as backstop for PreToolUse, notes TOCTOU race closure, marks "Yes -- Claude only" blocking.
- `hooks.md` commit flow diagram -- Claude branch guard is correctly placed as step 2a with the TOCTOU explanation. The step numbering issue (D1 above) is the only gap.
- `OVERVIEW.md` event flow diagram -- correctly lists all 7 steps including the Claude branch guard as step 1.
- `kit/TODOS.md` -- investigation entry (original lines 53-68) properly deleted; no stale cross-references remain.

### Tests Review

#### Finding T1 (low): detached HEAD / empty branch name path untested

When `git branch --show-current` returns empty (detached HEAD, bare repo, or the `2>/dev/null || echo ""` fallback fires), `_current_branch=""` -- which does not match `main` or `master`, so the guard fails open (allows the commit). This is the correct and documented behavior (spec Gotcha #3: "If the harness ever stops setting it, the guard becomes a no-op (fails open to 'allow')"), but there is no explicit test for `_current_branch=""`.

A test like `git -C "$TEST_REPO" checkout --detach; run_guard CLAUDECODE=1; assert_success` would close this gap.

**Severity:** Low. The behavior is correct (fail-open) and unlikely to regress since the guard only activates on exact string match `main` or `master`. The risk of an empty string matching either is essentially zero.

#### Tests coverage: what is adequate

- **guard-husky-branch.bats** (8 tests): Full Claude/human x main/feature/master matrix. Edge cases for CLAUDECODE="" and CLAUDECODE=0. Parity test to catch drift between production guard and test fixture. Comprehensive.
- **guard-branch-not-main.bats** (2 new tests): Regression anchors for the exact 2026-05-20 incident command forms (multi `-c` flag, env-var prefix + `-c` flag). These confirm the PreToolUse hook was never the bug, locking in that future refactors don't regress these forms.
- **Spec test #8 deviation:** Spec specified "blocks even with -c flags (TOCTOU regression)" as test 8 but the implementation has a parity test instead. This is a reasonable improvement -- the `-c` flags test would be testing a non-existent code path (the husky guard doesn't parse commands), while the parity test provides genuine regression protection against guard/fixture drift.
- **Exit code convention:** Tests correctly assert `exit 1` for the husky guard (standard git hook) vs `exit 2` for the PreToolUse hook (Claude Code convention). Matches the spec's Gotcha #5.

### Spec-to-delivery gap analysis

| Spec item | Delivered? | Notes |
|---|---|---|
| 1. Husky branch guard | Yes | Lines 7-21 of `.husky/pre-commit`, exactly as specified |
| 2. PreToolUse regression tests | Yes | 2 tests added to guard-branch-not-main.bats |
| 3. Husky guard bats tests | Yes | 8 tests in guard-husky-branch.bats (test #8 shape changed, see above) |
| 4. CLAUDE.md Known Footgun | Yes | Two-layer defense + incident documented |
| 5. Close TODOS entry | Yes | 16-line investigation entry deleted from kit/TODOS.md |
| Extra: hooks.md diagram | Yes (finding D1) | Diagram updated but step count off by one |
| Extra: OVERVIEW.md | Yes (finding D2) | Event flow correct, workspace layout off by one |

---

## Dismissals

None

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

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention

**Result: pass**

Checked 5 devshop conventions against the diff (origin/main..HEAD, 7 commits):

1. **New scripts under `kit/scripts/` have paired bats tests** -- N/A. No new scripts; the guard is inline in `.husky/pre-commit`.
2. **Shell scripts have expected structure** -- `.husky/pre-commit` uses the existing dash-to-bash re-exec pattern (husky invokes with `sh -e`; line 3-5 re-execs under bash). New code follows the same `[ "$VAR" = "val" ]` POSIX-compatible idioms inside the bash context. New bats files have `#!/usr/bin/env bats` shebangs. Pass.
3. **Bats test files follow naming conventions and use shared helpers** -- Both new files (`guard-branch-not-main.bats`, `guard-husky-branch.bats`) use the `guard-*` prefix consistent with existing guard tests (`guard-clean-tree.bats`, `guard-hook-bypass.bats`, etc.). Both `load helpers/setup`, call `create_test_repo`, and use bats-assert matchers. `guard-husky-branch.bats` includes a parity test (test 8) that extracts the guard block from `.husky/pre-commit` and diffs against the test fixture to catch drift. Pass.
4. **Guide docs linked in routing index** -- N/A. No new guide docs; only updates to existing `hooks.md` and `OVERVIEW.md`.
5. **Commit messages follow conventional commit format** -- All 7 commits use `type(scope): description`. Types: `fix`, `test`, `docs`, `chore`. All subjects under 72 chars. Scope is consistently `hooks` for implementation commits and `fix-branch-guard-on-main` for spec scaffolding. Pass.

Additional checks performed:
- **Step count consistency across docs**: OVERVIEW.md compact refs (lines 96, 107) say "6-step chain + 4 guards"; event flow diagram (line 142) says "7 steps + devshop guards"; hooks.md says "6 steps." The +1 delta between compact refs and event flow diagram is the devshop-only bats step — same pattern as origin/main (was 5/6, now 6/7). Consistent.
- **TODOS closure**: The investigation TODO for `check-branch-not-main.sh` (17-line block) is deleted from `kit/TODOS.md` in the same branch that ships the fix. The companion TODO for rename-detect fallback is correctly preserved and expanded. Follows the "close tracker entries when a fix ships" convention.
- **CLAUDE.md Known Footgun update**: The "Never commit directly to main" entry is expanded to describe both enforcement layers with worked-incident reference. No new footgun entry created (the guard is a fix, not a new trap). Appropriate.

## Dismissals

None


## Phase 3 → 4 advance log

### 2026-05-27T06:24:53Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T06:24:53Z -->

### 2026-05-27T06:24:53Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T06:24:53Z -->

### 2026-05-27T06:24:53Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants are the test surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T06:24:53Z -->

### 2026-05-27T06:24:53Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T06:24:53Z -->

## Audit 1: manual (2026-05-26)

<!-- audited-at: 3b284ae59f209c8209b67636cfdacbfe83945878 -->
<!-- range: f8a8f26579c1386145fa260d24b73c049e7b3a8d..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

All four commits in range `f8a8f26..HEAD` are bookkeeping (tasks.md update, BUILD-LOG entry, Phase 3 gate results, step count corrections). Changes outside `specs/`:

- **BUILD-LOG.md** — new entry follows established format, headline/summary accurate.
- **PLAN.md** — `fix-branch-guard-on-main` row removed from Planned table; correct (feature shipping).
- **kit/docs/guide/hooks.md** — step count corrected from 6 to 7 (adds 2a Claude branch guard + 2f bats = 7 total). Consistent with the actual `.husky/pre-commit` script.
- **kit/docs/OVERVIEW.md** — project-repo tree labels corrected from "6-step" to "5-step" (project template has no Claude branch guard and no bats step = 5 steps). Event-flow diagram correctly shows "7 steps + devshop guards". Internal consistency verified: lines 96/107 (project tree = 5-step) vs line 142 (devshop event flow = 7 steps) describe different contexts.

No stale "6-step" references remain anywhere in `kit/docs/` or `CLAUDE.md`. No TODOS/ROADMAP entries left unclosed. CLAUDE.md Known Footguns section was updated in an earlier commit (outside this range) and is consistent.

### Bypass trailer audit

No `Docs-Coverage-Bypass:` or `Tests-Coverage-Bypass:` trailers found in range.

### Tests findings

- (none)

Range `f8a8f26..HEAD` (4 commits) contains only bookkeeping and doc corrections:

| Commit | File | Nature |
|--------|------|--------|
| `da6216c` | `kit/docs/guide/hooks.md` | Step count correction (6 -> 7) + step renumber |
| `da6216c` | `kit/docs/OVERVIEW.md` | Step count correction (6 -> 5) in two tree-diagram lines |
| `c43ef6d` | `specs/` artifacts | Phase 3 gate results + review.md |
| `23a47b2` | `BUILD-LOG.md` | Build log entry for the feature |
| `3b284ae` | `specs/` artifacts | tasks.md final state |

No new code, no behavior changes, no test-requiring surface.

### Bypass trailer audit

- (none found)

No `Tests-Coverage-Bypass:` trailers in the range.
