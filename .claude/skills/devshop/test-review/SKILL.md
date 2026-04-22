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
