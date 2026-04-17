---
name: ak-pre-ship
version: 3.1.0
description: |
  Quality gates before shipping. Pauses on findings, auto-advances on clean passes.
  After each code-changing gate, verifies tests still pass (stuck protocol if not).
  Does NOT ship or create a PR — use /ak-build for the full pipeline, or /ship after this.
  Runs: preflight → docs → metrics → responsive → /simplify → /ak-test-review → /review
  → /cso → /design-review → /qa → /benchmark → convention check.
  Preflight blocks if required tooling (e.g. Chromium for browser gates) is missing,
  so gates can never silently turn a missing-tool into a cheerful "skipped".
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
- Result: `pass` | `findings (N)` | `n/a (reason)` | `blocked (reason)`
- If findings were found and fixed: what was found, which commit fixed it

### Outcome semantics (important — do not conflate)

- **`pass`** — gate ran and either found no issues, or findings were fixed during the run.
- **`findings (N)`** — gate ran and surfaced N issues that still need action. Pipeline
  usually pauses here.
- **`n/a`** — gate does not apply to this PR (e.g. docs check when no docs changed,
  design-review on a non-UI PR). An expected no-op; does not indicate a problem.
- **`blocked`** — gate could NOT run because required tooling was missing or misconfigured
  (e.g. Chromium unavailable for design-review). This is a failure mode, not a no-op.
  `/ak-pre-ship` MUST report blocked gates explicitly to the caller. `/ak-build` MUST
  refuse to advance to `/ship` if any gate is blocked.

Never use `blocked` when you mean `n/a`, and never use `n/a` when the real reason is
missing tooling. The orchestrator relies on this distinction.

## Phase 0: Preflight

Before running any gate, verify the tooling this pre-ship depends on. This exists
specifically so a missing browser (or any other tool) can't silently degrade a gate
into a cheerful "skipped" result. If tooling is missing and a required gate depends
on it, the whole pre-ship aborts with a `blocked` status and a one-line fix.

### Scope detection

Decide which gates this PR actually needs, so preflight only fails on genuinely
required tooling:

```bash
git diff --name-only origin/main...HEAD > /tmp/preship-changed.txt
TOUCHES_UI=$(grep -E '^(apps/|packages/ui/|components/)' /tmp/preship-changed.txt | head -1)
```

- If `$TOUCHES_UI` is non-empty → Gates 3, 8, 9, 10 apply (browser required).
- Otherwise → those gates are `n/a`; browser preflight is advisory only.

### Tooling checks

Always (warn only — non-blocking):

- `gh auth status` — GitHub CLI authenticated.
- `[ "$(git branch --show-current)" != "main" ]` — not on main.

If `$TOUCHES_UI` (blocking if any of these fail):

```bash
# Try the Playwright-bundled Chromium first, then any system chrome
CHROMIUM=$(ls /home/node/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)
CHROMIUM=${CHROMIUM:-$(which chromium 2>/dev/null)}
CHROMIUM=${CHROMIUM:-$(which chrome 2>/dev/null)}
"$CHROMIUM" --version >/dev/null 2>&1 || BLOCK_REASON="Chromium not available"
```

If blocked:

1. Record `blocked (Chromium not available — run the fix below)` against the four
   browser gates (3, 8, 9, 10).
2. Report back to the caller immediately with a fix recipe:

   ```
   Preflight failed: Chromium cannot launch.
   Likely missing: shared libraries (libnspr4, libnss3, libatk1.0-0t64, ...).

   Fix one of:
     - Rebuild devcontainer — template Dockerfile installs these libs.
     - Or: sudo pnpm --dir apps/web exec playwright install-deps chromium

   Blocking /ak-pre-ship. Re-run after the fix.
   ```

3. Do NOT run Gates 1–11. Exit here with the `blocked` summary.

If preflight passes, proceed to Gate 1.

## Gate 1: Devshop docs check

If the PR touches `kit/` or reference docs (`kit/docs/OVERVIEW.md`, `kit/docs/guide/`):

- Verify both reference docs are in sync
- Pause if they've drifted

## Gate 2: Metrics check

If the PR touches user-facing code (components, API wrappers, edge functions):

- Verify `posthog.capture()` calls exist for events in this feature's spec
- Cross-reference against `METRICS.md`
- **Pause if missing** — don't auto-advance on a user-facing PR without metrics

## Gate 3: Responsive + theme check (UI PRs only)

- If PR doesn't touch UI files (`components/`, `app/`, `packages/ui/`) → record `n/a (no UI changes)` and skip.
- If Phase 0 preflight flagged Chromium as unavailable → this is `blocked` (not `skipped`, not `n/a`). See preflight recovery.

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

## Gate 5: /ak-test-review

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

- If PR doesn't touch UI files → `n/a (no UI changes)`.
- If Phase 0 preflight flagged Chromium as unavailable → `blocked`.

Invoke `/design-review` via Skill tool.
Visual audit with fix loop — finds issues, fixes in source, commits atomically.

**⚠ Changes code.** After this gate:

```bash
pnpm turbo run test:unit
```

If tests fail → stuck protocol (see below).

## Gate 9: /qa

- If Phase 0 preflight flagged Chromium as unavailable → `blocked`.

Invoke `/qa` via Skill tool. Browser-based QA — discovers bugs, fixes source code,
commits per bug, re-tests. Has its own internal fix loop.

Runs AFTER /design-review so it browser-tests the visually polished code. This is the
final "does this actually work in a browser" pass before /ship.

## Gate 10: /benchmark (UI PRs only)

- If PR doesn't touch UI files → `n/a (no UI changes)`.
- If Phase 0 preflight flagged Chromium as unavailable → `blocked`.

Invoke `/benchmark` via Skill tool.
Performance regression check (Core Web Vitals + load time). Report only.

## Gate 11: Convention check

Run the mechanical check first, then apply judgment:

```bash
bash kit/scripts/check-file-headers.sh main
```

Review any flagged files — skip config-like or trivial files (single export, <50 lines). Then verify:

- File headers (`// What:` / `// Why:` / `// Does NOT:`) exist on non-trivial files (>1 export or >50 lines) under `src/` or `app/`
- JSDoc on exported functions
- Every new migration file has a `-- ROLLBACK` comment block — **pause if missing**
- Backlog items appear to be in the correct file per routing guide in `kit/docs/guide/ § Shared Conventions`
- No completed items left in `PRODUCT-ROADMAP.md` or `kit/ROADMAP.md` — if this PR ships a roadmap item, remove the entry and log the completion in `BUILD-LOG.md`

## Output

After all gates complete, report the accumulated audit trail to the caller.
Do NOT ship, push, create a PR, or post comments — that's `/ak-build`'s job (or the user
runs `/ship` manually). `/ak-pre-ship` is quality gates only.

### Required summary fields

When you return to the caller, include these counts explicitly (not buried in prose):

- `passed: N` — gates that ran and passed
- `findings_pending: N` — gates with unresolved findings
- `n_a: N` — gates that did not apply
- **`blocked: N`** — gates that could not run due to missing tooling

The caller uses `blocked` as a hard signal. If `blocked > 0`, `/ak-build` must NOT
advance to `/ship`. Emit the preflight fix recipe verbatim so the user can copy it
out of the orchestrator's report.

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
