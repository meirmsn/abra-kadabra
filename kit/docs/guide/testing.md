# Testing patterns

Canonical test-shape patterns that aren't tied to a specific stack surface. For Supabase + Next.js + Playwright scaffold patterns (env-var hygiene, CSP/WS, E2E helpers, realtime publication, WebKit form-state, realtime WS-failure), see `kit/docs/guide/supabase-ssr-boilerplate.md`. For the broader convention layer (test presence, slow-job lifecycle, doc coverage), see `kit/docs/guide/conventions.md`.

Each pattern below was codified from a real project incident. Don't paraphrase the recipe; copy it and adapt the project-specific names. The behaviors they encode are subtle — the wrong shape passes locally and fails (or drifts past CI's wall-clock budget) in subtle, intermittent ways.

---

## Pattern 1: Tier A2 retry-budget tests use `page.clock.fastForward()`, not bumped per-test timeouts

**Why:** Tier A2 surfaces (`useOptimisticMutation({ failureMode: 'banner' })` per the latency-feedback framework) retry on a backoff schedule. Lalista's `RETRY_BACKOFF_MS = [1000, 3000, 7000]` totals 11 seconds of wall-clock backoff before the failure banner fires. A Playwright spec that exercises the full retry sequence — sign-in flow → trigger optimistic mutation → abort RTT → wait for backoff → assert banner — runs ~15-20s wall-clock once you add fixture overhead. That blows past Playwright's default 30s `test` timeout the first time you also add a second assertion or a slower CI runner.

The **wrong** workaround is to bump the timeouts: `test.setTimeout(60000)` + `await expect(banner).toBeVisible({ timeout: 25000 })`. It works, but it bakes the backoff intervals into the test wall-clock, slows every retry-budget spec by ~10-15s, makes flake-on-slow-runner more likely (the 11s budget can stretch to 14s on a noisy CI), and hides the real shape from the next reader (a 25s `toBeVisible` looks like a flake patch, not a deliberate retry assertion).

The **right** API is `page.clock.install()` + `page.clock.fastForward()` (Playwright 1.45+). Install fake time before the test triggers the mutation, fast-forward past the backoff schedule, and assert the banner at fake-time-end. The test runs in <2s wall-clock, the retry intervals are visible in the test source as the literal `fastForward` argument, and the spec is robust to runner-speed noise.

Lalista's `apps/web/e2e/add-item-banner.spec.ts` is the **don't-do-this** prior art: shipped with `test.setTimeout(60000)` + `await expect(bannerLabel).toBeVisible({ timeout: 25000 })` because the `page.clock` API hadn't been adopted in the spec yet. The spec passes, but every Tier A2 surface that follows the same shape will rediscover the timeout-bumping workaround instead of the right answer.

### The pattern

```ts
import { test, expect } from '@playwright/test';

test('failure banner renders after retry budget exhausts', async ({ page }) => {
  // Install fake time BEFORE triggering anything timer-driven.
  await page.clock.install();

  // Fault-inject the underlying RPC / edge-function so the optimistic
  // mutation always fails, forcing the hook through the full retry schedule.
  await page.route('**/functions/v1/add-item', (route) => route.abort());

  await page.goto('/list');
  await page.getByRole('button', { name: /add/i }).click();
  await page.getByRole('textbox').fill('milk');
  await page.getByRole('button', { name: /^add$/i }).click();

  // RETRY_BACKOFF_MS = [1000, 3000, 7000] → 11s of fake-time backoff.
  // Fast-forward past the schedule + a small buffer for the post-budget tick.
  await page.clock.fastForward('00:12');

  const banner = page.getByRole('alert').filter({ hasText: /couldn't add/i });
  await expect(banner).toBeVisible(); // no { timeout: 25000 } needed
  await expect(page.getByRole('button', { name: /^retry$/i })).toBeVisible();
  await expect(page.getByRole('button', { name: /^undo$/i })).toBeVisible();
});
```

### Prereqs

1. **Playwright ≥ 1.45** — `page.clock` was added in 1.45. Check `apps/web/package.json`'s `@playwright/test` pin and bump if needed. (Lalista is on 1.55; verify on each new project.)
2. **`clock.install()` happens before the timer-driven code path executes** — install fake time before navigation if the page itself sets timers on load, or after navigation but before the action that triggers the retry hook. The wrong order gives you a real-clock retry against a fake-clock assertion.
3. **Sign-in / setup that uses `setTimeout` for redirects** — fake time also freezes those. Either install the clock AFTER sign-in completes, OR `fastForward` past the redirect timer too. The cleanest shape is "do all real-time setup first, then `clock.install()`, then trigger the Tier A2 action."

### Assertion shape

- **Drop the per-assertion `timeout` override**. The whole point of fake time is to make the wall-clock budget shrink to ~zero; the default 5s assertion timeout is plenty for the post-fastForward render to settle.
- **Keep `test.setTimeout()` at the default**. If a fake-clock spec still wants 60s, the clock isn't being used correctly.
- **Use the same `getByRole('alert')` shape as Pattern 6** in `supabase-ssr-boilerplate.md` — Tier A2 banners and realtime-failure banners share the same a11y contract.

### Why not `vi.useFakeTimers()` / `jest.useFakeTimers()`?

Those fake the test process's clock. Playwright tests run in two processes (test runner + browser); `page.clock` is the browser-side fake. Faking the runner's clock has no effect on the browser's `setTimeout`, which is where the retry-backoff actually lives.

### Cross-references

- `kit/docs/guide/latency-feedback.md` (focused stub today — Tier C + sizing-primitive override only) + `lalista/specs/app-snappiness/spec.md § D1` (canonical for the full 4-tier framework until the post-soak lift). Together they define which surfaces are Tier A2 and what `useOptimisticMutation({ failureMode: 'banner' })` guarantees. Lift tracked in `kit/ROADMAP.md § Latency feedback framework`; once the framework lands in `latency-feedback.md`, this bullet collapses to a one-line pointer at that guide.
- `kit/TODOS.md` — `/ak-pre-ship` Gate 9 fault-injected QA pass (the runtime companion to this test pattern; together they cover the "happy-path crawl + retry-budget assertion" matrix for Tier A2 surfaces)
- Lalista PR #49 (2026-05-07) — `add-item-banner.spec.ts` as the don't-do-this prior art (`test.setTimeout(60000)` + `toBeVisible({ timeout: 25000 })`)
- Playwright `page.clock` docs: https://playwright.dev/docs/clock
