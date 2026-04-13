#!/bin/bash
# sync-from-devshop.sh — pull build tooling updates from the devshop repo into this project.
#
# The devshop repo (abra-kadabra) is bind-mounted at /devshop (cloned on the host,
# mounted into the devcontainer). This script copies files listed in manifest.txt
# and shows a diff for review. Injected files (skills, settings, etc.) are handled
# by init-devshop.sh — this script only syncs build tooling (turbo.json, eslint, etc.).
#
# Before running: make sure the devshop repo is up to date on the host side
# (git pull in the abra-kadabra directory).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.devshop/manifest.txt"
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
  echo "ERROR: .devshop/manifest.txt not found."
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
  src="$DEVSHOP_DIR/$path"
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

# --- Inject .devshop/CLAUDE.md into root CLAUDE.md ---
DEVSHOP_CLAUDE="$PROJECT_ROOT/.devshop/CLAUDE.md"
ROOT_CLAUDE="$PROJECT_ROOT/CLAUDE.md"

if [ -f "$DEVSHOP_CLAUDE" ] && [ -f "$ROOT_CLAUDE" ]; then
  SYNCED_NOTE="[Synced from .devshop/CLAUDE.md by sync-from-devshop.sh — edit .devshop/CLAUDE.md, not here]"

  if grep -q "^## Devshop Conventions" "$ROOT_CLAUDE"; then
    echo ""
    echo "Injecting .devshop/CLAUDE.md into root CLAUDE.md..."

    BEFORE=$(sed -n '1,/^## Devshop Conventions/{ /^## Devshop Conventions/!p }' "$ROOT_CLAUDE")
    HEADING="## Devshop Conventions"
    NEW_CONTENT=$(cat "$DEVSHOP_CLAUDE")

    AFTER=$(awk '
      /^## Devshop Conventions/ { found=1; next }
      found && /^## / { found=0; printing=1 }
      printing { print }
    ' "$ROOT_CLAUDE")

    CURRENT_SECTION=$(awk '
      /^## Devshop Conventions/ { found=1; next }
      found && /^## / { exit }
      found { print }
    ' "$ROOT_CLAUDE")

    PROPOSED="$SYNCED_NOTE

$NEW_CONTENT"

    if [ "$CURRENT_SECTION" = "$PROPOSED" ]; then
      echo "CLAUDE.md devshop section is already up to date."
    else
      DIFF=$(diff <(echo "$CURRENT_SECTION") <(echo "$PROPOSED") || true)
      if [ -n "$DIFF" ]; then
        echo ""
        echo "CLAUDE.md devshop section will change:"
        echo "$DIFF"
        echo ""
        # Non-interactive: always apply (Claude or human can review via git diff after)
        {
          echo "$BEFORE"
          echo "$HEADING"
          echo ""
          echo "$SYNCED_NOTE"
          echo ""
          echo "$NEW_CONTENT"
          echo ""
          [ -n "$AFTER" ] && echo "$AFTER"
        } > "$ROOT_CLAUDE"
        echo "CLAUDE.md updated."
      fi
    fi
  else
    echo ""
    echo "Root CLAUDE.md has no '## Devshop Conventions' heading — adding it..."
    {
      cat "$ROOT_CLAUDE"
      echo ""
      echo "## Devshop Conventions"
      echo ""
      echo "$SYNCED_NOTE"
      echo ""
      cat "$DEVSHOP_CLAUDE"
      echo ""
    } > "${ROOT_CLAUDE}.tmp"
    mv "${ROOT_CLAUDE}.tmp" "$ROOT_CLAUDE"
    echo "CLAUDE.md updated with devshop conventions section."
  fi
fi

# --- Show what changed ---
echo ""
echo "=== Changes from devshop sync ==="
cd "$PROJECT_ROOT"
git diff

DEVSHOP_VERSION=$(cat "$DEVSHOP_DIR/.devshop/version" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo ""
echo "Review the changes above. If they look good:"
echo "  git add -A && git commit -m 'chore: sync from devshop v$DEVSHOP_VERSION'"
