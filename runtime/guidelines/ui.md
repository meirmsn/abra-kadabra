# UI guideline

For any change with a user interface (TARGET § L3 Build 8; spec
[`ui-baseline.md`](../../specs/ui-baseline.md)). Stack homes say how on their stack; this says what.
The project's own rules win on conflict; say so in the PR.

## The baseline

- **Responsive, designed phone first:** one column at 375 px, wider from 768 px, more columns from
  1280 px. Nothing scrolls sideways; text lines stay readable (`--measure`).
- **Light and dark:** the system setting by default, and a theme control that overrides it both
  ways and is remembered in that browser. Its shape is the project's, in `DESIGN.md` (a button that
  cycles, one button per choice, a menu): mark the control, or the group holding its buttons, with
  `[data-theme-toggle]`. The render check tests only the outcome; the project's own tests prove
  how its control behaves.
- **Start from [`runtime/templates/ui/`](../templates/ui/)** when the project has no baseline yet:
  - `base.css` and `theme.js`: copy them; the project owns them (its colours, more components).
    Load `theme.js` in `<head>` as a plain script, or inline it, so there's no flash of the wrong
    theme. [`example.html`](../templates/ui/example.html) shows every piece in use.
  - `tokens-check.mjs` and `render-check.mjs`: copy them unchanged into `scripts/ui/`; they are
    optional `devshop` copies in the project contract, so session start reports drift and a newer
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

## Design direction (once per product)

A project with a UI and no `DESIGN.md` gets its design direction as its own slice, the second
after the walking skeleton and before any slice that styles a page beyond the baseline
(`devshop:split`; [spec](../../specs/big-changes-in-slices.md)). The skeleton ships on the baseline
above, so the project has a preview to publish the direction's pages on. The slice runs gstack's
`/design-consultation` and lands `DESIGN.md` and the theme CSS in one PR, whose spec records
`DESIGN.md` as the decision (the reviewer judges a change that adds it against the head's).

- **Unattended where it can be:** product questions are answered from the plan document; the
  owner answers the memorable-thing question and makes the picks. No Codex or other outside voice,
  no learnings from other projects, and no write to `CLAUDE.md` (the project's own; the skill
  offers one with `DESIGN.md`).
- **Published, not opened:** with no design binary the skill writes one self-contained HTML
  preview with the real faces and palette and runs `open`, which does nothing here. Publish that
  page where the project's previews publish, or as a private page, and send the owner the link.
- **Variants, then the pick:** two or three hand-built HTML variants with the real tokens, distinct
  directions (if the headline could be swapped between two without anyone noticing, they are too
  alike), on one published page. The owner picks and comments; iterate if asked. The pick and its
  reasons go in `DESIGN.md`'s decisions log. Variants of a single screen later: only when the
  owner asks, while that slice is sharpened; the pick then feeds its core flow and states.
- **`DESIGN.md` as the skill writes it,** with its tokens and the derived theme CSS under the
  baseline's names (`tokens-check.mjs` and the reviewer read those), and fonts self-hosted as the
  stack home says. Never gstack's image binary or its comparison board (an OpenAI key and a
  server on 127.0.0.1, F-NEW-87).

## Design review (before `ship`)

`build` runs gstack's `/design-review` on every change that changes what a page renders (markup,
styles, scripts a page loads, its assets), after its tests pass and before `devshop:pr`
([spec](../../specs/design-review-in-build.md)). It is feedback, not a wall.

- **Not without `DESIGN.md`:** no `DESIGN.md` in the project, no run; the PR's line says so.
- **On a local run:** commit first (it needs a clean tree), start the app with the project's
  `scripts/local-run.sh` (`PORT=<free port> scripts/local-run.sh`, the one way to run the site
  locally; the project contract lists it), and run it with `http://127.0.0.1:<port>`, scoped to the
  pages the change touches (not its diff-aware mode, which takes no URL and looks only on ports
  3000, 4000 and 8080). No `scripts/local-run.sh`: it can't run, and the PR's line says so.
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

## The reviewer's browser (a local run)

The independent reviewer judges a UI change in a browser when the project declares
`scripts/local-run.sh` ([spec](../../specs/reviewer-browser.md); how it runs:
[the reviewer's README](../reviewer/README.md#the-local-run-and-the-browser)). Without it, the
reviewer reviews UI by reading.

- **The script** serves the site on `127.0.0.1:$PORT` (bound to that address explicitly, not
  `localhost`, which may be `::1` only) and runs until stopped, e.g.
  `exec python3 -m http.server --bind 127.0.0.1 "$PORT"` for static files, or the stack's dev
  server with its host and port flags. It runs from the repo root with the session's
  `node_modules`; it installs nothing and reaches no other host.
- **Same origin only:** the reviewer's browser blocks every other origin, so a page that needs a
  CDN font or script shows without it (fonts are listed as "remote font not loaded"). A redirect to
  another host or port is a page that doesn't load.
- **`DESIGN.md` at the base commit** is what the reviewer judges against: a change that edits it
  records that as a decision in its spec.
