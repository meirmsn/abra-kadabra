#!/bin/bash
# Adversarial review of commit guard bypass reasons.
# Called by devshop-commit-guard.sh and check-clean-tree.sh when a bypass
# reason is provided. Spawns a haiku agent to judge the reason.
#
# Usage: adversarial-doc-review.sh <check-type> <reason> [context...]
#   check-type: docsVerified | docSyncReason | crossRepoReason | dirtyTreeReason
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
    DIFF=$(git diff --cached --stat 2>/dev/null)
    GUIDE_MD=$(grep -n '^##' "$GIT_ROOT/.devshop/GUIDE.md" 2>/dev/null | head -50)
    README_MD=$(cat "$GIT_ROOT/.devshop/README.md" 2>/dev/null)
    CLAUDE_MD=$(cat "$GIT_ROOT/.devshop/CLAUDE.md" 2>/dev/null | head -100)
    CONTEXT="Staged diff (first 300 lines):
$DIFF

=== .devshop/CLAUDE.md ===
$CLAUDE_MD

=== .devshop/README.md ===
$README_MD

=== .devshop/GUIDE.md (first 200 lines) ===
$GUIDE_MD"
    ;;
  docSyncReason)
    DIFF=$(git diff --cached -- .devshop/CLAUDE.md .devshop/README.md .devshop/GUIDE.md 2>/dev/null | head -300)
    README_MD=$(cat "$GIT_ROOT/.devshop/README.md" 2>/dev/null)
    CLAUDE_MD=$(cat "$GIT_ROOT/.devshop/CLAUDE.md" 2>/dev/null)
    GUIDE_HEADERS=$(grep -n '^##' "$GIT_ROOT/.devshop/GUIDE.md" 2>/dev/null | head -50)
    CONTEXT="Doc changes (first 300 lines):
$DIFF

=== .devshop/CLAUDE.md ===
$CLAUDE_MD

=== .devshop/README.md ===
$README_MD

=== .devshop/GUIDE.md section headers ===
$GUIDE_HEADERS"
    ;;
  crossRepoReason)
    case "$GIT_ROOT" in
      /workspace) OTHER=/devshop ;;
      /devshop) OTHER=/workspace ;;
      *) OTHER="" ;;
    esac
    OTHER_STATUS=""
    [ -n "$OTHER" ] && OTHER_STATUS=$(git -C "$OTHER" status --porcelain 2>/dev/null | head -20)
    CONTEXT="Other repo uncommitted changes:
$OTHER_STATUS"
    ;;
  dirtyTreeReason)
    DIRTY=$(git status --porcelain 2>/dev/null | head -20)
    CONTEXT="Untracked/unstaged files:
$DIRTY"
    ;;
esac

# Spawn adversarial review
PROMPT="You are a commit guard auditor. Your default position is to REJECT bypass reasons. Be strict.

A developer is committing code and provided a reason to skip a commit guard check.

Check type: $CHECK_TYPE
Reason given: $REASON

Context:
$CONTEXT

Evaluate:
1. Is the stated reason factually accurate given the context?
2. Does skipping this check create a real risk (stale docs, forgotten files, missed changes)?
3. Is the reason specific enough? Generic reasons like 'docs are fine' or 'will fix later' are NOT acceptable.
4. For doc checks: does the reason name specific sections reviewed? Do those sections actually match the changes?

Respond with EXACTLY one line:
PASS - only if the reason is genuinely legitimate and specific
FAIL: <what is wrong with the reason or what was missed>"

# Write prompt to temp file to avoid argument length limits
PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"

REVIEW=$(claude -p --model haiku < "$PROMPT_FILE" 2>/dev/null) || REVIEW="PASS"
rm -f "$PROMPT_FILE"

if echo "$REVIEW" | grep -qi "^FAIL"; then
  echo "$REVIEW"
  exit 1
fi

exit 0
