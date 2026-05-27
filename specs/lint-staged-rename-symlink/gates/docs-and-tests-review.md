<!-- audited-at: 0f46375e0306aec2f8ad4fee7dfec78e0ec2ff5d -->

## Gate 5: docs-and-tests-review

### Test coverage

| Area | Status | Notes |
|------|--------|-------|
| Convention test (`kit/tests/convention-lint-staged-no-stash.bats`) | pass | 4 cases: positive match + negative-guard for both devshop and template pre-commit hooks. Guards against regression if hooks are regenerated. |
| Unit / integration tests | n/a | Fix is a CLI flag addition to hook config, not code logic. No runtime paths to unit-test. Convention test is the correct level. |

**Assessment**: Test coverage is sufficient. The fix is a config flag (`--no-stash`) appended to two shell hook files. The convention test verifies presence of the flag in both hooks and absence of bare (unflagged) invocations. No additional test level is warranted.

### Docs coverage

| Doc | Change | Status |
|-----|--------|--------|
| `kit/TODOS.md` | Deleted the "lint-staged stash backup chokes on rename + new-symlink-at-old-path" entry (closed). Updated the sibling "vanishing stash" entry to note `--no-stash` is already shipped, reducing the suspect surface. | pass |
| `.claude/skills/devshop/merge-devshop/SKILL.md` | Updated cross-reference from "bug is tracked separately" to "bug is fixed -- `--no-stash` disables lint-staged's `git stash` backup". | pass |
| `PLAN.md` line 84 | **Stale cross-reference.** The row's "Source" column points to `kit/TODOS.md` section "lint-staged stash backup chokes on rename + new-symlink" -- that section was deleted by this diff. | low finding |

**Stale reference search**: Searched `CLAUDE.md`, `kit/docs/`, `.claude/skills/`, and `kit/TODOS.md` for "lint-staged stash backup chokes", "rename.*symlink", and "--no-stash". Only hit beyond the updated files is the `PLAN.md` row (line 84). The bats test file at `kit/tests/util-ak-merge-devshop.bats:634` mentions "lint-staged stash bug" in the context of the Phase 2 detection test -- this is still accurate (the detection skill test is complementary, not stale).

### Summary

- **Findings**: high=0 medium=0 low=1
- **Low-1**: `PLAN.md` line 84 cross-ref to deleted TODOS entry is now a broken pointer. Non-blocking -- PLAN.md is a planning artifact and the row description is still accurate; the pointer just leads nowhere.

## Dismissals

| # | Finding | Severity | Disposition | Rationale |
|---|---------|----------|-------------|-----------|
| Low-1 | `PLAN.md` line 84 stale TODOS cross-ref | low | dismissed | PLAN.md is an internal planning table, not operator-facing docs. The row description ("Fix lint-staged stash backup failure...") is correct; only the Source column's deep-link is broken. Fixing it is a cosmetic follow-up, not a ship-blocker. The feature itself is fully documented in the updated SKILL.md and TODOS.md entries. |
