# A design guideline: read `DESIGN.md` first, the surface rule, and what done means for UI

**Go:** pending

## Intent

The owner asked (2026-10-26) for a decision on "what DevShop should adopt, adapt, or skip so that
every product we build can get sleek, elegant, non-'AI slop' UI through a generic, reusable
process — not one-off prompt poetry", under the research pack's constraints: one design skill, a
persistent `DESIGN.md`, human-made component kits, a screenshot loop, no skill stacking. The
analysis (this session, reviewed adversarially) found the devshop already has that structure and
proposed four changes: a design guideline (this one), impeccable's detector engine in the bootstrap,
a `DESIGN.md` shape check in the fast tier, and the React home's defaults at M3. On the five open
calls (the engine, the surface rule, shadcn/ui as the React default, a new guideline file, the
order A then B then C) the owner said "agree with your 4 recs" (2026-10-31). The design-direction
route itself landed with [`big-changes-in-slices.md`](big-changes-in-slices.md), which names the
rest as "its own change after this one".

## Decisions

- **No new design skill.** gstack's `/design-consultation` (the direction) and `/design-review`
  (the polish and the AI-slop checklist) are the devshop's one design voice; the research's finding
  is that stacked design skills give conflicting art direction and more generic output. Rejected:
  Impeccable's skill, Hallmark, Taste Skill, UI/UX Pro Max and Anthropic's `frontend-design`, each
  a second voice, and the Vercel guidelines skill, which fetches its rules from the web at run
  time (outside content as instructions; the reviewer sandbox has no WebFetch) (owner, 2026-10-31,
  on the analysis)
- **A new guideline, `runtime/guidelines/design.md`:** what a product looks like, beside `ui.md`,
  which keeps how an interface behaves and is checked (the baseline, the two checks, § Design
  direction, § Design review, the reviewer's browser). `build` already loads every guideline a
  change's disciplines touch. Rejected: extending `ui.md`, already past one screen and doing a
  different job (owner, 2026-10-31)
- **The forced read, in `build` § 2:** the disciplines bullet gains one line: a UI change reads the
  project's `DESIGN.md` first (its front matter is the normative tokens, its prose the reasons),
  then `design.md` and `ui.md`. The skill stays within its one-page cap (60 lines, 600 words; it is
  at 58 and 548). Rejected: importing `DESIGN.md` into every session through the project's
  `CLAUDE.md` (every non-UI change pays for it; the reviewer and the design review enforce it, the
  read only helps the builder get it right the first time) (Claude's proposal, 2026-10-31)
- **The surface rule:** a UI change's spec names its surface, `customer-facing` or `internal`
  (admin pages, operator tools); unnamed means customer-facing. Both get `DESIGN.md`, tokens only,
  the two checks, the design review with its High findings fixed, the six screenshots and the
  reviewer. An internal surface skips the variants (one direction, derived from the product's
  `DESIGN.md` where it has one) and the design review's Medium and Polish fixes, which are logged
  instead. Rejected: the full treatment everywhere (the heavy loops cost five to seven minutes a
  change and the owner's phone time; the research reserves them for what customers see) (owner,
  2026-10-31)
- **The placeholder rule:** the baseline's blue accent, or its system font stack as the display
  voice, shipped as a product's brand with no `DESIGN.md` decision is a `design` finding. System
  body text is fine where `DESIGN.md` says so; the website's route (system body, self-hosted display
  faces) stays valid (Claude's proposal, 2026-10-31)
- **Components and motion, the defaults every app inherits:** React stack homes use shadcn/ui, the
  theme CSS generated from `DESIGN.md`'s tokens under the baseline's token names so one
  `tokens-check` covers both, styles in stylesheets (the detector's DOM mode can't see CSS-in-JS);
  apps with no front-end build step keep the baseline CSS. No motion kit as a dependency: one
  authored motion moment per page, named in `DESIGN.md`'s motion section, its block copied into
  the repo; no component-generating MCP. Stated in the guideline now; the Next.js home pins the
  library at M3 (W10.11.7). Rejected: Basecoat for React homes (its point is the shadcn look without
  React) (owner, 2026-10-31)
- **The definition of done for a UI change,** in the guideline, checked by the reviewer by
  reading: the fast-tier checks green; the render check green at 375, 768 and 1280 px in light
  and dark with its six screenshots pinned to the final commit on the PR, plus a row per
  core-flow step and state; the Design review line with its scores and findings, or why it
  could not run, said on the PR and to the owner; the reviewer's `design` and `qa` lenses passing
  on the local run; no value outside `DESIGN.md` and no `DESIGN.md` edit without a recorded
  decision; the owner's approval, which is the human taste pass. Rejected: a new label in
  `pr-body-check.py` (a check change with its own failing tests, for lines the reviewer already
  reads) (Claude's proposal, 2026-10-31)
- **What agent instructions forbid,** as one list in the guideline: a second design voice;
  "make it beautiful, modern, clean" in a spec or prompt (a UI item names tokens and components,
  or a `DESIGN.md` decision); a value `DESIGN.md` doesn't name; the placeholder brand; a motion
  kit, the same entrance on every page, `transition: all`; design rules fetched at run time;
  `@DESIGN.md` in every session (Claude's proposal, 2026-10-31)
- **Two starter lines:** `runtime/templates/project-claude.md` gains one line, UI work starts from
  `DESIGN.md`; `runtime/templates/spec.md`'s Core flow comment gains: the surface, and the
  `DESIGN.md` tokens and components the change uses, anything `DESIGN.md` must gain being a
  decision. Comments only: no change to `spec-check.py` (Claude's proposal, 2026-10-31)
- **The proof is a dry run, graded before it runs,** recorded under `kit/notes/revamp/spikes/`:
  a scratch project from `runtime/templates/ui/` with a `DESIGN.md` in the open format naming a
  display face and an accent the baseline doesn't have, and one small task (add a titled card to
  the page). Two fresh helpers, one each: the control gets `main`'s `build` § 2 and guidelines,
  the guided one this change's. Pass: the guided helper reads `DESIGN.md` before its first edit and
  its CSS names only `DESIGN.md`'s values; the control misses at least one of those. A helper that
  can't start is a could-not-run, re-run once. Rejected: a CI test (CI runs no LLM jobs) (Claude's
  proposal, 2026-10-31)
- **Not here:** `intent`, `split` and `ui.md` § Design direction (the slices change owns them);
  the engine in the bootstrap, the `DESIGN.md` shape check and the Next.js home (their own
  changes, in that order, owner 2026-10-31); the `pr` skill's size

## Acceptance items

- **AC-1** `runtime/guidelines/design.md` exists, within two screens, with: the forced read and
  what in `DESIGN.md` is normative; the surface rule with its default; the placeholder rule; the
  components and motion defaults; the one-voice rule; the definition of done; the forbid list; and
  the font rule (display faces self-hosted as Latin-subset woff2 with their licence, their source
  host named for the allowlist) — verified by review: reading the file
- **AC-2** `runtime/skills/build/SKILL.md` § 2's disciplines bullet says a UI change reads the
  project's `DESIGN.md` first, then `design.md` and `ui.md`; the skills check
  (`scripts/skills-check.py runtime`) prints no problem and no warning for `build`, and
  `tests/skills-check.test.sh` passes — verified by review: the diff and the command's output
  under the PR's Evidence
- **AC-3** `runtime/templates/project-claude.md` has the starter line and
  `runtime/templates/spec.md`'s Core flow comment names the surface and the tokens and components;
  `runtime/scripts/spec-check.py` is unchanged and `tests/spec-check.test.sh` passes — verified by
  review: the diff and CI on the PR's head
- **AC-4** `runtime/guidelines/README.md` and `docs/README.md` link `design.md` and say what it
  holds, and `scripts/docs-map-check.py` passes — verified by review: the diff and CI on the PR's
  head
- **AC-5** The spike record holds the grading (committed before the runs), both helpers' prompts
  and outputs verbatim, and the result: the guided run passes both lines and the control misses at
  least one — verified by review: the record and its commits' order
- **AC-6** `kit/notes/revamp/LOG.md` has an entry, and `kit/notes/revamp/workstreams/W10-v2.md`
  W10.11.7 notes that the React defaults are stated in `design.md` and the home pins them — verified
  by review: the diff

## Out of scope

- impeccable's detector engine in the bootstrap (the next change, with the owner's yes recorded
  there), the `DESIGN.md` shape check (`design-md-check.mjs`) and the stack homes' fast-tier wiring
  of the UI checks, the Next.js home's library pin (M3)
- Any change to `intent`, `split`, `ui.md` § Design direction, `spec-check.py`,
  `pr-body-check.py`, `skills-check.py` or `runtime/templates/pr-body.md`
- A check that enforces the surface rule or the definition of done; both are read by the reviewer
- Native apps (M4)
