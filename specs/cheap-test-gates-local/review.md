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
