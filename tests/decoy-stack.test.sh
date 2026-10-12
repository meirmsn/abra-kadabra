#!/usr/bin/env bash
# The north-star decoy (W10.5.3, TARGET north-star step 2): the nextjs-supabase stack home must never
# load for the fixture (a Cloudflare Workers + D1 project that also has a package.json), and must load
# for a real Next.js or Supabase project. Runs the real runtime/scripts/stack-homes.sh against the real
# runtime/stacks/, on scratch projects shaped like each case.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
script="$repo_root/runtime/scripts/stack-homes.sh"
decoy="$repo_root/runtime/stacks/nextjs-supabase"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[ -f "$decoy/README.md" ] && [ -f "$decoy/detect" ] || fail "no nextjs-supabase stack home at runtime/stacks/nextjs-supabase"

# project <name>: an empty project directory.
project() { mkdir -p "$work/$1"; echo "$work/$1"; }
# loads <name> <project> yes|no: whether the STACKS line names nextjs-supabase.
loads() {
  local out rc=0
  out=$("$script" "$2" 2>&1) || rc=$?
  [ "$rc" = 0 ] || { echo "$out" >&2; fail "$1: stack-homes.sh exited $rc"; }
  local line
  line=$(grep '^STACKS: ' <<<"$out") || fail "$1: no STACKS line"
  if grep -qw 'nextjs-supabase' <<<"$line"; then got=yes; else got=no; fi
  [ "$got" = "$3" ] || { echo "$out" >&2; fail "$1: nextjs-supabase loaded=$got, want $3"; }
  if [ "$3" = yes ]; then
    grep -qx "$decoy/README.md" <<<"$out" || fail "$1: the home's README isn't printed"
  else
    ! grep -q "nextjs-supabase/README.md" <<<"$out" || fail "$1: the README is printed for a stack not loaded"
  fi
  echo "ok - $1"
}

# The fixture's shape: package.json with Workers tooling, wrangler.jsonc, a Worker, specs.
p=$(project fixture)
mkdir -p "$p/src" "$p/specs" "$p/traffic" "$p/migrations"
cat >"$p/package.json" <<'JSON'
{
  "name": "fixture",
  "scripts": { "dev": "wrangler dev", "test": "vitest run" },
  "devDependencies": { "@cloudflare/vitest-plugin": "1.4.0", "vitest": "5.0.3", "wrangler": "4.149.0" }
}
JSON
echo '{ "name": "fixture", "main": "src/index.js" }' >"$p/wrangler.jsonc"
echo 'export default {};' >"$p/src/index.js"
loads "the fixture's shape never loads the decoy" "$p" no

# Near misses: "next" as a word, a script, or another package's name.
p=$(project near)
cat >"$p/package.json" <<'JSON'
{
  "name": "near",
  "description": "the next version of the list",
  "scripts": { "build": "next build", "next-step": "echo" },
  "dependencies": { "next-auth": "5.0.0", "nextra": "3.0.0" }
}
JSON
loads "next in a description, a script or another package's name doesn't load it" "$p" no

# Real Next.js and Supabase projects do load it.
p=$(project nextdep)
printf '{\n  "dependencies": {\n    "next": "15.5.0",\n    "react": "19.1.0"\n  }\n}\n' >"$p/package.json"
loads "a next dependency loads it" "$p" yes

p=$(project nextconfig)
echo 'export default {};' >"$p/next.config.mjs"
loads "a next.config file loads it" "$p" yes

p=$(project supa)
mkdir -p "$p/supabase" && echo 'project_id = "x"' >"$p/supabase/config.toml"
loads "a supabase/config.toml loads it" "$p" yes

echo "PASS: the decoy loads only for Next.js / Supabase projects"
