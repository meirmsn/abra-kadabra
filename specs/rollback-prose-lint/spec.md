<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: rollback-prose-lint -->
<!-- date: 2026-05-26 -->

# Spec: rollback-prose-lint

**Sources:**

- `kit/TODOS.md` § Migration rollback prose lines break CI rollback round-trip — primary scope source
- `template/scripts/ci-rollback-explain.sh` — the CI-side consumer whose `extract_rollback()` strips `-- ` prefixes
- `kit/hooks/pre-commit.sh` — pre-commit router (wire target)
- `kit/scripts/commit-hooks/` — existing commit-hook scripts (pattern reference)
- `kit/tests/guard-*.bats` — existing guard tests (test pattern reference)

**One-liner:** Pre-commit lint catches prose lines in migration `-- ROLLBACK:` blocks before they reach CI's rollback round-trip test.

---

## Product update

### Headline (user-facing)

Migration rollback blocks are now validated at commit time, not just in CI.

### Detail (team-facing)

New pre-commit lint (`check-rollback-prose.sh`) scans `-- ROLLBACK:` blocks in staged migration files for prose lines that would break `ci-rollback-explain.sh`'s prefix-stripping logic with SQL syntax errors. Catches the home-os PR #35 failure pattern locally instead of after an 8-minute CI round-trip.

---

## Decisions (resolved at spec time)

3 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without re-asking.

### D1: Where in pre-commit.sh

**Decision:** Project-side only (`/workspace` case in `pre-commit.sh`) — devshop has no migration files.

**Rationale:** Migration files only exist in project repos under `supabase/migrations/`. The devshop-self and `/devshop` branches in `pre-commit.sh` have no migration surface to lint.

### D2: Valid SQL keyword set

**Decision:** The following keywords are valid first-word starts for rollback block lines: `DROP`, `CREATE`, `ALTER`, `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `SET`, `RESET`, `GRANT`, `REVOKE`, `NOTIFY`, `BEGIN`, `COMMIT`, `ROLLBACK`, `DO`, `WITH`, `TRUNCATE`, `COMMENT`. Plus the existing `noop:` escape hatch (case-insensitive).

**Rationale:** Covers all standard DDL/DML/TCL statements that could legitimately appear in a rollback block. The `noop:` case is already handled by `ci-rollback-explain.sh`'s `is_rollback_noop()` function.

### D3: Prose detection heuristic

**Decision:** Only flag lines whose first non-whitespace word is a Capitalized English word that isn't a SQL keyword. Skip: empty lines, lines starting with lowercase, lines starting with `(` or whitespace-only, lines starting with `--` (nested comments). The `noop:` pattern is also allowed.

**Rationale:** Matches the TODOS entry's specified heuristic. Catches the worked incident's pattern (`Restore the migration 006b version...`) without false-positiving on SQL continuations like `  VALUES (...)` or `  ON CONFLICT DO NOTHING`.

---

## In scope

- New pre-commit lint script `check-rollback-prose.sh` that scans staged migration files' `-- ROLLBACK:` blocks for prose lines (capitalized English words that aren't SQL keywords)
- Wire the lint into `kit/hooks/pre-commit.sh` in the `/workspace` (project) case
- Bats test suite covering pass/fail/edge cases
- Documentation update in `kit/docs/guide/hooks.md`

## Out of scope

- Modifying `ci-rollback-explain.sh` (CI-side consumer stays as-is)
- Devshop-side pre-commit wiring (no migration files in devshop repos)
- Rollback block presence enforcement (that's `ci-rollback-explain.sh`'s job)

## Files to create/modify

| Action | Path | Purpose |
|--------|------|---------|
| CREATE | `kit/scripts/commit-hooks/check-rollback-prose.sh` | The lint script |
| MODIFY | `kit/hooks/pre-commit.sh` | Wire the lint into the `/workspace` case |
| CREATE | `kit/tests/guard-rollback-prose.bats` | Bats test suite |
| MODIFY | `kit/docs/guide/hooks.md` | Document the new check |

## Tests

Bats tests in `kit/tests/guard-rollback-prose.bats`:

1. **Pass: no migration files staged** — exits 0 silently
2. **Pass: migration with valid SQL-only rollback block** — exits 0
3. **Pass: migration with noop rollback** — exits 0
4. **Pass: multi-line SQL continuation (lowercase start)** — exits 0
5. **Fail: migration with prose line in rollback block** — exits 1, output includes the prose line
6. **Fail: worked incident pattern** — `-- Restore the migration 006b version (resets card_count only):` caught
7. **Pass: migration without ROLLBACK block** — exits 0 (marker mandate is `ci-rollback-explain.sh`'s job)
8. **Edge: empty rollback block** — exits 0

## Task order

1. **T-1: Write `check-rollback-prose.sh`** — no dependencies
2. **T-2: Wire into `pre-commit.sh`** — depends on T-1
3. **T-3: Write bats tests** — depends on T-1
4. **T-4: Update `hooks.md` docs** — depends on T-1, T-2

## Gotchas

- Script runs from PROJECT repo root (`/workspace`), not devshop — paths are relative to the project
- Must be dash-compatible (`sh`) — no arrays, no `[[ ]]`, no process substitution
- The `extract_rollback()` in `ci-rollback-explain.sh` uses `awk` with `sub(/^-- ?/, "")` — our lint operates on the raw `-- ` prefixed lines, not the stripped version, since we need to detect prose before stripping
- Lines starting with `(`, `)`, `'`, `"`, `-`, `*`, or digits are SQL continuations (VALUES clauses, subqueries, string literals, comments, list items, numeric literals)
- The `noop:` escape hatch is case-insensitive per `ci-rollback-explain.sh`'s `is_rollback_noop()`
- `check-docs-coverage-devshop.sh` maps `kit/scripts/commit-hooks/**` to `kit/docs/guide/hooks.md` — the Task 4 docs commit satisfies this
