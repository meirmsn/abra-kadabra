---
name: ak-status
version: 1.1.0
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
