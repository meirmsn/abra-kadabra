#!/usr/bin/env bash
# Places the Next.js home's UI files in a project (runtime/stacks/nextjs-supabase/README.md § UI),
# each on its own: a missing file is placed (scripts with their executable bit), an identical one is
# left alone, and one that differs is shown as a diff and left untouched while the others are
# placed. It never touches scripts/check-fast.sh or scripts/check-slow.sh: the README says which
# line the project's own fast tier gains.
# Usage: place.sh <project>
# Exit 0 = every file placed or already identical; 1 = some differ (shown, untouched); 2 = couldn't
# run (no such project, a source it can't read).
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd) || exit 2
ui="$here/../../templates/ui"

cant() {
  echo "place: can't run: $*" >&2
  exit 2
}

[ $# -eq 1 ] && [ -n "$1" ] || cant "usage: place.sh <project>"
[ -d "$1" ] || cant "$1 is not a directory"
project=$(cd "$1" && pwd) || cant "can't enter $1"

# <source> <project path> <mode>
files=(
  "$here/globals.css app/globals.css 644"
  "$ui/theme.js public/theme.js 644"
  "$here/ui-tokens.sh scripts/ui-tokens.sh 755"
  "$ui/tokens-check.mjs scripts/ui/tokens-check.mjs 644"
  "$ui/render-check.mjs scripts/ui/render-check.mjs 644"
  "$ui/design-md-check.mjs scripts/ui/design-md-check.mjs 755"
)
for entry in "${files[@]}"; do
  read -r src _ _ <<<"$entry"
  [ -f "$src" ] && [ -r "$src" ] || cant "can't read $src"
done

differ=0
for entry in "${files[@]}"; do
  read -r src dest mode <<<"$entry"
  target="$project/$dest"
  if [ ! -e "$target" ]; then
    mkdir -p "$(dirname "$target")" || cant "can't create $(dirname "$dest")"
    { cp "$src" "$target" && chmod "$mode" "$target"; } || cant "can't write $dest"
    echo "placed: $dest"
  elif cmp -s "$src" "$target"; then
    echo "same: $dest"
  else
    echo "differs: $dest (left as it is; merge by hand):"
    diff -u "$target" "$src" | sed '1,2d'
    differ=1
  fi
done
[ "$differ" = 0 ] || echo "place: some files differ; nothing of theirs was changed"
exit "$differ"
