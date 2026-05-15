#!/bin/bash
# What: Soft nudge — when a project commits files that have [sync]-tagged devshop
#       template counterparts, surface a one-line reminder per file to consider
#       propagating the change back via sync/to-devshop.sh.
# Why: [sync] entries (.github/workflows/, .husky/, turbo.json, eslint.config.mjs, …)
#      represent shared tooling that's bidirectional by design. Without a nudge,
#      project-side fixes drift from the template — the home-os PR #15 case had ci.yml
#      fixes living in project repos for a month before propagating. The manifest
#      already encodes the bidirectional intent; this hook just surfaces it.
# Does NOT: Block, auto-propagate, or fire on [scaffold-once] / [symlink] / [locked]
#      entries. Pure nudge — operator decides whether the diff propagates or stays
#      project-specific.
#
# Project repos only — devshop-self / devshop-repo mode short-circuits in the caller.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
[ -d "$DEVSHOP" ] || exit 0

MANIFEST="$DEVSHOP/kit/manifest.txt"
TEMPLATE_DIR="$DEVSHOP/template"
[ -f "$MANIFEST" ] || exit 0
[ -d "$TEMPLATE_DIR" ] || exit 0

# shellcheck source=/devshop/kit/scripts/sync/lib/parse-manifest.sh
source "$DEVSHOP/kit/scripts/sync/lib/parse-manifest.sh"
parse_manifest "$MANIFEST" >/dev/null 2>&1 || exit 0

# [sync]-only — [scaffold-once] is intentionally project-owned after first scaffold,
# [symlink] auto-propagates by definition, [locked] is root-owned (project can't stage edits).
SYNC_PATHS=$(manifest_paths_by sync || true)
[ -n "$SYNC_PATHS" ] || exit 0

STAGED=$(git diff --cached --name-only 2>/dev/null || true)
[ -n "$STAGED" ] || exit 0

is_excluded() {
  local file="$1" ex
  for ex in "${MANIFEST_EXCLUDES[@]:-}"; do
    [ -n "$ex" ] || continue
    [ "$file" = "$ex" ] && return 0
  done
  return 1
}

MATCHES=""
while IFS= read -r file; do
  [ -n "$file" ] || continue
  is_excluded "$file" && continue
  while IFS= read -r sync_entry; do
    [ -n "$sync_entry" ] || continue
    if [[ "$sync_entry" == */ ]]; then
      [[ "$file" == "$sync_entry"* ]] || continue
    else
      [ "$file" = "$sync_entry" ] || continue
    fi
    [ -e "$TEMPLATE_DIR/$file" ] && MATCHES+="$file"$'\n' && break
  done <<< "$SYNC_PATHS"
done <<< "$STAGED"

[ -z "$MATCHES" ] && exit 0

echo ""
echo "📦 Devshop template counterparts staged in this commit:"
while IFS= read -r f; do
  [ -n "$f" ] && echo "    $f  →  $DEVSHOP/template/$f"
done <<< "$MATCHES"
echo ""
echo "    These paths are [sync] in kit/manifest.txt — changes may belong"
echo "    in the devshop template too. After this commit, consider:"
echo "      .devshopkit/scripts/sync/to-devshop.sh"
echo "    to diff + propagate (or skip if the change is project-specific)."
echo ""

exit 0
