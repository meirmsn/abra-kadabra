<!-- audited-at: a429760a4cdbb5545fd4e9542020b62e72c9683b -->

# Pre-ship review: rollback-prose-lint

## Preflight

- TOUCHES_UI=
- TOUCHES_MIGRATIONS=
- TOUCHES_FUNCTIONS=
- TOUCHES_KIT=yes
- TOUCHES_CODE=
- TOUCHES_USER_CODE=
- HAS_TURBO=
- Chromium: not needed
- Supabase: not needed
- Result: pass

## Gate 1: docs-check

**Result: pass**

### Checked surfaces

| Doc file | Coverage | Notes |
|----------|----------|-------|
| `kit/docs/guide/hooks.md` | Adequate | New `check-rollback-prose.sh` documented in three places: Commit Flow diagram (line 73-76), Guards table (line 169), and position in the pre-commit guard ordering matches `pre-commit.sh` wiring |
| `CLAUDE.md` | N/A | No devshop-side convention change; project-only hook does not require CLAUDE.md entry |
| `kit/docs/OVERVIEW.md` | N/A | No architectural change |

### Detail

The diff adds `check-rollback-prose.sh` and wires it into `pre-commit.sh` under the `/workspace` (project) case. The `hooks.md` doc update (Task T-4) covers:

1. **Commit Flow diagram** -- entry under step 2e devshop pre-commit guards, positioned between `check-docs-coverage-{project,devshop}.sh` and `commit-guard.sh`, matching the actual call order in `pre-commit.sh`.
2. **Guards table** -- full row with Type (Deterministic), scope (project only), description (what it scans, what it skips, worked incident), and bypass (No bypass -- fix the prose line).
3. The guard's behavior (SQL keyword allow-list, noop escape hatch, skip conditions) is accurately summarized without duplicating implementation detail.

No gaps found.

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

**Outcome**: pass

**Suite**: bats (devshop-self mode)
**Command**: `kit/tests/lib/bats-core/bin/bats kit/tests/`
**Result**: 1397/1397 tests passed

Two pre-existing test gaps were found and fixed during this run:
1. `pre-commit-router.bats` test 410 — mock list missing `check-rollback-prose.sh` stub, causing `bash: ...check-rollback-prose.sh: No such file or directory` (exit 127). Fixed by adding the stub to the setup mock list and adding positive/negative routing assertions.
2. `structural-invariants.bats` test 683 — `check-rollback-prose.sh` tracked as 100755 instead of the required 100644. Fixed via `git update-index --chmod=-x`.

After fixes, full suite passes clean.

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

**Scope reviewed:** `check-rollback-prose.sh`, `pre-commit.sh` wiring, `guard-rollback-prose.bats`, `hooks.md` docs update.

### Finding 1 (fixed): Dead noop: case branch + redundant subshell

`check-rollback-prose.sh` lines 94-103 contained two noop checks:

1. `case "$first_word" in NOOP:)` -- **dead code**. `first_word` was already uppercased via `awk '{print toupper($1)}'` and had trailing non-alpha characters stripped via `sed 's/[^A-Z]$//'`, so the colon in `NOOP:` was already removed. This branch could never match.
2. A fallback that spawned a new subshell (`printf | awk`) to re-extract the first word from `$trimmed` and glob-match case-insensitively. This worked but was unnecessary since `first_word` was already case-normalized.

**Fix:** Replaced both blocks with a single `case "$first_word" in NOOP)` -- matches the already-uppercased, colon-stripped value. Eliminates the dead branch and one subshell per non-keyword line.

**Commit:** `678455e` -- `fix(hooks): remove dead noop: case branch in rollback prose lint`

### Other areas reviewed (no findings)

- **pre-commit.sh wiring**: Correctly placed in the `/workspace` case, after `check-docs-coverage-project.sh` and before `commit-guard.sh`. Consistent with other project-only checks.
- **Bats tests**: 14 tests with good coverage -- pass cases (SQL keywords, noop variants, lowercase continuations, special chars, no rollback block, empty block), fail cases (prose line, worked incident pattern), edge cases (multiple files, non-migration SQL). All use the shared `setup.bash` helpers correctly.
- **Docs update**: `hooks.md` tree diagram and guard-reference table entries are accurate and consistent with the script's behavior.
- **Dash compatibility**: Script uses `#!/bin/sh`, `set -eu`, POSIX `case` statements, `$(...)` command substitution, no bash-isms. Correct.

### Test verification

14/14 bats tests pass after the fix.

## Dismissals

None

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

## Gate 6: /review

**Reviewer:** Claude Opus 4.7 (1M context)
**Scope:** `check-rollback-prose.sh` (new, ~120 lines), `pre-commit.sh` wiring (1 line), `guard-rollback-prose.bats` (14 tests), `pre-commit-router.bats` (stub additions), `hooks.md` (doc update).
**Result:** pass

### 1. Correctness

The prose detection heuristic is sound and well-aligned with the CI-side consumer (`ci-rollback-explain.sh`'s `extract_rollback()` function).

- **Prefix stripping** matches CI: the lint handles both `"-- "` (space) and `"--"` (no space), which aligns with CI's `sub(/^-- ?/, "")` regex.
- **ROLLBACK marker** uses exact `^-- ROLLBACK:` match via `grep -q` (line 28) and `case` (line 43), consistent with CI's `/^-- ROLLBACK:/` awk pattern.
- **Non-commented lines skipped** (lines 52-54): lines after the marker that don't start with `--` are skipped. This is correct -- CI's `sub(/^-- ?/, "")` is a no-op on these lines, so they pass through as-is (already valid SQL or blank lines).
- **Multiple ROLLBACK markers**: `in_rollback` is set once and never reset, matching CI's `found=1` behavior (everything after the first marker is rollback content). Consistent.
- **SQL keyword list** covers all D2 decision keywords plus a generous set of clause-starting keywords (WHERE, FROM, INTO, VALUES, ON, IF, ELSE, END, etc.). The expanded set beyond D2 reduces false positives on multi-line SQL statements.
- **noop handling**: case-insensitive via uppercased `first_word` comparison against `NOOP`, matching CI's `[Nn]oop:*` pattern. The trailing colon is stripped by the `sed 's/[^A-Z]$//'` so `"noop:" -> "NOOP"`. Correct.

**One theoretical false negative**: a prose line starting with a SQL keyword (e.g., `"-- DROP everything and start over"`) would be skipped. After prefix-stripping, Postgres would reject `DROP everything and start over` as a syntax error. However, this is extremely unlikely in practice and would require full SQL parsing to detect -- outside the heuristic's design scope. Not actionable.

### 2. Dash compatibility

The script uses `#!/bin/sh` and is clean of bash-isms:
- No `[[` tests -- uses `[ ]` throughout
- No `function` keyword -- uses POSIX function syntax (none needed; the script is linear)
- No `local` declarations
- No arrays, no process substitution (`<()`), no `source`
- Arithmetic via `$(( ))` (POSIX)
- `case` statements for all pattern matching (POSIX)
- `printf '%s'` instead of `echo -n` (POSIX-portable)
- No issues found.

### 3. Edge cases

- **Empty files**: the `while read` loop gets no lines, `found_prose` stays 0, exit 0. Correct.
- **File without trailing newline**: the `|| [ -n "$line" ]` guard handles this. Correct.
- **Binary content**: the `grep -q '^-- ROLLBACK:'` would not match binary content, so the file would be skipped at line 29. Safe.
- **Very long lines**: no line-length limits are imposed. The pipeline (`printf | awk | sed`) handles arbitrary-length lines. No concern.
- **File with ROLLBACK marker but only blank comment lines after it**: the `[ -z "$trimmed" ] && continue` on line 59 handles whitespace-only stripped content. Correct.
- **Filenames with spaces in migration paths**: the unquoted `for file in $STAGED_MIGRATIONS` would word-split on spaces. Migration filenames are timestamp-prefixed by convention (`20260101000000_name.sql`) and spaces would break many other tools. Not a practical concern.

### 4. Security

- No `eval`, no unquoted command-position expansion.
- All variables are properly quoted in `printf` format strings and `printf '%s'` calls.
- File content is read via `read -r` (no backslash interpretation) with `IFS=` (preserves leading/trailing whitespace).
- `awk` and `sed` receive content via pipe, not as arguments -- no injection vector.
- The `$file` variable in the output comes from `git diff --cached --name-only`, which is controlled by the staging area. Safe.

### 5. Integration

- **Wiring position in `pre-commit.sh`**: placed after `check-docs-coverage-project.sh` and before `commit-guard.sh` in the `/workspace` case. This is the correct scope (project repos only) and correct position (after coverage checks, before the final commit guard).
- **Devshop-self and /devshop cases do NOT call the script**: verified in both `pre-commit.sh` code and `pre-commit-router.bats` negative assertions (`[ ! -f ... check-rollback-prose.sh.args ]`). Correct -- devshop repos have no migration files.
- **Router test updated**: the project-repo test name, assertions, and devshop negative assertions all updated consistently.
- **Invocation uses `bash`**: the router calls `bash "$SCRIPTS_DIR/commit-hooks/check-rollback-prose.sh"` even though the script's shebang is `#!/bin/sh`. This is harmless (bash can run sh-compatible scripts) and follows the pattern used by all other commit hooks in the router.

### 6. Documentation (hooks.md)

- The commit flow diagram, guard table, and Commit Flow ascii art all updated consistently.
- The `check-rollback-prose.sh` entry in the guard table accurately describes behavior: deterministic, project only, no bypass.
- The hooks.md diff also cleans up a stale "Claude branch guard" reference (changing 7-step to 5-step count and removing the guard row). Verified against the actual `.husky/pre-commit` -- this cleanup is correct; the Claude branch guard step is not present in the current `.husky/pre-commit`.

### 7. Test coverage

14 bats tests cover:
- No migration staged (exit 0)
- Valid SQL-only rollback (exit 0)
- noop rollback (exit 0, both `noop:` and `Noop:` casing)
- Lowercase continuation lines (exit 0)
- Special character starts (exit 0)
- Parentheses starts (exit 0)
- Prose line detection (exit 1)
- Worked incident pattern -- home-os PR #35 (exit 1)
- No ROLLBACK block (exit 0)
- Empty rollback block (exit 0)
- Multiple files with one offender (exit 1, correct file only)
- Non-migration SQL files ignored (exit 0)
- Full SQL keyword list exercise (exit 0)

All 14 tests pass.

## Dismissals

None

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

**Verdict: pass**

Checked 4 conventions against the diff vs `origin/main`:

1. **Shell script 3-line header (`# What:` / `# Why:` / `# Does NOT:`)** -- PASS
   - `kit/scripts/commit-hooks/check-rollback-prose.sh` (new): lines 2-7 carry all three headers.
   - `kit/hooks/pre-commit.sh` (modified): lines 2-4 carry all three headers (unchanged).

2. **Bats test coverage for new scripts** -- PASS
   - `check-rollback-prose.sh` is paired with `kit/tests/guard-rollback-prose.bats` (14 tests, all passing).
   - `kit/tests/pre-commit-router.bats` also references `check-rollback-prose.sh` in its stub list and project-mode assertion.
   - `check-tests-coverage-devshop.sh` grep-based coverage check would find both `.bats` files.

3. **Guide docs linked in routing index (`kit/docs/guide/README.md`)** -- PASS
   - The "Ops + deploy" routing group row for `kit/scripts/commit-hooks/**` already routes to `hooks.md`.
   - `hooks.md` was updated in this diff: commit-flow diagram (step 2e), guard table (new `check-rollback-prose.sh` row), and CLAUDE.md's Known Footguns section all document the new hook.

4. **SKILL.md frontmatter** -- n/a (no new skills in this diff).

Bats verification: `kit/tests/guard-rollback-prose.bats` -- 14/14 pass.

## Dismissals

None


## Phase 3 → 4 advance log

### 2026-05-27T07:01:00Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:01:00Z -->

### 2026-05-27T07:01:00Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:01:00Z -->

### 2026-05-27T07:01:00Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:01:00Z -->

### 2026-05-27T07:01:00Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-27T07:01:00Z -->

## Audit 1 (manual, pre-merge)

<!-- audited-at: 3f81027b6f0ca53416f4440997c803ea6191d46b -->

findings: high=0 medium=0 low=0

### Commit range

`a429760..3f81027` (2 commits since Gate 5 audit stamp)

| SHA | Subject | Files |
|-----|---------|-------|
| `a91a27b` | chore(rollback-prose-lint): Phase 3 pre-ship gate results | specs/rollback-prose-lint/gates/* (20 files), review.md, hero/SKIP.md |
| `3f81027` | chore(build-log): record rollback-prose-lint | BUILD-LOG.md, PLAN.md, kit/TODOS.md |

### Docs review

**Scope**: no docs-surface code changed in this range. Changes are bookkeeping only (gate artifacts, BUILD-LOG entry, PLAN.md row removal, TODOS.md entry removal).

1. **BUILD-LOG.md entry** -- accurate. Branch name, spec path, headline, summary, commit count (9), and quality-gate summary all match the feature's actual history. The "squashed to 1 on main via /ak-merge-devshop" is forward-looking (merge has not happened yet) but consistent with the devshop shipping flow.

2. **PLAN.md row removal** -- correct per `kit/docs/guide/conventions.md § Closing TODO / ROADMAP entries when a fix ships`. The `rollback-prose-lint` row is removed from the `## Planned (v0)` table. No stale cross-references remain.

3. **kit/TODOS.md entry removal** -- correct. The 9-line TODOS entry (`Migration rollback prose lines break CI rollback round-trip silently`) is cleanly removed. Verified no other files reference this specific TODOS entry.

4. **Gate artifacts** (specs/rollback-prose-lint/gates/) -- 20 gate result files plus hero/SKIP.md. These are structured artifacts from /ak-pre-ship; no docs-surface concern.

No gaps found.

### Tests review

No test files changed in this commit range. The feature's test coverage was established in earlier commits and audited at Gate 5 (SHA `a429760`). Bats suite verified: 14/14 pass at HEAD.

The Gate 5 audit identified 2 medium and 3 low test coverage gaps (mixed-case SQL keywords, multiple-prose-line reporting, no-space prefix, marker trailing text, all-caps NOOP). These remain open but are coverage-completeness items, not correctness risks -- the script handles all cases correctly; the gaps are untested-but-working paths.

### Summary

Clean bookkeeping range. No code, test, or doc-surface changes since the Gate 5 audit. BUILD-LOG, PLAN.md, and TODOS.md closures are accurate and follow the devshop conventions for entry removal when a fix ships.
