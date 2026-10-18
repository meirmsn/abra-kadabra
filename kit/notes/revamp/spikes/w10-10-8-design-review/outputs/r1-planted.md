# Round 1, planted run (2026-10-17)

The helper's hand-back, sections 1 (gstack's final report), 3 (git state) and 5 (failed steps), as
returned. Its section 2 listed the skill's questions and how it resolved each without asking
anyone; section 4 the files it wrote outside git (gstack's state under `~/.gstack/`, the repo's
ignored `.gstack/`, screenshots in the scratchpad) and "nothing was sent to Codex or any other
outside service". It could not write `FINDINGS.md` (a subagent's report-file write is refused by the
harness), so it returned the rows as text.

## gstack's final report

```
# Design audit: http://127.0.0.1:8102/ (home page only)

Branch `feat/notes`, base `main`. Scope: index.html, the page the Notes change touches. Final commit `4dc1ba4`.
Driver: gstack's own headless browser (`$B`, Chromium at GSTACK_CHROMIUM_PATH); Aside not available on Linux.
Calibrated against DESIGN.md (format: spec; front-matter tokens normative).
Detector: not installed (impeccable engine not present; install offer declined, unattended run).
Outside voices: not run (devshop guideline: no Codex or other outside voice).

## First impression

- The site communicates **a calm, plain household task list**.
- I notice **the Notes panel breaks the page's voice**: it is the only serif text on the page and its heading is hot magenta.
- The first 3 things my eye goes to are: **"This week"**, **the magenta "Notes" heading**, **the blue "See tasks" button**. Notes is not meant to be the second loudest thing; the hierarchy lies.
- One word: **tidy-but-interrupted**.

Page area test: header (site + theme), week summary (three cards), Notes, Tasks, New task form, footer. All nameable in 2 s.

Classifier: OPERATE (app UI). Trunk test: PARTIAL (site ID, page name, options clear; no nav or search, which a one-page app does not need).

## Inferred design system (rendered)

- Fonts: system stack (all sections) plus `"Comic Neue", cursive` on .notes, which is not installed and rendered as Times New Roman.
- Colours: all DESIGN.md tokens, plus `rgb(255, 0, 170)` (#ff00aa) on the Notes heading.
- Headings: h1 36px/700, every h2 18px/700. DESIGN.md heading weight is 650.
- Spacing: all on the --space-* scale except .notes padding 13px.

## Findings

### FINDING-001 (High, Typography): Notes renders in an undeclared font
`.notes { font-family: 'Comic Neue', cursive }`. DESIGN.md: system font stack only. Not installed, so it fell back to Times New Roman serif; on machines that have Comic Neue it renders a Comic family face.
Fix: removed the declaration; the section inherits the body stack.
Status: verified. Commit `030b3a1`. Files: notes.css. Before: notes-light-before.png. After: finding-001-after.png.

### FINDING-002 (High, Color): Notes heading in an off-palette magenta
`.notes h2 { color: #ff00aa }`. DESIGN.md: "No other colour appears on a page", primary is the one accent. Same magenta in dark mode (no dark value). It also made Notes the second loudest element.
Fix: removed the colour; the heading inherits --foreground like the other h2s (light oklch(0.21 0.02 260), dark oklch(0.96 0.005 250)).
Status: verified. Commit `f231441`. Files: notes.css. Before: notes-light-before.png, notes-dark-before.png. After: finding-002-after.png, finding-002-after-dark.png.

### FINDING-003 (Medium, Spacing): Notes padding off the spacing scale
`.notes { padding: 13px }`, not on the 4 px scale; Notes text sat 3px left of the summary cards' text edge (190 vs 193 px).
Fix: `padding: var(--space-4)`. Measured after: padding 16px, Notes text x = 193 = card text x.
Status: verified. Commit `4dc1ba4`. Files: notes.css. After: finding-003-after.png.

### FINDING-004 (Medium, Typography): heading weight is 700, DESIGN.md says 650
All h1/h2 compute to 700 (base.css `h1, h2` sets no weight). Outside the change: logged, not fixed.
Status: deferred (outside the change).

### FINDING-005 (Polish, Performance): console 404 on page load
One `Failed to load resource: 404` on every load (no favicon is served). Outside the change: logged, not fixed.
Status: deferred (outside the change).

## Interaction flow

Theme toggle: system → light → dark → system, label updates each step, no new console errors. Goodwill 70 → 75 (+5 obvious primary actions). Notes has no interaction.

## Responsive

375 / 768 / 1280 captured before and after. No horizontal scroll at 375 (scrollWidth 375). Notes stacks cleanly at every width.

## Scores

| Category | Before | After |
|---|---|---|
| Visual hierarchy | A | A |
| Typography | C+ | A- |
| Spacing & layout | A- | A |
| Color & contrast | B | A |
| Interaction states | A | A |
| Responsive | A | A |
| Content | A | A |
| AI slop | A | A |
| Motion | A | A |
| Performance feel | A | A |

Design score: A- → A. AI slop score: A → A (system-ui is DESIGN.md's declared stack, so not a slop finding).

## Quick wins
1. Set `font-weight: 650` on `h1, h2` in base.css to match DESIGN.md (FINDING-004).
2. Serve a favicon or a `<link rel="icon" href="data:,">` to clear the console 404 (FINDING-005).

## Summary

- Total findings: 5
- Fixes applied: verified 3, best-effort 0, reverted 0
- Deferred: 2 (outside the change)
- Design score: A- → A
- AI slop score: A → A
- Detector: not installed

PR summary: Design review found 5 issues, fixed 3. Design score A- → A, AI slop score A → A.
```

## Git state

```
4dc1ba4 fix: Notes panel padding is on the spacing scale
f231441 fix: Notes heading uses the text colour, not off-palette magenta
030b3a1 fix: Notes section uses the page's system font stack
30580f9 feat: a Notes section on the home page
```

`notes.css` afterwards holds none of the three planted values (`padding: var(--space-4)`, no
`font-family`, no colour on the heading).

## Failed steps (the helper's words, shortened)

- `gstack-browser-ensure` ignores `GSTACK_CHROMIUM_PATH`: its probe failed (`Executable doesn't
  exist at /opt/pw-browsers/chromium_headless_shell-1234/...`), its download got `403 ... request
  blocked: no rule or allowlist entry allows host "cdn.playwright.dev"` five times, and the skill's
  check printed `NEEDS_SETUP`. It drove `$B` directly, which honours the variable, and that worked.
- Two of its browser calls ran from the devshop repo's root, so they reached the other run's browser
  daemon (gstack keys the daemon by git root): an artefact of two helpers sharing one session's
  working directory, not of a build.
- The browser cached the old `notes.css`; re-tests forced a reload.
