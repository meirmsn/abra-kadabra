---
name: ak-status
version: 1.0.0
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

Derive feature name from branch, then read feature artifacts:

```bash
BRANCH=$(git branch --show-current)
FEATURE=$(echo "$BRANCH" | sed 's|^feature/||;s|^feat/||;s|^fix/||')
FEATURE_DIR="specs/$FEATURE"
cat "$FEATURE_DIR/spec.md" 2>/dev/null || echo "No active spec"
cat "$FEATURE_DIR/tasks.md" 2>/dev/null || echo "No tasks"
cat "$FEATURE_DIR/review.md" 2>/dev/null || echo "No review yet"
git log --oneline -10
git status --short
```

Also check for in-progress state:

- Any `in_progress` tasks in `$FEATURE_DIR/tasks.md`
- Any uncommitted changes
- Any stashed changes (`git stash list`)

## Output

One paragraph briefing covering:

1. **Phase**: implementing / pre-ship / between features / devshop construction
2. **What's done**: completed tasks or recent commits
3. **What's next**: next task, or next workflow step
4. **Blockers**: anything marked blocked in tasks.md, or uncommitted work that needs attention

Keep it concise — this is a briefing, not a report. Do not modify any files.
