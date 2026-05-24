#!/bin/bash
# sync-to-devshop.sh — push build tooling changes from this project to the devshop repo.
#
# Show-first-confirm-then-apply: previews proposed changes via a dry-run diff,
# then applies only after operator confirmation. --yes / -y bypasses the prompt.
#
# The devshop repo (abra-kadabra) is bind-mounted at /devshop. This script copies
# files listed in manifest.txt into the devshop's template/ directory, commits in
# the devshop repo, and prints push instructions for the human operator.
#
# Usage:
#   sync-to-devshop.sh                  # auto-detect bump level
#   sync-to-devshop.sh --bump patch     # force patch bump
#   sync-to-devshop.sh --bump minor     # force minor bump
#   sync-to-devshop.sh --bump major     # force major bump
#   sync-to-devshop.sh --seed           # initial seed (first push to empty repo)
#   sync-to-devshop.sh --yes            # skip confirmation prompt
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Three levels up: see sibling from-devshop.sh for the rationale.
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.devshopkit/manifest.txt"
VERSION_FILE="$PROJECT_ROOT/.devshopkit/version"
DEVSHOP_DIR="${DEVSHOP_DIR:-/devshop}"

# --- Parse args (--yes / -y extracted by preview-confirm lib, rest passed through) ---
source "$SCRIPT_DIR/lib/preview-confirm.sh"
preview_confirm_parse_args "$@"
set -- "${PREVIEW_CONFIRM_REMAINING_ARGS[@]}"

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
if [ ! -d "$DEVSHOP_DIR" ]; then
  echo "ERROR: $DEVSHOP_DIR does not exist."
  echo ""
  echo "The devshop repo (abra-kadabra) must be bind-mounted into the devcontainer."
  echo "Setup (one-time):"
  echo "  1. On host: git clone <devshop-url> as sibling to this project"
  echo "  2. Add to .devcontainer/devcontainer.json mounts:"
  echo '     "source=${localWorkspaceFolder}/../abra-kadabra,target=/devshop,type=bind,consistency=delegated"'
  echo "  3. Rebuild devcontainer"
  exit 1
fi

if [ ! -d "$DEVSHOP_DIR/.git" ]; then
  echo "ERROR: $DEVSHOP_DIR is not a git repository."
  echo "Clone the devshop repo on the host first, then rebuild the devcontainer."
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: .devshopkit/manifest.txt not found."
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')

# --- Read manifest via shared parser ---
# Only [sync] entries get pushed to template/. [locked] entries are owned by
# init-devshop.sh on the workspace side and devshop-self locks for the devshop
# mirror; pushing them via to-devshop would either clobber root-locked files
# (cp fails with EACCES) or undo the locking. [symlink] and [scaffold-once]
# entries are similarly owned by other mechanisms.
source "$SCRIPT_DIR/lib/parse-manifest.sh"
parse_manifest "$MANIFEST"
PATHS=()
EXCLUDES=()
while IFS= read -r path; do
  [ -n "$path" ] && PATHS+=("$path")
done < <(manifest_paths_by sync)
for excl in "${MANIFEST_EXCLUDES[@]:-}"; do
  [ -n "$excl" ] && EXCLUDES+=("$excl")
done

# --- Build rsync exclude args for a directory (three-source model) ---
build_rsync_excludes() {
  local path="$1"
  RSYNC_EXCLUDES=()
  for excl in "${EXCLUDES[@]:-}"; do
    [ -z "$excl" ] && continue
    if [[ "$excl" == "$path"* ]]; then
      local rel="${excl#$path}"
      RSYNC_EXCLUDES+=(--exclude "$rel")
    fi
  done
  while IFS= read -r locked_rel; do
    [ -n "$locked_rel" ] && RSYNC_EXCLUDES+=(--exclude "$locked_rel")
  done < <(manifest_locked_under "$path")
  while IFS= read -r scaffold_rel; do
    [ -n "$scaffold_rel" ] && RSYNC_EXCLUDES+=(--exclude "$scaffold_rel")
  done < <(manifest_scaffold_once_under "$path")
}

check_file_locks() {
  UNLOCKED=""
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    target="$DEVSHOP_DIR/template/$p"
    [ ! -f "$target" ] && continue
    OWNER=$(stat -c '%U' "$target" 2>/dev/null || true)
    if [ "$OWNER" != "root" ]; then
      UNLOCKED="$UNLOCKED template/$p"
    fi
  done < <(manifest_paths_by locked)
  for f in .claude/settings.json; do
    target="$DEVSHOP_DIR/$f"
    [ ! -f "$target" ] && continue
    OWNER=$(stat -c '%U' "$target" 2>/dev/null || true)
    if [ "$OWNER" != "root" ]; then
      UNLOCKED="$UNLOCKED $f"
    fi
  done
  if [ -n "$UNLOCKED" ]; then
    echo ""
    echo "Warning: Security-critical files not locked in devshop repo:"
    echo "  cd <path-to-devshop-repo>"
    echo "  sudo chown root:root$UNLOCKED"
    echo "  sudo chmod 644$UNLOCKED"
  fi
}

# --- Dry-run: stage proposed changes to temp dir ---
preview_confirm_init
echo "Preparing sync preview (${#PATHS[@]} paths from project to devshop)..."

for path in "${PATHS[@]}"; do
  src="$PROJECT_ROOT/$path"

  if [ -d "$src" ]; then
    build_rsync_excludes "$path"
    preview_confirm_stage_dir "$src" "$DEVSHOP_DIR/template/$path" "$path" "${RSYNC_EXCLUDES[@]}"
  elif [ -f "$src" ]; then
    preview_confirm_stage_file "$src" "proposed/$path"
    if [ -f "$DEVSHOP_DIR/template/$path" ]; then
      preview_confirm_stage_file "$DEVSHOP_DIR/template/$path" "current/$path"
    fi
  else
    echo "WARNING: $path not found in project, skipping"
  fi
done

# --- Show preview and prompt (skip for --seed with no prior state) ---
if [ "$SEED" = true ]; then
  _PC_AUTO_YES=true
fi

if ! preview_confirm_show_and_ask "$DEVSHOP_DIR/template"; then
  exit 0
fi

# --- Apply: copy files from project to devshop ---
echo ""
echo "Applying changes..."
for path in "${PATHS[@]}"; do
  src="$PROJECT_ROOT/$path"
  dst="$DEVSHOP_DIR/template/$path"

  if [ -d "$src" ]; then
    build_rsync_excludes "$path"
    mkdir -p "$dst"
    rsync -ac --delete "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/"
  elif [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  else
    echo "WARNING: $path not found in project, skipping"
  fi
done

# --- Remove excluded files that may exist from prior syncs ---
for excl in "${EXCLUDES[@]}"; do
  target="$DEVSHOP_DIR/template/$excl"
  [ -e "$target" ] && rm -rf "$target" && echo "Excluded: $excl"
done

# --- Stage changes ---
cd "$DEVSHOP_DIR"
git add -A

# --- Initial seed ---
if [ "$SEED" = true ]; then
  if git diff --cached --quiet; then
    echo "Nothing to seed — devshop already matches project."
    exit 0
  fi
  git commit -m "Initial devshop seed (v$CURRENT_VERSION)"
  echo ""
  echo "=== Initial seed committed ==="
  echo ""
  echo "Push from host:"
  echo "  cd <path-to-devshop-repo> && git push -u origin main"
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
echo "$NEW_VERSION" > "$DEVSHOP_DIR/kit/version"
echo "$NEW_VERSION" > "$VERSION_FILE"

# Re-stage after version update
git add -A

# --- Build commit message from synced files ---
DIFF_SUMMARY=$(git --no-pager diff --cached --stat | head -20)
CHANGED_FILES=$(echo "$DIFF_SUMMARY" | awk '/\|/ {print $1}' | head -10)

COMMIT_BODY=""
if [ -n "$CHANGED_FILES" ]; then
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    COMMIT_BODY="$COMMIT_BODY
- $file"
  done <<< "$CHANGED_FILES"
fi

if [ -n "$COMMIT_BODY" ]; then
  git commit -m "chore: sync from project v$NEW_VERSION
$COMMIT_BODY"
else
  git commit -m "chore: sync from project v$NEW_VERSION"
fi

# --- Changelog entry (in project repo) ---
DIFF_SUMMARY=$(git --no-pager diff --stat HEAD~1..HEAD | head -20)
CHANGELOG_MSG=$(echo "$DIFF_SUMMARY" | awk '/\|/ {print "- " $1}' | head -10)
[ -z "$CHANGELOG_MSG" ] && CHANGELOG_MSG="- Synced from project"
bash "$SCRIPT_DIR/changelog-entry.sh" "$NEW_VERSION" "$CHANGELOG_MSG"

echo ""
echo "=== Sync committed (v$CURRENT_VERSION → v$NEW_VERSION) ==="
echo ""
echo "Changes in devshop repo:"
echo "$DIFF_SUMMARY"
echo ""
echo "Push from host:"
echo "  cd <path-to-devshop-repo> && git push"
check_file_locks
echo ""
echo "Then commit the version bump + changelog in this project:"
echo "  git add .devshopkit/version .devshopkit/docs/CHANGELOG.md && git commit -m 'Bump devshop version to $NEW_VERSION'"
