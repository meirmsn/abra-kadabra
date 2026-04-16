#!/bin/bash
# release.sh — bump devshop version and tag. For direct devshop repo edits.
# Run from the devshop repo root (not a project repo).
# Shows changes since last version tag, suggests bump level, asks for confirmation.
#
# Pre-release gate: semantic test coverage review — checks whether tests cover
# all functional changes since the last tag. Runs once per release, not per commit.
#
# Usage:
#   release.sh                # interactive (prompts for bump level + confirm)
#   release.sh --bump patch   # non-interactive (for Claude)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="kit/version"

# Parse args
ARG_BUMP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) ARG_BUMP="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ ! -f "$VERSION_FILE" ]; then
  echo "ERROR: $VERSION_FILE not found. Are you in the devshop repo root?"
  exit 1
fi

# Guard: releases only from main
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "ERROR: Releases must be from main (currently on '$CURRENT_BRANCH')."
  echo "Merge or rebase to main first, then release."
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
LAST_TAG="v$CURRENT_VERSION"

echo "Current version: $CURRENT_VERSION"
echo ""

# Show changes since last tag
if git rev-parse "$LAST_TAG" &>/dev/null; then
  echo "Changes since $LAST_TAG:"
  git log --oneline "$LAST_TAG"..HEAD
  echo ""

else
  echo "No previous tag found. This will be the first tagged release."
fi

# Pre-release test coverage review runs in the commit guard — see check 5 in
# kit/scripts/devshop-commit-guard.sh. Triggered by kit/version being staged,
# which happens below when release.sh writes the new version and calls
# `git commit`. The review covers all changes since $LAST_TAG via the adversarial
# agent. Cannot be bypassed by calling `git tag` directly without a bump commit.

if [ -n "$ARG_BUMP" ]; then
  BUMP="$ARG_BUMP"
elif [ -t 0 ]; then
  # Interactive — prompt the user
  read -p "Bump level (patch/minor/major): " BUMP
else
  echo "ERROR: --bump is required in non-interactive mode."
  echo "Analyze the changes since the last release to determine the level:"
  echo "  patch — bug fixes, doc updates, internal refactors"
  echo "  minor — new capabilities, structural changes, new scripts/skills"
  echo "  major — breaking changes that require project-side updates"
  exit 1
fi

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

if [ -z "$ARG_BUMP" ]; then
  # Interactive — confirm before proceeding
  read -p "Confirm? (y/n): " CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# Generate changelog message from commits since last tag
if git rev-parse "$LAST_TAG" &>/dev/null; then
  CHANGELOG_MSG=$(git log --oneline "$LAST_TAG"..HEAD | sed 's/^[a-f0-9]* /- /')
else
  CHANGELOG_MSG="- Initial release"
fi

# Write new version, update changelog, commit, tag
echo "$NEW_VERSION" > "$VERSION_FILE"
CHANGELOG_PATH="$(pwd)/kit/docs/CHANGELOG.md"
bash "$SCRIPT_DIR/changelog-entry.sh" "$NEW_VERSION" "$CHANGELOG_MSG" "$CHANGELOG_PATH"
git add "$VERSION_FILE" "$CHANGELOG_PATH"
git commit -m "Bump devshop version to $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION"

# Push + create GitHub release (if devshop token is available)
# DEVSHOP_GITHUB_TOKEN is written to /etc/devshop-env by init-devshop.sh.
# Remote stays SSH — we construct a transient HTTPS URL just for the push.
source /etc/devshop-env 2>/dev/null || true
echo ""
if [ -n "$DEVSHOP_GITHUB_TOKEN" ]; then
  _REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  _REPO_PATH=$(echo "$_REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
  _PUSH_URL="https://x-access-token:${DEVSHOP_GITHUB_TOKEN}@github.com/${_REPO_PATH}.git"
  git push "$_PUSH_URL" HEAD --tags
  GH_TOKEN="$DEVSHOP_GITHUB_TOKEN" gh release create "v$NEW_VERSION" \
    --repo "$_REPO_PATH" \
    --title "v$NEW_VERSION" \
    --notes "$CHANGELOG_MSG"
  unset _REMOTE_URL _REPO_PATH _PUSH_URL
  echo "Done. v$NEW_VERSION pushed and released on GitHub."
else
  echo "Done. Version bumped to $NEW_VERSION and tagged v$NEW_VERSION."
  echo "Push with: git push (tags included if push.followTags is set)"
  echo "No DEVSHOP_GITHUB_TOKEN — run init-devshop.sh with .devcontainer/.env to enable."
fi
