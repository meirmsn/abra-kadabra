# Tailwind v4 gotchas

Stack-version footguns surfaced by Tailwind v4 — its source-scanning model and its named-key sizing-utility resolution through `--spacing-*` tokens. Both reproduce on any project that combines Tailwind v4 with a monorepo workspace package OR an 8px-grid spacing-token theme, which is the standard template choice.

## Contents

- [Tailwind v4 @source directive](#tailwind-v4-source-directive)
- [Named-key sizing utilities resolve through `--spacing-*`](#named-key-sizing-utilities-resolve-through---spacing-)

---

## Tailwind v4 @source directive

Tailwind v4 scans `@source`-declared globs for class-name usage; classes used only inside a non-scanned file ship as dead CSS. In a monorepo where styled components live in workspace packages outside the app's own tree (e.g. `packages/ui/**` consumed by `apps/web/**`), the app's root CSS file MUST declare each workspace-package source as an `@source` line.

```css
/* apps/web/app/globals.css */
@import 'tailwindcss';
@source "../../../packages/ui/src/**/*.{ts,tsx}";
```

Forgetting the `@source` line silently strips utilities used only by the consumed package — token classes (`bg-primary`, `border-border`), spacing utilities, etc. — and produces unstyled output without a build error or warning. When a new styled workspace package is added (e.g. a future `packages/icons`), add a matching `@source` line in the same PR.

## Named-key sizing utilities resolve through `--spacing-*`

When `--spacing-*` tokens are defined in a Tailwind v4 `@theme inline` block (8/16/24/32 px on an 8px grid is a common template default), Tailwind v4 resolves every named-key sizing utility — `max-w-sm`, `max-w-md`, `min-w-lg`, `h-xl`, `w-2xl`, etc. — through the spacing scale, NOT the container scale. So `max-w-sm` ships as `max-width: 8px`, not the 24rem container value. Defining `--container-*` tokens alongside `--spacing-*` does NOT override.

Use arbitrary values for sizing — `max-w-[24rem]`, `h-[32px]`, `min-w-[420px]` — and reserve named keys for true spacing utilities (`p-4`, `gap-2`). The two scales collide at named-key resolution, and the container scale loses.

Restoring the container scale requires dropping `--spacing-*` and inheriting Tailwind's defaults — a wide blast radius on every gap/padding token in the codebase. Not done lightly. Verified empirically against direct `@tailwindcss/node` compile (2026-05-07).
