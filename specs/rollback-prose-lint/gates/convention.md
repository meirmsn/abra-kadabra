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
