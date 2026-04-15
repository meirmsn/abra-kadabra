#!/bin/bash
# PostToolUse hook: after git push, prompt Claude to review PR title/description.
# Fires once per push. No output if on main, no open PR, or non-PR pushes.
set -euo pipefail

# Read hook input — check the actual push command
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip branch deletions
echo "$COMMAND" | grep -q '\-\-delete' && exit 0

BRANCH=$(git branch --show-current 2>/dev/null || true)
[ -z "$BRANCH" ] && exit 0
[ "$BRANCH" = "main" ] && exit 0

# Check if there's an open PR for this branch
PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || true)
[ -z "$PR" ] && exit 0

# Get current state
COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null || true)
COMMIT_COUNT=$(echo "$COMMITS" | grep -c . || true)
PR_DATA=$(gh pr view "$PR" --json title,body 2>/dev/null || true)
CURRENT_TITLE=$(echo "$PR_DATA" | jq -r '.title // empty')
CURRENT_BODY_PREVIEW=$(echo "$PR_DATA" | jq -r '.body // empty' | head -5)

# Build context with proper JSON escaping
CONTEXT=$(jq -n --arg pr "$PR" --arg branch "$BRANCH" --arg count "$COMMIT_COUNT" \
  --arg commits "$COMMITS" --arg title "$CURRENT_TITLE" --arg body "$CURRENT_BODY_PREVIEW" \
  '"⚠️ MANDATORY: Review PR #\($pr) title and description NOW before doing anything else.\n\nBranch: \($branch) (\($count) commits)\n\nCommits:\n\($commits)\n\nCurrent title: \($title)\nCurrent description (first 5 lines):\n\($body)\n\nThis is a TWO-STEP process. You MUST complete Step 1 before Step 2.\n\n## Step 1: ASSESS (text output only — NO tool calls)\n\nTell the user what needs changing and why. For each of title and description:\n- Quote the current version\n- Compare against the full commit history above\n- State: \"needs update because...\" or \"no change needed because...\"\n\n⚠️ DO NOT call gh pr edit or any other tool in the same response as Step 1. Output text ONLY. Wait for the user to see your assessment.\n\n## Step 2: UPDATE (after user has seen Step 1)\n\nIn your NEXT response, run `gh pr edit \($pr)` commands as needed.\n- Title update: tell user \"Title: old → new\"\n- Description update: tell user what changed\n- No change: skip the command\n\nDo NOT combine Steps 1 and 2 into one response. Do NOT run gh pr edit without showing the assessment first."')

# Output as PostToolUse additionalContext
jq -n --argjson ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}'
