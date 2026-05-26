#!/bin/bash
# propagation-entry.sh — extract **Existing projects:** blocks from commits
# since a tag and append a versioned section to PROPAGATION.md.
# Called by release.sh after version bumps.
#
# Usage:
#   propagation-entry.sh <version> <last-tag> [propagation-path]
set -euo pipefail

VERSION="${1:?Usage: propagation-entry.sh <version> <last-tag> [propagation-path]}"
LAST_TAG="${2:?Usage: propagation-entry.sh <version> <last-tag> [propagation-path]}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_PROPAGATION="$(cd "$SCRIPT_DIR/../.." && pwd)/kit/docs/PROPAGATION.md"
PROPAGATION="${3:-$DEFAULT_PROPAGATION}"

if [ ! -f "$PROPAGATION" ]; then
  echo "ERROR: $PROPAGATION not found."
  exit 1
fi

ENTRIES=""

while IFS= read -r sha; do
  [ -z "$sha" ] && continue
  SUBJECT=$(git log -1 --format='%s' "$sha")
  BODY=$(git log -1 --format='%b' "$sha")

  # Extract the **Existing projects:** block. It runs from the marker
  # through the next section break (---, ##, Key details:, or EOF).
  BLOCK=$(echo "$BODY" | awk '
    /^\*\*Existing projects:\*\*/ { found=1; sub(/^\*\*Existing projects:\*\* */, ""); }
    found && /^---$/ { exit }
    found && /^## / { exit }
    found && /^Key details:/ { exit }
    found { print }
  ')

  BLOCK=$(echo "$BLOCK" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sed '/^$/d')

  if [ -n "$BLOCK" ]; then
    ENTRIES="${ENTRIES}- **${SUBJECT}** — ${BLOCK}
"
  fi
done < <(git log --format='%H' --reverse "${LAST_TAG}..HEAD" 2>/dev/null)

if [ -n "$ENTRIES" ]; then
  SECTION="## v${VERSION}\n\n${ENTRIES}"
else
  SECTION="## v${VERSION}\n\n(no manual steps)"
fi

# Insert before the first existing ## v line (newest at top).
# Same pattern as changelog-entry.sh.
awk -v entry="$SECTION" '
  /^## v[0-9]/ && !inserted {
    printf "%s\n\n", entry
    inserted = 1
  }
  { print }
  END { if (!inserted) printf "\n%s\n", entry }
' "$PROPAGATION" > "${PROPAGATION}.tmp"

mv "${PROPAGATION}.tmp" "$PROPAGATION"
echo "Propagation entry added: v${VERSION}"
