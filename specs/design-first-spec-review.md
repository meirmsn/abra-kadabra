# The spec review asks whether the design is right before it checks the details

**Go:** "go", after "2. B" and "3. A" (owner, 2026-10-14)

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

- (Superseded by option C below: § 4 keeps its old wording.) § 4 asks the four design questions
  first, then the existing detail questions, in the same paragraph; the design answers come first in the helper's findings. The skill is at 60 lines and
  589 words of its one-page cap (60 lines, 600 words; `scripts/skills-check.py`), so the detail list
  is reworded shorter rather than the cap raised. Rejected: a separate design-review helper (a
  second agent run per spec, more ceremony for the same questions); a sub-skill or a notes file
  beside the skill holding the questions (a skill's description loads in every session, and either
  is one more place to look, for four short questions) ("you can do inline as you said", owner,
  2026-10-14)
- Step 2 (sharpen) gets one clause: ask why the problem exists before choosing among the fixes on
  offer, and fix the cause when it is within reach. The author applies it while choosing; the
  review in § 4 checks it. Rejected: leaving step 2 alone (the review would then be the only place
  that asks, after the spec is written) ("yes", owner, 2026-10-14)
- The PR reviewer's matching lens (`runtime/reviewer/prompt.md`) is not built here: other sessions
  change `runtime/reviewer/`, and the reviewer has its own eval to re-run. It becomes its own `[ ]`
  task line in W10 (proposed, 2026-10-14)
- The detail list's "missing failure modes" folds into the design question "what new failure modes
  does it add", so it isn't asked twice; every other detail question stays
- The proof is a replay with the same helper the skill names (the `Plan` agent type). Its prompt is
  the § 4 text of the wording under test, quoted as written, plus the spec's path and the owner's
  words. Each spec is replayed from a `git archive` export of the commit it was written on, with no
  `.git`, so the later fix can't be read from history: the first pinned-tools draft (commit
  `59dbdb7` on its branch) and two honest specs as controls, so a false alarm on good plans would
  show: `specs/ci-fast-slow-tiers.md` (exported from `a0a55e4^` with that spec's blob from
  `a0a55e4`) and `specs/ui-baseline.md` (exported from `960a834^` with its blob from `960a834`),
  each with its Go line set back to pending, so the helper can't defer to a recorded go. Both
  controls are final, approved versions; no honest first draft is on record. Rejected: a control
  written for this test (the author would write the answer) (owner chose two controls, "2. B",
  2026-10-14). The owner's words are the spec's own Intent section, which records the request the
  draft was written from; for pinned-tools that is before the owner's "huge solution" message. Each
  spec is reviewed three times with the old § 4 wording and three times with the new one; prompts,
  raw outputs and grading go in `kit/notes/revamp/spikes/w10-6-20-design-first-review/`. Three
  runs, not one: model runs are not deterministic (proposed, 2026-10-14; adversarial review)
- If the old wording flags the pinned-tools draft in 2 or more of 3 runs, the replay can't show the
  new wording helps: the build stops there and the result goes to the owner, who decides whether
  the change is still worth making. The grading rule is not changed after the runs ("3. A", owner,
  2026-10-14)
- Grading is fixed before the runs. A run "flags" a spec only when its design answer calls the
  spec's core design a workaround of a deeper cause, or out of proportion to the problem; naming an
  alternative in passing is not a flag. For the pinned-tools draft, the flag counts only if it names
  the off-PATH install (or linking the tools onto PATH) as the cause or the better design. The
  replay helpers are told to read only their export; a grep of each helper's transcript for paths
  outside it is recorded, and a run that read outside its export is discarded and re-run
- Changed after the go (owner, 2026-10-14, "B", after the first replay failed both bars, LOG #66;
  AC-1, AC-4 and AC-5 rewritten to this outcome when round 2 failed too):
  one more round. The design questions also make the helper argue for the strongest option the
  author rejected or didn't list, and ask whether the change fixes where the problem starts or only
  where it shows (all three round-1 runs named the pinned-tools cause and still accepted the
  draft's rejection of the simpler fix). Round 2 re-runs only the new wording (3 runs per spec, the
  same exports, prompts built the same way) against the same bars, graded by the same rule. The
  pinned-tools draft is no longer held out, since the wording was shaped after seeing its miss. If
  round 2 fails either bar, § 4 goes back to its old wording, only the § 2 clause ships, and the
  finding is recorded (option C)
- Changed after the go (owner, 2026-10-14: "how about we don't do the change to the reviewer, and
  write down the issue in the findings"): W10.6.21, the PR reviewer's lens, is dropped (`[-]`), and
  F-NEW-65 records the blind spot for both reviews, to be refined in rounds when it is seen again;
  AC-6 changed to match

## Acceptance items

- **AC-1** `runtime/skills/intent/SKILL.md` § 4 keeps its wording from before this change, since
  the replay failed both rounds (option C; changed after the go by the owner's "B", 2026-10-14) —
  verified by review: the diff
- **AC-2** `runtime/skills/intent/SKILL.md` § 2 tells the author to ask why the problem exists
  before choosing a fix, and to fix the cause when it is within reach — verified by review: the diff
- **AC-3** The intent skill passes `scripts/skills-check.py` (its one-page cap and the always-loaded
  description budget), so the change adds no length past the cap
- **AC-4** The spike record holds both rounds of the replay: every run's report verbatim, the
  contamination check, and each run graded by the rule fixed before the runs; round 1 shows the
  old and new wording on all three specs, round 2 the new wording on all three — verified by review:
  the spike record
- **AC-5** The finding (design questions in the review prompt neither caught the pinned-tools
  symptom fix nor stayed quiet on the honest specs) is recorded where W10.6.21 will read it before
  it is built — verified by review: the diff
- **AC-6** `kit/notes/revamp/workstreams/W10-v2.md` has a W10.6.20 line for this change and a
  dropped (`[-]`) W10.6.21 line for the PR reviewer's lens with the owner's reason, and
  `kit/notes/revamp/LOG.md` has an entry for it — verified by review: the diff

## Out of scope

- The PR reviewer's prompt (`runtime/reviewer/`) and its eval: not changed (owner, 2026-10-14; F-NEW-65)
- The independent reviewer's spec mode (TARGET Intent 5, an M2 item)
- A catalogue of design patterns or anti-patterns, and any new check script
- Changing the pinned-tools spec or its build
