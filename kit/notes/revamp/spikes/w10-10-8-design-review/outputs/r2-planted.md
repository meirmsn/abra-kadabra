# Round 2, planted run (2026-10-17)

The helper's hand-back, sections 1 (gstack's final report, which it returned as text: report-file
writes from a subagent are refused by the harness), 2 (questions), 3 (git state) and 5 (failed
steps). Its section 4: screenshots in the scratchpad and gstack's state under `~/.gstack/`;
"nothing was sent to Codex or any other outside service"; the one outbound attempt was gstack's
browser check downloading Chromium, blocked.

## gstack's final report

**Design review: http://127.0.0.1:8202/, home page only (index.html)**

- **Driver:** gstack's own headless browser (`$B`), using the image's Chromium through
  `GSTACK_CHROMIUM_PATH`. Aside is not installed on Linux.
- **Mode:** App UI (an "Operate" page). Calibrated against DESIGN.md, which is in the strict spec
  format; its tokens bless the system-ui font stack.
- **Detector:** not installed, so no scan ran.

**First impression:** the page reads as a calm, competent task list. The Notes card breaks it
straight away: a magenta heading and serif body text in a sans-serif, cool-gray page. My eye goes to
"This week", then the magenta "Notes", then the blue "See tasks". The second of those is the
hierarchy lying. One word: interrupted.

**Rendered design system before fixes**

- Fonts: system-ui stack, plus `"Comic Neue", cursive`, which rendered as a serif fallback.
- Colours: every token, plus `rgb(255, 0, 170)`, which is not in the palette.
- Headings: h1 is 36px/700; every h2 is 18px/700.
- No horizontal scroll at 375px.
- Console: one 404 (`/favicon.ico`).
- Load: domComplete at 36ms.

**Findings**

| Id          | Impact | Category    | Finding                                                                                                     | Status                                                                                                       | Commit  |
| ----------- | ------ | ----------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------- |
| FINDING-001 | High   | Typography  | `.notes` set `font-family: 'Comic Neue', cursive`, a font DESIGN.md doesn't name (`typography.body.fontFamily`). | verified (computed font is now the system stack)                                                             | d2f7738 |
| FINDING-002 | High   | Color       | `.notes h2` was `#ff00aa`, outside the palette ("No other colour appears on a page").                        | verified (now `oklch(0.21 0.02 260)` in light and `oklch(0.96 0.005 250)` in dark, matching the other h2s) | a40713b |
| FINDING-003 | Medium | Spacing     | `.notes` padding was 13px, off the 4px scale; the summary cards use 16px.                                   | verified (now `--space-4`, 16px)                                                                             | 1d4056d |
| FINDING-004 | Polish | Content     | The "Notes" section and the New task form's "Notes" field share a name for two things.                      | deferred: renaming the section is a spec decision for the owner                                              | —       |
| FINDING-005 | Polish | Performance | `/favicon.ico` returns 404 on first load.                                                                   | deferred: outside the change                                                                                 | —       |

- **Trunk test:** PARTIAL. There is no nav or search, but it is a single page and this predates the
  change.
- **Phase 4 flows:** skipped, because the Notes section is static and has nothing to interact with.
- **Summary:** 5 findings; 3 fixed and verified, 0 best-effort, 0 reverted; 2 deferred.
- **Scores:** design score B+ → A; AI-slop score A → A; detector not installed.
- **Console after fixes:** no errors.
- **PR line:** "Design review found 5 issues, fixed 3. Design score B+ → A, AI slop score A → A."
  The fixes are as of commit `1d4056d`.

## Questions (the helper's words, shortened)

None was asked. Decided by the guideline: telemetry opt-in (stays off; its marker untouched, so it
comes back next run), test framework bootstrap (skipped), saving a `DESIGN.md` (declined),
cross-project learnings (this project only), outside voices (not run), `TODOS.md` (skipped),
`./setup` on `NEEDS_SETUP` (no; drove `$B` directly). Decided by the helper: the detector download
("not now"), target mockups (not used: an outside image service), the fix-risk stop (never
reached).

## Git state

```
1d4056d fix: the Notes section's padding is on the spacing scale
a40713b fix: the Notes heading uses the page's text colour
d2f7738 fix: the Notes section uses the system font stack
618ebde feat: a Notes section on the home page
```

`notes.css` afterwards: `padding: var(--space-4)`, no `font-family`, no colour on the heading.

## Failed steps

- gstack's browser check, as the guideline predicts (`Download failed: server returned code 403
  ... "cdn.playwright.dev"` five times, then `NEEDS_SETUP`); `$B` with the variable worked
  (`Navigated to http://127.0.0.1:8202/ (200)`).
- `$B screenshot` writes only under `/tmp` or the repo.
