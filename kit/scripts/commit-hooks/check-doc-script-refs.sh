#!/bin/bash
# What: Pre-commit check (devshop-self only) — flags broken kit/scripts or kit/hooks
#       references in active docs (catches rename/move/delete drift)
# Why: Stale references accumulate when scripts are renamed/moved/deleted but the
#      prose mentions in docs/guide/, ROADMAP.md, CLAUDE.md, README.md, and SKILL.md
#      files don't get swept. Surfaced 2026-04-29 during a hook-architecture audit.
# Does NOT: Validate references in kit/notes/ — those are historical and intentionally
#           document why scripts were deleted/renamed (e.g., ak-commit-design.md).
#
# Active doc paths scanned:
#   /devshop/kit/docs/**/*.md
#   /devshop/kit/ROADMAP.md
#   /devshop/CLAUDE.md
#   /devshop/README.md
#   /devshop/.claude/skills/**/SKILL.md
#
# Reference patterns matched:
#   kit/scripts/<name>.sh  | kit/scripts/<subdir>/<name>.sh  (any depth)
#   kit/hooks/<name>.sh
#   /devshop/kit/scripts/...sh | /devshop/kit/hooks/...sh
#
# Exempt list at /devshop/.devshop-doc-script-refs-exempt (one regex per line, # comments OK)
# for intentionally-stale historical refs that aren't migrated to kit/notes/.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

# Devshop-self only — projects don't have kit/scripts/ to validate against.
[ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ] || exit 0

# Active doc roots to scan.
DOC_ROOTS=(
  "$DEVSHOP/kit/docs"
  "$DEVSHOP/kit/ROADMAP.md"
  "$DEVSHOP/CLAUDE.md"
  "$DEVSHOP/README.md"
  "$DEVSHOP/.claude/skills"
)

EXEMPT_FILE="$DEVSHOP/.devshop-doc-script-refs-exempt"

# Collect all kit/scripts/...sh and kit/hooks/...sh references with their source files.
# Format: <referenced-path>\t<doc-file>:<line-num>
matches=$(
  for root in "${DOC_ROOTS[@]}"; do
    [ -e "$root" ] || continue
    if [ -d "$root" ]; then
      grep -rEn --include='*.md' \
        '(/devshop/)?kit/(scripts|hooks)/[a-zA-Z0-9_./-]+\.sh' "$root" 2>/dev/null || true
    else
      grep -En \
        '(/devshop/)?kit/(scripts|hooks)/[a-zA-Z0-9_./-]+\.sh' "$root" 2>/dev/null \
        | sed "s|^|$root:|" || true
    fi
  done
)

[ -z "$matches" ] && exit 0

# Parse matches: each line is <doc-file>:<line-num>:<text>
# Extract the script ref(s) from each text, build a (doc_file:line, ref) list.
broken_lines=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  # Split into <doc>:<lineno>:<text>
  doc_path=$(echo "$line" | cut -d: -f1)
  line_num=$(echo "$line" | cut -d: -f2)
  text=$(echo "$line" | cut -d: -f3-)

  # Extract every kit/scripts/...sh and kit/hooks/...sh reference from this line
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    # Strip leading /devshop/ if present, normalize
    rel="${ref#/devshop/}"
    # Apply exempt list (regex match on the relative path).
    # Use process substitution so `grep -f` reads patterns from a stream while
    # the input arrives via `<<<` (otherwise both contend for stdin).
    if [ -f "$EXEMPT_FILE" ]; then
      if grep -qE -f <(sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$EXEMPT_FILE" | grep -v '^$') <<< "$rel" 2>/dev/null; then
        continue
      fi
    fi
    # Verify the file exists
    if [ ! -f "$DEVSHOP/$rel" ]; then
      broken_lines+="    $rel"$'\n'
      broken_lines+="      ↳ referenced at $doc_path:$line_num"$'\n'
    fi
  done < <(echo "$text" | grep -oE '(/devshop/)?kit/(scripts|hooks)/[a-zA-Z0-9_./-]+\.sh')
done <<< "$matches"

if [ -n "$broken_lines" ]; then
  echo ""
  echo "✖ BLOCKING: stale kit/scripts or kit/hooks references in active docs:" >&2
  echo "" >&2
  echo -n "$broken_lines" >&2
  echo "" >&2
  echo "  These references point to files that don't exist (rename / move /" >&2
  echo "  delete drift). Either restore the file at the cited path, or update" >&2
  echo "  the doc to match the new path." >&2
  echo "" >&2
  echo "  Historical notes under kit/notes/** are NOT scanned — those are" >&2
  echo "  expected to mention deleted scripts (rationale archives)." >&2
  echo "" >&2
  echo "  If a reference is intentionally stale and can't move to kit/notes/," >&2
  echo "  add a regex pattern to .devshop-doc-script-refs-exempt at the repo root." >&2
  exit 1
fi

exit 0
