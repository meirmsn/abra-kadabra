---
name: ak-status
version: 1.2.0
description: |
  Session orientation briefing. Reads feature artifacts from specs/<name>/, recent git log,
  current branch, and uncommitted changes. Outputs a one-paragraph briefing of where things stand.
  Use at the start of any new session, or when asked "where are we?", "status", "what's next". (devshop)
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Status

Session orientation — run at the start of any new session to get oriented.

## Gather state

Read project-level context first, then feature artifacts:

```bash
# Project-level state
cat PLAN.md 2>/dev/null                                       # full forward plan — Active + Planned
head -40 BUILD-LOG.md 2>/dev/null                             # intro + most recent ship entries (newest at top)
git log --oneline -10
git status --short
git stash list 2>/dev/null
gh pr list --state open --json number,title,headRefName --jq '.[] | "#\(.number) \(.title) (\(.headRefName))"' 2>/dev/null || echo "No open PRs (or gh not available)"

# All specs (birds-eye view of features with artifacts on disk)
for spec in specs/*/spec.md; do
  [ -f "$spec" ] || continue
  name=$(basename "$(dirname "$spec")")
  has_tasks=$( [ -f "specs/$name/tasks.md" ] && echo "+tasks" || echo "" )
  has_review=$( [ -f "specs/$name/review.md" ] && echo "+review" || echo "" )
  echo "  $name $has_tasks $has_review"
done || echo "No specs"

# Feature-level state (if on a feature branch)
BRANCH=$(git branch --show-current)
FEATURE=$(echo "$BRANCH" | sed 's|^feature/||;s|^feat/||;s|^fix/||')
FEATURE_DIR="specs/$FEATURE"
cat "$FEATURE_DIR/spec.md" 2>/dev/null || echo "No active spec"
cat "$FEATURE_DIR/tasks.md" 2>/dev/null || echo "No tasks"
cat "$FEATURE_DIR/review.md" 2>/dev/null || echo "No review yet"
```

Also check for in-progress state:

- `PLAN.md § Active` rows (what branches are alive and what they're building)
- `PLAN.md § Planned` rows (what's next, ordered)
- Any `in_progress` tasks in `$FEATURE_DIR/tasks.md`
- Any uncommitted changes
- Any stashed changes

## Output

Two parts: the structured one-liner block, then a "Next up" synthesis paragraph when the phase is `between features` and PLAN.md has a Planned row.

### Part 1 — Structured block

Use this exact format — no prose, no paragraphs:

```
Phase:    <init / implementing / pre-ship / between features / devshop>
Branch:   <current branch name>
Active:   <active branches from PLAN.md § Active with their Notes, or "none">
Planned:  <top 1–3 rows from PLAN.md § Planned with their #, or "none">
Recent:   <last 1–2 ship entries from BUILD-LOG.md (feature + PR#), or "none">
Done:     <completed tasks on current branch, recent commits summary>
Next:     <next task, next workflow step, or next init step>
Blocked:  <anything blocked, pending [HUMAN] steps, or "none">
Dirty:    <uncommitted changes, stashes, or "clean">
PRs:      <open PRs with number/title, or "none">
Specs:    <all specs in specs/ with state markers (+tasks, +review), or "none">
```

Keep each line to one sentence. Do not modify any files.

### Part 2 — "Next up" synthesis (conditional)

**When to produce**: phase is `between features` (on main, no active row in PLAN.md) **and** PLAN.md has at least one row under `## Planned`. Skip otherwise.

**What it is**: a 2–4 line paragraph that previews exactly what `/ak-build` would do if invoked right now. This is the regenerable forward orientation the structured `Next:` single-liner can't express — a session-resume view without needing conversation history.

**How to build it**:

1. Read PLAN.md `## Planned` top row (smallest `#`). Extract:
   - **Feature** cell → what `/ak-build` will be invoked on (e.g. `core-flows`)
   - **Notes** cell → scope summary and scope-source pointer (typically `PRODUCT-ROADMAP.md § v0 § 1e` or a gstack plan reference)

2. Follow the scope-source pointer:
   - If it names a `PRODUCT-ROADMAP.md § ...` section, read that section from `PRODUCT-ROADMAP.md` and extract (a) the ~3-bullet scope summary, (b) any open-decisions / questions list (e.g. "Open `/ak-spec`-time decisions" headers with enumerated items).
   - If it names a gstack plan file under `.gstack/projects/<slug>/`, read that and summarize similarly.

3. Discover what `/ak-spec` Step 2 would consume generically:
   - `.gstack/projects/<slug>/*-design-*.md` (newest by mtime) — product design doc
   - `.gstack/projects/<slug>/*-test-plan-*.md` (newest) — test plan
   - `DESIGN.md` at root (if present and the feature touches UI)
   - `.gstack/projects/<slug>/ceo-plans/*.md` (if exists)

4. Synthesize 2–4 lines describing:
   - Command to invoke: `` `/ak-build <feature>` ``
   - What it flips: `PLAN.md § Planned` row #N → `## Active`
   - What `/ak-spec` consumes: the pointer source + discovered gstack files + `DESIGN.md`
   - What pauses for human confirmation: open-decisions / METRICS events / scope questions — with a rough count
   - If the feature's scope source references migrations, tests, or specific components, mention them by name

Use backticks for file paths and command names. No emoji. No additional sections.

**Example output** (for lalista's current state):

> **Next up**: `/ak-build core-flows` flips PLAN.md row 1 (core flows) from Planned → Active. `/ak-spec` will consume `PRODUCT-ROADMAP.md § v0 § 1e` + `DESIGN.md` + `.gstack/projects/meirmsn-lalista/*-design-*.md` + `*-test-plan-*.md`. Expect to pause for 7 open `/ak-spec`-time decisions (theme bootstrap, FAB vs sticky, disambiguation UI, METRICS confirmation, sign-out surface, close-out gates, IA for public landing + `/list`). Migration 009 (ON DELETE FK cascades) lands as the first migration in this PR per the 2026-04-20 decision.

**When Part 2 is skipped**: state one sentence explaining why (`on feature branch — in-flight view lives in tasks.md`, `no planned work — PLAN.md empty`, `init mode — finish setup first`, etc.).
