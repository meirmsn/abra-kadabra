## Gate 5: docs-and-tests-review

<!-- audited-at: a429760a4cdbb5545fd4e9542020b62e72c9683b -->

findings: high=0 medium=2 low=3

### Docs review

**Scope**: `kit/docs/guide/hooks.md` is the only doc changed. Checked whether CLAUDE.md, `kit/docs/guide/conventions.md`, or template CLAUDE.md need updates.

**hooks.md additions (two locations)**:

1. Flow diagram (section 2e, devshop pre-commit guards): adds `check-rollback-prose.sh (project only)` with a three-line description. Placement is correct -- between `check-docs-coverage-project.sh` and `commit-guard.sh`, matching the wiring order in `pre-commit.sh`.

2. Guards table: adds a full row with type `Deterministic`, scope `Project repo only`, comprehensive description of heuristic + skip conditions + worked incident reference, and bypass column `No bypass -- fix the prose line`. Row content is accurate and thorough.

**Other docs -- no updates needed**:

- `CLAUDE.md` -- does not enumerate individual pre-commit scripts; references hooks.md for the full list. No update needed.
- `kit/docs/guide/conventions.md` -- covers testing philosophy and metrics lifecycle, not individual hook scripts. No update needed.
- Template CLAUDE.md -- project-side CLAUDE.md is self-sufficient per the design principle; the SessionStart hook bridges devshop context. No update needed.
- `check-docs-coverage-devshop.sh` already maps `kit/scripts/commit-hooks/**` to `kit/docs/guide/hooks.md`, so the docs-coverage guard will correctly enforce co-changes for this script in future commits.

**Docs verdict**: Adequate. The two additions accurately reflect the script's behavior and are placed in the correct locations.

### Tests review

**14 bats tests in `guard-rollback-prose.bats`**:

| # | Test | Category | Verdict |
|---|------|----------|---------|
| 1 | No migration files staged | Pass path | OK |
| 2 | Valid SQL-only rollback block | Pass path | OK |
| 3 | noop rollback (lowercase) | Pass path | OK |
| 4 | Noop rollback (mixed case) | Pass path | OK |
| 5 | Lowercase continuation lines | Pass path | OK |
| 6 | Lines starting with parens/quotes/digits | Pass path | OK |
| 7 | Lines starting with parentheses | Pass path | OK (redundant with #6 but harmless) |
| 8 | Prose line in rollback block | Fail path | OK |
| 9 | Worked incident pattern (home-os PR #35) | Fail path | OK |
| 10 | No ROLLBACK block in migration | Pass path | OK |
| 11 | Empty rollback block | Edge case | OK |
| 12 | Multiple files, one with prose | Edge case | OK -- verifies only offending file is reported |
| 13 | Non-migration SQL files ignored | Edge case | OK |
| 14 | All D2 SQL keywords recognized | Pass path | OK -- exercises every keyword from the decision list |

**pre-commit-router.bats changes**: correctly adds mock stub creation for the new script, updates the project-repo test name and assertions to verify `check-rollback-prose.sh.args` exists, and adds negative assertions for devshop-repo and devshop-self tests to verify it is NOT called in those modes.

**Missing test coverage (medium)**:

- **(M1)** No test for mixed-case SQL keywords (e.g., `-- Drop TABLE IF EXISTS items;`). The script uppercases `first_word` via `awk '{print toupper($1)}'`, so this should work, but there is no test confirming it. The spec's D2 decision implies case-insensitive keyword matching but the test suite only exercises uppercase keywords (test #14) and lowercase noop (tests #3, #4).

- **(M2)** No test for multiple prose lines in a single file. The current fail-path tests have exactly one prose line each. A test confirming that all prose lines are reported (not just the first) would strengthen confidence in the while-loop iteration. The script does not `break` after finding prose, so it should report all, but this is untested.

**Minor gaps (low)**:

- **(L1)** No test for the `--` prefix (no space after double-dash). The script handles `"--"*` as a fallback after `"-- "*` (line 51), but no test exercises this path. This is an uncommon format in practice.

- **(L2)** No test for `-- ROLLBACK:` marker line with trailing text (e.g., `-- ROLLBACK: Undo the table creation`). The script's case pattern `"-- ROLLBACK:"*` matches any trailing text and then `continue`s without checking the marker line itself. This is correct behavior but untested.

- **(L3)** No test for `-- NOOP: nothing` (all-caps). Tests cover lowercase `noop:` and mixed `Noop:` but not `NOOP:`. The script logic handles this correctly (toupper + colon-strip yields `NOOP` which matches), but there is no explicit test.

### Summary

The documentation is adequate and accurate. The test suite covers all 8 spec-listed test scenarios plus 6 additional edge cases, and the router integration tests correctly verify project-only wiring. Two medium gaps (mixed-case keywords, multiple-prose-line reporting) and three low gaps (no-space prefix, marker trailing text, all-caps NOOP) exist but do not represent correctness risks -- the script logic handles all of these correctly; the gaps are coverage completeness, not behavior bugs.

## Dismissals

None
