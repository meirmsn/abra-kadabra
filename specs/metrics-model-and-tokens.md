# The metrics comment names the models and splits the tokens behind the dollars

**Go:** "Go", after choosing "Models on Cost, Tokens line", "Both" and "Same window, labelled" on the three questions (owner, 2026-10-30)

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

The three the owner asked to decide are marked _(owner's question n)_; the owner chose the proposed
answer to each on 2026-10-30 ("Models on Cost, Tokens line", "Both", "Same window, labelled").

- **The tokens and the models come from the transcript, not from `get_session`:** every assistant
  entry of a session's `.jsonl` carries `message.usage` (`input_tokens`, `output_tokens`,
  `cache_creation_input_tokens`, `cache_read_input_tokens`), `message.model` and `message.id`,
  checked on this session's own transcript on 2026-10-30 (and `get_session` showed no `usage`
  object at all mid-turn). So `change-metrics.py` computes them, for any time window, and the model
  passes nothing new: `devshop:pr` § 5 is unchanged, which keeps the always-loaded budget. Rejected:
  passing `get_session`'s `usage` totals and `session_context.model` as new arguments, which gives
  one number for the whole session, needs the earlier totals recorded in the marker to take a
  difference, can't name a second model after a fallback, and grows the skill (Claude, 2026-10-30;
  the owner's brief suggested passing them, this is the alternative, for their decision)
- **The session's subagents count too:** their transcripts are
  `<projects>/*/<session id>/subagents/agent-*.jsonl` (seen 2026-10-30: `isSidechain: true`,
  `sessionId` the session's, the same `message` shape), and the session's `cost_usd` includes them,
  so the Tokens line reads those files beside the session's own, for usage and models only: their
  `user` entries are never owner messages or wakes, and nothing else in the metrics changes
  (Claude, from the spec review, 2026-10-30, which found this session's review subagent at 1.2M
  cache reads)
- **One API message, counted once:** Claude Code writes one assistant entry per content block, each
  repeating the same `message.id` and the same `usage`, so the counts are summed over distinct
  `message.id` across every file read (seen 2026-10-30: 31 entries, 17 messages; summing entries
  doubles the numbers). A message's time is its first entry's timestamp (entries of one message are
  up to 3 s apart). An entry with no `message.id` counts on its own (Claude, 2026-10-30)
- **The window the tokens cover is the one the dollars cover** _(owner's question 3; owner: "Same window, labelled", 2026-10-30)_:
  from the session's previous metrics comment to this render, or the whole session for its first
  comment. `change-metrics.sh` passes that comment's `created_at` as `--prev-posted`, read from the
  same comment whose marker gives `--prev-cost`, `unknown` when it has none, like `--prev-cost`.
  `--cost` minus `--prev-cost` already measures that window, so the two lines explain each other,
  and the Tokens line says which window it is: "the session since its comment on PR #163", or "the
  whole session". Known gaps, inherited from the cost rule and not closed here: a PR the owner
  merged with no session merge before it bills the whole session; a comment posted while the
  earlier PR's is still waiting gets an unknown start; the dollars start at the `get_session` read
  and the tokens at the comment's time, so the message that ran `post` is in one comment's tokens
  and the next one's dollars. Rejected: the change's own window (clock start to the final state),
  whose dollars can only be estimated by pro-rating, and a guess never shows (owner's rule); and
  recording the change's start in `devshop:intent` (rejected before, "one more moving part")
- **The Cost line names the models beside the dollars they explain; the tokens get a line of their
  own** _(owner's question 1; owner: "Models on Cost, Tokens line", 2026-10-30, over their first
  preference of everything on the Cost line, which would wrap twice on a phone)_: `$17.85 ($17.82 session on
claude-fable-5-1 + $0.03 reviewer on claude-sonnet-5-5)`. The session's models are the distinct
  `message.model` values of the window's messages, first-seen order, comma separated; "on an unknown
  model" when none can be read. The reviewer's "on <models>" appears only when rounds were counted:
  the distinct `reviewer.model` values of the counted verdict files that have one; when none has
  one, the model field of the PR's reviewer footers (`Independent reviewer · devshop <sha> ·
<model> · session <id> · $<cost>`); when neither, "on an unknown model". `$0.00 reviewer` (no
  rounds) and `unknown reviewer` (rounds unknown) take no "on". An unknown session cost keeps its
  models: "unknown session on claude-fable-5-1" (Claude, 2026-10-30)
- **The Tokens line** _(owner's question 1, continued)_: `- **Tokens:** 36k input · 272k output ·
3.2M cache writes · 160M cache reads · 25 turns (20 wake-ups) · 640k context at merge · the
session since its comment on PR #163`. Units, rounding half-up: under 1,000 plain ("980"); from
  1,000 in thousands with no decimals ("36k", "272k", 2,500 is "3k"); from 999,500 up in millions
  with one decimal, ".0" dropped ("1M" for 999,500 and for 1,049,999, "1.1M" for 1,050,000, "3.2M",
  "160M")
- **Two numbers flag the pattern earlier than the tokens** _(owner's question 2; owner: "Both",
  2026-10-30; both come from the transcript for free)_: _turns_, the owner messages and wakes in the
  window, with how many were wake-ups (a wake-up is what the transcript already counts as one: a
  check-in, a PR event, a subagent's hand-back), and the _context at merge_: the input side of the
  last API message at or before `merged_at` (`input_tokens` + `cache_creation_input_tokens` +
  `cache_read_input_tokens`), which is what every later wake-up re-reads. Rejected: turns per push,
  which the owner named (the reader divides, pushes are on the Quality line), and the context size
  from `get_session`'s `context_usage.used_tokens`, a new passed value that measures the post, not
  the merge
- **Unknowns, never guesses** (the owner's standing rule), part by part: no transcript makes the
  whole line `- **Tokens:** unknown`; a `--prev-posted unknown` too (the window has no start). With
  a transcript, the turns always show; the four counts are "unknown tokens" when no message in the
  window has usage; the context is "unknown context at merge" when no message with usage is at or
  before the merge. The marker line is unchanged: the tokens need nothing recorded (Claude,
  2026-10-30)
- **The PR 7 fixture has no usage** (it was rebuilt from `list_events`, which carries none), so the
  pinned comment of `specs/deploy-and-metrics-comments.md` (its eleventh item, left there as
  history; this spec's AC-5 is the comment now) keeps every number and gains "on an unknown model"
  for the session, the reviewer's model from the fixture's footers, and the Tokens line with
  unknown counts and the turns the fixture has (10, 8 of them wake-ups, counted 2026-10-30). The
  fixture's footers name the reviewer's model as the literal word `model`; they get the made-up
  `model-example` so the line reads as one. The made-up session of the same test gains usage,
  models, a subagent file, and an earlier comment time, and proves the counting. Rejected:
  inventing usage for the PR 7 fixture, which would pin numbers nobody measured (Claude,
  2026-10-30)
- **The check comes first, and is proven to fail:** the test's expected comments carry the new
  fields, so it fails on the script before this change; its mutants are each killed by a case:
  summing entries instead of messages; a subagent file not read; a message before the window's
  start or after the render counted; a message after the merge, or one exactly at it dropped, as
  the context at merge; the unit thresholds and half-up rounding; a model listed twice; the
  reviewer's model read from the footer's wrong field (CLAUDE.md rule; Claude, 2026-10-30)
- **The interview:** the owner's brief named the three decisions to make and said to start right
  away; this spec asks those three (with the adversarial review's questions) in place of gstack's
  full `/spec` interview, which TARGET gives to features (F-NEW-122). Logged as a sighting of
  F-NEW-78 (Claude, 2026-10-30)
- **Docs:** `docs/README.md`'s "How a change went" entry lists the models and tokens with the other
  numbers and links this spec. `devshop:pr` § 5 names the script and its arguments, not the
  comment's lines, so "the skill says the same thing" is met by it needing no change, said in the
  PR body (Claude, 2026-10-30)

## Acceptance items

- **AC-1** `change-metrics.py render` sums the four usage counts (input, output, cache writes
  and cache reads: `input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
  `cache_read_input_tokens`) over the distinct `message.id`s of the assistant entries of the
  session's files and its `subagents/agent-*.jsonl` files whose first entry's time is after
  `--prev-posted` (or any time, without it) and not after the render's now, counting an entry that
  repeats another's `message.id` once, and prints them on a **Tokens:** line as "<input> input ·
  <output> output · <cache writes> cache writes · <cache reads> cache reads", in the Decisions'
  units with half-up rounding: 980 → "980", 2,500 → "3k", 36,400 → "36k", 999,499 → "999k",
  999,500 → "1M", 1,049,999 → "1M", 1,050,000 → "1.1M", 160,000,000 → "160M"
- **AC-2** The Tokens line continues with "<n> turns (<m> wake-ups)", the owner messages plus wakes
  of the session's own files in the window and the wakes among them, then "<context> context at
  merge", the input side of the last message with usage at or before `merged_at` (one exactly at it
  counts; one after it never), then the window: "the session since its comment on PR #<n>" with
  `--prev-posted`, else "the whole session"; the parts are separated by " · "
- **AC-3** The Cost line reads "$<total> ($<session> session on <models> + $<reviewer> reviewer on
  <models>)": the session's models are the window's distinct `message.model` values in first-seen
  order, comma separated, else "an unknown model"; the reviewer's "on <models>" appears only with
  counted rounds, naming the distinct `reviewer.model` values of the counted verdict files that have
  one, else the model field of the PR's reviewer footers, else "an unknown model"; "$0.00 reviewer"
  and "unknown reviewer" take no "on"; "unknown session on <models>" keeps the models
- **AC-4** With no transcript, or `--prev-posted unknown`, the line is "**Tokens:** unknown" and
  every other line still renders; with a transcript but no usage in the window the turns show with
  "unknown tokens" and "unknown context at merge"; a `--prev-posted` that is neither a time nor
  `unknown` exits 2; the marker line is unchanged
- **AC-5** On the PR 7 fixture, whose footers name `model-example`, the comment is the one
  `specs/deploy-and-metrics-comments.md` pins (its eleventh item) with the Cost line "$4.05 ($3.88
  session on an unknown model + $0.17 reviewer on model-example)" and, after it, the line
  "**Tokens:** unknown tokens · 10 turns (8 wake-ups) · unknown context at merge · the whole
  session"
- **AC-6** `change-metrics.sh post` passes the earlier PR's metrics comment's `created_at` as
  `--prev-posted` (`unknown` when the comment has none) whenever it passes `--prev-cost`, and the
  posted comment carries the Tokens line and the models, the window named by that PR's number
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
- Closing the cost rule's known gaps named in the Decisions (a PR the owner merged first, two
  comments in flight at once)
- Lighthouse or other project quality numbers
