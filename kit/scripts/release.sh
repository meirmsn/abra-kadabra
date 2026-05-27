#!/bin/bash
# release.sh — bump devshop version and tag. For direct devshop repo edits.
# Run from the devshop repo root (not a project repo).
# Shows changes since last version tag, suggests bump level, asks for confirmation.
#
# Test-coverage at release time: the per-commit `release-coverage` adversarial
# review was removed in PR-C of the audit-time docs+tests migration (see
# kit/ROADMAP.md). Coverage judgment now lives in audit-time `/ak-tests-review`,
# which fires per-merge via `/ak-check-docs-and-tests`. The release flow here is
# reduced to: bump version + write a semantic tag-description summary + tag + push.
#
# Atomic rollback on failure: any step before the commit (incl. husky pre-commit
# checks) failing → kit/version and kit/docs/CHANGELOG.md are restored to HEAD
# via a shell trap, so re-running release.sh starts from a clean slate. If the
# commit SUCCEEDS but a later step fails (tag already exists, push fails,
# gh release create fails), the local commit is KEPT — re-doing the bump commit
# would re-add a duplicate CHANGELOG entry. The trap inspects PHASE to know
# which mode to apply:
#   - modifying  → files written but commit failed → roll back fully
#   - committed  → commit survived; tag/push/release failed → keep, retry manually
#   - completed  → all good → no-op
# See PHASE/rollback below.
#
# Usage:
#   release.sh                         # interactive (prompts for bump level + confirm)
#   release.sh --bump patch            # non-interactive (for Claude)
#   release.sh --bump minor --no-push  # generate + stage files, stop before commit
#   release.sh --finalize              # commit + tag + push (after --no-push)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="kit/version"

# Parse args
ARG_BUMP=""
NO_PUSH=false
FINALIZE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) ARG_BUMP="$2"; shift 2 ;;
    --no-push) NO_PUSH=true; shift ;;
    --finalize) FINALIZE=true; shift ;;
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

# --finalize: pick up after --no-push. Expects files already staged
# (possibly edited by the caller between --no-push and --finalize).
if [ "$FINALIZE" = true ]; then
  NEW_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
  CHANGELOG_PATH="$(pwd)/kit/docs/CHANGELOG.md"
  PROPAGATION_PATH="$(pwd)/kit/docs/PROPAGATION.md"

  # Guard: --finalize expects --no-push to have staged the release files.
  STAGED=$(git diff --cached --name-only)
  for required in "$VERSION_FILE" "template/.devshop-version" "$CHANGELOG_PATH"; do
    # Normalize to relative path for matching
    rel=$(echo "$required" | sed "s|^$(pwd)/||")
    if ! echo "$STAGED" | grep -qxF "$rel"; then
      echo "ERROR: --finalize expects $rel to be staged (run --no-push first)."
      exit 1
    fi
  done

  # Re-stage PROPAGATION.md in case the caller edited it
  git add "$PROPAGATION_PATH"

  CLAUDECODE= git \
    -c devshop.docsCoverageReason="kit/version: AFFECTED — mechanical version bump, no doc change needed. template/.devshop-version: AFFECTED — tracks kit/version for sync drift detection, no doc change needed. kit/docs/CHANGELOG.md: AFFECTED — auto-generated changelog entry. kit/docs/PROPAGATION.md: AFFECTED — auto-generated propagation entry. kit/docs/guide/architecture.md: NOT-AFFECTED — unrelated to version bump. kit/docs/guide/security.md: NOT-AFFECTED — unrelated. kit/docs/guide/ops.md: NOT-AFFECTED — unrelated. kit/docs/guide/workflow.md: NOT-AFFECTED — unrelated. kit/docs/guide/conventions.md: NOT-AFFECTED — unrelated. kit/docs/guide/hooks.md: NOT-AFFECTED — unrelated. kit/docs/guide/supabase-ssr-boilerplate.md: NOT-AFFECTED — unrelated. CLAUDE.md: NOT-AFFECTED — unrelated" \
    -c devshop.docsReviewed="kit/version + template/.devshop-version + CHANGELOG.md + PROPAGATION.md: AFFECTED — mechanical version bump artifacts; no guide docs need updating" \
    commit -m "Bump devshop version to $NEW_VERSION"
  git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION"

  source /etc/devshop-env 2>/dev/null || true
  if [ -n "$DEVSHOP_GITHUB_TOKEN" ]; then
    LAST_TAG_BEFORE=$(git describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo "")
    CHANGELOG_MSG=$(git log --oneline "${LAST_TAG_BEFORE}..HEAD~1" 2>/dev/null | sed 's/^[a-f0-9]* /- /' || echo "- v$NEW_VERSION")
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
  fi
  exit 0
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
LAST_TAG="v$CURRENT_VERSION"
CHANGELOG_PATH="$(pwd)/kit/docs/CHANGELOG.md"
PROPAGATION_PATH="$(pwd)/kit/docs/PROPAGATION.md"

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

# Pre-release test-coverage review moved to audit-time `/ak-tests-review` in
# PR-C (see kit/ROADMAP.md). The bump commit below no longer triggers a
# per-commit adversarial review — coverage is judged per-merge in the audit
# pipeline, not at release time. The CHANGELOG entry below is the human-facing
# release artifact.

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
      echo "✖ Release failed before commit (exit $exit_code) — rolling back kit/version, template/.devshop-version, CHANGELOG.md, and PROPAGATION.md to HEAD."
      git restore --staged "$VERSION_FILE" template/.devshop-version "$CHANGELOG_PATH" "$PROPAGATION_PATH" 2>/dev/null || true
      git restore "$VERSION_FILE" template/.devshop-version "$CHANGELOG_PATH" "$PROPAGATION_PATH" 2>/dev/null || true
      ;;
    committed)
      echo ""
      echo "⚠ Commit (v$NEW_VERSION) landed locally but a later step failed (exit $exit_code)."
      echo "   Local commit is KEPT (so you don't double-write the CHANGELOG entry on retry)."
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
echo "$NEW_VERSION" > template/.devshop-version
bash "$SCRIPT_DIR/changelog-entry.sh" "$NEW_VERSION" "$CHANGELOG_MSG" "$CHANGELOG_PATH"
bash "$SCRIPT_DIR/propagation-entry.sh" "$NEW_VERSION" "$LAST_TAG" "$PROPAGATION_PATH"
git add "$VERSION_FILE" template/.devshop-version "$CHANGELOG_PATH" "$PROPAGATION_PATH"

# --no-push: stop after file generation + staging, before commit.
# The caller (skill) reviews PROPAGATION.md, edits if needed, re-stages,
# then commits + tags + pushes — one clean commit, no amend needed.
if [ "$NO_PUSH" = true ]; then
  echo ""
  echo "Staged: $VERSION_FILE template/.devshop-version $CHANGELOG_PATH $PROPAGATION_PATH"
  echo ""
  echo "Done. Version $NEW_VERSION files generated and staged."
  echo "--no-push: stopping before commit. The caller is responsible for:"
  echo "  1. Reviewing/editing PROPAGATION.md (already staged — re-stage if edited)"
  echo "  2. Committing: CLAUDECODE= git commit -m 'Bump devshop version to $NEW_VERSION'"
  echo "  3. Tagging: git tag -a v$NEW_VERSION -m 'v$NEW_VERSION'"
  echo "  4. Pushing + creating the GitHub release"
  PHASE="completed"
  exit 0
fi

# Unset CLAUDECODE so the husky branch guard allows this commit on main.
# Release commits are deliberate, human-approved — all other pre-commit
# checks (lint-staged, typecheck, gitleaks, bats) still fire normally.
# The docsCoverageReason bypass is needed because template/.devshop-version
# triggers the "template" surface group — but the version bump is mechanical.
CLAUDECODE= git \
  -c devshop.docsCoverageReason="kit/version: AFFECTED — mechanical version bump, no doc change needed. template/.devshop-version: AFFECTED — tracks kit/version for sync drift detection, no doc change needed. kit/docs/CHANGELOG.md: AFFECTED — auto-generated changelog entry. kit/docs/PROPAGATION.md: AFFECTED — auto-generated propagation entry. kit/docs/guide/architecture.md: NOT-AFFECTED — unrelated to version bump. kit/docs/guide/security.md: NOT-AFFECTED — unrelated. kit/docs/guide/ops.md: NOT-AFFECTED — unrelated. kit/docs/guide/workflow.md: NOT-AFFECTED — unrelated. kit/docs/guide/conventions.md: NOT-AFFECTED — unrelated. kit/docs/guide/hooks.md: NOT-AFFECTED — unrelated. kit/docs/guide/supabase-ssr-boilerplate.md: NOT-AFFECTED — unrelated. CLAUDE.md: NOT-AFFECTED — unrelated" \
  -c devshop.docsReviewed="kit/version + template/.devshop-version + CHANGELOG.md + PROPAGATION.md: AFFECTED — mechanical version bump artifacts; no guide docs need updating" \
  commit -m "Bump devshop version to $NEW_VERSION"
PHASE="committed"
git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION"

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
