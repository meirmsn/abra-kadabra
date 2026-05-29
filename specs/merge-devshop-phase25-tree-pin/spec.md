<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: merge-devshop-phase25-tree-pin -->
<!-- date: 2026-05-29 -->

# Spec: merge-devshop-phase25-tree-pin

**Sources:**

- `kit/TODOS.md § /ak-merge-devshop Phase 2.5 can test the wrong tree under parallel merges` — primary scope + fix shape
- `PLAN.md` row `merge-devshop-phase25-tree-pin` — scope summary + source pointer
- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2.5` — the block being hardened
- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 3` (lines 1101-1117) — the checkout-verification guard being mirrored
- `kit/tests/util-ak-merge-devshop.bats § G2` — the test section the new coverage joins

Harden `/ak-merge-devshop`'s Phase 2.5 pre-merge bats gate so a concurrent
(parallel) merge session can't flip the tested checkout's HEAD between the
squash (Phase 2) and the gate (Phase 2.5) and cause the gate to read a green
verdict from the wrong tree — which would fast-forward a genuinely-red test
suite onto `main`.

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — devshop mode
routes Headline → BUILD-LOG `Headline:` field, Detail → BUILD-LOG `Summary:`
field, and `/ak-merge-devshop`'s squash commit body reads this section.

### Headline (user-facing)

Infrastructure update — no user-visible change in this PR.

### Detail (team-facing)

Hardens `/ak-merge-devshop`'s pre-merge bats gate so a parallel merge running
at the same time can't trick it into reading a green result from the wrong
checkout and fast-forwarding a red test suite onto `main`. The gate now pins
the suite to the resolved worktree path and asserts the tested HEAD is the
squash commit both before and after the run, halting if a sibling session
moved the checkout mid-flow.

---

## Decisions (resolved at spec time)

4 spec-time decisions resolved in Phase 0 with the operator. Recorded below so
Phase 1 preserves them verbatim and a crashed Phase 1 resumes without re-asking.

### D1: Which checkout does Phase 2.5 test, and how is it resolved?

**Decision:** Resolve `$WORKTREE_PATH` to an absolute path when set
(`cd "$WORKTREE_PATH" && pwd -P`); else fall back to
`git rev-parse --show-toplevel`. Run `bats` against that explicit `$BATS_CWD`.

**Rationale:** The TODO's fix shape — never let `--show-toplevel` resolve
implicitly at gate time, since under a parallel merge a sibling session can
flip `/devshop`'s HEAD between Phase 2 and Phase 2.5. Pinning the dir is the
first half; the SHA assertion (D2) is the second.

### D2: What does the green result get checked against?

**Decision:** Pin `EXPECTED_SHA=$(git -C "$BATS_CWD" rev-parse "$BRANCH")`
(the squash commit Phase 2 created, which is the branch tip) and assert
`git -C "$BATS_CWD" rev-parse HEAD == EXPECTED_SHA`.

**Rationale:** Empirically confirmed — `git rev-parse <branch>` resolves the
ref regardless of which branch a checkout currently has, and `git -C <dir>
rev-parse HEAD` reads that dir's own HEAD. The squash commit IS the branch tip
after Phase 2, so the branch ref is the correct expectation.

### D3: When do we assert?

**Decision:** Assert HEAD equality BOTH before the suite (a wrong checkout
should never run) AND after the suite (a flip landed mid-run → the green just
read is untrustworthy). Halt (exit 1) on either mismatch.

**Rationale:** The race window spans the entire ~60–90s suite — the largest
window in the flow. A before-only check misses a flip that lands during the
run; an after-only check wastes a full suite run against the wrong tree. Both
ends are cheap (`rev-parse`).

### D4: How is the guard tested?

**Decision:** Content-validation bats tests in
`kit/tests/util-ak-merge-devshop.bats § G2` — grep the Phase 2.5 prose for the
guard's components (absolute-path resolution, `EXPECTED_SHA` pin to `$BRANCH`,
before+after HEAD assertions, halt-on-mismatch, the rationale comment).

**Rationale:** The skill is a pure LLM markdown prompt. The test file's stated
scope: "Behavior tests (running the LLM end-to-end) are out of scope; this
proves the prompt reflects the contract." Every existing Phase 2.5 / Phase 3
guard (the bats-count gate, the calibration-and-task-phases checkout
verification) is tested by grepping SKILL.md prose. Consistency + the file's
explicit scope statement both point at content validation.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance.
     The Product update + Decisions sections above stay verbatim. -->

## Mode

Devshop-self-mode. The deliverable is a prompt-contract edit to an
`/ak-merge-devshop` SKILL.md phase plus content-validation bats coverage. There
is no UI, no METRICS.md, no migrations, no edge functions, no `apps/`/`packages/`
code. The test surface is bats (`kit/tests/`), not vitest/Playwright. The
metrics-confirmation, render-conditions, and offline-behavior sections of the
`/ak-spec` checklist are N/A and intentionally omitted.

## Core user story

N/A — devshop tooling change (skill prompt + bats test). No user-facing flow
added or modified.

## In scope

1. **Harden `SKILL.md § Phase 2.5`'s bats gate against a HEAD-flip race.** The
   current gate (SKILL.md ~lines 1025-1050) computes
   `BATS_CWD="${GIT_DIR:-$(git rev-parse --show-toplevel)}"` (where `GIT_DIR` is
   set to `$WORKTREE_PATH` when present) and runs the full kit bats suite against
   it. It never asserts which commit it tested. Add a HEAD-pin guard that:
   - **Resolves `$BATS_CWD` to an absolute path** — `cd "$WORKTREE_PATH" && pwd -P`
     when `$WORKTREE_PATH` is set; else `git rev-parse --show-toplevel` (D1). The
     absolute-path resolution removes the implicit `--show-toplevel` re-resolution
     that follows whatever `/devshop` currently points at.
   - **Pins `EXPECTED_SHA=$(git -C "$BATS_CWD" rev-parse "$BRANCH")`** — the squash
     commit Phase 2 created, which is the branch tip after Phase 2 (D2).
   - **Asserts `git -C "$BATS_CWD" rev-parse HEAD == EXPECTED_SHA` BEFORE the
     suite** — halt (`exit 1`) on mismatch so a wrong checkout never runs (D3).
   - **Asserts the same equality AFTER the suite** — halt on mismatch so a flip
     that landed mid-run (the ~60-90s suite is the largest race window in the
     flow) invalidates the green just read (D3).
   - **Carries a rationale comment** naming the parallel-merge HEAD-flip race and
     pointing at the Phase 3 mirror (the calibration-and-task-phases
     2026-05-20 incident) + the `1d343bf` (2026-05-28) worked incident, mirroring
     how the existing Phase 2.5 count-gate and Phase 3 checkout-verification carry
     their incident provenance.
2. **Preserve the existing count-based verdict logic** (`FAILED=$(grep -c '^not ok')`,
   halt-on-`FAILED>0`, the 2026-05-27 buried-`not ok` incident comment). The new
   guard wraps the existing run; it does not replace the count gate.
3. **Add content-validation bats coverage** to
   `kit/tests/util-ak-merge-devshop.bats § Section G2` proving the Phase 2.5 prose
   now contains each guard component (D4).
4. **Close the `kit/TODOS.md` entry** "`/ak-merge-devshop` Phase 2.5 can test the
   wrong tree under parallel merges (HEAD race)" (TODOS.md lines 549-553) and
   unwind cross-references, per `CLAUDE.md § Closing TODO / ROADMAP entries when a
   fix ships`.

## Out of scope

- **Behavior tests that run the LLM end-to-end.** Per the test file's stated scope
  and D4: the skill is a pure LLM markdown prompt; tests prove the prompt reflects
  the contract via `grep`, they do not simulate a live parallel-merge race.
- **Phase 3's existing checkout-verification guard.** It already mirrors the same
  race class; this PR adds the symmetric guard to Phase 2.5, it does not touch
  Phase 3.
- **The `--source-worktree` push path (Phase 3).** Out of scope — Phase 2.5 runs
  before Phase 3 regardless of path; the guard reads `$WORKTREE_PATH` and `$BRANCH`
  which are already set identically in both the auto-detected-worktree and
  `--source-worktree` branches of Phase 0.1.
- **Root-cause work on the vanishing-stash footgun** — separate open `kit/TODOS.md`
  entry, untouched here.
- **Any change to `check-bats-devshop.sh`, `.husky/pre-commit`, or CI.** The gate is
  the manual Phase 2.5 step only.

## Files to create / modify

| File | Change |
| --- | --- |
| `.claude/skills/devshop/merge-devshop/SKILL.md` | Modify `## Phase 2.5: Full bats suite` (~lines 1017-1069): wrap the existing bats run with absolute-path `$BATS_CWD` resolution, `EXPECTED_SHA` pin to `$BRANCH`, before+after HEAD assertions, halt-on-mismatch, and a rationale comment mirroring the Phase 3 guard (~lines 1101-1117). |
| `kit/tests/util-ak-merge-devshop.bats` | Modify `# === Section G2 ===` (~line 523): add content-validation tests grepping the Phase 2.5 prose for absolute-path resolution, `EXPECTED_SHA` pin, before+after HEAD assertions, halt-on-mismatch, and the race-rationale comment. |
| `kit/TODOS.md` | Delete the HEAD-race entry (lines 549-553). |

No new files. No doc files beyond the TODOS deletion — the SKILL.md edit is
self-documenting via its inline rationale comment, satisfying the
"every devshop tooling change includes doc updates in the same commit" rule
(the skill prose IS the doc surface here).

## Tests

Content-validation bats in `kit/tests/util-ak-merge-devshop.bats § Section G2`,
joining the three existing G2 tests (count-verdict, halt-on-fail,
pre-existing-failure rule). Pattern: `awk '/^## Phase 2\.5:/,/^## Phase 3:/'`
to scope the section, then `grep -qE` each guard component. New assertions:

1. **Resolves `$BATS_CWD` to an absolute path.** Assert the section contains the
   `cd "$WORKTREE_PATH" && pwd -P` (or `pwd -P`) absolute-path resolution rather
   than relying on a bare `git rev-parse --show-toplevel` at run time.
2. **Pins `EXPECTED_SHA` to `$BRANCH`.** Assert `EXPECTED_SHA=` is set via
   `git -C ... rev-parse "$BRANCH"` (or `$BRANCH`).
3. **Asserts HEAD before AND after the suite.** Assert the section references
   `git -C ... rev-parse HEAD` and contains both a before-run and after-run
   assertion (e.g. two `EXPECTED_SHA` comparisons, or distinct "before"/"after"
   markers in the prose).
4. **Halts on HEAD mismatch.** Assert the mismatch branch contains `exit 1` and a
   message naming the wrong-checkout / HEAD-moved condition.
5. **Documents the parallel-merge race.** Assert the section's prose names the
   parallel-merge HEAD-flip race and/or the `1d343bf` / calibration-and-task-phases
   provenance.

Full-suite gate after implementation: `kit/tests/lib/bats-core/bin/bats kit/tests/`
must be green (this is exactly the Phase 2.5 gate the change hardens — run it from
the worktree root, which already has submodules populated).

## Dependencies

None new. Implementation touches only markdown (SKILL.md) and a bats file. Bats
vendored libs (`kit/tests/lib/bats-{core,support,assert}`) are already populated in
this worktree via the `submodule update --init --recursive` step from worktree
setup.

## Decision rows from Confidence Calibration

Reviewed against the stop-and-ask list: this change touches none of the
ten categories (no DB, no auth, no third-party API, no perf-sensitive path, no
security logic, no test deletion, no new metric events, no new input-handling
path, no UI a11y/i18n, no new error/observability surface). It hardens an existing
loud-failure gate. Proceed-autonomously: it is a bug fix with a clear root cause
(HEAD-flip race) and a confirming content-validation test, in the
"Documentation updates" + "Bug fixes with clear root cause + confirming test"
lanes. The four substantive decisions (D1-D4) were resolved at Phase 0 and are
recorded above verbatim.

## Task order

1. **Add the HEAD-pin guard to `SKILL.md § Phase 2.5`.** Resolve `$BATS_CWD`
   absolutely (D1), pin `EXPECTED_SHA` to `$BRANCH` (D2), assert HEAD equality
   before and after the suite (D3), halt with a clear message on either mismatch,
   add the race-rationale comment mirroring the Phase 3 guard. Preserve the
   existing count-based verdict logic and its 2026-05-27 incident comment.
2. **Add the Section G2 content-validation bats coverage** (D4) — the five
   assertions above. Run `kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-merge-devshop.bats`
   to confirm green, then the full `kit/tests/` suite.
3. **Close the `kit/TODOS.md` HEAD-race entry** (lines 549-553) and unwind
   cross-references — confirm no other doc/skill cites the open TODO as pending
   (grep for "wrong tree under parallel", "HEAD race", "Phase 2.5 can test the
   wrong tree"). The `spec.md` Sources pointer to the TODO is a historical
   provenance reference and stays.

(Flat list — 3 tasks, well under the 15-task phasing threshold. Tasks 1+2 land in
one commit per the "code without tests is never done" rule; task 3 may land in the
same commit since closing the tracker entry is part of shipping the fix.)

## Gotchas

- **`.husky/` runs under dash, not bash** (user memory: `feedback_husky-dash.md`).
  Irrelevant here — the guard lives in SKILL.md prose (an LLM-executed bash block,
  not a husky hook) and the tests are bats. No husky edit in scope.
- **`$BRANCH` and `$WORKTREE_PATH` are already resolved by Phase 0.1** (SKILL.md
  lines 107-203) in all three entry paths (`--source-worktree`, auto-detected
  worktree, legacy on-feature-branch). The guard reads them; it must NOT
  re-resolve them. In the legacy path `$WORKTREE_PATH` is empty, so `$BATS_CWD`
  falls back to `git rev-parse --show-toplevel` — the absolute-path resolution
  still applies via `pwd -P` after the fallback if needed.
- **`git rev-parse <branch>` resolves the ref regardless of the current checkout**
  (D2 rationale, empirically confirmed) — so `EXPECTED_SHA` is correct even when a
  sibling session has flipped `/devshop`'s HEAD. `git -C "$BATS_CWD" rev-parse HEAD`
  reads that specific dir's HEAD. The two together are the race detector.
- **The after-suite assertion is the load-bearing half.** A before-only check
  misses a flip that lands during the ~60-90s run; the incident (`1d343bf`,
  2026-05-28) shows a red suite reaching `main` precisely because nothing
  re-checked post-run. Don't drop the after-assertion to "save a rev-parse."
- **Mirror the Phase 3 guard's shape, don't reinvent it.** Phase 3 (SKILL.md
  ~1101-1117) already has the canonical wrong-branch-after-checkout guard with its
  incident comment and recovery prose. The Phase 2.5 guard should read as a
  recognizable sibling so a future reader sees the pattern is intentional and
  symmetric.
- **`pwd -P` resolves symlinks** — `.worktrees/` paths and `/devshop` are real
  dirs here, but `-P` is the safe choice for the comparison to be SHA-exact rather
  than path-string-exact.
- **Content-validation only** — do not attempt to write a test that spins up a
  parallel merge or mutates HEAD mid-run. Per D4 and the file's header, the tests
  prove the prompt carries the contract; behavior simulation is explicitly out of
  scope.

## Acceptance

- [ ] `SKILL.md § Phase 2.5` resolves `$BATS_CWD` to an absolute path (no bare
  run-time `--show-toplevel` dependency), pins `EXPECTED_SHA` to `$BRANCH`, asserts
  `HEAD == EXPECTED_SHA` both before and after the bats run, and halts (`exit 1`)
  with a clear message on either mismatch.
- [ ] The guard carries a rationale comment naming the parallel-merge HEAD-flip
  race + the Phase 3 mirror + the `1d343bf` worked incident.
- [ ] The existing count-based verdict logic and its 2026-05-27 incident comment
  are preserved unchanged.
- [ ] `kit/tests/util-ak-merge-devshop.bats § Section G2` has new content-validation
  tests for all five guard components; the file passes.
- [ ] Full `kit/tests/` bats suite is green.
- [ ] The `kit/TODOS.md` HEAD-race entry (lines 549-553) is deleted and no
  doc/skill still cites it as pending.
- [ ] The `## Product update` and `## Decisions` sections are unchanged from the
  Phase 0 skeleton.
