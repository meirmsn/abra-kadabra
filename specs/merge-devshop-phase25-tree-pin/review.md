# Review — merge-devshop-phase25-tree-pin

## Router Summary

- Dispatched gates (6): docs-check, fast-job-local, simplify, docs-and-tests-review (Audit 1), review, convention — all pass / clean.
- Pre-composed carve-outs (13): devshop-self-mode n/a or structural-blocked (no UI / supabase / metrics / migrations / perf surface).
- Findings: high=0, medium=1 (workflow.md Phase 2.5 doc-coverage — fixed in this branch), low=0, pending=0.
- No findings dismissed beyond the structural carve-outs logged below.

## Gate 1: docs-check

**Verdict: pass**

Scope: `git diff origin/main...fix/merge-devshop-phase25-tree-pin` substantive feature files
(`.claude/skills/devshop/merge-devshop/SKILL.md`, `kit/tests/util-ak-merge-devshop.bats`,
`kit/TODOS.md`, `specs/merge-devshop-phase25-tree-pin/`). Merge-commit content
(structural-invariants.bats, specs/reconcile-script-wiring/) ignored per gate brief.

Devshop doc-coverage rule applied: "every devshop tooling change includes doc updates in
the same commit." Reference doc surfaces checked: `kit/docs/guide/*.md`, `kit/docs/OVERVIEW.md`,
`CLAUDE.md`, and the SKILL.md prose itself.

### Check 1 — SKILL.md prose documents the new before/after HEAD-pin assertions (the doc update IS the skill prose)

PASS. The Phase 2.5 prose block (SKILL.md, just above the `bash` fence) was rewritten, not
just the code. The prose explicitly describes the new guard in plain language before the code
appears:

- States the gate "pins itself to the commit it is supposed to be testing."
- Names the three mechanics: resolve `$BATS_CWD` to an absolute path, pin `EXPECTED_SHA` to
  the `$BRANCH` tip (the Phase 2 squash commit), and assert `HEAD == EXPECTED_SHA`
  **"both before and after the suite."**
- Explains the threat (a parallel session flipping HEAD in the ~60-90s Phase 2→2.5 window)
  and the consequence the pin prevents (ff-pushing a genuinely-red suite onto main).
- Cites the worked incident (`1d343bf`, 2026-05-28) and frames the guard as the
  "symmetric sibling of the Phase 3 checkout-verification guard
  (calibration-and-task-phases, 2026-05-20)."

The code block then implements exactly that: absolute-path `BATS_CWD` resolution (`cd … && pwd -P`),
`EXPECTED_SHA=$(git -C "$BATS_CWD" rev-parse "$BRANCH")`, a BEFORE-suite abort, an AFTER-suite
abort, and a verdict line that names the SHA tested. Prose and code agree; the prose is a genuine
human-readable description of the new behavior, not a bare code dump. The spec's documentation
decision (spec.md lines 175-178) — "the skill prose IS the doc surface here" — is satisfied.

The cross-reference to the Phase 3 checkout-verification guard is not dangling: that guard exists
in SKILL.md (Phase 3 block, ~lines 1164-1206, the "verify checkout on main / wrong branch" abort).

### Check 2 — does any OTHER living doc describe Phase 2.5's gate behavior in a now-stale way?

PASS (no stale statement found).

- `kit/docs/guide/workflow.md` line 488 (`/ak-merge-devshop` row) is the only living-doc
  description of the merge-devshop Phase 2.5 gate. It states Phase 2.5 "computes its verdict
  from a `grep -c '^not ok'` count … and halts with the failing test names on any failure."
  That sentence remains **true** after this change — the count-based verdict mechanism is
  unchanged. It does NOT assert anything about checkout/tree trust (it never claimed "trusts the
  tree unconditionally" or "no HEAD pin"), so it does not describe the OLD behavior as current.
  The HEAD-pin is a new, additional safety facet; its absence from this one-line summary is an
  omission, not a contradiction. Not a coverage gap under the "every tooling change includes doc
  updates" rule, because the canonical doc surface for this change is the SKILL.md prose (Check 1),
  and workflow.md line 488 is a deliberately compressed pipeline-table summary, not a Phase 2.5
  contract. See Dismissals for the optional-enrichment note.
- The other `Phase 2.5` hits — `workflow.md` lines 79/261, `kit/docs/CHANGELOG.md` lines 14/15,
  `kit/docs/PROPAGATION.md` line 31 — refer to **`/ak-build`'s** Phase 2.5 (the devshop-only
  "fresh-eyes verification" step), a different phase entirely. Out of scope, not stale.
- `kit/docs/guide/hooks.md` (Phase 3 / pushToMainApproved references) and `CLAUDE.md`
  (worktree-merge paragraph) describe Phase 3 / worktree mechanics, not the Phase 2.5 race
  posture. Nothing there is contradicted by this change.

### Check 3 — kit/TODOS.md HEAD-race entry removed; no living doc still cites it as open/pending

PASS. The removed entry's distinctive markers — `1d343bf`, "HEAD race", "test the wrong tree
under parallel", "wrong tree under parallel merges" — appear in NO living doc
(`kit/docs/`, `CLAUDE.md`, `kit/ROADMAP.md`). `1d343bf` is referenced only inside the shipped
SKILL.md prose (as the worked-incident citation for the now-fixed guard) and in the
spec/tasks artifacts — appropriate, since the fix shipped. The replacement TODOS.md entry
(the residual "doc/SKILL edit can silently drift a content-asserting bats test" item) is
correctly retained as a still-open, distinct concern. No stale "still pending" surface remains.

## Dismissals

- **workflow.md line 488 not enriched with the HEAD-pin** — dismissed as a coverage gap; logged
  as optional enrichment, not a blocker. Rationale: the sentence's positive claim (count-based
  verdict + halt-on-failure) stays accurate; it makes no false claim about checkout-tree trust,
  so it is not "OLD behavior described as current." The spec scoped the doc surface to the
  SKILL.md prose (spec.md §175-178), which fully covers the change. An operator MAY choose to
  append a clause ("… and pins HEAD to the squash commit before/after the run") to that row for
  completeness, but its absence does not violate the same-commit docs rule. Routing if pursued:
  a one-line workflow.md tweak, not blocking.
- **Propagation/migration-block coverage** — n/a here. This gate verifies docs coverage, not the
  propagation-block surface; the SKILL.md change is consumed via the symlinked skill (no file copy
  for projects), and the squash-time `prTextHygieneReason` dimension-(d) check owns that surface
  at merge time, not Gate 1.

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass (full bats suite green: 1567 passed, 0 failed; re-run against merged HEAD 6986b3f)

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: /simplify

**Verdict: pass — no changes.**

Scope reviewed (three-dot delta `origin/main...fix/merge-devshop-phase25-tree-pin`,
substantive files only):

- `.claude/skills/devshop/merge-devshop/SKILL.md` — new Phase 2.5 HEAD-pin guard (embedded bash).
- `kit/tests/util-ak-merge-devshop.bats` — 5 new § Section G2 content-validation tests.

Content arriving via the branch's merge commit (structural-invariants.bats,
specs/reconcile-script-wiring/) was excluded per the gate brief.

All four /simplify angles assessed; the delta is already clean:

- **Reuse** — The `awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE"` section
  extraction repeats across the 5 new tests, but this is the dominant idiom
  across all ~35 pre-existing tests in the file (40 `awk '/^## Phase…` ranges
  total; no shared helper exists — each test inlines its own range). The two
  new ordering tests use the `local section; section=$(awk …)` capture-and-reuse
  pattern, which is the established idiom for ordering tests (lines 139, 628,
  747). Both new-test styles mirror their respective established siblings. No
  reuse gap.

- **Simplification** — Each new test is a single `grep -q` assertion (or one
  awk-capture + ordered line-number checks for the two ordering tests). No
  redundant/derivable state, no copy-paste-with-variation beyond the shared
  idiom, no deep nesting, no dead code. The two ordering tests capture
  `section` once and reuse it three times. Nothing to collapse.

- **Efficiency** — The guard adds two `git rev-parse HEAD` calls (before + after)
  plus one `pwd -P` — all sub-millisecond, bracketing a ~60-90s suite. The
  before/after pin IS the load-bearing mechanism, not wasted work. Tests run a
  few cheap awk/grep passes each. No wasted computation.

- **Altitude** — Implemented at the right depth: the guard pins to `$BRANCH`
  (the durable ref, correct even if a sibling session has flipped the checkout's
  HEAD) rather than special-casing path strings, and the before+after
  assertions generalize the full race window. This is the intended symmetric
  sibling of the Phase 3 checkout-verification guard — symmetry preserved, not
  collapsed (per brief, the two guards must NOT be DRY'd into a shared helper;
  they are prose SKILL.md phases, not executable code).

Baseline confirmed green: `kit/tests/lib/bats-core/bin/bats
kit/tests/util-ak-merge-devshop.bats` → 103/103 passing.

## Dismissals

- Reuse: extracting a shared `awk`-range section-extractor helper —
  rationale: would diverge the 5 new tests from the 35 pre-existing siblings
  that all inline the same idiom; consistency with the surrounding file
  outweighs the marginal DRY gain, and there is no existing helper to call.
- Reuse/Simplification: collapsing the Phase 2.5 HEAD-pin guard and the Phase 3
  checkout-verification guard into one shared block —
  rationale: explicitly out of scope per the gate brief; the two guards are
  intentionally symmetric prose phases (not executable code), and their
  mirroring is a documented feature defending the same parallel-merge race at
  two different moments (checkout time vs test time).

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

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

## Gate 11: convention

**Verdict: pass.** No convention violations in the feature delta. No changes made.

Scope checked: `git diff origin/main...fix/merge-devshop-phase25-tree-pin`, feature files only
(SKILL.md Phase 2.5, kit/tests/util-ak-merge-devshop.bats §G2, kit/TODOS.md). Merge-commit content
from origin/main ignored.

### Checks

- **SKILL.md frontmatter intact** — `name: ak-merge-devshop` present; YAML block well-formed.
- **Heading structure intact** — `## Phase 2.5: Full bats suite` (line 1017) and `## Phase 3:
  Fast-forward main + push` (line 1146) both present and in order. The bats §G2 awk range
  `/^## Phase 2\.5:/,/^## Phase 3:/` resolves to a non-empty 130-line section, so the grep-based
  content tests bind correctly.
- **New bats tests follow file style** — 5 new tests appended in a `# === Section G2 ===`-style
  block before `# === Section H — Phase 3 ===`. Same idioms as existing tests: `awk` range slice +
  `grep -qE`, line-ordering assertions via `grep -n | cut -d: -f1`, leading `#` rationale comments,
  `$SKILL_FILE` shared var. Consistent with the file's established structure.
- **kit/TODOS.md closure follows the convention** — the HEAD-race entry (`Phase 2.5 can test the
  wrong tree under parallel merges`) was hard-deleted (no strikethrough, no "shipped" footnote). The
  surviving entry in its place is a genuinely distinct concern — the *doc/SKILL.md edit drifts a
  bats-asserting test* prevention sub-point, which this PR does NOT fix (it needs a
  `structural-invariants.bats` mapping or conventions note). Correctly retained as still-open, not a
  zombie of the deleted entry.
- **No new kit/scripts/ file** — `git diff --name-status` on `kit/scripts/` is empty. No
  new-script-needs-bats-test obligation.
- **Commit + PR text style** — substantive subject `fix(ak-merge-devshop): pin Phase 2.5 bats gate
  to the tested commit` describes the observable change, ≤72 chars, no internal jargon. Remaining
  subjects are conventionally-scoped pipeline chores (spec skeleton/expansion, TODO drop).
- **Tests green** — `kit/tests/util-ak-merge-devshop.bats`: 103 passed, 0 failed (includes the 5 new
  §G2 tests).

### Dismissals

- **PLAN.md line 76 cross-reference to the deleted kit/TODOS.md HEAD-race section** — `n/a (handled
  downstream)`. PLAN.md is NOT in this branch's delta. The orphan-looking pointer lives inside the
  feature's own `## Planned (v0)` row, whose final column cites
  `kit/TODOS.md § /ak-merge-devshop Phase 2.5 can test the wrong tree under parallel merges` — the
  section this PR deleted. This is intentional, not a missed unwind: (a) tasks.md's closure-task
  "Done when" explicitly scopes the grep to exclude `PLAN.md row`; (b) the PLAN.md lifecycle rule
  (PLAN.md line 52) deletes the entire Planned row at ship time (Phase 4.0: BUILD-LOG + PLAN
  closure, currently pending), which removes the orphan reference with the row. Unwinding the column
  now would leave a dangling row; the pipeline removes the whole row instead. No action at this gate.

## Phase 3 → 4 advance log

### 2026-05-29T09:58:46Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — no auth boundary, no RLS, no third-party APIs — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:58:46Z -->

### 2026-05-29T09:58:46Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — no UI surface — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:58:46Z -->

### 2026-05-29T09:58:46Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — no UI surface; bats invariants are the test surface (Gate 2d) — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:58:46Z -->

### 2026-05-29T09:58:46Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — no perf surface — gate structurally inapplicable
**Follow-up tracker:** n/a — structural; no tooling gap to close
<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T09:58:46Z -->

---

## Audit 1: manual (2026-05-29)

<!-- audited-at: 6986b3f592f5f6c690078496c79849670c02d293 -->
<!-- range: e930fdc00eef8f6fad3e2254167af0121ff2bea6..6986b3f592f5f6c690078496c79849670c02d293 -->

findings: high=0 medium=1 low=0

### Docs findings

- [medium] kit/docs/guide/workflow.md:488 — The `/ak-merge-devshop` row's Phase 2.5 description is stale: it documents the `grep -c '^not ok'` verdict-count gate but not the new HEAD-pin guard (absolute `$BATS_CWD` + `EXPECTED_SHA` before/after assertions) this feature adds to defend the parallel-merge HEAD-flip race. Canonical guide-doc summary of the hardened phase under-describes it. Recommend one clause noting the gate pins the tested tree to the squash commit and re-asserts HEAD before+after the suite.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

## Audit 2: manual (2026-05-29)

<!-- audited-at: 088dd237b479a02dd97667441b0c23b162de7301 -->
<!-- range: e930fdc00eef8f6fad3e2254167af0121ff2bea6..088dd237b479a02dd97667441b0c23b162de7301 -->

findings: high=0 medium=0 low=0

This is the `/ak-merge-devshop` Phase 1.1 merge-time audit over the feature's
full net delta (origin/main `e930fdc` is an ancestor of HEAD `088dd23`, so the
range is exactly the squash delta). The prior Audit 1 (at `6986b3f`) flagged ONE
medium — `kit/docs/guide/workflow.md` omitted the HEAD-pin guard from its Phase
2.5 description. **That finding is CONFIRMED closed**: commit `37b006e` (in this
range) rewrote the `/ak-merge-devshop` row to document the guard ("pins the
suite to the resolved (absolute) worktree path and asserts the tested `HEAD`
equals the squash commit both before and after the run … codified from
`1d343bf`"). No new findings.

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
