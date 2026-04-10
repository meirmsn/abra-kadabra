#!/bin/bash
# release.sh — bump devshop version and tag. For direct template repo edits.
# Run from the template repo root (not a project repo).
# Shows changes since last version tag, suggests bump level, asks for confirmation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE=".devshop/version"

if [ ! -f "$VERSION_FILE" ]; then
  echo "ERROR: $VERSION_FILE not found. Are you in the template repo root?"
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
LAST_TAG="devshop-v$CURRENT_VERSION"

echo "Current version: $CURRENT_VERSION"
echo ""

# Show changes since last tag
if git rev-parse "$LAST_TAG" &>/dev/null; then
  echo "Changes since $LAST_TAG:"
  git log --oneline "$LAST_TAG"..HEAD
  echo ""

  # Guess bump: new files = minor, only modifications = patch
  NEW_FILES=$(git diff --name-only --diff-filter=A "$LAST_TAG"..HEAD | wc -l)
  if [ "$NEW_FILES" -gt 0 ]; then
    SUGGESTED="minor"
  else
    SUGGESTED="patch"
  fi
else
  echo "No previous tag found. This will be the first tagged release."
  SUGGESTED="minor"
fi

echo "Suggested bump: $SUGGESTED"
read -p "Bump level (patch/minor/major) [$SUGGESTED]: " BUMP
BUMP=${BUMP:-$SUGGESTED}

# Calculate new version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case "$BUMP" in
  patch) PATCH=$((PATCH + 1)) ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  *) echo "Invalid bump level: $BUMP"; exit 1 ;;
esac
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo ""
echo "Bumping $CURRENT_VERSION -> $NEW_VERSION"
read -p "Confirm? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Aborted."
  exit 1
fi

# Generate changelog message from commits since last tag
if git rev-parse "$LAST_TAG" &>/dev/null; then
  CHANGELOG_MSG=$(git log --oneline "$LAST_TAG"..HEAD | sed 's/^[a-f0-9]* /- /')
else
  CHANGELOG_MSG="- Initial release"
fi

# Write new version, update changelog, commit, tag
echo "$NEW_VERSION" > "$VERSION_FILE"
CHANGELOG_PATH="$(pwd)/.devshop/CHANGELOG.md"
bash "$SCRIPT_DIR/changelog-entry.sh" "$NEW_VERSION" "$CHANGELOG_MSG" "$CHANGELOG_PATH"
git add "$VERSION_FILE" "$CHANGELOG_PATH"
git commit -m "Bump devshop version to $NEW_VERSION"
git tag "devshop-v$NEW_VERSION"

echo ""
echo "Done. Version bumped to $NEW_VERSION and tagged devshop-v$NEW_VERSION."
echo "Push with: git push && git push --tags"
