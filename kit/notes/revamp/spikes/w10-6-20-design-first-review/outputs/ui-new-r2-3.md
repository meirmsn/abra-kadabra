The spec is the only file under `ui/`, so I couldn't check any of its literal claims against code. That covers file paths, `skills-check.py`, `/opt/devshop-current`, L-72, TARGET refs and the Playwright/Chromium build. Treat every item below as a claim to check.

1. **The fix doesn't reach the symptom.** The cause is that the Build skill has no design defaults or guidance, so it emitted bare HTML. The spec fixes that at the source (guideline, templates, one line in the skill). But no AC shows the Build skill actually producing a styled page. AC-6 only checks that a line and a path exist, and the fixture restyle is deferred. Ask the owner whether that deferral is acceptable, or whether a check that a Build run picks up the baseline belongs here.

2. **The strongest alternative isn't argued.** Basecoat (C) needs no React, and as far as I know it also ships as a prebuilt CSS file (verify). If so, it would serve the fixture now with no build step and would replace the hand-written `base.css`. The spec only defers C to M2. It should say why a custom CSS file now beats adopting C now.

3. **The size is out of proportion to "a design baseline".** Most of the work is two checkers:
   - a strict custom CSS parser with contrast maths and OKLCH gamut clipping;
   - a render checker that computes the effective background of every visible text, plus toggle/reload, size, overflow and pressed-state rules;
   - both copied into every project, re-copied on upgrade, and pinned to Playwright.

   The owner asked for none of this; it is all Claude's proposals. Token-pair contrast also overlaps with render contrast. Ask whether one checker, or a smaller render check, would do.

4. **AC-2/AC-3 likely contradict each other.** `example.html` must contain a disabled and a busy button (AC-2), and the render check must exit 0 on it (AC-3). Yet the render check enforces contrast on "every visible text", and disabled styling is usually dimmed. WCAG exempts disabled controls; the spec doesn't. Add the exemption, or define how disabled and busy look.

5. **New false-positive failure modes in the render check:**
   - Sr-only text and off-canvas menus have a non-zero box past the edge, so they count as "visible" and trip overflow.
   - The effective background is undefined for images, gradients and positioned overlays.
   - Chromium's `getComputedStyle` can return `oklch(...)`/`color-mix()`, not `rgb()`, so the checker must parse those.
   - Third-party scripts that throw give exit 2.
   - The cloud image's preinstalled Chromium can change under the 1.56.1 pin.

6. **Ambiguity: what is the theme file?** AC-1 takes `--theme <theme.css>`, but the shipped and owned files are only `base.css` and `theme.js`. Is the theme inside `base.css`? If so, the "a token is defined only by the theme file" and "any other block declaring a custom property → exit 2" rules forbid helper custom properties in `base.css` (e.g. `--page-max`). The spec should name the file and say whether non-theme custom properties are allowed.

7. **Status contradiction.** `**Go:** pending`, yet a decision reads "Changed after the go … owner chose to fix the reviewer's findings". Either the go was given, or that line is stale.

8. **Parts of the L-72 contract are specified but untested.** Hover change, visible focus ring (and its 3:1 non-text contrast), `touch-action`, disabled and busy looks, and the toggle naming its current choice (its accessible name) have no AC. The same goes for the 2- and 3-column card flow and the maximum line length; AC-3 only checks that `<main>` gets wider.

9. **The toggle test procedure is unstated.** With the cycle system → light → dark, under system dark the first click gives light, and the second gives dark, which looks identical to system. How many clicks, and what counts as "overrides both ways" for an arbitrary page? Without JS the toggle is a dead visible control; hide it or say so.

10. **Token names may not match current shadcn/ui.** I believe the Tailwind-v4 theme dropped `--destructive-foreground`, and it adds `--popover*`, `--card-foreground`, `--chart-*` and `--sidebar-*`. Check which shadcn version "same names" targets, since that determines the AC-1 pairs.

11. **AC-6 details.** `skills-check.py` "checks the path exists" for `/opt/devshop-current/templates/ui/`. Does that path exist in CI, and before this release is installed? Also, "within one page" is unclear in AC-6.

12. **Scope added beyond the owner's words:** copying the check scripts into each project's `scripts/ui/`, the upgrade-step re-copy, the CI Playwright job, and the spike-folder screenshots. They're defensible, but the owner should approve them explicitly.

13. **Smaller edge cases:**
    - A `var()` fallback containing a nested `var()`.
    - A `@media` condition written with different spacing, e.g. `(prefers-color-scheme:dark)`: does that count as "exactly", or exit 2?
    - The pressed-state rule on a disabled button, which can't be pressed.
    - The 44 px rule for an unlabelled checkbox.
    - A `select` on iOS.

### Critical Files for Implementation
- <replay>/ui/specs/ui-baseline.md
