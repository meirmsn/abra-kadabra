# The React home's UI defaults: shadcn/ui on the baseline's tokens, at each project's own version

**Go:** "Go with all 10." (owner, 2026-11-04, on the second review's ten changes; the four questions answered 2026-11-03: "1. B", "2. A", "3. A", and motion as the project's call)

## Intent

Spec D of the UI tooling strategy the owner accepted on 2026-10-31 ("agree with your 4 recs"; the
order A, B, C, then D). The owner asked (2026-11-02): "D the React home's defaults at M3", whose job
spec A's decisions name: "React stack homes use shadcn/ui, the theme CSS derived by hand from
`DESIGN.md`'s tokens under the baseline's token names so one `tokens-check` covers both, styles in
stylesheets (the detector's DOM mode can't see CSS-in-JS); the Next.js home pins the library at
M3", and spec C left to it: "the stack home fills `THEME_CSS` in its `check-fast.sh` and wires all
three UI checks (`tokens-check.mjs`, `design-md-check.mjs`, `render-check.mjs`) on its stack". The
spec must settle the library pin, Tailwind's role, where the theme lives and how `THEME_CSS` names
it, the derivation under the three selectors the checks require, the theme toggle, the wiring of
the tiers and `supplies` ("or say why not"), "styles in stylesheets, no CSS-in-JS; one authored
motion moment per page as `design.md` says; fonts self-hosted", and "every check is proven to fail".
Out of scope by the owner's words: "the reviewer's prompt, any wall on design findings, the pilot
web app's own repo (this change edits only the devshop)". Workstream lines W10.8.3 and W10.11.7;
roadmap R-7 (M3) stays open. Surface: none; this change renders no page of a product.

The owner then set two principles (2026-11-03): "each project should use whatever version of shadcn
they want, not depend on the devshop for that", and on motion, "Roughly speaking the Dev Shop maybe
give some defaults, but definitely each project should know you know if he wants animations or
not". After a second adversarial review asked for "practicality and simplicity and what we
ultimately want to achieve with the dev shop of working on multiple projects", the owner took all
ten of its changes ("Go with all 10.", 2026-11-04): this spec is the smaller version that leaves.

Why: the pilot web app (Next.js with Supabase and Tailwind v4, on Workers through the OpenNext
adapter, W10.11.2) is the first React project. Without a home that says how shadcn/ui's theme takes
the baseline's shape, its UI work would start from shadcn/ui's own theme (`:root` plus a `.dark`
class), which `tokens-check.mjs` can't judge, and its fast tier would run none of the UI checks.

The experiment came first: [the spike record](../kit/notes/revamp/spikes/react-home/README.md)
(2026-11-02), a scratch Next.js app with Tailwind v4 and a shadcn/ui button on the baseline's
tokens. Every "spike:" below points at a row there.

## Decisions

- **The version is the project's; a devshop script copies components at it.** shadcn/ui's `shadcn`
  package on npm is a command with no component in it: it downloads each one from `ui.shadcn.com`
  as the site is that day, a host cloud sessions block (spike). A project pins its own version as
  `shadcn` in its `package.json`, exact; the home names `4.23.0`, the version the spike read, as a
  starting point. The devshop's tested
  `runtime/stacks/nextjs-supabase/shadcn-add.mjs <project> <component>...`, run from the session's
  devshop copy, reads that version and fetches each component's source from shadcn/ui's release
  tag `shadcn@<version>` on GitHub (`apps/v4/registry/new-york-v4/ui/<name>.tsx`), which sessions
  reach. It follows the file's own imports, with no registry index to parse: an import of
  `@/registry/new-york-v4/ui/<other>` copies that component too, of `…/hooks/<name>` the hook, and
  of `…/lib/utils` or the bare `cn` module shadcn/ui's sources use the `cn` helper
  (`lib/utils.ts`); each is rewritten to the project's `@/components/ui/`, `@/hooks/` and
  `@/lib/utils`. Any other package it imports that the project's `package.json` lacks (`react`,
  `react-dom` and `next` aside) is installed with `npm install --save-exact`. It writes
  `components/ui/`, `hooks/` and `lib/` at the project's root. A file that exists and differs is
  shown as a diff and nothing is written (exit 1), so a re-add is a diff the builder makes on
  purpose. It exits 2, never 0, on no `package.json`, no `shadcn` in it, a range or tag in place of a
  version, a component the tag lacks, an `@/` import it doesn't know, a file it can't fetch, or a
  failed install. A component's own colour tokens aren't copied: the theme's tokens come from
  `DESIGN.md`. `SHADCN_SOURCE` overrides the source's base (with `{version}` in it) for its tests.
  No `components.json` and no `shadcn init`: the command isn't run, and `init` or `add` would write
  shadcn/ui's theme and `.dark` blocks into the project's. Rejected: the command with
  `ui.shadcn.com` allowed per environment; a devshop-wide version; reading the registry's
  TypeScript index or its JSON index (a parser to keep up with upstream, and the JSON index is
  style-neutral: it names no `radix-ui` for the button) (owner, "1. B", 2026-11-03, and "Go with all
  10.", 2026-11-04)
- **How a project gets the home's files: `place.sh`, file by file.** The home's tested
  `runtime/stacks/nextjs-supabase/place.sh <project>` places `app/globals.css` (the home's),
  `public/theme.js` (the baseline's), `scripts/ui-tokens.sh` (the home's) and the three devshop
  copies `scripts/ui/tokens-check.mjs`, `render-check.mjs` and `design-md-check.mjs`, each on its
  own: a missing file is placed (scripts keep their executable bit), an identical one left alone, and
  one that differs is shown as a diff and left untouched while the others are placed; exit 1 when
  any differed, 0 otherwise, 2 on a project that isn't a directory or a source it can't read. So on
  an existing app (the pilot web app has its own `app/globals.css`) it places what's missing and
  shows what to merge. It never edits `scripts/check-fast.sh` or `scripts/check-slow.sh`, which every
  project already has from the templates. The upgrade doesn't show when a home's file changes: a
  `low` row in `FINDINGS.md` (owner, "2. A", 2026-11-03, and "Go with all 10.", 2026-11-04)
- **Tailwind v4 is the styling layer; the theme is one file, `app/globals.css`.** In this order:
  `@import 'tailwindcss'`; `@import 'tw-animate-css'` (the motion default below); the `dark`
  variant; the bridge; the three token rules; the project's `@font-face` rules; the base layer.
  `THEME_CSS="app/globals.css"`. One file so a token block written into it by hand or by a tool is
  where the checks look: a `.dark` block makes `tokens-check.mjs` exit 2 and a light-only token is a
  finding (spike). The checks read it as they read `base.css`: their reader skips `@theme inline`'s
  declarations, the variant's rules declare nothing, `@font-face` holds no custom property (spike;
  the first review confirmed it in the reader). The token rules are `base.css`'s three rules
  verbatim, so a project with no `DESIGN.md` has the baseline as its design; the direction slice
  changes their values. Rejected: a separate `theme.css` (a block written into `globals.css` goes
  unseen); shadcn/ui's own theme (`tokens-check.mjs` can't judge it, spike) (Claude's proposal,
  2026-11-02)
- **The bridge adds the theme's tokens to Tailwind and takes nothing away.** In `@theme inline`
  (a utility reads `var(--<name>)` itself): `--color-<name>: var(--<name>)` for each colour token, a
  token in `:root` whose whole value is hex or `oklch()`; `--radius-sm`, `-md`, `-lg` and `-xl`, the
  steps the components use, each `var(--radius)` (a `DESIGN.md` that adds `rounded.<k>` points that
  step at `--radius-<k>` in the same change); `--spacing: var(--space-1)`, so Tailwind's scale is
  multiples of `DESIGN.md`'s step `1`. Tailwind's palette, shadows and type scale stay: the pilot
  web app already uses Tailwind v4, and clearing the palette would make its existing colour classes
  paint nothing. The cost: a palette class off the design still paints; the reviewer finds a value
  `DESIGN.md` doesn't name (`design.md`). A class naming a token the bridge lacks compiles to
  nothing without a word, and `tokens-check.mjs` doesn't read Tailwind's `(--name)` shorthand: one
  `low` row in `FINDINGS.md`. Inside `components/ui/`, a multiple of `--space-1` (the components'
  `h-9`, `px-2.5`) counts as derived; the project's own code uses the named steps (owner, "3. A",
  2026-11-03). Fonts: `font-sans` and `font-mono` read the theme's tokens, whose unlayered `:root`
  values win over Tailwind's defaults; a role face gets `--font-<role>: var(--font-<role>)` (spike)
  (Claude's proposal, 2026-11-02; the palette kept: owner, "Go with all 10.", 2026-11-04)
- **Dark mode and the toggle.** The variant is exactly:

  ```css
  @custom-variant dark {
    &:where([data-theme='dark'], [data-theme='dark'] *) {
      @slot;
    }
    @media (prefers-color-scheme: dark) {
      &:where(
        :root:not([data-theme='light']),
        :root:not([data-theme='light']) *
      ) {
        @slot;
      }
    }
  }
  ```

  so the components' `dark:` classes follow the token rules' selectors (spike); shadcn/ui's `.dark`
  class is not used. `theme.js` (placed at `public/theme.js`) is loaded by `<script src="/theme.js">`
  in the root layout's `<head>`, before the first paint, the `@next/next/no-sync-scripts` lint rule
  disabled on that line with its reason, and given the page's nonce where the project's
  content-security policy uses one; `<html>` carries `suppressHydrationWarning`. The toggle is a
  shadcn/ui `Button` with `data-theme-toggle` and `suppressHydrationWarning`, in the root layout,
  which persists across client navigation (`theme.js` labels it only when it first runs and on a
  click). Spike: the render check's toggle rule passes both ways and after a reload. Rejected:
  `next-themes` (a second toggle beside the tested `theme.js`) (Claude's proposal, 2026-11-02)

- **The base layer:** `min-height: var(--tap)` on `[data-slot='button']`, `[data-slot='input']`
  and `[data-slot='select-trigger']`, `min-width: var(--tap)` on `[data-slot='button']` (shadcn/ui's
  button is 36 px tall; spike: `target-size` fails on every button without it); `base.css`'s busy
  rules (`aria-busy`, the delayed spinner, its two keyframes) for `[data-slot='button']`;
  `base.css`'s reduced-motion rule; the body's background, text colour and font; the border colour.
  Hover, focus, disabled and pressed come with the components (spike: the pressed rule passes)
  (Claude's proposal, 2026-11-02)
- **Fonts self-hosted, as plain `@font-face`:** woff2 under `public/fonts/` with the licence file,
  `font-display: swap`, preloaded in the root layout; each font token names its face, then a generic
  family (F-NEW-90). Rejected: `next/font` (spike: the token lands on a generated class outside the
  three rules, with a family list `DESIGN.md` can't name) (Claude's proposal, 2026-11-02)
- **Styles in stylesheets:** Tailwind's compiled stylesheet; no CSS-in-JS library and no
  `<style jsx>`. A rule the reviewer sees in the diff, not a check (Claude's proposal, 2026-11-02)
- **Motion is the project's call; the home gives the default.** Whether a project animates, where,
  and with what dependency is its decision in `DESIGN.md`'s motion section. The home's default is
  shadcn/ui's: `tw-animate-css` (CSS only, MIT, no dependencies; the home names `1.4.0`), imported
  in `app/globals.css`, so dialogs and menus open as shadcn/ui ships them; a project that wants none
  removes it. `prefers-reduced-motion` is respected either way. `design.md`'s motion bullet says
  that, with no count of moments, and "a motion kit as a dependency" leaves its Never list ("the
  same entrance on every page" and `transition: all` stay). Rejected: spec A's "no motion kit as a
  dependency" (Claude's reading of the owner's "selective motion blocks", which the owner didn't
  recognise) (owner, 2026-11-03, and "Go with all 10.", 2026-11-04)
- **The fast tier: one line in the project's own `check-fast.sh`.** The home's tested
  `scripts/ui-tokens.sh <theme.css> <library dir>` runs `node scripts/ui/tokens-check.mjs --theme
<theme.css>` over every file `git ls-files` lists as `*.css`, `*.ts`, `*.tsx`, `*.jsx` or `*.mdx`,
  except the theme and the library directory; the project's `check-fast.sh` (from the template)
  sets `THEME_CSS="app/globals.css"` and calls it as a stack part:
  `part scripts/ui-tokens.sh "$THEME_CSS" components/ui`. The template's design part runs
  `design-md-check.mjs` once `DESIGN.md` exists, unchanged. _Mitigation:_ the library directory is
  left out because its components use variables Radix or their own inline styles set at run time
  (`var(--radix-select-trigger-height)`, spike), which the check would report as undefined; root
  cause: `tokens-check.mjs` reads every `var()` as a theme token. The components' colours, radius
  and spacing reach a page through the bridge, which is checked. It exits 2, never a finding, on a
  missing argument, a missing theme or `scripts/ui/tokens-check.mjs`, or `git ls-files` failing;
  the check's own exits pass through. Rejected: a forked `check-fast.sh` in the home (two files to
  keep equal) (owner, "Go with all 10.", 2026-11-04)
- **The slow tier is a paragraph, not a template.** The project's `check-slow.sh` runs
  `render-check.mjs` on every path in `quality/routes.json` over `scripts/local-run.sh`, as the
  Cloudflare home's quality bar does, waiting for `/` to answer rather than for `/build.txt`. The
  pilot web app loads both homes, and its real slow tier (the OpenNext build and `wrangler dev`) is
  W10.11.6's to write; the Cloudflare home has no template either (owner, "Go with all 10.",
  2026-11-04)
- **No `supplies`, and why not.** For the pilot web app the Cloudflare home already supplies
  `render-check.mjs` and `local-run.sh`; a missing token check copy already makes the fast tier exit
  2 through `ui-tokens.sh`, and the template's design part does the same for `design-md-check.mjs`
  once `DESIGN.md` exists. A `supplies` line would also reach a Supabase project with no web page,
  and would report before an app adopts (owner, "Go with all 10.", 2026-11-04)
- **An existing app adopts in two steps.** The pilot web app's own theme almost surely fails
  `tokens-check.mjs`, and its adoption (W10.11.6) needs both tiers green. So: adopt with `THEME_CSS`
  empty and the `ui-tokens.sh` line out; move the theme to the baseline's names, with `DESIGN.md`, in
  its direction slice (W10.11.7), and add the line there. `place.sh` shows what to merge (owner, "Go
  with all 10.", 2026-11-04)
- **The home's README:** the placeholder line narrows to "placeholder except § UI" (W10.11.11 writes
  the rest), and `## UI: shadcn/ui on the baseline's tokens` says the decisions above in the home's
  words: the versions are the project's (with the ones the home proved), `place.sh` and
  `shadcn-add.mjs`, the bridge, the toggle, the base layer, fonts, motion, the fast-tier line, the
  slow tier, the adoption order, why no `supplies`, and a link to the spike record.
  `runtime/stacks/README.md`'s line for the home says the same in one clause (Claude's proposal,
  2026-11-02)
- **Docs, in files this change owns:** `design.md` § Components and motion says each project pins
  its own shadcn/ui version as the Next.js home describes (for spec A's "the Next.js home pins the
  version"), and its motion bullet and Never list change as Motion says; `ui.md` § The baseline's
  "Start from `runtime/templates/ui/`" bullet gains that a Next.js project takes the home's files
  through `place.sh`; `docs/README.md` links the new test; W10.8.3 and W10.11.7 get dated notes;
  `kit/notes/revamp/LOG.md` an entry. No shipped spec is edited (LOG #95) (Claude's proposal,
  2026-11-02)
- **The proof:** `tests/nextjs-home.test.sh`, fast, every case printing
  `react-home-ui-defaults AC-<n>`: the home's real `globals.css` with the real `tokens-check.mjs`
  and `design-md-check.mjs` in a scratch git project run through the real template `check-fast.sh`
  with the one line added (stubs for its non-UI parts), `place.sh` on scratch projects, and
  `shadcn-add.mjs` against synthetic component sources in a local directory with a stub `npm`. The
  PR's Evidence records each new rule's mutant and the case that killed it, and a re-run of the
  spike's build and render check with the final `globals.css` (Claude's proposal, 2026-11-02;
  scaled down: owner, "Go with all 10.", 2026-11-04)
- **Not here:** the pilot web app's repo; a forked `check-fast.sh`, a `check-slow.sh` template,
  `components.json`, `.npmrc` and `supplies` (cut by the go); the reviewer's prompt; a wall on design
  findings; changes to the three checks; a CSS-in-JS check; F-NEW-81, 82 and 90 into `ui.md`

## Acceptance items

- **AC-1** The home's `globals.css`: its three token rules are `runtime/templates/ui/base.css`'s
  three token rules, text for text; it declares custom properties only in those rules and in
  `@theme inline`; `tokens-check.mjs --theme` on it exits 0, and `design-md-check.mjs --theme` on it
  with `tests/fixtures/design-md/baseline/DESIGN.md` exits 0
- **AC-2** It opens with `@import 'tailwindcss'` then `@import 'tw-animate-css'`; its bridge holds
  exactly one `--color-<name>: var(--<name>)` for each `:root` token whose whole value is hex or
  `oklch()`, no other `--color-` entry and no `--color-*: initial`, `--radius-sm`, `-md`, `-lg` and
  `-xl` each `var(--radius)`, and `--spacing: var(--space-1)`; its `dark` variant is the text quoted
  in Decisions; its base layer holds `min-height: var(--tap)` for the button, input and
  select-trigger slots, `min-width: var(--tap)` for the button's, `base.css`'s busy rules for the
  button slot and `base.css`'s reduced-motion rule
- **AC-3** In a scratch git project whose `scripts/check-fast.sh` is the template's with
  `THEME_CSS="app/globals.css"` and the one `ui-tokens.sh` line, the home's `globals.css` as
  `app/globals.css` and the real token check: the tier passes, with `tokens-check.mjs` given
  `--theme app/globals.css` and the tracked `*.css`, `*.ts`, `*.tsx`, `*.jsx` and `*.mdx` files
  except the theme and `components/ui/`; a `components/ui/` file using `var(--radix-…)` passes; the
  tier fails (exit 1, every other part still run) on a page using a token the theme lacks, a bridge
  entry naming a token the theme lacks, and a light-only colour added to `:root`; `ui-tokens.sh`
  exits 2 on a `.dark` block in the theme, a missing `scripts/ui/tokens-check.mjs`, a missing theme,
  a missing argument, and no git repository
- **AC-4** The same project with `tests/fixtures/design-md/baseline/DESIGN.md` as its `DESIGN.md`
  and the real `design-md-check.mjs`: the tier passes; with a colour token added to the theme's
  `:root` and both dark rules that the `DESIGN.md` doesn't name, it fails with
  `theme-not-in-design`
- **AC-5** `place.sh <project>` on an empty project places the six files at their paths, the
  scripts executable, and exits 0; run again it changes nothing and exits 0; with one file present
  and different it shows that file's diff, leaves it untouched, places the others, and exits 1; on a
  path that isn't a directory it exits 2
- **AC-6** `shadcn-add.mjs`, with `SHADCN_SOURCE` pointing at synthetic sources and a stub `npm`:
  it reads the project's exact `shadcn` version and fetches from that version's directory; it
  copies a component, a component it imports, a hook it imports and `lib/utils.ts`, with the
  imports rewritten to `@/components/ui/`, `@/hooks/` and `@/lib/utils`; it installs the imported
  packages the project lacks with `--save-exact`, once, and none it already has; with a differing
  file already present it shows the diff, writes nothing, runs no install, and exits 1; it exits 2
  with no `package.json`, no `shadcn` in it, a range in place of a version, a component the source
  lacks, an unknown `@/` import, and a failed install
- **AC-7** The home's README § UI says the versions are the project's (naming `shadcn` `4.23.0`,
  `tailwindcss` and `@tailwindcss/postcss` `4.3.3` and `tw-animate-css` `1.4.0` as the ones it
  proved), the fast-tier line, the slow tier, the adoption order, the toggle, fonts, motion and why
  no `supplies`; `runtime/stacks/README.md`, `design.md` § Components and motion and its Never list,
  `ui.md` § The baseline and `docs/README.md` say what Decisions says; `design.md` stays within 120
  lines and 1200 words; `scripts/docs-map-check.py` passes; no file under `specs/` other than this
  one changes — verified by review: the diff and CI on the PR's head
- **AC-8** `tests/run.sh` passes with the new test file in it, and the PR's Evidence lists each new
  rule's mutant and the case that killed it, and the spike's build and render check re-run with the
  final `globals.css` — verified by review: the Evidence section and CI on the PR's head
- **AC-9** `kit/notes/revamp/LOG.md` has an entry; W10.8.3 and W10.11.7 carry dated notes;
  `FINDINGS.md` has the two `low` rows Decisions names (silent Tailwind classes and the shorthand;
  the upgrade not showing a home's file) — verified by review: the diff

## Out of scope

- The pilot web app's repo: its theme, `check-fast.sh`, `check-slow.sh`, `scripts/local-run.sh`,
  deploy and `DESIGN.md` (W10.11.6, W10.11.7, W10.11.11)
- `runtime/reviewer/` (prompt, `review.sh`, eval) and any wall on design findings
- Changes to `tokens-check.mjs`, `design-md-check.mjs` or `render-check.mjs` (reading Tailwind's
  `(--name)` shorthand, knowing runtime variables: findings)
- The `shadcn` command, `components.json`, other shadcn/ui styles and bases
- A forked `check-fast.sh`, a `check-slow.sh` template, `supplies`, `.npmrc`
- A Next.js build in the devshop's CI (the spike's re-run is the build's evidence)
