# The metrics comment names the models and splits the tokens behind the dollars

**Go:** pending

## Intent

The owner (2026-10-30), about the "How this change went" comment the devshop posts on a merged PR:
"perhaps in that comment we should put the model used and tokens used?" Then: "Can you show me the
task suggestion and put everything in the prompt so that we can start working on this right away."
The roadmap entry is R-15.

What happened: one session shipped two PRs. The first (a README rewrite) posted `$109.38 ($99.37
session + $10.01 reviewer)` with 50 pushes and 88 reviewer rounds. The second (one image line added to
the README, under four minutes of agent work) posted `$17.85 ($17.82 session + $0.03 reviewer)`. The
$17.82 was not the change: it was the session re-reading its 640k-token context on each of about
twenty wake-ups between the two merges (CI events, the approval, the merge, the metrics retries). The
comment gave no way to see that. Two problems, in the owner's words:

1. "The comment shows dollars only. The session API already exposes what explains them: the model,
   and token counts split by kind (input, output, cache reads, cache writes). For that session: 36k
   input, 272k output, 3.2M cache writes, 160M cache reads. Cache reads were the whole bill."
2. "The script attributes the whole session cost since the previous merge to the PR […]. That is
   right for a one-change session and wrong for a session that ships several PRs, or that idles on
   wake-ups between them."

Done when (owner): the comment on a merged PR shows the model(s) and the token split beside the
dollars; the test fails on the old script for the new fields and passes on the new one, with its
mutants killed; the spec, the `pr` skill and `docs/README.md` say the same thing; the `pr` skill's
description must not grow, and its one-page size is a warning to watch.

## Decisions

- **The tokens and the models come from the transcript, not from `get_session`:** every assistant
  entry of a session's `.jsonl` carries `message.usage` (`input_tokens`, `output_tokens`,
  `cache_creation_input_tokens`, `cache_read_input_tokens`) and `message.model`, checked on this
  session's own transcript on 2026-10-30. So `change-metrics.py` computes them, for any time window,
  and the model passes nothing new: `devshop:pr` § 5 is unchanged, which keeps the always-loaded
  budget. Rejected: passing `get_session`'s `usage` totals and `session_context.model` as new
  arguments, which gives one number for the whole session, needs the earlier totals recorded in the
  marker to take a difference, can't name a second model after a fallback, and grows the skill
  (Claude, 2026-10-30; the owner's "Where the pieces are" suggested passing them, this is the
  alternative, for their decision)
- **One API message, counted once:** Claude Code writes one assistant entry per content block, each
  repeating the same `message.id` and the same `usage`, so the counts are summed over distinct
  `message.id` (seen 2026-10-30: 31 entries, 17 messages; summing entries doubles the numbers). An
  entry with no `message.id` counts on its own (Claude, 2026-10-30)
- **The window the tokens cover is the one the dollars cover:** from the session's previous
  metrics comment (its `created_at`, which `change-metrics.sh` reads from the earlier PR as it reads
  the recorded cost, passed as `--prev-posted`) to the render, or the whole session for its first
  comment. `--cost` minus `--prev-cost` already measures that window, so the two lines explain each
  other, and the session's comments add up to the session's total: every token and dollar is on
  exactly one comment, idle wake-ups included. The line says which window it is: "the session since
  its comment on PR #163", or "the whole session". Rejected: the change's own window (clock start to
  the final state), whose dollars can only be estimated by pro-rating, and a guess never shows
  (owner's rule); and recording the change's start in `devshop:intent` (rejected before, "one more
  moving part"). _(Owner's question 3; proposed, pending their answer.)_
- **The Cost line names the models beside the dollars they explain; the tokens get a line of
  their own:** `$17.85 ($17.82 session on claude-fable-5-1 + $0.03 reviewer on claude-sonnet-5-5)`.
  The session's models are the distinct `message.model` values of the window's messages, in first
  seen order, comma separated; the reviewer's are the distinct `reviewer.model` values of the
  rounds' verdict files, else the third field of the PR's reviewer footers
  (`Independent reviewer · devshop <sha> · <model> · session <id> · $<cost>`). A model that can't be
  read is "an unknown model". Model names are shown as given, never shortened. Rejected: growing the
  Cost line with the tokens too, which wraps twice on a phone; a separate **Model:** line, a seventh
  line for two words _(Owner's question 1; proposed.)_
- **The Tokens line:** `- **Tokens:** 36k input · 272k output · 3.2M cache writes · 160M cache
reads · 25 turns (20 wake-ups) · 640k context at merge · the session since its comment on PR
#163`. Counts under 1,000 are plain; from 1,000 to under 1,000,000 in thousands with no decimals
  ("36k", "272k"); from 1,000,000 up in millions with one decimal, ".0" dropped ("3.2M", "160M").
  Rounding is to the nearest unit; a count that rounds to the next unit's threshold is written in
  that unit ("1.0M" is "1M") _(Owner's question 1; proposed.)_
- **Two numbers flag the pattern earlier than the tokens:** _turns_, the owner messages and wakes in
  the window, with how many were wake-ups (a wake-up is what the transcript already counts as one:
  a check-in, a PR event, a subagent's hand-back), and the _context at merge_: the input side of
  the last API message at or before the merge (`input_tokens` + `cache_creation_input_tokens` +
  `cache_read_input_tokens`), which is what every later wake-up re-reads. Both come from the
  transcript. Rejected: turns per push (the reader divides, pushes are on the Quality line) and the
  context size from `get_session`'s `context_usage.used_tokens`, a new passed value that measures
  the post, not the merge _(Owner's question 2; proposed.)_
- **Unknowns, never guesses** (the owner's standing rule): no transcript, or no usage in the window's
  messages, makes the Tokens line `- **Tokens:** unknown`; a previous metrics comment with no
  readable `created_at` makes it unknown too (the window has no start); no message at or before the
  merge makes the context at merge "unknown context at merge" while the counts still show. The
  Cost line's shape is unchanged for an unknown cost. The marker line is unchanged: the tokens need
  nothing recorded (Claude, 2026-10-30)
- **The PR 7 fixture has no usage** (it was rebuilt from `list_events`, which carries none), so its
  pinned comment (the eleventh item of `specs/deploy-and-metrics-comments.md`) keeps every number and gains "on an
  unknown model" twice and a `- **Tokens:** unknown` line; the made-up session of the same test
  carries usage and models and proves the counting. Rejected: inventing usage for the PR 7 fixture,
  which would pin numbers nobody measured (Claude, 2026-10-30)
- **The check comes first, and is proven to fail:** the test's expected comments carry the new
  fields, so it fails on the script before this change; its mutants (summing entries instead of
  messages, counting messages before the window's start or after the render, a message after the
  merge taken as the context at merge, a wrong unit threshold, a model listed twice, the reviewer's
  footer model read from the wrong field) are each killed by a case in the test (CLAUDE.md rule;
  Claude, 2026-10-30)
- **The interview:** the owner's brief named the three decisions to make and said to start right
  away; this spec asks those three (with the adversarial review's questions) in place of gstack's
  full `/spec` interview, which TARGET gives to features (F-NEW-122). Logged as a sighting of
  F-NEW-78 (Claude, 2026-10-30)
- **Docs:** `docs/README.md`'s "How a change went" entry lists the models and tokens with the other
  numbers and links this spec; `devshop:pr` § 5 is read and found to need no change, said in the PR
  body (Claude, 2026-10-30)

## Acceptance items

- **AC-1** `change-metrics.py render` sums the four usage counts (input, output, cache writes
  and cache reads: `input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
  `cache_read_input_tokens`) over the distinct `message.id`s of the assistant entries whose time is
  after `--prev-posted` (or any time, without it) and not after the render's now, counting an entry
  that repeats another's `message.id` once, and prints them on a **Tokens:** line as
  "<input> input · <output> output · <cache writes> cache writes · <cache reads> cache reads", in
  the Decisions' units ("980", "36k", "272k", "1M", "3.2M", "160M")
- **AC-2** The Tokens line continues with "<n> turns (<m> wake-ups)", the owner messages plus wakes
  in the window and the wakes among them, then "<context> context at merge", the input side of the
  last message at or before the merge, then the window: "the session since its comment on PR #<n>"
  with `--prev-posted`, else "the whole session"; the parts are separated by " · "
- **AC-3** The Cost line reads "$<total> ($<session> session on <models> + $<reviewer> reviewer on
  <models>)": the session's models are the window's distinct `message.model` values in first-seen
  order, comma separated; the reviewer's are the distinct `reviewer.model` values of the counted
  verdict files, else the model field of the PR's reviewer footers; one that can't be read is "an
  unknown model"
- **AC-4** With no transcript, no usage on the window's messages, or a `--prev-posted` that isn't a
  time, the line is "**Tokens:** unknown" and every other line still renders; with usage but no
  message at or before the merge, the counts show and the context is "unknown context at merge";
  the marker line is unchanged
- **AC-5** On the PR 7 fixture the comment is the one `specs/deploy-and-metrics-comments.md` pins
  (its eleventh item) with "on an unknown model" after the session's and the reviewer's dollars and
  a "**Tokens:** unknown" line after the Cost line
- **AC-6** `change-metrics.sh post` passes the earlier PR's metrics comment's `created_at` as
  `--prev-posted` when it passes `--prev-cost`, and the posted comment carries the Tokens line and
  the models
- **AC-7** `tests/change-metrics.test.sh` fails on `change-metrics.py` as of `main` before this
  change (the new fields are missing from its output) — verified by review: run the new test against
  the old script and show the failure
- **AC-8** `docs/README.md`'s "How a change went" entry names the models and the token split among
  what the comment shows and links this spec; `runtime/skills/pr/SKILL.md` is unchanged and
  `scripts/skills-check.py` passes with the `pr` description's word count unchanged — verified by
  review: read the entry and the skill's diff, run the check

## Out of scope

- Passing `get_session`'s token totals or model to the script (the transcript has them)
- Re-posting the metrics comments already posted
- Attributing a change's dollars to its own window by estimate
- Lighthouse or other project quality numbers
- Subagents' transcripts (`subagents/`): their tokens are in their own files; the session's cost
  may include them while the Tokens line doesn't, an accepted gap until one is seen
