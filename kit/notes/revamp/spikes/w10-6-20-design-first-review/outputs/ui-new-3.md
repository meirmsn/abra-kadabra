The only file under the project directory is the spec, so I couldn't check its literal paths and names against any code: `runtime/guidelines/ui.md`, `skills-check.py`, `/opt/devshop-current`, `tests/skills-check.test.sh`, the CI `slow` job and the docs map. These are claims you'll need to check yourself.

1. **Cause and size.** The cause is right: the Build skill had no UI guideline or starting template, so it produced bare HTML. A guideline plus `base.css` and `theme.js` fixes that. The two checks are much bigger than the problem and the owner never asked for them: a strict CSS-shape parser, OKLCH-to-sRGB gamut clipping, painted-contrast analysis, overflow and size heuristics. Simpler option: keep only the render check, which already measures contrast as painted (including hard-coded colours), and cut the token check to "undefined `var()`". That makes static contrast, alpha handling, gamut clipping and dark-rule parity unnecessary. This is a sizing decision for the owner.

2. **Unlisted option: `light-dark()` with `color-scheme`.** Each token would be declared once, e.g. `--background: light-dark(L, D)`, with `color-scheme` set from `data-theme` and from the system. That removes the duplicated dark block (and the drift it invites, which AC-1 then has to police) and most of the theme-shape rules. It needs fairly recent browsers (roughly 2024 on). The spec should say why it was rejected.

3. **"One token check covers both" (Decisions, token names) is likely false.** shadcn/ui's `globals.css` uses a `.dark { }` block and Tailwind v4 `@theme inline { }` blocks that declare custom properties. Under the token-check rules, any such block makes it exit 2. shadcn also switches theme with a `.dark` class, not `data-theme`. Also, by my calculation from memory, shadcn's default `--muted-foreground` on `--muted` (#737373 on #f5f5f5) is about 4.35:1, so the rule "each `--X-foreground` on its `--X`" would fail shadcn's own defaults. Either narrow the claim or settle it at M2.

4. **The header says "Go: pending", but a decision says "Changed after the go".** One of them is wrong.

5. **Toggle without JavaScript.** The spec says that without JS the page follows the system, but the toggle still shows and does nothing. Say whether it's hidden without JS (e.g. `theme.js` reveals it). The render check's "both ways" test is also loose: it doesn't say how many clicks it allows, or whether a toggle with only light and dark passes. The required "names the current choice" isn't tested anywhere.

6. **Some requirements aren't tested.**
   - Cards in 2 columns from 768 px and 3 from 1280 px.
   - Maximum line length.
   - Hover change, `touch-action`, the focus ring, and the disabled and busy looks.

   AC-3 only checks that `<main>` is wider at 1280 px, so these are only claims. Either add checks or mark them "by review".

7. **The render check will flag good pages (false positives).**
   - "Any visible element past the edge" flags skip links and sr-only text positioned off-screen, and content inside a horizontally scrolling container (`overflow:auto`). The rule needs an exemption for clipped elements and elements inside a scroll container.
   - "Every button has a pressed state" should exempt disabled and busy buttons.
   - The inline-link exemption ("its parent has its own text") fails for `<p>Read <strong><a>…</a></strong> now</p>`.
   - "Effective background" isn't defined for gradients, background images or semi-transparent layers. Say whether those skip the element or exit 2.

8. **Hard to measure.** A pressed state measured as a computed-style change during mousedown is flaky if the style has a transition. Say whether the check waits for transitions or disables them.

9. **Weak assumptions.**
   - "Node is the one runtime every web project already has" doesn't hold for Python-served apps with no `package.json`. Say what they do.
   - The Playwright 1.56.1 pin rests on one observation of what cloud sessions had preinstalled (2026-10-13). If the image changes, every copied project breaks with exit 2. Add a note on how the pin gets updated (the upgrade step?).

10. **Scope the owner didn't ask for.** Viewport-meta and overflow rules, the `file://` support, and AC-8's screenshots committed to a spike folder (they make the repo bigger). These are probably fine, but confirm them, especially the committed binaries.

11. **Smaller gaps.**
    - AC-6 relies on `/opt/devshop-current/templates/ui/` mapping to `runtime/templates/ui/`. Confirm that `skills-check.py` resolves it in CI, not only in a session.
    - AC-1 doesn't say what happens with a `var(--x)` in `base.css` that the theme defines only via `@property`, or with duplicate declarations inside one rule.
    - Without the owner's go, AC-1 and AC-3 risk turning into a large test matrix.
