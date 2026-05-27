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
