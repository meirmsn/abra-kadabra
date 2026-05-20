# Audit 3 — Tests review

**Range**: `2c076fa..HEAD` (1 commit — `fe4459a fix(closure): unwind Audit 2 findings — drop wrong tightener + complete sweeps`)
**Feature dir**: `specs/convention-housekeeping`
**Test files touched**: `kit/tests/guard-docs-coverage-project.bats` (2 assertions deleted from one BLOCK test; no new tests, no skipped tests, no `.only`, no source-code changes).

## Verification

Re-ran the bats suite directly (did not trust the operator's "30/30" claim from the commit message):

```
$ kit/tests/lib/bats-core/bin/bats kit/tests/guard-docs-coverage-project.bats
1..30
ok 1..ok 30
```

All 30 tests pass.

Verified the rationale for the revert by inspecting the underlying hook:

- `kit/scripts/commit-hooks/check-docs-coverage-project.sh:202-203` — the BLOCK message for new analytics call sites reads `"✖ BLOCKING: New analytics event call sites added without METRICS.md update: new posthog.capture(...) / Sentry.captureException(...) call site(s)"`. It does NOT include the offending file path in its output. The two deleted assertions (`assert_output --partial "apps/web/lib/foo.ts"` and `refute_output --partial "specs/foo/review.md"`) would have failed against this generic message — the tightener Audit 1 / Audit 2 introduced was asserting against a contract the hook does not implement. Revert is correct.
- Path-scope contract is still triangulated by companion tests at the **diff-input level** rather than the output level:
  - `check-docs-coverage-project.sh:157` enforces the carve-out via `git diff --cached -- ':!specs/*/review.md' ':!specs/*/tasks.md'`.
  - Test 6 (line 88) — PASS when only `specs/foo/review.md` mentions `posthog.capture`.
  - Test 7 (line 96) — PASS when only `specs/foo/tasks.md` mentions `Sentry.captureException`.
  - Test 8 (line 104) — BLOCK still fires when both prose AND a real `apps/web/lib/foo.ts` call site are staged together (the assertion now asserts only `"METRICS.md"` in output, which is the literal substring the hook emits).

## Findings

Tests look solid — no findings.

### Section A — Coverage of new behavior

No new source code or scripts in range. Test file modification subtracts assertions, doesn't add behavior. N/A.

### Section B — Test quality

- **Weak assertions**: none. The remaining `assert_output --partial "METRICS.md"` in test 8 is the load-bearing signal (the BLOCK message names METRICS.md as the missing doc) and is the strongest assertion the hook output can support.
- **Missing error / invalid input tests**: N/A (no new wrappers).
- **Untested auth boundaries**: N/A (no RLS surface).
- **Implementation detail tests**: the deletion REMOVES an implementation-detail-leaning assertion (the hook does not emit file paths; asserting on them was coupling test to a non-existent contract). Direction of change is healthy.
- **Missing boundary conditions**: none introduced.
- **Shape-only assertions**: N/A (bash output assertions, not state-shape).
- **Skipped tests audit**: `git diff --diff-filter=AM 2c076fa..HEAD -- '*.bats'` shows zero `.skip` / `.only` / `skip_if` additions.
- **WebKit hydration / realtime publication / wrapper API / runtime validation / routeWebSocket**: N/A (no Playwright, no realtime, no wrapper, no edge function in range).

### Section C — Bypass trailer audit

```
$ git log --format='%H%n%B%n---' 2c076fa..HEAD | grep -i '^Tests-Coverage-Bypass:'
(no matches)
```

Zero bypass trailers in range. N/A.

## Summary

`high=0 medium=0 low=0`
