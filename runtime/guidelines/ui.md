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
