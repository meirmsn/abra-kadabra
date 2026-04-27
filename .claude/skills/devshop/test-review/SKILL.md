---
name: ak-test-review
version: 1.0.0
description: |
  Review test quality with fresh eyes — no implementation context.
  Reads tests alongside the code they test and flags weak assertions,
  missing error paths, and untested auth boundaries.
  Use when asked to "review tests", "test quality check", or as part of /ak-pre-ship. (devshop)
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# Test Review

Review test quality with **fresh eyes** — read tests alongside the code they test,
with no implementation context. You are looking at this code for the first time.

Reference the testing philosophy in `kit/docs/guide/ § Shared Conventions` for principles.

## What to flag

### Weak assertions

- `toBeDefined()`, `toBeTruthy()` on return values — assert the actual expected value
- `expect(result).not.toBeNull()` — what IS the result? Assert on it.
- `expect(array.length).toBeGreaterThan(0)` — assert on specific items when possible

### Missing error/invalid input tests

- Every API wrapper needs at least one test with **invalid input** (malformed data, missing fields)
- Every API wrapper needs at least one test with **unauthorized access** (wrong user, expired token)
- Functions that can throw: is there a test for the throw path?

### Untested auth boundaries (RLS)

- Every table with RLS policies must have at least one integration test:
  authenticate as User A → create data → authenticate as User B → verify data is NOT visible
- RLS bugs are silent data leaks — mocked unit tests can never catch them

### Implementation detail tests

- Tests that mock internals and assert on internal state instead of contracts
- Tests that break when you refactor without changing behavior
- Tests coupled to specific function signatures instead of inputs → outputs

### Missing boundary conditions

- Empty inputs, single item, maximum length
- Concurrent modifications where applicable
- Off-by-one in pagination or list operations

### Shape-only assertions (must pair with user-visible output)

For every test that asserts on state shape, array length, mock-call count, or internal reducer output, verify a corresponding assertion exists on user-visible rendered output — text content (`getByText`, `toHaveTextContent`), role (`getByRole`), or accessibility attributes (`getByLabelText`, `toHaveAccessibleName`). Shape assertion without a matching DOM assertion → flag as finding.

**Escape hatch**: if the code genuinely has no user-visible output (pure-state reducer, internal data transform, utility function), a test-file comment stating the rationale (`// shape-only: pure reducer, no render path`) is sufficient to bypass. ACCEPT bypass comments that name the absence of user-visible output; REJECT generic / boilerplate bypass comments ("test simple state", "obvious from context").

Scope: only flag tests added or modified in this PR's diff. Do not re-flag grandfathered tests in untouched files. See `kit/docs/guide/conventions.md § Test Assertion Depth`.

### WebKit form-state hydration race (Playwright `mobile` project only)

Direct `page.goto('/<form-route>')` followed by immediate `fill()` + `click()` on a controlled-input form races React 18's state hydration on WebKit. The fill dispatches input events but React state may not commit before the click — submit handlers see empty state and fail validation. The submit never fires the API call. Symptom: form refuses to submit on `mobile` only; assertions like `waitForURL(/\/<next>/)` time out.

Flag any new E2E test that does:

```ts
await page.goto('/sign-in'); // or any form route on the mobile project
await page.getByLabel(...).fill(...);
await page.getByRole('button', ...).click();
await page.waitForURL(...);  // ← will time out on WebKit
```

**Recommendation**: navigate via a click chain that lets React hydrate first (e.g. `/` → "Get started" → /sign-in), or add `await page.waitForLoadState('networkidle')` after the goto. Full pattern + lalista PR 26 trace evidence in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 5`.

### Realtime test missing publication migration

If a new E2E or integration test calls `subscribeTo<X>` (or any `postgres_changes` subscription) on a table, verify a migration exists adding that table to the `supabase_realtime` publication. Without it, the subscriber connects but never receives events from other sessions — the test will time out on the assertion that the change arrived. See `kit/docs/guide/conventions.md § Realtime publication setup` + `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 4`.

### Skipped tests audit

Tests that look green in CI but quietly run nothing are worse than no test — they create false confidence. Scan the diff for skip / `.only` patterns:

- **`test.only(...)` / `describe.only(...)`** — pins the runner to that block, silently hides every other test in the file. CI passes but only ran 1/N. Always flag as **critical** — never acceptable in committed code.
- **`test.skip(true, ...)` / `describe.skip` (hard skip)** — require a grep-able pointer in the skip reason (e.g., `TODOS.md § <section> § <name>`). Run `grep -F` against `TODOS.md` to verify the pointer resolves; stale pointers (referencing sections that no longer exist) → flag as **important**. Hard skips with no pointer at all → flag as **important** (becomes invisible coverage debt).
- **`test.skip(<predicate>, '<reason>')` (conditional skip)** — verify the predicate evaluates `false` in at least one CI job that actually runs the suite. Common pitfall: `test.skip(!isLocalSupabase(), ...)` is correct only when some CI job sets `SUPABASE_URL=http://127.0.0.1:54321`. If no job satisfies the predicate, the test runs nowhere → flag as **critical**.
- **`test.skip()` with no args** — Vitest no-op block; reports as zero tests, no failure signal. Always flag as **critical**.

Quick scan command:

```bash
git diff --diff-filter=AM <base>...HEAD -- '*.spec.ts' '*.test.ts' '*.test.tsx' \
  | grep -nE '^\+.*\b(test|describe|it)\.(skip|only)\b' | grep -v '^+++'
```

For each match, report the file:line, the pattern, and (for hard skips) whether the TODO pointer in the skip reason resolves against `TODOS.md`. Lalista PR 27 is the prior art — the audit caught one stale pointer (`v0 § Carry-forward § password-reset-e2e` after the entry moved to `v1 § Verification debt`) and confirmed the conditional `!isLocalSupabase()` skips run in slow-job.

## Output format

For each finding:

```
### [file:line] — [severity: critical | important | suggestion]
**What**: [specific assertion or test that needs improvement]
**Why**: [what bug this could miss]
**Fix**: [specific improvement — show the code]
```

## Behavior

- Report findings. Do NOT auto-fix.
- Pause for review — the user or `/ak-pre-ship` decides whether to fix before continuing.
- If no findings: report "Tests look solid" and auto-advance.
