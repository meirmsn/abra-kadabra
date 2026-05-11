# Latency feedback

How to bridge user-perceived latency with the right affordance — loading skeletons,
threshold spinners, optimistic-mutation rollbacks, route-loading placeholders. The
goal is "did my tap register?" never crosses the user's mind, and "I navigated away
and the rollback fired silently" data loss is impossible.

> **Status (2026-05-08):** focused stub. The full 4-tier framework (A1/A2/B/C/D) +
> canonical surface mapping + tokens (`FEEDBACK_THRESHOLD_MS`, `RETRY_BUDGET_MS`,
> `RETRY_BACKOFF_MS`) was first proven in lalista's chapter 1m and is scheduled
> to lift here post-soak per
> `PRODUCT-ROADMAP.md § Devshop extraction of validated UX patterns` in lalista.
> Until then, the canonical reference for the framework is
> `specs/app-snappiness/spec.md § D1` in lalista.
>
> **The rules below apply now, before the framework lifts** — they surfaced as
> soak findings and would otherwise rot inside a project's CLAUDE.md gotchas.

## Contents

- [Tier C: a route's `loading.tsx` and its client component's own load skeleton must paint identically](#tier-c-a-routes-loadingtsx-and-its-client-components-own-load-skeleton-must-paint-identically)
- [Sizing primitives that accept a `className` override must not bake conflicting CSS properties](#sizing-primitives-that-accept-a-classname-override-must-not-bake-conflicting-css-properties)
- [Application](#application)

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

## Application

These rules apply to any project using a latency-feedback framework or any
analogous "primitive + caller-overridden className" pattern (so: most Tailwind
component libraries shipped via a workspace package). The implement skill picks
them up via `kit/docs/guide/conventions.md § Responsive + Theme`, which links
back here.

When the full 4-tier framework lifts from lalista post-soak, this guide
expands with the tier table, canonical surface mapping, primitive APIs
(`useSubmitFeedback`, `SubmitButton`, `LoadingArea`, `useOptimisticMutation`),
and the `FEEDBACK_THRESHOLD_MS` / `RETRY_BUDGET_MS` / `RETRY_BACKOFF_MS` tokens.
