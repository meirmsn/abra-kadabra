<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: ak-build-no-silent-scope-down -->
<!-- date: 2026-05-28 -->

# Spec: ak-build-no-silent-scope-down (devshop)

**Sources:**

- `kit/ROADMAP.md § /ak-build no-silent-scope-down` — primary scope, problem statement, fix shape, bias-avoidance constraint
- `PLAN.md § Planned (v0)` row `ak-build-no-silent-scope-down` — scope summary, leverage
- `.claude/skills/devshop/build/SKILL.md § # Build / Step 0 / Phase 0` — insertion point
- `kit/tests/util-ak-build-skill.bats` — regression-guard test surface (style reference)
- Prior shipped spec `specs/worktree-support/spec.md` — style + structure reference

A behavioral injunction that prevents `/ak-build` from silently improvising a
lighter flow for "small" tasks. Turns the implicit "run the full pipeline"
expectation into an explicit, prominent prohibition with a single narrow escape
hatch (an `AskUserQuestion` whose recommended default is the full pipeline).

---

## Product update

### Headline (user-facing)

`/ak-build` now always runs its complete pipeline — spec, implement, quality
gates, bookkeeping, and audit trail — for every task no matter how small. If a
lighter flow ever genuinely seems warranted, it stops and asks you first
instead of silently improvising one.

### Detail (team-facing)

Adds a prominent prohibition block at the top of `build/SKILL.md` (Step 0 /
Phase 0) that removes the agent's discretion to hand-roll a reduced flow; the
only escape is an explicit `AskUserQuestion` with full-pipeline as the
recommended default. Backed by a one-line restatement at the Phase 0 decision
beat and a bats regression guard. No script changes, no behavior change to any
phase's mechanics.

---

## Decisions (resolved at spec time)

### D1: Placement of the prohibition block

**Decision:** New `## Non-negotiable: run the full pipeline` H2 inserted
between the "Two modes" intro block (ends line 53) and `## Architecture:
subagent delegation` (line 55) in `.claude/skills/devshop/build/SKILL.md`.

**Rationale:** Roadmap calls for a "short, prominent block near the top." The
top-of-file spot (before any phase detail) is the most-read location and frames
the entire skill before the agent reaches any phase it might be tempted to skip.

### D2: Framing — prohibition with a narrow escape hatch, NOT a routine check

**Decision:** The block states the default unconditionally (run every phase,
no question) and frames `AskUserQuestion` as an *exception* path triggered only
by the agent's own deviation impulse. It MUST NOT introduce a per-run "is this
too small for the pipeline?" assessment step, and MUST NOT add a "Step 0.1:
assess pipeline applicability" beat.

**Rationale:** Operator-specified, load-bearing constraint. A routine
applicability check would bias toward shortcuts and add decision fatigue on
every run — the opposite of the intent. Frame as "run it all; if tempted to
deviate, ask instead of acting."

### D3: One-line restatement at the Phase 0 decision beat

**Decision:** A single sentence at the very start of `## Phase 0: Preview +
decisions checkpoint`, cross-referencing the top-of-file block.

**Rationale:** Roadmap: "a one-line restatement at the Phase 0 decision beat."
Phase 0 is where the agent first pauses to think about shape — the right place
for a reminder without repeating the full block.

### D4: Reduced-flow AskUserQuestion template

**Decision:** Embed a concrete `AskUserQuestion` template inside the prohibition
block with three options in order: (1) Run the full pipeline (Recommended);
(2) Run a reduced flow — name what's dropped and why; (3) Abort. Option 2
requires the agent to enumerate exactly which artifacts/phases would be skipped.

**Rationale:** Roadmap marks the template "(optionally)". Including it makes the
escape hatch concrete so even the exception is structured rather than
improvised, and forces the trade-off to be explicit to the operator.

### D5: Regression guard (bats)

**Decision:** Add a new "Section E" to `kit/tests/util-ak-build-skill.bats`
with grep-assertions that: the prohibition block header exists; the no-discretion
phrasing is present; the anti-bias phrasing is present (and the forbidden
"assess pipeline applicability" step is absent); the AskUserQuestion template
options are present; the Phase 0 one-liner is present. Tests derive the SKILL
path from `$TESTS_DIR` (worktree-correct), matching the file's existing pattern.

**Rationale:** Roadmap: "Consider a bats/static check that the injunction text
is present (cheap regression guard)." Enforcement is behavioral, but a presence
check catches a future edit silently deleting the block. bats is the devshop
test surface for a prose-only change.

### D6: Guide-doc coherence touch

**Decision:** One sentence in `kit/docs/guide/workflow.md` noting `/ak-build`
runs the full pipeline by default and asks before deviating. Minimal — a single
line, not a new section.

**Rationale:** Keeps the guide-level pipeline description coherent with the skill
behavior and satisfies the docs-check gate. Kept to one line to avoid scope creep.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Task order, Gotchas, Acceptance. The Product update
     + Decisions sections above stay verbatim. -->

## In scope

- A prominent top-of-file prohibition block in `.claude/skills/devshop/build/SKILL.md`
  that states the default unconditionally: every `/ak-build` run executes its
  complete pipeline (spec → implement → quality gates → bookkeeping → ship/merge),
  regardless of how small the task seems. The agent has **no discretion** to
  hand-roll a lighter flow.
- A single narrow escape hatch framed as an *exception*: if the agent feels a
  genuine impulse to deviate, it MUST stop and fire an `AskUserQuestion` (with the
  full pipeline as the recommended default) rather than silently improvising a
  reduced flow.
- A concrete `AskUserQuestion` template embedded in the block (per D4) with three
  ordered options: (1) Run the full pipeline (Recommended); (2) Run a reduced flow
  — agent must enumerate exactly which artifacts/phases would be dropped and why;
  (3) Abort.
- A one-line restatement at the very start of `## Phase 0: Preview + decisions
  checkpoint`, cross-referencing the top-of-file block (per D3).
- A one-line coherence touch in `kit/docs/guide/workflow.md § Step 4` noting
  `/ak-build` runs the full pipeline by default and asks before deviating (per D6).
- A new "Section E" of grep-assertion bats tests in
  `kit/tests/util-ak-build-skill.bats` guarding block presence, no-discretion
  phrasing, anti-bias phrasing, absence of the forbidden "assess pipeline
  applicability" step, the AskUserQuestion template options, and the Phase 0
  one-liner (per D5).

## Out of scope

- **No script changes.** This is a prose injunction inside an LLM-prompt skill
  file plus a guide-doc line plus presence tests. No `kit/scripts/**` edits, no
  hook changes, no `.husky/**` edits.
- **No new pipeline phases.** The block does NOT add a "Step 0.1: assess pipeline
  applicability" beat or any numbered phase. It frames behavior, not mechanics.
- **No per-run applicability check.** Explicitly forbidden by D2 — the block must
  NOT introduce a routine "is this too small for the pipeline?" assessment that
  fires every run. The default is unconditional; the question fires only on the
  agent's own deviation impulse.
- **No behavior change to any phase's mechanics.** Phases 0–6, the gate matrix,
  the devshop-mode carve-outs, and the merge transport are all untouched.
- **No project-mode vs devshop-mode divergence.** The injunction applies to both
  modes identically — it lives above the mode-specific phase detail.

## Files to create/modify

> **Symlink note:** `.claude/skills/ak-build/` is a symlink to
> `.claude/skills/devshop/build/` (same inode). Editing either path edits the same
> file. The **canonical path is `.claude/skills/devshop/build/SKILL.md`** — all
> edits and all test references use that path.

1. **`.claude/skills/devshop/build/SKILL.md`** (modify) — two edits:
   - **Insert the prohibition block** between the "Two modes" intro block (ends at
     line 53, `…Read `devshop-mode.md` in this directory for devshop-specific
     phases.`) and `## Architecture: subagent delegation` (line 55). New H2:
     `## Non-negotiable: run the full pipeline`. Content (per D1, D2, D4):
     - One sentence stating the unconditional default — run **every** phase for
       **every** task, no matter how small, with no per-run question and no
       hand-rolled reduced flow.
     - A no-discretion sentence making clear the agent does NOT decide a task is
       "too small" for the pipeline.
     - The anti-bias framing: there is **no** routine "assess pipeline
       applicability" step; the only deviation path is the exception below.
     - The exception path: if the agent feels a genuine impulse to deviate, it
       stops and asks via `AskUserQuestion` rather than acting.
     - The embedded `AskUserQuestion` template (three ordered options per D4,
       option 2 requires enumerating dropped artifacts/phases).
   - **Insert the Phase 0 one-liner** as the first line under
     `## Phase 0: Preview + decisions checkpoint` (currently line 252), before the
     existing "Before spawning any subagent…" paragraph. One sentence
     cross-referencing `§ Non-negotiable: run the full pipeline` (per D3).

2. **`kit/docs/guide/workflow.md`** (modify) — one sentence in `## Step 4:
   `/ak-build` …` noting the pipeline runs in full by default and that `/ak-build`
   asks before deviating to a lighter flow (per D6). Placed in the Step 4 prose so
   the guide-level pipeline description stays coherent with the skill behavior.

3. **`kit/tests/util-ak-build-skill.bats`** (modify) — append "Section E" with the
   grep-assertion @tests described under ## Tests. The file already derives
   `SKILL_FILE` and `WORKFLOW_FILE` from `$TESTS_DIR` in `setup()` (lines 27–28),
   so the new tests inherit worktree-correct paths with no extra plumbing.

## Tests

All assertions are content-validation greps against `$SKILL_FILE` (the worktree
copy, via `$TESTS_DIR`) and one against `$WORKFLOW_FILE`, matching the file's
existing Section A/B/D snapshot-test style. Add a `# === Section E — …` banner
comment, then:

- **`@test "Section E: prohibition block header present"`** — assert the H2
  exists: `grep -qE '^## Non-negotiable: run the full pipeline' "$SKILL_FILE"`.
- **`@test "Section E: no-discretion phrasing present"`** — assert the block
  removes agent discretion (e.g. grep for phrasing that the agent must run every
  phase / has no discretion to hand-roll a reduced flow). Target a distinctive
  phrase the block introduces, e.g. `grep -qiE 'no discretion|hand-roll' …` paired
  with an "every phase / every task / no matter how small" grep.
- **`@test "Section E: anti-bias phrasing present AND forbidden step absent"`** —
  the load-bearing anti-bias test (D2/D5). Assert the block frames deviation as an
  exception (positive grep for the exception/`AskUserQuestion` framing) AND assert
  the forbidden routine step is **absent**:
  `! grep -qiE 'assess pipeline applicability' "$SKILL_FILE"` and
  `! grep -qiE 'Step 0\.1' "$SKILL_FILE"` (no per-run applicability beat).
- **`@test "Section E: AskUserQuestion template options present"`** — assert all
  three escape-hatch options exist: positive greps for the full-pipeline
  (Recommended) option, the reduced-flow option (with the "name what's dropped"
  enumeration requirement), and the Abort option.
- **`@test "Section E: Phase 0 one-liner restatement present"`** — assert a line
  near `## Phase 0` cross-references the top-of-file block (grep for the
  `Non-negotiable` reference appearing in the Phase 0 region, e.g. via an `awk`
  slice of `/^## Phase 0/,/^### 0\.1/` then grep for `Non-negotiable`).
- **`@test "Section E: workflow.md notes full-pipeline-by-default + asks before deviating"`**
  — `tr '\n' ' ' < "$WORKFLOW_FILE"` then grep for the full-pipeline-by-default /
  asks-before-deviating phrasing, matching the existing newline-collapse pattern
  used by the other `workflow.md` tests (lines 87–88, 127–128).

The exact distinctive phrases are chosen during Task 1 (block authoring) and the
greps in Task 3 are matched to them — author the prose first, then pin the tests
to it.

## Task order

Dependency-ordered (3 tasks; migrations-first / E2E-last ordering rules do not
apply to a prose-only change):

1. **Prohibition block + Phase 0 one-liner in `build/SKILL.md`** — author the
   `## Non-negotiable: run the full pipeline` block at the D1 insertion point and
   the D3 one-liner under `## Phase 0`. This defines the canonical wording that the
   tests pin to, so it goes first.
2. **One-line coherence touch to `kit/docs/guide/workflow.md`** — the D6 Step 4
   sentence. Independent of Task 1's exact wording but logically downstream of the
   behavior it describes.
3. **Section E tests in `kit/tests/util-ak-build-skill.bats`** — grep-assertions
   pinned to the phrases authored in Tasks 1 and 2. Goes last so the greps match
   the final committed prose.

## Gotchas

- **The symlink — edit once, both paths update.** `.claude/skills/ak-build/` and
  `.claude/skills/devshop/build/` are the same inode. Edit only the canonical
  `.claude/skills/devshop/build/SKILL.md`; do NOT also edit the `ak-build/` path
  (it would be a no-op redundant edit at best, or a confusing double-edit).
- **The anti-bias constraint is load-bearing in the WORDING (D2).** The block must
  read as "run it all; if tempted to deviate, ask" — NOT "check whether this is too
  small, then decide." A test asserts the forbidden `assess pipeline applicability`
  step and a `Step 0.1` beat are **ABSENT**. When authoring, avoid any phrasing
  that reads like a routine per-run gate; frame `AskUserQuestion` strictly as an
  exception triggered by the agent's own impulse.
- **bats runs under the worktree's submodule-vendored libs.** The test file's
  `setup()` does `load helpers/setup` and the bats-support/bats-assert libraries
  are git submodules — run tests from inside this worktree (where
  `submodule update --init --recursive` has populated `kit/tests/lib/`). Running
  from a worktree without populated submodules fails with
  `Could not find '<…>/kit/tests/lib/bats-support/load'`.
- **Tests derive paths from `$TESTS_DIR`, not hardcoded `/devshop/...`.** This is
  already the file's convention (lines 27–28) and is what makes the tests fire
  against the worktree copy being edited rather than the canonical `/devshop` tree.
  New Section E tests must reuse `$SKILL_FILE` / `$WORKFLOW_FILE`, not new
  hardcoded paths.
- **Author prose before pinning greps.** The distinctive phrases the Section E
  greps match are decided in Task 1; lock them, then write Task 3's assertions
  against the committed wording so they don't drift.

## Acceptance

- `bats kit/tests/util-ak-build-skill.bats` is green from inside the worktree
  (all existing Sections A–D plus the new Section E pass).
- The prohibition block is present and prominent — a top-of-file H2 above
  `## Architecture: subagent delegation`, before any phase detail.
- The wording honors the anti-bias constraint (D2): unconditional default +
  exception-only `AskUserQuestion`, with NO routine "assess pipeline
  applicability" step and NO `Step 0.1` beat (verified by the absence assertions).
- The Phase 0 one-liner (D3) and the workflow.md coherence line (D6) are present
  and cross-reference / mirror the block.
- The `AskUserQuestion` template (D4) is embedded with all three ordered options,
  option 2 requiring enumeration of dropped artifacts/phases.
- No script, hook, or phase-mechanics changes shipped.
- PLAN.md row + `kit/ROADMAP.md § /ak-build no-silent-scope-down` closure is
  deferred to Phase 4.0 (BUILD-LOG + PLAN + roadmap closure), per the standard
  pipeline — NOT done at spec time.
