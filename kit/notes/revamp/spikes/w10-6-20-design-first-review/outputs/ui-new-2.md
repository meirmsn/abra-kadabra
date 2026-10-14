Note: the directory holds only the spec, so I could not check any literal path or claim against code (`runtime/templates/ui/`, `skills-check.py`, `/opt/devshop-current/`, L-72, TARGET items, the Playwright 1.56.1 / Chromium 1194 pairing). Treat those as unverified.

1. **The checks are much bigger than the problem.** The cause was that nothing gave the Build skill a styled starting point or told it to use one. Templates, `ui.md` and one line in the build skill fix that. On top, the spec adds a CSS-shape parser, OKLCH→sRGB contrast maths, `var()` resolution, and a Playwright render check with over 12 rules. The owner asked for none of these; they are all Claude's proposals. The render check's painted-contrast test already covers the token pairs (and hard-coded colours), so the token check largely duplicates it. Simpler option, not listed: keep the render check plus screenshots, and cut the token check down to "every `var(--x)` is defined". Ask the owner whether they want this weight.

2. **Go status contradicts itself.** The header says "**Go:** pending", but a decision is headed "Changed after the go" and quotes "1, go ahead". Either the go was given or that bullet is wrong.

3. **`example.html` likely fails its own render check (AC-2 vs AC-3).** AC-2 requires a disabled and a busy button. The pressed-state rule cannot fire on a disabled button, and disabled styling usually fails 4.5:1 (WCAG exempts disabled controls). Placeholder text has the same contrast risk. Exemptions for disabled, `aria-busy` and placeholder need stating.

4. **Overflow rule gives false positives.** "Any visible element past the edge" flags visually-hidden (sr-only, `left:-9999px`) elements and content inside a legitimate `overflow-x:auto` scroller (tables, code). Define it against clipping ancestors, or exempt these.

5. **The theme file is not identified.** AC-1 takes `--theme <theme.css>`, but the templates are only `base.css` and `theme.js`, and AC-2 runs the check "with `example.html` and `theme.js`" without saying what `--theme` is. If the theme is `base.css`, the strict-shape rule (any other block declaring a custom property → exit 2) bans component-local custom properties, a limit projects will hit once they own the file.

6. **Non-colour tokens conflict.** AC-1 exits 0 only if each token is "defined by the theme for both themes", yet only a colour token missing from dark is a finding, while "only for dark" is a finding for any token. It is unclear whether `--radius`, set on `:root` alone, passes. State that light-only non-colour tokens are fine.

7. **The toggle test is ambiguous.** The cycle is system→light→dark. "Overrides the system both ways" doesn't say how many clicks, or what counts as overriding when the choice already matches the system (light under system-light shows no change). Specify, for example: under system light, click until `data-theme="dark"` and check the background changes; the reverse under system dark. "Names the current choice" is in the decisions but no AC tests it.

8. **Pressed-state and hover tests overlap.** Hover changes the computed style too, so the check must compare hovered with hovered+mouse-down, or every button passes. On 375 px phone emulation (`hasTouch`), hover may not apply.

9. **The 44 px rule needs more definition.** It doesn't say whether a checkbox's label alone, or label plus input, must reach 44 px. The "link inside a sentence" exemption (parent has text of its own) also exempts a nav link whose `<li>` has a text bullet or separator such as "|", the very case AC-3 wants caught.

10. **Missing edge cases.** A toggle that is visible but dead without JavaScript (hide it until JS runs?). `localStorage` holding an unknown value. Focus-ring visibility: `--ring` against the background at 3:1 (WCAG 1.4.11) is not checked, though the control contract requires a visible ring. Contrast on gradients or translucent backgrounds in the render check (exit 2 or skip?).

11. **Scope added beyond the owner's words.** The L-72 contract as global rules, the CI slow job and `package.json` pin in this repo, workstream lines, and the spike-folder screenshots. Each is defensible but should be named as an addition, not presented as intent.

12. **Shadcn token fidelity.** Current shadcn (OKLCH, v4) has dropped `--destructive-foreground` and has `--popover` and `--card-foreground`. The "where shadcn/ui has one" rule needs a pinned shadcn version, or the token list and contrast pairs are ambiguous.

13. **AC-6 path.** `skills-check.py` "checks the path exists" for `/opt/devshop-current/templates/ui/`. It is not stated whether that path exists in CI or only in installed sessions. Unverified here.

14. **Intent fit is good.** Option A, the system-default theme with a manual toggle, responsive across 375/768/1280, the fixture left for later, and merging after 10.6.4 all match the owner's words.
