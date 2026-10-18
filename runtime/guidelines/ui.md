# UI guideline

For any change with a user interface (TARGET § L3 Build 8; spec
[`ui-baseline.md`](../../specs/ui-baseline.md)). Stack homes say how on their stack; this says what.
The project's own rules win on conflict; say so in the PR.

## The baseline

- **Responsive, designed phone first:** one column at 375 px, wider from 768 px, more columns from
  1280 px. Nothing scrolls sideways; text lines stay readable (`--measure`).
- **Light and dark:** the system setting by default, and a theme toggle (`[data-theme-toggle]`)
  that overrides it and is remembered in that browser.
- **Start from [`runtime/templates/ui/`](../templates/ui/)** when the project has no baseline yet:
  - `base.css` and `theme.js`: copy them; the project owns them (its colours, more components).
    Load `theme.js` in `<head>` as a plain script, or inline it, so there's no flash of the wrong
    theme. [`example.html`](../templates/ui/example.html) shows every piece in use.
  - `tokens-check.mjs` and `render-check.mjs`: copy them unchanged into `scripts/ui/`; a newer
    devshop version's upgrade re-copies them.
- **Tokens only:** colours, radius and spacing come from the theme's tokens (shadcn/ui's names);
  name only tokens the theme defines, for light and dark (L-78). A new colour gets a light and a
  dark value.

## Every control (L-72)

Looks tappable (never plain text), at least 44 × 44 px, reacts on hover, shows the press at once,
disables at once while working with a spinner only after a delay, and restores on failure. The
baseline sets these once (`button`, `.btn`, `:active`, `aria-busy`); don't redo them per component.

## Checks

- **Fast tier:** `node scripts/ui/tokens-check.mjs --theme <theme.css> <files…>`: every `var()` is
  defined in both themes, the dark rules agree, and colour pairs reach 4.5:1.
- **Slow tier:** `node scripts/ui/render-check.mjs --url <page> --out <dir>` on each changed page
  (served locally or the preview): at 375, 768 and 1280 px in both system themes it checks
  overflow, contrast as painted, 44 px targets, the pressed state, the toggle and a widening
  `<main>`. It needs Playwright pinned in the project's `package.json` and that version's Chromium
  installed in the slow CI job (`npx playwright install --with-deps chromium`).
- Either exits 2 when it can't judge; that's never a pass.
- **The PR** carries the six screenshots it writes (`<width>-<theme>.png`), pinned to the commit.

## Design review (before `ship`)

`build` runs gstack's `/design-review` on every change that changes what a page renders (markup,
styles, scripts a page loads, its assets), after its tests pass and before `devshop:pr`
([spec](../../specs/design-review-in-build.md)). It is feedback, not a wall.

- **Not without `DESIGN.md`:** no `DESIGN.md` in the project, no run; the PR's line says so.
- **On a local run:** commit first (it needs a clean tree), start the app locally as the project's
  `CLAUDE.md` or stack home says, and run it with that URL, scoped to the pages the change touches
  (not its diff-aware mode, which takes no URL and looks only on ports 3000, 4000 and 8080).
- **Unattended:** its questions don't go to the owner. No test framework bootstrap, no edits to
  `CLAUDE.md` or `TESTING.md`, no `DESIGN.md` written, no `TODOS.md` step, no Codex or other
  outside voice (the code stays in the session), no learnings from other projects.
- **Fixes only what the change built:** a finding on the pages and lines the change touches is
  fixed under `build` § 3 (its commit subjects, tests edited when behaviour changes), not in
  gstack's commit format; anything else is logged, not fixed. A fix that would change a spec
  decision or acceptance item goes to the owner (`intent` step 5). Then run the new and affected
  tests and the fast checks again.
- **Its findings, like the reviewer's:** High is fixed before `ship`; one that can't be (outside
  the change, or a spec change) is a `med` row the owner is asked about. Medium left unfixed is a
  `med` row, Polish a `low` row in `FINDINGS.md`, committed before `ship`.
- **On the PR,** under Evidence: `**Design review:**` design score and AI-slop score before → after,
  findings fixed and logged, for commit `<sha>`; run again on a later round that changes what a
  page renders, and rewrite the line. Can't run (no browser, the app won't start, the skill fails):
  the line says why, and the owner hears it with the PR's link. Its browser is the image's
  Chromium, which the bootstrap sets as `GSTACK_CHROMIUM_PATH`. _Mitigation:_ gstack's browser
  check (`gstack-browser-ensure`) ignores that variable, so the skill prints `NEEDS_SETUP` though
  its browser works: with the variable set, drive `$B` directly; never run gstack's `./setup` or ask
  the owner to (its download is blocked). Root cause: that check in the pinned gstack, F-NEW-101.
