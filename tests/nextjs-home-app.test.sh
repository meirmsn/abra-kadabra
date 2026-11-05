#!/usr/bin/env bash
# tier: slow
# The Next.js home end to end (specs/react-home-ui-defaults.md AC-11): a synthetic Next.js app
# (tests/fixtures/nextjs-home-app/, every dependency locked) gets the home's files from place.sh and a
# button and a dialog from shadcn/ui's real release through shadcn-add.mjs, then passes the token
# check, the DESIGN.md check, a production build and the render check at 375, 768 and 1280 px in
# light and dark. Needs the npm registry and GitHub's raw host; a failed install or fetch fails the
# test with "can't run", never a pass. Uses the devshop's own pinned Playwright and its Chromium.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
home="$repo_root/runtime/stacks/nextjs-supabase"
fixture="$repo_root/tests/fixtures/nextjs-home-app"
[ -d "$repo_root/node_modules/playwright" ] || fail "Playwright not installed (npm ci)"
for t in node npm git curl setsid; do command -v "$t" >/dev/null || fail "can't run: $t not found"; done

work=$(mktemp -d)
server=
cleanup() {
  [ -z "$server" ] || kill -- "-$server" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
isolate_git "$work"
app="$work/app"
cp -R "$fixture" "$app"
printf 'node_modules/\n.next/\nnext-env.d.ts\n*.tsbuildinfo\n' >"$app/.gitignore"
log="$work/log"

# step <name> <command...>: runs it in the app, exit 0 wanted; its output in $log.
step() {
  local name=$1 rc=0
  shift
  (cd "$app" && "$@") >"$log" 2>&1 || rc=$?
  [ "$rc" = 0 ] || { tail -30 "$log" >&2; fail "react-home-ui-defaults AC-11: $name: exit $rc"; }
}

rc=0
(cd "$app" && timeout 600 npm ci --no-audit --no-fund) >"$log" 2>&1 || rc=$?
[ "$rc" = 0 ] || { tail -20 "$log" >&2; fail "react-home-ui-defaults AC-11: can't run: npm ci failed (exit $rc; network?)"; }
# The render check imports Playwright from the app's tree: the devshop's own pinned copy.
ln -s "$repo_root/node_modules/playwright" "$app/node_modules/playwright"
ln -s "$repo_root/node_modules/playwright-core" "$app/node_modules/playwright-core"

step "place.sh" "$home/place.sh" .
echo "ok - react-home-ui-defaults AC-11: place.sh places the home's files in the app"

step "shadcn-add.mjs button dialog" node "$home/shadcn-add.mjs" . button dialog
grep -qF "from shadcn@4.23.0" "$log" || { cat "$log" >&2; fail "react-home-ui-defaults AC-11: shadcn-add didn't read the app's version"; }
! grep -q "npm install" "$log" || { cat "$log" >&2; fail "react-home-ui-defaults AC-11: shadcn-add installed a package the lockfile doesn't hold"; }
for f in components/ui/button.tsx components/ui/dialog.tsx lib/utils.ts; do
  [ -f "$app/$f" ] || fail "react-home-ui-defaults AC-11: $f wasn't copied"
done
echo "ok - react-home-ui-defaults AC-11: shadcn-add.mjs copies the button and dialog from the release, nothing to install"

(cd "$app" && git init -q && git add -A && git commit -qm app)
step "ui-tokens.sh" scripts/ui-tokens.sh app/globals.css components/ui
grep -q "^tokens-check: ok" "$log" || { cat "$log" >&2; fail "react-home-ui-defaults AC-11: no tokens-check ok line"; }
step "design-md-check.mjs" node scripts/ui/design-md-check.mjs --theme app/globals.css "$repo_root/tests/fixtures/design-md/baseline/DESIGN.md"
echo "ok - react-home-ui-defaults AC-11: the token check and the DESIGN.md check pass on the app"

step "next build" env NEXT_TELEMETRY_DISABLED=1 timeout 600 npx next build
echo "ok - react-home-ui-defaults AC-11: the app builds"

port=$(node -e "const s=require('net').createServer();s.listen(0,'127.0.0.1',()=>{console.log(s.address().port);s.close()})")
(cd "$app" && NEXT_TELEMETRY_DISABLED=1 exec setsid npx next start -H 127.0.0.1 -p "$port") >"$work/server.log" 2>&1 &
server=$!
for _ in $(seq 1 60); do
  curl -sf -o /dev/null "http://127.0.0.1:$port/" && break
  kill -0 "$server" 2>/dev/null || { cat "$work/server.log" >&2; fail "react-home-ui-defaults AC-11: can't run: the server exited"; }
  sleep 1
done
curl -sf -o /dev/null "http://127.0.0.1:$port/" || { cat "$work/server.log" >&2; fail "react-home-ui-defaults AC-11: can't run: the server never answered"; }
step "render-check.mjs" node scripts/ui/render-check.mjs --url "http://127.0.0.1:$port/" --out "$work/shots"
grep -qF "ok at 375, 768, 1280 px, light and dark" "$log" || { cat "$log" >&2; fail "react-home-ui-defaults AC-11: no render-check ok line"; }
echo "ok - react-home-ui-defaults AC-11: the render check passes at 375, 768 and 1280 px, light and dark"

echo "PASS: the Next.js home end to end on a real app"
