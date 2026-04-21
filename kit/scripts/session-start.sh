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

# Backward / forward context — artifacts differ per repo kind.
#   Project sessions: BUILD-LOG.md (shipped history) + PLAN.md (Active + Planned).
#   Devshop sessions: kit/docs/CHANGELOG.md (release history). No PLAN.md yet —
#     devshop uses kit/TODOS.md + kit/ROADMAP.md for forward-looking work.
if [ "$ROOT" = "/devshop" ]; then
  CONTEXT+="
=== kit/docs/CHANGELOG.md (head 25) ===
"
  CONTEXT+="$(head -25 "$ROOT/kit/docs/CHANGELOG.md" 2>/dev/null || echo "(CHANGELOG.md not found)")
"
else
  CONTEXT+="
=== BUILD-LOG.md (head 15) ===
"
  CONTEXT+="$(head -15 "$ROOT/BUILD-LOG.md" 2>/dev/null || echo "(BUILD-LOG.md not found)")
"
  CONTEXT+="
=== PLAN.md (Active + Planned) ===
"
  CONTEXT+="$(awk '/^## Active/{flag=1} /^<!--/{flag=0} flag' "$ROOT/PLAN.md" 2>/dev/null || echo "(PLAN.md not found)")
"
fi

CONTEXT+="
=== Current Branch ===
$BRANCH"

# Workaround for anthropics/claude-code#22583: CLAUDE.md from additionalDirectories
# not loaded despite CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1.
# Only force-load when the session cwd is NOT /devshop — on devshop sessions
# it's already loaded natively via the session cwd's CLAUDE.md discovery.
if [ "$ROOT" != "/devshop" ] && [ -f /devshop/CLAUDE.md ]; then
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

# --- Parse forward/backward orientation signals (per-repo) ---

LAST_BUILD=""        # project: most recent BUILD-LOG.md entry header
NEXT_PLAN=""         # project: top-priority Planned row (Feature + first clause of Notes)
RELEASE_VERSION=""   # devshop: kit/version
COMMITS_SINCE_TAG="" # devshop: commits on main since the latest tag

if [ "$ROOT" = "/devshop" ]; then
  # Devshop session — release-oriented briefing.
  RELEASE_VERSION="$(cat "$ROOT/kit/version" 2>/dev/null || true)"
  LAST_TAG="$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
  if [ -n "$LAST_TAG" ]; then
    COMMITS_SINCE_TAG="$(git -C "$ROOT" rev-list --count "$LAST_TAG..HEAD" 2>/dev/null || echo 0)"
  fi
else
  # Project session — BUILD-LOG last entry + PLAN.md top Planned row.
  if [ -f "$ROOT/BUILD-LOG.md" ]; then
    LAST_BUILD="$(grep -m1 '^### ' "$ROOT/BUILD-LOG.md" | sed 's/^### //' || true)"
  fi
  if [ -f "$ROOT/PLAN.md" ]; then
    # First data row under ## Planned, format `| N | <feature> | <notes> |`
    NEXT_ROW="$(awk '/^## Planned/,/^<!--/' "$ROOT/PLAN.md" 2>/dev/null | grep -m1 '^| [0-9]' || true)"
    if [ -n "$NEXT_ROW" ]; then
      NEXT_FEATURE="$(echo "$NEXT_ROW" | awk -F'|' '{gsub(/^ +| +$/, "", $3); print $3}')"
      # First two sentences of Notes (split on LITERAL ". ", not regex ". ")
      # — gives enough orientation without dumping the full scope blurb.
      NEXT_NOTE="$(echo "$NEXT_ROW" | awk -F'|' '{gsub(/^ +| +$/, "", $4); print $4}' \
        | awk -F'\\. ' '{ if (NF >= 2) print $1 ". " $2 "."; else print $1 }')"
      NEXT_PLAN="${NEXT_FEATURE} — ${NEXT_NOTE}"
    fi
  fi
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

# Project: Build (most recent ship) + Next (top-priority planned row)
if [ -n "$LAST_BUILD" ]; then
  BRIEFING+="
 Build:   ${LAST_BUILD}"
fi
if [ -n "$NEXT_PLAN" ]; then
  BRIEFING+="
 Next:    ${NEXT_PLAN}"
fi

# Devshop: Release (current kit/version) + commits queued since the latest tag
if [ -n "$RELEASE_VERSION" ]; then
  BRIEFING+="
 Release: v${RELEASE_VERSION}"
fi
if [ -n "$COMMITS_SINCE_TAG" ] && [ "$COMMITS_SINCE_TAG" -gt 0 ]; then
  BRIEFING+="
 Queue:   ${COMMITS_SINCE_TAG} commit(s) on main since last tag — /ak-release-devshop to cut"
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
