# Review — cheap-test-gates-local

<!-- audited-at: 613ce0b25356b925e5b72b89ddaa3ec0d74c5f75 -->

## Router Summary

| Gate                         | Outcome            | Dismissals | Adversarial review            |
| ---------------------------- | ------------------ | ---------- | ----------------------------- |
| `docs-check` (ak)            | findings (1) fixed | None       | skipped (scoped parse = None) |
| `metrics-check` (ak)         | n/a                | None       | skipped                       |
| `rls-coverage` (ak)          | n/a                | None       | skipped                       |
| `slow-job-lifecycle` (ak)    | n/a                | None       | skipped                       |
| `changed-tests-local` (ak)   | n/a                | None       | skipped (self-eat avoided)    |
| `responsive-theme` (ak)      | n/a                | None       | skipped                       |
| `simplify`                   | findings (1) fixed | None       | skipped                       |
| `docs-and-tests-review` (ak) | findings (1) fixed | None       | skipped                       |
| `review`                     | pass               | None       | skipped                       |
| `cso`                        | pass               | None       | skipped                       |
| `design-review`              | n/a                | None       | skipped                       |
| `design-conformance` (ak)    | n/a                | None       | skipped                       |
| `qa`                         | n/a                | None       | skipped                       |
| `benchmark`                  | n/a                | None       | skipped                       |
| `convention` (ak)            | pass               | None       | skipped                       |

**Total dismissed findings**: 0 (0 LLM-reviewed, 0 shim-mapped, 0 rejected).

## Gate 1: docs-check (ak)

**Outcome:** `findings (1) fixed`

The PR is heavy on docs (this is devshop infra; the surfaces are exclusively kit/docs/guide/ + CLAUDE.md + .claude/skills/devshop/pre-ship/SKILL.md), so this is the load-bearing gate.

### Finding (fixed)

- `kit/docs/OVERVIEW.md:103` — the "Pre-ship gate helpers" enumeration listed `router-shim, verify-story, design-conformance, supabase-bootstrap, rls-coverage-check, slow-job-lifecycle-check` but did not include the two new files this PR adds (`changed-tests-local`, `path-classifier`). OVERVIEW.md is a Tier-1 reference doc; this enumeration is the only place outside the new feature's own surfaces that names the helper inventory, so it is load-bearing for "what's on disk in preship/?" navigation. Fixed in commit `ce86bc6` by appending the two filenames to the list.

### Dismissals

None

## Gate 2: metrics-check (ak)

**Outcome:** `n/a`

Devshop has no `METRICS.md` — there is no event taxonomy here. This PR is devshop infra (gate body + classifier + adversarial-review check-type), not user-facing code, so no `posthog.capture` / `Sentry.captureException` surface to validate.

### Dismissals

None

## Gate 2b: rls-coverage (ak)

**Outcome:** `n/a (no supabase/migrations directory)`

Devshop self-repo has no Supabase. The gate's scope-detection rule fires only when the diff touches `supabase/migrations/**` or `packages/core/src/api/**`; neither applies.

### Dismissals

None

## Gate 2c: slow-job-lifecycle (ak)

**Outcome:** `n/a (no integration tests or E2E specs — Phase 1c/1g threshold not crossed)`

Devshop's CI substrate is BATS (`kit/tests/`), not Vitest integration tests + Playwright. The gate's scope rule is `find packages/ apps/ -name '*.integration.test.ts' OR find apps -path '*/e2e/*.spec.ts'` — devshop has neither directory. No analog exists.

### Dismissals

None

## Gate 2d: changed-tests-local (ak)

**Outcome:** `n/a (devshop self-repo; gate runs only on diffs that touch the project-template stack-needing globs apps/**, packages/{core,ui}/**, etc.)`

The gate this PR ships does not self-fire on the devshop repo because devshop has no `apps/` / `packages/` tree to test against. The classifier's `not-stack-needing` verdict is correct for this diff (the changes are entirely under `kit/scripts/preship/`, `kit/docs/guide/`, `kit/tests/`, `.claude/skills/devshop/pre-ship/SKILL.md`, and `CLAUDE.md` — none of which match the stack-needing globs). The gate IS exercised by its own BATS suite (`kit/tests/preship-changed-tests-local.bats`, 10 tests, all green). End-to-end validation against a real diff comes from the deferred lalista-adoption PR (spec § Deferred follow-ups row 3).

### Dismissals

None

## Gate 3: responsive-theme (ak)

**Outcome:** `n/a (devshop self-repo; no UI to capture)`

No `apps/web/`, no React, no DOM. Browser preflight is skipped per the same shape.

### Dismissals

None

## Gate 4: /simplify

**Outcome:** `findings (1) fixed`

Code-quality pass over the bash scripts and skill markdown. The bypass-flag flow + classifier + sub-fix-3 promotion are tight; the 4-step gate body in `changed-tests-local.sh` keeps each step's wallclock budget and failure path obvious.

### Finding (fixed)

- `kit/scripts/preship/changed-tests-local.sh` — four dead-code variables (`E2E_RAN_COUNT`, `E2E_DEFERRED_COUNT`, `SMOKE_RAN_COUNT`, `SMOKE_DEFERRED_COUNT`) were assigned at three points each (initialization + budget-hit + clean-pass) but never read. The triage line `found N specs; M ran, K deferred to CI` is built inline from `<TOTAL>` only. Removed in commit `613ce0b` (~7 lines collapse, no behavior change). BATS 660/660 still pass.

### Notes (not findings — judgment calls)

- `diff_needs_stack` in `changed-tests-local.sh` (lines 91–116) duplicates `path-classifier.sh diff-needs-stack` logic. The script tries the canonical helper first (line 96) and only falls through to inline classification when the helper isn't on disk. Documented as "self-contained shape" — justified resilience for a kit/devshop infra script that may run in a half-bootstrapped environment.
- `realpath --relative-to` chain at line 196–197 (E2E path translation) is convoluted (prefix-strip then fall-through to `realpath --relative-to`) but verified correct in both edge cases (root-level and nested playwright.config.ts). Readability nit, not a defect.
- 4-step gate body has structural duplication (each step: `if ! ( cd ... timeout ... cmd ); then RC=$?; case 124/other ...`). The steps differ enough in arg construction (E2E `--project=chromium --max-failures=1 --workers=1`, integration `VITEST_INTEGRATION=1`, smoke same as E2E but different file list) that DRY'ing them into a shared helper would obscure each step's wallclock budget. Acceptable.

### Dismissals

None

## Gate 5: /ak-check-docs-and-tests (Audit 1)

See `## Audit 1` below.

### Dismissals

None

## Gate 6: /review (staff-engineer)

**Outcome:** `pass`

Staff-engineer mindset diff review across the 16 files. No structural / SQL safety / LLM trust-boundary / conditional-side-effect issues.

### Notes

- `emit_degraded_outcome` in `supabase-bootstrap.sh` matches D6 decision matrix exactly. Fail-safe paths (classifier missing → `blocked`; git error → `blocked`) chosen correctly: better strict-when-can't-decide than lax.
- The `when-relevant|*)` catch-all in the case statement maps any unknown config value to default behavior. Forward-compatible but masks typos. Acceptable trade-off — the bats `D6 decision matrix` coverage exercises every documented value.
- `adversarial-review.sh` localTestSkipReason addition mirrors `testReviewSkipReason`'s structure exactly: same Sonnet routing, same prompt template shape, rule #10 mirrors rule #7. Unknown-check-type fall-through enumeration updated.
- `(cd "$PROJECT_ROOT" 2>/dev/null && git config ...)` subshell pattern is correct under `set -euo pipefail` thanks to the `|| true` tail.
- No new shelling-out / writes / network surfaces introduced beyond what existed.

### Dismissals

None

## Gate 7: /cso (security)

**Outcome:** `pass`

Security review of the new bypass-flag flow + classifier + adversarial-review check-type.

### Notes

- `localTestSkipReason` is read via `git config --get` (no exec, no eval) and passed quoted to `bash adversarial-review.sh localTestSkipReason "$SKIP_REASON"`. The reason flows into `claude` CLI as a prompt template variable; no shell expansion path. Default REJECT semantics on rule #10 mirror existing pattern.
- `requireHealthyLocalStack` defaults to `when-relevant` (the strict path: hard-block on stack-needing diffs). Fail-safe.
- `LOCAL_TESTS_BASE_REF` env override is passed quoted as a positional arg to `path-classifier.sh diff-needs-stack`, which then quotes it again into `git diff "$base"...HEAD`. No injection surface.
- `PATH_CLASSIFIER_SCRIPT` env override exists for tests; production callers don't set it. An attacker who could already set env vars on a developer's box could redirect to a malicious script — same threat surface the existing `ADVERSARIAL_REVIEW_SH` / `claude` CLI overrides have.
- No new credential surfaces, no new network calls, no new file writes outside `/tmp` (test fixtures only).

### Dismissals

None

## Gate 8: /design-review

**Outcome:** `n/a (devshop self-repo; no UI)`

### Dismissals

None

## Gate 8b: /ak-design-conformance

**Outcome:** `n/a (no DESIGN.md at devshop repo root)`

### Dismissals

None

## Gate 9: /qa

**Outcome:** `n/a (devshop self-repo; no user-facing dev server to walk)`

The devshop has no app, no `pnpm dev`, no Playwright fixture set. The gate's user-flow walk against a localhost dev server has no analog here. Validation of the new gate's behavior is provided by the BATS suite (`preship-changed-tests-local.bats` × 10 tests) + the deferred lalista-adoption PR (spec § Deferred follow-ups row 3) which exercises end-to-end against a real diff.

### Dismissals

None

## Gate 10: /benchmark

**Outcome:** `n/a (devshop self-repo; no UI)`

### Dismissals

None

## Gate 11: convention check (ak)

**Outcome:** `pass`

Convention header check (`bash kit/scripts/commit-hooks/check-file-headers.sh main`) returns exit 0 against the diff. Both new scripts (`changed-tests-local.sh`, `path-classifier.sh`) have the canonical `What:` / `Why:` / `Does NOT:` block at the top. New BATS files have descriptive header comments. Hooks-coverage doc enumeration includes `localTestSkipReason` (3 mentions in `kit/docs/guide/hooks.md`).

No new migration files (rollback-comment + ON-DELETE-clause sub-checks are vacuously satisfied). No new `subscribeTo<X>` helpers (publication-migration sub-check vacuously satisfied). No completed roadmap items left in `kit/ROADMAP.md` — the source roadmap entry for this PR is marked `[SHIPPED 2026-05-06 — feature/cheap-test-gates-local]` per Task 7.

### Dismissals

None

---

## Audit 1: pre-polish (2026-05-07)

<!-- audited-at: 613ce0b25356b925e5b72b89ddaa3ec0d74c5f75 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=1

### Docs findings

- [low] kit/docs/guide/conventions.md:215 — bypass-flag bash example contained duplicate `git` token: `git -c devshop.localTestSkipReason="..." \ git push`. Adequacy nit — pasted example wouldn't run as written, and `git push` was misleading because `localTestSkipReason` is read by the /ak-pre-ship gate body itself, not by `git push`'s pre-push hook chain. Fixed in this audit pass: replaced with `git config devshop.localTestSkipReason "<why>"` set + `--unset` clear recipe; named /ak-pre-ship as the invocation site explicitly.

### Tests findings

- (none) — Tests look solid. Coverage matrix verified:
  - `kit/scripts/adversarial-review.sh` (added `localTestSkipReason`) → `kit/tests/util-adversarial-review-localTestSkipReason.bats` (13 tests).
  - `kit/scripts/preship/changed-tests-local.sh` (NEW) → `kit/tests/preship-changed-tests-local.bats` (10 tests).
  - `kit/scripts/preship/path-classifier.sh` (NEW) → `kit/tests/util-path-classifier.bats` (25 tests).
  - `kit/scripts/preship/supabase-bootstrap.sh` (extended) → `kit/tests/preship-supabase-bootstrap-classifier.bats` (14 tests; full D6 matrix).
    Section B: no `test.only` / weak skips; mocks consistent with `util-adversarial-review-narrowing.bats` template; assertions check actual stdout content + exit codes, not shape-only.

### Bypass trailer audit

- 613ce0b `Docs-Coverage-Bypass:` — VERIFIED. Bypass body cites a "zero hits across all 13 reference docs" attestation for the four removed counter variables. Re-grep across `CLAUDE.md`, `kit/docs/OVERVIEW.md`, `README.md`, `kit/docs/FAQ.md`, and all `kit/docs/guide/*.md` returns 0 matches for `E2E_RAN_COUNT|E2E_DEFERRED_COUNT|SMOKE_RAN_COUNT|SMOKE_DEFERRED_COUNT`. Bypass attestation accurate; trailer load-bearing for a pure dead-code refactor where no doc edit is warranted.
- (no `Tests-Coverage-Bypass:` trailers in range — Layer 1 tests-coverage-devshop hook fired on each of Tasks 1, 2, 3 and was satisfied by paired bats in the same commit.)

---

## Audit 2: post-polish (2026-05-06)

<!-- audited-at: 98082c2a73c1289b004c4ec4e152aa4cf493cd58 -->
<!-- range: 613ce0b25356b925e5b72b89ddaa3ec0d74c5f75..98082c2a73c1289b004c4ec4e152aa4cf493cd58 -->

findings: high=0 medium=2 low=0

Three commits in range, all docs/bookkeeping (zero source files, zero test files touched):

- `320e86d` chore(cheap-test-gates-local): record /ak-pre-ship Audit 1 + fix bypass example
- `3b8937d` docs: bump quality-gate count from 14 to 15 (changed-tests-local at #2d)
- `98082c2` chore(build-log): record cheap-test-gates-local

### Docs findings

- [medium] kit/docs/guide/workflow.md:58 + kit/docs/guide/workflow.md:377 — two stale "14 gates" references not updated by the /document-release commit (3b8937d). Line 58 is the Phase 3 ASCII pipeline diagram (`Phase 3 · /ak-pre-ship  (14 gates, re-run tests after each)`); line 377 is the skill-summary table row for `/ak-pre-ship` (`Quality gates only (14 gates incl. rls-coverage, slow-job-lifecycle, design-conformance).`). Both contradict line 187 in the same file (correctly bumped to "15 gates" by 3b8937d) and `README.md:33` (correctly "15 quality gates"). Canonical source `pre-ship/SKILL.md § Gates (canonical order + named IDs)` enumerates 15 rows. Fix: bump both to "15 gates"; in the line-377 row, update the parenthetical to enumerate the new gate (e.g. `Quality gates only (15 gates incl. changed-tests-local, rls-coverage, slow-job-lifecycle, design-conformance).`). Verified by `grep -rnE "14 (gate|quality)" --include="*.md"` from repo root.
- [medium] kit/ROADMAP.md:1710 — the surviving stage-2 entry's preamble ("The shipped feature (sub-fix 2 stage 1) implements the convention-based smoke-set floor only…") references the "sub-fix 2 stage 1" enumeration that was defined only in the just-deleted v1 entry. After the deletion, the reader has to reconstruct the enumeration from context. The stage-3 entry on line 1738 was rewritten on the same axis ("The shipped `changed-tests-local` gate catches this only when…", per commit 98082c2's message: "Cross-reference at the import-graph follow-up rewritten in imperative present tense"); the stage-2 entry was not given the same treatment. Asymmetric. Fix: rewrite the stage-2 preamble to use the shipped-gate name directly, e.g. `The shipped 'changed-tests-local' gate implements the convention-based smoke-set floor only (apps/web/e2e/*-qa-walk.spec.ts ∪ apps/web/e2e/qa-walk.spec.ts).` Severity medium because it's the explicit symmetry counterpart to a fix the commit message claims was made; closing this asymmetry keeps the audit-trail self-consistent.

### Tests findings

- (none) — zero source files (`.sh`, `.ts`, `.tsx`) and zero test files (`.bats`, `.test.ts`, `.spec.ts`) touched in range. The shipped behavior's coverage matrix was verified in Audit 1 (commit ranges before 613ce0b); nothing in this range modifies it. All Section B sub-sections (weak assertions, missing error/invalid input, RLS auth boundaries, implementation detail tests, missing boundary conditions, shape-only assertions, WebKit hydration race, realtime publication, wrapper API design, runtime validation at LLM boundaries, skipped tests audit) are vacuously satisfied — no diff-staged tests to scan.

### Bypass trailer audit

- (none) — `git log --format='%B' 613ce0b..98082c2 | grep -E '^(Tests|Docs)-Coverage-Bypass:'` returns zero rows. No bypass trailers in range — nothing to verify.

### Summary

`findings: high=0 medium=2 low=0` — both medium findings are intra-doc consistency adequacy nits in the docs domain. No high-severity issues. Phase 6 surfaces them in the audit comment per /ak-build § Phase 5.8.4. Tests are solid (zero test changes in range; Audit 1's coverage matrix unaffected).
