# Tasks: fix-branch-guard-on-main

## Task 1: Add regression-anchor bats tests for PreToolUse hook
- **File:** `kit/tests/guard-branch-not-main.bats` (existing, append)
- **Status:** done
- **Tests:** 2 new tests — exact incident command form + env-var prefix compound form
- **Done when:** All new + existing tests pass

## Task 2: Add Claude-specific branch guard in .husky/pre-commit
- **File:** `.husky/pre-commit` (modify)
- **Status:** done
- **Changes:** Move `_current_branch` early, insert CLAUDECODE=1 guard block
- **Done when:** CLAUDECODE=1 blocks on main; unset CLAUDECODE passes on main

## Task 3: Add bats tests for the husky branch guard
- **File:** `kit/tests/guard-husky-branch.bats` (new)
- **Status:** done
- **Tests:** 8 tests — Claude/human x main/feature matrix + edge cases + parity
- **Done when:** All 8 tests pass, parity test confirms guard matches production

## Task 4: Document multi-session TOCTOU + close TODOS entry
- **Files:** `CLAUDE.md`, `kit/TODOS.md`
- **Status:** done
- **Changes:** Expand Known Footgun entry, delete closed TODOS investigation entry
- **Done when:** Docs updated, TODOS entry removed, full bats suite passes
