# The React home spike: shadcn/ui and Tailwind v4 on the baseline's tokens

[Spec](../../../../../specs/react-home-ui-defaults.md), its experiment before the decisions. Run on
2026-11-02 in a cloud session, on a scratch Next.js app outside any project. The question: can a
Next.js app styled by Tailwind v4 and shadcn/ui keep its theme in the shape the devshop's three UI
checks read (`:root`, `:root[data-theme="dark"]`, `:root:not([data-theme="light"])` in the dark
media query), and pass them? Synthetic throughout; no project's files were read.

## Set-up

- **The app,** [`app/`](app): `package.json` with Next 16.2.4 and React 19.2.5 (the pilot web app's
  versions, W10.11.2), `tailwindcss` and `@tailwindcss/postcss` 4.3.3, `shadcn` 4.23.0 (the CLI's
  latest on 2026-11-02, published 2026-10-27), Playwright 1.56.1; installed with `npm install` from
  the registry. [`app/app/globals.css`](app/app/globals.css) is the theme: Tailwind's import, a
  `dark` variant on the baseline's two dark selectors, the bridge (`@theme inline`), the three token
  rules of `runtime/templates/ui/base.css` verbatim, and a base layer.
  [`app/app/layout.tsx`](app/app/layout.tsx) loads `runtime/templates/ui/theme.js`, copied unchanged
  to `public/theme.js`; [`app/app/page.tsx`](app/app/page.tsx) renders two shadcn/ui buttons and a
  theme toggle that is a third.
- **The component:** `shadcn add` could not run: the CLI fetches from `ui.shadcn.com`, and this
  environment's network policy refused the host (the proxy answered 403 to `CONNECT`). The button
  was copied instead from shadcn/ui's source at the CLI's tag on GitHub's raw host, which answered:
  `shadcn-ui/ui` at `shadcn@4.23.0`, `apps/v4/registry/new-york-v4/ui/button.tsx`, its `cn` import
  pointed at `@/lib/utils`. Its runtime dependencies were added at exact versions: `radix-ui`,
  `class-variance-authority`, `clsx`, `tailwind-merge`.
- **The checks:** the devshop's `runtime/templates/ui/` copies at `main` `90a54f5`, unchanged.
  [`run.sh`](run.sh) builds with `next build`, serves with `next start` on `127.0.0.1` and runs
  `render-check.mjs` on `/`.

## Results

| Probe                                                                                                  | Result                                                                                                                                               |
| ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tokens-check.mjs --theme app/globals.css app/page.tsx components/ui/button.tsx`                       | exit 0: 32 tokens, 9 contrast pairs. Its reader skips `@theme inline`'s declarations (no rule inside) and the variant's `@slot` rules declare nothing |
| `design-md-check.mjs --theme app/globals.css tests/fixtures/design-md/baseline/DESIGN.md`              | exit 0: 28 tokens derived                                                                                                                            |
| `next build`, then `render-check.mjs` on `/`                                                           | exit 0 at 375, 768 and 1280 px, light and dark: the toggle both ways and after a reload, 44 px targets, the pressed state, contrast                 |
| The same without the base layer's 44 px rule                                                           | exit 1: `target-size` on every button at every width (shadcn/ui's `h-9` button is 36 px tall)                                                         |
| A `.dark { … }` block appended to the theme, as the CLI writes a component's tokens                   | `tokens-check.mjs` exit 2: `'.dark' declares custom properties`                                                                                     |
| A light-only `--sidebar` added to `:root`, as the CLI writes one                                       | `tokens-check.mjs` exit 1 `light-only-colour`; `design-md-check.mjs` exit 1 `theme-not-in-design`                                                    |
| shadcn/ui's own theme shape (`:root` and `.dark`) as the theme                                          | `tokens-check.mjs` exit 2: `'.dark' declares custom properties`                                                                                     |
| A bridge entry `--color-chart-1: var(--chart-1)` with no `--chart-1` in the theme, the bridge as a file | `tokens-check.mjs` exit 1 `undefined-token`                                                                                                          |
| `text-white bg-red-500 border-black` on the page, with `--color-*: initial` in the bridge              | no CSS generated for any of the three; `text-primary-foreground` compiles to `color: var(--primary-foreground)`                                     |
| The same without `--color-*: initial`                                                                  | all three compile, to `var(--color-white)`, `var(--color-red-500)`, `var(--color-black)` (Tailwind's palette)                                         |
| `dark:text-foreground` with the custom variant                                                         | compiles to a `[data-theme="dark"]` rule and a `:root:not([data-theme="light"])` rule inside `@media (prefers-color-scheme: dark)`                   |
| Tailwind's own `--font-sans`                                                                           | emitted in `@layer theme`; the theme's unlayered `:root` value wins, so `font-sans` and the body read the theme's stack                               |
| `--font-display: var(--font-display)` in the bridge, `--font-display: Georgia, serif` in `:root`       | `.font-display { font-family: var(--font-display) }`; the self-reference is emitted in `@layer theme` only, so the theme's value wins                |
| `next/font/local` with `variable: '--font-sans'` and a self-hosted Inter woff2                          | `.inter_…__variable { --font-sans: "inter", "inter Fallback" }`: the token on a generated class, outside the three rules, with a generated family list |
| A hand-written `components.json` (`new-york`, `app/globals.css`, the five aliases) against the pinned CLI's own `rawConfigSchema` (`shadcn/schema`) | valid; without `tailwind.baseColor` invalid (a required string); `style` takes any string, so the schema doesn't prove the style exists |
| The theme split in two files (`theme.css` imported by `globals.css`)                                  | also passes all three checks, with `theme.css` as the theme; a `.dark` block written into `globals.css` would then go unseen                         |

Two of shadcn/ui's new-york-v4 sources at the tag use Radix's runtime variables in `var()`
(`select`: `--radix-select-trigger-height`, `--radix-select-trigger-width`; `navigation-menu`:
`--radix-navigation-menu-viewport-height`, `…-width`), which `tokens-check.mjs` would report as
undefined; others use Tailwind v4's `(--name)` shorthand, which it doesn't read. The overlays
(`dialog`, `dropdown-menu`, `select`, `sheet`, `popover`, `tooltip`, `accordion`) use
`tw-animate-css` classes; none of the sources read uses shadcn/ui's own `shadcn/tailwind.css`.

## What it settles, and what it doesn't

The one-file theme, the bridge, the dark variant, the 44 px base rule, `theme.js` by `src`, the
toggle as a server-rendered button and plain `@font-face` over `next/font` rest on the rows above.
Not shown here: `shadcn add` itself (the host is blocked), a page with a self-hosted face through
`@font-face` (the `next/font` probe used one), the OpenNext build, and any real project's pages.
