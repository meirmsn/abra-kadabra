#!/usr/bin/env bash
# This repo's per-file lint: the devshop's per-edit nudge (runtime/hooks/post-edit.sh) runs it on
# each file Claude edits. Prettier rewrites the file's formatting in place (the version package.json
# pins; .prettierignore applies), and shellcheck reports on it if it is a shell script (by extension
# or shebang). The spikes, kept as notes, are skipped, as in scripts/shellcheck.sh.
# Usage: scripts/lint-file.sh <repo-relative file>   (run from the repo root)
#   $PRETTIER and $SHELLCHECK override the tools (tests).
# Exit 0 = clean (formatting fixed); 1 = shellcheck findings; 2 = can't run (missing or unpinned tool).
set -uo pipefail

f=${1:?usage: scripts/lint-file.sh <file>}
[ -f "$f" ] || exit 0
case $f in kit/notes/revamp/spikes/*) exit 0 ;; esac
repo=$(cd "$(dirname "$0")/.." && pwd)
prettier=${PRETTIER:-$repo/node_modules/.bin/prettier}
shellcheck=${SHELLCHECK:-shellcheck}
rc=0

if ! command -v "$prettier" >/dev/null; then
  echo "lint-file: prettier not found at $prettier (run npm ci)" >&2
  rc=2
else
  want=$(node -p 'require(process.argv[1]).devDependencies.prettier' "$repo/package.json" 2>/dev/null)
  got=$("$prettier" --version 2>/dev/null)
  if [ -z "$want" ] || [ "$got" != "$want" ]; then
    echo "lint-file: prettier is '$got', package.json pins '$want' (run npm ci)" >&2
    rc=2
  else
    "$prettier" --write --ignore-unknown --log-level warn -- "$f" || rc=2
  fi
fi

case $f in
  *.sh | *.bash) shell=1 ;;
  *) head -n1 -- "$f" | grep -qE '^#!.*[/ ](ba|da)?sh([[:space:]]|$)' && shell=1 || shell=0 ;;
esac
if [ "$shell" = 1 ]; then
  if ! command -v "$shellcheck" >/dev/null; then
    echo "lint-file: shellcheck not found" >&2
    rc=2
  elif ! "$shellcheck" --external-sources -- "$f"; then
    [ "$rc" -ge 1 ] || rc=1
  fi
fi
exit "$rc"
