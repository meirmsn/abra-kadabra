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
