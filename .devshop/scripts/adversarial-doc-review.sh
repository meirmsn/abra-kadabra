#!/bin/bash
# PostToolUse hook: adversarial review when commit bypass flags are used.
# Spawns a haiku agent to verify the bypass reason is legitimate.
# Fires after git commit — checks if any devshop.* bypass flag was used.
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Only fire on git commit commands
echo "$COMMAND" | grep -qE 'git.*commit' || exit 0

# Check for any bypass flag
BYPASS_FLAGS=()
echo "$COMMAND" | grep -q 'devshop\.docsVerified' && BYPASS_FLAGS+=("docsVerified")
echo "$COMMAND" | grep -q 'devshop\.docSyncReason' && BYPASS_FLAGS+=("docSyncReason")
echo "$COMMAND" | grep -q 'devshop\.crossRepoReason' && BYPASS_FLAGS+=("crossRepoReason")
echo "$COMMAND" | grep -q 'devshop\.dirtyTreeReason' && BYPASS_FLAGS+=("dirtyTreeReason")

[ ${#BYPASS_FLAGS[@]} -eq 0 ] && exit 0

# Extract the bypass reason(s) from the command
REASONS=$(echo "$COMMAND" | grep -oP 'devshop\.\w+="[^"]*"' || echo "no reason extracted")

# Detect which repo we're in
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "/workspace")

# Build context based on flag types
CONTEXT=""

for FLAG in "${BYPASS_FLAGS[@]}"; do
  case "$FLAG" in
    docsVerified|docSyncReason)
      # Read the staged diff and reference docs
      DIFF=$(git -C "$GIT_ROOT" diff --cached 2>/dev/null | head -200 || echo "no diff")
      CLAUDE_MD=$(cat /devshop/.devshop/CLAUDE.md 2>/dev/null || echo "not found")
      README_MD=$(cat /devshop/.devshop/README.md 2>/dev/null || echo "not found")
      # GUIDE.md is large — read section headers + changed areas
      GUIDE_HEADERS=$(grep -n '^##' /devshop/.devshop/GUIDE.md 2>/dev/null | head -40 || echo "not found")
      CONTEXT+="
=== Staged diff (first 200 lines) ===
$DIFF

=== .devshop/CLAUDE.md ===
$CLAUDE_MD

=== .devshop/README.md ===
$README_MD

=== .devshop/GUIDE.md section headers ===
$GUIDE_HEADERS
"
      ;;
    crossRepoReason)
      case "$GIT_ROOT" in
        /workspace) OTHER=/devshop ;;
        /devshop) OTHER=/workspace ;;
        *) OTHER="" ;;
      esac
      if [ -n "$OTHER" ]; then
        OTHER_STATUS=$(git -C "$OTHER" status --porcelain 2>/dev/null | head -15 || echo "clean")
        CONTEXT+="
=== Other repo ($OTHER) uncommitted changes ===
$OTHER_STATUS
"
      fi
      ;;
    dirtyTreeReason)
      DIRTY=$(git -C "$GIT_ROOT" status --porcelain 2>/dev/null | head -15 || echo "clean")
      CONTEXT+="
=== Untracked/unstaged files in $GIT_ROOT ===
$DIRTY
"
      ;;
  esac
done

# Spawn adversarial review via haiku
PROMPT="You are a commit guard auditor. Your default position is to REJECT bypass reasons.

A developer used bypass flags to skip commit guards. Your job: determine if the bypass is legitimate.

Bypass flags used: ${BYPASS_FLAGS[*]}
Bypass reasons given: $REASONS

Context:
$CONTEXT

For each bypass flag, evaluate:
1. Is the stated reason factually accurate given the context?
2. Does skipping this check create a real risk (stale docs, forgotten files, missed cross-repo changes)?
3. Would a careful human reviewer accept this reason?

Respond with exactly one of:
PASS - if every bypass reason is genuinely legitimate
FAIL: <specific issue> - if any reason is wrong, misleading, or lazy

Be strict. 'Docs are fine' without evidence is not legitimate. 'Will commit separately' for cross-repo is legitimate if the changes are genuinely independent."

REVIEW=$(claude -p --model haiku "$PROMPT" 2>/dev/null || echo "PASS")

if echo "$REVIEW" | grep -qi "^FAIL"; then
  # Escape for JSON
  ESCAPED=$(echo "$REVIEW" | head -10 | jq -Rs . | sed 's/^"//;s/"$//')
  cat <<HOOK_OUTPUT
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"⚠️ ADVERSARIAL DOC REVIEW FAILED\n\n${ESCAPED}\n\nYou used a commit bypass flag and the adversarial reviewer found issues. Fix the problems identified above, amend or create a follow-up commit, and ensure docs are accurate."}}
HOOK_OUTPUT
fi
