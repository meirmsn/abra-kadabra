Scope note: the directory has only `specs/ui-baseline.md`. None of the code the spec refers to exists there (`runtime/guidelines/`, `templates/ui/`, `skills-check.py`, `tests/skills-check.test.sh`, `package.json`, CI, the workstream file, L-72, the TARGET items), so I couldn't check any literal code or path against a codebase. All of those are still unverified.

1. **The go status contradicts itself.** The header says "**Go:** pending", but a decision is headed "Changed after the go" and quotes the owner ("1, go ahead"). Either the go was given and the header is stale, or the change happened before the go and the heading is wrong. Ask the owner.
2. **One owner decision is stronger than what the owner said.** The owner said "if [the fixture is] staying for the future, we do B or C". That is conditional. The spec records "The fixture stays a Workers app… rejected: moving the fixture to React (owner)" as settled. It also says "the Next.js home is its decoy" without explaining it. Ask whether "stays" was actually decided.
3. **Your own example would fail the render check: disabled controls.** WCAG exempts disabled controls from contrast, but the spec gives no exemption. `example.html` must contain a disabled button, which usually has dimmed text, and AC-3 flags any visible text below threshold. Add an exemption for `:disabled`, `aria-disabled` and maybe placeholder text, or state that disabled styles must still pass.
4. **It's unclear which file the theme is.** AC-2 runs `tokens-check.mjs` on "base.css with example.html and theme.js" but never says what `--theme` is. If the tokens live in `base.css`, any other block there declaring a custom property (a local `--gap`) causes exit 2. If they live in a separate theme file, the template list (`base.css`, `theme.js`) is missing that file.
5. **The light-only rule conflicts with non-colour tokens.** AC-1 requires every token to be "defined by the theme for both themes", but the error case only names "a colour token defined for light but not dark". `--radius` would normally be declared only in `:root`. Say whether non-colour tokens may be light-only.
6. **Most of the L-72 control contract isn't tested.** The render check tests size and the pressed state only. Hover change, visible focus ring, `touch-action: manipulation`, the disabled look and the `aria-busy` look have no AC. Focus-ring contrast (3:1 for non-text, WCAG 1.4.11) is missing too. Either add these checks or state that review covers them.
7. **The overflow rule will give false positives.** "Any visible element reaching past the viewport's left or right edge" flags:
   - content inside a deliberately scrolling wrapper (a wide table in `overflow-x: auto`);
   - off-screen skip links (`left: -9999px`, which still has a non-zero box);
   - visually-hidden text.

   Define exemptions, or limit the rule to elements not clipped by a scroll container.
8. **The toggle's semantics aren't defined.** With the system in dark, the cycle system → light → dark: what counts as "overrides in either direction", and how many clicks does the check make? "Names the current choice" has no AC; say whether it's checked by accessible name or visible text. It's also unspecified how `theme.js`, running in `<head>`, binds the toggle before the DOM exists, and whether `localStorage` persistence works on `file://` in that Chromium. AC-3 depends on both.
9. **The pressed-state check could be flaky.** "Changes its computed style" while pressed doesn't say when it's sampled; a CSS transition could mean nothing has changed yet. Specify a mouse-down and when to read the style, or require no transition on `:active`.
10. **The contrast method isn't specified.** For "effective background as the browser paints", it doesn't say how backgrounds that are images, gradients or semi-transparent layers are handled: skip, exit 2, or composite.
11. **Exit-code gaps in AC-1 and AC-3:**
    - which code wins when a file has both exit-1 and exit-2 conditions;
    - whether alpha = 1 (for example `rgb(… / 1)`) counts as "has alpha";
    - whether "the page throws an error" means an uncaught exception only, or `console.error` too.
12. **The inline-link exemption is easy to game.** A nav using text separators ("Home | About") gives the parent text of its own, so short nav links are exempt. That contradicts AC-3's "a row of short links in a nav" example.
13. **Scope beyond the ask.** The owner asked for a responsive, themed baseline with a toggle. The strict-shape token checker, the full contrast engine in the render check, the CI slow job, the Playwright pin, the build-skill line and the workstream entries are Claude's additions. They're defensible but sizeable; confirm the owner wants them in this slice rather than only the CSS, `theme.js` and the guideline.
14. **Some checks can't be tested as written.** AC-5's "in one page" and AC-6's "within one page" are vague; give a length or drop them. AC-8 depends on a manual send in the session.
15. **Unverifiable environment claims.** "Playwright 1.56.1 ↔ Chromium build 1194 preinstalled" needs checking. Also confirm that `/opt/devshop-current/templates/ui/` maps to `runtime/templates/ui/` and that `skills-check.py` resolves that path in CI.
16. **Upgrades will overwrite local changes.** The upgrade step "re-copies" the check scripts into the project's `scripts/ui/`, silently replacing any local edits. Say so in the guideline, or have the upgrade detect a changed file.

### Critical Files for Implementation
- <replay>/ui/specs/ui-baseline.md
