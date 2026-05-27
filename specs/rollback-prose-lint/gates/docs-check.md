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
