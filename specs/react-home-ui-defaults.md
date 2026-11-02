# The React home's UI defaults: shadcn/ui on the baseline's tokens, pinned in the Next.js home

**Go:** pending

## Intent

Spec D of the UI tooling strategy the owner accepted on 2026-10-31 ("agree with your 4 recs"; the
order A, B, C, then D). The owner asked (2026-11-02): "D the React home's defaults at M3", whose job
spec A's decisions name: "React stack homes use shadcn/ui, the theme CSS derived by hand from
`DESIGN.md`'s tokens under the baseline's token names so one `tokens-check` covers both, styles in
stylesheets (the detector's DOM mode can't see CSS-in-JS); the Next.js home pins the library at
M3", and spec C left to it: "the stack home fills `THEME_CSS` in its `check-fast.sh` and wires all
three UI checks (`tokens-check.mjs`, `design-md-check.mjs`, `render-check.mjs`) on its stack". The
spec must settle "the library pin", "Tailwind's role", "where the theme CSS lives in a Next.js
project and how `THEME_CSS` names it", "the derivation on this stack" under the three selectors the
checks require, "the theme toggle (`[data-theme-toggle]`) on this stack", "the wiring" of the fast
and slow tiers and `supplies`, "styles in stylesheets, no CSS-in-JS; one authored motion moment per
page as `design.md` says; fonts self-hosted", and "every check is proven to fail". Out of scope by
the owner's words: "the reviewer's prompt, any wall on design findings, the pilot web app's own repo
(this change edits only the devshop)". Workstream lines W10.8.3 and W10.11.7; roadmap R-7 (M3) stays
open. Surface: none; this change renders no page of a product.

Why: the pilot web app (Next.js with Supabase, on Workers through the OpenNext adapter, W10.11.2)
is the first React project. Without a home that says how shadcn/ui's theme takes the baseline's
shape, its first UI change would start from shadcn/ui's own theme (`:root` plus a `.dark` class),
which `tokens-check.mjs` can't judge, and its fast tier would run none of the UI checks.

The experiment came first: [the spike record](../kit/notes/revamp/spikes/react-home/README.md)
(2026-11-02), a scratch Next.js app with Tailwind v4 and a shadcn/ui button on the baseline's
tokens. Every "spike:" below points at a row there.

## Decisions

- **The pin: the `shadcn` CLI at 4.23.0, exact, and the copies it makes.** shadcn/ui is not a
  runtime library: its CLI copies component source into the project, which owns it from then on.
  A project on this stack pins `shadcn` `4.23.0` in `devDependencies` (the latest on 2026-11-02,
  published 2026-10-27) and runs that local binary (`npx shadcn add <name>`, never
  `shadcn@latest`); `tailwindcss` and `@tailwindcss/postcss` `4.3.3`, exact; each runtime dependency
  the CLI adds (`radix-ui`, `class-variance-authority`, `clsx`, `tailwind-merge`, `lucide-react`) at
  an exact version. `components.json` is placed from the home's template, not written by
  `shadcn init`, which would write shadcn/ui's own theme over the home's: `style` `new-york` (what
  the pinned CLI picks for a Tailwind v4 project; its sources are `new-york-v4` in shadcn/ui's
  repository), `rsc` and `tsx` true, `tailwind.css` `app/globals.css`, `tailwind.config` empty,
  `cssVariables` true, `iconLibrary` `lucide`, the aliases `@/components`, `@/components/ui`,
  `@/lib`, `@/lib/utils`, `@/hooks`. Moving the CLI's pin is a change of its own, and a re-added
  component is a diff to review, since the copy is project code. Rejected: Basecoat (spec A, the
  owner's call 3); `shadcn@latest` (a different component source on every run) (Claude's proposal,
  2026-11-02)
- **The CLI needs `ui.shadcn.com`.** The pinned CLI fetches components from that host, which this
  environment's network policy denies (spike: the proxy answered 403). The home's set-up gains an
  owner's step: allow `ui.shadcn.com` in the network policy of the project's cloud environment;
  the session checks it with `curl -sI https://ui.shadcn.com/` answering. Where it isn't allowed,
  `shadcn add` can't run and the change says so plainly; the home names no hand-copy route, since
  that would be a mechanical step outside a tested script (the spike's hand copy was the
  experiment's, not a route). Rejected: a tested script that copies components from shadcn/ui's
  GitHub source at the tag (reachable here; a second component route to build and prove, kept as
  the fallback if the owner won't allow the host) (Claude's proposal, 2026-11-02; open question 1)
- **Tailwind v4 is the styling layer; the theme is one file, `app/globals.css`.** The home ships
  `runtime/stacks/nextjs-supabase/globals.css`, which a project copies to `app/globals.css`, in
  this order: `@import 'tailwindcss'`; the `dark` variant; the bridge; the three token rules; the
  base layer. The template's `check-fast.sh` gets `THEME_CSS="app/globals.css"`. One file because
  shadcn/ui's CLI writes a component's tokens into the file `components.json` names: with that file
  the theme, a `.dark` block it writes makes `tokens-check.mjs` exit 2 and a light-only token is a
  finding in both checks (spike). `tokens-check.mjs` and `design-md-check.mjs` read the file as
  they read `base.css`: their reader skips `@theme inline`'s declarations (no rule inside) and the
  variant's rules declare nothing (spike, both exit 0). The token rules are `base.css`'s three
  rules verbatim, so a project with no `DESIGN.md` has the baseline as its design (`ui.md`); the
  direction slice changes their values to `DESIGN.md`'s. Rejected: a separate `theme.css` imported
  by `globals.css` (passes too, spike, but a `.dark` block the CLI writes into `globals.css` goes
  unseen); shadcn/ui's own theme (`:root` plus `.dark`: `tokens-check.mjs` can't judge it, spike)
  (Claude's proposal, 2026-11-02)
- **The bridge:** `@theme inline` holding `--color-*: initial`, then `--color-<name>: var(--<name>)`
  for every colour token in `:root` and nothing else under `--color-`; `--radius-sm`, `-md`, `-lg`
  and `-xl` from `--radius` as shadcn/ui derives them (`calc(var(--radius) - 4px)`, `- 2px`, itself,
  `+ 4px`); `--spacing: var(--space-1)`. Clearing the palette means a class naming a colour the
  theme lacks (`text-white`, which shadcn/ui's destructive button carries; `bg-red-500`) compiles
  to nothing, so the only colours a utility can paint are the theme's (spike). `inline` makes the
  utilities read `var(--<name>)` itself. Tailwind's spacing scale becomes multiples of `DESIGN.md`'s
  step `1`, so `p-4` is `--space-4` while the steps are linear, as the baseline's are. Fonts:
  `font-sans` and `font-mono` read the theme's `--font-sans` and `--font-mono`, whose unlayered
  `:root` values win over Tailwind's defaults (spike); a role face beyond them gets
  `--font-<role>: var(--font-<role>)` in the bridge, whose self-reference Tailwind emits only in its
  theme layer, where the theme's value wins (spike). Shadows and type sizes stay Tailwind's
  defaults: `DESIGN.md` has no group for them (spec C). The cost, said plainly: Tailwind skips a
  class it can't build without a word, so a class naming a token the bridge lacks paints nothing; no
  check sees the class, the render check and the reviewer see its effect. `tokens-check.mjs`
  doesn't read Tailwind's `(--name)` shorthand either. Both go to `FINDINGS.md` as one `low` row
  (Claude's proposal, 2026-11-02)
- **Dark mode and the toggle.** `@custom-variant dark` names the baseline's two dark selectors (the
  toggle's `[data-theme='dark']`, and the system's dark when `:root` isn't `[data-theme='light']`,
  inside `@media (prefers-color-scheme: dark)`), so shadcn/ui's `dark:` classes follow the same
  rules as the tokens (spike: both compile); shadcn/ui's `.dark` class is not used. `theme.js` is
  copied unchanged to `public/theme.js` and loaded by `<script src="/theme.js">` in the root
  layout's `<head>`, a plain script before the first paint, with the `@next/next/no-sync-scripts`
  lint rule disabled on that line and its reason; `<html>` carries `suppressHydrationWarning`, since
  `theme.js` sets `data-theme` before React hydrates. The toggle is a shadcn/ui `Button` with
  `data-theme-toggle` and `suppressHydrationWarning`, rendered by a server component: `theme.js`
  rewrites its label, and a client component that re-renders it would put the server's label back.
  Spike: the render check's toggle rule passes both ways and after a reload. Rejected: `next-themes`
  (shadcn/ui's suggestion; a second toggle beside the tested `theme.js`); an inline script (a
  content-security policy needs a nonce or hash for it, and `script-src 'self'` allows the file)
  (Claude's proposal, 2026-11-02)
- **Controls at 44 px without editing the copies.** shadcn/ui's sizes are under 44 px (its button is
  36 px tall: spike, `target-size` on every button without the rule). The base layer sets
  `min-height: var(--tap)` on `[data-slot='button']`, `[data-slot='input']` and
  `[data-slot='select-trigger']`, and `min-width: var(--tap)` on `[data-slot='button']`; a minimum
  overrides a utility's smaller `height` whatever the layer, so the copies stay as the CLI wrote
  them. Smaller controls (checkbox, switch, radio) are the project's; the render check finds them.
  The base layer also carries `base.css`'s reduced-motion rule, the body's background, text colour
  and font, and the border colour. Rejected: editing each copy's size classes (a diff on every
  re-add) (Claude's proposal, 2026-11-02)
- **Fonts self-hosted, as plain `@font-face`.** woff2 files under `public/fonts/` with their licence
  file, `@font-face` rules with `font-display: swap` in `app/globals.css`, preloaded by
  `<link rel="preload" as="font" type="font/woff2" crossorigin>` in the root layout; each font
  token names its face, then a generic family (F-NEW-90). Rejected: `next/font` (spike:
  `next/font/local` puts the token on a generated class, outside the three rules the checks read,
  with a generated family list `DESIGN.md` can't name; `next/font/google` downloads the files when
  the app builds) (Claude's proposal, 2026-11-02)
- **Styles in stylesheets.** Tailwind compiles the classes into the stylesheet Next.js serves; no
  CSS-in-JS library (`styled-components`, `@emotion/*`) and no `<style jsx>`. A rule for the
  builder that the reviewer sees in the diff, not a check. Rejected: a fast-tier check for it (a new
  project-facing check for a rule no change has broken yet) (Claude's proposal, 2026-11-02)
- **Motion.** One authored moment per page, named in `DESIGN.md`'s motion section (`design.md`):
  on this stack it is CSS (`@keyframes` and its rule in a stylesheet), or a block copied from a
  kit's source with the kit's licence file whose imports are React and the project's own; a block
  that imports `motion` or `framer-motion` brings a motion kit as a dependency and isn't used.
  `tw-animate-css`, the package shadcn/ui's overlays take their enter and exit classes from, is not
  added: without it those classes compile to nothing and the overlays open without animation, the
  baseline's behaviour. Rejected: adding it (a motion pack as a dependency) (Claude's proposal,
  2026-11-02; open question 2)
- **The fast tier: the home's `check-fast.sh`.** The home ships
  `runtime/stacks/nextjs-supabase/check-fast.sh`, which a project on this stack copies instead of
  the template: the template with three places filled: `THEME_CSS="app/globals.css"`, `UI_LIBRARY` beside it, and the stack
  part. The stack part runs `tokens-check.mjs` over the theme and every file `git ls-files` lists
  as `*.css`, `*.tsx`, `*.jsx` or `*.mdx`, except the theme itself and `UI_LIBRARY`
  (`components/ui`, a variable beside `THEME_CSS`): two of the copies, `select` and
  `navigation-menu`, use Radix's runtime variables (`var(--radix-…)`), which the check would report
  as undefined (spike); the copies' colours, radius and spacing reach a page through the bridge,
  which is checked. A missing `scripts/ui/tokens-check.mjs` is "couldn't run", exit 2, never a
  finding (`node` on a missing file exits 1); so is `git ls-files` failing. The design part is the
  template's, unchanged. A project with `src/` sets `THEME_CSS`, `UI_LIBRARY` and
  `components.json`'s paths to match. A test holds the home's copy equal to the template outside
  those three places, so a template change reaches it. Rejected: wiring `tokens-check.mjs` into the
  template (the owner kept it out at spec C's go) (Claude's proposal, 2026-11-02)
- **The slow tier: the home's `check-slow.sh`.** The home ships
  `runtime/stacks/nextjs-supabase/check-slow.sh`: it starts `scripts/local-run.sh` on a free local
  port in its own process group, waits up to `LOCAL_RUN_WAIT` seconds (default 300) for any HTTP
  answer at `/`, runs `node scripts/ui/render-check.mjs --url http://127.0.0.1:<port><path> --out
<SHOTS_DIR>/<slug>` for every path in `quality/routes.json` (a JSON list of paths starting with
  `/`, the Cloudflare home's name for it; `SHOTS_DIR` defaults to `ui-shots`), every path even after
  one fails, stops the server's group and exits with the worst. It exits 2, never 0, when
  `scripts/local-run.sh` is missing or not executable, the render check's copy is missing,
  `quality/routes.json` is missing, unreadable, not a list, empty or holds a path without a leading
  `/`, or the server exits or doesn't answer in time (its log's last lines printed). The project's
  own end-to-end tests go below a marked line. A signed-in page renders the sign-in page it
  redirects to; the list holds public pages until W10.11.9's authenticated step. What
  `scripts/local-run.sh` runs (on the pilot web app, the OpenNext build and `wrangler dev`, as the
  Cloudflare home says) stays the project's, written with W10.11.6. Rejected: the Cloudflare home's
  broken-page proof in the seed (a served Next.js page can't be edited per run; the devshop's slow
  test proves the render check fails a broken page through this script instead) (Claude's proposal,
  2026-11-02)
- **`supplies`:** `scripts/ui/tokens-check.mjs`, `scripts/ui/render-check.mjs` and
  `scripts/local-run.sh`, the three the home's tiers run every time. Not
  `scripts/ui/design-md-check.mjs`: `DESIGN.md` is optional on every stack (spec C), `supplies`
  can't say "once a `DESIGN.md` exists", and the fast tier's part already makes a missing copy
  "couldn't run" once one does. The cost: the home loads for any Next.js or Supabase project, so a
  Supabase project with no web page would be asked for the UI copies; none exists today, and the
  day one does its `detect` splits. A `low` row in `FINDINGS.md` (Claude's proposal, 2026-11-02)
- **The home's README:** the placeholder line narrows to "placeholder except § UI" (W10.11.11
  writes the rest from what ships), and a `## UI: shadcn/ui on the baseline's tokens` section says
  the decisions above in the home's words: the pins, what a project copies and where
  (`app/globals.css`, `components.json`, `public/theme.js`, `scripts/check-fast.sh`,
  `scripts/check-slow.sh`, `quality/routes.json`), the owner's set-up step and its check, and links
  the spike record. `runtime/stacks/README.md`'s line for the home says the same in one clause
  (Claude's proposal, 2026-11-02)
- **Docs, in files this change owns:** `design.md` § Components and motion's "The Next.js home pins
  the version" links the home's section; `ui.md` § The baseline's "Start from
  `runtime/templates/ui/`" bullet gains that a Next.js project takes the home's `globals.css` in
  place of `base.css` (one clause); `docs/README.md` links the spike record and the two new tests;
  W10.8.3 and W10.11.7 get dated notes; `kit/notes/revamp/LOG.md` an entry. No shipped spec is
  edited (LOG #95) (Claude's proposal, 2026-11-02)
- **The proof:** `tests/nextjs-home.test.sh` (fast) and `tests/nextjs-home-render.test.sh` (slow,
  the real render check in Chromium); every case prints `react-home-ui-defaults AC-<n>`. The fast
  test runs the home's real files with the real `tokens-check.mjs` and `design-md-check.mjs` in a
  scratch git project, stubs for the non-UI parts; the slow test serves pages from a fake
  `scripts/local-run.sh` (`python3 -m http.server`). `tests/contract-check.test.sh` gains the home's
  `supplies` count. The PR's Evidence records each new rule's mutant and the case that killed it. No
  Next.js build in the devshop's CI: the build is the spike's record, not a test the devshop can
  install for (Claude's proposal, 2026-11-02)
- **Not here:** the pilot web app's repo and its `scripts/local-run.sh`, `scripts/setup.sh` and
  deploy (W10.11.6, W10.11.11); the reviewer's prompt; a wall on design findings; changes to the
  three checks; a CSS-in-JS check; F-NEW-81, 82 and 90 into `ui.md` (W10.11.7); a `DESIGN.md` for
  the pilot web app (its direction slice)

## Acceptance items

- **AC-1** The home's `globals.css`: its three token rules are `runtime/templates/ui/base.css`'s
  three token rules, text for text; it declares custom properties only in those rules and in
  `@theme inline`; `tokens-check.mjs --theme` on it exits 0, and `design-md-check.mjs --theme` on it
  with `tests/fixtures/design-md/baseline/DESIGN.md` exits 0
- **AC-2** The bridge in the home's `globals.css` holds `--color-*: initial` and exactly one
  `--color-<name>: var(--<name>)` per colour token in its `:root` and no other `--color-` entry,
  `--radius-sm`, `-md`, `-lg` and `-xl` from `var(--radius)`, and `--spacing: var(--space-1)`; its
  `@custom-variant dark` names `[data-theme='dark']` and, inside
  `@media (prefers-color-scheme: dark)`, `:root:not([data-theme='light'])`; its base layer sets
  `min-height: var(--tap)` on the three slots and `min-width: var(--tap)` on the button's, and
  holds the reduced-motion rule
- **AC-3** The home's `check-fast.sh` is the template's `check-fast.sh` but for the `THEME_CSS` line
  (`app/globals.css`), the `UI_LIBRARY` line and the stack part
- **AC-4** In a scratch git project with the home's `check-fast.sh`, its `globals.css` as
  `app/globals.css` and the real token check: the tier passes, with `tokens-check.mjs` given
  `--theme app/globals.css` and the tracked `*.css`, `*.tsx`, `*.jsx` and `*.mdx` files except the
  theme and `components/ui/`; a copy under `components/ui/` using `var(--radix-…)` passes; it fails
  (exit 1, every other part still run) on a page using a token the theme lacks, a bridge entry
  naming a token the theme lacks, and a light-only colour added to `:root`; it can't run (exit 2) on
  a `.dark` block in the theme, a missing `scripts/ui/tokens-check.mjs`, a missing theme, and no
  git repository
- **AC-5** The same project with `tests/fixtures/design-md/baseline/DESIGN.md` as its `DESIGN.md`
  and the real `design-md-check.mjs`: the tier passes; with a colour token added to the theme's
  `:root` and both dark rules that the `DESIGN.md` doesn't name, it fails with
  `theme-not-in-design`
- **AC-6** The home's `check-slow.sh` with a stub render check and a `scripts/local-run.sh` serving
  files on `127.0.0.1:$PORT`: each path in `quality/routes.json` is rendered with
  `--url http://127.0.0.1:<port><path>` and its own `--out` directory under `SHOTS_DIR`; a path
  whose check exits 1 fails the tier and every path still runs; one that exits 2 makes it exit 2;
  it exits 2 with no `scripts/local-run.sh`, no render check copy, no `quality/routes.json`, one that
  isn't a JSON list, an empty list, a path without a leading `/`, a server that exits at once and one
  that never answers within `LOCAL_RUN_WAIT`; the server no longer answers once the tier ends
- **AC-7** With the real render check in Chromium, the home's `check-slow.sh` over a
  `scripts/local-run.sh` serving the baseline's example page passes and leaves the six screenshots;
  with that page's viewport meta removed it fails (exit 1)
- **AC-8** `runtime/stacks/nextjs-supabase/supplies` names `scripts/ui/tokens-check.mjs`,
  `scripts/ui/render-check.mjs` and `scripts/local-run.sh` and nothing else; it parses against the
  real contract, and a project it applies to that lacks one of them is red
- **AC-9** The home's `components.json` is valid JSON with `style` `new-york`, `rsc` and `tsx` true,
  `tailwind.css` `app/globals.css`, `tailwind.config` empty, `cssVariables` true, `iconLibrary`
  `lucide` and the five aliases; the home's README names `shadcn` `4.23.0`, `tailwindcss` and
  `@tailwindcss/postcss` `4.3.3`, and the owner's step for `ui.shadcn.com`
- **AC-10** The home's README § UI, `runtime/stacks/README.md`, `design.md` § Components and
  motion, `ui.md` § The baseline and `docs/README.md` say what Decisions says; `design.md` stays
  within 120 lines and 1200 words; `scripts/docs-map-check.py` passes; no file under `specs/` other
  than this one changes — verified by review: the diff and CI on the PR's head
- **AC-11** `tests/run.sh` passes with the two new test files in it, and the PR's Evidence lists
  each new rule's mutant and the case that killed it — verified by review: the Evidence section and
  CI on the PR's head
- **AC-12** `kit/notes/revamp/LOG.md` has an entry; W10.8.3 and W10.11.7 carry dated notes;
  `FINDINGS.md` has the two `low` rows Decisions names — verified by review: the diff

## Out of scope

- The pilot web app's repo: its `components.json`, `globals.css`, `scripts/local-run.sh`, deploy and
  `DESIGN.md` (W10.11.6, W10.11.7, W10.11.11)
- `runtime/reviewer/` (prompt, `review.sh`, eval) and any wall on design findings
- Changes to `tokens-check.mjs`, `design-md-check.mjs` or `render-check.mjs`, including reading
  Tailwind's `(--name)` shorthand (a finding)
- A check for CSS-in-JS, for classes Tailwind can't build, or for the motion rule
- A route that copies components without the CLI, unless the owner won't allow `ui.shadcn.com`
- A Next.js build in the devshop's CI
