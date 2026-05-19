# Latency feedback

How to bridge user-perceived latency with the right affordance — loading
skeletons, threshold spinners, optimistic-mutation rollbacks, route-loading
placeholders. The goal: "did my tap register?" never crosses the user's
mind, and "I navigated away and the rollback fired silently" data loss is
impossible.

This guide pairs a 5-tier framework (A1 / A2 / B / C / D) with the rule
that maps any new interactive surface to one of the five, plus the
primitive contracts and tokens that make each tier concrete. The framework
was co-developed and soaked in lalista chapter 1m
(`feat/app-snappiness`, PR #49, 2026-05-07) before lifting here. The
lalista surface mapping in `specs/app-snappiness/spec.md § D1` is a worked
example of producing a project-specific tier mapping inside a spec's
`## Decisions` block — every project with interactive UI does the same
exercise as part of its own spec.

## Contents

- [The framework (5 tiers)](#the-framework-5-tiers)
- [Decision rule](#decision-rule)
- [Tokens](#tokens)
- [Primitive contracts](#primitive-contracts)
- [The queueMicrotask gotcha (load-bearing)](#the-queuemicrotask-gotcha-load-bearing)
- [Test patterns to reproduce](#test-patterns-to-reproduce)
- [Applying the framework to your project](#applying-the-framework-to-your-project)
- [Tier C is the navigation boundary, not the data-fetch boundary — in-page client `useEffect` fetches need their own affordance](#tier-c-is-the-navigation-boundary-not-the-data-fetch-boundary--in-page-client-useeffect-fetches-need-their-own-affordance)
- [Tier C: a route's `loading.tsx` and its client component's own load skeleton must paint identically](#tier-c-a-routes-loadingtsx-and-its-client-components-own-load-skeleton-must-paint-identically)
- [Sizing primitives that accept a `className` override must not bake conflicting CSS properties](#sizing-primitives-that-accept-a-classname-override-must-not-bake-conflicting-css-properties)
- [Cross-refs](#cross-refs)

---

## The framework (5 tiers)

Pick the tier by walking the [Decision rule](#decision-rule). Each row
defines the *affordance* (what the user sees on tap) and the *failure mode*
(what they see if the underlying mutation rejects).

| Tier | Name | When | Affordance | Failure |
|------|------|------|------------|---------|
| **A1** | Benign optimistic | Mutation usually succeeds; rollback is self-explanatory; user stays on the same screen | Visual change instant; no spinner, no disable | Silent rollback (reverted state IS the message) |
| **A2** | Banner-on-failure optimistic | Mutation usually succeeds, but failure could be missed if user navigates; loss matters | Visual change instant; retry up to `RETRY_BUDGET_MS` in background | Cross-screen banner ("Couldn't save '<item>' — retry / undo") |
| **B** | Threshold spinner | User waiting on a network round-trip with no local state to commit; action gates further progress | Instant disable + spinner after `FEEDBACK_THRESHOLD_MS` | Inline error |
| **C** | Route loading | Tapping a link to a different page | Page chrome paints; content area soft-pulses (`LoadingArea`) | `error.tsx` |
| **D** | CSS press only | Sub-100ms ops, or no observable result | OS / `:active` | n/a |

**A1 vs A2** is the framework's most important distinction:

- **A1** assumes the user will see the rollback (they're still on the
  screen that committed the change, the reverted state is self-evident).
- **A2** assumes they might not (they could navigate away before the
  server responds, or the failure isn't obvious from the reverted state
  alone) — the cross-screen banner catches them wherever they ended up.

If you find yourself wanting to add a spinner to a Tier A surface, you
have the wrong tier — Tier A's "I heard you" signal is the visual commit
itself. A spinner over already-committed state is noise.

**Worked examples by tier** (category-shaped — your surfaces will look
different):

- **A1**: a one-tap toggle whose rollback is visually obvious — bookmark
  flip, like, mark-as-done. Realtime or next-fetch reconciliation closes
  the loop.
- **A2**: a high-stakes form submit that survives the user navigating
  away — create-a-record from a modal, send-a-message, optimistic queue
  write.
- **B**: a non-optimistic mutation that gates further progress — sign-in,
  sign-up, password reset, destructive confirm. No local state to commit;
  the user is waiting on the round-trip to know whether they advance.
- **C**: any route segment whose tap-to-render path takes >100ms with no
  progressively-rendered chrome — the next page's first paint is the
  affordance once the route resolves.
- **D**: CSS-only interactions — theme toggle, sheet open/close, section
  collapse. No JS state, no spinner; `:active` and `transition` handle it.

---

## Decision rule

When you add a new interactive surface, walk these four questions in
order. Stop at the first one that resolves.

1. **What's the operation's latency?** If sub-100ms or no observable
   result → **Tier D**. Stop. (CSS only; no JS state, no primitive.)
2. **Is the surface a route navigation to a different page?** If yes →
   **Tier C**. (Use `loading.tsx` + `LoadingArea`.) Stop.
3. **Is there local state to commit optimistically?** That is — does the
   action have an obvious visible result the UI can paint *before* the
   server confirms?
   - **No** → **Tier B**. (Instant disable + threshold spinner at
     `FEEDBACK_THRESHOLD_MS`.) Stop.
   - **Yes** → continue to (4).
4. **Would a silent rollback be self-explanatory in context?** That is —
   if the mutation fails and the UI reverts, will the user understand
   what happened from the reverted state alone, AND are they likely to
   still be on this screen to see it?
   - **Yes** → **Tier A1**.
     (`useOptimisticMutation({ failureMode: 'rollback' })`; realtime /
     next-fetch reconciles.)
   - **No** (loss matters; user may navigate away before failure
     surfaces) → **Tier A2**.
     (`useOptimisticMutation({ failureMode: 'banner' })` + cross-screen
     banner slot.)

The rule is intentionally short — most interactive surfaces resolve in
two or three questions. If you're stuck choosing between A1 and A2, A2 is
the safer default (the banner adds no friction when the mutation
succeeds, and catches losses A1 would silently drop).

---

## Tokens

Three named constants drive the framework's timing. Export them from your
project's shared UI package (`packages/ui/src/tokens.ts` or equivalent)
so the primitives and any caller can reach the same values.

| Token | Value | What it controls |
|-------|-------|------------------|
| `FEEDBACK_THRESHOLD_MS` | `250` | Tier B spinner delay. Submit buttons disable instantly to communicate "I heard you"; the spinner only flashes if the action is still in-flight after this many ms. Below the threshold, the disable + post-resolve label swap is the entire affordance — no spinner flicker on fast resolves. |
| `RETRY_BUDGET_MS` | `15000` | Tier A2 total retry window before escalating to a banner. Covers transient mobile-network blips silently (the common case); persistent failures escalate to the cross-screen banner. |
| `RETRY_BACKOFF_MS` | `[1000, 3000, 7000]` | Tier A2 retry delays in ms. Sum is 11s of backoff + ~4× per-attempt RTT ≈ the full `RETRY_BUDGET_MS`. If an individual attempt exceeds the remaining budget mid-sequence, that attempt still completes (no preemption of in-flight requests), but no further retries are scheduled. |

**Tier C's pulse animation** uses your design system's soft-pulse —
Tailwind's `animate-pulse` default is fine. There is no named opacity
token; the primitive bakes the class directly. If your design system
tunes the pulse, tune it inside the `LoadingArea` primitive once, not at
every call site.

---

## Primitive contracts

The four primitives below are described as interface contracts, not
concrete code. Implement them in your project's shared UI package; the
contracts are what the framework guarantees. Lalista's implementations
in `packages/ui/src/` are the canonical prior art (and the source for the
eventual `@devshop-template/ui` extraction tracked in
`kit/ROADMAP.md § Latency feedback framework`).

### useOptimisticMutation

Tier A1 + A2 hook. Wraps an async mutation with an immediate visual
commit and a discriminated failure mode.

**Config:**

- `mutate: (args: TArgs) => Promise<TResult>` — async work that fires in
  the background after the optimistic commit.
- `applyOptimistic: (args: TArgs) => void` — synchronous visual commit;
  runs in the same render as the click handler.
- `onFailure` — discriminated union:
  - **`{ failureMode: 'rollback', rollback: () => void }`** — Tier A1.
  - **`{ failureMode: 'banner', rollback: () => void, bannerLabel: string, onBannerDismiss?: () => void }`** — Tier A2.
- `isHardError?: (err: unknown) => boolean` — classifier for "server said
  no, do not retry" (4xx/5xx). Default treats any error with a numeric
  `status` in `[400, 600)` as hard; everything else is transient (network
  blip). Override for non-HTTP error shapes (e.g. RPC validation errors
  with no HTTP status).

**Result:**

- `run(args: TArgs) => Promise<void>` — kicks off the optimistic flow.
  Sequence: clear stale banner → clear stale retry timer →
  `applyOptimistic(args)` synchronously → `setIsPending(true)` → start
  the retry sequence.
- `isPending: boolean` — true between `run()` and final resolution
  (success, hard-fail, banner dismiss, or undo).
- `banner: BannerState | null` — non-null only in banner mode after a
  hard failure or budget exhaustion; null otherwise.

**`BannerState`:**

- `label: string` — passed through from `bannerLabel`.
- `retry()` — clears timer + banner, sets pending, re-fires the mutation
  from attempt 0 with the original args. **Does NOT re-call
  `applyOptimistic`** — the optimistic state is still committed from the
  original `run`.
- `undo()` — clears timer + banner + pending, calls `rollback()`.
- `dismiss()` — clears timer + banner + pending, calls the optional
  `onBannerDismiss` callback. Caller owns any non-rollback cleanup.

**Retry sequence (banner mode only):**

1. Attempt 1 fires immediately inside `run()`.
2. On transient failure AND `attempt < RETRY_BACKOFF_MS.length`: schedule
   attempt N+1 after `RETRY_BACKOFF_MS[attempt]` ms.
3. Before scheduling: if `elapsed + backoff > RETRY_BUDGET_MS`, skip the
   retry and escalate immediately — don't schedule a doomed retry.
4. On hard error OR after the final attempt
   (`RETRY_BACKOFF_MS.length + 1` total attempts — 4 with the current
   backoff array): escalate to banner.

**Unmount safety:** clear the pending retry `setTimeout` in the effect
cleanup. A queued attempt that fires after the consumer unmounts would
call `setState` on an unmounted hook AND fire a `mutate()` the caller no
longer expects.

**Closure stability:** mirror `config` onto a ref each render so banner
callbacks (`retry` / `undo` / `dismiss`) and the recursive attempt
scheduler always see the latest props without rebinding `run`'s identity.

### useSubmitFeedback

Tier B's threshold-spinner state machine. Caller drives `isPending`; the
hook owns the `showSpinner` timer.

**Signature:**
`useSubmitFeedback(isPending: boolean, options?: { thresholdMs?: number }): { showSpinner: boolean }`

- On `isPending: false → true`: schedule `setShowSpinner(true)` via
  `setTimeout(thresholdMs ?? FEEDBACK_THRESHOLD_MS)`.
- On `isPending: true → false`: the effect cleanup clears the unfired
  timer AND resets `showSpinner` to `false`.

**Load-bearing detail:** the `setShowSpinner(false)` inside the cleanup
runs as part of the next effect pass / unmount, NOT synchronously after
the render that triggered it — that's what makes the threshold-then-clear
sequencing race-free. Moving it out of cleanup (or trying to
"synchronously reset" on the trailing edge) re-introduces a "spinner
flashes for one frame after the action resolves" race.

### SubmitButton

Thin presentational wrapper composing `useSubmitFeedback(isPending)`
over a base `Button` primitive.

**Props:** `children` (idle label), `isPending`, `pendingLabel?`
(post-threshold label; defaults to `children`), `isSuccess?`
(caller-controlled), `successLabel?` (post-success label; defaults to
`children`), plus standard button HTML attrs.

**Behavior:**

- `disabled = isPending || isSuccess || disabledProp` — flips
  synchronously on pending so the "I heard you" signal is instant.
- Spinner only appears when `showSpinner` flips true at the threshold.
- `aria-busy={isPending}` always reflects pending state (independent of
  the threshold).
- Hides the spinner on success even while `isPending` momentarily
  overlaps `isSuccess`.
- Does NOT manage form state, dispatch network calls, retry, or surface
  its own error UI. Failure UI is the caller's responsibility (Tier B's
  failure cell is "inline error").

### LoadingArea

Tier C's empty-container primitive. Renders a single soft-pulsing
rectangle sized by the caller, with the right ARIA shape for assistive
tech.

**Behavior:**

- Single wrapper element with `role="status"`, `aria-busy="true"`, and
  the caller-provided `aria-label`.
- Soft-pulse background — your design system's `animate-pulse` default.
- Optional `children` slot for layout-shape preservation when the
  placeholder needs to mimic real content shape.
- **Caller owns the dimension.** Don't bake `min-h-*` / `min-w-*`
  defaults into the primitive — they don't lose to caller overrides at
  the CSS layer (see [Sizing primitives that accept a `className`
  override must not bake conflicting CSS
  properties](#sizing-primitives-that-accept-a-classname-override-must-not-bake-conflicting-css-properties)
  below).

---

## The queueMicrotask gotcha (load-bearing)

This is the single detail most likely to silently break Tier A in a
React 19 project. Preserve verbatim if you fork the primitives.

When `failureMode: 'rollback'` fires after a failed mutation, the
rollback handler must run AFTER the pessimistic state has been visually
committed — not synchronously inside the same render that committed it.
React 19's auto-batching will otherwise elide the visible "row appeared
then disappeared" frame, and the user sees no feedback at all.

Two ways to break the batch:

1. `flushSync` around `applyOptimistic`, then run the mutation. Forces
   React to commit the optimistic frame to the DOM before the next
   `setState` lands.
2. Schedule the rollback via `queueMicrotask` so the optimistic frame
   paints before the rejection's `setState`. This is the canonical
   approach in `useOptimisticMutation` because it doesn't require the
   caller to know anything about React internals at the call site.

Inside the hook, the rollback path looks like this:

```ts
} catch (err) {
  if (cfg.onFailure.failureMode === 'rollback') {
    // Rollback after the optimistic frame paints, not synchronously.
    // queueMicrotask defers the rollback's setState one tick so
    // React 19's auto-batching can't elide the visible
    // "row appeared then disappeared" frame.
    queueMicrotask(() => {
      const latest = configRef.current.onFailure;
      if (latest.failureMode === 'rollback') {
        latest.rollback();
      }
      setIsPending(false);
    });
    return;
  }
  // ... banner-mode retry logic below
}
```

The comment above the `queueMicrotask` call is itself load-bearing — it's
the only thing that protects the pattern from being "simplified" by a
future contributor who doesn't know about React 19's auto-batching
behavior.

---

## Test patterns to reproduce

When you implement the framework in your project, these tests pin the
contract against regression. Names match lalista's
`packages/ui/src/useOptimisticMutation.test.ts`; replicate them by name
so the canonical-pin lineage stays legible.

**`useOptimisticMutation`:**

- `rollback mode (Tier A1) > calls rollback once on error and never retries`
  — asserts the rollback fires exactly once after a microtask flush,
  with a single mutate attempt.
- `rollback mode (Tier A1) > rollback fires AFTER applyOptimistic + mutate (paints optimistic frame first)`
  — **the canonical pin against the queueMicrotask gotcha**. Records
  call order into an array and asserts
  `['apply', 'mutate-start', 'rollback']`. Don't delete this test; if it
  breaks, the gotcha has been re-introduced.
- `banner mode (Tier A2) > runs the 4-attempt sequence with [1s, 3s, 7s] backoff and escalates banner`
  — fake-timer test (use `vi.useFakeTimers()` +
  `vi.advanceTimersByTime`) driving the full retry budget. Asserts 4
  mutate calls and banner surfaces after the final reject.
- `banner mode (Tier A2) > escalates banner immediately on hard error (no retries)`
  — `{ status: 422 }` short-circuits the retry sequence.
- `banner mode (Tier A2) > respects custom isHardError classifier` —
  non-HTTP error shapes can mark themselves as hard.
- `banner mode (Tier A2) > retry button re-fires mutation with the same args`
  — verifies the closure captures args and that retry does NOT re-call
  `applyOptimistic`.
- `banner mode (Tier A2) > undo button calls rollback and clears banner`.
- `banner mode (Tier A2) > dismiss button clears banner without rollback (caller-owned cleanup)`
  — verifies `onBannerDismiss` runs while `rollback` does not.

**`useSubmitFeedback`:** cover the 249ms-vs-250ms threshold edge and the
cleanup-resets-showSpinner-without-leaking-the-timer invariant. The
multi-cycle test (pending → resolved → pending again) is the canonical
pin against the load-bearing detail named in the contract above — the
cleanup-deferred `setShowSpinner(false)` keeps the threshold-then-clear
sequencing race-free.

**`SubmitButton`:** include a case verifying the success label persists
when both `isSuccess` and `isPending` are momentarily true.

**`LoadingArea`:** assert the pulse class, `className` override
pass-through, child pass-through, `role="status"`, and `aria-busy="true"`.

Tier A2's end-to-end Playwright tests (the full retry sequence with
network failures) need fake-clock control — see
[`testing.md`](./testing.md) Pattern 1 (`page.clock.fastForward()`, not
bumped per-test timeouts).

---

## Applying the framework to your project

When you add interactive UI to a project, produce a **surface mapping**
as part of your spec's `## Decisions` block. The mapping is a small
table that walks every interactive surface in the feature through the
[Decision rule](#decision-rule) and pins it to a tier. Format:

| Surface | Tier | Notes |
|---------|------|-------|
| <feature submit button> | B | `SubmitButton` |
| <one-tap toggle on the row> | A1 | `useOptimisticMutation({ failureMode: 'rollback' })` |
| <high-stakes form on the modal> | A2 | `useOptimisticMutation({ failureMode: 'banner' })` |
| <nav from list → detail page> | C | `loading.tsx` + `LoadingArea` |
| <theme toggle> | D | CSS only |

A worked example with real surfaces lives in
`lalista/specs/app-snappiness/spec.md § D1`. The mapping is the
artifact; it documents the tier decision for every interactive surface
so reviewers (and `/ak-pre-ship` Gate 9's fault-injected QA pass on
Tier A2 surfaces) can verify each one behaves correctly under failure.

The mapping is reviewed at:

- **Spec time** by `/ak-spec`'s consultation step (currently open work;
  see `kit/ROADMAP.md § Latency feedback framework`).
- **Implementation time** by per-commit grep — any new
  `useOptimisticMutation` / `useSubmitFeedback` / `SubmitButton` call
  site should map to a row in the spec's surface mapping.
- **Pre-ship time** by `/ak-pre-ship` Gate 9's fault-injection pass on
  Tier A2 surfaces (per `kit/TODOS.md § fault-injected-qa-gate`).

The framework is portable across React projects; the primitives are not
yet extracted to a shared package. Tracked in `kit/ROADMAP.md § Latency
feedback framework`. Until extraction, every project ships its own copy
from the lalista prior art (or imports from lalista directly during the
transition).

The corner-case sections below cover Tier C / primitive-design failure
modes that operate *within* the framework — apply them on top of the
tier decision, not instead of it.

---

## Tier C is the navigation boundary, not the data-fetch boundary — in-page client `useEffect` fetches need their own affordance

### The trap

`loading.tsx` covers the **navigation boundary**: it renders while the server
component (auth, top-level data fetches) runs, then unmounts the moment the
server returns and the page shell hydrates. It does **not** cover a follow-up
client-side `useEffect` data fetch inside that shell.

If a client component on a Tier-C-mapped route fetches its own data in `useEffect`
(e.g., a settings sub-section that pulls its rows after the page renders, because
the data isn't cheap to fetch SSR or has its own freshness contract), the user
sees three frames:

1. **Frame 1** (RSC stream): `loading.tsx` paints.
2. **Frame 2** (client hydrate): page shell + the client component's content
   slot, **empty** — its fetch round-trip is in flight, but `loading.tsx` is
   already gone. The page looks "done loading" but sits silent for the round-trip
   duration (~50–500ms typical, longer on real mobile networks).
3. **Frame 3**: real content arrives, content slot populates.

Frame 2 is the gap. The user perceives "the app loaded but this part is broken"
rather than "still loading" — there's no affordance distinguishing the two.

This is a **different failure mode** from the "two skeletons must paint
identically" rule below. There, two skeletons exist but mismatch (a snap).
Here, the second skeleton is missing entirely (a stall).

First incidence in lalista: PR #61 (settings/Members section). The household-
collaborators PR mapped `/settings` to Tier C, assuming `loading.tsx` would
cover the full load. `MembersSection` then fetched members + pending invites
in `useEffect` per the spec's "page-load freshness, no realtime" contract.
On local Supabase the fetch was <50ms — invisible. On real iOS the round-trip
was perceptible and the section sat empty after `loading.tsx` cleared.

### The fix (pick one)

1. **Add a section-scoped skeleton in the client component's loading state.**
   Cheapest fix: a couple of `animate-pulse` bars or a `LoadingArea` sized to
   match the real content slot, rendered until the fetch resolves. Combine with
   the "must paint identically" rule below — if both `loading.tsx` and this new
   skeleton render the same primitive at the same height, the user sees one
   continuous loading affordance across frames 1 and 2, then real content at
   frame 3. No gap, no snap.
2. **Hoist the data fetch into the server component (RSC) and pass as a prop.**
   The client mounts with `loadState === 'ready'` — no second loading state,
   no Frame 2 gap. Costs one extra round-trip on the SSR path; right answer
   when the data is cheap to fetch server-side and doesn't need a separate
   freshness contract.
3. **Wrap the client component in a `<Suspense>` boundary in the page** so
   `loading.tsx`'s fallback covers it too. Only works when the component is
   itself a Server Component (the `useEffect` fetch you're hiding has to be
   movable to the server). Architecturally cleanest when feasible.

### Don't

- Rely on `loading.tsx` alone for a route whose primary content comes from a
  client `useEffect` fetch. `loading.tsx` is the **page-navigation** affordance,
  not the **first-paint-to-data-ready** affordance.
- Assume "the fetch is fast, no skeleton needed." Local-dev round-trips are
  not real-mobile round-trips; the assumption only survives until the first
  iOS soak. Add the affordance regardless; remove only when measured to be
  imperceptible (<16ms) on production traffic.

### Detection at QA / design-review / pre-ship time

Cold-navigate to a route under Tier C on a throttled connection (Slow 3G works;
real iPhone over LTE is the gold standard). Watch the content area after
`loading.tsx` clears. If it goes blank/empty for any perceptible duration
before populating, the route has a missing in-page affordance — apply fix (1),
(2), or (3) above.

For static checking: in any client component file that does
`useEffect(() => { fetch... })` for content data, grep for an early-return
skeleton branch (`if (!loaded) return <...>` or equivalent). Absent → flag
for review.

---

## Tier C: a route's `loading.tsx` and its client component's own load skeleton must paint identically

### The trap

A Next.js App Router route that ships **both** a Suspense fallback
(`app/<route>/loading.tsx`, RSC-streamed) **and** a client component that re-fetches
in `useEffect` (e.g., a list view that mounts, subscribes to realtime, and runs
its own data fetch on mount) renders **two skeletons back-to-back** during a fresh
navigation:

1. **Frame 1** (RSC stream): `loading.tsx` paints — page chrome + a placeholder
   primitive in the content slot.
2. **Frame 2** (client hydrate): the client component mounts with
   `loadState === 'loading'`, runs its `useEffect` fetch, and paints **its own**
   skeleton until the fetch resolves.
3. **Frame 3**: real content.

If Frames 1 and 2 differ — different primitive, different dimensions, different
opacity, different colors — the user sees a snap. The first incidence in lalista
presented as "a big rectangle flashes, then three smaller rectangles, then the
list" — two skeletons rendered with different heights and opacity, perceived as
a glitch.

### The fix (pick one)

1. **Match the two skeletons exactly.** Use the same primitive
   (e.g., `LoadingArea`) with the same `className` height in both
   `loading.tsx` and the client component's own loading branch. This is the
   cheapest fix and the right default — the visual continuity is more
   important than the marginal "skeleton tuned for this surface" gain.
2. **Eliminate the second skeleton.** Have the server component fetch the
   initial payload and pass it as a prop into the client component, so the
   client mounts with `loadState === 'ready'` and there's nothing to skeleton
   over. This is the architecturally cleaner answer when the data is cheap
   to fetch server-side; it costs an extra round-trip on the SSR path in
   exchange for one fewer visual frame.

### Don't

Keep two hand-rolled skeletons that are "approximately" the same. Heights drift,
opacity drifts, and the bug returns the next time someone tweaks one without the
other.

### Detection at QA / design-review time

Watch the route's first paint on a cold navigation (cache disabled). If the
content area changes shape, height, or opacity between the very first frame
and the moment real content lands, you have a two-skeleton snap.

---

## Sizing primitives that accept a `className` override must not bake conflicting CSS properties

### The trap

A primitive that accepts a `className` override and merges it into its base
classes (the common Tailwind composition pattern) **cannot** prevent
property-level conflicts at the CSS layer. If the base sets `min-h-[120px]`
and the caller passes `h-[72px]`, the merged class string is
`min-h-[120px] h-[72px]` — both apply, and CSS resolves the box height as
`max(min-height, height) = 120px`. The caller's intent vanishes silently.

The first incidence in lalista: `LoadingArea` shipped with `min-h-[120px]`
baked in. Three of four `loading.tsx` files passed shorter heights
(`h-[72px]`, `h-[80px]`, `h-[40px]`) — all rendered at 120px. No error, no
warning, just silently wrong layouts everywhere the primitive was used at
<120px height.

### The rule

A sizing primitive that takes a `className` override leaves the dimension to
the caller. No baked `min-h-*`, `max-h-*`, `min-w-*`, `max-w-*` defaults that
the override can't reach. Either:

- **Don't ship a default size** — every caller passes one.
- **Or document the floor and design every caller around it** (rare; usually
  not worth the asymmetry it introduces).

### Don't

Ship a "sane default" min-height that "callers can override." They can't, at
the property level CSS doesn't work that way. The override merges in but loses
the resolution step.

### Detection at code-review / pre-ship time

Grep new primitives for `min-h-*`, `max-h-*`, `min-w-*`, `max-w-*` baked into
their base classes. If the primitive accepts `className`, the baked dimension
is a trap.

**See also:** [`supabase-ssr-boilerplate.md § Pattern 5`](./supabase-ssr-boilerplate.md#pattern-5-webkit-form-state-hydration-race-in-playwright-mobile-tests) — same shape of trap ("primitive accepts an override but encodes a conflicting platform default"); the principle generalizes beyond CSS to mobile WebKit's pre-hydration form-state.

---

## Cross-refs

- [`conventions.md § Responsive + Theme`](./conventions.md#responsive--theme) — the implement skill picks this guide up via that section's routing.
- [`testing.md`](./testing.md) Pattern 1 — Tier A2 retry-budget E2E tests use `page.clock.fastForward()`, not bumped per-test timeouts.
- [`ops.md § PWA`](./ops.md#pwa) — the iOS input-zoom rule applies to every Tier B submit-button form (`font-size ≥ 16px` floor on focusable input primitives prevents WebKit's auto-zoom).
- [`README.md`](./README.md) — the routing index that fires this guide on `useOptimisticMutation` / `SubmitButton` / `LoadingArea` / `loading.tsx` / client `useEffect` fetches / `"Tier A2"` / `"Tier C"` / `"skeleton"` / `"latency"` triggers.
- `kit/ROADMAP.md § Latency feedback framework` — the primitives extraction to a shared `@devshop-template/ui` package and `/ak-spec` consultation step (both open work).
- `kit/TODOS.md § fault-injected-qa-gate` — the `/ak-pre-ship` Gate 9 extension that fault-injects Tier A2 surfaces.
- `lalista/specs/app-snappiness/spec.md § D1` — the original spec where the framework was first written down, plus the canonical worked example of a project-specific surface mapping.
