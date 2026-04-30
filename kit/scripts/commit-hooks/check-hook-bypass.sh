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

# Leading-executable whitelist. The outer `if: Bash(*git*commit*)` matcher
# uses substring globbing, so it fires on any command containing both "git"
# and "commit" — including `gh pr create --body "...git commit..."`.
#
# Strip env-var assignments at command start (KEY=value), then inspect the
# leading executable token. Only proceed when the command actually starts
# with `git` (any path) or `cd` (for `cd /foo && git commit` chains). `gh`,
# `echo`, `pnpm`, etc. can't be a real commit invocation — exit early.
#
# Bypass strings inside env-var prefixes (e.g. `HUSKY=0 git commit`) are
# still caught: env-vars are stripped to find LEAD, but the bypass-string
# regexes below run against $CMD (the original).
#
# A regex-based "actual git commit invocation" check (mirroring
# check-branch-not-main.sh:15) would be too brittle here — its `[^ ]+` token
# trips on quoted values that contain spaces, e.g.
#   git -c devshop.hookBypassReason="just because" commit --no-verify
# which is the canonical legitimate Tier-3 bypass form. The whitelist alone
# closes the realistic false-positive (gh pr create with body text). On the
# remaining surface (commands with leading `git`/`cd` that aren't real
# commits, e.g. `git commit-tree` or `git log --grep="commit"`), the
# bypass-string regexes correctly exit 0 — no false block.
STRIPPED=$(echo "$CMD" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*//')
LEAD=$(echo "$STRIPPED" | awk '{print $1}')
case "$LEAD" in
  git|*/git|cd) ;;  # proceed
  *) exit 0 ;;
esac

# --- Tier 1: Always block — no legitimate use case ---
# Match core.hooksPath only in load-bearing positions:
#   `-c[[:space:]]+core.hooksPath=` — the git -c flag form
#   `git config <flags> core.hooksPath` — persistent config set (bounded to
#     a single command via `[^;&|]*` so a doc citation after a separator
#     doesn't match)
#   `GIT_CONFIG_PARAMETERS=…core.hooksPath` — env-var smuggled config
# Bare `core.hooksPath` mentions in commit messages or doc citations are NOT
# load-bearing and must not match.
if echo "$CMD" | grep -qE '(-c[[:space:]]+["'"'"'`]?core\.hooksPath=|git[[:space:]]+config[[:space:]][^;&|]*core\.hooksPath|GIT_CONFIG_PARAMETERS=[^[:space:]]*core\.hooksPath)'; then
  cat <<'HOOK_EOF'
BLOCKED: core.hooksPath bypass detected.

Redirecting the hooks path disables all pre-commit enforcement (gitleaks,
typecheck, commit guard). This is never legitimate — use --no-verify with
a devshop.hookBypassReason if you need to skip hooks for a specific commit.
HOOK_EOF
  exit 2
fi

# Match HUSKY=0 / HUSKY_SKIP= ONLY when they appear as an env-var prefix
# (start of command, after a shell separator, or after `export`) — not when
# they appear inside a commit message or doc citation. Same anchoring shape
# as DEVSHOP_SKIP_ADVERSARIAL below:
#   ^             — beginning of command
#   [;&|`]        — after ; & | or backtick
#   $\(           — after $( substitution opener
#   followed by optional whitespace, optional `export `, then HUSKY=…
if echo "$CMD" | grep -qE '(^|[;&|`]|\$\()[[:space:]]*(export[[:space:]]+)?(HUSKY=0|HUSKY_SKIP=)'; then
  cat <<'HOOK_EOF'
BLOCKED: HUSKY bypass detected.

Setting HUSKY=0 silently disables all pre-commit hooks. This is never
legitimate — use --no-verify with a devshop.hookBypassReason if you need
to skip hooks for a specific commit.
HOOK_EOF
  exit 2
fi

# Match the actual flag-assignment form (`devshop.humanReviewed=...`), not bare
# mentions of the flag name in commit messages or doc citations. The bypass
# requires the `=` for git -c to apply it.
if echo "$CMD" | grep -qE 'devshop\.humanReviewed='; then
  cat <<'HOOK_EOF'
BLOCKED: devshop.humanReviewed is reserved for human-only use.

This flag bypasses adversarial review entirely. Only a human can use it,
by running the commit directly in the terminal:
  ! git -c devshop.humanReviewed="approve: <assessment>" commit ...
HOOK_EOF
  exit 2
fi

# Match DEVSHOP_SKIP_ADVERSARIAL= ONLY when it appears as an env-var prefix
# (start of command, or after a shell separator) — not when it appears inside
# a commit message or other quoted text. Anchors:
#   ^             — beginning of command
#   [;&|]         — after ; & or | (and-or chains)
#   $\(           — after $( substitution opener
#   `             — after backtick command substitution opener
# Followed by optional whitespace then DEVSHOP_SKIP_ADVERSARIAL=
if echo "$CMD" | grep -qE '(^|[;&|`]|\$\()[[:space:]]*DEVSHOP_SKIP_ADVERSARIAL='; then
  cat <<'HOOK_EOF'
BLOCKED: DEVSHOP_SKIP_ADVERSARIAL bypass detected.

Setting DEVSHOP_SKIP_ADVERSARIAL=1 disables ALL adversarial review for
the process — every bypass flag (dirtyTreeReason, docsReviewed,
manifestReviewed, etc.) auto-passes without judgment. This is never
legitimate from Claude — it would silently neutralize every gate at once.

The env var exists for the human operator's tight iteration loops with
active human review. If you need to bypass a specific check, use that
check's named bypass flag with a reviewable reason:
  git -c devshop.<check>Reason="<specific reason>" commit ...
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
