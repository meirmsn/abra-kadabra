The directory holds only `specs/ui-baseline.md`, so I couldn't check any literal against the codebase (see 10). Treat everything below as claims to verify.

1. **The go status contradicts itself.** The spec says `**Go:** pending`, but a Decision says "Changed after the go" and quotes "1, go ahead". Either the go was given (update the header) or "1, go ahead" only approved the fixes, in which case "after the go" is wrong. Ask the owner which.

2. **The owner's "responsive, not just phone" is only weakly tested.** The Decisions promise two card columns from 768 px, three from 1280 px, and a maximum line length. AC-3 only checks that `<main>` is wider at 1280 than at 375. A page that never reflows its cards passes. Add checks for the card column counts at 768 and 1280, and for the line-length cap.

3. **Several promised toggle and theme behaviours have no acceptance item:**
   - the toggle names the current choice
   - it cycles system → light → dark → system
   - no flash before the first paint
   - a blocked `localStorage` falls back to system
   - without JavaScript the page follows the system

   Either add them to AC-3 or mark them review-only. Also unspecified: what `data-theme` holds in "system" mode (attribute removed, or `"system"`).

4. **Most of the L-72 control contract is untested.** AC-3 tests the 44 px size and the pressed state. Nothing tests the hover change, the visible focus ring, `touch-action: manipulation`, or the disabled and busy looks. It's also unclear whether disabled or `aria-busy` buttons are exempt from the pressed-state rule (the example has both).

5. **Ambiguous measurements in the render check:**
   - "Page background": is it read from `html` or `body`, and what if one is transparent?
   - "Phone emulation": is it `isMobile`, `hasTouch`, a device scale factor? Viewport heights aren't given.
   - "The page throws an error": is it only uncaught `pageerror`, or `console.error` too?
   - Does exit 1 report every finding or stop at the first? What wins when an exit-1 and an exit-2 condition occur together?

6. **The token rules are unclear for non-colour tokens.** AC-1 requires every token "defined by the theme for both themes". `--radius` would naturally sit only on `:root`. Is that "defined for dark" by inheritance? The spec fails only light-only *colour* tokens, so say so explicitly. Also, "comments are ignored" is stated for the theme only. Does a `var(--` inside an HTML or JS comment in a scanned file count?

7. **The shadcn/ui token list may not match current shadcn.** shadcn/ui v4 (the OKLCH, Tailwind v4 version) dropped `--destructive-foreground`. It also has `--popover`, `--chart-*` and `--sidebar-*`, which the spec doesn't list. "Each colour with its `-foreground` pair where shadcn/ui has one" depends on the version. Pin the shadcn version the names come from, or list the exact set.

8. **The in-sentence link exemption can be gamed.** A nav row like `Home | About | Docs` has separator text in the parent, so every link becomes exempt. That defeats the AC-3 case "a row of short links in a nav". Consider ignoring punctuation-only text, or requiring words.

9. **Some scope goes beyond the ask; confirm it with the owner.** The owner asked for a design baseline (responsive, both themes, toggle, possibly shadcn). Claude's proposals add:
   - a token linter with OKLCH parsing and gamut clipping
   - a Playwright render checker with contrast analysis
   - check scripts copied into every project's `scripts/ui/` and CI
   - a Playwright pin in every project
   - an upgrade step that re-copies the scripts

   These are probably worthwhile, but they're all Claude's decisions. The upgrade re-copy and the copy into `scripts/ui/` have no acceptance item, so they are either missing ACs or silent scope.

10. **Unverifiable literals, to check by hand:**
   - `runtime/guidelines/ui.md`, and the guidelines README's example name `ui-ux.md`
   - `runtime/templates/ui/`, and that it maps to `/opt/devshop-current/templates/ui/` (the AC-6 path)
   - `skills-check.py` checking that paths exist, and `tests/skills-check.test.sh`
   - the build skill's "disciplines line"
   - L-72, TARGET Build 8 / Reach 1 / Shape 3, W10.6.4, W10.6.9
   - a CI job named `slow`
   - Playwright 1.56.1 pairing with Chromium build 1194 under `PLAYWRIGHT_BROWSERS_PATH`

   AC-6 also doesn't say which directory the check scripts ship in, alongside `base.css` and `theme.js` or elsewhere.

11. **The timing is consistent but worth stating.** "Built after 10.6.4" was later replaced by "do the work on this session, i will merge once 10.6.4 is done", and the Decisions follow the later wording. Keep both quotes so the order is clear.

12. **Minor items:**
   - "Within one page" (AC-5, AC-6) isn't measurable. Use a line count or drop it.
   - AC-2 says "every primitive above", but it should refer to the `base.css` Decision explicitly.
   - The example omits a radio button, though AC-3 has a radio/label rule.
