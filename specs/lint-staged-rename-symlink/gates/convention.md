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
