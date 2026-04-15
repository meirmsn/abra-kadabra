#!/bin/bash
# sync-from-devshop.sh — pull build tooling updates from the devshop repo into this project.
#
# The devshop repo (abra-kadabra) is bind-mounted at /devshop. This script copies
# files listed in manifest.txt from the devshop's template/ directory and shows a
# diff for review. Injected files (skills, settings, etc.) are handled by
# init-devshop.sh — this script only syncs build tooling (turbo.json, eslint, etc.).
#
# Before running: make sure the devshop repo is up to date on the host side
# (git pull in the abra-kadabra directory).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.devshopkit/manifest.txt"
DEVSHOP_DIR="${DEVSHOP_DIR:-/devshop}"

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
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: .devshopkit/manifest.txt not found."
  exit 1
fi

# --- Read manifest (strip annotations, skip comments and blanks) ---
PATHS=()
while IFS= read -r line; do
  [[ "$line" =~ ^[[:space:]]*# ]] && continue
  [[ -z "${line// /}" ]] && continue
  path=$(echo "$line" | sed 's/\[.*\]//g' | xargs)
  [ -n "$path" ] && PATHS+=("$path")
done < "$MANIFEST"

# --- Copy files from devshop to project ---
echo "Syncing ${#PATHS[@]} paths from devshop to project..."
for path in "${PATHS[@]}"; do
  src="$DEVSHOP_DIR/template/$path"
  dst="$PROJECT_ROOT/$path"

  if [ -d "$src" ]; then
    mkdir -p "$dst"
    rsync -a --delete "$src/" "$dst/"
  elif [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  else
    echo "WARNING: $path not found in devshop, skipping"
  fi
done


# --- Show what changed ---
echo ""
echo "=== Changes from devshop sync ==="
cd "$PROJECT_ROOT"
git diff

DEVSHOP_VERSION=$(cat "$DEVSHOP_DIR/kit/version" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo ""
echo "Review the changes above. If they look good:"
echo "  git add -A && git commit -m 'chore: sync from devshop v$DEVSHOP_VERSION'"
