#!/usr/bin/env bash
# The Cloudflare stack home (W10.10.2): runtime/stacks/cloudflare/ loads for a Cloudflare Workers
# project (a wrangler config, as the website and the fixture have) and never for a project with only a
# package.json or a Next.js project; its README is a real home (its eight sections, each by heading),
# not a placeholder. Runs the real runtime/scripts/stack-homes.sh against the real runtime/stacks/.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
script="$repo_root/runtime/scripts/stack-homes.sh"
home="$repo_root/runtime/stacks/cloudflare"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

[ -f "$home/README.md" ] && [ -f "$home/detect" ] || fail "no cloudflare stack home at runtime/stacks/cloudflare"
# A real home, not a hollow one: the sections W10.10.2 asks for, each as a heading.
for h in 'Set-up' 'Deploy, with the day-one rollback' 'Previews: one Worker per PR, in a separate account' \
  'The quality bar, in the slow tier' 'Platform controls in use (TARGET Safety 12)' 'Cloud-session facts' \
  'Tests are named by spec and item' "What the website's first changes taught"; do
  grep -qx "## $h" "$home/README.md" || fail "the home has no '## $h' section"
done
! grep -qi 'placeholder' "$home/README.md" || fail "the home still calls itself a placeholder"

# loads <name> <project> yes|no: whether the STACKS line names cloudflare, and its README is printed.
loads() {
  local out rc=0 line got
  out=$("$script" "$2" 2>&1) || rc=$?
  [ "$rc" = 0 ] || { echo "$out" >&2; fail "$1: stack-homes.sh exited $rc"; }
  line=$(grep '^STACKS: ' <<<"$out") || fail "$1: no STACKS line"
  if grep -qw 'cloudflare' <<<"$line"; then got=yes; else got=no; fi
  [ "$got" = "$3" ] || { echo "$out" >&2; fail "$1: cloudflare loaded=$got, want $3"; }
  if [ "$3" = yes ]; then
    grep -qx "$home/README.md" <<<"$out" || fail "$1: the home's README isn't printed"
  else
    ! grep -q "cloudflare/README.md" <<<"$out" || fail "$1: the README is printed for a stack not loaded"
  fi
  echo "ok - $1"
}

# The website's shape: a Worker serving static assets, configured in wrangler.jsonc.
p="$work/website"
mkdir -p "$p/site" "$p/scripts"
printf '{\n  "name": "website",\n  "devDependencies": { "wrangler": "4.149.0" }\n}\n' >"$p/package.json"
echo '{ "name": "website", "assets": { "directory": "./dist" } }' >"$p/wrangler.jsonc"
loads "a Worker with a wrangler.jsonc loads it" "$p" yes

p="$work/toml"
mkdir -p "$p"
printf 'name = "app"\nmain = "src/index.js"\n' >"$p/wrangler.toml"
loads "a wrangler.toml loads it" "$p" yes

p="$work/json"
mkdir -p "$p"
echo '{ "name": "app" }' >"$p/wrangler.json"
loads "a wrangler.json loads it" "$p" yes

# A Node project with no wrangler config isn't a Cloudflare project, even one that mentions Workers.
p="$work/node"
mkdir -p "$p"
printf '{\n  "name": "tool",\n  "description": "deploys to cloudflare workers one day",\n  "devDependencies": { "prettier": "3.9.10" }\n}\n' >"$p/package.json"
loads "a package.json alone doesn't load it" "$p" no

p="$work/next"
mkdir -p "$p"
printf '{\n  "dependencies": { "next": "15.5.0" }\n}\n' >"$p/package.json"
echo 'export default {};' >"$p/next.config.mjs"
loads "a Next.js project doesn't load it" "$p" no

echo "PASS: the Cloudflare home loads only for a project with a wrangler config"
