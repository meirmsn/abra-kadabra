Limit on this review: the directory holds only the spec. I could not check any of its literal references against code: `runtime/guidelines/ui.md`, `skills-check.py`, `tests/skills-check.test.sh`, the CI `slow` job, L-72, TARGET Build 8, Shape 3, Reach 1, W10.6.9, `/opt/devshop-current/`. Each one still needs checking.

1. **Status contradiction.** Line 3 says "Go: pending". Lines 37-39 say "Changed after the go … owner chose to fix the reviewer's findings". Either the go was given and line 3 is wrong, or the line 37-39 entry is stale. Ask the owner which.

2. **Cause vs symptom, and size.** The cause is that the Build skill has no design default to start from. The template, the guideline and the AC-6 skill line fix that at the source, which is good. But most of the spec is two checkers, and the owner never asked for them: CSS shape parsing, OKLCH parsing with gamut clipping, two-theme contrast, and a Playwright render check with about 15 rules plus a CI pin. That is added scope, all marked "Claude's proposal". Contrast is checked twice: the render check measures painted contrast, which covers the token pairs and also catches hard-coded colours. **Strongest rejected/unlisted option:** ship the baseline, the guideline and the screenshots, and let the render check cover contrast. Drop the token-check contrast and gamut work, or the whole token check. Another unlisted option is vendoring a classless CSS file (e.g. Pico) remapped to shadcn token names. Ask the owner whether the checks are wanted at this size now.

3. **Theme file is unclear.** AC-1 takes `--theme <theme.css>`. AC-2 runs the check on `base.css` but never names the theme file. The ownership line copies only `base.css` and `theme.js`. Is the theme inside `base.css`? If it is, the strict "any other block declaring a custom property → exit 2" rule limits what `base.css` itself may contain. The spec should list every file in `runtime/templates/ui/`, and where the two scripts live in the devshop before they are copied to `scripts/ui/`.

4. **New failure mode: the Playwright pin.** It is tied to a Chromium build that today's cloud image happens to have (1194). When the image changes, sessions fail or download a browser. Projects also inherit a Node and `package.json` requirement, which sits awkwardly with "stack-agnostic". What should happen when the preinstalled build doesn't match?

5. **Missing `color-scheme`.** Nothing sets `color-scheme: light dark` (or per theme). Without it, native controls (select popups, checkboxes, scrollbars, date pickers) stay light in dark mode. The example uses exactly these controls.

6. **Render-check false positives (missing edge cases):**
   - Disabled controls: WCAG exempts their text contrast, and a dimmed disabled button will fail 4.5:1.
   - Visually-hidden or skip links (1 px box, "visible" under the definition) will fail the 44 px rule.
   - Horizontally scrollable containers (`overflow-x: auto` tables or code) have children past the viewport edge and will be flagged as overflow.
   - The "effective background" is undefined for `background-image`/gradients and semi-transparent layers. Say whether to composite, skip or exit 2.
   - Placeholder text is not covered.

7. **Untestable or ambiguous details:**
   - "Pressing a button changes its computed style" doesn't say which properties, whether the mouse is held during measurement, or whether a destructive or submit button actually fires.
   - "Toggle overrides the system both ways" doesn't say how the checker drives a cycle of three states (click until the background changes? a maximum number of clicks?).
   - In "system" mode, does `theme.js` remove `data-theme` or set nothing? The CSS depends on it being absent.
   - Checking that the toggle "names the current choice" is not in any AC.

8. **shadcn token claim to verify.** Current shadcn/ui (Tailwind v4) themes switch dark mode with a `.dark` class, not `data-theme`. Some versions also dropped `--destructive-foreground`. The promise that "the same names, one token check covers both" may not hold at M2. Check against the shadcn version you intend to use.

9. **Intent coverage is fine.** Phone first, responsive to desktop, system theme plus a manual toggle, option A now and B/C at M2, built in this session and merged after 10.6.4: all match the owner's words. The fixture restyle is correctly deferred.

10. **Small fixes:**
    - Two paths, `runtime/templates/ui/` (lines 49-52, AC-5) and `/opt/devshop-current/templates/ui/` (AC-6), refer to the same place without saying so. State the mapping.
    - AC-1 allows a non-colour token (e.g. `--radius`) to be light-only but rejects colour tokens that are; say so explicitly.
    - AC-8 commits screenshots to a spike folder in the repo; ask whether the owner wants them kept after merge.
