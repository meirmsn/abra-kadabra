#!/bin/bash
# What: Pre-commit guard — refuses duplicate supabase_port_offset values
#       across kit/notes/projects/*.md files.
# Why:  Two projects sharing the same port offset causes silent host-port
#       collisions when both run concurrently on the same Docker host.
# Does NOT: validate that the offset is a multiple of 100 — that's a style
#       convention, not a correctness invariant.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
PROJECTS_DIR="$DEVSHOP/kit/notes/projects"

if [ ! -d "$PROJECTS_DIR" ]; then
  exit 0
fi

# Only run when a projects/*.md file is staged.
STAGED_PROJECT_FILES=$(git diff --cached --name-only -- 'kit/notes/projects/*.md' 2>/dev/null || true)
if [ -z "$STAGED_PROJECT_FILES" ]; then
  exit 0
fi

declare -A OFFSET_MAP
DUPLICATES=""

for notes_file in "$PROJECTS_DIR"/*.md; do
  [ -f "$notes_file" ] || continue
  project_name="$(basename "$notes_file" .md)"
  offset=$(grep -m1 '^supabase_port_offset:' "$notes_file" 2>/dev/null | sed 's/^supabase_port_offset:[[:space:]]*//' | tr -d '[:space:]' || true)
  [ -z "$offset" ] && continue

  if [ -n "${OFFSET_MAP[$offset]:-}" ]; then
    DUPLICATES+="  ✖ offset $offset claimed by both '${OFFSET_MAP[$offset]}' and '$project_name'\n"
  else
    OFFSET_MAP[$offset]="$project_name"
  fi
done

if [ -n "$DUPLICATES" ]; then
  echo "✖ Duplicate supabase_port_offset detected:"
  printf '%b' "$DUPLICATES"
  echo ""
  echo "Each project must have a unique port offset to avoid host-port collisions."
  echo "Edit the conflicting kit/notes/projects/<name>.md frontmatter to resolve."
  exit 1
fi
