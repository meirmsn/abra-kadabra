#!/usr/bin/env bash
# What: PreToolUse hook — blocks git commands that bypass pre-commit hooks
# Why: Pre-commit hooks enforce security (gitleaks, clean-tree, commit guard).
#      Bypassing them silently disables the enforcement chain.
# Does NOT: Block legitimate --no-verify with a reviewed reason

set -euo pipefail

# Read the tool input from stdin (JSON with command)
INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty')"

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
  STAGED=$(git diff --cached --stat 2>/dev/null || true)
  PROMPT="You are a commit guard auditor. Your default position is to REJECT bypass reasons. Be strict.

A developer wants to commit with --no-verify, skipping ALL pre-commit hooks:
- lint-staged (ESLint + Prettier)
- typecheck (TypeScript)
- gitleaks (secret scanning)
- devshop commit guard (mixed commits, docs drift)

Reason given: $REASON

Staged files:
$STAGED

Evaluate:
1. Is this a known legitimate scenario? (migration commits with git rm --cached,
   binary files that break lint-staged, intermediate refactor state with type errors)
2. Is the reason specific to THIS commit, or generic ('will fix later', 'just this once')?
3. Does skipping secret scanning (gitleaks) create a real risk for these files?

Respond with EXACTLY one line:
PASS - only if the reason is genuinely legitimate and specific
FAIL: <what is wrong with the reason>"

  PROMPT_FILE=$(mktemp)
  echo "$PROMPT" > "$PROMPT_FILE"

  REVIEW=$(claude -p --model sonnet < "$PROMPT_FILE" 2>/dev/null) || {
    rm -f "$PROMPT_FILE"
    echo "⚠ Adversarial review API unavailable. Manual review required."
    echo ""
    echo "  --no-verify reason: $REASON"
    echo "  Staged files:"
    echo "$STAGED" | sed 's/^/    /'
    echo ""
    echo "  To approve as human reviewer, run directly in the terminal:"
    echo "    ! git -c devshop.humanReviewed=\"approve: <your assessment>\" -c devshop.hookBypassReason=\"$REASON\" commit --no-verify ..."
    exit 2
  }
  rm -f "$PROMPT_FILE"

  if echo "$REVIEW" | grep -qi "^FAIL"; then
    cat <<HOOK_EOF
BLOCKED: Adversarial review REJECTED your --no-verify reason.

$REVIEW

Fix the issue that requires --no-verify, or provide a better reason.
HOOK_EOF
    exit 2
  fi

  # Accepted — log the bypass
  echo "⚠ --no-verify accepted: $REASON" >&2
fi
