# The spec review asks whether the design is right before it checks the details

**Go:** pending

## Intent

Seen 2026-10-14, in the session that wrote the pinned-tools spec: the `intent` skill's adversarial
spec review (`runtime/skills/intent/SKILL.md` § 4) asks the read-only helper only about the spec's
internal quality (match with the intent, ambiguity, untestable items, missing edge cases, added
scope, literal code). It never asks whether the design is right. The first pinned-tools proposal (a
SessionStart hook writing PATH through `$CLAUDE_ENV_FILE`, plus new `DEVSHOP:` lines) passed that
review with 15 detail findings, and fixing them made the spec bigger. The owner then asked "seems
like a huge solution (will it bring even more issues?), what is the source of the problem here?".
The root cause was simpler: the tools were installed off PATH, and the fix was one link step in the
bootstrap. A second review that asked design questions first confirmed the smaller fix and found an
existing bug (a failed re-install of a new tool version left the old binary running). The rule
exists in CLAUDE.md ("Root cause over band-aid"), but the review step didn't apply it.

The owner wants the review's helper to answer design questions first, before the detail list: is
this the root cause or a workaround (name the cause); what is the simplest, most reliable design,
including options the author rejected or the owner didn't list; is the size proportionate to the
problem; what new failure modes does it add. Kept short: the skill must stay light (REVIEW-1 warns
against ceremony), no catalogue of patterns. Possibly the author's own step 2 too. Later, a matching
lens in the PR reviewer. Proven by replaying the review on the first pinned-tools proposal and on an
honest, proportionate spec.

## Decisions

- § 4 asks the four design questions first, then the existing detail questions, in the same
  paragraph; the design answers come first in the helper's findings. The skill is at 60 lines and
  589 words of its one-page cap (60 lines, 600 words; `scripts/skills-check.py`), so the detail list
  is reworded shorter rather than the cap raised. Rejected: a separate design-review helper (a
  second agent run per spec, more ceremony for the same questions) (proposed, 2026-10-14)
- Step 2 (sharpen) gets one clause: ask why the problem exists before choosing among the fixes on
  offer, and fix the cause when it is within reach. The author applies it while choosing; the
  review in § 4 checks it. Rejected: leaving step 2 alone (the review would then be the only place
  that asks, after the spec is written) (proposed, 2026-10-14)
- The PR reviewer's matching lens (`runtime/reviewer/prompt.md`) is not built here: other sessions
  change `runtime/reviewer/`, and the reviewer has its own eval to re-run. It becomes its own `[ ]`
  task line in W10 (proposed, 2026-10-14)
- The proof is a replay with the same helper the skill names (the `Plan` agent type), given only
  the spec's path and the owner's words, in a checkout of the commit the spec was written on, so the
  later fix isn't there to read: the first pinned-tools draft (commit `59dbdb7` on its branch) and
  `specs/ci-fast-slow-tiers.md` (the commit before it merged, with the spec file added). Each spec
  is reviewed once with the old § 4 wording and three times with the new one; the prompts, outputs
  and grading go in `kit/notes/revamp/spikes/w10-6-20-design-first-review/`. Model runs are not
  deterministic, so three runs per spec, not one (proposed, 2026-10-14)
- "Flagged" means the helper's design answer says the spec treats a symptom or a workaround, or
  that it is out of proportion, or puts forward a different design as the better one. For the
  pinned-tools draft, the flag counts only if it names the off-PATH install (or linking the tools
  onto PATH) as the cause or the better design

## Acceptance items

- **AC-1** `runtime/skills/intent/SKILL.md` § 4 asks the helper, before the detail questions,
  whether the spec fixes the root cause or a workaround (naming the cause), what the simplest
  reliable design is (rejected and unlisted options included), whether the size is in proportion
  to the problem, and what new failure modes it adds; the detail questions it asked before are all
  still asked — verified by review: the diff
- **AC-2** `runtime/skills/intent/SKILL.md` § 2 tells the author to ask why the problem exists
  before choosing a fix, and to fix the cause when it is within reach — verified by review: the diff
- **AC-3** The intent skill passes `scripts/skills-check.py` (its one-page cap and the always-loaded
  description budget), so the change adds no length past the cap
- **AC-4** In the replay, the new wording flags the first pinned-tools draft in 3 of 3 runs, each
  naming the off-PATH install or linking the tools onto PATH; the old wording's run is recorded
  beside them — verified by review: the spike record
- **AC-5** In the replay, the new wording flags `specs/ci-fast-slow-tiers.md` in 0 of 3 runs —
  verified by review: the spike record
- **AC-6** `kit/notes/revamp/workstreams/W10-v2.md` has a W10.6.20 line for this change and a new
  `[ ]` line for the PR reviewer's lens, and `kit/notes/revamp/LOG.md` has an entry for it —
  verified by review: the diff

## Out of scope

- The PR reviewer's prompt (`runtime/reviewer/`) and its eval: its own task (AC-6)
- The independent reviewer's spec mode (TARGET Intent 5, an M2 item)
- A catalogue of design patterns or anti-patterns, and any new check script
- Changing the pinned-tools spec or its build
