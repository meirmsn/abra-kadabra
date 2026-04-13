#!/bin/bash
# devshop-commit-guard.sh — commit-time guard for devshop hygiene.
# Runs as a Claude Code PreToolUse hook (triggered on Bash(git commit*)).
#
# Four checks (all blocking via exit 2):
#   1. Mixed commit detection: devshop + project files staged together (project repo only)
#   2. Docs drift detection: devshop tooling changed without docs update
#   3. Reference doc consistency: one doc changed without verifying the others
#   4. Cross-repo awareness: uncommitted changes in the other repo
#
# Bypass: pass a reason via git -c flag:
#   git -c devshop.<key>="<reason>" commit -m "..."
# The hook reads the pending command from Claude Code stdin (JSON) to extract -c flags.
# When running outside Claude (e.g., manual git commit), git -c works natively.
set -euo pipefail

# --- Read pending command from Claude Code hook stdin ---
# Claude Code passes tool input as JSON on stdin for PreToolUse hooks.
# When stdin is a terminal (manual execution), skip — git -c works natively via git config.
HOOK_COMMAND=""
if [ ! -t 0 ]; then
  HOOK_INPUT=$(cat)
  HOOK_COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
fi

# Extract a git -c bypass value. Checks the pending command first (Claude hook context),
# then falls back to git config (manual/git-hook context where -c is inherited).
get_bypass() {
  local key="$1"
  if [ -n "$HOOK_COMMAND" ]; then
    # Match: -c key="quoted value"
    local val
    val=$(echo "$HOOK_COMMAND" | sed -n "s/.*-c ${key}=\"\([^\"]*\)\".*/\1/p")
    if [ -z "$val" ]; then
      # Match: -c key=unquoted_value
      val=$(echo "$HOOK_COMMAND" | sed -n "s/.*-c ${key}=\([^ \"]*\).*/\1/p")
    fi
    [ -n "$val" ] && echo "$val" && return 0
  fi
  git config --get "$key" 2>/dev/null && return 0
  return 1
}

# --- Repo detection ---
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
case "$GIT_ROOT" in
  /workspace) CURRENT_REPO=project; OTHER_REPO=/devshop;  OTHER_NAME="devshop (abra-kadabra)" ;;
  /devshop)   CURRENT_REPO=devshop; OTHER_REPO=/workspace; OTHER_NAME="project" ;;
  *)          CURRENT_REPO=unknown; OTHER_REPO="";          OTHER_NAME="" ;;
esac

STAGED=$(git diff --cached --name-only)
[ -z "$STAGED" ] && exit 0

FAILED=false

# --- Classify staged files ---
# Used by check 1 (project repo only) and check 2 (both repos, as guard condition).
DEVSHOP_PATTERNS=(
  '^\.devshop/'
  '^\.claude/'
  '^\.dcg\.toml$'
  '^CLAUDE\.md$'
  '^BUILD-LOG\.md$'
)
DEVSHOP_REGEX=$(IFS='|'; echo "${DEVSHOP_PATTERNS[*]}")

DEVSHOP_FILES=()
PROJECT_FILES=()
AMBIGUOUS_FILES=()

while IFS= read -r file; do
  [ -z "$file" ] && continue
  if echo "$file" | grep -qE "$DEVSHOP_REGEX"; then
    DEVSHOP_FILES+=("$file")
  elif echo "$file" | grep -qE '^\.claude/|^\.devshop/'; then
    AMBIGUOUS_FILES+=("$file")
  else
    PROJECT_FILES+=("$file")
  fi
done <<< "$STAGED"

# --- Check 1: Mixed commit detection (project repo only) ---
# In the devshop repo all files are devshop content (including templates).
# This check only applies to the project repo where devshop files should be gitignored.
if [ "$CURRENT_REPO" = "project" ]; then
  if [ ${#DEVSHOP_FILES[@]} -gt 0 ] && [ ${#PROJECT_FILES[@]} -gt 0 ]; then
    echo "" >&2
    echo "✖ Mixed commit: devshop + project files staged together." >&2
    echo "  Devshop changes should be in separate commits." >&2
    echo "" >&2
    echo "  Devshop files:" >&2
    for f in "${DEVSHOP_FILES[@]}"; do echo "    $f" >&2; done
    echo "  Project files:" >&2
    for f in "${PROJECT_FILES[@]}"; do echo "    $f" >&2; done
    echo "" >&2
    echo "  Unstage one set and commit separately." >&2
    FAILED=true
  fi

  if [ ${#AMBIGUOUS_FILES[@]} -gt 0 ]; then
    echo "" >&2
    echo "✖ Ambiguous files — devshop or project? Review these staged files:" >&2
    for f in "${AMBIGUOUS_FILES[@]}"; do echo "    $f" >&2; done
    echo "" >&2
    echo "  If devshop: move to a separate commit." >&2
    echo "  If project: add the path to the project-layer exception in this script." >&2
    FAILED=true
  fi
fi

# --- Check 2: Docs drift detection ---
# When devshop tooling changes, verify docs are updated.
# In the project repo: only fires when devshop files are staged (safety net).
# In the devshop repo: always fires (this is where tooling changes happen).
RUN_DRIFT_CHECK=false
if [ "$CURRENT_REPO" = "devshop" ]; then
  RUN_DRIFT_CHECK=true
elif [ "$CURRENT_REPO" = "project" ] && [ ${#DEVSHOP_FILES[@]} -gt 0 ]; then
  RUN_DRIFT_CHECK=true
fi

if [ "$RUN_DRIFT_CHECK" = true ]; then
  DRIFT_WARNINGS=()

  echo "$STAGED" | grep -q '^\.husky/pre-commit$' && \
    DRIFT_WARNINGS+=("  .husky/pre-commit changed → verify GUIDE.md § Commit Flow + CLAUDE.md § Non-Negotiables")

  echo "$STAGED" | grep -q '^\.claude/settings\.json$' && \
    DRIFT_WARNINGS+=("  .claude/settings.json changed → verify GUIDE.md § Claude Code Hooks table")

  echo "$STAGED" | grep -q '^\.claude/skills/devshop/' && \
    DRIFT_WARNINGS+=("  Devshop skill changed → verify GUIDE.md § Devshop Skill Map")

  echo "$STAGED" | grep -q '^\.devshop/scripts/' && \
    DRIFT_WARNINGS+=("  Devshop script changed → verify GUIDE.md references to changed scripts")

  echo "$STAGED" | grep -q '^\.github/workflows/' && \
    DRIFT_WARNINGS+=("  Workflow changed → verify GUIDE.md § CI/CD section")

  echo "$STAGED" | grep -q '^\.devshop/FAQ\.md$' && \
    DRIFT_WARNINGS+=("  FAQ.md changed → verify README.md § Further Reading still lists it")

  echo "$STAGED" | grep -q '^\.claude/skills/devshop/init/SKILL\.md$' && \
    DRIFT_WARNINGS+=("  Init skill changed → verify .devshop/templates/README.md.tmpl still matches")

  if [ ${#DRIFT_WARNINGS[@]} -gt 0 ]; then
    NON_CHANGELOG=$(echo "$STAGED" | grep -E "$DEVSHOP_REGEX" | grep -vE '^\.devshop/(CHANGELOG\.md|version)$' || true)

    if [ -n "$NON_CHANGELOG" ]; then
      BYPASS_DOCS=$(get_bypass devshop.docsVerified || true)

      if [ -n "$BYPASS_DOCS" ]; then
        echo "✓ Docs drift verified: $BYPASS_DOCS" >&2
      else
        echo "" >&2
        echo "✖ Devshop tooling changed — verify docs are up to date:" >&2
        for w in "${DRIFT_WARNINGS[@]}"; do echo "$w" >&2; done
        echo "" >&2
        echo "  Explain what you verified (even if docs are co-staged):" >&2
        echo "    git -c devshop.docsVerified=\"<what you checked>\" commit ..." >&2
        FAILED=true
      fi
    fi
  fi
fi

# --- Check 3: Reference doc consistency ---
# When any devshop reference doc is staged, the committer must either:
#   (a) stage all three docs, or
#   (b) certify consistency by providing a reason why unstaged docs don't need updating.
#
# Each doc has a different scope — not every change needs all three updated:
#   .devshop/CLAUDE.md  — agent rules and config (what Claude must/must not do)
#   .devshop/README.md  — bird's eye overview (~80 lines, orientation only)
#   .devshop/GUIDE.md   — full operational reference (workflow, checklists, conventions)
HAS_CLAUDE_MD=false
HAS_README=false
HAS_GUIDE=false
echo "$STAGED" | grep -q '^\.devshop/CLAUDE\.md$' && HAS_CLAUDE_MD=true
echo "$STAGED" | grep -q '^\.devshop/README\.md$' && HAS_README=true
echo "$STAGED" | grep -q '^\.devshop/GUIDE\.md$' && HAS_GUIDE=true

DOC_COUNT=0
CHANGED_DOCS=()
UNCHANGED_DOCS=()
$HAS_CLAUDE_MD && DOC_COUNT=$((DOC_COUNT + 1)) && CHANGED_DOCS+=("CLAUDE.md") || UNCHANGED_DOCS+=(".devshop/CLAUDE.md  (agent rules)")
$HAS_README && DOC_COUNT=$((DOC_COUNT + 1)) && CHANGED_DOCS+=("README.md") || UNCHANGED_DOCS+=(".devshop/README.md  (overview)")
$HAS_GUIDE && DOC_COUNT=$((DOC_COUNT + 1)) && CHANGED_DOCS+=("GUIDE.md") || UNCHANGED_DOCS+=(".devshop/GUIDE.md   (full reference)")

if [ "$DOC_COUNT" -gt 0 ] && [ "$DOC_COUNT" -lt 3 ]; then
  CHANGED_LIST=$(IFS=', '; echo "${CHANGED_DOCS[*]}")
  BYPASS_DOC_SYNC=$(get_bypass devshop.docSyncReason || true)

  if [ -n "$BYPASS_DOC_SYNC" ]; then
    echo "✓ Doc consistency verified: $BYPASS_DOC_SYNC" >&2
  else
    echo "" >&2
    echo "✖ Reference doc changed ($CHANGED_LIST) — verify the others are consistent:" >&2
    for doc in "${UNCHANGED_DOCS[@]}"; do echo "    $doc" >&2; done
    echo "" >&2
    echo "  Not every change needs all three updated — each doc has a different scope." >&2
    echo "  If the unstaged docs are already consistent, bypass with a reason:" >&2
    echo "    git -c devshop.docSyncReason=\"<reason>\" commit ..." >&2
    echo "" >&2
    echo "  Examples:" >&2
    echo "    \"operational detail — below README overview scope, no rule changes\"" >&2
    echo "    \"agent rule change — README overview unchanged, GUIDE procedures unaffected\"" >&2
    echo "    \"overview wording — GUIDE already covers this, no rule impact\"" >&2
    FAILED=true
  fi
fi

# --- Check 4: Cross-repo awareness ---
# When committing in one repo, check if the other has uncommitted changes.
# Prevents forgetting to commit related changes in the companion repo.
if [ -n "$OTHER_REPO" ] && [ -d "$OTHER_REPO/.git" ]; then
  OTHER_DIRTY=$(git -C "$OTHER_REPO" status --porcelain 2>/dev/null | head -10 || true)

  if [ -n "$OTHER_DIRTY" ]; then
    BYPASS_CROSS_REPO=$(get_bypass devshop.crossRepoReason || true)

    if [ -n "$BYPASS_CROSS_REPO" ]; then
      echo "✓ Cross-repo skip: $BYPASS_CROSS_REPO" >&2
    else
      echo "" >&2
      echo "✖ The $OTHER_NAME repo has uncommitted changes:" >&2
      echo "$OTHER_DIRTY" | sed 's/^/    /' >&2
      echo "" >&2
      echo "  Commit there too, or bypass with a reason:" >&2
      echo "    git -c devshop.crossRepoReason=\"<reason>\" commit ..." >&2
      echo "" >&2
      echo "  Examples:" >&2
      echo "    \"committing repos sequentially — $OTHER_NAME is next\"" >&2
      echo "    \"$OTHER_NAME changes are unrelated, will address separately\"" >&2
      FAILED=true
    fi
  fi
fi

if [ "$FAILED" = true ]; then
  exit 2
fi
