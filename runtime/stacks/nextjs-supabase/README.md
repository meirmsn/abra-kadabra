# Next.js + Supabase

**A placeholder except § UI.** The rest of this home is written with the first project that ships
on the stack (W10.11.11). Until then, outside § UI, a project on this stack gets no stack-specific
guidance from here: follow the project's own `CLAUDE.md` and docs, and say in the PR that this home
is a placeholder.

It loads for a Next.js or Supabase project and never for a project that only has a `package.json`
(a Cloudflare Workers project, say): `tests/decoy-stack.test.sh` proves both sides. A Next.js app on
Workers through the OpenNext adapter has a wrangler config too, so the
[Cloudflare home](../cloudflare/README.md) loads beside this one.

## UI: shadcn/ui on the baseline's tokens

What a React page here is built from, for the [design](../../guidelines/design.md) and
[UI](../../guidelines/ui.md) guidelines ([spec](../../../specs/react-home-ui-defaults.md); what it
rests on: the [spike](../../../kit/notes/revamp/spikes/react-home/README.md)). The project's own
`DESIGN.md` and rules win on conflict; say so in the PR.

**The versions are the project's.** Tailwind v4 is the styling layer and shadcn/ui the components.
The project pins `shadcn`, `tailwindcss`, `@tailwindcss/postcss` and `tw-animate-css` in its
`package.json`, exact, and moves them when it chooses. This home proved `shadcn` 4.23.0,
`tailwindcss` and `@tailwindcss/postcss` 4.3.3 and `tw-animate-css` 1.4.0, with Next.js 16.2.4.

**Placing the files:** `/opt/devshop-current/stacks/nextjs-supabase/place.sh <project>` places
`app/globals.css` (the theme), `public/theme.js` (the baseline's toggle script),
`scripts/ui-tokens.sh` and the three devshop check copies under `scripts/ui/`. Each file on its own:
a missing one is placed, an identical one left alone, one that differs shown as a diff and never
touched (exit 1). It doesn't touch `scripts/check-fast.sh` or `scripts/check-slow.sh`.

**Adding a component:** `/opt/devshop-current/stacks/nextjs-supabase/shadcn-add.mjs <project>
<component>...`. shadcn/ui's npm package is a command that downloads each component from
`ui.shadcn.com`, which cloud sessions block, as the site is that day. This script reads the
project's exact `shadcn` version and copies each component from shadcn/ui's GitHub release tag
`shadcn@<version>` (the new-york-v4 style), with the components, hooks and `lib/utils.ts` it
imports. It rewrites their imports to `@/components/ui/`, `@/hooks/` and `@/lib/utils` and installs
the packages they import with `npm install --save-exact`. `lib/utils.ts` re-exports `cn` from
shadcn/ui's `cn` package. A file that differs is shown and nothing is written (exit 1); a re-add is a
diff you make on purpose. There is no `components.json`, and `shadcn init` or `shadcn add` is never
run: they write shadcn/ui's own theme and `.dark` blocks into `app/globals.css`. A component's own
colour tokens (the sidebar's, the chart's) aren't copied: they go into `DESIGN.md` as a decision and
into the theme in the change that adds the component.

**The theme is one file, `app/globals.css`, and `THEME_CSS` names it.** In order: the imports of
Tailwind and `tw-animate-css`; the `dark` variant; the bridge; the baseline's three token rules
(`:root`, `:root[data-theme="dark"]`, `:root:not([data-theme="light"])` in the dark media query);
the project's `@font-face` rules; the base layer. Until the design-direction slice derives the token
rules from `DESIGN.md`, they are `base.css`'s. One file, so a token block anyone writes into it is
where `tokens-check.mjs` and `design-md-check.mjs` look: they read it as they read `base.css`.

- **The bridge** (`@theme inline`) adds the theme's tokens to Tailwind: `--color-<name>` for each
  colour token, `--radius-sm` to `-xl` as `var(--radius)` (a `DESIGN.md` that adds `rounded.<k>`
  points that step at `--radius-<k>`), and `--spacing: var(--space-1)`, so Tailwind's scale is
  multiples of `DESIGN.md`'s step `1`. A new colour token gets its bridge line in the same change.
  Tailwind's own palette stays, so an off-design class like `bg-gray-500` still paints: the reviewer
  finds it as a value `DESIGN.md` doesn't name. A class naming a token the bridge lacks paints
  nothing, without a word.
- **Spacing in the components:** inside `components/ui/`, a multiple of `--space-1` (`h-9`,
  `px-2.5`) counts as derived; the project's own code uses the steps `DESIGN.md` names.
- **Dark mode:** the `dark` variant names the baseline's two dark selectors, so `dark:` classes
  follow the token rules. shadcn/ui's `.dark` class isn't used.
- **The base layer** sets 44 px on the button, input and select-trigger slots (shadcn/ui's button
  is 36 px tall, and the render check fails it), the baseline's busy state on the button slot, the
  reduced-motion rule, the body's colours and font, and the border colour.

**The toggle:** `<script src="/theme.js">` in the root layout's `<head>`, before the first paint,
with `@next/next/no-sync-scripts` disabled on that line and its reason, and the page's nonce if the
project's content-security policy uses one; `suppressHydrationWarning` on `<html>`. The control is a
shadcn/ui `Button` with `data-theme-toggle` and `suppressHydrationWarning`, in the root layout:
`theme.js` labels it only when it first runs and on a click, and the root layout persists across
client navigation. Not `next-themes`.

**Fonts:** self-hosted woff2 under `public/fonts/` with their licence file, `@font-face` in
`app/globals.css` with `font-display: swap`, preloaded in the root layout; each font token names its
face, then a generic family. Not `next/font`: it puts the token on a generated class the checks
can't see, with a family list `DESIGN.md` can't name.

**Styles in stylesheets:** Tailwind's compiled stylesheet; no CSS-in-JS library and no
`<style jsx>`, which the design review's detector can't read.

**Motion is the project's call,** in `DESIGN.md`'s motion section: whether it animates, where, and
with what. The default is shadcn/ui's `tw-animate-css`, so dialogs and menus open as shadcn/ui ships
them; a project that wants none removes the import and the package. `prefers-reduced-motion` is
respected either way.

**The fast tier:** the project's `scripts/check-fast.sh`, from the template, sets
`THEME_CSS="app/globals.css"` and gains one stack part:

```bash
part scripts/ui-tokens.sh "$THEME_CSS" components/ui
```

`ui-tokens.sh` runs `tokens-check.mjs` with the theme over every tracked `*.css`, `*.ts`, `*.tsx`,
`*.jsx` and `*.mdx` file except the theme and `components/ui/`. _Mitigation:_ `components/ui/` is
left out because its components put variables Radix or their inline styles set at run time inside
`var()`, which the check would report as undefined; root cause: `tokens-check.mjs` reads every
`var()` as a theme token. Its colours, radius and spacing reach a page through the bridge, which is
checked. The template's design part runs `design-md-check.mjs` once `DESIGN.md` exists.

**The slow tier:** the project's `scripts/check-slow.sh` runs
`node scripts/ui/render-check.mjs --url <page> --out <dir>` on every path in `quality/routes.json`,
over `scripts/local-run.sh` on a free local port, as the Cloudflare home's quality bar does, waiting
for `/` to answer (not `/build.txt`). A signed-in page renders the sign-in page it redirects to, so
the list holds public pages. On a Workers app the local run is the OpenNext build and `wrangler dev`.

**An existing app adopts in two steps.** Its own theme almost surely fails `tokens-check.mjs`, and
adoption needs both tiers green. So: adopt with `THEME_CSS` empty and without the `ui-tokens.sh`
line; then, in its design-direction slice, move the theme to the baseline's names with `DESIGN.md`
and add the line. `place.sh` shows what to merge.

**No `supplies` file.** On Workers the Cloudflare home already supplies `render-check.mjs` and
`scripts/local-run.sh`; a missing token check copy makes `ui-tokens.sh` exit 2, and a missing
`design-md-check.mjs` makes the template's design part exit 2 once `DESIGN.md` exists. A `supplies`
line would also reach a Supabase project with no web page.
