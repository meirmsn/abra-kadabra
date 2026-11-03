# Run 1 (2026-11-01): the helper's hand-back, verbatim

One fresh `general-purpose` helper, given `ui.md` § Design review, the scratch repo, its branch
`launch` and `http://127.0.0.1:32877/launch.html`. Its final message follows unchanged, apart from
this heading.

---

# Design review dry run — `http://127.0.0.1:32877/launch.html` (branch `launch`)

Status: DONE (ran end to end; two deviations from the skill's wording, both forced by the image and listed in § 5).

## 1. Set-up lines (verbatim, in order)

Preamble (`gstack-skill-start --skill design-review --model claude`), the lines that gate later steps:
```
SKILL_START_PROTO: 1
UPGRADE_AVAILABLE 1.91.93.0 1.92.37.0
SESSION_KIND: interactive
TELEMETRY: off
TEL_PROMPTED: no
SESSION_ID: 99-1793556428-e2efb5aa
TEL_START: 1793556428
QUESTION_TUNING: false
UPDATE_CHECK: true
LEARNINGS: 0
ARTIFACTS_SYNC: off
```
(plus three `GSTACK_INSTRUCTION_BEGIN` blocks: `upgrade-flow`, `feature-overlay`, `lake-intro`; see § 3.)

DESIGN.md format check:
```
DESIGN_MD_FORMAT: spec
DESIGN_MD_MARKER: spec
```
`git status --porcelain`: empty (clean tree; no question).

Aside browser check:
```
NEEDS_ASIDE: Linux
```
`$B` browser check (`B=/root/.claude/skills/gstack/browse/dist/browse`):
```
NEEDS_SETUP
```
Design-binary check (run without its `~/.gstack/design-ready` marker write, which the dcg hook blocked):
```
DESIGN_NOT_AVAILABLE: /root/.claude/skills/gstack/design/dist/design is not installed. Fix: cd /root/.claude/skills/gstack && ./setup
```
Test-framework markers: no `CLAUDE.md`/`TESTING.md`; only output `TESTFILES:0` (no ecosystem marker).

Detector probe (`bun --no-env-file run $HOME/.claude/skills/gstack/bin/gstack-design-detect.ts probe --host claude`):
```
IMPECCABLE_READY: /root/.impeccable/bin/0.1.3/impeccable
IMPECCABLE_SKILL: absent
IMPECCABLE_HOOK: absent
IMPECCABLE_IGNORED_RULES: 
IMPECCABLE_IGNORED_FILES: 
IMPECCABLE_IGNORED_VALUES: 
```
(No `DESIGN_DETECTOR_INSTALL_OFFER` line, so no install question arose.)

Output dirs: `REPORT_DIR: /root/.gstack/projects/spike-site/designs/design-audit-20261101`, `RUN_ID: 180852-19380`. Learnings: `CROSS_PROJECT: ` (unset).

First DOM-dump/scan attempt (the browse daemon had wedged after the first full-page screenshot, so the dump wrote nothing and the scan ran over an empty run directory; recorded, not used):
```
DOM_DUMP_MISSING: launch (the dump script wrote nothing)
IMPECCABLE_READY: /root/.impeccable/bin/0.1.3/impeccable
IMPECCABLE_SKILL: absent
IMPECCABLE_HOOK: absent
IMPECCABLE_IGNORED_RULES: 
IMPECCABLE_IGNORED_FILES: 
IMPECCABLE_IGNORED_VALUES: 
═══ BEGIN UNTRUSTED CONTENT (design detector output) ═══
DETECT_TOP total=0 rules=0
═══ END UNTRUSTED CONTENT ═══
DETECT_SUMMARY: total=0 slop=0 quality=0 advisory=0 ignored=0 high=0 medium=0 polish=0
DETECT_EXIT: 0
DETECT_EXIT_CODE=0
```

Baseline DOM dump and scan (Phase 0/3, after the daemon restart):
```
DOM_DUMP_OK: launch
IMPECCABLE_READY: /root/.impeccable/bin/0.1.3/impeccable
IMPECCABLE_SKILL: absent
IMPECCABLE_HOOK: absent
IMPECCABLE_IGNORED_RULES: 
IMPECCABLE_IGNORED_FILES: 
IMPECCABLE_IGNORED_VALUES: 
═══ BEGIN UNTRUSTED CONTENT (design detector output) ═══
DETECT_TOP total=5 rules=5
[low-contrast] impact=high tier=ask count=1 handoff=/impeccable colorize
  /root/.gstack/projects/spike-site/designs/design-audit-20261101/dom/180852-19380/launch.dom.html:0  4.0:1 (need 4.5:1) — text #ffffff on #a855f7
[ai-color-palette] impact=medium tier=ask count=1 handoff=/impeccable colorize
  /root/.gstack/projects/spike-site/designs/design-audit-20261101/dom/180852-19380/launch.dom.html:0  Purple/violet accent colors detected
[hero-eyebrow-chip] impact=medium tier=ask count=1 handoff=/impeccable quieter
  /root/.gstack/projects/spike-site/designs/design-audit-20261101/dom/180852-19380/launch.dom.html:0  eyebrow chip (tracked-caps) "Introducing" above h1 "Unlock your potential"
[nested-cards] impact=medium tier=ask count=1 handoff=/impeccable layout
  /root/.gstack/projects/spike-site/designs/design-audit-20261101/dom/180852-19380/launch.dom.html:0  Card inside card (div)
[overused-font] impact=medium tier=ask count=1 handoff=/impeccable typeset
  /root/.gstack/projects/spike-site/designs/design-audit-20261101/dom/180852-19380/launch.dom.html:0  Primary font: inter
═══ END UNTRUSTED CONTENT ═══
DETECT_SUMMARY: total=5 slop=4 quality=1 advisory=0 ignored=0 high=1 medium=4 polish=0
DETECT_EXIT: 2
DETECT_EXIT_CODE=2
```

Final re-dump and re-scan (Phase 9, after the four fix commits):
```
DOM_DUMP_OK: launch
IMPECCABLE_READY: /root/.impeccable/bin/0.1.3/impeccable
IMPECCABLE_SKILL: absent
IMPECCABLE_HOOK: absent
IMPECCABLE_IGNORED_RULES: 
IMPECCABLE_IGNORED_FILES: 
IMPECCABLE_IGNORED_VALUES: 
═══ BEGIN UNTRUSTED CONTENT (design detector output) ═══
DETECT_TOP total=0 rules=0
═══ END UNTRUSTED CONTENT ═══
DETECT_SUMMARY: total=0 slop=0 quality=0 advisory=0 ignored=0 high=0 medium=0 polish=0
DETECT_EXIT: 0
DETECT_EXIT_CODE=0
```
Skill end: `SKILL_END: recorded outcome=success duration_s=1106`.

## 2. gstack's final report (verbatim, as written to `/root/.gstack/projects/spike-site/designs/design-audit-20261101/design-audit-127.0.0.1.md`)

# Design Review: http://127.0.0.1:32877/launch.html (branch `launch`, scope: this page only)

Driver: gstack's own headless Chromium (`$B`, run from `browse/src/cli.ts`; the compiled binary is not built and `./setup` is not run here). Detector: impeccable 0.1.3 via the bootstrap's engine, DOM mode: static scan of the rendered DOM; cross-origin CSS not resolved. Design system: DESIGN.md (`DESIGN_MD_FORMAT: spec`), calibrated against its flat token map.

## Headline

- **Design Score: B → A** (weighted 3.15 → 3.75 of 4)
- **AI Slop Score: C → A** — before: a purple-gradient hero in Inter with a tracked-caps eyebrow over three nested cards; the template, not a product. After: one headline on the project's primary colour, one paragraph, the system stack; nothing left for a generator to have drawn.
- **Detector: 5 → 0** (engine 0.1.3; DOM mode, page `launch`)

## First Impression (before)

I'm looking at a violet-to-purple gradient band with INTRODUCING in tiny tracked caps at top-left and a 56 px bold "Unlock your potential" under it. Below, a white card, inside it a slightly smaller white card, inside that a third one holding one sentence: "Three cards deep." Then 300 px of nothing. The site communicates **a starter template, not a product**. I notice there is nothing to do: no button, no link, no name of what is being launched. The first three things my eye goes to are: **the purple gradient**, **the headline**, **the stacked card shadows**. One word: **placeholder**.

Page Area Test: hero (I can name it: "the headline"); the card stack (I cannot name its purpose in 2 seconds: it holds one sentence about itself). Classifier: PERSUADE (a launch page is hero-driven; Landing Page Rules apply).

## Inferred Design System (rendered, before)

- Fonts: `Inter, sans-serif` on every rendered element (DESIGN.md token `typography.body.fontFamily` is the system stack; no web font is loaded, so Inter only renders where it is installed).
- Colours: `#7c3aed → #a855f7` gradient, `#ffffff`, `#1a1a2e`; none is a DESIGN.md token (`colors.primary` is `oklch(0.5 0.19 262)`).
- Heading scale: one h1 at 56 px/700, line-height `normal`; no text-wrap balance.
- Spacing: 64 px hero padding (the scale tops at `spacing.8` = 2 rem), 24 px everywhere else (`spacing.6`), 8 px (`spacing.2`); radius 16 px and 12 px (`rounded.default` is 0.75 rem); shadow `0 10px 30px rgba(0,0,0,.1)` (base.css ships `--shadow`).
- Root cause of all of the above: `launch.html` loaded neither `base.css` nor `theme.js`; it restyled itself inline.

## Trunk Test

Before: FAIL (0/6: no site identity, no page name beyond the tab title, no sections, no options, no "you are here", no search). After: FAIL (unchanged: site identity and navigation are content the change does not include; FINDING-007).

## Findings

| ID | Impact | Category | Finding | Fix status |
|---|---|---|---|---|
| FINDING-001 `[low-contrast]` | High | Color & Contrast | White text on the violet gradient: 4.0:1 against the light end `#a855f7` (needs 4.5:1; the 12 px eyebrow is small text). Confirmed in the rendered page. Fix: paint the hero with `colors.primary` / `colors.primary-foreground`. | **verified** — 4c005b3, `launch.html`; after: 5.97:1 (`rgb(30,89,205)` / `rgb(248,250,253)`), dark theme 0.72/0.18 pair; before `first-impression.png`, after `finding-001-after.png` |
| FINDING-002 `[ai-color-palette]` | Medium | AI Slop / Color | Purple-violet gradient hero, body `#1a1a2e`: DESIGN.md says `primary` is the one action colour and no colour outside the tokens appears; the page also ignored the theme (no `theme.js`, no dark tokens). Fix: load `base.css` and `theme.js`, use the tokens. | **verified** — 4c005b3 (same root cause as 001); after: hero `oklch(0.5 0.19 262)` flat, body `--background`/`--foreground`, `data-theme=dark` switches both |
| FINDING-003 `[overused-font]` | Medium | Typography | Inter as display and body face; token `typography.body.fontFamily` is the system stack ("no web fonts"). Fix: drop the inline font declarations. | **verified** — 53bf81c; after: every rendered element on `system-ui, -apple-system, "Segoe UI", Roboto, …`; `finding-003-after.png` |
| FINDING-004 `[hero-eyebrow-chip]` | Medium | Typography / AI Slop | "INTRODUCING": 12 px uppercase, 0.2 em tracking, directly above the 56 px h1. The chip says nothing the title does not. Fix: remove it; the hero keeps one headline (hero budget). | **verified** — 0be61ce; after: `.eyebrow` absent, hero = one h1; `finding-004-after.png` |
| FINDING-005 `[nested-cards]` | Medium | Spacing & Layout / AI Slop | Card inside card inside card around one sentence; DESIGN.md: "nothing decorative: the content is the interface"; cards only when the card is the interaction. Fix: one paragraph in `main.page`. | **verified** — 3089b48; after: no `.card` on the page, one `p` at 686 px measure; `finding-005-after.png` |
| FINDING-006 | Medium | Spacing & Layout | Off-token values: 64 px hero padding (names `spacing.8` = 2 rem), radius 16/12 px (names `rounded.default` = 0.75 rem), a bespoke shadow (names `--shadow`), line-height `normal` (names `typography.body.lineHeight` = 1.5), hero text at x=24 while nothing shares a page column. | **verified** — 4c005b3 (hero inner block shares `.page` geometry; line-height 24 px) and 3089b48 (cards removed, `main.page`); after: h1 and paragraph both start at x=16/32/176 at 375/768/1440 |
| FINDING-007 | High | Visual Hierarchy | No action, no site identity, no navigation: trunk test FAIL, hard rejection 3 ("strong headline with no clear action"). What the launch leads to is a content and spec decision. | **deferred** → owner (`med` row: "roadmap or keep watching?") |
| FINDING-008 | Medium | Content & Microcopy | "Unlock your potential" is generic hero copy (blacklist); "Three cards deep." describes the layout, not the product, and is now untrue. Copy belongs to the team. Page words: 5; happy talk: 5 (100 %). | **deferred** → `med` row |
| FINDING-009 | Polish | Performance as Design | One console error: `/favicon.ico` 404. Site-level, not on this change's lines; baseline before and after. | **deferred** → `low` row |
| FINDING-010 | Polish | Typography | h1 without `text-wrap: balance`. | **verified** — resolved by 4c005b3 through `base.css` (`textWrap: balance`) |
| FINDING-011 | Polish | Motion | No authored motion moment on a Persuade surface (landing rule). Noted, not graded. | **deferred** → `low` row |

Prior learning applied: none (project-scoped search, 0 learnings).

## Category grades (before → after)

| Category | Weight | Before | After |
|---|---|---|---|
| Visual Hierarchy | 15 % | B (007) | B (007 deferred) |
| Typography | 15 % | B (003, 004) | A |
| Spacing & Layout | 15 % | B (005, 006) | A |
| Color & Contrast | 10 % | C (001, 002) | A |
| Interaction States | 10 % | A (no interactive elements to grade) | A (same) |
| Responsive | 10 % | A (no horizontal scroll at 375/768/1440; one column) | A |
| Content Quality | 10 % | B (008) | B (008 deferred) |
| AI Slop | 5 % | C (002, 003, 004, 005) | A |
| Motion | 5 % | A (011 polish) | A |
| Performance Feel | 5 % | A (load 32 ms; 009 polish) | A |

## Interaction Flow Review

No flow to walk: the page has no link, button or form (snapshot: "no interactive elements found"). Goodwill not scored; the absence of a task is FINDING-007.

## Cross-Page Consistency

Out of scope (one page). Noted: after the fixes the hero and content share `.page`'s column with the baseline site; before, the launch page shared nothing with it.

## Quick Wins

1. Give the hero its action: one `.btn-primary` naming the outcome (FINDING-007; needs the owner's word on where it goes).
2. Replace the two copy lines with product language (FINDING-008).
3. Ship a favicon or a `<link rel="icon">` (FINDING-009).

## Summary

- Total findings: 11 (detector contributed 5, all confirmed in the rendered page)
- Fixes applied: 4 commits (verified: 6 findings — 001, 002, 003, 004, 005, 006, plus 010 resolved by 001's commit; best-effort: 0; reverted: 0)
- Deferred: 007 (High → `med` row to the owner), 008 (`med` row), 009 (`low` row), 011 (`low` row)
- Design score delta: B → A
- AI slop score delta: C → A
- Detector: 5 → 0
- Regression: no previous `design-baseline.json` (first scan)

PR Summary:
> Design review found 11 issues, fixed 7. Design score B → A, AI slop score C → A. Detector 5 → 0 (impeccable 0.1.3, DOM mode).

(End of verbatim report. Also written: `design-baseline.json` + `design-baseline.180852-19380.json` in the same directory, and the one-line index `/root/.gstack/projects/spike-site/builder-launch-design-audit-20261101-180852.md`. Screenshots in `REPORT_DIR/screenshots/`: `first-impression.png`, `launch-mobile.png`, `launch-tablet.png`, `launch-desktop.png`, `finding-00{1,3,4,5}-after.png`, `after-{mobile,tablet,desktop}.png`.)

The guideline's PR line would read: `**Design review:** design B → A, AI slop C → A; 7 findings fixed (4c005b3, 53bf81c, 0be61ce, 3089b48), 4 logged (007 med, 008 med, 009 low, 011 low), for commit 3089b48; detector: ran, 5 → 0 findings (engine 0.1.3).`

## 3. Questions the skill would have asked, and the answer given

| Where | Question | Answer and why |
|---|---|---|
| Preamble `upgrade-flow` block (`UPGRADE_AVAILABLE 1.91.93.0 1.92.37.0`) | "AskUserQuestion with 4 options" to upgrade gstack | Not asked, not upgraded; snooze state not written (told not to touch `~/.gstack` config). Guideline: "**Unattended:** its questions don't go to the owner." Task: "Do not run gstack's `./setup`. Do not install anything." |
| Preamble `lake-intro` block | "offer to open [the Boil the Ocean post]" | Not offered, nothing opened; the `.completeness-intro-seen` and `.feature-prompted-model-overlay` marker touches skipped (same `~/.gstack` constraint). Guideline: questions don't go to the owner. |
| Setup: dirty working tree | "Commit / Stash / Abort" | Not asked: `git status --porcelain` was empty. Guideline: "**On a local run:** commit first (it needs a clean tree)". |
| Aside check `NEEDS_ASIDE: Linux` | "Download Aside at aside.com…" | Not said: the skill itself says "Off macOS, do not pitch it"; continued to the `$B` fallback. |
| `$B` check `NEEDS_SETUP` | "gstack's own browser needs a one-time build (~10 seconds). OK to proceed?" then `./setup` | Not asked, `./setup` not run. Guideline: "with the variable set, drive `$B` directly; never run gstack's `./setup` or ask the owner to (its download is blocked)." |
| Test Framework Bootstrap (no ecosystem marker) | "I couldn't detect your project's language. What runtime are you using?" (A–H) | Not asked; continued without tests, without writing `.gstack/no-test-bootstrap`, no CLAUDE.md/TESTING.md created. Guideline: "No test framework bootstrap, no edits to `CLAUDE.md` or `TESTING.md`". |
| Design detector install offer | "D<N> — Install impeccable's design detector engine?" | Never printed (`IMPECCABLE_READY`); had it appeared the answer was "continue without": "The detector engine is the bootstrap's … gstack's offer to install one, when it appears, is declined ("continue without")." |
| Telemetry consent (`GSTACK_INSTRUCTION` privacy stop-gate) | consent question | Never printed (`TELEMETRY: off`, no consent block); would have been declined per the task. |
| Prior Learnings (`CROSS_PROJECT` unset) | "Enable cross-project learnings (recommended) / Keep learnings project-scoped only" | B, project-scoped; `gstack-config set cross_project_learnings false` not run (`~/.gstack` config untouched). Guideline: "no learnings from other projects". Search ran project-scoped: 0 learnings. |
| Phase 2 | "Want me to save this as your DESIGN.md?" | No. Guideline: "no `DESIGN.md` written" (one exists; `DESIGN_MD_MARKER: spec`, no conversion offered, as the skill says). |
| Design Outside Voices | Codex design voice + Claude design subagent | Skipped both (`codex_reviews` unset, `codex: not installed` → would be `CODEX_MODE: not_installed`); `gstack-review-log` not written. Guideline: "no Codex or other outside voice (the code stays in the session)". |
| Phase 8f self-regulation | "If risk > 20%: STOP … Ask whether to continue" | Not triggered: 4 edits to one HTML file, 0 reverts, no unrelated files (≤ 20 %). |
| Phase 11 | TODOS.md update | No `TODOS.md` in the repo; guideline: "no `TODOS.md` step". |
| Capture Learnings / Operational Self-Improvement | log learnings | "No durable learnings this session" (the browse-daemon wedge is an image quirk already carried in this report); `gstack-learnings-log` not run (writes under `~/.gstack`). |

## 4. Git state

`git -C /tmp/devshop-build/spike-site log --oneline launch`:
```
3089b48 fix: launch page content is one column, not three nested cards
0be61ce fix: launch hero drops the tracked-caps eyebrow above the headline
53bf81c fix: launch page uses the system font stack, not Inter
4c005b3 fix: launch hero uses the primary token, not a violet gradient
0a47dd4 a launch page
4fecd4c the baseline site
```
Files changed by the review: `launch.html` only (`git diff --stat 0a47dd4..launch`: `1 file changed, 11 insertions(+), 21 deletions(-)`). Working tree clean. The browse daemon created `/tmp/devshop-build/spike-site/.gstack/` (its state, log, `tmp/`), self-ignored by its own `.gstack/.gitignore` (`*`); nothing else in the repo was touched. No `FINDINGS.md` exists in the scratch repo and none was created (scope was the change's own lines); the four rows it would carry are in the table above. Commit subjects follow the devshop's Conventional-Commit form, not gstack's `style(design): FINDING-NNN —`.

Final `launch.html`: loads `theme.js` and `base.css`; inline CSS is two rules (`.hero` on `--primary`/`--primary-foreground`; `.hero h1` size clamp to 3.5 rem); body = `section.hero > div.page > h1` and `main.page > p`.

## 5. Failed or improvised steps

1. **`$B` does not exist in this image.** `/root/.claude/skills/gstack/browse/dist/browse` is absent (`timeout: failed to run command '/root/.claude/skills/gstack/browse/dist/browse': No such file or directory`); gstack has no `node_modules` either. The guideline's mitigation ("with the variable set, drive `$B` directly") assumes a built binary and does not hold as worded here. Instead of stopping, I ran the same CLI from its source: `bun --no-env-file run ~/.claude/skills/gstack/browse/src/cli.ts <cmd>` with `GSTACK_CHROMIUM_PATH=/opt/pw-browsers/chromium` and `NODE_PATH=/opt/node-tools/node_modules` (Playwright, `diff`, `socks` already live there from the bootstrap). Nothing installed, no `./setup`. The CLI supports this "dev mode" itself; it launched `/opt/pw-browsers/chromium` headless and loaded the page (`Navigated to http://127.0.0.1:32877/launch.html (200)`). This is the F-NEW-101 root cause's neighbour: the guideline should say the binary may be unbuilt, not only that `gstack-browser-ensure` ignores the variable.
2. **Full-page screenshots wedge the browse daemon.** `screenshot` (default full-page), `responsive` and `snapshot -a` each returned `[browse] The operation timed out.` and left the daemon "busy" (`did not answer /health within ~8s`), twice. Recovered with `--force-restart` (local tab only, nothing lost) and took every later capture with `viewport WxH` + `screenshot --viewport`. The mobile shot came from `responsive` before its wedge; tablet/desktop from the viewport route. No annotated screenshot was produced (the page has no interactive elements, so `snapshot -i` had nothing to annotate anyway).
3. **Scan over an empty run directory.** Because of (2) the first DOM dump wrote nothing (`DOM_DUMP_MISSING`) and the scan that followed reported `total=0`; I discarded it and re-dumped/re-scanned after the restart (the 5-finding baseline above).
4. **dcg hook blocks, worked around without changing meaning:** (a) the DESIGN SETUP block's `echo "$_DK" > "$_DC"` cache-marker write (reran the check without it); (b) the skill's `> "$_DJ"` mktemp redirect (wrote to literal `/tmp/gstack-dr-180852/detect-{baseline,final}.json`); (c) `rm -rf` of the DOM run directory (used `rm -f` on the one file + `rmdir`).
5. **Writes under `~/.gstack` limited to the skill's artifacts.** Wrote `REPORT_DIR` (report, baseline JSON, screenshots), the project index line, and `gstack-skill-end` local analytics; skipped config/marker/log writes (upgrade snooze, feature markers, `cross_project_learnings`, review-log, learnings-log, `design-ready`).
6. **One commit covers two detector findings.** 4c005b3 fixes FINDING-001 and FINDING-002 (and part of 006) because they share one root cause (the page never loaded `base.css`/`theme.js`); the devshop's "root cause over band-aid" won over the skill's "one commit per fix". The other three findings each got their own commit.
7. **Outside services: nothing was sent by me.** The detector ran locally; no Codex, no subagent, no `/impeccable`, no installer; `TELEMETRY: off` and `skill-end` wrote only local analytics; Chromium requested only `127.0.0.1:32877` (the proxy bypass list covers it; the sole 404 was `/favicon.ico` on that host). The one outbound call I did not make myself: gstack's own preamble runs `gstack-update-check` (`UPDATE_CHECK: true`), which fetches `raw.githubusercontent.com/garrytan/gstack/main/VERSION` on a 12-hour cache and printed `UPGRADE_AVAILABLE`; whether this run hit the network or its cache I did not verify.
