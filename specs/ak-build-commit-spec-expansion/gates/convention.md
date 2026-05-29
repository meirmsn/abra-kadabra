## Gate 11: convention

- Result: findings (1) fixed

SKILL.md frontmatter intact; no new scripts/guide-docs; Section G bats coverage
(4 tests) green (46/46); all cross-refs resolve; prose follows house style; all
commit subjects conventional-commit, ≤72 chars, observable-change.

Finding (FIXED): `kit/TODOS.md` still carried the open entry "`/ak-build` Phase 1
doesn't commit the expanded `spec.md`" — the exact bug this branch fixes —
violating CLAUDE.md § "Closing TODO / ROADMAP entries when a fix ships". Closed
in commit `c64de2c`: deleted the TODOS entry (+ its trailing metadata tag) and
removed the `ak-build-commit-spec-expansion` PLAN row. No other cross-references
to the entry exist (verified via repo-wide grep).

## Dismissals

None
