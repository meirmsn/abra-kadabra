<!-- audited-at: e8c851d7acea4ad63d0dddc899b1d04e47f3ead7 -->
# Pre-ship review — lint-staged-rename-symlink

## Router Summary

- Gates dispatched: 6
- Pre-composed carve-outs: 13
- Structural blocked (devshop-self-mode): 4 (Gates 7, 8, 9, 10)
- Findings: 7 doc accuracy fixes applied (Gate 1)
- Overall: pass (all findings resolved)

## Gate 1: docs-check

**Scope**: reference docs (`kit/docs/guide/*.md`, `CLAUDE.md`) vs diff on `main...HEAD`.

The diff adds `--no-stash` to both pre-commit hooks, disabling lint-staged's `git stash` backup. Several guide passages now describe behavior that no longer occurs.

### Finding 1 — `kit/docs/guide/hooks.md` line 55: step list says `pnpm exec lint-staged`

The ASCII tree (§ 2 overview) shows `2c. pnpm exec lint-staged` without `--no-stash`. Should read `pnpm exec lint-staged --no-stash` to match the actual hook.

**Severity**: low (cosmetic accuracy in reference tree).

### Finding 2 — `kit/docs/guide/hooks.md` line 138: table row says `pnpm exec lint-staged`

The blocking-hooks table shows the bare command. Should include `--no-stash`.

**Severity**: low (cosmetic accuracy in reference table).

### Finding 3 — `kit/docs/guide/hooks.md` lines 156: stash behavior paragraph is factually wrong

> "Both tasks modify files, so lint-staged's default `stash: true` behavior fires on every pre-commit: a backup of staged + unstaged state is created via `git stash create` and stored under a `refs/lint-staged/*` namespace…"

With `--no-stash`, lint-staged no longer creates any stash backup. This paragraph describes behavior that is now disabled. It should be updated to note that `--no-stash` is passed, the stash backup is disabled, and the `refs/lint-staged/*` machinery no longer runs.

**Severity**: medium (misleading — someone debugging a stash issue would read this and look for `refs/lint-staged/*` activity that no longer exists).

### Finding 4 — `kit/docs/guide/hooks.md` lines 319: "Recovering a vanished stash" says lint-staged is "the leading suspect"

> "The pre-commit lint-staged backup mechanic (§ 2 — lint-staged config) is the leading suspect — it uses `git stash create` machinery for its own backup and runs on every commit"

Now that `--no-stash` disables the backup, lint-staged no longer calls `git stash create` during pre-commit. The "runs on every commit" claim is false. Should note the backup mechanic is now disabled via `--no-stash`, which narrows the suspect surface (cross-reference: the TODOS entry and SKILL.md already note this).

**Severity**: medium (misleading investigation guidance — someone would chase a suspect that's been eliminated).

### Finding 5 — `kit/docs/guide/hooks.md` line 344: prevention section says stashes "still at risk if lint-staged fires"

> "Operator stashes made BEFORE invoking the skill are still at risk if lint-staged fires during the merge."

With `--no-stash`, lint-staged no longer touches the stash. This risk statement is no longer accurate.

**Severity**: medium (overstates residual risk, could cause unnecessary workarounds).

### Finding 6 — `CLAUDE.md` line 113: known footgun says lint-staged stash machinery is "the leading suspect"

> "Lint-staged's pre-commit stash-backup machinery is the leading suspect; root cause is still under investigation."

Should note that `--no-stash` now disables lint-staged's stash backup, reducing the suspect surface. The footgun entry should still exist (the vanishing-stash bug is not confirmed closed), but the characterization of lint-staged as "leading suspect" with active stash machinery should be updated to reflect that the machinery is now off.

**Severity**: medium (stale investigation guidance in the highest-visibility doc).

### Finding 7 — `kit/docs/guide/architecture.md` line 217: migration-commit gotcha mentions lint-staged's stash/restore

> "`git rm --cached` combined with lint-staged's stash/restore can delete files from disk if they're gitignored."

With `--no-stash`, lint-staged no longer performs stash/restore. The migration-commit advice to use `--no-verify` is still sound as a general precaution, but the stated mechanism (lint-staged stash/restore) no longer applies.

**Severity**: low (the advice `--no-verify` is still correct; only the stated mechanism is outdated).

---

## Dismissals

No findings dismissed. All 7 findings are doc-accuracy issues caused by the `--no-stash` change making existing prose factually incorrect. None are pre-existing issues unrelated to the diff.

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

- Result: pass
- bats kit/tests/: 1406/1406 pass (includes 4 new convention-lint-staged-no-stash tests)

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

Reviewed the diff (main...HEAD, 7 files, 283 insertions / 24 deletions) for unnecessary complexity, redundant tests, and over-engineering.

### Files reviewed

1. `.husky/pre-commit` -- 1-line change (`--no-stash` flag). Minimal.
2. `template/.husky/pre-commit` -- 1-line change. Minimal.
3. `kit/tests/convention-lint-staged-no-stash.bats` -- 36 lines, 4 test cases.
4. `kit/TODOS.md` -- deleted ~16-line resolved entry; updated sibling entry's candidate-fix paragraph.
5. `.claude/skills/devshop/merge-devshop/SKILL.md` -- 4-line cross-reference update.
6. `specs/lint-staged-rename-symlink/spec.md` -- spec artifact (not shipped code).
7. `specs/lint-staged-rename-symlink/tasks.md` -- task tracker (not shipped code).

### Negative test cases (tests 3-4): evaluated, kept

The bats test has 2 positive cases (flag present) and 2 negative cases (no bare invocation without the flag). The negative cases guard a distinct failure mode: someone adds a second `pnpm exec lint-staged` line without `--no-stash`. The positive tests would still pass in that scenario (grep output contains `--no-stash` from the flagged line) while the negative tests would catch the bare invocation.

This scenario is unlikely but the cost is 10 lines of trivial shell. The tests are simple grep pipelines, not over-engineered. Removing them would save negligible complexity while weakening coverage. Kept as-is.

### Result

No simplification opportunities found. The diff is already minimal: 2 one-line hook edits, 1 convention test, 1 TODOS cleanup, 1 cross-reference update.

## Dismissals

None -- no findings to dismiss.

<!-- audited-at: 0f46375e0306aec2f8ad4fee7dfec78e0ec2ff5d -->

## Gate 5: docs-and-tests-review

### Test coverage

| Area | Status | Notes |
|------|--------|-------|
| Convention test (`kit/tests/convention-lint-staged-no-stash.bats`) | pass | 4 cases: positive match + negative-guard for both devshop and template pre-commit hooks. Guards against regression if hooks are regenerated. |
| Unit / integration tests | n/a | Fix is a CLI flag addition to hook config, not code logic. No runtime paths to unit-test. Convention test is the correct level. |

**Assessment**: Test coverage is sufficient. The fix is a config flag (`--no-stash`) appended to two shell hook files. The convention test verifies presence of the flag in both hooks and absence of bare (unflagged) invocations. No additional test level is warranted.

### Docs coverage

| Doc | Change | Status |
|-----|--------|--------|
| `kit/TODOS.md` | Deleted the "lint-staged stash backup chokes on rename + new-symlink-at-old-path" entry (closed). Updated the sibling "vanishing stash" entry to note `--no-stash` is already shipped, reducing the suspect surface. | pass |
| `.claude/skills/devshop/merge-devshop/SKILL.md` | Updated cross-reference from "bug is tracked separately" to "bug is fixed -- `--no-stash` disables lint-staged's `git stash` backup". | pass |
| `PLAN.md` line 84 | **Stale cross-reference.** The row's "Source" column points to `kit/TODOS.md` section "lint-staged stash backup chokes on rename + new-symlink" -- that section was deleted by this diff. | low finding |

**Stale reference search**: Searched `CLAUDE.md`, `kit/docs/`, `.claude/skills/`, and `kit/TODOS.md` for "lint-staged stash backup chokes", "rename.*symlink", and "--no-stash". Only hit beyond the updated files is the `PLAN.md` row (line 84). The bats test file at `kit/tests/util-ak-merge-devshop.bats:634` mentions "lint-staged stash bug" in the context of the Phase 2 detection test -- this is still accurate (the detection skill test is complementary, not stale).

### Summary

- **Findings**: high=0 medium=0 low=1
- **Low-1**: `PLAN.md` line 84 cross-ref to deleted TODOS entry is now a broken pointer. Non-blocking -- PLAN.md is a planning artifact and the row description is still accurate; the pointer just leads nowhere.

## Dismissals

| # | Finding | Severity | Disposition | Rationale |
|---|---------|----------|-------------|-----------|
| Low-1 | `PLAN.md` line 84 stale TODOS cross-ref | low | dismissed | PLAN.md is an internal planning table, not operator-facing docs. The row description ("Fix lint-staged stash backup failure...") is correct; only the Source column's deep-link is broken. Fixing it is a cosmetic follow-up, not a ship-blocker. The feature itself is fully documented in the updated SKILL.md and TODOS.md entries. |

## Gate 6: /review

**Scope reviewed**: `git diff main...HEAD` (7 files, 283 insertions, 24 deletions across 6 commits on `fix/lint-staged-rename-symlink`).

### 1. Does `--no-stash` fix the rename+symlink stash failure?

**Yes.** `--no-stash` disables lint-staged's `git stash` backup entirely (lint-staged v15 CLI flag). The error `error: 'OLD/file' is beyond a symbolic link` originates from `git stash` itself when it encounters a symlink at a path that was previously a real file in the staged diff. With stash disabled, lint-staged never calls `git stash`, so the error never fires. Correct fix for the stated problem.

### 2. TODOS entry deletion

**Clean.** The full block (from `- [ ] **lint-staged stash backup chokes...` through the `[v0+, hook-bug, ...]` tag line) is deleted. The transition from the preceding entry (`[v1, kit-script-generalization...]`) to the next entry (`- [ ] **Root-cause investigation: operator stashes vanish...`) is clean with no orphaned blank lines.

The sibling "Root-cause investigation" entry's "Candidate fixes" paragraph (line 410) was correctly updated to note that `--no-stash` is already applied, reducing the suspect surface. Good cross-reference maintenance.

The `PLAN.md` Source column still references `kit/TODOS.md § lint-staged stash backup chokes on rename + new-symlink` — this is historical provenance (same pattern as `hero-upload-private-repos` whose TODOS entry was also deleted), not a live pointer. Not a defect.

### 3. Bats test correctness

**Correct.** Four test cases:
- Tests 1-2 (positive): grep for `pnpm exec lint-staged` in each hook, assert the output contains `--no-stash`. Verifies the flag is present.
- Tests 3-4 (negative): grep for `pnpm exec lint-staged` then pipe through `grep -v -- '--no-stash'` — asserts failure (no bare invocation without the flag). Catches regression where someone adds a second lint-staged call without `--no-stash`.

The `setup()` uses `TESTS_DIR` (set by `helpers/setup`) to compute `DEVSHOP_ROOT` via `cd "$TESTS_DIR/../.." && pwd`. This correctly resolves to the repo root from `kit/tests/`. Both hooks use `skip` if the file doesn't exist — safe for template-only or devshop-only checkouts.

### 4. SKILL.md cross-reference update

**Accurate.** Lines 1260-1264 correctly changed from "tracked separately (see kit/TODOS.md entry...)" to "is fixed -- `--no-stash` disables lint-staged's `git stash` backup in both pre-commit hooks (shipped via `fix/lint-staged-rename-symlink`)". The branch name reference matches the actual branch (`fix/lint-staged-rename-symlink`).

**Pre-existing stale reference (not introduced by this diff):** SKILL.md line 1273 says `invoked from .husky/pre-commit:5` — lint-staged is on line 27, not line 5. This was already wrong on `main` before this branch. Same stale `:5` reference exists in `kit/TODOS.md` line 406 (the sibling "Root-cause investigation" entry). Neither was touched by this diff's hunks. Not a regression.

### 5. Regressions from `--no-stash`

**No regressions identified.** The `--no-stash` flag has two effects in lint-staged v15:
1. Disables `git stash` backup before running tasks — the intended fix.
2. Implies `hidePartiallyStaged: false` — partial staging (individual hunks) will expose unstaged changes to linters. This is explicitly accepted in spec decision D3 (partial staging is rare in the devshop workflow).

The pre-commit hook's remaining steps (turbo typecheck, gitleaks, bats suite, kit hooks) are unaffected — they don't depend on lint-staged's stash behavior.

### Verdict

**Pass.** The fix is minimal, correct, well-tested, and properly documented. No regressions.

## Dismissals

No findings to dismiss.

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

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

**Scope**: `main...HEAD` (8 commits, `b7469c1..5474324`)

### 1. Bats test file: `kit/tests/convention-lint-staged-no-stash.bats`

Compared against `kit/tests/guard-husky-branch.bats` and broader test corpus.

| Check | Status | Notes |
|---|---|---|
| Shebang + header comment | pass | `#!/usr/bin/env bats` + descriptive comment on line 2-3 |
| `setup()` loads `helpers/setup` | pass | First line of setup |
| `DEVSHOP_ROOT` derivation | pass | Uses `$(cd "$TESTS_DIR/../.." && pwd)` pattern (same as `util-husky-hooks.bats`) |
| Test names: descriptive, colon-separated scope | pass | `"devshop .husky/pre-commit: lint-staged invoked with --no-stash"` |
| Skip guard on missing file | pass | `[ -f "$DEVSHOP_HOOK" ] || skip` — standard pattern |
| `run` + `assert_*` usage | pass | Uses `run grep`, `assert_success`, `assert_output --partial`, `assert_failure` |
| Positive + negative test coverage | pass | Tests 1-2 positive (flag present), tests 3-4 negative (no bare invocation) |
| No hardcoded paths | pass | Derives paths from `$TESTS_DIR` |

**Naming prefix**: `convention-` is a new prefix in the test corpus (all existing files use `guard-`, `util-`, `preship-`, `template-`, `structural-`, etc.). The test's purpose (enforce a convention on production files) is distinct from `guard-*` tests (test script behavior) and `structural-invariants.bats` (wiring/cross-reference checks), so the new prefix is defensible. Not a defect.

### 2. Commit messages

```
5474324 feat(hooks): catch prose in migration rollback blocks at commit time
0f46375 chore(lint-staged-rename-symlink): tasks.md (Phase 2 complete)
4b773d6 chore(roadmap): close lint-staged stash backup TODOS entry
a8f2cf1 test(hooks): bats convention test for lint-staged --no-stash
0d68c3d fix(hooks): add --no-stash to lint-staged in pre-commit hooks
760288a chore(lint-staged-rename-symlink): spec (Phase 1)
57da3f1 chore(lint-staged-rename-symlink): Phase 0 spec skeleton (decisions)
b7469c1 fix(plan): close hero-upload-private-repos — not reproducible
```

| Check | Status | Notes |
|---|---|---|
| Conventional commit format (`type(scope): description`) | pass | All 8 commits follow the pattern |
| Types used correctly | pass | `fix` for bug fixes, `test` for test-only, `chore` for spec/tasks/cleanup, `feat` for new capability |
| Scope consistency | pass | `hooks` for hook changes, `lint-staged-rename-symlink` for spec artifacts, `roadmap`/`plan` for doc updates |
| Squashed commit (`5474324`) has structured body | pass | Full conventional-commit body with `## Squashed commits` section per merge-devshop convention |
| No WIP/fixup commits | pass | All messages are descriptive |

**Note**: Commit `5474324` (`feat(hooks): catch prose in migration rollback blocks`) and `b7469c1` (`fix(plan): close hero-upload-private-repos`) appear to be from other features squash-merged onto this branch. This is an unusual pattern (branch carries commits from unrelated features) but not a convention violation -- they were likely already on the branch before the lint-staged work started, or landed via rebase.

### 3. Shell scripts (modified hooks)

| Check | Status | Notes |
|---|---|---|
| `.husky/pre-commit`: bash re-exec guard intact | pass | Lines 1-5 unchanged |
| `.husky/pre-commit`: Claude branch guard intact | pass | Lines 7-21 unchanged |
| `.husky/pre-commit`: lint-staged line is sole change | pass | `pnpm exec lint-staged` -> `pnpm exec lint-staged --no-stash` |
| `.husky/pre-commit`: downstream pipeline intact | pass | turbo typecheck, gitleaks, bats suite, kit hook all unchanged |
| `template/.husky/pre-commit`: lint-staged line is sole change | pass | Same 1-line change |
| `template/.husky/pre-commit`: downstream pipeline intact | pass | turbo typecheck, gitleaks, project hook all unchanged |
| No trailing whitespace or formatting changes | pass | Clean diff |

### Summary

All convention checks pass. The `convention-` test filename prefix is new but justified by the test's purpose. Commit messages follow conventional commit format consistently. Hook modifications are minimal and preserve existing structure.

**Result: pass**

## Dismissals

None. No findings to dismiss.


## Phase 3 → 4 advance log

### 2026-05-27T07:32:19Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:32:19Z -->

### 2026-05-27T07:32:19Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:32:19Z -->

### 2026-05-27T07:32:19Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:32:19Z -->

### 2026-05-27T07:32:19Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:32:19Z -->
