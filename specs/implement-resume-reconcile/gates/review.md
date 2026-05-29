## Gate 6: /review

- Result: findings (1) fixed

Scope reviewed: the 9-file delta `git diff $(git merge-base origin/main HEAD)..HEAD`
(MB `4a77f28`). Substantive surface: `kit/scripts/reconcile-task-commits.sh` +
`kit/tests/util-reconcile-task-commits.bats`, plus the SKILL/workflow wiring and
`util-ak-build-skill.bats` Section F. Both bats suites run green (11 + 53 tests).

### Findings

- **low — `kit/scripts/reconcile-task-commits.sh:91` (DONE_AWK regex)**: a
  `**Status**: done` line carrying a trailing CR (CRLF line ending) does NOT match
  — the `([ \t]*$|[ \t])` anchor treats `\r` as an ordinary char after `done`, so a
  CRLF tasks.md would undercount `DONE_COUNT` (verified: `printf '**Status**: done\r\n'`
  counts 0). Direction is fail-SAFE for the trustworthy verdict (lower done-count can
  only make `IMPL >= DONE` more likely → a false PASS, not a false fail), but it is
  still a latent miscount. tasks.md is repo-authored under LF so this is unlikely in
  practice; flagging for completeness, not blocking.
  Fix: tolerate an optional CR before the EOL/whitespace anchor, e.g.
  `/^\*\*Status\*\*:[ \t]*done([ \t\r]*$|[ \t])/`, or strip CRs (`sub(/\r$/,"")`) at
  the top of the awk program. Add a CRLF fixture case to the bats suite if adopted.

### Correctness checks that PASSED (no finding)

- **Off-by-one / empty-range / zero-done**: verdict is `IMPL_COUNT >= DONE_COUNT`
  (`>=`, not `>`), so all-done-all-committed (N==N) passes and empty range with zero
  done passes (0 >= 0). `awk 'END{print n+0}'` always emits an integer, so the
  `[ "$X" -ge "$Y" ]` arithmetic test can never receive an empty/non-numeric operand
  under `set -e`. Verified manually.
- **Bookkeeping-exclusion anchoring**: the four `next` patterns are correctly anchored
  — `^chore\(roadmap\):` (literal parens) does NOT match `chore(roadmapX)` or
  `fix(roadmap-ui)`; the Phase-0 pattern requires the full `Phase 0 spec skeleton`
  substring after the scope. No real impl commit is wrongly excluded; no bookkeeping
  commit slips through. The DONE regex does NOT false-match the legend line
  `**Status**: todo | in_progress | done | blocked` (anchored on `done` immediately
  after the colon; legend starts with `todo`). Verified manually against 5 scope
  variants + the legend line.
- **Negative control proves exclusion is load-bearing**: case 6b (2 impl + 4
  bookkeeping, 3 done → exit 1) would false-PASS (IMPL=6>=3) if the exclusion broke.
  This is a genuine negative control, not an incidentally-passing test.
- **Rebase-robustness (D3) is genuinely proven**: case 5 advances `main` by a commit
  then `git rebase`s the feature branch, asserts SHAs changed AND exit 0 still holds.
  The excluded Phase-0-skeleton commit is replayed too but stays excluded by subject.
  This is the decisive proof the count heuristic survives the /ak-merge-devshop
  Phase 1.0 rebase path a SHA-stamping approach would false-fail on.
- **Clean-tree detection scope**: `git status --porcelain` catches staged, unstaged,
  AND untracked (case 3 uses an untracked file and correctly fails). It is scoped to
  the work tree containing cwd, so in a linked worktree it reports that worktree's
  state — correct.
- **Exit-code contract**: 0 trustworthy / 1 not-trustworthy / 64 usage, consistent
  across script, header legend, spec, and tests (cases 7a/7b/7c cover all three 64
  paths: missing arg, absent tasks.md, unresolvable base-ref; not-a-git-repo guard
  present but untested — acceptable, hard to fixture). The SKILL rung-2 wiring treats
  ANY non-zero (1 or 64) as "re-enter Phase 2, never skip" — fails safe on an
  unresolvable `origin/main` too.
- **Quoting / `set -euo` discipline**: all expansions quoted; `BASE_REF="${2:-origin/main}"`
  and `AWK_BIN="${AWK_BIN:-}"` guard unbound vars under `set -u`; base-ref is validated
  with `rev-parse --verify` before `git log`, so the `git log | awk` pipe can't fail
  the range under `pipefail`.
- **Wiring sync + doc sweep**: Section F asserts the rung-2 call, the do-NOT-skip /
  re-enter-Phase-2 prose, the trustworthy-condition shape, the Phase 2 note, the
  resume-table row, and that workflow.md dropped the false "commit SHAs" claim. The
  real tasks.md for this feature (4 `**Status**: done`) is counted correctly by the
  helper regex, confirming the marker format matches what /ak-implement writes.

## Focused fix log

- low CRLF finding **fixed** at `a793b1b`: the helper now strips CR on the
  tasks.md read (`tr -d '\r' < "$TASKS_FILE" | "$AWK_BIN" ...`) — chosen over the
  awk-anchor tweak because it needs no regex change, so mawk parity (case 8) is
  untouched. Added regression sentinel case 9 (CRLF tasks.md, 3 done + 2 impl →
  exit 1; would false-pass without the strip) + aligned spec § Tests. Reconcile
  suite green 12/12; full suite green.

## Dismissals

None.
