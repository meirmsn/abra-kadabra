findings: high=0 medium=0 low=0

- (none)

Coverage assessment: COMPLETE. The two new bats assertions in kit/tests/util-ak-build-devshop-mode.bats pin exactly the two non-obvious lines the fix introduces:
  - test "SKILL.md mode detection is worktree-aware via --git-common-dir" (lines 36-43) asserts BOTH the `git rev-parse --git-common-dir` read AND the `/devshop/.git` comparison are present — covers the OR-in of the worktree signal.
  - test "SKILL.md mode detection absolutizes a relative common-dir" (lines 45-50) asserts the `GIT_COMMON="$GIT_ROOT/$GIT_COMMON"` absolutization — covers the main-checkout case that would otherwise fall through to project mode.
The pre-existing assertions (MODE=devshop, MODE=project, GIT_ROOT --show-toplevel) still pass, so the OR-branch logic remains pinned at both ends. Empirically validated the shell logic from both the linked worktree (raw common-dir already absolute → /devshop/.git → devshop) and the main /devshop checkout (relative ".git" → absolutized → /devshop/.git → devshop) — both resolve to MODE=devshop as intended.

Test-style note (not a finding): these are grep-based content-presence assertions, not behavioral execution of the extracted shell. This matches the established pattern of util-ak-build-devshop-mode.bats (header comment line 7: "Pattern follows util-ak-build-skill.bats (grep distinctive phrases)"), so it is the correct convention for this file, not a coverage gap. Full file suite green: 29/29.
