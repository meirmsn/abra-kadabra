#!/usr/bin/env bash
# Tests runtime/scripts/stack-homes.sh, which picks the stack homes a project's change loads (TARGET §
# L3 Build 2, north-star step 2): a stack applies when any path its `detect` file lists exists in the
# project. It prints one STACKS: line (the log) and the home to read for each applying stack; a
# decoy home that doesn't apply is never printed. Runs a copy of the script beside fake stacks.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
rt="$work/runtime"
mkdir -p "$rt/scripts"
cp "$repo_root/runtime/scripts/stack-homes.sh" "$rt/scripts/"
script="$rt/scripts/stack-homes.sh"

# home <stack> <detect lines...>: a stack home with a README and a detect file.
home() {
  local s=$1
  shift
  mkdir -p "$rt/stacks/$s"
  echo "# $s" >"$rt/stacks/$s/README.md"
  printf '%s\n' "$@" >"$rt/stacks/$s/detect"
}
# run <name> <want exit> <project> <want output, exactly; or '' to skip> [text the output must name]
run() {
  local rc=0 out
  out=$("$script" "$3" 2>&1) || rc=$?
  [ "$rc" = "$2" ] || { echo "$out" >&2; fail "$1: expected exit $2, got $rc"; }
  [ -z "$4" ] || [ "$out" = "$4" ] || { printf 'got:\n%s\nwant:\n%s\n' "$out" "$4" >&2; fail "$1: wrong output"; }
  [ -z "${5:-}" ] || grep -qF -- "$5" <<<"$out" || { echo "$out" >&2; fail "$1: output doesn't name '$5'"; }
  echo "ok - $1"
}

proj="$work/proj"
mkdir -p "$proj/src"
run "a version with no stack homes loads none" 0 "$proj" "STACKS: none"

home cloudflare '# Workers + D1' '' 'wrangler.json' 'wrangler.toml'
home nextjs-supabase 'next.config.*' 'supabase/config.toml'
run "a project matching no stack loads none" 0 "$proj" "STACKS: none"

touch "$proj/wrangler.toml"
run "only the matching stack loads; the decoy doesn't" 0 "$proj" \
  "STACKS: cloudflare
$rt/stacks/cloudflare/README.md"

touch "$proj/next.config.mjs"
run "a glob in detect matches; both load, sorted" 0 "$proj" \
  "STACKS: cloudflare, nextjs-supabase
$rt/stacks/cloudflare/README.md
$rt/stacks/nextjs-supabase/README.md"

rm "$proj/next.config.mjs" "$proj/wrangler.toml"
mkdir -p "$proj/supabase" && touch "$proj/supabase/config.toml"
run "a nested path in detect matches" 0 "$proj" \
  "STACKS: nextjs-supabase
$rt/stacks/nextjs-supabase/README.md"

# Fail closed: a stack home that can't be judged stops the run (exit 2), never silently skips.
home broken 'x'
rm "$rt/stacks/broken/detect"
run "a stack home without detect can't run" 2 "$proj" '' "broken: no detect file"
home broken 'x'
rm "$rt/stacks/broken/README.md"
run "a stack home without README.md can't run" 2 "$proj" '' "broken: no README.md"
home broken '../outside'
run "a detect path leaving the project can't run" 2 "$proj" '' "broken: detect path"
home broken '/etc/passwd'
run "an absolute detect path can't run" 2 "$proj" '' "broken: detect path"
home broken '# only a comment'
run "a detect file with no paths can't run" 2 "$proj" '' "broken: detect lists no paths"
rm -rf "$rt/stacks/broken"
run "a missing project can't run" 2 "$work/nope" '' "not a directory"
run "no argument can't run" 2 "" '' "usage"
