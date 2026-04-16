#!/bin/bash
# Adversarial review of bypass reasons.
# Shared engine for all commit guard checks. Each caller passes a check type;
# this script gathers context, spawns a Sonnet agent to judge the reason,
# and returns PASS (exit 0) or FAIL (exit 1).
#
# Callers: devshop-commit-guard.sh, check-clean-tree.sh, check-hook-bypass.sh
#
# Usage: adversarial-review.sh <check-type> <reason> [context...]
#   check-type: docsVerified | docSyncReason | crossRepoReason | dirtyTreeReason | hookBypass
#   reason: the bypass reason provided via git -c
#   context: additional context (piped or as arguments)
#
# Exit 0 = accepted, exit 1 = rejected (reason on stdout)
set -euo pipefail

CHECK_TYPE="${1:-unknown}"
REASON="${2:-no reason given}"
shift 2 || true

# Gather context based on check type
CONTEXT=""
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

case "$CHECK_TYPE" in
  docsVerified)
    DIFF=$(git diff --cached --stat 2>/dev/null || true)
    DIFF_FULL=$(git diff --cached 2>/dev/null | head -300 || true)
    GUIDE_HEADERS=$(for f in "$GIT_ROOT"/kit/docs/guide/*.md; do echo "--- $(basename "$f") ---"; grep -n '^##' "$f" 2>/dev/null | head -20; done || true)
    README_MD=$(cat "$GIT_ROOT/kit/docs/OVERVIEW.md" 2>/dev/null || true)
    CLAUDE_MD=$(cat "$GIT_ROOT/CLAUDE.md" 2>/dev/null | head -100 || true)
    FAQ_HEADERS=$(grep -n '^##' "$GIT_ROOT/kit/docs/FAQ.md" 2>/dev/null | head -30 || true)
    MODEL_MD=$(cat "$GIT_ROOT/kit/docs/MODEL.md" 2>/dev/null || true)
    PROJECT_CLAUDE=$(cat "/workspace/CLAUDE.md" 2>/dev/null | head -100 || true)
    PROJECT_README=$(cat "$GIT_ROOT/README.md" 2>/dev/null | head -60 || true)
    CONTEXT="Staged diff summary:
$DIFF

Staged diff (first 300 lines):
$DIFF_FULL

=== CLAUDE.md (devshop) (first 100 lines) ===
$CLAUDE_MD

=== kit/docs/MODEL.md ===
$MODEL_MD

=== kit/docs/OVERVIEW.md ===
$README_MD

=== kit/docs/guide/ section headers ===
$GUIDE_HEADERS

=== kit/docs/FAQ.md section headers ===
$FAQ_HEADERS

=== CLAUDE.md (project) (first 100 lines) ===
$PROJECT_CLAUDE

=== README.md (first 60 lines) ===
$PROJECT_README

The reviewer MUST have checked ALL of these docs — not just the ones that already mention the changed code. New functionality needs to be documented for the first time."
    ;;
  docSyncReason)
    DIFF=$(git diff --cached -- CLAUDE.md kit/docs/OVERVIEW.md kit/docs/guide/ 2>/dev/null | head -300 || true)
    README_MD=$(cat "$GIT_ROOT/kit/docs/OVERVIEW.md" 2>/dev/null || true)
    CLAUDE_MD=$(cat "$GIT_ROOT/CLAUDE.md" 2>/dev/null || true)
    GUIDE_HEADERS=$(for f in "$GIT_ROOT"/kit/docs/guide/*.md; do echo "--- $(basename "$f") ---"; grep -n '^##' "$f" 2>/dev/null | head -20; done || true)
    CONTEXT="Doc changes (first 300 lines):
$DIFF

=== CLAUDE.md (devshop) ===
$CLAUDE_MD

=== kit/docs/OVERVIEW.md ===
$README_MD

=== kit/docs/guide/ section headers ===
$GUIDE_HEADERS"
    ;;
  crossRepoReason)
    # Use caller-provided snapshot (avoids TOCTOU with lint-staged stash cycle)
    OTHER_STATUS="${1:-}"
    if [ -z "$OTHER_STATUS" ]; then
      # Fallback: re-check if no snapshot passed
      case "$GIT_ROOT" in
        /workspace) OTHER=/devshop ;;
        /devshop) OTHER=/workspace ;;
        *) OTHER="" ;;
      esac
      [ -n "$OTHER" ] && OTHER_STATUS=$(git -C "$OTHER" status --porcelain 2>/dev/null | head -20 || true)
    fi
    CONTEXT="Other repo uncommitted changes:
$OTHER_STATUS"
    ;;
  dirtyTreeReason)
    DIRTY=$(git status --porcelain 2>/dev/null | grep -E '^\?\?|^ [MD]' | head -20 || true)
    BRANCH=$(git branch --show-current 2>/dev/null || true)
    STASHED=$(git stash list 2>/dev/null | grep -Fi "on $BRANCH:" | head -5 || true)
    CONTEXT="Untracked/unstaged files:
$DIRTY

Stashed changes on current branch ($BRANCH):
${STASHED:-(none)}"
    ;;
  hookBypass)
    STAGED=$(git diff --cached --stat 2>/dev/null || true)
    CONTEXT="The developer wants to commit with --no-verify, skipping ALL pre-commit hooks:
- lint-staged (ESLint + Prettier)
- typecheck (TypeScript)
- gitleaks (secret scanning)
- devshop commit guard (mixed commits, docs drift)

Staged files:
$STAGED"
    ;;
  manifestReviewed)
    CONTEXT="Template file additions/removals vs manifest.txt.
The developer proposes how to handle manifest updates.

Reason: $REASON"
    ;;
esac

# --- Human review fallback (when API is unavailable) ---
# devshop.humanReviewed is blocked by PreToolUse hook for Claude —
# only reachable when human runs git commit directly in terminal.
HUMAN_REVIEW=$(git config --get devshop.humanReviewed 2>/dev/null || true)
if [ -n "$HUMAN_REVIEW" ]; then
  echo "✓ Human-reviewed: $HUMAN_REVIEW"
  exit 0
fi

# Spawn adversarial review
PROMPT="You are a commit guard auditor. Your default position is to REJECT bypass reasons. Be strict.

A developer is committing code and provided a reason to skip a commit guard check.

Check type: $CHECK_TYPE
Reason given: $REASON

Context:
$CONTEXT

Evaluate:
1. Is the stated reason factually accurate given the context?
2. Does skipping this check create a real risk (stale docs, forgotten files, missed changes, leaked secrets)?
3. Is the reason specific enough? Generic reasons like 'docs are fine' or 'will fix later' are NOT acceptable.
4. For doc checks: does the reason name specific sections reviewed? Do those sections actually match the changes?
5. For doc checks: if the diff introduces a NEW capability (new script category, new workflow, new convention, new tool), verify documentation exists at the right level:
   - guide/ section required: what it is, how it works, how to extend it (e.g., conventions.md for testing strategy, hooks.md for new guards)
   - OVERVIEW.md if it changes the workspace layout, event flow, or file map
   - MODEL.md if it adds a new structural component to the kit (rare)
   - CLAUDE.md if it changes how Claude should behave or what workflows to follow
   Layout mentions alone (a line in a tree diagram) are NOT sufficient for new capabilities — strategy/usage docs are also required.
6. For hookBypass: is this a known legitimate scenario (migration commits with git rm --cached, binary files that break lint-staged, intermediate refactor state with type errors)? Does skipping gitleaks create a real risk for these files?

Respond with EXACTLY one line:
PASS - only if the reason is genuinely legitimate and specific
FAIL: <what is wrong with the reason or what was missed>"

# Write prompt to temp file to avoid argument length limits
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

REVIEW=""
BACKOFF_DELAYS=(15 60)
ATTEMPT=0
MAX_ATTEMPTS=$(( ${#BACKOFF_DELAYS[@]} + 1 ))

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  REVIEW=$(timeout 90 claude -p --model sonnet < "$PROMPT_FILE" 2>/dev/null) && break
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    DELAY=${BACKOFF_DELAYS[$((ATTEMPT - 1))]}
    echo "⚠ Adversarial review attempt $ATTEMPT failed. Retrying in ${DELAY}s..."
    sleep "$DELAY"
  fi
done

if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
  rm -f "$PROMPT_FILE"
  echo "⚠ Adversarial review API unavailable after $MAX_ATTEMPTS attempts. Manual review required."
  echo ""
  echo "  Check type: $CHECK_TYPE"
  echo "  Bypass reason: $REASON"
  echo ""
  echo "  Context:"
  echo "$CONTEXT" | head -30 | sed 's/^/    /'
  echo ""
  echo "  To approve as human reviewer, run directly in the terminal:"
  echo "    ! git -c devshop.humanReviewed=\"approve: <your assessment>\" commit ..."
  exit 1
fi
rm -f "$PROMPT_FILE"

if echo "$REVIEW" | grep -qi "^FAIL"; then
  echo "$REVIEW"
  exit 1
fi

exit 0
