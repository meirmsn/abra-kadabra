<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: cheap-test-gates-local -->
<!-- date: 2026-05-06 -->

# Spec: cheap-test-gates-local (PR 1)

**Sources:**

- `/devshop/kit/ROADMAP.md § Shift cheap test gates from CI-only to local pre-push` (lines 1708–1779, v1) — primary scope source
- `/devshop/.claude/skills/ak-pre-ship/SKILL.md` — gate ordering (#2c slow-job-lifecycle is the existing neighbor; new gate slots at #2d) and preflight Supabase-bootstrap shape
- `/devshop/kit/scripts/preship/supabase-bootstrap.sh` — existing preflight stack-bootstrap helper (sub-fix 3 extends this)
- `/devshop/kit/scripts/adversarial-review.sh` — adversarial review channel for new bypass-flag check-type
- `/devshop/kit/hooks/pre-push.sh` — existing pre-push guard chain (Check 0–3); reference for bypass-flag conventions like `git config devshop.dirtyPushReason`
- `/devshop/.claude/skills/devshop/build/SKILL.md` — pre-ship → ship handoff and PR body checkbox semantics (the Playwright `--list` parse-check claim cited at line 1421 turns out not to be wired today; this PR wires it)
- `/devshop/kit/docs/guide/{conventions,hooks,workflow}.md` — convention docs that need updates
- `/workspace/apps/web/e2e/*-qa-walk.spec.ts` (lalista) — empirical evidence for the "QA-walk specs as smoke set" convention (4 such specs already exist organically)

**One-liner:** Shift the _cheap_ halves of integration + E2E test execution from CI-only into `/ak-pre-ship` so a developer discovers a broken Playwright spec or a degraded local Supabase stack 30 seconds before pushing instead of 8–10 minutes after, without changing what runs in CI.

---

## Decisions (resolved at spec time)

Nine `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below verbatim so Phase 1 preserves them and a crash-restart resumes without re-asking.

### D1: Gate slot in pre-ship

**Decision:** New devshop-owned gate `changed-tests-local (ak)` at position **#2d** in `/devshop/.claude/skills/ak-pre-ship/SKILL.md § Gates (canonical order + named IDs)` — after `slow-job-lifecycle` (#2c), before `responsive-theme` (#3).

**Rationale:** Mirrors existing devshop gate ordering (rls-coverage 2b, slow-job-lifecycle 2c, design-conformance 8b — all `(ak)` gates wedged into the gstack-derived numbering). Runs early so a halt fires before browser/QA gates spend their wallclock.

### D2: Parse-check wiring

**Decision:** Same gate runs `playwright test --list` as the _first_ step (parse-check), then runs the execution-on-changed step second. Parse failure short-circuits before execution.

**Rationale:** The roadmap's claim that `playwright test --list` is "already wired into pre-ship" doesn't match the current tree — grep across `.claude/skills/`, `.husky/`, `kit/hooks/`, `template/`, and CI workflows finds zero invocations. The claim's intent is correct (parse errors should never reach CI); wiring it as the cheap front-half of the new gate is the right home.

### D3: Smoke-set discovery shape

**Decision:** **Convention-based glob, no config file in this PR.** The smoke set is the union of two globs at the project repo root:

- `apps/web/e2e/*-qa-walk.spec.ts`
- `apps/web/e2e/qa-walk.spec.ts`

Gate runs every match against `pnpm dev` whenever the diff touches `apps/web/**` or `packages/{core,ui}/**`.

**Rationale:** Lalista already adopted the `*-qa-walk` convention organically (4 specs as of 2026-05-06: `core-flows-qa-walk.spec.ts`, `disambig-add-new-hero-qa-walk.spec.ts`, `qa-walk.spec.ts`, `ci-slow-job-qa-walk.spec.ts`). Convention-over-config means the floor exists immediately for any project that follows the same naming. An explicit `kit/template/.devshop/test-impact.json` becomes a sub-fix 2 stage 2 concern (deferred — see "Deferred follow-ups" below).

### D4: Stack-needing path classifier (sub-fix 3)

**Decision:** Hardcoded path-classifier function in a new helper `kit/scripts/preship/path-classifier.sh` (or inlined into `supabase-bootstrap.sh`'s `up` subcommand — Phase 1 picks the file split). Seeded with the roadmap's table verbatim:

| Path glob                                      | Classified as     |
| ---------------------------------------------- | ----------------- |
| `apps/**`                                      | stack-needing     |
| `packages/core/**`, `packages/ui/**`           | stack-needing     |
| `**/*.integration.test.ts` (added or modified) | stack-needing     |
| `apps/web/e2e/*.spec.ts` (added or modified)   | stack-needing     |
| `supabase/migrations/**`                       | stack-needing     |
| `supabase/functions/**`                        | stack-needing     |
| Anything else                                  | not stack-needing |

**Rationale:** Roadmap states these are "project-template defaults; projects can extend." In this PR no project extends, so a hardcoded baseline is sufficient. Extension surface (per-project override file) becomes sub-fix 2 stage 2's `test-impact.json` concern.

### D5: Wallclock budgets + bypass mechanism

**Decision:**

- E2E execution-on-changed cap: **2 minutes** total (Playwright `--max-failures=1 --workers=1` against `pnpm dev`, chromium only — full multi-viewport stays on CI).
- Integration execution-on-changed cap: **1 minute** (`VITEST_INTEGRATION=1 pnpm vitest run <changed files>`).
- Smoke-set cap: **2 minutes** total. Specs that exceed the budget produce the "found N specs; M ran, K deferred to CI" triage line per the roadmap.
- Combined floor cap: **~5 minutes** total (matches roadmap text).
- Bypass: `git config devshop.localTestSkipReason "<why these are OK to skip locally>"`. Same shape as existing `devshop.testReviewSkipReason` / `devshop.dirtyPushReason` / `devshop.prDescStaleReason`.

**Rationale:** Reuses the existing devshop bypass channel; no new escape-hatch surface. The 2/1/2/5 budgets are the roadmap's numbers verbatim, not invented here.

### D6: Sub-fix 3's config flag default

**Decision:** `git config devshop.requireHealthyLocalStack` reads one of:

- _(unset)_ → behave as `when-relevant`. **Default behavior — fail-shut on stack-needing diffs only.**
- `when-relevant` → same as unset; explicit form for clarity.
- `never` → preflight always treats degraded stack as `pass-with-note` (legacy behavior; explicit opt-out for projects that legitimately can't run a local stack).
- `always` → preflight treats any degraded stack as `blocked` regardless of diff. Aspirational; not the default.

**Rationale:** Roadmap says default `'when-relevant'` once one project runs two cycles cleanly; until then ship behind the same key. The unset → `when-relevant` mapping means new projects get fail-shut behavior immediately on stack-needing diffs without any explicit opt-in, while the `never` value provides a documented escape for projects that don't have a local stack at all.

### D7: New gate's dismissal-log + adversarial-review wiring

**Decision:** Gate emits `## Dismissals` section per the existing devshop convention. Adversarial review fires through `kit/scripts/adversarial-review.sh` with **two** check-types:

1. `dismissalLog` — for the gate's findings dismissals (existing channel, no new code).
2. `localTestSkipReason` — **new** check-type added to `adversarial-review.sh`, mirrors existing `testReviewSkipReason` shape. Reviews the bypass reason set via `git config devshop.localTestSkipReason`.

**Rationale:** Consistent with existing `(ak)` gates (rls-coverage, slow-job-lifecycle, design-conformance). The bypass-flag adversarial review is the structural backstop that prevents "ran out of time, skipping" from becoming a habit.

### D8: BATS test coverage for the new gate itself

**Decision:** Add BATS test files in `kit/tests/`:

- `util-path-classifier.bats` — every path in D4's table maps to the expected classification; ambiguous paths (e.g., `apps/web/e2e/_smoke/`) classify deterministically.
- `util-changed-tests-local.bats` — diff parsing, spec-glob match, timeout enforcement, bypass parsing, output shape.
- `util-adversarial-review-localTestSkipReason.bats` — new check-type wired correctly, weak/generic reasons rejected.
- `util-supabase-bootstrap-classifier.bats` — preflight integration: degraded stack + stack-needing diff → `blocked`; degraded stack + docs-only diff → `pass-with-note`; honors `git config devshop.requireHealthyLocalStack` values.

**Rationale:** Devshop convention — every new helper script gets BATS coverage in `kit/tests/`. See existing patterns in `kit/tests/util-adversarial-review*.bats`, `kit/tests/util-rls-coverage*.bats`.

### D9: Cross-project adoption surface

**Decision:** **Devshop-side only in this PR.** Template gets:

- The new gate definition in `ak-pre-ship/SKILL.md`.
- The new helper scripts in `kit/scripts/preship/`.
- The new BATS tests in `kit/tests/`.
- Doc updates (`kit/docs/guide/{hooks,conventions,workflow}.md`, `/devshop/CLAUDE.md` Tier 1).
- Roadmap bookkeeping (this entry → `[SHIPPED]`; new v1 entries for deferred sub-fix 2 stages + lalista adoption).

**Lalista adoption is a separate follow-up PR** (per user direction at Phase 0).

**Rationale:** Self-contained PR is easier to review. Lalista PR becomes the validation ground that proves the gate fires correctly on a real diff (and inversely, that pure-docs diffs don't trigger it).

---

## Deferred follow-ups (NOT shipping in this PR)

Recorded here so Phase 7's notify step can remind the operator and Phase 5.6 / 5.8 can add the new entries to `kit/ROADMAP.md`.

1. **Sub-fix 2 stage 2 — path-pattern map.** Per-project config at `.devshop/test-impact.json` mapping changed source paths to spec paths via filename regex. New v1 roadmap entry to be added in Phase 5.6.
2. **Sub-fix 2 stage 3 — import-graph match.** `tsc --listFiles` (or madge) walk to find every spec that transitively imports the changed file, cached against diff hash. New v1 roadmap entry to be added in Phase 5.6.
3. **Lalista adoption PR.** Demonstrates the new gate firing on a real lalista diff: validates the `*-qa-walk` smoke-set convention (already organically present), exercises sub-fix 3's `blocked` promotion against a real degraded-stack scenario, and verifies the bypass flow. New v1 roadmap entry to be added in Phase 5.6.

Out-of-scope items already called out by the source roadmap entry (no new entries needed — they exist):

- Slow-job skip-on-docs-only.
- Test-impact analysis (TIA) systems.
- Tightening `/qa`'s `n/a` criteria.

---

<!-- /ak-spec (Phase 1) expanded the file from here. The Decisions and Deferred
     follow-ups sections above are user-approved and verbatim. -->

## In scope

Concrete bullets, grouped by file/concept. One-screen-scannable per area; deeper
detail goes into "Files to create / modify" and "API / behavior contracts" below.

**New devshop gate `changed-tests-local (ak)` at #2d in `ak-pre-ship/SKILL.md`**

- Scope detection: runs whenever the diff against `origin/main` includes any of
  the stack-needing path globs from D4 (so it's `n/a` for pure-docs diffs).
- Step 1 (parse-check): `pnpm exec playwright test --list` from the project's
  Playwright config root. Parse failure → halt with `findings (1)` (no execution
  step runs). Cap: 30s.
- Step 2 (changed E2E execution): collect `apps/web/e2e/*.spec.ts` files in
  `git diff --name-only origin/main...HEAD` whose status is A (added) or M
  (modified). Run them against `pnpm dev` with chromium-only,
  `--max-failures=1 --workers=1`. Wallclock cap: 2 min total per D5.
- Step 3 (changed integration execution): collect `*.integration.test.ts` files
  matching the diff. Run with `VITEST_INTEGRATION=1 pnpm vitest run <files>`
  against the local Supabase stack already brought up by preflight. Cap: 1 min.
- Step 4 (smoke set): when the diff touches `apps/**` or `packages/{core,ui}/**`,
  run the union of `apps/web/e2e/*-qa-walk.spec.ts` and
  `apps/web/e2e/qa-walk.spec.ts` (D3). Cap: 2 min total. On timeout, emit the
  triage line `found N specs; M ran, K deferred to CI` per D5.
- Combined floor cap: ~5 min wallclock. Each step uses the shell `timeout`
  builtin; on hit, the step exits cleanly with the triage line and the gate
  records `findings (N) [budget exceeded]` rather than `pass`.
- Bypass: `git config devshop.localTestSkipReason "<why>"` per D5. Adversarial
  review fires through the new `localTestSkipReason` check-type (D7).
- Output: stdout follows the canonical gate shape — outcome line, findings
  bullets, `## Dismissals` section per the existing devshop convention.

**Stack-needing path classifier (sub-fix 3)**

- New helper `kit/scripts/preship/path-classifier.sh classify <path>` returns
  one of `stack-needing` / `not-stack-needing` on stdout (exit 0 either way).
  Seeded with D4's globs verbatim.
- New helper `kit/scripts/preship/path-classifier.sh diff-needs-stack
[<base-ref>]` walks `git diff --name-only <base>...HEAD` and exits 0 if any
  path classifies as `stack-needing`, exit 1 otherwise. Default base: `origin/main`.
- `supabase-bootstrap.sh up` calls `diff-needs-stack` BEFORE the existing
  reachability detection. When the result is `not-stack-needing` (docs-only
  diff), preserve current `pass-with-note` behavior even on a degraded stack.
  When `stack-needing`, promote a degraded stack from `pass-with-note` to
  `blocked` per D6's `when-relevant` semantics.
- `git config devshop.requireHealthyLocalStack` reads one of `unset` /
  `when-relevant` / `never` / `always` (D6). The script normalizes unset →
  `when-relevant`.

**New adversarial-review check-type `localTestSkipReason`**

- Added to `kit/scripts/adversarial-review.sh`'s case statement next to
  `testReviewSkipReason`.
- Sonnet-routed (joins the `prDescStaleReason | testReviewSkipReason |
dismissalLog | hookBypass | exemptAddition` Sonnet group — judgment-heavy,
  high-blast-radius — see existing `get_model_for_check_type`).
- Prompt mirrors `testReviewSkipReason`'s shape: per-finding engagement,
  no-core-flow-dismissal, plausible follow-up commitment, no security-boundary
  skips. Default REJECT.

**BATS test coverage**

Four new BATS suites in `kit/tests/`, mirroring the shape of existing helpers:

- `util-path-classifier.bats` — every path in D4's table classifies as
  expected; ambiguous paths (`apps/web/e2e/_smoke/foo.spec.ts`,
  `supabase/migrations/.gitkeep`, etc.) classify deterministically;
  `diff-needs-stack` exit codes match the table.
- `preship-changed-tests-local.bats` — diff parsing, spec-glob match logic,
  smoke-set globbing, timeout enforcement (mocked via fast-failing test
  doubles), bypass-flag plumbing, output shape (outcome line + Dismissals
  body), `n/a` paths.
- `util-adversarial-review-localTestSkipReason.bats` — new check-type wired
  correctly (no "unknown check type"), weak/generic reasons rejected
  (`"will fix later"` / `"ran out of time"`), specific reasons accepted
  (per-finding rationale + ROADMAP/TODOS pointer).
- `preship-supabase-bootstrap-classifier.bats` — preflight integration:
  degraded stack + stack-needing diff → `blocked`; degraded stack +
  docs-only diff → `pass-with-note`; honors all four
  `devshop.requireHealthyLocalStack` values.

**Doc updates**

- `kit/docs/guide/conventions.md § Slow-Job Lifecycle` — add cross-reference to
  the new local pre-push gate (the local floor doesn't replace slow-job; it
  catches the cheap subset earlier).
- `kit/docs/guide/conventions.md` — new section `## Local Pre-Push Test Gates`
  documenting the smoke-set convention (`*-qa-walk.spec.ts`), the
  stack-needing path classifier, the wallclock budgets, and the bypass flag.
- `kit/docs/guide/hooks.md § Dismissal Log` — add `localTestSkipReason` to the
  bypass-flag section's enumeration of devshop-side bypass surfaces.
- `kit/docs/guide/workflow.md § Pipeline at a Glance` — note the new gate at
  #2d in the ordering callout.
- `/devshop/CLAUDE.md` Tier 1 — add a one-line entry noting the new gate's
  bypass flag (`devshop.localTestSkipReason`) and the
  `devshop.requireHealthyLocalStack` config key, in the same shape as existing
  bypass-flag mentions.

**Roadmap bookkeeping**

- `kit/ROADMAP.md § Shift cheap test gates from CI-only to local pre-push` →
  mark `[SHIPPED]` and add a one-line link to this PR.
- Three new v1 entries appended (per "Deferred follow-ups" above): sub-fix 2
  stage 2 (`test-impact.json` path-pattern map), sub-fix 2 stage 3
  (import-graph match via `tsc --listFiles` / `madge`), and the lalista
  adoption PR.

**Conditional: PLAN.md + BUILD-LOG.md seed in the devshop repo**

- The devshop repo currently has no `PLAN.md` / `BUILD-LOG.md` at root (only
  `template/PLAN.md` + `template/BUILD-LOG.md`). `/ak-build § Phase 5.6`
  already self-heals (reads "If `BUILD-LOG.md` doesn't exist, copy from
  `/devshop/template/BUILD-LOG.md`. If `PLAN.md` doesn't exist, copy from
  `/devshop/template/PLAN.md`."). This task seeds both proactively to avoid
  the docs-only-first-commit edge case where 5.6 races against 5.7's
  re-watch. See Task 8 below for the full decision and Gotcha 4.

## Out of scope

Re-stated from the skeleton's Deferred follow-ups + the source roadmap's
explicit out-of-scope table, so a reviewer sees the full boundary in one
place:

**Deferred to follow-up PRs** (tracked as new v1 roadmap entries by Task 7):

- **Sub-fix 2 stage 2** — per-project `.devshop/test-impact.json` mapping
  changed source paths to spec paths via filename regex. The convention-based
  smoke set is the floor this PR ships; an explicit per-project config is the
  precision layer above it.
- **Sub-fix 2 stage 3** — import-graph match (`tsc --listFiles` or `madge`)
  cached against diff hash. The most expensive heuristic; deferred until the
  smoke + path-pattern layers prove insufficient on a real project.
- **Lalista adoption PR** — first project to validate the new gate
  end-to-end. Convention-based smoke set already organically present; the
  PR's job is to verify the gate fires correctly + bypass flow works + the
  promoted `blocked` outcome is recoverable.

**Already separate roadmap entries** (called out in the source roadmap as
explicitly out of scope; no new entries needed):

- Slow-job skip-on-docs-only — `paths-ignore` filter in `.github/workflows/ci.yml`.
- Test-impact analysis (TIA) systems — Datadog Test Optimization /
  Gradle-Enterprise-style real instrumentation, the precise version of
  sub-fix 2.
- Tightening `/qa`'s `n/a` criteria — requiring file:line claims an
  adversarial reviewer can verify, not self-attestation prose.

## Files to create / modify

Grouped by area. Action codes: **C** = create, **M** = modify.

### Skills

| Path                                           | Action | What changes                                                                                                                                                                          | Why                    |
| ---------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| `/devshop/.claude/skills/ak-pre-ship/SKILL.md` | M      | Insert new `## Gate changed-tests-local (ak)` body between `slow-job-lifecycle` (#2c) and `Gate 3: Responsive + theme check` (#3); add row to the canonical-order table at line ~205. | D1 — gate slot at #2d. |

### Scripts

| Path                                         | Action | What changes                                                                                                                                                                                                                                                                                                                                                                                                                                 | Why                             |
| -------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `kit/scripts/preship/changed-tests-local.sh` | C      | Implements the four-step gate body (parse-check → changed E2E → changed integration → smoke set), wallclock-bounded via `timeout`, emits canonical outcome line + Dismissals body.                                                                                                                                                                                                                                                           | D1, D2, D3, D5.                 |
| `kit/scripts/preship/path-classifier.sh`     | C      | Two subcommands: `classify <path>` and `diff-needs-stack [<base-ref>]`. Hardcoded glob list from D4.                                                                                                                                                                                                                                                                                                                                         | D4 — sub-fix 3 path classifier. |
| `kit/scripts/preship/supabase-bootstrap.sh`  | M      | `up` mode: before the existing reachability `case "$SHAPE"` block, query `path-classifier.sh diff-needs-stack`. When the diff is stack-needing AND the chosen detection branch reports "blocked"-shaped state (currently exit 0 with `blocked:` stdout), promote to a hard `blocked` per D6. When not stack-needing, preserve today's `pass-with-note` behavior. Read `git config devshop.requireHealthyLocalStack` to override (D6 values). | D6 — sub-fix 3 promotion.       |
| `kit/scripts/adversarial-review.sh`          | M      | Add `localTestSkipReason)` case (after `testReviewSkipReason)`); add to Sonnet branch in `get_model_for_check_type`; append per-check-type rule #10 to the prompt mirroring `testReviewSkipReason`'s shape.                                                                                                                                                                                                                                  | D7 — new check-type.            |

### Tests

| Path                                                         | Action | What changes                                                                                                                                                  | Why |
| ------------------------------------------------------------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --- |
| `kit/tests/util-path-classifier.bats`                        | C      | Verify every D4 row's classification + ambiguous-path determinism + `diff-needs-stack` exit codes.                                                            | D8. |
| `kit/tests/preship-changed-tests-local.bats`                 | C      | Diff parsing / spec-glob match / smoke-set globbing / timeout enforcement / bypass plumbing / output-shape contract.                                          | D8. |
| `kit/tests/util-adversarial-review-localTestSkipReason.bats` | C      | New check-type wired (no "unknown") + weak/generic reasons rejected + specific reasons accepted. Mocks `claude` per `util-adversarial-review-narrowing.bats`. | D8. |
| `kit/tests/preship-supabase-bootstrap-classifier.bats`       | C      | Preflight integration: degraded × stack-needing → `blocked`; degraded × docs-only → `pass-with-note`; honors all four config values.                          | D8. |

### Hooks

No changes. The new bypass flag `devshop.localTestSkipReason` is read by the
gate body itself (in `changed-tests-local.sh`), not by `pre-push.sh`. Hooks
contract already covers `git config`-based bypass; no new wiring needed.

### Docs

| Path                            | Action | What changes                                                                                                                                                                                                     | Why                      |
| ------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `kit/docs/guide/conventions.md` | M      | Add `## Local Pre-Push Test Gates` section (smoke-set convention, classifier, budgets, bypass); cross-reference from existing `## Slow-Job Lifecycle`.                                                           | D9 — convention surface. |
| `kit/docs/guide/hooks.md`       | M      | Add `localTestSkipReason` to the bypass-flag enumeration in `## Dismissal Log § Bypass flags + env hatches`.                                                                                                     | D9.                      |
| `kit/docs/guide/workflow.md`    | M      | Note new gate #2d in `## Pipeline at a Glance`.                                                                                                                                                                  | D9.                      |
| `/devshop/CLAUDE.md`            | M      | One-line Tier-1 entry: "`devshop.localTestSkipReason` bypasses the `changed-tests-local (ak)` gate; `devshop.requireHealthyLocalStack` controls preflight's degraded-stack promotion (default `when-relevant`)." | D9 — Tier 1.             |

### Roadmap

| Path             | Action | What changes                                                                                                                                                            | Why                       |
| ---------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- |
| `kit/ROADMAP.md` | M      | Mark "Shift cheap test gates from CI-only to local pre-push" `[SHIPPED]` with PR link. Append three v1 entries: sub-fix 2 stage 2, sub-fix 2 stage 3, lalista adoption. | D9 — roadmap bookkeeping. |

### Devshop bookkeeping (conditional — see Task 8)

| Path                    | Action | What changes                                                                         | Why                                                                                                    |
| ----------------------- | ------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `/devshop/PLAN.md`      | C      | Copy from `/devshop/template/PLAN.md`; add Active row for this branch.               | Phase 5.6 self-heals if missing, but seeding proactively avoids the 5.6/5.7 race surfaced in Gotcha 4. |
| `/devshop/BUILD-LOG.md` | C      | Copy from `/devshop/template/BUILD-LOG.md` (intro + `_No builds yet._` placeholder). | Same.                                                                                                  |

## API / behavior contracts

### `changed-tests-local.sh` — the new gate body

**CLI:** `bash changed-tests-local.sh [<project-root>]`. Default project root is
`git rev-parse --show-toplevel`.

**Stdout contract** (mandatory shape, parsed by the pre-ship orchestrator):

```
<outcome-line>
<finding bullets, indented "  - ">

## Dismissals
<None | bulleted list with rationale: lines>
```

**Outcome line** is exactly one of:

- `pass` — every step ran cleanly within budget OR every step was no-op (no
  changed specs and smoke set didn't apply).
- `findings (N)` — N steps surfaced failures. Each step's failures appear as
  bullets.
- `findings (N) [budget exceeded]` — at least one step hit its wallclock cap;
  triage line `found N specs; M ran, K deferred to CI` appears as a bullet.
- `n/a (no stack-needing paths in diff)` — diff is pure-docs / outside D4's
  globs.
- `blocked (<reason>)` — preflight precondition not met (e.g. `pnpm dev` won't
  start, Playwright not installed). Distinguished from `findings` because the
  gate couldn't run the substance, not that the substance failed.

**Audit hooks:**

- After the outcome, the gate writes the same data as a section into
  `specs/<feature>/review.md § Gate changed-tests-local` (per the Dismissal
  Log convention) so the Router Summary aggregator picks it up.
- `## Dismissals` body is `None` when no findings were dismissed (the common
  case — failed specs typically produce findings, not dismissals). When the
  budget is exceeded, the deferred-to-CI specs are recorded as dismissals
  with rationale `wallclock budget exceeded; CI will exercise these in slow-job`
  — and adversarial review verifies the budget-exceeded triage line is honest.

**Bypass:** `git config devshop.localTestSkipReason "<reason>"` short-circuits
the gate after invoking adversarial review (`localTestSkipReason` check-type)
on the reason. Acceptance → `pass (skipped — adversarially reviewed)`. Rejection
→ `findings (1) pending` with the reviewer's verdict as the bullet.

### `path-classifier.sh` — the new helper

**Subcommands:**

| Subcommand                  | Args                                      | Stdout                                 | Exit                                                                     |
| --------------------------- | ----------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------ |
| `classify <path>`           | one path string                           | `stack-needing` or `not-stack-needing` | 0 (always — read-only classification)                                    |
| `diff-needs-stack [<base>]` | optional base ref (default `origin/main`) | (silent)                               | 0 if any diff path classifies stack-needing; 1 otherwise; 2 on git error |

Path matching is hardcoded glob-vs-path tests (no external deps). Implementation
is idempotent and side-effect-free.

### `supabase-bootstrap.sh up` — the contract change

The existing `up` mode has three reachability shapes (compose / docker-bind /
host) and one fall-through (`none`). Today, `none` and shape-specific failures
(relay unreachable, docker missing) emit `blocked:` to stdout with exit 0 and
the orchestrator decides what to do. This PR adds an EARLIER decision point
that runs BEFORE shape detection.

**Decision matrix** (D6, codified):

| `requireHealthyLocalStack` | diff-needs-stack | reachability | Outcome                                                                                           |
| -------------------------- | ---------------- | ------------ | ------------------------------------------------------------------------------------------------- |
| _unset_ or `when-relevant` | yes              | healthy      | existing `ok` / `reused`                                                                          |
| _unset_ or `when-relevant` | yes              | degraded     | **`blocked` (NEW)**                                                                               |
| _unset_ or `when-relevant` | no               | healthy      | existing `ok` / `reused`                                                                          |
| _unset_ or `when-relevant` | no               | degraded     | `pass-with-note` (legacy; surfaced via stdout `blocked:` shape — orchestrator treats as advisory) |
| `never`                    | any              | degraded     | `pass-with-note` (legacy — explicit opt-out)                                                      |
| `always`                   | any              | degraded     | **`blocked`**                                                                                     |
| `always`                   | any              | healthy      | existing `ok` / `reused`                                                                          |

**Implementation note:** the existing `blocked:` stdout token already exists
in the script; the change is solely about WHEN the script emits it. The
orchestrator-side reading of `blocked:` is unchanged.

### `adversarial-review.sh` — `localTestSkipReason` check-type

**Trigger:** the `changed-tests-local` gate body invokes
`bash adversarial-review.sh localTestSkipReason "$REASON"` when
`devshop.localTestSkipReason` is set.

**Reviewer prompt** (added as per-check-type rule #10, mirrors #7's structure
verbatim except substituting "the changed-tests-local gate" for "Phase 5.8"):

```
10. For localTestSkipReason (changed-tests-local gate bypass): the Reason justifies
    skipping local execution of changed E2E specs / changed integration specs /
    smoke set despite paths in the diff that need them. PASS requires ALL of:
    (a) Per-finding engagement: the reason names each test category being
        skipped (e.g. "skipping the smoke set because pnpm dev wedges in this
        devcontainer; the changed E2E specs ran fine") AND explains why CI
        coverage is sufficient for that category.
    (b) No core-flow dismissal: skipping the smoke set on a diff that touches
        the project's primary user verb is categorically NOT acceptable.
    (c) Plausible follow-up commitment (when "will fix later" appears): the
        reason names a specific TODOS.md / ROADMAP entry tracking the
        environmental fix.
    (d) No silent-broken-env skips: "the local stack is broken so I'm
        skipping" must include either an open issue tracking the env fix OR
        a concrete recipe the operator already tried.
    Default: REJECT. Generic "ran out of time" / "I'll fix later" / "low risk"
    FAIL.
```

**Verdict shape:** identical to existing check-types — single line `PASS` or
`FAIL: <what's wrong>`. Exit 0 = accepted, exit 1 = rejected.

## Tests

The devshop repo's test substrate is BATS — there is no Vitest / Playwright at
this layer. Each behavior contract above maps to one or more BATS test cases:

| BATS file                                          | Asserts                                                                                                                                                                 |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `util-path-classifier.bats`                        | `classify apps/web/components/X.tsx` → `stack-needing`                                                                                                                  |
|                                                    | `classify packages/core/src/api/y.ts` → `stack-needing`                                                                                                                 |
|                                                    | `classify packages/ui/src/Button.tsx` → `stack-needing`                                                                                                                 |
|                                                    | `classify foo.integration.test.ts` → `stack-needing`                                                                                                                    |
|                                                    | `classify apps/web/e2e/x.spec.ts` → `stack-needing`                                                                                                                     |
|                                                    | `classify supabase/migrations/001.sql` → `stack-needing`                                                                                                                |
|                                                    | `classify supabase/functions/foo/index.ts` → `stack-needing`                                                                                                            |
|                                                    | `classify README.md` → `not-stack-needing`                                                                                                                              |
|                                                    | `classify CLAUDE.md` → `not-stack-needing`                                                                                                                              |
|                                                    | `classify specs/foo/spec.md` → `not-stack-needing`                                                                                                                      |
|                                                    | `classify .github/workflows/ci.yml` → `not-stack-needing`                                                                                                               |
|                                                    | Ambiguous: `apps/web/e2e/_smoke/foo.spec.ts` → `stack-needing` (matches `apps/**`); `supabase/migrations/.gitkeep` → `stack-needing` (matches `supabase/migrations/**`) |
|                                                    | `diff-needs-stack` exits 0 when fixture diff has any stack-needing path                                                                                                 |
|                                                    | `diff-needs-stack` exits 1 on pure-docs fixture diff                                                                                                                    |
| `preship-changed-tests-local.bats`                 | `n/a` outcome on diff with no stack-needing paths                                                                                                                       |
|                                                    | parse-check failure short-circuits before execution (mock `playwright` to exit non-zero on `--list`)                                                                    |
|                                                    | changed E2E specs detected from `git diff --name-only`                                                                                                                  |
|                                                    | smoke-set glob includes `apps/web/e2e/qa-walk.spec.ts` AND `*-qa-walk.spec.ts`                                                                                          |
|                                                    | wallclock cap honored via mocked slow-running test stub (uses `timeout` builtin)                                                                                        |
|                                                    | budget-exceeded triage line `found N specs; M ran, K deferred to CI` rendered correctly                                                                                 |
|                                                    | bypass flag `devshop.localTestSkipReason` short-circuits with adversarial-review invocation                                                                             |
|                                                    | `## Dismissals` section body shape (`None` vs bulleted list)                                                                                                            |
| `util-adversarial-review-localTestSkipReason.bats` | calling `adversarial-review.sh localTestSkipReason "..."` does NOT hit the "unknown check type" branch                                                                  |
|                                                    | weak reason `"will fix later"` → reviewer FAILs (mocked `claude` returns FAIL; assert exit 1)                                                                           |
|                                                    | weak reason `"ran out of time"` → FAIL                                                                                                                                  |
|                                                    | specific reason naming category + TODOS pointer → PASS (mocked `claude` returns PASS; assert exit 0)                                                                    |
|                                                    | check-type routes to Sonnet (assert prompt prefix matches Sonnet model selection)                                                                                       |
| `preship-supabase-bootstrap-classifier.bats`       | degraded stack + stack-needing diff + unset config → `blocked` on stdout                                                                                                |
|                                                    | degraded stack + docs-only diff + unset config → existing `blocked:` (legacy shape) — orchestrator treats as advisory; assert no NEW promotion                          |
|                                                    | `requireHealthyLocalStack=never` + degraded + stack-needing → no promotion (legacy `blocked:` advisory)                                                                 |
|                                                    | `requireHealthyLocalStack=always` + degraded + docs-only → promoted to `blocked`                                                                                        |
|                                                    | `requireHealthyLocalStack=when-relevant` is identical to unset                                                                                                          |
|                                                    | healthy stack + any diff + any config → no behavior change vs today                                                                                                     |

All BATS suites use the existing `kit/tests/helpers/setup` harness (mock `$PATH`,
`create_test_repo`, mocked `claude` / `git` where needed) per the
`util-adversarial-review-narrowing.bats` and `preship-rls-coverage.bats`
templates.

## Dependencies

External / pre-existing surfaces this PR builds on. None of these are new.

- `kit/scripts/adversarial-review.sh` — surviving check-type registry,
  per-check-type model routing, prompt-rule template structure (rules 1–9
  enumerated; this PR adds rule 10).
- `kit/scripts/preship/supabase-bootstrap.sh` — three-shape reachability
  detection, `blocked:` stdout convention, `up` / `down` / `status` modes.
- `kit/scripts/preship/slow-job-lifecycle-check.sh` and
  `kit/scripts/preship/rls-coverage-check.sh` — canonical templates for an
  `(ak)` gate helper (stdout outcome shape, project-root arg, `n/a` outcomes,
  `findings (N)` shape).
- `kit/tests/test_helper.bash` and `kit/tests/helpers/setup` — BATS harness
  (mock-bin path, `create_test_repo`, fixture write helpers).
- `pnpm`, `playwright` — must be on `$PATH` when the gate runs. Already
  required by the project template; no new installation step.
- `timeout` (coreutils) — already required by existing devshop scripts; no
  new dep.
- `git config devshop.<key>` convention — already used by `dirtyPushReason`,
  `prDescStaleReason`, `testReviewSkipReason`, `humanReviewed`. New keys
  `localTestSkipReason` and `requireHealthyLocalStack` are additive.

No new external dependencies (no new npm packages, no new system tools).

## Task order

Eight tasks. Each is one logical commit. Dependencies are listed; later tasks
can be reordered only when their listed dependency is satisfied.

### Task 1 — `changed-tests-local.sh` helper + diff/spec/glob plumbing

**What:** Create `kit/scripts/preship/changed-tests-local.sh` implementing the
four-step gate body (parse-check → changed E2E → changed integration → smoke
set) with wallclock caps via `timeout`, canonical stdout contract, bypass-flag
plumbing.

**Dependencies:** none (pure new file).

**Commit shape:** `feat(preship): add changed-tests-local gate helper`

### Task 2 — Path classifier + `supabase-bootstrap.sh` integration (sub-fix 3)

**What:** Create `kit/scripts/preship/path-classifier.sh` with `classify` and
`diff-needs-stack` subcommands. Modify `supabase-bootstrap.sh up` to call
`diff-needs-stack` and `git config devshop.requireHealthyLocalStack`, applying
the D6 decision matrix.

**Dependencies:** none (path-classifier is new; bootstrap modification is
self-contained).

**Commit shape:** `feat(preship): promote degraded local Supabase to blocked on stack-needing diffs`

### Task 3 — `localTestSkipReason` adversarial-review check-type

**What:** Add `localTestSkipReason)` case to
`kit/scripts/adversarial-review.sh`. Sonnet-route. Append rule #10 to the
prompt mirroring `testReviewSkipReason`'s structure.

**Dependencies:** Task 1 (the gate body invokes the new check-type, but the
gate body's `localTestSkipReason` invocation will fall through to the
"unknown check type" branch until this task lands; commit ordering matters
here — Task 3 must merge before the gate is considered functional).

**Commit shape:** `feat(adversarial-review): add localTestSkipReason check-type`

### Task 4 — Wire new gate at #2d in `ak-pre-ship/SKILL.md`

**What:** Add row to the canonical-order table; insert
`## Gate changed-tests-local (ak)` body between `slow-job-lifecycle` (#2c)
and `Gate 3` (#3); document the bypass flag and outcome contract; reference
`changed-tests-local.sh`.

**Dependencies:** Tasks 1, 2, 3 (all three pieces must exist for the gate to
function end-to-end).

**Commit shape:** `feat(ak-pre-ship): wire changed-tests-local gate at #2d`

### Task 5 — BATS test coverage

**What:** Add the four BATS files enumerated in Tests above. Reuses the
`kit/tests/helpers/setup` harness and `MOCK_BIN` pattern.

**Dependencies:** Tasks 1, 2, 3 (the scripts under test must exist).

**Commit shape:** `test(preship): cover changed-tests-local + path-classifier + bootstrap promotion`

### Task 6 — Doc updates

**What:** `kit/docs/guide/conventions.md` (new `## Local Pre-Push Test Gates`
section + cross-ref from `## Slow-Job Lifecycle`); `kit/docs/guide/hooks.md`
(bypass-flag enumeration); `kit/docs/guide/workflow.md` (`## Pipeline at a
Glance` callout); `/devshop/CLAUDE.md` Tier-1 entry.

**Dependencies:** Task 4 (skill is the source of truth the docs reference).

**Commit shape:** `docs: document local pre-push test gates + bypass flags`

### Task 7 — Roadmap bookkeeping

**What:** Mark `kit/ROADMAP.md § Shift cheap test gates from CI-only to local
pre-push` as `[SHIPPED]` with PR link. Append three new v1 entries (sub-fix 2
stage 2, sub-fix 2 stage 3, lalista adoption) at appropriate roadmap
positions.

**Dependencies:** none for the markings themselves; conceptually Tasks 1–6
must be the substance the entry marks shipped.

**Commit shape:** `chore(roadmap): mark cheap-test-gates-local shipped + queue follow-ups`

### Task 8 (conditional) — Seed `PLAN.md` + `BUILD-LOG.md` in the devshop repo

**Decision context:**

`/ak-build § Phase 5.6` reads (line 690 of the skill body):

> If `BUILD-LOG.md` doesn't exist, copy from `/devshop/template/BUILD-LOG.md`.
> If `PLAN.md` doesn't exist, copy from `/devshop/template/PLAN.md`.

So the absence of `/devshop/PLAN.md` and `/devshop/BUILD-LOG.md` does NOT
crash 5.6 — it self-heals. The risk is more subtle (Gotcha 4): when 5.6 runs
and creates these files for the first time, the resulting commit is
docs-only, and 5.7's re-watch can interact with that fact in unexpected ways
(e.g. the docs-only commit retriggering CI without the cheap gate ever
running).

**Decision: SEED proactively in this PR.** Two rationales:

1. The dependency on Phase 5.6's self-heal is implicit. Making the files
   exist BEFORE 5.6 runs makes the commit shape cleaner (5.6 just appends
   and updates, never creates).
2. Even if Phase 5.6's self-heal works perfectly, having `PLAN.md` exist
   from the start means Task 8 is the right place to record this PR as the
   active feature — surfaced visibly to anyone reading the repo state.

**What:** Copy `/devshop/template/PLAN.md` → `/devshop/PLAN.md` and
`/devshop/template/BUILD-LOG.md` → `/devshop/BUILD-LOG.md`. Add this PR's
Active row to PLAN.md per the file's documented format.

**Dependencies:** none (file creation only).

**Commit shape:** `chore: seed devshop PLAN.md + BUILD-LOG.md`

**Risk if skipped:** Phase 5.6 self-heals; the PR still ships. But the
docs-only-first-commit edge case (Gotcha 4) becomes a real possibility, and
a future devshop-self PR runs the same gauntlet without this PR's resolution
path documented. SEED is the strictly safer choice.

## Gotchas

1. **The roadmap claim that `playwright test --list` is "already wired into
   pre-ship" is wrong.** Grep across `.claude/skills/`, `.husky/`,
   `kit/hooks/`, `template/`, and `.github/workflows/` finds zero invocations.
   The only mentions are the roadmap entry itself and one PR-checklist line in
   `.claude/skills/devshop/build/SKILL.md` referencing this future state. This
   PR adds the parse-check as Step 1 of the new gate (D2). Future readers who
   look for "where is parse-check today?" will not find it elsewhere — it
   lives only in `changed-tests-local.sh`.

2. **The new gate needs `pnpm dev` running for E2E execution.** Preflight's
   `supabase-bootstrap.sh up` already provides the Supabase stack, but the
   Next.js dev server is a separate lifecycle. Phase 1 (this spec) defers to
   Phase 2 the choice between (a) the gate body backgrounds `pnpm dev` itself
   with a wallclock-bounded `nohup` + cleanup trap, or (b) the gate body
   relies on a Playwright global-setup hook (`playwright.config.ts §
webServer`) that owns the lifecycle. Lalista's existing config already
   has `webServer: { command: 'pnpm dev', ... }` so option (b) Just Works
   when the gate uses `pnpm playwright test ...` against a config that
   declares it. Phase 2 picks one; recommended default is **option (b)** —
   delegate the lifecycle to Playwright's webServer block, which projects
   already configure for CI runs. The gate's job is then "run the right test
   subset under the project's existing config," not "manage a Next.js dev
   server."

3. **Wallclock caps via the `timeout` shell builtin.** Each step is
   `timeout <Ns> <invocation>`; on hit, exit code is 124 and the gate emits
   the "found N specs; M ran, K deferred to CI" triage line as a finding.
   `timeout` does NOT propagate signals to grandchildren by default — passing
   `timeout --kill-after=10s` ensures Playwright workers actually exit. The
   gate body must `wait` for the timeout to settle before moving to the next
   step or it can leak processes that compete for the dev server port.

4. **PLAN.md / BUILD-LOG.md absence in the devshop repo (Task 8 driver).**
   Phase 5.6 self-heals, but the docs-only-first-commit shape that 5.6
   creates can interact with 5.7's re-watch. Task 8 seeds proactively to
   defuse this. The risk is documented at line 739 of
   `.claude/skills/devshop/build/SKILL.md` ("the diff is docs-only (PLAN.md +
   BUILD-LOG.md), the new run can fail on...") — this PR is the first one to
   exercise that path on the devshop-self repo.

5. **Bypass-flag adversarial review (`localTestSkipReason`) follows the
   weak-reason rejection patterns** from `testReviewSkipReason` and
   `dismissalLog` verbatim:
   - PASS: per-category engagement + ROADMAP/TODOS pointer + no
     core-flow dismissal + no security-boundary skip.
   - FAIL: "ran out of time" / "I'll fix later" / "low risk" without
     specifics / generic "tests look fine" / claims with no per-finding
     attestation.

   The reviewer's default is REJECT; passes require explicit specificity.

6. **The smoke-set glob is convention-based, not config-driven** (D3). A
   project that doesn't follow `*-qa-walk.spec.ts` naming gets no smoke set
   from this PR; that's intentional — sub-fix 2 stage 2 is the explicit
   per-project config-file follow-up. Lalista already organically uses the
   convention (4 specs as of 2026-05-06); other projects adopt by renaming.

7. **The `apps/**`glob in D4 includes`apps/_/e2e/_`(E2E specs) — this is
intentional.** A diff that adds an E2E spec under`apps/web/e2e/`is
stack-needing because the spec is what we want to run locally. The
classifier doesn't try to be clever about distinguishing "spec that needs
stack" from "doc next to a spec"; the broad`apps/\*_`plus the more
specific`apps/web/e2e/_.spec.ts` row in D4 give the same answer for any
   spec-touching diff.

8. **`requireHealthyLocalStack` is read by `supabase-bootstrap.sh`, not by
   the new gate.** The promotion happens in preflight, before the gate runs.
   The gate's own bypass flag (`localTestSkipReason`) is independent — a
   project can have a healthy stack and still bypass the gate (e.g. for a
   deliberate slow-job-only test).

## Acceptance / rollout / rollback

### Acceptance criteria

- All four BATS suites pass (verified by `bats kit/tests/util-path-classifier.bats
kit/tests/preship-changed-tests-local.bats
kit/tests/util-adversarial-review-localTestSkipReason.bats
kit/tests/preship-supabase-bootstrap-classifier.bats`).
- Synthetic stack-needing diff + degraded local Supabase + unset
  `requireHealthyLocalStack` config → preflight emits `blocked` (NEW; not
  `pass-with-note`).
- Synthetic docs-only diff + same degraded stack → preflight does NOT emit
  the new `blocked` promotion; behavior identical to today.
- `git config devshop.localTestSkipReason "ran out of time"` against the new
  gate → adversarial review FAILs (assertion: gate emits
  `findings (1) pending` with reviewer's verdict on stdout).
- `git config devshop.localTestSkipReason "<specific per-category rationale
  - TODOS pointer>"`→ adversarial review PASSes; gate emits`pass (skipped — adversarially reviewed)`.
- Running `/ak-pre-ship` against this branch produces the new gate's report
  inline at #2d in the canonical-order table; Router Summary aggregates the
  new gate's Dismissals section.

### Rollout

- Lands on devshop main via this PR; lalista (and any other adopting project)
  picks it up automatically on next `/devshop pull` (no project-side action
  needed for the gate to start firing — convention-based smoke set requires
  no config; lalista already has the convention organically).
- First lalista PR exercising the new gate validates end-to-end (this is the
  deferred follow-up in `## Deferred follow-ups` row 3).
- No metrics changes (this PR is devshop infra, not user-facing). No
  `METRICS.md` update.

### Rollback

- **Pure devshop revert.** No migration, no data shape change, no
  project-side state created.
- **Runtime escape:** `git config devshop.requireHealthyLocalStack never`
  documented in the new `## Local Pre-Push Test Gates` section (Task 6).
  Sets preflight's promotion behavior back to legacy `pass-with-note` for
  any project that can't run a local stack at all.
- **Gate-level escape:** `git config devshop.localTestSkipReason "<reason>"`
  bypasses the new gate per-invocation (subject to adversarial review). The
  combination of these two flags lets an operator opt out of both halves of
  the change without reverting commits.
- **Hard rollback path:** revert the seven feature commits (Tasks 1–7); Task
  8 (PLAN.md + BUILD-LOG.md seed) is independent — leave it in place since
  Phase 5.6 expects them.
