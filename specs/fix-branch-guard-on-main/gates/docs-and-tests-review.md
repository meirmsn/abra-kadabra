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
