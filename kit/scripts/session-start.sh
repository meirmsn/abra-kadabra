#!/usr/bin/env bash
# What: Session start hook — injects project context and shows workflow status
# Why: Surfaces open PRs, WIP branches, and init progress so the user picks what to work on
# Does NOT: Run /ak-status or other skills — those still require manual invocation

set -euo pipefail

# Recreate devshop symlinks if missing (git ops can lose them).
if [ ! -L /workspace/.devshopkit ] && [ -d /devshop/kit ]; then
  bash /devshop/kit/scripts/create-devshop-symlinks.sh 2>/dev/null || true
fi

# Check security-critical files (warns if missing, stale, or symlinked)
SECURITY_WARN="$(bash /devshop/kit/scripts/check-security-files-freshness.sh 2>/dev/null)" || true

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo /workspace)"
BRANCH="$(git -C "$ROOT" branch --show-current 2>/dev/null || echo "(detached)")"
PROJECT_NAME="$(git -C "$ROOT" remote get-url origin 2>/dev/null | sed 's#.*/##; s/\.git$//' || echo "Project")"

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

# --- Parse init progress (from devshop notes, not project BUILD-LOG) ---

INIT_DONE=true
INIT_STEP=""
INIT_TRACKER="/devshop/kit/notes/projects/${PROJECT_NAME}.md"
if [ -f "$INIT_TRACKER" ]; then
  TOTAL="$(grep -c '^\s*[0-9]\+\. \[' "$INIT_TRACKER" 2>/dev/null || echo 0)"
  DONE="$(grep -c '^\s*[0-9]\+\. \[x\]' "$INIT_TRACKER" 2>/dev/null || echo 0)"
  if [ "$DONE" -lt "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    INIT_DONE=false
    INIT_STEP="$(grep -m1 '^\s*[0-9]\+\. \[ \]' "$INIT_TRACKER" | sed 's/.*\[ \] //' || true)"
    INIT_STEP="${DONE}/${TOTAL} done — next: ${INIT_STEP}"
  fi
fi

# --- Parse latest build from project BUILD-LOG ---

LAST_BUILD=""
if [ -f "$ROOT/BUILD-LOG.md" ]; then
  # Grab the most recent ### heading in the Log section (format: "### feature-name (YYYY-MM-DD)")
  LAST_BUILD="$(grep -m1 '^### ' "$ROOT/BUILD-LOG.md" | sed 's/^### //' || true)"
fi

# --- Cross-repo WIP heads-up (warning only) ---
# Catches uncommitted or stashed work left in either repo from a previous session,
# so Claude doesn't start editing over it. Non-blocking — the user may legitimately
# be resuming WIP. Moved here from a PostToolUse hook during the 2026-04-18 hook
# architecture migration (see kit/notes/roadmap/hook-migration-plan.md).

SESSION_WIP=()
for REPO_DIR in /workspace /devshop; do
  [ ! -d "$REPO_DIR/.git" ] && continue
  REPO_LABEL="$(basename "$REPO_DIR")"
  [ "$REPO_LABEL" = "devshop" ] && REPO_LABEL="devshop (abra-kadabra)"

  WIP_DIRTY="$(git -C "$REPO_DIR" status --porcelain 2>/dev/null | head -5 || true)"
  WIP_STASH_COUNT="$(git -C "$REPO_DIR" stash list 2>/dev/null | wc -l | tr -d ' ' || echo 0)"

  if [ -n "$WIP_DIRTY" ]; then
    SESSION_WIP+=("$REPO_LABEL has uncommitted changes:
$(echo "$WIP_DIRTY" | sed 's/^/    /')")
  fi
  if [ "$WIP_STASH_COUNT" -gt 0 ]; then
    WIP_STASH_LIST="$(git -C "$REPO_DIR" stash list 2>/dev/null | head -3)"
    SESSION_WIP+=("$REPO_LABEL has $WIP_STASH_COUNT stash entrie(s):
$(echo "$WIP_STASH_LIST" | sed 's/^/    /')")
  fi
done

# --- Build visible briefing ---

BRIEFING="
────────────────────────────────────────
 ${PROJECT_NAME} — Session Briefing
────────────────────────────────────────
 Branch:  ${BRANCH}${DIRTY}${UNPUSHED}"

# Init section — only if init is not done
if [ "$INIT_DONE" = false ] && [ -n "$INIT_STEP" ]; then
  BRIEFING+="
 Init:    ${INIT_STEP}"
fi

# Last build — only if there's a build entry
if [ -n "$LAST_BUILD" ]; then
  BRIEFING+="
 Build:   ${LAST_BUILD}"
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

# Cross-repo WIP (uncommitted + stash)
if [ ${#SESSION_WIP[@]} -gt 0 ]; then
  BRIEFING+="
 ⚠ Heads up — WIP from a previous session:"
  for _wip_entry in "${SESSION_WIP[@]}"; do
    BRIEFING+="
   ${_wip_entry}"
  done
fi

# Security warnings (if any)
if [ -n "$SECURITY_WARN" ]; then
  BRIEFING+=$'\n \033[1;31m'"${SECURITY_WARN}"$'\033[0m'
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
