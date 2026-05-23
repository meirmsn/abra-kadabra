#!/bin/bash
# What: Prints the next available Supabase port offset (lowest unused 100-block).
# Why:  Called by /ak-new-project Phase A to auto-assign a port offset to a new
#       project without operator input.
# Does NOT: write to any file — the caller writes the offset to notes frontmatter.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
PROJECTS_DIR="$DEVSHOP/kit/notes/projects"

if [ ! -d "$PROJECTS_DIR" ]; then
  echo "0"
  exit 0
fi

TAKEN_OFFSETS=$(grep -h '^supabase_port_offset:' "$PROJECTS_DIR"/*.md 2>/dev/null \
  | sed 's/^supabase_port_offset:[[:space:]]*//' | sed 's/[[:space:]]*$//' | sort -n || true)

OFFSET=0
while echo "$TAKEN_OFFSETS" | grep -qx "$OFFSET" 2>/dev/null; do
  OFFSET=$((OFFSET + 100))
done

# Operator override takes precedence
echo "${SUPABASE_PORT_OFFSET_OVERRIDE:-$OFFSET}"
