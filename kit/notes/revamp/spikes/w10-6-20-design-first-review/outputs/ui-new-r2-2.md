The directory holds only the spec, so I could not check any codebase references against real files. That covers L-72, TARGET Build 8/Reach 1/Shape 3, `skills-check.py`, the README's `ui-ux.md`, `/opt/devshop-current`, and Playwright 1.56.1 being Chromium build 1194. Verify each one yourself. Everything below is a claim to check.

1. **The fixture decision misreads the owner.** The owner said: "we should do A, and if [the fixture is] staying for the future, we do B or C once we decide in M2". That makes B/C conditional and aimed at the fixture. The spec says the B/C choice is for React stack homes, and it records "the fixture stays a Workers app… rejected: moving the fixture to React" as the owner's decision. Ask the owner which reading is right. C (Basecoat, which needs no React) is exactly the option that fits a fixture that stays.

2. **The token-name rationale doesn't hold.** It says "one token check covers both". But a stock shadcn/ui theme uses `.dark { … }` and Tailwind v4's `@theme inline` block, which declares custom properties. Under the strict shape rules the check exits 2 on it. Current shadcn also has no `--destructive-foreground`, and it adds `--popover`, `--chart-*` and `--sidebar-*`. Either drop the claim or say M2 must extend the check.

3. **Where the cause starts.** The bare page came from Build having no UI default. The fix (a guideline, templates, a line in the build skill) does target that. But AC-6 only fires for "a project without the baseline", and nothing makes Build actually use the tokens or run the checks. The only enforcement is a guideline the reviewer reads.

4. **Strongest option not listed: a stock classless/minimal CSS kit** (Pico, or Basecoat's CDN CSS) instead of a hand-built `base.css` plus two custom checkers. It would be far less code to own. Its cost is that the token names differ. Ask whether the owner weighed this.

5. **Size is out of proportion.** The owner asked for a look: responsive, themed, with a toggle. Most of the spec is checker machinery that Claude proposed: a strict CSS-shape parser, OKLCH gamut clipping, alpha rules, painted-contrast computation, overflow probing and a Playwright pin in CI. This is added scope, and the owner hasn't explicitly approved it. Ask whether the render check alone (in the slow tier) is enough for now.

6. **New failure mode: the strict theme shape blocks project ownership.** A project "owns base.css (more components)", but any local custom property breaks the check: it is either undefined (exit 1) or another-shape (exit 2). It's also unclear which file is the theme: is `--theme` given `base.css`, or a separate `theme.css`? AC-2 suggests `base.css`. Name the file and put the constraint in `ui.md`.

7. **Render-check false positives on its own example.**
   - The disabled button's text has low contrast, and WCAG exempts disabled controls. The spec gives no exemption, so the check would flag it.
   - Disabled buttons can't be pressed, so "no pressed state" would flag them.
   - Off-screen skip links (`left: -9999px`) and children of `overflow-x: auto` containers would count as "past the edge".

   State an exemption for each.

8. **Ambiguous or untestable items.**
   - **Toggle check:** starting from system-light, the first click goes to light, which looks the same. The check needs a defined probe, such as clicking up to 3 times and watching the background.
   - **Page background:** say whether it is read from `html` or `body`, and what happens if it's transparent.
   - **Effective background:** define how it's computed when there are background images, gradients or overlapping elements.
   - **"Page throws":** `pageerror` only, or console errors too?
   - **Not tested anywhere:**
     - The toggle naming its current choice
     - No flash before first paint
     - The page following the system without JavaScript
     - Two- and three-column cards at 768 and 1280 px
     - Maximum line length
     - Hover, focus ring, `touch-action`, and the disabled/busy looks
   - **AC-2 "uses every primitive":** list the selectors the test looks for.

9. **Edge cases missing.**
   - `localStorage` reload persistence on `file://` in Chromium. Verify it works.
   - A stored value that's invalid or stale.
   - `--muted-foreground` on `--muted`, and link colour (`--primary`) on `--background`. Neither is a token-check pair.
   - `var(--x)` text inside JS strings or comments in scanned files.

10. **Status inconsistency.** The header says `Go: pending`, yet one Decision is titled "Changed after the go" and cites "1, go ahead". Pick one.

11. **Matches the owner.** The timing (build now, owner merges after 10.6.4), the manual toggle by default, and "responsive, not just phone" with widths 375/768/1280 all match the owner's words.
