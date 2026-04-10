#!/bin/bash
# sync-to-template.sh — push dev-shop changes from this project to the template repo.
#
# The template repo is bind-mounted at /template-repo (cloned on the host, mounted
# into the devcontainer). This script copies files per manifest.txt, commits in the
# template repo, and prints push instructions for the human operator (the devcontainer
# PAT doesn't cover the template repo — pushing happens on the host side).
#
# Usage:
#   sync-to-template.sh                  # auto-detect bump level
#   sync-to-template.sh --bump patch     # force patch bump
#   sync-to-template.sh --bump minor     # force minor bump
#   sync-to-template.sh --bump major     # force major bump
#   sync-to-template.sh --seed           # initial seed (first push to empty repo)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.devshop/manifest.txt"
VERSION_FILE="$PROJECT_ROOT/.devshop/version"
TEMPLATE_DIR="/template-repo"

# --- Parse args ---
BUMP=""
SEED=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) BUMP="$2"; shift 2 ;;
    --seed) SEED=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# --- Guards ---
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "ERROR: $TEMPLATE_DIR does not exist."
  echo ""
  echo "The template repo must be bind-mounted into the devcontainer."
  echo "Setup (one-time):"
  echo "  1. On host: git clone <template-url> as sibling to this project"
  echo "  2. Add to .devcontainer/devcontainer.json mounts:"
  echo '     "source=${localWorkspaceFolder}/../abra-kadabra,target=/template-repo,type=bind,consistency=delegated"'
  echo "  3. Rebuild devcontainer"
  exit 1
fi

if [ ! -d "$TEMPLATE_DIR/.git" ]; then
  echo "ERROR: $TEMPLATE_DIR is not a git repository."
  echo "Clone the template repo on the host first, then rebuild the devcontainer."
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: .devshop/manifest.txt not found."
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

LOCK_FILES=".claude/settings.json .devcontainer/devcontainer.json .devcontainer/init-firewall.sh .devcontainer/Dockerfile .devcontainer/checksums.sha256"
check_file_locks() {
  UNLOCKED=""
  for f in $LOCK_FILES; do
    target="$TEMPLATE_DIR/$f"
    [ ! -f "$target" ] && continue
    OWNER=$(stat -c '%U' "$target" 2>/dev/null || true)
    if [ "$OWNER" != "root" ]; then
      UNLOCKED="$UNLOCKED $f"
    fi
  done
  if [ -n "$UNLOCKED" ]; then
    echo ""
    echo "⚠ Security-critical files not locked in template repo:"
    echo "  cd <path-to-template-repo>"
    echo "  sudo chown root:root$UNLOCKED"
    echo "  sudo chmod 644$UNLOCKED"
  fi
}

# --- Read manifest (strip annotations, skip comments/blanks, collect excludes) ---
PATHS=()
EXCLUDES=()
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// /}" ]] && continue
  path=$(echo "$line" | sed 's/\[.*\]//g' | xargs)
  [ -z "$path" ] && continue
  if [[ "$path" == !* ]]; then
    EXCLUDES+=("${path#!}")
  else
    PATHS+=("$path")
  fi
done < "$MANIFEST"

# --- Copy files from project to template ---
echo "Syncing ${#PATHS[@]} paths from project to template..."
for path in "${PATHS[@]}"; do
  src="$PROJECT_ROOT/$path"
  dst="$TEMPLATE_DIR/$path"

  if [ -d "$src" ]; then
    # Build rsync exclude args for this directory
    RSYNC_EXCLUDES=()
    for excl in "${EXCLUDES[@]}"; do
      if [[ "$excl" == "$path"* ]]; then
        rel="${excl#$path}"
        RSYNC_EXCLUDES+=(--exclude "$rel")
      fi
    done
    mkdir -p "$dst"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/"
  elif [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  else
    echo "WARNING: $path not found in project, skipping"
  fi
done

# --- Remove excluded files that may exist from prior syncs ---
for excl in "${EXCLUDES[@]}"; do
  target="$TEMPLATE_DIR/$excl"
  [ -e "$target" ] && rm -rf "$target" && echo "Excluded: $excl"
done

# Template repo gets its own README (from templates/ folder)
cp "$PROJECT_ROOT/.devshop/templates/README.md.tmpl" "$TEMPLATE_DIR/README.md"

# --- Stage changes ---
cd "$TEMPLATE_DIR"
git add -A

# --- Initial seed ---
if [ "$SEED" = true ]; then
  if git diff --cached --quiet; then
    echo "Nothing to seed — template already matches project."
    exit 0
  fi
  git commit -m "Initial devshop seed (v$CURRENT_VERSION)"
  echo ""
  echo "=== Initial seed committed ==="
  echo ""
  echo "Push from host:"
  echo "  cd <path-to-template-repo> && git push -u origin main"
  check_file_locks
  exit 0
fi

# --- Check for changes ---
if git diff --cached --quiet; then
  echo "No changes to sync."
  exit 0
fi

# --- Determine version bump ---
if [ -z "$BUMP" ]; then
  NEW_FILES=$(git diff --cached --name-only --diff-filter=A | wc -l)
  if [ "$NEW_FILES" -gt 0 ]; then
    BUMP="minor"
  else
    BUMP="patch"
  fi
  echo "Auto-detected bump: $BUMP"
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  patch) PATCH=$((PATCH + 1)) ;;
  *) echo "Invalid bump level: $BUMP"; exit 1 ;;
esac
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

# Update version in both repos
echo "$NEW_VERSION" > "$TEMPLATE_DIR/.devshop/version"
echo "$NEW_VERSION" > "$VERSION_FILE"

# Re-stage after version update
git add -A

# --- Commit ---
git commit -m "devshop sync v$NEW_VERSION"

# --- Changelog entry (in project repo) ---
DIFF_SUMMARY=$(git --no-pager diff --stat HEAD~1..HEAD | head -20)
CHANGELOG_MSG=$(echo "$DIFF_SUMMARY" | awk '/\|/ {print "- " $1}' | head -10)
[ -z "$CHANGELOG_MSG" ] && CHANGELOG_MSG="- Synced from project"
bash "$SCRIPT_DIR/changelog-entry.sh" "$NEW_VERSION" "$CHANGELOG_MSG"

echo ""
echo "=== Sync committed (v$CURRENT_VERSION → v$NEW_VERSION) ==="
echo ""
echo "Changes in template repo:"
echo "$DIFF_SUMMARY"
echo ""
echo "Push from host:"
echo "  cd <path-to-template-repo> && git push"
check_file_locks
echo ""
echo "Then commit the version bump + changelog in this project:"
echo "  git add .devshop/version .devshop/CHANGELOG.md && git commit -m 'Bump devshop version to $NEW_VERSION'"
