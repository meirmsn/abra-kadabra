Only `specs/ui-baseline.md` is in the directory, so I couldn't check any claim about the codebase: the skill text, `skills-check.py`, the README's `ui-ux.md`, L-72, the TARGET items, the paths, or the cloud Chromium build 1194. Treat those as unchecked.

1. **The design is far bigger than the problem.** The root cause is real and the spec names it: the Build skill has no design guideline or starting files, so it writes bare HTML. A guideline plus `base.css` and `theme.js` fixes that. Most of the weight is in two check scripts that each project copies:
   - A CSS parser with strict theme-shape rules.
   - OKLCH-to-sRGB conversion with gamut clipping.
   - About 15 render rules.

   The two contrast checks overlap: the render check measures painted text, which already covers the token pairs. The simpler design is a render check plus a tiny "is every `var()` defined" scan, with no contrast in the token check. That option isn't listed, so it was never rejected. Ask the owner whether two copied checkers are wanted now.

2. **No way to serve the files in the fixture's kind of app.** The fixture is a Workers app that renders HTML strings with no build step. The spec never says how such an app delivers `base.css` and `theme.js`: inlined in the HTML string, or served as static assets (which needs a binding). An inline script can also be blocked by a Content-Security-Policy. Option A rests on this case, so the guideline must say how.

3. **No URL for the render check in CI.** AC-3 takes `--url`. `example.html` works over `file://`, but a real project's slow CI job needs a running server (for example `wrangler dev`), and nothing says who starts it or waits for it to be ready.

4. **`base.css` conflicts with the token rules.**
   - AC-2 doesn't say whether `base.css` is the `--theme` file or a scanned file.
   - If it is the theme, any component rule that sets a custom property makes the check exit 2.
   - If it isn't, local helper properties such as `--gap` fail, because "a token is defined only by the theme file". That stops projects from adding their own components, which the Ownership decision says they will.
   - The spec doesn't say whether non-colour tokens like `--radius` must be repeated in the dark rules.

5. **Several render rules can't be tested as written.**
   - "Effective background": no algorithm for transparent ancestors, gradients, images or overlays.
   - "Page background": is it `html` or `body`? If transparent, it reads `rgba(0,0,0,0)` in both themes.
   - Toggle: with the system in light, the first click (to light) changes nothing visible. How many clicks may the check make, and how does it read the toggle's current choice? A project's two-state toggle may fail.
   - Pressed state: no ruling on CSS transitions (style read mid-transition), or on disabled and busy buttons.
   - "Page throws an error": uncaught exceptions only, or console errors too?
   - Exit-code order when both a 1 and a 2 condition occur.

6. **Two layout decisions have no check.** Cards in two columns from 768 px and three from 1280 px, and the maximum line length, aren't in any AC. AC-3 only checks that `<main>` is wider at 1280 px. Add a check or say review covers them.

7. **The Playwright pin is fragile.** It ties 1.56.1 to a Chromium build "seen 2026-10-13" in cloud sessions; when that image changes, sessions download a browser or fail. There's no fallback. And the scripts are re-copied by "a later devshop version's upgrade step", but no AC changes `devshop-upgrade` to do that.

8. **The record contradicts itself.** The header says "Go: pending", yet a decision reads "Changed after the go" and quotes the owner's "1, go ahead". Fix one of them.

9. **Path mismatch.** AC-6 names `/opt/devshop-current/templates/ui/`, while the files live in `runtime/templates/ui/`. `skills-check.py` "checks the path exists": in which tree? If it checks the literal `/opt` path, CI fails unless the devshop is installed there.

10. **Phone emulation has unstated effects.** At 375 px, does emulation turn on touch? That changes how a press is simulated and makes hover meaningless. AC-4's screenshots must come from a fresh browser context, or the toggle test's stored choice leaks into them.

11. **Scope beyond the owner's words, and fit with them.**
   - Additions: OKLCH gamut clipping, the strict theme-shape grammar, the `var(--` scan over TS and HTML, and the AC-8 spike folder. They are defensible, but it's Claude's proposal throughout.
   - The owner asked for a "modern component baseline". The baseline is minimal (no dialog, tabs or nav component), so say in the guideline that it is deliberately minimal and that B or C at M2 is where richer components come from.
   - The theme toggle and "responsive, not just phone" match the owner's words.

12. **Small gaps.**
   - Out-of-gamut colours are clipped silently; that could pass a pair that is really wrong.
   - "Link inside a sentence" uses the parent's own text, so a link in a table cell with a label passes.
   - Does the 44 px rule exempt disabled controls?
   - No behaviour is set for a page with no text.
