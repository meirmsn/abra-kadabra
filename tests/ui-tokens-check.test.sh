#!/usr/bin/env bash
# Tests runtime/templates/ui/tokens-check.mjs (spec specs/ui-baseline.md, AC-1 and AC-2; L-78): every
# var(--name) a page uses is defined by the theme for light and dark, the two dark rules agree, and
# each contrast pair reaches 4.5:1 in both themes. Feeds it each known-bad theme or page, then the
# real baseline (base.css, theme.js, example.html).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
ui="$repo_root/runtime/templates/ui"
check="$ui/tokens-check.mjs"
[ -f "$check" ] || fail "missing $check"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# theme <file> <light decls> <dark decls> [extra css]: a theme of the required shape.
theme() {
  cat >"$1" <<EOF
/* a comment that mentions :root { --ghost: red; } is ignored */
:root {
  $2
}
:root[data-theme="dark"] {
  $3
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    $3
  }
}
${4:-}
EOF
}
LIGHT='--background: #ffffff; --foreground: #111111; --primary: oklch(0.45 0.2 260); --primary-foreground: #ffffff; --muted-foreground: #555555; --radius: 0.5rem;'
DARK='--background: #111111; --foreground: #eeeeee; --primary: oklch(0.8 0.1 260); --primary-foreground: #111111; --muted-foreground: #aaaaaa;'

# run <name> <want exit> <text the output must name, or ''> <args...>
run() {
  local name=$1 want=$2 needle=$3 rc=0 out
  shift 3
  out=$(node "$check" "$@" 2>&1) || rc=$?
  [ "$rc" = "$want" ] || { echo "$out" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$needle" ] || grep -qF -- "$needle" <<<"$out" || { echo "$out" >&2; fail "$name: output doesn't name '$needle'"; }
  echo "ok - $name"
}

page="$work/page.html"
printf '<p style="color: var(--foreground); border-radius: var(--radius)">hi</p>\n' >"$page"

theme "$work/good.css" "$LIGHT" "$DARK"
run "AC-1: a good theme and page pass" 0 "" --theme "$work/good.css" "$page"

printf '<p style="color: var(--nope, red)">x</p>\n' >"$work/undef.html"
run "AC-1: an undefined token fails, fallback or not" 1 "--nope" --theme "$work/good.css" "$work/undef.html"

# shellcheck disable=SC2016 # literal backticks: TS source
printf 'const s = `<p style="color: var(--ghost)">`;\n' >"$work/page.ts"
run "AC-1: tokens in any file type are scanned; a comment doesn't define one" 1 "--ghost" \
  --theme "$work/good.css" "$work/page.ts"

# shellcheck disable=SC2016 # literal ${name}: TS source
printf 'const s = `color: var(--${name})`;\n' >"$work/dyn.ts"
run "AC-1: a var() with no literal name fails" 1 "no literal name" --theme "$work/good.css" "$work/dyn.ts"
# shellcheck disable=SC2016 # literal ${tone}: TS source
printf 'const s = `color: var(--primary-${tone})`;\n' >"$work/dyn2.ts"
run "AC-1: a var() whose name is partly built at runtime fails" 1 "no literal name" --theme "$work/good.css" "$work/dyn2.ts"

theme "$work/lightonly.css" "$LIGHT --accent: #336699;" "$DARK"
run "AC-1: a colour defined for light but not dark fails" 1 "--accent" --theme "$work/lightonly.css" "$page"

theme "$work/darkonly.css" "$LIGHT" "$DARK --extra: #123456;"
run "AC-1: a token defined only for dark fails" 1 "--extra" --theme "$work/darkonly.css" "$page"

cat >"$work/differ.css" <<EOF
:root { $LIGHT }
:root[data-theme="dark"] { $DARK }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { ${DARK/--foreground: #eeeeee;/--foreground: #dddddd;} }
}
EOF
run "AC-1: the two dark rules differing fails" 1 "--foreground" --theme "$work/differ.css" "$page"

theme "$work/lowc.css" "${LIGHT/--muted-foreground: #555555;/--muted-foreground: #bbbbbb;}" "$DARK"
run "AC-1: a low-contrast pair fails" 1 "--muted-foreground" --theme "$work/lowc.css" "$page"

theme "$work/lowdark.css" "$LIGHT" "${DARK/--primary-foreground: #111111;/--primary-foreground: #eeeeee;}"
run "AC-1: a low-contrast pair in dark only fails" 1 "dark" --theme "$work/lowdark.css" "$page"

theme "$work/viavar.css" "${LIGHT/--primary-foreground: #ffffff;/--primary-foreground: var(--primary);}" "$DARK"
run "AC-1: a pair reached through var() is resolved and judged" 1 "--primary-foreground" \
  --theme "$work/viavar.css" "$page"

run "AC-1: a missing file can't be judged" 2 "" --theme "$work/good.css" "$work/missing.html"
run "AC-1: a missing theme can't be judged" 2 "" --theme "$work/missing.css" "$page"
printf ':root { %s }\n' "$LIGHT" >"$work/nodark.css"
run "AC-1: a theme without the dark rules can't be judged" 2 "dark" --theme "$work/nodark.css" "$page"
printf '/* :root { --x: 1 } */\n.card { color: red; }\n' >"$work/noroot.css"
run "AC-1: a theme without :root can't be judged" 2 ":root" --theme "$work/noroot.css" "$page"
theme "$work/shape.css" "$LIGHT" "$DARK" '.card { --card-gap: 1rem; }'
run "AC-1: a custom property in another block can't be judged" 2 ".card" --theme "$work/shape.css" "$page"
theme "$work/alpha.css" "${LIGHT/--foreground: #111111;/--foreground: oklch(0.2 0 0 \/ 80%);}" "$DARK"
run "AC-1: alpha in a contrast pair can't be judged" 2 "alpha" --theme "$work/alpha.css" "$page"
theme "$work/hexalpha.css" "${LIGHT/--foreground: #111111;/--foreground: #11111180;}" "$DARK"
run "AC-1: hex alpha in a contrast pair can't be judged" 2 "alpha" --theme "$work/hexalpha.css" "$page"
theme "$work/parse.css" "${LIGHT/--foreground: #111111;/--foreground: color-mix(in srgb, red, blue);}" "$DARK"
run "AC-1: a colour it can't parse in a pair can't be judged" 2 "--foreground" --theme "$work/parse.css" "$page"
run "AC-1: no arguments can't be judged" 2 ""

# AC-2: the real baseline passes, and the example uses every primitive.
run "AC-2: base.css passes with example.html and theme.js" 0 "" \
  --theme "$ui/base.css" "$ui/example.html" "$ui/theme.js"
for sel in 'class="page"' '<header' 'data-theme-toggle' 'class="card' '<ul' 'btn-primary' 'btn-secondary' \
  'btn-destructive' 'disabled' 'aria-busy="true"' '<label' 'type="text"' '<select' 'type="checkbox"' '<textarea'; do
  grep -qF -- "$sel" "$ui/example.html" || fail "AC-2: example.html doesn't use $sel"
done
tr '\n' ' ' <"$ui/example.html" | grep -qE '<p>[^<]*<a href' || fail "AC-2: example.html has no link inside a sentence"
echo "ok - AC-2: example.html uses every primitive"
