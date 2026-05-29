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
