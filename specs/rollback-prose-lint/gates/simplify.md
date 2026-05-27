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
