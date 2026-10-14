Scope note: the directory holds only `specs/ui-baseline.md`. I couldn't check any codebase reference (`runtime/guidelines/`, `skills-check.py`, `tests/skills-check.test.sh`, the build skill's "disciplines line", `/opt/devshop-current`, L-72, TARGET items, W10.6.x), so treat all of them as unverified.

1. **The go status contradicts itself.** The header says `**Go:** pending`, but a Decision reads "Changed after the go … ('1, go ahead')". Either the go was given or it wasn't. Fix the header or the decision.

2. **The fixture decision misreads the owner.** The owner said "if [the fixture is] staying for the future, we do B or C once we decide in M2", which is conditional. The spec records "The fixture stays a Workers app … rejected: moving the fixture to React (owner)". The owner didn't reject that; they left it open for M2. Ask the owner.

3. **It's unclear which file is the theme.** AC-1 takes `--theme <theme.css>`, but the deliverables are only `base.css` and `theme.js`, and AC-2 runs the check on base.css with example.html and theme.js, so the `--theme` argument is unnamed. If base.css is the theme, the rule that any other block declaring a custom property exits 2 forbids component-local custom properties in base.css. Name the theme file and add it to the file list in Ownership and AC-5.

4. **"Defined for both themes" is ambiguous.** Non-colour tokens like `--radius` live only on `:root`, and dark inherits them through the cascade. Does a light-only non-colour token pass? Must a colour token be redeclared in dark even when its value is the same? When a dark `var()` points to a token that exists only in light, which value is used?

5. **shadcn token names have drifted.** Current shadcn/ui (Tailwind v4) dropped `--destructive-foreground`. "Where shadcn/ui has one" then leaves destructive button text with no contrast pair. The list also omits `--popover`, `--chart-*` and `--sidebar-*`. Pin a shadcn version or give an explicit list.

6. **The toggle protocol is undefined for the checker.** The cycle is system → light → dark. Under a light system, the first click to "light" changes nothing visible. The render check needs a rule, for example "click until `data-theme` equals X", or it can't judge "overrides both ways". "Names the current choice" is untested.

7. **Parts of the control contract are untested.** The render check covers size and pressed state only. Hover change, the visible focus ring, `touch-action`, and the disabled and busy looks have no AC. It's also unclear whether disabled or `aria-busy` buttons are exempt from the "no pressed state" failure. If they aren't, `example.html` fails its own check.

8. **Layout promises are untested.** Two columns from 768 px, three from 1280 px, and the maximum line length are decided but never checked. Only "`<main>` is wider at 1280 than at 375" is.

9. **The overflow rule will give false failures.** "Any visible element reaching past the edge" catches screen-reader-only text (1 px box, positioned off-screen), skip links, and content inside a deliberately scrolling container (`overflow-x: auto` code or table wrappers). Define the exclusions.

10. **"Effective background" is undefined** for gradients, images, semi-transparent layers and positioned overlays. Say what happens there: skip, exit 2, or fail.

11. **The token scan over "any file type" is too broad.** A text scan for `var(--` also hits comments and prose, e.g. ui.md or JS strings. Say whether comments are ignored outside the theme too.

12. **Added scope with no AC.** Shipping the check scripts into a project's `scripts/ui/` and having the upgrade step re-copy them has no acceptance item. Nothing states where the scripts live in the devshop either (`runtime/templates/ui/`?). Either add ACs or move it to a later task. Pinning Playwright to 1.56.1 rests on one observation of cloud sessions ("seen 2026-10-13"); it's fragile, so say what happens when the preinstalled build changes.

13. **Some items can't be tested.** "In one page" (AC-5, AC-6) has no measure. AC-8's "sent to the owner in the session" is a process step, not a property of the code.

14. **Smaller gaps:**
    - The OKLCH values to ship are never given.
    - Contrast covers only text pairs. The focus ring and borders against the background (3:1, WCAG 1.4.11) aren't checked.
    - Named colours, `transparent`, `color-mix()` and relative colours aren't classified.
    - The phone emulation's viewport height and `hasTouch` aren't set, which matters for hover.
    - AC-4's screenshots show only system themes, not the toggle overrides.
    - Exit 2 covers uncaught page errors, but failed subresource loads and console errors are unspecified.

15. **Intent check.** "Phone first" plus "responsive, not just phone" and "toggle in the default" are both reflected. The "modern … possibly shadcn" ask is met only by token names and plain CSS, so confirm the owner accepts that as "modern component baseline" for now.
