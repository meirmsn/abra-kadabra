## Gate 4: /simplify

Reviewed the diff (main...HEAD, 7 files, 283 insertions / 24 deletions) for unnecessary complexity, redundant tests, and over-engineering.

### Files reviewed

1. `.husky/pre-commit` -- 1-line change (`--no-stash` flag). Minimal.
2. `template/.husky/pre-commit` -- 1-line change. Minimal.
3. `kit/tests/convention-lint-staged-no-stash.bats` -- 36 lines, 4 test cases.
4. `kit/TODOS.md` -- deleted ~16-line resolved entry; updated sibling entry's candidate-fix paragraph.
5. `.claude/skills/devshop/merge-devshop/SKILL.md` -- 4-line cross-reference update.
6. `specs/lint-staged-rename-symlink/spec.md` -- spec artifact (not shipped code).
7. `specs/lint-staged-rename-symlink/tasks.md` -- task tracker (not shipped code).

### Negative test cases (tests 3-4): evaluated, kept

The bats test has 2 positive cases (flag present) and 2 negative cases (no bare invocation without the flag). The negative cases guard a distinct failure mode: someone adds a second `pnpm exec lint-staged` line without `--no-stash`. The positive tests would still pass in that scenario (grep output contains `--no-stash` from the flagged line) while the negative tests would catch the bare invocation.

This scenario is unlikely but the cost is 10 lines of trivial shell. The tests are simple grep pipelines, not over-engineered. Removing them would save negligible complexity while weakening coverage. Kept as-is.

### Result

No simplification opportunities found. The diff is already minimal: 2 one-line hook edits, 1 convention test, 1 TODOS cleanup, 1 cross-reference update.

## Dismissals

None -- no findings to dismiss.
