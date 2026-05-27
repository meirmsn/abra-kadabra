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
