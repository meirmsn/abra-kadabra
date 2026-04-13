#!/bin/bash
# changelog-entry.sh — append a versioned entry to the devshop CHANGELOG.md.
# Called by sync-to-devshop.sh and release.sh after version bumps.
#
# Usage:
#   changelog-entry.sh <version> <message> [changelog-path]
#
# message can be multi-line (use \n or pass a heredoc via variable).
# changelog-path defaults to .devshop/CHANGELOG.md relative to the script's repo root.
set -euo pipefail

VERSION="${1:?Usage: changelog-entry.sh <version> <message> [changelog-path]}"
MESSAGE="${2:?Usage: changelog-entry.sh <version> <message> [changelog-path]}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_CHANGELOG="$(cd "$SCRIPT_DIR/../.." && pwd)/.devshop/CHANGELOG.md"
CHANGELOG="${3:-$DEFAULT_CHANGELOG}"

if [ ! -f "$CHANGELOG" ]; then
  echo "ERROR: $CHANGELOG not found."
  exit 1
fi

DATE=$(date +%Y-%m-%d)
ENTRY="## v${VERSION} (${DATE})\n\n${MESSAGE}"

# Insert after the first blank line following the file header (line 3: "Auto-appended by...")
# This places new entries at the top of the changelog, below the header.
awk -v entry="$ENTRY" '
  /^## v[0-9]/ && !inserted {
    print entry
    print ""
    inserted = 1
  }
  { print }
' "$CHANGELOG" > "${CHANGELOG}.tmp"

mv "${CHANGELOG}.tmp" "$CHANGELOG"
echo "Changelog entry added: v${VERSION}"
