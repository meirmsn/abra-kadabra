# A design guideline: read `DESIGN.md` first, the surface rule, and what done means for UI

**Go:** "1. yes 2. ok 3. internal also med" (owner, 2026-10-31, the three questions on the go screen: all five calls, the forced read instead of the import, and Medium fixed on internal surfaces too)

## Intent

The owner asked (2026-10-26): "decide what DevShop should adopt, adapt, or skip so that every
product we build can get sleek, elegant, non-'AI slop' UI through a generic, reusable process—not
one-off prompt poetry", with the research pack's conclusions as constraints: "a persistent design
system (`DESIGN.md` / tokens), one strong design skill with real anti-slop gates, human-made
component kits (e.g. shadcn + selective motion blocks), and a screenshot / browser critique loop";
"Load one primary design skill plus the design-system file; stacking many design skills creates
conflicting art direction"; "reserve heavy polish loops for customer-facing surfaces"; "Human taste
pass still required"; "Wire harness docs correctly (`AGENTS.md` / `CLAUDE.md`; Claude Code often
needs `@DESIGN.md` import)". The analysis (this session, reviewed adversarially) found the devshop
already has that structure and proposed four changes: this guideline, impeccable's detector engine
in the bootstrap, a `DESIGN.md` shape check in the fast tier, and the React home's defaults at M3.
Shown five numbered calls (1 install the pinned detector engine; 2 a lighter treatment for internal
screens; 3 shadcn/ui as the React default over Basecoat; 4 a new guideline file rather than
extending `ui.md`; 5 the order A, B, C, then D with the React app), the owner answered "agree with
your 4 recs" (2026-10-31), and at the go confirmed it meant all five ("1. yes"). The design-direction route itself
landed with [`big-changes-in-slices.md`](big-changes-in-slices.md), whose out-of-scope names the
rest as "its own change after this one".

## Decisions

- **No new design skill.** gstack's `/design-consultation` (the direction) and `/design-review`
  (the polish and the AI-slop checklist) are the one design voice the devshop already runs.
  Rejected: Impeccable's skill, Hallmark, Taste Skill, UI/UX Pro Max and Anthropic's
  `frontend-design`, each a second voice; the Vercel guidelines skill, which fetches its rules from
  the web at run time (outside content as instructions; the reviewer sandbox has no WebFetch)
  (Claude, 2026-10-31, from the owner's constraint of 2026-10-26: one skill, never stacked)
- **A new guideline, `runtime/guidelines/design.md`:** what a product looks like, beside `ui.md`,
  which keeps how an interface behaves and is checked. There is no "design" discipline: `build`
  reads it because its new line names it, with `ui.md`, for every change that changes what a page
  renders; the guidelines README says so. Rejected: extending `ui.md`, already past one screen and
  doing a different job (owner, 2026-10-31, call 4)
- **The forced read, in `build` § 2:** the disciplines bullet gains a sentence: a change that
  changes what a page renders reads the project's `DESIGN.md` first (its front matter is the
  normative tokens, its prose the reasons; with no `DESIGN.md`, the baseline in `ui.md` is the
  design), then `/opt/devshop-current/guidelines/design.md` and `ui.md`. The skill stays within its
  cap (60 lines, 600 words; it is at 58 and 548, and the sentence wraps to two lines). Rejected:
  importing `DESIGN.md` into every session through the project's `CLAUDE.md`, which the owner's
  brief named as what Claude Code often needs: every non-UI change would pay for it, and what
  enforces the design file is the design review and the reviewer, not the import; the read only
  helps the builder get it right the first time. A reversal of the brief, accepted at the go
  ("2. ok", owner, 2026-10-31)
- **What enforces what, said honestly in the guideline:** the independent reviewer reads the PR,
  the project and `DESIGN.md`, never the devshop's guidelines; today it finds a font, colour or
  spacing value `DESIGN.md` doesn't name and a `DESIGN.md` edit without a recorded decision
  (`runtime/reviewer/prompt-browse.md`). The surface rule, the placeholder rule and the definition
  of done are the builder's instructions and the owner's reading of the PR. A reviewer-prompt
  change needs the reviewer eval and is out of scope (Claude, 2026-10-31, after the spec review)
- **The surface rule:** a change that changes what a page renders names its surface in its spec,
  `customer-facing` or `internal` (admin pages, operator tools); unnamed, or a change with no spec
  (a bug fix), means customer-facing. Both get `DESIGN.md`, tokens only, the two checks, the design
  review with its High and Medium findings on the touched lines fixed and Polish logged, the six
  screenshots and the reviewer. The owner's go made Medium the same on both ("3. internal also
  med"), so `ui.md` § Design review's severity mapping stands for every surface and gains one
  sentence saying so. What internal skips is the direction's variants: an internal product's
  direction slice may take one direction instead of two or three, the owner's call at that slice's
  go; § Design direction itself is not edited. Rejected: the full treatment everywhere (the brief
  reserves the heavy loops for what customers see); rejected at the go: internal fixing only High
  (owner, 2026-10-31, call 2 and "3. internal also med")
- **The placeholder rule, once `DESIGN.md` exists:** from the design-direction slice on, the
  baseline's blue accent or its system font stack as the display voice with no `DESIGN.md` decision
  is a design finding. Before it (the walking skeleton, a bug fix on a project with no `DESIGN.md`,
  an app whose owner asked for no direction) the baseline is the brand, as `ui.md` § Design
  direction already makes it. System body text is fine where `DESIGN.md` says so (the website's
  route); fonts as the stack home says (Claude's proposal, 2026-10-31)
- **Components and motion, the defaults every app inherits:** React stack homes use shadcn/ui,
  the theme CSS derived by hand from `DESIGN.md`'s tokens under the baseline's token names so one
  `tokens-check` covers both (the shape check that proves the derivation is the next change),
  styles in stylesheets (the detector's DOM mode can't see CSS-in-JS); apps with no front-end build
  step keep the baseline CSS. No motion kit as a dependency: one authored motion moment per page,
  named in `DESIGN.md`'s motion section, its block copied from the kit's source into the repo with
  the kit's licence file; no component-generating MCP. Stated in the guideline now; the Next.js
  home pins the library at M3. Rejected: Basecoat for React homes (its point is the shadcn look
  without React) (owner, 2026-10-31, call 3)
- **The definition of done for a change that changes what a page renders,** in the guideline: the
  fast-tier checks green; the render check green at 375, 768 and 1280 px in light and dark with its
  six screenshots pinned to the final commit on the PR, plus a row per core-flow step and state;
  the Design review line with its scores and findings, or why it could not run, said on the PR and
  to the owner; the reviewer's `design` and `qa` lenses passing on the local run; once `DESIGN.md`
  exists, no value outside it and no edit to it without a recorded decision; the owner's
  approval, which is the human taste pass. Rejected: a new label in `pr-body-check.py` (a check
  change with its own failing tests, for lines the owner already reads) (Claude's proposal,
  2026-10-31)
- **What agent instructions forbid,** as one list in the guideline: a second design voice; "make
  it beautiful, modern, clean" in a spec or prompt (a UI item names tokens and components, or a
  `DESIGN.md` decision); a value `DESIGN.md` doesn't name; the placeholder brand after the
  direction; a motion kit as a dependency, the same entrance on every page, `transition: all`;
  design rules fetched at run time; `@DESIGN.md` imported into every session (Claude's proposal,
  2026-10-31)
- **Two starter lines:** `runtime/templates/project-claude.md` gains one line, UI work starts from
  `DESIGN.md`; `runtime/templates/spec.md`'s Intent comment (Intent is required, Core flow is not)
  gains: a change that changes what a page renders names its surface and the `DESIGN.md` tokens
  and components it uses, anything `DESIGN.md` must gain being a decision. Comments only, with no
  `{{…}}` in them (the placeholder scan reads raw text): no change to `spec-check.py` (Claude's
  proposal, 2026-10-31)
- **The proof is a dry run, graded before it runs,** recorded under `kit/notes/revamp/spikes/`
  and linked from the docs map: a scratch project from `runtime/templates/ui/` (its theme CSS the
  baseline's, unchanged) with a `DESIGN.md` in the open format naming a display face and an accent
  the baseline doesn't have, and one task the baseline can't satisfy: a page section with its
  heading in the display face and one highlighted figure in the accent, with no matching class in
  `base.css`. Fresh `general-purpose` helpers, which may edit the scratch repo (outside any
  project), two runs per arm: the control gets `main`'s `build` § 2 and guidelines, the guided arm
  this change's. Each helper's output lists the files it read, in order, then its diff. A run
  passes when `DESIGN.md` is read before the first edit and every new literal value in its CSS
  (face, colour) is one `DESIGN.md` names. Pass: both guided runs pass; at least one control run
  misses a line. A helper that can't start is a could-not-run, re-run once; if the re-run can't
  start either, the record says so, no pass is claimed, and the owner hears it. If both control runs
  pass too, the record says the forced read showed no difference on this task; the guideline still
  lands, and the one line stays as cheap insurance unless the owner drops it. Rejected: a CI test
  (CI runs no LLM jobs) (Claude's proposal, 2026-10-31)
- **Not here:** `intent`, `split` and `ui.md` § Design direction (the slices change owns them);
  the reviewer's prompt; the engine in the bootstrap, the `DESIGN.md` shape check and the Next.js
  home (their own changes); the `pr` skill's size

## Acceptance items

- **AC-1** `runtime/guidelines/design.md` exists, at most 120 lines and 1200 words, with: the
  forced read, what in `DESIGN.md` is normative and what applies with none; what enforces what;
  the surface rule with its default and what internal skips; the placeholder rule and when it starts; the
  components and motion defaults; the one-voice rule; the definition of done; the forbid list —
  verified by review: reading the file
- **AC-2** `runtime/skills/build/SKILL.md` § 2's disciplines bullet says a change that changes
  what a page renders reads the project's `DESIGN.md` first, then `design.md` and `ui.md`; the
  skills check (`scripts/skills-check.py runtime`) prints no problem and no warning for `build`,
  and `tests/skills-check.test.sh` passes — verified by review: the diff and the command's output
  under the PR's Evidence
- **AC-3** `runtime/templates/project-claude.md` has the starter line; `runtime/templates/spec.md`'s
  Intent comment names the surface and the tokens and components, with no `{{…}}` added;
  `runtime/scripts/spec-check.py` is unchanged and `tests/spec-check.test.sh` passes — verified by
  review: the diff and CI on the PR's head
- **AC-4** `runtime/guidelines/README.md` says `design.md` is read with `ui.md` by every change
  that changes what a page renders; `runtime/guidelines/ui.md` § Design review has the one
  sentence pointing at the surface rule and nothing else in `ui.md` changes; `docs/README.md` links
  `design.md` and the spike record, and `scripts/docs-map-check.py` passes — verified by review:
  the diff and CI on the PR's head
- **AC-5** The spike record holds the grading (committed before the runs), the scratch
  `DESIGN.md`, the task, every helper's prompt and output verbatim (files read in order, the diff),
  and the result against the pass rule in Decisions, could-not-runs included — verified by review:
  the record and its commits' order
- **AC-6** `kit/notes/revamp/LOG.md` has an entry, and `kit/notes/revamp/workstreams/W10-v2.md`
  W10.8.3 and W10.11.7 carry a dated note that the React defaults are stated in `design.md` and the
  home pins the library at M3 — verified by review: the diff

## Out of scope

- impeccable's detector engine in the bootstrap (the next change, with the owner's yes recorded
  there), the `DESIGN.md` shape check (`design-md-check.mjs`) and the stack homes' fast-tier wiring
  of the UI checks, the Next.js home's library pin (M3)
- Any change to the reviewer's prompt or `review.sh`, to `intent`, `split`, `ui.md` § Design
  direction, `spec-check.py`, `pr-body-check.py`, `skills-check.py` or `runtime/templates/pr-body.md`
- A check that enforces the surface rule or the definition of done; both are read by the builder
  and the owner
- Native apps (M4)
