#!/usr/bin/env bash
# What: Session start hook — injects project context and shows workflow status
# Why: Surfaces open PRs, WIP branches, and init progress so the user picks what to work on
# Does NOT: Run /ak-status or other skills — those still require manual invocation

set -euo pipefail

# Recreate devshop symlinks if missing (git ops can lose them).
if [ ! -L /workspace/.devshop ] && [ -d /devshop/.devshop ]; then
  bash /devshop/.devshop/scripts/create-devshop-symlinks.sh 2>/dev/null || true
fi

# Check security-critical files (warns if missing, stale, or symlinked)
bash /devshop/.devshop/scripts/check-security-files-freshness.sh 2>/dev/null || true

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo /workspace)"
BRANCH="$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "(detached)")"

# --- Context for Claude (not shown to user) ---

CONTEXT=""
CONTEXT+="=== README.md ===
"
CONTEXT+="$(cat "$ROOT/README.md" 2>/dev/null || echo "(README.md not found)")
"
CONTEXT+="
=== BUILD-LOG.md (Status) ===
"
CONTEXT+="$(head -15 "$ROOT/BUILD-LOG.md" 2>/dev/null || echo "(BUILD-LOG.md not found)")
"
CONTEXT+="
=== Current Branch ===
$BRANCH"

# Workaround for anthropics/claude-code#22583: CLAUDE.md from additionalDirectories
# not loaded despite CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1
if [ -f /devshop/CLAUDE.md ]; then
  CONTEXT+="

=== /devshop/CLAUDE.md ===
$(cat /devshop/CLAUDE.md)"
fi

# --- Gather git state ---

# Check for uncommitted changes
DIRTY=""
if ! git -C "$ROOT" diff --quiet 2>/dev/null || ! git -C "$ROOT" diff --cached --quiet 2>/dev/null; then
  DIRTY=" (uncommitted changes)"
fi
UNTRACKED="$(git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null | head -1)"
if [ -n "$UNTRACKED" ]; then
  DIRTY="${DIRTY} (untracked files)"
fi

# Unpushed commits on current branch
UPSTREAM="$(git -C "$ROOT" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)"
UNPUSHED=""
if [ -n "$UPSTREAM" ]; then
  UNPUSHED_COUNT="$(git -C "$ROOT" rev-list --count "$UPSTREAM..HEAD" 2>/dev/null || echo 0)"
  if [ "$UNPUSHED_COUNT" -gt 0 ]; then
    UNPUSHED=" ($UNPUSHED_COUNT unpushed)"
  fi
fi

# Open PRs and WIP branches (single gh call, 5s timeout)
OPEN_PRS=""
WIP_BRANCHES=""
if command -v gh &>/dev/null; then
  PR_JSON="$(timeout 5 gh pr list --state open --limit 20 --json number,title,headRefName 2>/dev/null || true)"
  if [ -n "$PR_JSON" ]; then
    OPEN_PRS="$(echo "$PR_JSON" | jq -r '.[] | "  #\(.number) \(.title) (\(.headRefName))"' 2>/dev/null || true)"
    PR_BRANCHES="$(echo "$PR_JSON" | jq -r '.[].headRefName' 2>/dev/null || true)"
    while IFS= read -r b; do
      [ -z "$b" ] && continue
      [ "$b" = "main" ] || [ "$b" = "master" ] && continue
      if ! echo "$PR_BRANCHES" | grep -qxF "$b"; then
        WIP_BRANCHES+="  $b
"
      fi
    done < <(git -C "$ROOT" branch --format='%(refname:short)' 2>/dev/null)
  fi
fi

# --- Parse BUILD-LOG status ---

PHASE=""
STEP=""
REMAINING=""
INIT_DONE=false
if [ -f "$ROOT/BUILD-LOG.md" ]; then
  PHASE="$(grep -m1 '^\*\*Current phase\*\*' "$ROOT/BUILD-LOG.md" | sed 's/.*: //' || true)"
  STEP="$(grep -m1 '^\*\*Current step\*\*' "$ROOT/BUILD-LOG.md" | sed 's/.*: //' || true)"
  REMAINING="$(grep -m1 '^\*\*Remaining\*\*' "$ROOT/BUILD-LOG.md" | sed 's/.*: //' || true)"
  if [ -z "$REMAINING" ] || [ "$REMAINING" = "None" ] || [ "$REMAINING" = "none" ]; then
    INIT_DONE=true
  fi
fi

# --- Build visible briefing ---

BRIEFING="
────────────────────────────────────────
 lalista — Session Briefing
────────────────────────────────────────
 Branch:  ${BRANCH}${DIRTY}${UNPUSHED}"

# Init section — only if init is not done
if [ "$INIT_DONE" = false ] && [ -n "$PHASE" ]; then
  BRIEFING+="
 Init:    ${STEP:-unknown}"
fi

# Open PRs
if [ -n "$OPEN_PRS" ]; then
  BRIEFING+="
 PRs:
$OPEN_PRS"
else
  BRIEFING+="
 PRs:     (none)"
fi

# WIP branches (no PR yet)
if [ -n "$WIP_BRANCHES" ]; then
  BRIEFING+="
 WIP:
${WIP_BRANCHES%$'\n'}"
fi

BRIEFING+="
────────────────────────────────────────
 /ak-status  — full briefing
 /ak-build   — autonomous build pipeline
 /ak-go-live — autonomous deploy pipeline
────────────────────────────────────────"

# Output as JSON: context for Claude, briefing for user
# SessionStart hooks require the hookSpecificOutput wrapper
jq -n \
  --arg ctx "$CONTEXT" \
  --arg msg "$BRIEFING" \
  '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": $ctx}, "systemMessage": $msg}'
