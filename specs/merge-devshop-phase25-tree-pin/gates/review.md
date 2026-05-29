## Gate 6: /review

Scope reviewed: `git diff origin/main...fix/merge-devshop-phase25-tree-pin` — the new
Phase 2.5 HEAD-pin guard in `.claude/skills/devshop/merge-devshop/SKILL.md`, the 5 new
§ Section G2 content-validation tests in `kit/tests/util-ak-merge-devshop.bats`, and the
`kit/TODOS.md` HEAD-race closure. Merge-commit content (structural-invariants.bats,
specs/reconcile-script-wiring/) explicitly excluded.

Verdict: **pass** — no high/medium findings. Two low observations recorded as dismissals
(both intentional / out-of-scope), no action required to land.

### Correctness of the Phase 2.5 bash guard

Verified against the four risk dimensions in the gate brief:

- **Before-assertion truly before the bats run.** `HEAD_NOW` check (line 1072) sits above
  `BATS_OUT=$(mktemp)` and the `bats` invocation (line 1089). Mutation test (removing the
  `HEAD_NOW=...` line) flips test 6 red — binding confirmed.
- **After-assertion truly after the verdict.** `HEAD_AFTER` check (line 1106) sits below the
  `FAILED>0` halt (lines 1094-1100) and below the count computation, before the success echo.
  Mutation test (removing the `HEAD_AFTER` block) flips test 7 red — binding confirmed.
- **EXPECTED_SHA vs HEAD detects wrong-checkout / mid-flow flip — correctly.** `EXPECTED_SHA=git -C
  "$BATS_CWD" rev-parse "$BRANCH"` resolves the *ref* (immune to a sibling flipping the checkout's
  detached HEAD), while both `HEAD_NOW`/`HEAD_AFTER` resolve the live `HEAD`. Confirmed the
  load-bearing assumption that `$BRANCH` tip == squash commit holds in **both** flow paths:
  - Worktree path: Phase 2's `git -C "$WORKTREE_PATH" commit` advances the worktree's checked-out
    `$BRANCH` to the squash commit, so `rev-parse $BRANCH == rev-parse HEAD` in `$BATS_CWD`.
  - Legacy on-feature-branch path: `WORKTREE_PATH=""`, `BATS_CWD=--show-toplevel` (= /devshop, on
    `$BRANCH=$CURRENT`), same equality holds.
- **Both halt paths (exit 1) correct.** BEFORE-halt has no `BATS_OUT` to clean (mktemp not yet
  run) — correctly omits `rm -f`. AFTER-halt and the FAILED-halt both `rm -f "$BATS_OUT"` before
  `exit 1`. No tempfile leak on any exit path.
- **No way for a red suite to slip to main via the reviewed change.** The pre-existing
  count-based verdict (`FAILED=grep -c '^not ok'`) is untouched and still gates first; the new
  HEAD pin is strictly additive (it can only *add* halts, never relax the count gate). The success
  echo and Phase 3 hand-off are reached only after count==0 AND HEAD unchanged.

### Shell-safety

- Quoting correct throughout: `"$WORKTREE_PATH"`, `"$BATS_CWD"`, `"$BRANCH"`, `"$EXPECTED_SHA"`,
  `"$HEAD_NOW"`, `"$HEAD_AFTER"` all double-quoted in every expansion and `[ ... ]` test.
- Absolute-path resolution `BATS_CWD=$(cd "$WORKTREE_PATH" && pwd -P)` is the right idiom —
  `pwd -P` resolves symlinks so the later SHA comparison is tree-exact, and `cd && pwd` runs in a
  subshell so the surrounding cwd is not mutated.
- No clobbering of the existing verdict variables (`BATS_OUT`/`FAILED`/`PASSED`); the new vars
  (`BATS_CWD` reuse, `EXPECTED_SHA`, `HEAD_NOW`, `HEAD_AFTER`) are distinct and don't collide.
- `string` comparison `!=` on full 40-char SHAs is correct (no numeric coercion risk).

### The bats tests

All 5 new tests are real behavioral bindings, not trivially-true greps — verified by mutation
testing (removing/altering the guarded line flips the corresponding test red in each case: BEFORE,
AFTER, EXPECTED_SHA ref). The awk range `/^## Phase 2\.5:/,/^## Phase 3:/` matches the actual
headings (lines 1017 / 1146), so the tests are scoped to the right section and can't be satisfied
by matching text elsewhere in the file. Ordering tests (6, 7) assert line-number `-lt`/`-gt`
relative to the `bats` invocation line — a meaningful structural guarantee, not a presence grep.
Full file green: 103/103.

### Trust-boundary / logic

No LLM trust-boundary, SQL, or conditional-side-effect issues — this is bash-in-markdown skill
content, not app code. The guard introduces no side effects on either halt path (read-only
`rev-parse` + `echo` + `rm` of its own tempfile + `exit`).

### Tracker hygiene

`kit/TODOS.md` closure is correct: the HEAD-race bullet (now fixed) is deleted, and the distinct
"doc/SKILL edit can drift an asserting test silently" sub-item is correctly *retained* as a still-open
medium TODO (that's the structural-invariants work, out of this feature's scope). Remaining
`1d343bf` references in SKILL.md are the new feature's own rationale comments, not stale cross-refs.

## Dismissals

- **[low] Flip-and-flip-back during the suite is theoretically undetectable.** If a parallel session
  moved `$BATS_CWD`'s HEAD away from `EXPECTED_SHA` *during* the ~60-90s run and moved it *back*
  before the AFTER check, both pins pass while the suite actually executed against a transiently-wrong
  tree. Dismissed: (a) requires two precisely-timed flips inside one run on a single-developer devshop —
  vanishingly unlikely; (b) detecting it would require sampling HEAD throughout the run, far beyond the
  point-in-time pin this fix scopes; (c) the symmetric Phase 3 checkout-verification guard provides a
  second backstop at push time. Not worth complicating the guard.

- **[low] EXPECTED_SHA emptiness not explicitly guarded.** If `git rev-parse "$BRANCH"` ever failed
  (ref deleted between Phase 2 and here), `EXPECTED_SHA` would be empty and the `!=` test would
  (correctly) halt on mismatch anyway — failure mode is a halt, never a false-green. Dismissed: the
  fail-safe direction is already correct; an explicit empty-string check would only improve the error
  message, not the safety. Out of scope for a HALT-ON-FIND gate.
