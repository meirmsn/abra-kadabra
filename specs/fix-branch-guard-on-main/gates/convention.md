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
