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
tokens. Every "spike:" below points at a row there. The adversarial review's findings were checked
and folded in; what only the owner can decide is in the four open questions named below.

## Decisions

- **The pin: the `shadcn` CLI at 4.23.0, exact; the committed copies are the record.** shadcn/ui is
  not a runtime library: its CLI copies component source into the project, which owns it from then
  on. A project on this stack pins `shadcn` `4.23.0` in `devDependencies` (the latest on
  2026-11-02, published 2026-10-27) and runs that local binary (`npx shadcn add <name>`, never
  `shadcn@latest`), with `tailwindcss` and `@tailwindcss/postcss` `4.3.3`. The CLI's version pins
  how a component is fetched and rewritten, not its source: it reads the registry at
  `ui.shadcn.com` as it is that day, so the copy committed in `components/ui/` is what the project
  runs, and a re-added component is a diff to review. The home's `.npmrc` (`save-exact=true`) makes
  every dependency the CLI or a session adds (`radix-ui`, `class-variance-authority`, `clsx`,
  `tailwind-merge`, `lucide-react`, …) an exact version. `components.json` is placed from the home's
  template, never written by `shadcn init`, which would write shadcn/ui's own theme over the
  home's: `style` `new-york` (what the pinned CLI picks for a Tailwind v4 project; its sources are
  `new-york-v4` in shadcn/ui's repository), `rsc` and `tsx` true, `tailwind.config` empty,
  `tailwind.css` `app/globals.css`, `tailwind.baseColor` `neutral` (required by the CLI's schema;
  only `init` reads it), `tailwind.cssVariables` true, `tailwind.prefix` empty, `iconLibrary`
  `lucide`, the aliases `components` `@/components`, `ui` `@/components/ui`, `lib` `@/lib`, `utils`
  `@/lib/utils`, `hooks` `@/hooks` (spike: the pinned CLI's own schema accepts it). Moving the CLI's
  pin is a change of its own. Rejected: Basecoat (spec A, the owner's call 3); `shadcn@latest` (the
  fetch and rewrite would change under the project too) (Claude's proposal, 2026-11-02; open
  question 1)
- **The CLI needs `ui.shadcn.com` (open question 1).** That host is denied by this environment's
  network policy (spike: the proxy answered 403), so the home's set-up gains an owner's step: allow
  `ui.shadcn.com` in the network policy of the project's cloud environment; the session checks it
  with `curl -sI https://ui.shadcn.com/` answering. Where it isn't allowed, `shadcn add` can't run
  and the change says so plainly; the home names no hand-copy route, which would be a mechanical
  step outside a tested script. Rejected for now: a tested script that copies a component from
  shadcn/ui's GitHub source at the CLI's tag (`apps/v4/registry/new-york-v4/ui/<name>.tsx`, which
  answers here). It would pin the source too and need no new host, but it is a second component
  route to build and prove, and it would redo by hand the CLI's dependency and alias handling. The
  owner's call: allow the host and keep the CLI (Claude's recommendation), or the script (Claude's
  proposal, 2026-11-02)
- **How a project gets the home's files: a tested script (owner, "2. A", 2026-11-03).** The home's files
  (`globals.css`, `components.json`, `.npmrc`, `check-fast.sh`, `check-slow.sh`) and the
  baseline's `theme.js` are not in `runtime/project-files.txt`, whose seeds every project gets at
  init whatever its stack. Claude's recommendation: a tested script in the home,
  `runtime/stacks/nextjs-supabase/place.sh <project>`, which copies each file to its path
  (`app/globals.css`, `components.json`, `.npmrc`, `scripts/check-fast.sh`,
  `scripts/check-slow.sh`, `public/theme.js`), leaves an identical file alone, and refuses a file
  that exists and differs, naming it, without touching any file (exit 1; exit 2 on a project that
  isn't a directory or a home file it can't read). A project that already holds the template's
  `check-fast.sh` gets the home's lines merged by hand in that change, which the refusal names. The
  upgrade doesn't show when a home's file changes: a `low` row in `FINDINGS.md`, with a stack-scoped
  manifest as its fix. Rejected: a table in the README for a session to copy from (a mechanical
  step in prose); a stack-scoped manifest now (a change to init, the upgrade and the contract, not
  this one's) (Claude's proposal, 2026-11-02)
- **Tailwind v4 is the styling layer; the theme is one file, `app/globals.css`.** The home's
  `globals.css` holds, in this order: `@import 'tailwindcss'`; the `dark` variant; the bridge; the
  three token rules; the `@font-face` rules once the project has faces; the base layer. The home's
  `check-fast.sh` sets `THEME_CSS="app/globals.css"`. One file because shadcn/ui's CLI writes a
  component's tokens into the file `components.json` names: with that file the theme, a `.dark`
  block it writes makes `tokens-check.mjs` exit 2 and a light-only token is a finding in both checks
  (spike). The checks read the file as they read `base.css`: their reader skips `@theme inline`'s
  declarations (no rule inside), the variant's rules declare nothing, and `@font-face` holds no
  custom property (spike; the review confirmed it in the reader). The token rules are `base.css`'s
  three rules verbatim, so a project with no `DESIGN.md` has the baseline as its design (`ui.md`);
  the direction slice changes their values to `DESIGN.md`'s. Rejected: a separate `theme.css`
  imported by `globals.css` (passes too, spike, but a `.dark` block the CLI writes into
  `globals.css` goes unseen); shadcn/ui's own theme (`:root` plus `.dark`: `tokens-check.mjs` can't
  judge it, spike) (Claude's proposal, 2026-11-02)
- **The bridge: only the theme's values reach a utility.** In `@theme inline` (`inline`: a utility
  reads `var(--<name>)` itself):
  - colours: `--color-*: initial`, then `--color-<name>: var(--<name>)` for each colour token, a
    token in `:root` whose whole value is hex or `oklch()`, and no other `--color-` entry. Clearing
    the palette makes a class naming a colour the theme lacks (`text-white`, `bg-red-500`) compile
    to nothing (spike);
  - radius: `--radius-*: initial`, then `--radius-sm`, `-md`, `-lg` and `-xl` (the steps the copies
    use), each `var(--radius-<k>)` when the theme declares that token and `var(--radius)` when it
    doesn't. The baseline's theme has only `--radius`, so all four are `var(--radius)`; a
    `DESIGN.md` that adds `rounded.<k>` gets `--radius-<k>` in the theme (spec C) and its bridge line
    in the same change, so the copies paint only radii `DESIGN.md` names. Rejected: shadcn/ui's
    `calc(var(--radius) ± 2px or 4px)` (lengths `DESIGN.md` doesn't name);
  - spacing: `--spacing: var(--space-1)`, so Tailwind's scale is multiples of `DESIGN.md`'s step `1`
    and `p-4` is `--space-4` while the steps are linear, as the baseline's are. The copies size
    their parts by that scale (`h-9`, `px-2.5`, `gap-1.5`), and clearing it would collapse them. So
    a copy's dimension is a multiple of a named step, which `design.md` would call a value
    `DESIGN.md` doesn't name. The home says a multiple of `--space-1` inside the copies is
    derived, and the project's own code uses the named steps (owner, "3. A (just because B makes it
    unusuable which seems lke a no go)", 2026-11-03);
  - fonts: `font-sans` and `font-mono` read the theme's `--font-sans` and `--font-mono`, whose
    unlayered `:root` values win over Tailwind's defaults (spike); a role face beyond them gets
    `--font-<role>: var(--font-<role>)`, whose self-reference Tailwind emits only in its theme layer,
    where the theme's value wins (spike);
  - shadows and the type scale stay Tailwind's: `DESIGN.md` has no shadow group, and its
    typography roles' sizes are prose to the shape check (spec C), as the baseline's own sizes are.

  The cost, said plainly: Tailwind skips a class it can't build without a word, so a class naming a
  token the bridge lacks paints nothing; no check sees the class, the render check and the reviewer
  see its effect. `tokens-check.mjs` doesn't read Tailwind's `(--name)` shorthand either. Both go to
  `FINDINGS.md` as one `low` row (Claude's proposal, 2026-11-02)

- **The copies' palette classes get their token from the base layer.** At the pin, the new-york-v4
  sources name the palette four ways (read from the tag): `text-white` on the destructive `button`
  and `badge`, `bg-white` on the `slider-thumb`, `bg-black/50` on the `dialog`, `alert-dialog`,
  `sheet` and `drawer` overlays. With the palette cleared those classes paint nothing, so a
  destructive label would inherit `--foreground` on `--destructive`. The base layer gives
  `[data-slot='button'][data-variant='destructive']` and
  `[data-slot='badge'][data-variant='destructive']` `color: var(--destructive-foreground)`, and
  `[data-slot='slider-thumb']` `background-color: var(--background)`. The overlays' scrim has no
  token in the baseline: the change that adds the first overlay adds a scrim colour to `DESIGN.md`
  (a decision) and its base-layer rule; until then an overlay has no scrim. The home's README lists
  the four classes at the pin, and a later pin re-reads them. Rejected: mapping `--color-white` and
  `--color-black` to tokens (a white that is not white in dark); editing the copies (a diff on every
  re-add) (Claude's proposal, 2026-11-02)
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

  so shadcn/ui's `dark:` classes follow the same rules as the tokens (spike: both compile);
  shadcn/ui's `.dark` class is not used. `theme.js` is copied unchanged to `public/theme.js` and
  loaded by `<script src="/theme.js">` in the root layout's `<head>`, a plain script before the
  first paint, with the `@next/next/no-sync-scripts` lint rule disabled on that line and its reason;
  under a content-security policy that uses a nonce, the layout passes it to that tag. `<html>`
  carries `suppressHydrationWarning`, since `theme.js` sets `data-theme` before React hydrates. The
  toggle is a shadcn/ui `Button` with `data-theme-toggle` and `suppressHydrationWarning`, rendered
  by a server component in the root layout: `theme.js` labels it only when it first runs and on a
  click, and the root layout's markup is the one part of the page that persists across client
  navigation, so a toggle anywhere else would show the server's label after a navigation. Spike:
  the render check's toggle rule passes both ways and after a reload. Rejected: `next-themes`
  (shadcn/ui's suggestion; a second toggle beside the tested `theme.js`); an inline copy of
  `theme.js` (a second copy that drifts from the baseline's, where the file stays byte-identical)
  (Claude's proposal, 2026-11-02)

- **Controls: 44 px and the baseline's busy state, without editing the copies.** shadcn/ui's sizes
  are under 44 px (its button is 36 px tall: spike, `target-size` on every button without the rule).
  The base layer sets `min-height: var(--tap)` on `[data-slot='button']`, `[data-slot='input']` and
  `[data-slot='select-trigger']`, and `min-width: var(--tap)` on `[data-slot='button']`; a minimum
  overrides a utility's smaller `height` whatever the layer. The copies carry hover, focus-visible,
  disabled and a pressed change of their own (spike: the render check's pressed rule passes on the
  default and outline buttons); the base layer adds `base.css`'s busy rules (`aria-busy`, the
  delayed spinner and its two keyframes) for `[data-slot='button']`, and `base.css`'s reduced-motion
  rule, the body's background, text colour and font, and the border colour. Smaller controls
  (checkbox, switch, radio) are the project's; the render check finds them. Rejected: editing each
  copy's classes (a diff on every re-add) (Claude's proposal, 2026-11-02)
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
- **Motion (open question 4).** One authored moment per page, named in `DESIGN.md`'s motion
  section (`design.md`): on this stack it is CSS (`@keyframes` and its rule in a stylesheet), or a
  block copied from a kit's source with the kit's licence file whose imports are React and the
  project's own; a block that imports `motion` or `framer-motion` brings a motion kit as a
  dependency and isn't used. `tw-animate-css`, the package shadcn/ui's overlays and accordion take
  their enter and exit classes from, is not added: without it those classes compile to nothing and
  the overlays open without animation, the baseline's behaviour. Rejected: adding it (a motion pack
  as a dependency) (Claude's proposal, 2026-11-02)
- **The fast tier: the home's `check-fast.sh`.** It is the template's with three places filled:
  `THEME_CSS="app/globals.css"`; `TOKENS_SKIP`, beside it; and the stack part. The stack part runs
  `node scripts/ui/tokens-check.mjs --theme "$THEME_CSS"` over every file `git ls-files` lists as
  `*.css`, `*.ts`, `*.tsx`, `*.jsx` or `*.mdx`, except the theme itself and the files in
  `TOKENS_SKIP`. _Mitigation:_ `TOKENS_SKIP` lists the copies that, at the pin, put a variable
  their library or their own inline style sets at run time inside `var()`:
  `components/ui/navigation-menu.tsx` and `components/ui/select.tsx` (Radix's), and
  `components/ui/sidebar.tsx` and `components/ui/toggle-group.tsx` (their own). The check would
  report those as undefined tokens. Root cause: `tokens-check.mjs` reads every `var()` name as a
  theme token and has no way to know a runtime variable. Every other copy, edited or not, is
  checked. A missing `scripts/ui/tokens-check.mjs` is "couldn't run", exit 2, never a finding (`node`
  on a missing file exits 1); so is `git ls-files` failing, and the check's own exit 2 when the list
  is empty. The design part is the template's, unchanged. A project with `src/` sets `THEME_CSS`,
  `TOKENS_SKIP` and `components.json`'s paths to match. A test holds the home's file equal to the
  template outside those three places, so a template change reaches it. Rejected: wiring
  `tokens-check.mjs` into the template (the owner kept it out at spec C's go); skipping all of
  `components/ui/` (copies edited to use an undefined token would go unchecked) (Claude's proposal,
  2026-11-02)
- **The slow tier: the home's `check-slow.sh`.** It starts `scripts/local-run.sh` on a free local
  port in its own process group, waits up to `LOCAL_RUN_WAIT` seconds (default 300) for any HTTP
  answer at `/`, then runs `node scripts/ui/render-check.mjs --url http://127.0.0.1:<port><path>
--out <SHOTS_DIR>/<slug>` for every path in `quality/routes.json` (a JSON list of paths starting
  with `/`, the Cloudflare home's name for it; `SHOTS_DIR` defaults to `ui-shots`), every path even
  after one fails, stops the server's group and exits with the worst. A path's slug is `root` for
  `/`; otherwise the path without its leading and trailing `/`, each `/` turned into `__` and each
  character outside `A-Za-z0-9._-` into `-`. It exits 2, never 0, when `scripts/local-run.sh` is
  missing or not executable, the render check's copy is missing, `quality/routes.json` is missing,
  unreadable, not a list, empty, holds a path without a leading `/` or two paths with one slug, or
  the server exits or doesn't answer in time (its log's last lines printed). The project's own
  end-to-end tests go below a marked line. A signed-in page renders the sign-in page it redirects
  to; the list holds public pages until W10.11.9's authenticated step. What `scripts/local-run.sh`
  runs stays the project's (on the pilot web app, the OpenNext build and `wrangler dev`, written
  with W10.11.6). **On a project both homes load** (the pilot web app has a `wrangler.jsonc`, so the
  Cloudflare home applies too): this file is its `check-slow.sh`, and the Cloudflare home's quality
  bar (the page check, Lighthouse, the byte budget), which that home describes for a static site and
  has no template of, joins it below the marked line when W10.11.6 or W10.11.11 writes it for a
  Next.js app; its `/build.txt` wait is the static site's and doesn't apply. Rejected: the
  Cloudflare home's broken-page proof in the seed (a served Next.js page can't be edited per run;
  the devshop's slow test proves the render check fails a broken page through this script instead)
  (Claude's proposal, 2026-11-02)
- **`supplies`:** `scripts/ui/tokens-check.mjs`, `scripts/ui/render-check.mjs` and
  `scripts/local-run.sh`, the three the home's tiers run every time. Not
  `scripts/ui/design-md-check.mjs`: `DESIGN.md` is optional on every stack (spec C), `supplies`
  can't say "once a `DESIGN.md` exists", and the fast tier's part already makes a missing copy
  "couldn't run" once one does. What it does: session start reports a missing one for every project
  the home loads for, from the devshop version that carries this file; CI's contract check runs
  without `supplies`, so CI is unchanged (feedback, not a wall). So the pilot web app's adoption
  (W10.11.6) brings the three with it or its sessions name them as missing until it does; and a
  Supabase project with no web page would be asked for them too. None exists today; the day one
  does, the home's `detect` splits. A `low` row in `FINDINGS.md` (Claude's proposal, 2026-11-02)
- **The home's README:** the placeholder line narrows to "placeholder except § UI" (W10.11.11
  writes the rest from what ships), and a `## UI: shadcn/ui on the baseline's tokens` section says
  the decisions above in the home's words: the pins, `place.sh` and what it places where, the
  bridge, the palette classes at the pin, the toggle, controls, fonts, motion, the two tiers and the
  two-homes order, the owner's set-up step and its check, and a link to the spike record.
  `runtime/stacks/README.md`'s line for the home says the same in one clause (Claude's proposal,
  2026-11-02)
- **Docs, in files this change owns:** `design.md` § Components and motion's "The Next.js home pins
  the version" links the home's section; `ui.md` § The baseline's "Start from
  `runtime/templates/ui/`" bullet gains that a Next.js project takes the home's `globals.css` in
  place of `base.css` (one clause); `docs/README.md` links the spike record and the new tests;
  W10.8.3 and W10.11.7 get dated notes; `kit/notes/revamp/LOG.md` an entry. No shipped spec is
  edited (LOG #95) (Claude's proposal, 2026-11-02)
- **The proof:** `tests/nextjs-home.test.sh` (fast) and `tests/nextjs-home-render.test.sh` (slow,
  the real render check in Chromium); every case prints `react-home-ui-defaults AC-<n>`. The fast
  test runs the home's real files with the real `tokens-check.mjs` and `design-md-check.mjs` in a
  scratch git project, with stubs for the non-UI parts; the slow test serves pages from a fake
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
- **AC-2** Its bridge holds `--color-*: initial` and exactly one `--color-<name>: var(--<name>)` for
  each `:root` token whose whole value is hex or `oklch()`, and no other `--color-` entry;
  `--radius-*: initial` and `--radius-sm`, `-md`, `-lg` and `-xl` each `var(--radius)`;
  `--spacing: var(--space-1)`; its `dark` variant is the text quoted in Decisions
- **AC-3** Its base layer holds `min-height: var(--tap)` for the button, input and select-trigger
  slots and `min-width: var(--tap)` for the button's; `color: var(--destructive-foreground)` for the
  destructive button and badge; `background-color: var(--background)` for the slider thumb;
  `base.css`'s busy rules for the button slot; and `base.css`'s reduced-motion rule
- **AC-4** The home's `check-fast.sh` is the template's `check-fast.sh` but for the `THEME_CSS` line
  (`app/globals.css`), the `TOKENS_SKIP` line (the four copies) and the stack part
- **AC-5** In a scratch git project with the home's `check-fast.sh`, its `globals.css` as
  `app/globals.css` and the real token check: the tier passes, with `tokens-check.mjs` given
  `--theme app/globals.css` and the tracked `*.css`, `*.ts`, `*.tsx`, `*.jsx` and `*.mdx` files
  except the theme and `TOKENS_SKIP`; a `components/ui/select.tsx` using `var(--radix-…)` passes;
  the tier fails (exit 1, every other part still run) on a page using a token the theme lacks, a
  copy under `components/ui/` outside `TOKENS_SKIP` doing the same, a bridge entry naming a token
  the theme lacks, and a light-only colour added to `:root`; it can't run (exit 2) on a `.dark`
  block in the theme, a missing `scripts/ui/tokens-check.mjs`, a missing theme, and no git
  repository
- **AC-6** The same project with `tests/fixtures/design-md/baseline/DESIGN.md` as its `DESIGN.md`
  and the real `design-md-check.mjs`: the tier passes; with a colour token added to the theme's
  `:root` and both dark rules that the `DESIGN.md` doesn't name, it fails with
  `theme-not-in-design`
- **AC-7** The home's `check-slow.sh` with a stub render check and a `scripts/local-run.sh` serving
  files on `127.0.0.1:$PORT`: each path in `quality/routes.json` is rendered with
  `--url http://127.0.0.1:<port><path>` and `--out <SHOTS_DIR>/<slug>` by the slug rule (`/` is
  `root`, `/a/b/` is `a__b`); a path whose check exits 1 fails the tier and every path still runs;
  one that exits 2 makes it exit 2; it exits 2 with no `scripts/local-run.sh`, no render check copy,
  no `quality/routes.json`, one that isn't a JSON list, an empty list, a path without a leading `/`,
  two paths with one slug, a server that exits at once and one that never answers within
  `LOCAL_RUN_WAIT`; the server no longer answers once the tier ends
- **AC-8** With the real render check in Chromium, the home's `check-slow.sh` over a
  `scripts/local-run.sh` serving the baseline's example page passes and leaves the six screenshots;
  with that page's viewport meta removed it fails (exit 1)
- **AC-9** `runtime/stacks/nextjs-supabase/supplies` names `scripts/ui/tokens-check.mjs`,
  `scripts/ui/render-check.mjs` and `scripts/local-run.sh` and nothing else; it parses against the
  real contract, and a project it applies to that lacks one of them is red
- **AC-10** The home's `components.json` is valid JSON with the fields and values Decisions lists,
  and its `.npmrc` is `save-exact=true`; the home's README names `shadcn` `4.23.0`, `tailwindcss`
  and `@tailwindcss/postcss` `4.3.3`, and the owner's step for `ui.shadcn.com`
- **AC-11** How a project gets the home's files, as the owner's answer to open question 2 decides
  (with Claude's recommendation: `place.sh` places each file at its path in an empty project, leaves
  identical files alone, refuses a differing file naming it and touching nothing with exit 1, and
  exits 2 on a missing project)
- **AC-12** The home's README § UI, `runtime/stacks/README.md`, `design.md` § Components and
  motion, `ui.md` § The baseline and `docs/README.md` say what Decisions says, including the fonts,
  motion, CSS-in-JS and toggle rules; `design.md` stays within 120 lines and 1200 words;
  `scripts/docs-map-check.py` passes; no file under `specs/` other than this one changes — verified
  by review: the diff and CI on the PR's head
- **AC-13** `tests/run.sh` passes with the two new test files in it, and the PR's Evidence lists
  each new rule's mutant and the case that killed it — verified by review: the Evidence section and
  CI on the PR's head
- **AC-14** `kit/notes/revamp/LOG.md` has an entry; W10.8.3 and W10.11.7 carry dated notes;
  `FINDINGS.md` has the three `low` rows Decisions names (silent Tailwind classes and the shorthand,
  the `supplies` reach, the upgrade not showing a home's file) — verified by review: the diff

## Out of scope

- The pilot web app's repo: its `components.json`, `globals.css`, `scripts/local-run.sh`, deploy and
  `DESIGN.md` (W10.11.6, W10.11.7, W10.11.11)
- `runtime/reviewer/` (prompt, `review.sh`, eval) and any wall on design findings
- Changes to `tokens-check.mjs`, `design-md-check.mjs` or `render-check.mjs`, including reading
  Tailwind's `(--name)` shorthand or knowing runtime variables (findings)
- A check for CSS-in-JS, for classes Tailwind can't build, or for the motion rule
- A route that copies components without the CLI, unless the owner picks it (open question 1)
- A stack-scoped manifest for the upgrade (a finding)
- A Next.js build in the devshop's CI
