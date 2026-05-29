## Gate 2d: fast-job-local (bats)

- Result: pass-with-note

Ran `bats kit/tests/` at HEAD. 1526 tests planned, **1525 pass / 1 fail**.

The single failure — test 1247 "Phase 6 audit comment posts concise summary
(no quality-gates table)" in `util-build-phase58-audit-parser.bats` — is
**pre-existing on /devshop main and unrelated to this diff**. Caused by
commit `1d343bf` ("drop PR gate comment"), which changed project-mode Phase 6
to post no comment but left this test asserting the removed wording. The test
reads the canonical `/devshop/.claude/skills/devshop/build/SKILL.md` path, so
it reflects main's state regardless of branch. This diff touches no test, no
script, no SKILL.md — confirmed via `git diff origin/main...HEAD --name-only`.

Filed for a dedicated test-only fix in `kit/TODOS.md` on branch
`chore/file-phase6-audit-test-stale` (commit `4d42af6`). Operator acknowledged
and chose to proceed.

## Dismissals

- test 1247 (Phase 6 audit-comment): dismissed as pre-existing/unrelated.
  rationale: introduced by 1d343bf (not on this branch); this diff touches no
  test/script/SKILL; filed in kit/TODOS.md for a separate fix.
