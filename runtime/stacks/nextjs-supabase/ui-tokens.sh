#!/usr/bin/env bash
# The token check over a Next.js project's code (runtime/stacks/nextjs-supabase/README.md § UI);
# place.sh places it at scripts/ui-tokens.sh. The project's check-fast.sh calls it as a stack part:
#   part scripts/ui-tokens.sh "$THEME_CSS" components/ui
# It runs scripts/ui/tokens-check.mjs (the devshop's copy) with the theme over every file git lists
# as *.css, *.ts, *.tsx, *.jsx or *.mdx, except the theme itself and the library directory.
# Mitigation: the library directory (shadcn/ui's copies) is left out because its components put
# variables Radix or their own inline styles set at run time inside var(), which the check would
# report as undefined tokens. Root cause: tokens-check.mjs reads every var() name as a theme token.
# Usage: scripts/ui-tokens.sh <theme.css> <library dir>
# Exit 0 = clean; 1 = findings; 2 = couldn't run (an argument missing, no theme, no check copy, git
# failing, nothing to check). Never a pass when it can't run.
set -uo pipefail

cant() {
  echo "ui-tokens: can't run: $*" >&2
  exit 2
}

[ $# -eq 2 ] && [ -n "$1" ] && [ -n "$2" ] || cant "usage: scripts/ui-tokens.sh <theme.css> <library dir>"
theme=$1
library=${2%/}
cd "$(dirname "$0")/.." || cant "can't enter the project"
[ -f "$theme" ] || cant "no theme at $theme"
[ -f scripts/ui/tokens-check.mjs ] || cant "no scripts/ui/tokens-check.mjs (place.sh places the devshop's copy)"
command -v node >/dev/null || cant "node not found"

listed=$(git ls-files -- '*.css' '*.ts' '*.tsx' '*.jsx' '*.mdx') || cant "git ls-files failed"
files=()
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ "$f" = "$theme" ] && continue
  case $f in "$library"/*) continue ;; esac
  files+=("$f")
done <<<"$listed"
[ ${#files[@]} -gt 0 ] || cant "no files to check besides the theme"

node scripts/ui/tokens-check.mjs --theme "$theme" "${files[@]}"
