# Every web app starts from a design baseline: responsive, light and dark

**Go:** pending

## Intent

A page the v2 Build skill produced on the fixture was functional but bare: plain HTML, no layout, no
theme. The owner wants every app the devshop builds to start from a design baseline: responsive
pages, phone first ("the owner works from a phone"); light and dark themes following the system
setting; a modern component and design baseline as the default, possibly shadcn/ui. After the
options: "we should do A, and if [the fixture is] staying for the future, we do B or C once we
decide in M2", built "after 10.6.4", then "we should do the work on this session, i will merge once
10.6.4 is done". On the summary: "i think we should have the manual theme toggle in the default,
just in case" and "should be responsive, not just phone" (owner, 2026-10-13).

## Decisions

- Option A: a stack-agnostic plain-CSS baseline every web app starts from, which works in apps that
  render HTML strings with no front-end build step, like the fixture. Whether React stack homes use
  shadcn/ui directly (B) or a shadcn-style library without React such as Basecoat (C) is decided at
  M2 with the Next.js home. The fixture stays a Workers app that renders HTML strings, because the
  Next.js home is its decoy; rejected: moving the fixture to React (owner, 2026-10-13)
- Token names are shadcn/ui's (`--background`, `--foreground`, `--card`, `--primary`,
  `--secondary`, `--muted`, `--accent`, `--destructive`, `--border`, `--input`, `--ring`,
  `--radius`, each colour with its `-foreground` pair where shadcn/ui has one), with OKLCH values,
  so a React app adopting shadcn/ui at M2 keeps the same names and one token check covers both.
  Rejected: our own names (a rename at M2) (Claude's proposal, 2026-10-13)
- The theme follows the system by default, and a theme toggle in the default page lets the viewer
  override it (owner, 2026-10-13). The toggle cycles system → light → dark → system and names the
  current choice; the choice is kept in the viewer's browser (`localStorage`, every access in
  `try`/`catch`, so a blocked store just means "system"); a small `theme.js`, inlined in `<head>`,
  sets `data-theme` on `<html>` before the first paint so there is no flash. Without JavaScript
  the page follows the system. CSS: light values on `:root`; dark values on `:root[data-theme="dark"]`
  and, identically, on `:root:not([data-theme="light"])` inside `@media (prefers-color-scheme:
dark)`. A system font stack, no web fonts (nothing to fetch, nothing for a sandbox to block)
  (Claude's proposal for the mechanism, 2026-10-13)
- Responsive across phone, tablet and desktop, not just phone (owner, 2026-10-13): one column on a
  phone, the page column widening and cards flowing into two columns from 768 px and three from
  1280 px, with a maximum line length for text. Checked at 375, 768 and 1280 px (Claude's proposal
  for the widths, 2026-10-13)
- `base.css` styles plain elements and a few classes, no build step: the responsive page column,
  a header with the theme toggle, cards, a list, buttons (primary, secondary,
  destructive), form fields with labels, and the L-72 control contract as global rules: 44 px
  minimum size, `touch-action: manipulation`, a hover change, a pressed state on `:active`, a
  visible focus ring, and disabled and busy (`aria-busy`) looks (Claude's proposal, 2026-10-13)
- Where it lives: the rules in the cross-platform guideline `runtime/guidelines/ui.md` (TARGET
  Build 8; it replaces the guidelines README's example name `ui-ux.md`), which the `build` skill
  already loads for UI changes; the files in `runtime/templates/ui/`. Rejected: a stack home, since
  the baseline is not tied to one stack (TARGET Reach 1) (Claude's proposal, 2026-10-13)
- Ownership: a project copies `base.css` and `theme.js` and owns them (its own colours, more components). The two
  check scripts are copied unchanged into the project's `scripts/ui/`, so a plain clone runs its
  own CI without the devshop (TARGET Shape 3); a later devshop version's upgrade step re-copies
  them. Their tests stay in the devshop. The project pins Playwright in its own `package.json` and
  its slow CI job installs that version's Chromium (Claude's proposal, 2026-10-13)
- Both checks are Node scripts, the one runtime every web project already has: a token check
  (static, a project's fast tier) and a render check (a browser, a project's slow tier). The
  reviewer judging the screenshots waits for M2, when it gets a browser. Rejected: a Python token
  check (a second runtime) (Claude's proposal, 2026-10-13)
- Token check rules. The scan is text, over any file type (CSS, HTML, TS), for `var(--name`. A
  token is defined only by the theme file. The theme file's shape is strict: declarations in a
  top-level rule whose selector is exactly `:root` are light; the top-level rule
  `:root[data-theme="dark"]` and the rule `:root:not([data-theme="light"])` inside an `@media`
  whose condition is exactly `(prefers-color-scheme: dark)` are dark, and must declare the same
  tokens with the same values; comments are ignored; any other block in the theme that declares a
  custom property makes the check exit 2 (a shape it can't judge). A colour token is one whose value is an OKLCH, hex, `rgb()` or `hsl()` colour, or
  a `var()` of a colour token; `var()` values resolve within the theme before contrast. A
  `var(--` not followed by a literal name (built at runtime) is a finding: the check can't see it
  (Claude's proposal, 2026-10-13)
- Contrast, at least 4.5:1 (WCAG AA body text): in the token check, `--foreground` on
  `--background`, `--muted-foreground` on `--background`, and each `--X-foreground` on its `--X`,
  in both themes; a colour with alpha in a pair makes it exit 2; out-of-gamut OKLCH is clipped to
  sRGB per channel. In the render check, every visible text against its effective background as
  the browser paints them (3:1 for large text: 24 px, or 18.66 px bold), which also catches
  hard-coded colours (Claude's proposal, 2026-10-13)
- Render check, theme and layout: the page background differs between system light and system
  dark; the toggle (`[data-theme-toggle]`, a visible control) overrides the system both ways and
  its choice survives a reload; the page has a `<main>` that is wider at 1280 px than at 375 px
  (Claude's proposal, 2026-10-13)
- Render check definitions. A control is `a[href]`, `button`, `input` (not hidden), `select`,
  `textarea`, `summary` or `[role=button]`; a checkbox or radio is measured by its label when it
  has one. Visible: rendered with a non-zero box, not `visibility: hidden`, not `opacity: 0`.
  Exempt from the size rule: a link inside a sentence (WCAG 2.5.8), meaning its parent element
  also has non-whitespace text of its own. Overflow: horizontal scroll (`scrollWidth` beyond the
  viewport), or any visible element reaching past the viewport's left or right edge, so
  `overflow-x: hidden` can't hide it. The pressed state: pressing a button changes its computed
  style. Measured after `document.fonts.ready`. `file://` URLs work (Claude's proposal,
  2026-10-13)
- Playwright pinned to 1.56.1: the version whose Chromium (build 1194) cloud sessions have
  preinstalled under `PLAYWRIGHT_BROWSERS_PATH`, so a session never downloads a browser (seen
  2026-10-13). This repo's slow CI job runs `npm ci` and installs that version's Chromium (Claude's
  proposal, 2026-10-13)
- Timing: built and shipped now; the owner merges after W10.6.4, the north-star run, so the run
  measures the devshop it started on. The fixture's page is restyled in its own later task, with
  the owner's OK, after W10.6.4; the owner then tags a new reset baseline (owner, 2026-10-13)

## Acceptance items

- **AC-1** `tokens-check.mjs --theme <theme.css> <files…>` exits 0 when every `var(--name)` in the
  given files and the theme is defined by the theme for both themes and every contrast pair
  passes; exits 1, naming the token and the rule, for each of: a `var()` of a token the theme
  doesn't define (a fallback value doesn't excuse it); a colour token defined for light but not
  dark; a token defined only for dark; the two dark rules differing (a token missing from one, or
  another value); a contrast pair below 4.5:1 in either theme, including one
  reached through a `var()` value; a `var(--` with no literal name; and exits 2 on a missing file,
  a theme with no `:root` rule or either dark rule missing, a theme block of another shape declaring a
  custom property, or a colour in a contrast pair it can't parse or that has alpha. Comments
  containing `:root {` don't count. Shown by a test feeding each case
- **AC-2** `base.css` passes `tokens-check.mjs` with `example.html` and `theme.js`, and
  `example.html` uses every primitive above: page column, header with the theme toggle, card, list, the three button kinds, a disabled and a busy
  button, a labelled text field, select, checkbox and textarea, and a link inside a sentence.
  Shown by a test
- **AC-3** `render-check.mjs --url <url> --out <dir>` loads the page at 375 px (phone emulation),
  768 px and 1280 px, each with the system in light and in dark, and exits 0 on `example.html`;
  exits 1, naming the rule, the width and the element, for each of: no viewport meta; horizontal
  scroll; an element past the edge hidden by `overflow-x: hidden`; the same page background in
  both system themes; no theme toggle; a toggle that doesn't override the system in either
  direction; a choice that doesn't survive a reload; no `<main>`, or one no wider at 1280 px than
  at 375 px; text below its contrast
  threshold (e.g. a hard-coded dark text colour in dark mode); a visible control smaller than 44 ×
  44 px, including a row of short links in a nav; a button with no pressed state; it doesn't flag a
  link inside a sentence; and exits 2 when Playwright can't be loaded, the browser can't start,
  the page fails to load or answers 400 or above, or the page throws an error. Shown by a test
  feeding a page with each fault
- **AC-4** The render check writes six full-page screenshots to `<dir>`, `<width>-<theme>.png` for
  widths 375, 768 and 1280 and themes `light` and `dark` (system setting, no override). Shown by
  the same test
- **AC-5** `runtime/guidelines/ui.md` says, in one page: designed phone first, both themes following
  the system with a toggle to override it; responsive from phone to desktop; start from `runtime/templates/ui/` and which files the project owns; use only tokens
  the theme defines; the L-72 control contract; run the two checks (pinned Playwright, slow tier)
  and put the six screenshots in the PR — verified by review: reading the file
- **AC-6** The `build` skill's existing disciplines line tells a UI change in a project without
  the baseline to start from `/opt/devshop-current/templates/ui/`, within one page, and
  `skills-check.py` passes (it checks the path exists). Shown by `tests/skills-check.test.sh`
- **AC-7** This repo: `package.json` pins Playwright 1.56.1; the render test is marked slow and
  CI's `slow` job runs `npm ci` and installs that version's Chromium; the guidelines README and
  the docs map name the new files; the workstream file has the task lines (this slice, the fixture
  restyle after W10.6.4, the M2 decision on B or C, the reviewer's browser) — verified by review:
  reading the diff
- **AC-8** The baseline is shown on a real page: `example.html` at 375, 768 and 1280 px in both
  themes, rendered by `render-check.mjs` on the final code, sent to the owner in the session and
  committed in a spike folder and embedded in the PR body by commit (the upload route of W10.6.9
  isn't usable from a cloud session yet; owner, 2026-10-13: "just do what you said for now") —
  verified by review: the six screenshots

## Core flow

1. A builder makes a UI change in a project without the baseline and copies the templates.
2. They build the page with the theme's tokens and run the token check, then the render check.
3. The PR carries the six screenshots.

## Out of scope

- Restyling the fixture's page: its own task after W10.6.4, with the owner's OK
- shadcn/ui or Basecoat in any stack home, and the Next.js and Cloudflare homes: M2
- The reviewer judging screenshots in a browser: M2
- A full accessibility audit (axe); native (iOS) themes
