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

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to create/modify,
     API/behavior contracts, Tests, Dependencies, Task order, Gotchas,
     Acceptance / rollout / rollback. The Decisions and Deferred follow-ups
     sections above stay verbatim. -->
