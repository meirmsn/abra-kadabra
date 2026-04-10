---
name: pre-ship
version: 3.0.0
description: |
  Quality gates before shipping. Pauses on findings, auto-advances on clean passes.
  After each code-changing gate, verifies tests still pass (stuck protocol if not).
  Does NOT ship or create a PR — use /build for the full pipeline, or /ship after this.
  Runs: docs → metrics → responsive → /simplify → /test-review → /review → /cso →
  /design-review → /qa → /benchmark → convention check.
  Use when asked to "pre-ship", "quality check", or "check before shipping". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - Agent
  - AskUserQuestion
---

# Pre-Ship

Chain quality gates before shipping. Pause on findings; auto-advance on clean passes.

**Key principle**: after every gate that changes code, verify tests still pass before
moving to the next gate. If tests fail, use the stuck protocol (see bottom of this file).

## Audit trail

As you run each gate, accumulate results in memory. You'll need them for the PR comment
at the end. For each gate, record:

- Gate name
- Result: `pass` | `findings (N)` | `skipped (reason)`
- If findings were found and fixed: what was found, which commit fixed it

## Gate 1: Devshop docs check

If the PR touches `.devshop/` or reference docs (`.devshop/README.md`, `.devshop/GUIDE.md`):

- Verify both reference docs are in sync
- Pause if they've drifted

## Gate 2: Metrics check

If the PR touches user-facing code (components, API wrappers, edge functions):

- Verify `posthog.capture()` calls exist for events in this feature's spec
- Cross-reference against `METRICS.md`
- **Pause if missing** — don't auto-advance on a user-facing PR without metrics

## Gate 3: Responsive + theme check (UI PRs only)

Skip if PR doesn't touch UI files (`components/`, `app/`, `packages/ui/`).

Verify the app at 4 combos:

- 375px light, 375px dark, 1440px light, 1440px dark

Check for:

- Overflow/scroll issues
- Unreadable text
- Untappable buttons (min 44px touch target)
- Hardcoded colors not using theme tokens
- Broken layouts

**Pause if any issues found.**

## Gate 4: /simplify

Invoke `/simplify` via Skill tool. Code quality pass (reuse, efficiency, dead code).

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 5: /test-review

Invoke `/devshop:test-review` via Skill tool. Test quality review with fresh eyes.
Report only — does not change code.

## Gate 6: /review

Invoke `/review` via Skill tool. Staff engineer code review.

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 7: /cso

Invoke `/cso` via Skill tool. Security audit. Reports findings, pauses for user to decide fixes.

**⚠ May change code** (user-directed fixes). After any fixes:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 8: /design-review (UI PRs only)

Skip if PR doesn't touch UI files. Invoke `/design-review` via Skill tool.
Visual audit with fix loop — finds issues, fixes in source, commits atomically.

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 9: /qa

Invoke `/qa` via Skill tool. Browser-based QA — discovers bugs, fixes source code,
commits per bug, re-tests. Has its own internal fix loop.

Runs AFTER /design-review so it browser-tests the visually polished code. This is the
final "does this actually work in a browser" pass before /ship.

## Gate 10: /benchmark (UI PRs only)

Skip if PR doesn't touch UI files. Invoke `/benchmark` via Skill tool.
Performance regression check (Core Web Vitals + load time). Report only.

## Gate 11: Convention check

Verify:

- File headers (`// What:` / `// Why:` / `// Does NOT:`) exist on non-trivial files (>1 export or >50 lines) under `src/` or `app/`
- JSDoc on exported functions
- Every new migration file has a `-- ROLLBACK` comment block — **pause if missing**
- Backlog items appear to be in the correct file per routing guide in `.devshop/GUIDE.md § Shared Conventions`

## Output

After all gates complete, report the accumulated audit trail to the caller.
Do NOT ship, push, create a PR, or post comments — that's `/build`'s job (or the user
runs `/ship` manually). `/pre-ship` is quality gates only.

## Stuck protocol (for test failures between gates)

When `pnpm turbo run test:unit` fails after a code-changing gate:

1. **Attempt 1–2**: read the error, identify which gate's change caused it, fix, rerun
2. **Attempt 3** (same error): invoke `/investigate` via Skill tool — wait for root-cause analysis
3. **Still stuck**: stop, ping user with: which gate caused the regression, the error, what was tried

## Behavior

After each gate:

- **Findings**: pause, show findings, wait for resolution before proceeding
- **Clean pass**: auto-advance to next gate (don't show six green checkmarks)
- **User can skip**: if asked to skip a gate, skip it and note in the audit trail
