#!/bin/bash
# release.sh — bump devshop version and tag. For direct devshop repo edits.
# Run from the devshop repo root (not a project repo).
# Shows changes since last version tag, suggests bump level, asks for confirmation.
#
# Test coverage review: the `release-coverage` check in devshop-commit-guard.sh
# fires on the bump commit (triggered by kit/version being staged) and runs an
# adversarial review of the changes since the last tag. Runs once per release,
# not per commit. Cannot be bypassed by skipping release.sh — any bump commit
# triggers it regardless of how the bump was made.
#
# Atomic rollback on failure: any step before the commit (incl. husky pre-commit
# tests + adversarial reviews) failing → kit/version and kit/docs/CHANGELOG.md
# are restored to HEAD via a shell trap, so re-running release.sh starts from a
# clean slate. If the commit SUCCEEDS but a later step fails (tag already
# exists, push fails, gh release create fails), the local commit is KEPT —
# adversarial review is expensive and we don't want to re-trigger it on retry.
# The trap inspects PHASE to know which mode to apply:
#   - modifying  → files written but commit failed → roll back fully
#   - committed  → commit survived; tag/push/release failed → keep, retry manually
#   - completed  → all good → no-op
# See PHASE/rollback below.
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
CHANGELOG_PATH="$(pwd)/kit/docs/CHANGELOG.md"

echo "Current version: $CURRENT_VERSION"
echo ""

# Show changes since last tag
if git rev-parse "$LAST_TAG" &>/dev/null; then
  CHANGES=$(git log --oneline "$LAST_TAG"..HEAD)
  if [ -z "$CHANGES" ]; then
    echo "ERROR: No commits since $LAST_TAG. Nothing to release."
    echo "Commit your changes first, then re-run release.sh."
    exit 1
  fi
  echo "Changes since $LAST_TAG:"
  echo "$CHANGES"
  echo ""
else
  echo "No previous tag found. This will be the first tagged release."
fi

# Pre-release test coverage review runs in the commit guard — see the
# release-coverage check in kit/scripts/commit-hooks/commit-guard.sh. Triggered by
# kit/version being staged, which happens below when release.sh writes the new
# version and calls `git commit`. The review covers all changes since $LAST_TAG
# via the adversarial agent. Cannot be bypassed by calling `git tag` directly
# without a bump commit.

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

# Generate changelog message from commits since last tag (reusing $CHANGES
# from the earlier show-and-validate block; falls back to initial-release
# message only when $LAST_TAG doesn't exist yet — the no-commits case is
# already trapped above with a clear exit 1).
if git rev-parse "$LAST_TAG" &>/dev/null; then
  CHANGELOG_MSG=$(echo "$CHANGES" | sed 's/^[a-f0-9]* /- /')
else
  CHANGELOG_MSG="- Initial release"
fi

# --- Atomic rollback on failure ---
# PHASE tracks how far we got. The trap on EXIT inspects PHASE and rolls back
# accordingly (see header comment for full intent):
#   modifying  → files written + staged but commit didn't succeed → restore
#                HEAD state for kit/version + CHANGELOG.md so re-running is clean.
#   committed  → commit survived but tag/push/release failed → KEEP commit
#                (so user retries remaining steps only; preserves adversarial
#                review work).
#   completed  → full success → no-op.
# This means a transient test failure or network blip doesn't leave a dirty tree.
PHASE="init"
rollback() {
  local exit_code=$?
  case "$PHASE" in
    modifying)
      echo ""
      echo "✖ Release failed before commit (exit $exit_code) — rolling back kit/version and CHANGELOG.md to HEAD."
      git restore --staged "$VERSION_FILE" "$CHANGELOG_PATH" 2>/dev/null || true
      git restore "$VERSION_FILE" "$CHANGELOG_PATH" 2>/dev/null || true
      ;;
    committed)
      echo ""
      echo "⚠ Commit (v$NEW_VERSION) landed locally but a later step failed (exit $exit_code)."
      echo "   Local commit is KEPT (so you don't re-trigger adversarial review on retry)."
      echo "   Retry the remaining steps manually:"
      echo "     # if tag not yet created:"
      echo "     git tag -a v$NEW_VERSION -m 'v$NEW_VERSION'"
      echo "     # push commit + tag:"
      echo "     git push origin main --tags"
      echo "     # GitHub release:"
      echo "     gh release create v$NEW_VERSION --notes \"\$CHANGELOG_MSG\""
      ;;
    completed) ;; # success, no-op
  esac
}
trap rollback EXIT

# Write new version, update changelog, commit, tag
PHASE="modifying"
echo "$NEW_VERSION" > "$VERSION_FILE"
bash "$SCRIPT_DIR/changelog-entry.sh" "$NEW_VERSION" "$CHANGELOG_MSG" "$CHANGELOG_PATH"
git add "$VERSION_FILE" "$CHANGELOG_PATH"
git commit -m "Bump devshop version to $NEW_VERSION"
PHASE="committed"
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

PHASE="completed"
