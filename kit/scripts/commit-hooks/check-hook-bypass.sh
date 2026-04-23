#!/usr/bin/env bash
# What: PreToolUse hook — blocks git commands that bypass pre-commit hooks
# Why: Pre-commit hooks enforce security (gitleaks, clean-tree, commit guard).
#      Bypassing them silently disables the enforcement chain.
# Does NOT: Block legitimate --no-verify with a reviewed reason

set -euo pipefail

# Read the tool input from stdin (JSON with command)
INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)" || CMD=""
if [ -z "$CMD" ]; then
  echo "BLOCKED: Could not parse tool input. Command blocked as a precaution."
  exit 2
fi

# --- Tier 1: Always block — no legitimate use case ---
if echo "$CMD" | grep -qE 'core\.hooksPath'; then
  cat <<'HOOK_EOF'
BLOCKED: core.hooksPath bypass detected.

Redirecting the hooks path disables all pre-commit enforcement (gitleaks,
typecheck, commit guard). This is never legitimate — use --no-verify with
a devshop.hookBypassReason if you need to skip hooks for a specific commit.
HOOK_EOF
  exit 2
fi

if echo "$CMD" | grep -qE 'HUSKY=0|HUSKY_SKIP'; then
  cat <<'HOOK_EOF'
BLOCKED: HUSKY bypass detected.

Setting HUSKY=0 silently disables all pre-commit hooks. This is never
legitimate — use --no-verify with a devshop.hookBypassReason if you need
to skip hooks for a specific commit.
HOOK_EOF
  exit 2
fi

if echo "$CMD" | grep -qE 'devshop\.humanReviewed'; then
  cat <<'HOOK_EOF'
BLOCKED: devshop.humanReviewed is reserved for human-only use.

This flag bypasses adversarial review entirely. Only a human can use it,
by running the commit directly in the terminal:
  ! git -c devshop.humanReviewed="approve: <assessment>" commit ...
HOOK_EOF
  exit 2
fi

# --- Tier 2: --no-verify without reason → block ---
if echo "$CMD" | grep -qE -- '--no-verify'; then
  # Check if a bypass reason is provided via git -c devshop.hookBypassReason="..."
  REASON=""
  if echo "$CMD" | grep -qE 'devshop\.hookBypassReason='; then
    REASON=$(echo "$CMD" | grep -oP 'devshop\.hookBypassReason=["'"'"']?\K[^"'"'"']*' || true)
    # Also try unquoted value
    [ -z "$REASON" ] && REASON=$(echo "$CMD" | grep -oP 'devshop\.hookBypassReason=\K\S+' || true)
  fi

  if [ -z "$REASON" ]; then
    cat <<'HOOK_EOF'
BLOCKED: --no-verify without bypass reason.

Pre-commit hooks are mandatory. If you have a legitimate reason to skip them
(e.g., migration commit that breaks lint-staged), provide a reason:

  git -c devshop.hookBypassReason="<why hooks must be skipped>" commit --no-verify ...

Your reason will be verified by an independent reviewer.
HOOK_EOF
    exit 2
  fi

  # --- Tier 3: --no-verify with reason → adversarial review ---
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  echo "⏳ Hook bypass: reviewing reason with adversarial agent..."
  REVIEW_RESULT=$(bash "$SCRIPT_DIR/../adversarial-review.sh" hookBypass "$REASON" 2>&1) || {
    cat <<HOOK_EOF
BLOCKED: Adversarial review REJECTED your --no-verify reason.

$REVIEW_RESULT

Fix the issue that requires --no-verify, or provide a better reason.
HOOK_EOF
    exit 2
  }

  # Accepted — log the bypass
  echo "⚠ --no-verify accepted: $REASON" >&2
fi
