#!/usr/bin/env bash
# tier: slow
# Tests runtime/templates/ui/render-check.mjs (spec specs/ui-baseline.md, AC-3 and AC-4) in a real
# browser: the baseline's example page passes at 375, 768 and 1280 px in both system themes and
# leaves six screenshots; each page below, the example with one fault injected, fails naming its
# rule; and every way the check can't run exits 2, never 0. Needs `npm ci` (Playwright, pinned) and
# that version's Chromium (cloud sessions have it; CI installs it).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
ui="$repo_root/runtime/templates/ui"
check="$ui/render-check.mjs"
[ -f "$check" ] || fail "missing $check"

work=$(mktemp -d)
server_pid=
cleanup() {
  [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
site="$work/site"
mkdir -p "$site"
cp "$ui/base.css" "$ui/theme.js" "$ui/example.html" "$site/"

# variant <name> <python expression on s, the example's text>: writes $site/<name>.html.
variant() {
  python3 - "$site/example.html" "$site/$1.html" "$2" <<'EOF'
import sys
s = open(sys.argv[1]).read()
t = eval(sys.argv[3])
assert t != s, "variant changed nothing"
open(sys.argv[2], "w").write(t)
EOF
}
# style: inject CSS at the end of <head>.
style() { echo "s.replace('</head>', '<style>$1</style></head>')"; }
# body: inject HTML at the start of <main>.
body() { echo "s.replace('<main class=\"page\">', '<main class=\"page\">$1', 1)"; }

# run <name> <want exit> <text the output must name, or ''> <url> [out dir]
run() {
  local name=$1 want=$2 needle=$3 url=$4 out=${5:-$work/out-$RANDOM} rc=0 log
  log=$(node "$check" --url "$url" --out "$out" 2>&1) || rc=$?
  [ "$rc" = "$want" ] || { echo "$log" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$needle" ] || grep -qF -- "$needle" <<<"$log" || { echo "$log" >&2; fail "$name: output doesn't name '$needle'"; }
  echo "ok - $name"
}

shots="$work/shots"
run "AC-3: the example passes (a link inside a sentence isn't flagged)" 0 "" "file://$site/example.html" "$shots"
for w in 375 768 1280; do
  for t in light dark; do
    f="$shots/$w-$t.png"
    [ -s "$f" ] || fail "AC-4: no screenshot $f"
    [ "$(head -c 8 "$f" | od -An -tx1 | tr -d ' \n')" = 89504e470d0a1a0a ] || fail "AC-4: $f is not a PNG"
  done
done
[ "$(find "$shots" -type f | wc -l)" = 6 ] || fail "AC-4: expected exactly six screenshots"
echo "ok - AC-4: six screenshots, <width>-<theme>.png"

variant noviewport "s.replace('<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />', '')"
run "AC-3: no viewport meta fails" 1 "viewport" "file://$site/noviewport.html"

variant wide "$(body '<div style=\"width:600px;height:10px\"></div>')"
run "AC-3: horizontal scroll fails" 1 "overflow" "file://$site/wide.html"

variant hidden "$(body '<div style=\"width:600px;height:10px\"></div>').replace('</head>', '<style>html,body{overflow-x:hidden}</style></head>')"
run "AC-3: an element past the edge fails even with overflow-x hidden" 1 "overflow" "file://$site/hidden.html"

variant samebg "$(style 'body{background:#ffffff !important}')"
run "AC-3: the same background in both system themes fails" 1 "theme-follows-system" "file://$site/samebg.html"

variant notoggle "s.replace('data-theme-toggle', 'data-x')"
run "AC-3: no theme toggle fails" 1 "theme-toggle" "file://$site/notoggle.html"

cat >"$site/inert.js" <<'EOF'
// A toggle that changes its label but never the theme.
document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-theme-toggle]');
  if (b) b.textContent = 'Theme: changed';
});
EOF
variant inert "s.replace('theme.js', 'inert.js')"
run "AC-3: a toggle that doesn't override the system fails" 1 "theme-toggle" "file://$site/inert.html"

cat >"$site/darkonly.js" <<'EOF'
// A toggle that can switch to dark but never to light: from a dark system it changes nothing.
let dark = false;
document.addEventListener('click', (e) => {
  if (!e.target.closest('[data-theme-toggle]')) return;
  dark = !dark;
  if (dark) document.documentElement.dataset.theme = 'dark';
  else delete document.documentElement.dataset.theme;
});
EOF
variant darkonly "s.replace('theme.js', 'darkonly.js')"
run "AC-3: a toggle that overrides only one way (never to light) fails" 1 "system dark" "file://$site/darkonly.html"

cat >"$site/forget.js" <<'EOF'
// A toggle that switches the theme but never keeps the choice.
const order = ['system', 'light', 'dark'];
let cur = 'system';
document.addEventListener('click', (e) => {
  const b = e.target.closest('[data-theme-toggle]');
  if (!b) return;
  cur = order[(order.indexOf(cur) + 1) % 3];
  if (cur === 'system') delete document.documentElement.dataset.theme;
  else document.documentElement.dataset.theme = cur;
});
EOF
variant forget "s.replace('theme.js', 'forget.js')"
run "AC-3: a choice that doesn't survive a reload fails" 1 "reload" "file://$site/forget.html"

cat >"$site/segmented.js" <<'EOF'
// A segmented control: one button per choice inside a [data-theme-toggle] group, kept in storage.
(function () {
  var root = document.documentElement;
  var saved = null;
  try { saved = localStorage.getItem('theme'); } catch (e) {}
  if (saved === 'light' || saved === 'dark') root.dataset.theme = saved;
  document.addEventListener('click', function (e) {
    var b = e.target.closest('[data-choice]');
    if (!b) return;
    var c = b.getAttribute('data-choice');
    if (c === 'system') delete root.dataset.theme;
    else root.dataset.theme = c;
    try { if (c === 'system') localStorage.removeItem('theme'); else localStorage.setItem('theme', c); } catch (e) {}
  });
})();
EOF
segmented='<div role="group" aria-label="Theme" data-theme-toggle><button class="btn btn-outline" type="button" data-choice="system" style="display:none">Auto</button><button class="btn btn-outline" type="button" data-choice="system">System</button><button class="btn btn-outline" type="button" data-choice="light">Light</button><button class="btn btn-outline" type="button" data-choice="dark">Dark</button></div>'
variant segmented "__import__('re').sub(r'<button[^>]*data-theme-toggle>.*?</button>', '''$segmented''', s, count=1, flags=16).replace('theme.js', 'segmented.js')"
run "AC-3: a segmented theme control (one button per choice, one hidden) passes" 0 "" "file://$site/segmented.html"

variant nomain "s.replace('<main', '<div').replace('</main>', '</div>')"
run "AC-3: no <main> fails" 1 "main" "file://$site/nomain.html"

variant narrow "$(style 'main{max-width:340px !important}')"
run "AC-3: a <main> no wider on desktop fails" 1 "responsive" "file://$site/narrow.html"

variant contrast "$(style '.card p{color:#333333 !important}')"
run "AC-3: hard-coded dark text in dark mode fails" 1 "contrast" "file://$site/contrast.html"

variant smallbtn "$(body '<button style=\"min-height:0;min-width:0;height:20px;padding:0 2px\">x</button>')"
run "AC-3: a control under 44 px fails" 1 "target-size" "file://$site/smallbtn.html"
variant btn40 "$(body '<button style=\"min-height:0;min-width:0;height:40px;width:40px;padding:0\">x</button>')"
run "AC-3: a 40 px button, just under the limit, fails" 1 "target-size" "file://$site/btn40.html"

variant nav "$(body '<nav class=\"tiny\"><a href=\"#a\">A</a> <a href=\"#b\">B</a></nav>').replace('</head>', '<style>nav.tiny a{min-height:0 !important;min-width:0 !important;padding:0 !important;display:inline !important}</style></head>')"
run "AC-3: a row of short nav links fails" 1 "target-size" "file://$site/nav.html"

variant nopress "$(style '*:active{transform:none !important;filter:none !important}')"
run "AC-3: a button with no pressed state fails" 1 "pressed-state" "file://$site/nopress.html"

# Can't run: exit 2, never a pass.
variant throws "s.replace('</body>', '<script>throw new Error(\"boom\")</script></body>')"
run "AC-3: a page that throws can't be judged" 2 "boom" "file://$site/throws.html"
run "AC-3: a page that doesn't load can't be judged" 2 "" "file://$site/missing.html"
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$site" >/dev/null 2>&1 &
server_pid=$!
for _ in $(seq 50); do curl -fsS -o /dev/null "http://127.0.0.1:$port/example.html" 2>/dev/null && break; sleep 0.1; done
run "AC-3: the example passes over http too" 0 "" "http://127.0.0.1:$port/example.html"
run "AC-3: a 404 can't be judged" 2 "404" "http://127.0.0.1:$port/missing.html"
rc=0
log=$(PLAYWRIGHT_BROWSERS_PATH="$work/no-browsers" node "$check" --url "file://$site/example.html" --out "$work/o" 2>&1) || rc=$?
[ "$rc" = 2 ] || { echo "$log" >&2; fail "AC-3: a browser that can't start: expected exit 2, got $rc"; }
echo "ok - AC-3: a browser that can't start can't be judged"
cp "$check" "$work/alone.mjs"
rc=0
log=$(node "$work/alone.mjs" --url "file://$site/example.html" --out "$work/o" 2>&1) || rc=$?
[ "$rc" = 2 ] || { echo "$log" >&2; fail "AC-3: Playwright missing: expected exit 2, got $rc"; }
grep -qi playwright <<<"$log" || fail "AC-3: Playwright missing: output doesn't say so"
echo "ok - AC-3: Playwright missing can't be judged"
rc=0
node "$check" --url "file://$site/example.html" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "AC-3: a missing --out: expected exit 2, got $rc"
echo "ok - AC-3: bad arguments can't be judged"
