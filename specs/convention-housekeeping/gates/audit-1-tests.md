# Audit 1 — Tests Review

**Range**: `origin/main..HEAD` (4 commits)
**Feature dir**: `specs/convention-housekeeping`

## Scope summary

Code surfaces in range:

- `kit/scripts/commit-hooks/check-docs-coverage-project.sh` — hook diff: scope the `git diff --cached` invocation to exclude `specs/*/review.md` + `specs/*/tasks.md` so analytics-function names mentioned in audit prose don't fire the `METRICS.md must be staged` block (commit `00e155f`).
- `kit/scripts/preship/migration-rollback-roundtrip.sh` — mode-only change (0644 → 0755). No behavior diff.
- `kit/tests/guard-docs-coverage-project.bats` — 3 new tests covering the exemption (commit `00e155f`).
- `kit/tests/structural-invariants.bats` — test-internal refactor revert: re-pin the `kit/scripts/*.sh` mode scan to the canonical `$DEVSHOP` tree instead of the per-worktree `git rev-parse --show-toplevel`. No source diff; test-only.
- `kit/tests/template-compose-isolation.bats` — test-internal revert: relax the firewall-port assertions back to literal `54321` / `54322` matches instead of the env-var-quoted form. No source diff; test-only.

All other files in the range are documentation (`*.md`), tracker (`PLAN.md`, `kit/TODOS.md`, `kit/ROADMAP.md`, `kit/docs/CHANGELOG.md`, `kit/docs/guide/conventions.md`, `kit/docs/guide/database-queries.md`, `template/CLAUDE.md`, `template/PRODUCT-ROADMAP.md`, `specs/prerelease-bats-gaps/**`), or version (`kit/version`) — no test obligation.

## Section A — Coverage of new behavior

The hook diff introduces one new exemption path (`specs/*/review.md` + `specs/*/tasks.md` excluded from the analytics-event diff scan) and preserves the negative case (a real call site in `apps/`, `packages/`, or `supabase/functions/` still fires).

`kit/tests/guard-docs-coverage-project.bats` adds three tests that cover the exact new behavior:

1. **PASS exemption — `review.md`**: stages `specs/foo/review.md` containing `posthog.capture()` in audit prose, asserts the script exits clean.
2. **PASS exemption — `tasks.md`**: stages `specs/foo/tasks.md` containing `Sentry.captureException` in descriptive prose, asserts the script exits clean.
3. **BLOCK negative case**: stages BOTH `specs/foo/review.md` (matching prose) AND `apps/web/lib/foo.ts` (real call site). Asserts the script blocks AND output mentions `METRICS.md` — proving the exemption is path-scoped, not content-scoped (a broad-text exemption would let the real call site through, which this test would catch).

The hook's other code paths (page/route triggers, OVERVIEW.md / ARCHITECTURE.md opt-ins, per-package READMEs, stale-reference scan, devshop-self early exit, override file, bypass flag) are unchanged in this range and remain covered by the pre-existing 27 tests in the file.

`structural-invariants.bats` and `template-compose-isolation.bats` are test-only edits that revert prior test refactors — no source behavior is gained or lost in the range that demands new coverage. The reverts retighten existing assertions (template-compose-isolation goes back to literal `54321` / `54322` port matches; structural-invariants goes back to scanning the canonical `$DEVSHOP` tree). Both are valid test-internal hygiene; Section A does not apply.

No coverage gaps in Section A.

## Section B — Test quality

The new bats tests use direct outcome assertions (`assert_success`, `assert_failure`, `assert_output --partial "METRICS.md"`) — no weak `toBeDefined`-style patterns. The bats harness's `run`/`assert_*` pair is the right grain for guard scripts (exit code + stderr substring are the actual contract).

The negative-case test (BLOCK with both prose and real call site staged) is the load-bearing assertion that makes the exemption safe — it verifies the change didn't widen the exempt set to "any commit that touches `specs/`". This is exactly the boundary test the diff demands.

One low-severity tightening opportunity (see findings).

No skipped tests, no `.only` / `.skip` patterns, no Playwright E2E patterns, no realtime / WebSocket / wrapper / LLM-edge-function surfaces are touched in the range.

## Section C — Bypass trailer audit

Harvest:

```
git log --format='%H%n%B%n---' origin/main..HEAD \
  | grep -E '(Tests-Coverage-Bypass|Docs-Coverage-Bypass):'
```

No real `Tests-Coverage-Bypass:` trailers in the range. (One incidental string match appears in commit `e0d5adc`'s body as prose describing the bypass-trailer machinery — not a trailer itself.) Per the skill's forward-compatibility note: zero rows is legitimate.

---

## Findings

### [domain: tests] [section: B] [severity: low]

**File**: `kit/tests/guard-docs-coverage-project.bats:104-113`
**What**: The BLOCK negative-case test (`actual call site in apps/ still fires when matching prose also exists in specs/`) asserts `assert_output --partial "METRICS.md"` but does not pin which staged path the hook cites as the trigger. If a future regression in `check-docs-coverage-project.sh` reported the failure against the prose path (`specs/foo/review.md`) instead of the real call site (`apps/web/lib/foo.ts`), the test would still pass because both staged files produce `METRICS.md` in the failure message.
**Why**: The test catches the obvious regression (broad-exempt would flip `assert_failure` to a passing `assert_success`), so the load-bearing assertion holds. But it under-specifies the contract: the exemption is "exclude prose paths from the diff scan, but report failures against the real source files," and the test doesn't pin the second half of that contract. A subtle regression that re-scanned the prose path AND cited it as the trigger would still satisfy the current assertion.
**Fix**: Add a one-line tightener after the existing `assert_output --partial "METRICS.md"`:

```bash
assert_output --partial "apps/web/lib/foo.ts"
refute_output --partial "specs/foo/review.md"
```

This pins both halves of the contract — exemption is path-scoped AND the failure cites the actual call site.

---

## Counts

- high: 0
- medium: 0
- low: 1
