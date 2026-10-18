#!/usr/bin/env bash
# tier: slow
# Tests runtime/reviewer/browse.mjs, the reviewer's `devshop-browse` (spec specs/reviewer-browser.md,
# AC-5), in a real browser: a local page gives six screenshots and its facts, with Playwright found
# only in the served project's node_modules; the UI baseline's example reports no colour outside its
# tokens; requests, WebSockets and fonts from another origin are blocked and listed; a path that
# leaves the local run, a flag or a second path is refused with nothing loaded; and every way it
# can't judge exits 2. Needs `npm ci` (Playwright, pinned) and that version's Chromium.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
[ -d "$repo_root/node_modules/playwright" ] || fail "Playwright not installed (npm ci)"

work=$(mktemp -d)
server_pid=
cleanup() {
  [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

# The script runs from a copy with no node_modules above it, so Playwright can come only from the
# project's own node_modules, as in a review's throwaway clone.
cp "$repo_root/runtime/reviewer/browse.mjs" "$work/browse.mjs"
project="$work/project"
mkdir -p "$project/site"
ln -s "$repo_root/node_modules" "$project/node_modules"
echo '{}' >"$project/package.json"
ui="$repo_root/runtime/templates/ui"
cp "$ui/base.css" "$ui/theme.js" "$ui/example.html" "$project/site/"
cat >"$project/site/ext.html" <<'EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Outside</title>
<style>
@font-face { font-family: Far; src: url(http://example.com/far.woff2) format('woff2'); }
p { font-family: Far, sans-serif; }
</style>
</head>
<body><main><p>Hello</p></main>
<script>
fetch('http://example.com/data.json').catch(() => {});
try { new WebSocket('ws://example.com/socket'); } catch (e) {}
</script>
</body>
</html>
EOF

# Unstyled elements and one styled one: only what differs from the browser's defaults is a fact.
cat >"$project/site/plain.html" <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Plain</title></head>
<body><h1>Title</h1><p>Text</p><ul><li>One</li></ul><button>Go</button>
<div style="padding: 7px; color: rgb(1, 2, 3)">Styled</div></body></html>
EOF
cat >"$project/site/tall.html" <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Tall</title></head>
<body style="margin: 0"><div style="height: 6000px">Tall</div></body></html>
EOF
cat >"$project/site/wide.html" <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Wide</title></head>
<body style="margin: 0"><div id="wide" style="width: 600px">Wide</div></body></html>
EOF
cat >"$project/site/clip.html" <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Clip</title></head>
<body style="margin: 0"><div style="overflow-x: auto"><div style="width: 900px">A wide table, scrolled in its box</div></div></body></html>
EOF
cat >"$project/site/sw.html" <<'EOF'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>SW</title></head>
<body><script>
// Blocked, registration may still resolve, but the worker never becomes active.
if (navigator.serviceWorker) {
  navigator.serviceWorker.register('/sw.js').catch(() => {});
  navigator.serviceWorker.ready.then(() => (document.title = 'active'));
}
</script></body></html>
EOF
echo 'self.addEventListener("fetch", () => {});' >"$project/site/sw.js"

port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server --bind 127.0.0.1 "$port" --directory "$project/site" >/dev/null 2>&1 &
server_pid=$!
for _ in $(seq 50); do curl --noproxy '*' -s -o /dev/null "http://127.0.0.1:$port/" && break; sleep 0.1; done

out="$work/shots"
# browse <want exit> <args...>: runs it as the wrapper would; sets $log.
browse() {
  local want=$1 rc=0
  shift
  log=$(DEVSHOP_BROWSE_ORIGIN="http://127.0.0.1:$port" DEVSHOP_BROWSE_PROJECT="$project" DEVSHOP_BROWSE_OUT="$out" \
    node "$work/browse.mjs" "$@" 2>&1) || rc=$?
  [ "$rc" = "$want" ] || { echo "$log" >&2; fail "browse $*: expected exit $want, got $rc"; }
}
facts() { sed -n '/^{/,$p' <<<"$log"; }
png_width() { python3 -c 'import struct, sys; d = open(sys.argv[1], "rb").read(24); assert d[:8] == b"\x89PNG\r\n\x1a\n"; print(struct.unpack(">I", d[16:20])[0])' "$1"; }

browse 0 /example.html
f=$(facts)
[ "$(jq -r .title <<<"$f")" = "Example app" ] || fail "AC-5: the title isn't in the facts"
[ "$(jq '.views | length' <<<"$f")" = 6 ] || fail "AC-5: expected six views"
for w in 375 768 1280; do
  for t in light dark; do
    shot=$(jq -r --argjson w "$w" --arg t "$t" '.views[] | select(.width == $w and .theme == $t) | .screenshot' <<<"$f")
    [ -s "$shot" ] || fail "AC-5: no screenshot for $w $t"
    grep -qxF "screenshot: $shot" <<<"$log" || fail "AC-5: the screenshot path for $w $t isn't printed"
    [ "$(png_width "$shot")" = "$w" ] || fail "AC-5: the $w $t screenshot is $(png_width "$shot") px wide"
  done
done
[ "$(find "$out" -name '*.png' | wc -l)" = 6 ] || fail "AC-5: expected exactly six screenshots"
cmp -s "$out/1/375-light.png" "$out/1/375-dark.png" && fail "AC-5: the light and dark screenshots are the same"
jq -e '[.views[] | .scrollsSideways == false and .pastEdge == []] | all' <<<"$f" >/dev/null \
  || fail "AC-5: the example is reported as overflowing"
jq -e '(.fonts | length) > 0 and all(.fonts[]; test("declared .*; drawn with "))' <<<"$f" >/dev/null \
  || fail "AC-5: no declared and drawn fonts in the facts"
jq -e '(.colours.light | length) > 0 and (.colours.dark | length) > 0 and (.spacing["375"] | length) > 0' <<<"$f" >/dev/null \
  || fail "AC-5: no colours per theme or spacing per width in the facts"
jq -e '.console == [] and .failed == [] and .blocked == []' <<<"$f" >/dev/null || fail "AC-5: the example has console errors or failed requests"
# Every colour reported on the example is one of base.css's token values, in both themes.
tokens=$(grep -oE 'oklch\([^)]*\)' "$ui/base.css" | sort -u)
while IFS= read -r value; do
  grep -qxF "$value" <<<"$tokens" || fail "AC-5: the example reports a colour outside base.css's tokens: $value"
done < <(jq -r '.colours[][]' <<<"$f" | sed -n 's/^[a-z-]*: #[0-9a-f]* (\(.*\)) ×.*/\1/p')
[ "$(jq -r '.colours[][]' <<<"$f" | wc -l)" = "$(jq -r '.colours[][]' <<<"$f" | grep -c ' (oklch(')" ] \
  || fail "AC-5: a colour on the example isn't a token value: $(jq -c .colours <<<"$f")"
echo "ok - AC-5: a local page: six screenshots and its facts; the example's colours are all its tokens"

# Only what differs from the defaults: the styled div's padding and colour, nothing from the
# unstyled heading, paragraph, list or button (their default margins, padding and borders).
browse 0 /plain.html
f=$(facts)
[ "$(jq -c '.spacing["375"]' <<<"$f")" = '["padding: 7px ×1 (first: div)"]' ] \
  || fail "AC-5: spacing beyond what differs from the defaults: $(jq -c .spacing <<<"$f")"
[ "$(jq -c '.colours.light' <<<"$f")" = '["color: #010203 (rgb(1, 2, 3)) ×1 (first: div)"]' ] \
  || fail "AC-5: colours beyond what differs from the defaults: $(jq -c .colours <<<"$f")"
# A tall page's screenshot is capped at 4000 px.
browse 0 /tall.html
shot=$(facts | jq -r '.views[0].screenshot')
h=$(python3 -c 'import struct, sys; print(struct.unpack(">I", open(sys.argv[1], "rb").read(24)[20:24])[0])' "$shot")
[ "$h" = 4000 ] || fail "AC-5: a 6000 px page's screenshot is $h px tall, not 4000"
# Overflow at 375 px, none at 1280 px.
browse 0 /wide.html
f=$(facts)
jq -e '.views[] | select(.width == 375 and .theme == "light") | .scrollsSideways and (.pastEdge | any(test("^div#wide spans 0..600px")))' <<<"$f" >/dev/null \
  || fail "AC-5: the 600 px element at 375 px isn't reported: $(jq -c .views <<<"$f")"
jq -e '.views[] | select(.width == 1280 and .theme == "light") | (.scrollsSideways | not) and .pastEdge == []' <<<"$f" >/dev/null \
  || fail "AC-5: overflow reported at 1280 px"
# Wider than the phone inside a box that scrolls (clips) it: not past the edge.
browse 0 /clip.html
jq -e '[.views[] | (.scrollsSideways | not) and .pastEdge == []] | all' <<<"$(facts)" >/dev/null \
  || fail "AC-5: an element clipped by its scrolling box is reported past the edge: $(facts | jq -c .views)"
# Service workers are blocked.
browse 0 /sw.html
[ "$(facts | jq -r .title)" = SW ] || fail "AC-5: a service worker became active: $(facts | jq -r .title)"
echo "ok - AC-5: only values that differ from the defaults; screenshots capped; overflow; no service worker"

# A page that reaches another origin: each request is blocked and listed, the font as not loaded.
browse 0 /ext.html
f=$(facts)
jq -e '.blocked | any(test("^fetch http://example.com/data.json"))' <<<"$f" >/dev/null || fail "AC-5: the fetch to another origin isn't listed as blocked: $(jq -c .blocked <<<"$f")"
jq -e '.blocked | any(. == "websocket ws://example.com/socket")' <<<"$f" >/dev/null || fail "AC-5: the WebSocket to another origin isn't listed as blocked: $(jq -c .blocked <<<"$f")"
jq -e '.blocked | any(. == "remote font not loaded: http://example.com/far.woff2")' <<<"$f" >/dev/null || fail "AC-5: the remote font isn't listed as not loaded: $(jq -c .blocked <<<"$f")"
jq -e '.fonts | any(test("declared Far, sans-serif"))' <<<"$f" >/dev/null || fail "AC-5: the declared family isn't in the facts"
echo "ok - AC-5: requests, WebSockets and fonts from another origin are blocked and listed"

# Refused, with nothing loaded: no new screenshot directory.
refused() { # <args...>
  local before
  before=$(find "$out" -mindepth 1 -maxdepth 1 | wc -l)
  browse 1 "$@"
  grep -qF "devshop-browse: refused" <<<"$log" || fail "AC-5: $* not refused: $log"
  [ "$(find "$out" -mindepth 1 -maxdepth 1 | wc -l)" = "$before" ] || fail "AC-5: $* loaded something"
}
refused //example.com/
refused http://example.com/
refused '\\example.com'
refused '/\example.com'
refused example.html
refused --width 375
refused /example.html /ext.html
refused
echo "ok - AC-5: another origin, a flag, no path or a second path is refused, nothing loaded"

# Can't judge: exit 2, never a pass.
browse 2 /missing.html
grep -qF "answered HTTP 404" <<<"$log" || fail "AC-5: a missing page isn't named: $log"
mkdir -p "$work/empty" && echo '{}' >"$work/empty/package.json"
rc=0
log=$(DEVSHOP_BROWSE_ORIGIN="http://127.0.0.1:$port" DEVSHOP_BROWSE_PROJECT="$work/empty" DEVSHOP_BROWSE_OUT="$out" \
  node "$work/browse.mjs" /example.html 2>&1) || rc=$?
{ [ "$rc" = 2 ] && grep -qF "Playwright can't be loaded" <<<"$log"; } || fail "AC-5: no Playwright in the project isn't exit 2: $rc $log"
rc=0
log=$(node "$work/browse.mjs" /example.html 2>&1) || rc=$?
[ "$rc" = 2 ] || fail "AC-5: run without the wrapper's variables isn't exit 2: $rc $log"
kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
browse 2 /example.html
grep -qF "didn't load" <<<"$log" || fail "AC-5: a local run that is down isn't named: $log"
echo "ok - AC-5: a missing page, no Playwright, no wrapper or a down local run exits 2"

echo "all reviewer-browse tests passed"
