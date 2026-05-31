---
name: ak-record-friction-log
version: 1.0.0
description: |
  Record a recurring friction / trip-up / devshop-generalizable lesson in
  kit/FRICTION-LOG.md. Scans existing entries for a match BEFORE adding so the
  same issue is never filed twice — on a match it bumps the count + links the
  session (and enriches detail if worth it); on no match it adds a new entry.
  Re-sorts by score (impact × count) and prints a notice if any entry now looks
  big/urgent/impactful (promotion candidate).
  Use when a session surfaces a devshop-generalizable lesson, when asked to
  "log friction", "record a trip-up", "add to the friction log", or as the
  durable destination for CLAUDE.md's "surface devshop-generalizable lessons
  proactively" rule. (devshop)
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - AskUserQuestion
---

# Record friction log

Append (or update) one observation in `kit/FRICTION-LOG.md` — the intake ledger
upstream of `kit/ROADMAP.md` / `kit/TODOS.md` / `PLAN.md`. The ledger's purpose,
entry schema, scoring, and ordering live in `kit/FRICTION-LOG.md`'s own header;
this skill is the **write path** that keeps those invariants (dedup, count,
session-link, sort, escalation notice) reliable instead of hand-maintained.

**Input**: a description of the friction — the symptom + what's known. Comes
from the skill args, or from the lesson the session is surfacing. If the
description is too thin to dedup against (no clear symptom), ask the operator
for one more sentence before proceeding.

This skill **records only**. Promotion into the backlog (ROADMAP/TODOS/PLAN) is
the operator's deliberate call (see § Step 5 and the ledger header).

## Step 0: Resolve the repo + session ref

```bash
ROOT=$(git rev-parse --show-toplevel)
LOG="$ROOT/kit/FRICTION-LOG.md"
TODAY=$(date -u +%Y-%m-%d)
BRANCH=$(git branch --show-current)
```

If `kit/FRICTION-LOG.md` does not exist (it normally does — it ships with the
devshop), scaffold it: write the `# Friction Log` header, the schema/scoring/
ordering description, and an empty `## Open` section, then add
the entry. Don't block on a missing file. (No `## Resolved` section — when a
fix ships its entry is deleted and its history folds into `BUILD-LOG.md`.)

The **session ref** is a short `YYYY-MM-DD — <one-line of what the session was
doing>` string (e.g. `2026-05-29 — /ak-build merge of foo; caught pre-push`).
The date is the same-session dedup key together with the symptom: if an entry's
Sessions list already contains a line for _this_ session's work, do NOT bump the
count again (a single session hitting the same issue twice is still count 1).

## Step 1: Read the whole ledger

Read `kit/FRICTION-LOG.md` in full. You need every entry's `### ` title +
**Symptom** + **Detail** to judge a semantic match, and every **Score** to
re-sort.

## Step 2: Scan for an existing match (the load-bearing step)

Compare the incoming friction against each existing `## Open` entry
**semantically** — match on "is this the same underlying problem?", not on
exact wording. Signals of a match:

- Same skill/script/phase + same failure mode (e.g. both are
  "`/ak-merge-devshop` Phase 2 anchor drift", even if the symptoms read
  differently).
- The incoming symptom is a more-specific instance of an entry's symptom.
- The candidate fixes point at the same code path.

When unsure whether two are the same issue, prefer **match-and-enrich** over a
near-duplicate new entry — a wrongly-merged entry is cheap to split later; a
near-dup silently splits the count signal and defeats the whole point. If
genuinely ambiguous and the impact is high, ask the operator.

## Step 3: Bump, or add

### 3a — Match found, AND this session already in its Sessions list

No-op on count. Optionally enrich **Detail** if this session learned something
new (a sharper mechanism, a confirmed fix, a wider blast radius). Report
"already logged this session" and skip to Step 4 (re-sort is still cheap/safe).

### 3b — Match found, new session

- Append a session line to the entry's **Sessions** list (`- $TODAY — <ref>`).
- Increment **Count** (= new Sessions list length).
- Recompute **Score** = Impact × Count.
- If this session sharpened the understanding, fold it into **Detail** (keep it
  the single best description — don't append a changelog).
- Re-evaluate **Impact** only if new evidence genuinely changes the severity
  (rare); note the change in Detail if so.

### 3c — No match

Create a new `### <title>` entry under `## Open` with every schema field:

- **Title**: names the skill/script/phase + the failure mode, observable-change
  style (same readability bar as commit subjects — no internal jargon).
- **Impact**: 1–5 on the `PLAN.md` scale (XS=1, S=2, M=3, L=4, XL=5) — the
  severity _if it recurs_. Assign it yourself from the evidence; the escalation
  notice (Step 5) is what surfaces big ones for the operator, so you don't need
  to ask unless the rating is a genuine coin-flip between, say, M and XL.
- **Count**: 1. **Score**: Impact × 1.
- **Status**: `open`.
- **First seen**: `$TODAY (<ref>)`.
- **Sessions**: the single `- $TODAY — <ref>` line.
- **Symptom**: the one-line a future session greps for to find this entry.
- **Detail**: mechanism + blast radius + candidate fix, as far as known.
- **Promotion target**: the tracker + section it would land in if promoted.

## Step 4: Re-sort `## Open` by score descending

Rewrite the `## Open` section so entries are ordered by **Score desc**,
tie-broken by **Impact desc**, then most-recently-seen. There is no `## Resolved`
section — when a fix ships its entry is deleted from this log and folded into the
`BUILD-LOG.md` entry, so the log holds only live (`open` / in-flight `promoted →`)
observations. The file must stay valid Markdown with exactly one `### ` heading
per entry.

## Step 5: Escalation notice + handoff

After writing, scan the **whole `## Open` section** (not just the entry you
touched — a bump may have pushed a sibling over the line) and print a notice for
every entry that now looks **big / urgent / impactful**:

- **Impact ≥ 4 (L/XL)** — severe-if-it-recurs, regardless of count, OR
- **Score ≥ 6** — the frequency × severity product is high enough to act, OR
- **Count crossed a round threshold this run** (3, 5, 10) — "this keeps
  happening."

For each flagged entry print: `⚠ <title> — Impact <n>, Count <n>, Score <n>.
Consider promoting to <promotion target>.` If nothing is flagged, say so
explicitly (`No entries currently cross the promotion-notice threshold.`).

The notice is advisory — it never promotes anything itself. Promotion stays the
operator's call (move the item into ROADMAP/TODOS/PLAN, then set the entry's
Status to `promoted → <tracker §>`).

## Step 6: Commit

The ledger lives in `kit/`, so a write is a devshop docs change. Commit on the
current feature branch (never main):

```bash
git add kit/FRICTION-LOG.md
git commit -m "docs(friction-log): <bumped|recorded> <short title>"
```

A bare `kit/FRICTION-LOG.md` edit passes the doc-coverage gate (it IS a doc); no
bypass needed. If the clean-tree guard fires on unrelated WIP, use the
documented `git -c devshop.dirtyTreeReason="…"` bypass — never discard unrelated
dirty files.

## Idempotence

- Re-running with the same friction in the same session → Step 3a no-op (the
  Sessions list already has today's ref); count does not double.
- The scan (Step 2) is the dedup guarantee: a differently-worded report of an
  existing issue bumps, never re-adds.
- Re-sorting (Step 4) is a pure function of the entries' scores — running it
  twice is a no-op.
