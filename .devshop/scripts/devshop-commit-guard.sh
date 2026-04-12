#!/bin/bash
# devshop-commit-guard.sh — pre-commit guard for devshop hygiene.
# Runs as the last step in .husky/pre-commit. All checks are blocking (exit 1).
#
# Three checks:
#   1. Mixed commit detection: devshop + project files staged together
#   2. Docs drift detection: devshop tooling changed without docs update
#   3. README↔GUIDE sync: one staged without the other
#
# Devshop files are identified by manifest paths. Unclassified files under
# devshop-adjacent paths are flagged as ambiguous for human/Claude review.
set -euo pipefail

STAGED=$(git diff --cached --name-only)
[ -z "$STAGED" ] && exit 0

# --- Devshop path patterns ---
# After devshop separation, injected files are gitignored in the project repo.
# These patterns catch accidental commits if someone removes a gitignore entry.
# Project infra (.devcontainer/, .husky/, .github/, turbo.json, etc.) is now
# project-layer and tracked normally — no longer classified as devshop.
DEVSHOP_PATTERNS=(
  '^\.devshop/'
  '^\.claude/'
  '^\.dcg\.toml$'
  '^CLAUDE\.md$'
  '^BUILD-LOG\.md$'
)

# Build combined regex
DEVSHOP_REGEX=$(IFS='|'; echo "${DEVSHOP_PATTERNS[*]}")

# --- Classify staged files ---
DEVSHOP_FILES=()
PROJECT_FILES=()
AMBIGUOUS_FILES=()

while IFS= read -r file; do
  [ -z "$file" ] && continue
  if echo "$file" | grep -qE "$DEVSHOP_REGEX"; then
    DEVSHOP_FILES+=("$file")
  elif echo "$file" | grep -qE '^\.claude/|^\.devshop/'; then
    # Under a devshop-adjacent path but not in manifest — ambiguous
    AMBIGUOUS_FILES+=("$file")
  else
    PROJECT_FILES+=("$file")
  fi
done <<< "$STAGED"

FAILED=false

# --- Check 1: Mixed commit detection ---
if [ ${#DEVSHOP_FILES[@]} -gt 0 ] && [ ${#PROJECT_FILES[@]} -gt 0 ]; then
  echo ""
  echo "✖ Mixed commit: devshop + project files staged together."
  echo "  Devshop changes should be in separate commits with \"devshop:\" prefix."
  echo ""
  echo "  Devshop files:"
  for f in "${DEVSHOP_FILES[@]}"; do echo "    $f"; done
  echo "  Project files:"
  for f in "${PROJECT_FILES[@]}"; do echo "    $f"; done
  echo ""
  echo "  Unstage one set and commit separately."
  FAILED=true
fi

if [ ${#AMBIGUOUS_FILES[@]} -gt 0 ]; then
  echo ""
  echo "✖ Ambiguous files — devshop or project? Review these staged files:"
  for f in "${AMBIGUOUS_FILES[@]}"; do echo "    $f"; done
  echo ""
  echo "  If devshop: move to a separate commit with \"devshop:\" prefix."
  echo "  If project: add the path to the project-layer exception in this script."
  FAILED=true
fi

# --- Check 2: Docs drift detection ---
# Only fires when devshop files are staged
if [ ${#DEVSHOP_FILES[@]} -gt 0 ]; then
  DRIFT_WARNINGS=()

  # Check each tooling category against staged devshop files
  echo "$STAGED" | grep -q '^\.husky/pre-commit$' && \
    DRIFT_WARNINGS+=("  .husky/pre-commit changed → verify GUIDE.md § Commit Flow + CLAUDE.md § Non-Negotiables pre-commit line + README pre-commit line")

  echo "$STAGED" | grep -q '^\.claude/settings\.json$' && \
    DRIFT_WARNINGS+=("  .claude/settings.json changed → verify GUIDE.md § Claude Code Hooks table")

  echo "$STAGED" | grep -q '^\.claude/skills/devshop/' && \
    DRIFT_WARNINGS+=("  Devshop skill changed → verify GUIDE.md § Devshop Skill Map + CLAUDE.md § Build and Deploy if workflow changed")

  echo "$STAGED" | grep -q '^\.devshop/scripts/' && \
    DRIFT_WARNINGS+=("  Devshop script changed → verify GUIDE.md references to changed scripts")

  echo "$STAGED" | grep -q '^\.github/workflows/' && \
    DRIFT_WARNINGS+=("  Workflow changed → verify GUIDE.md § CI/CD section")

  echo "$STAGED" | grep -q '^\.devshop/FAQ\.md$' && \
    DRIFT_WARNINGS+=("  FAQ.md changed → verify README.md § Further Reading still lists it")

  echo "$STAGED" | grep -q '^\.claude/skills/devshop/init/SKILL\.md$' && \
    DRIFT_WARNINGS+=("  Init skill changed → verify .devshop/templates/README.md.tmpl still matches")

  # Skip nudge for changelog/version (change on every sync)
  # Filter out CHANGELOG.md and version from triggering the general "docs drift" warning

  if [ ${#DRIFT_WARNINGS[@]} -gt 0 ]; then
    # Check if ONLY changelog/version files are staged (no real tooling changes)
    NON_CHANGELOG_DEVSHOP=$(echo "$STAGED" | grep -E "$DEVSHOP_REGEX" | grep -vE '^\.devshop/(CHANGELOG\.md|version)$' || true)

    if [ -n "$NON_CHANGELOG_DEVSHOP" ]; then
      # Auto-pass if a referenced doc is staged alongside the tooling change
      DOCS_STAGED=false
      echo "$STAGED" | grep -qE '^\.devshop/(GUIDE|README|CLAUDE)\.md$|^CLAUDE\.md$' && DOCS_STAGED=true

      # Explicit bypass for changes that genuinely don't need doc updates
      DOCS_VERIFIED=$(git config --get devshop.docsVerified 2>/dev/null || echo "false")

      if [ "$DOCS_STAGED" = false ] && [ "$DOCS_VERIFIED" != "true" ]; then
        echo ""
        echo "✖ Devshop tooling changed without doc updates staged:"
        for w in "${DRIFT_WARNINGS[@]}"; do echo "$w"; done
        echo ""
        echo "  Option A: Stage doc updates and re-commit."
        echo "  Option B: If no doc changes are needed, bypass with:"
        echo "    git -c devshop.docsVerified=true commit ..."
        echo "    and explain why in the commit message."
        FAILED=true
      fi
    fi
  fi
fi

# --- Check 3: Three-way doc consistency ---
# If any of the three devshop reference docs is staged, nudge to verify the other two.
HAS_CLAUDE_MD=false
HAS_README=false
HAS_GUIDE=false
echo "$STAGED" | grep -q '^\.devshop/CLAUDE\.md$' && HAS_CLAUDE_MD=true
echo "$STAGED" | grep -q '^\.devshop/README\.md$' && HAS_README=true
echo "$STAGED" | grep -q '^\.devshop/GUIDE\.md$' && HAS_GUIDE=true

DOC_COUNT=0
CHANGED_DOCS=()
UNCHANGED_DOCS=()
$HAS_CLAUDE_MD && DOC_COUNT=$((DOC_COUNT + 1)) && CHANGED_DOCS+=("CLAUDE.md") || UNCHANGED_DOCS+=(".devshop/CLAUDE.md  (rules)")
$HAS_README && DOC_COUNT=$((DOC_COUNT + 1)) && CHANGED_DOCS+=("README.md") || UNCHANGED_DOCS+=(".devshop/README.md  (bird's eye)")
$HAS_GUIDE && DOC_COUNT=$((DOC_COUNT + 1)) && CHANGED_DOCS+=("GUIDE.md") || UNCHANGED_DOCS+=(".devshop/GUIDE.md   (full reference)")

if [ "$DOC_COUNT" -gt 0 ] && [ "$DOC_COUNT" -lt 3 ]; then
  CHANGED_LIST=$(IFS=', '; echo "${CHANGED_DOCS[*]}")
  echo ""
  echo "⚠ Devshop reference doc changed ($CHANGED_LIST) — verify the others are still consistent:"
  for doc in "${UNCHANGED_DOCS[@]}"; do echo "  $doc"; done
  echo ""
  # Non-blocking — advisory only. Specific drift checks (Check 2) handle targeted blocking.
fi

if [ "$FAILED" = true ]; then
  exit 1
fi
