#!/bin/bash
# What: Pre-commit check — detects template/ file additions/removals not reflected in manifest.txt
# Why: manifest.txt curates which template files sync bidirectionally with projects.
#      New/removed files need a conscious decision about whether they belong in the manifest.
# Does NOT: Auto-update the manifest — blocks and asks Claude to propose with reasoning.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
MANIFEST="$DEVSHOP/kit/manifest.txt"

[ -f "$MANIFEST" ] || exit 0

# Only relevant in the devshop repo (template/ doesn't exist in project repos)
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then
  : # devshop-self mode, continue
elif [ "$GIT_ROOT" = "/devshop" ]; then
  : # devshop repo, continue
else
  exit 0
fi

# Get staged file changes (added/deleted) under template/
ADDED=$(git diff --cached --name-only --diff-filter=A | grep '^template/' | sed 's|^template/||' || true)
DELETED=$(git diff --cached --name-only --diff-filter=D | grep '^template/' | sed 's|^template/||' || true)

[ -z "$ADDED" ] && [ -z "$DELETED" ] && exit 0

# Read manifest entries (skip comments, blank lines, exclusions; strip [tag] annotations)
MANIFEST_ENTRIES=$(grep -v '^\s*#' "$MANIFEST" | grep -v '^\s*$' | grep -v '^!' | sed 's/\[[^]]*\]//g; s/[[:space:]]*$//' || true)

# Check which added/deleted files are NOT in the manifest
UNTRACKED_ADDED=""
UNTRACKED_DELETED=""

while IFS= read -r file; do
  [ -z "$file" ] && continue
  # Check if file or any parent directory is in manifest
  FOUND=false
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    # Directory entry (ends with /): check if file is under it
    if [[ "$entry" == */ ]] && [[ "$file" == "${entry}"* ]]; then
      FOUND=true
      break
    fi
    # Exact match
    if [ "$file" = "$entry" ]; then
      FOUND=true
      break
    fi
  done <<< "$MANIFEST_ENTRIES"
  if [ "$FOUND" = false ]; then
    UNTRACKED_ADDED+="    $file"$'\n'
  fi
done <<< "$ADDED"

while IFS= read -r file; do
  [ -z "$file" ] && continue
  FOUND=false
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    if [[ "$entry" == */ ]] && [[ "$file" == "${entry}"* ]]; then
      FOUND=true
      break
    fi
    if [ "$file" = "$entry" ]; then
      FOUND=true
      break
    fi
  done <<< "$MANIFEST_ENTRIES"
  if [ "$FOUND" = false ]; then
    UNTRACKED_DELETED+="    $file"$'\n'
  fi
done <<< "$DELETED"

# Also check: manifest entries that were deleted from template/
MANIFEST_DELETED=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    if [[ "$entry" == */ ]] && [[ "$file" == "${entry}"* ]]; then
      MANIFEST_DELETED+="    $file (covered by manifest entry: $entry)"$'\n'
      break
    fi
    if [ "$file" = "$entry" ]; then
      MANIFEST_DELETED+="    $file"$'\n'
      break
    fi
  done <<< "$MANIFEST_ENTRIES"
done <<< "$DELETED"

[ -z "$UNTRACKED_ADDED" ] && [ -z "$UNTRACKED_DELETED" ] && [ -z "$MANIFEST_DELETED" ] && exit 0

# Check for bypass
BYPASS=$(git config --get devshop.manifestReviewed 2>/dev/null || true)
if [ -n "$BYPASS" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  echo "⏳ Manifest check: reviewing proposal with adversarial agent..."
  REVIEW_RESULT=$(bash "$SCRIPT_DIR/../adversarial-review.sh" manifestReviewed "$BYPASS" 2>&1) || {
    echo ""
    echo "✖ ADVERSARIAL REVIEW REJECTED your manifest proposal."
    echo "  $REVIEW_RESULT"
    echo ""
    echo "  Update your proposal and retry."
    exit 1
  }
  echo "✓ Manifest check: adversarial review accepted."
  exit 0
fi

echo ""
echo "✖ BLOCKING: template/ files added or removed — manifest review required."
echo ""
if [ -n "$UNTRACKED_ADDED" ]; then
  echo "  Added to template/ but NOT in manifest.txt:"
  echo -n "$UNTRACKED_ADDED"
  echo ""
fi
if [ -n "$UNTRACKED_DELETED" ]; then
  echo "  Removed from template/ and NOT in manifest.txt:"
  echo -n "$UNTRACKED_DELETED"
  echo ""
fi
if [ -n "$MANIFEST_DELETED" ]; then
  echo "  Removed from template/ but still listed in manifest.txt:"
  echo -n "$MANIFEST_DELETED"
  echo ""
fi
echo "  For each file, propose to the user whether to:"
echo "    - Add to / remove from kit/manifest.txt (syncs bidirectionally with projects)"
echo "    - Leave as-is (template-only, not synced)"
echo "  Include reasoning for each decision."
echo ""
echo "  After updating manifest.txt (if needed), stage it and retry with:"
echo "    git -c devshop.manifestReviewed=\"<your proposal and reasoning>\" commit ..."
echo ""
echo "  Your proposal will be verified by an independent reviewer."
exit 1
