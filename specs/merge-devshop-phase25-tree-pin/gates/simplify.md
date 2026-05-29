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
