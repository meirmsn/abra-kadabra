---
name: ak-tests-review
version: 2.0.0
description: |
  Coverage + quality audit of tests in a commit range. Audit-time
  companion to /ak-docs-review. Invoked by /ak-check-docs-and-tests
  orchestrator (or directly when /ak-build Phase 5.8 fires).
  Use when asked to "audit tests", "tests review", or as part of
  /ak-check-docs-and-tests. (devshop)
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Tests Review

Fresh-eyes audit of test coverage and test quality across a commit range. Read tests alongside the code they test, with no implementation context — you are looking at this code for the first time. Findings are scoped to the range supplied by the orchestrator (typically `origin/main..HEAD` or `<pre-ship-sha>..HEAD`), so the same skill judges both pre-ship snapshots and post-ship follow-up commits.

Audit-time companion to `/ak-docs-review`. Invoked by the `/ak-check-docs-and-tests` orchestrator (which also handles output-file routing, Audit N numbering, and halt-on-high decisions); may also be invoked directly when `/ak-build` Phase 5.8 fires. Reference the testing philosophy in `kit/docs/guide/ § Shared Conventions` for principles.

## Inputs

- `$RANGE` — commit range to audit (e.g. `origin/main..HEAD`).
- `$FEATURE_DIR` — `specs/<feature>/` for emitting findings.

## Section A — Coverage of new behavior

For each source change in the diff range, verify a corresponding test exercises the **new behavior** — not just file pairing. A test file that exists alongside the source is necessary but not sufficient; the test must actually cover the new code path / new assertion / new failure mode introduced by the diff.

Rubric (project-side):

- New API wrapper in `packages/core/src/api/` → test for happy path AND invalid input AND unauthorized access (RLS where applicable)
- New `page.tsx` / `route.ts` → e2e spec exercising the primary verb
- New RPC function (`SECURITY DEFINER`) → integration test
- New edge function endpoint → integration test against deployed function OR slow-job e2e
- New `posthog.capture` / `Sentry.captureException` call site → trace assertion in an existing test (NOT a separate test, NOT shape-only)
- New realtime subscription wrapper → cross-session E2E + publication migration assertion

Rubric (devshop-side):

- New `kit/scripts/**.sh` → matching `.bats` spec under `kit/tests/`
- New `kit/scripts/preship/**.sh` → matching `guard-` or `util-` bats spec
- New `.claude/skills/devshop/**/SKILL.md` → either `util-<skill>.bats` (smoke) or proven-by an existing build/preship `.bats`
- New `kit/hooks/**` → `guard-` bats coverage

For each missing pair, flag with section tag = `[section: A]`.

## Section B — Test quality

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
- See `kit/docs/guide/conventions.md § Non-Negotiables — Testing` for the three-layer testing model + auth-boundary requirement and `§ QA-backend isolation` (`kit/notes/roadmap/qa-options.md`) for which Supabase flavor each layer points at.

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

### Wrapper API design — lifecycle events not just data

When a PR adds a new wrapper in `packages/core/src/api/**` (or equivalent) around an event-emitter-style library — supabase-js channel, EventEmitter, MQTT client, SSE, raw WebSocket — the wrapper must expose lifecycle / error events, not only the data event. Wrappers that swallow status callbacks force consumers into try/catch-only error handling, which only catches synchronous-construction failures. The dominant failure mode in production (`'CHANNEL_ERROR'` / `'TIMED_OUT'` async paths) silently no-ops UX that should react.

Quick scan command:

```bash
git diff --diff-filter=AM <base>...HEAD -- 'packages/core/src/api/*.ts' \
  | grep -nE '^\+.*\.(subscribe|on|addEventListener)\(' | grep -v '^+++'
```

For each match, locate the enclosing exported function (the wrapper). If the wrapper's signature doesn't accept an `onError`-shaped parameter (or `onStatus`, `onLifecycle`, etc. — any escape hatch for non-data events), flag as **critical**:

```
### packages/core/src/api/<wrapper>.ts:<line> — critical
**What**: wrapper calls `.subscribe(...)` / `.on(...)` but exposes only the data callback to consumers.
**Why**: async lifecycle events (e.g. supabase-js's `'CHANNEL_ERROR'`, `'TIMED_OUT'`) cannot reach consumer code. UX surfaces depending on these events (sync banners, error toasts) silently no-op in production.
**Fix**: extend the signature with an optional `onError?` (or `onStatus?`) parameter and wire it to the underlying status callback. See `kit/docs/guide/wrapper-boundaries.md § Wrapper API design` for the worked example.
```

Two false-positive escape hatches accepted at review time:

1. **Intentional fire-and-forget** (e.g. a "best-effort" wrapper that genuinely doesn't surface errors). A code comment naming this intent satisfies the bypass: `// fire-and-forget: errors logged, not surfaced`.
2. **Already exposed via a different shape** (wrapper returns a Promise that rejects on error, or yields events through an async iterator). Verify the alternative path actually surfaces lifecycle events before accepting the bypass.

Lalista PR 27 is the prior art — `subscribeToList(client, householdId, callback)` was extended to `subscribeToList(client, householdId, callback, onError?)` after the E2E test caught silent no-op of the sync-error banner. The test caught it because Pattern 6's `routeWebSocket` triggered `'CHANNEL_ERROR'` deterministically; the wrapper had been swallowing it.

### Runtime validation at LLM / edge-function boundaries

When a PR adds a wrapper in `packages/core/src/api/**` around `client.functions.invoke<T>(...)` or a `fetch(...).then(r => r.json()) as T` returning a hand-written response shape (LLM-backed edge function, third-party HTTP API with hand-written contract), the wrapper MUST parse with Zod at the boundary. TypeScript generics and `as`-casts are compile-time assertions only; a prompt edit, model swap, or function refactor changes the shape silently, surfacing as `response.foo.bar is undefined` deep in the call site instead of a clear "boundary returned unexpected shape" error at the seam.

Quick scan command:

```bash
git diff --diff-filter=AM <base>...HEAD -- 'packages/core/src/api/*.ts' \
  | grep -nE '^\+.*(\.functions\.invoke<|\.json\(\) as )' | grep -v '^+++'
```

For each match, verify the wrapper:

- Imports a schema from `packages/core/src/schemas/<feature>.ts`.
- Uses `.safeParse()` (never `.parse()` — the thrown-exception form skips the observability hook below).
- Throws a feature-named error class (`{Feature}ValidationError`) on validation failure.
- Captures to Sentry with `extra: { issues, raw_excerpt: scrubExcerpt(data) }` **before** throwing.

If any are missing, flag as **critical**:

```
### packages/core/src/api/<wrapper>.ts:<line> — critical
**What**: wrapper invokes an LLM-backed edge function (or hand-written-shape fetch) but doesn't parse the response with Zod.
**Why**: TypeScript generics + `as`-cast are compile-time only. A prompt tweak / model swap / function refactor changes the shape silently; bugs surface deep in the call site, not at the seam.
**Fix**: add a schema to `packages/core/src/schemas/<feature>.ts` (use `.passthrough()` so server-side additions don't break old clients), parse with `.safeParse()`, throw `{Feature}ValidationError`, capture to Sentry with a scrubbed payload excerpt before throwing. See `kit/docs/guide/wrapper-boundaries.md § Runtime Validation at LLM / Edge-Function Boundaries` for the full pattern + worked example.
```

Acceptable bypasses (don't flag):

- **PostgREST results** — `client.from('<table>').select(...)`. CI type-drift check enforces shape against schema; Zod here is paranoia.
- **App-internal calls** — TypeScript already proves the shape; bundle weight without ROI.
- **Form input** — HTML5 attributes + platform validation cover this layer.

When a wrapper genuinely returns `unknown` / `Record<string, unknown>` and pushes parsing to the caller (rare; generic proxies, transitional shims), require a code comment naming why so the bypass survives review. Lalista PR 6 (`packages/core/src/api/add-item.ts`) is the canonical first-adopter — `invokeAddItem` parses with `AddItemResponseSchema.safeParse()` and throws `AddItemValidationError` on failure.

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

## Section C — Bypass trailer audit

For each `Tests-Coverage-Bypass:` trailer harvested from the range, judge the bypass given the full diff context.

Harvest one-liner:

```bash
git log --format='%H%n%B%n---' "$RANGE" | \
  awk '/^Tests-Coverage-Bypass:/{print prev_sha, $0}/^[a-f0-9]{40}$/{prev_sha=$0}'
```

Three outcomes:

- **VERIFIED** — bypass was load-bearing AND remains valid given current diff.
- **DEFER** — bypass remains pending (e.g., test deferred to follow-up PR).
- **ESCALATE** — bypass was load-bearing at the time but the diff has shifted such that it would no longer be valid. Promote to medium or high.

The bypass trailer mechanic itself activates in PR-C; for now, this section may legitimately harvest zero rows. The prompt is forward-compatible.

## Output format

For each finding:

### [domain: tests] [section: A|B|C] [severity: high|medium|low]

**File**: `<path>:<line>`
**What**: <specific assertion or test that needs improvement>
**Why**: <what bug this could miss>
**Fix**: <specific improvement — show the code if relevant>

If 0/0/0 findings: "Tests look solid — no findings."

## Severity rules

- `high` → halt audit. Operator must fix before ship.
- `medium` → surface in Phase 6 audit comment.
- `low` → noted in `review.md`, not surfaced elsewhere.

## Behavior

- Report findings; do NOT auto-fix.
- Pause for review — orchestrator decides halt-or-continue based on highs.
- If no findings: report "Tests look solid" and auto-advance.
