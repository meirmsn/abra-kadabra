#!/usr/bin/env bash
# Tests runtime/templates/ui/design-md-check.mjs (spec specs/design-md-check.md, AC-1 to AC-4): a
# project's DESIGN.md has the shape the devshop relies on (front matter with colors in light and
# dark, typography, spacing, rounded; a Decisions section) and its theme CSS is derived from it
# under the baseline's token names, both ways. Feeds it a known-bad DESIGN.md or theme per rule,
# the can't-judge inputs, then the two committed fixture pairs (the baseline's own base.css among
# them).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
ui="$repo_root/runtime/templates/ui"
check="${DESIGN_MD_CHECK:-$ui/design-md-check.mjs}" # the override is for the mutant run
fixtures="$repo_root/tests/fixtures/design-md"
spec="design-md-check"
[ -f "$check" ] || fail "missing $check"
[ -x "$check" ] || fail "$check is not executable (the fast tier runs it as a part)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A good pair, small: the front matter's four groups and the theme derived from them.
COLORS='  background: "#ffffff"
  foreground: "#111111"
  card: "#f4f4f4"
  card-foreground: "{colors.foreground}"
  primary: "oklch(0.45 0.2 260)"
  primary-foreground: "#ffffff"
  muted-foreground: "#555555"
  border: "#dddddd"
  dark-background: "#111111"
  dark-foreground: "#eeeeee"
  dark-card: "#1c1c1c"
  dark-card-foreground: "{colors.dark-foreground}"
  dark-primary: "oklch(0.8 0.1 260)"
  dark-primary-foreground: "#111111"
  dark-muted-foreground: "#aaaaaa"
  dark-border: "#333333"'
TYPOGRAPHY='  display:
    fontFamily: "'"'"'Instrument Serif'"'"', Georgia, serif"
    fontWeight: 400
  body:
    fontFamily: "system-ui, sans-serif"
    fontSize: 1rem
  mono:
    fontFamily: "ui-monospace, monospace"'
SPACING='  "1": 0.25rem
  "4": 1rem'
ROUNDED='  default: 0.5rem'
BODY='
## Overview

A fixture.

## Decisions

- 2026-11-01: the test'"'"'s good file.'
# design <file> [colors] [typography] [spacing] [rounded] [body]: a DESIGN.md from the parts; a
# part given as OMIT leaves its group out.
design() {
  {
    printf -- '---\n# gstack: design-md-format=spec\nname: Test\n'
    printf 'description: A test file.\n'
    group colors "${2-$COLORS}"
    group typography "${3-$TYPOGRAPHY}"
    group spacing "${4-$SPACING}"
    group rounded "${5-$ROUNDED}"
    printf -- '---\n%s\n' "${6-$BODY}"
  } >"$1"
}
group() { [ "$2" = OMIT ] || printf '%s:\n%s\n' "$1" "$2"; }
LIGHT='--background: #ffffff; --foreground: #111111; --card: #f4f4f4; --card-foreground: var(--foreground); --primary: oklch(0.45 0.2 260); --primary-foreground: #ffffff; --muted-foreground: #555555; --border: #dddddd; --shadow: 0 1px 2px oklch(0 0 0 / 10%); --radius: 0.5rem; --font-display: "Instrument Serif", Georgia, serif; --font-sans: system-ui, sans-serif; --font-mono: ui-monospace, monospace; --font-weight-display: 400; --space-1: 0.25rem; --space-4: 1rem; --tap: 44px;'
DARK='--background: #111111; --foreground: #eeeeee; --card: #1c1c1c; --card-foreground: var(--foreground); --primary: oklch(0.8 0.1 260); --primary-foreground: #111111; --muted-foreground: #aaaaaa; --border: #333333;'
# theme <file> <light decls> <dark decls> [extra css]: a theme of the required shape.
theme() {
  cat >"$1" <<EOT
/* a comment that mentions :root { --ghost: red; } is ignored */
:root {
  color-scheme: light;
  $2
}
:root[data-theme='dark'] {
  $3
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme='light']) {
    $3
  }
}
${4:-}
EOT
}

# run <name> <want exit> <text the output must name, or ''> <args...>
run() {
  local name=$1 want=$2 needle=$3 rc=0 out
  shift 3
  out=$(node "$check" "$@" 2>&1) || rc=$?
  [ "$rc" = "$want" ] || { echo "$out" >&2; fail "$spec $name: expected exit $want, got $rc"; }
  [ -z "$needle" ] || grep -qF -- "$needle" <<<"$out" || { echo "$out" >&2; fail "$spec $name: output doesn't name '$needle'"; }
  echo "ok - $spec $name"
}
# bad <name> <needle> <design args...>: a DESIGN.md from the parts that must exit 1 naming <needle>.
bad() {
  local name=$1 needle=$2
  shift 2
  design "$work/bad.md" "$@"
  run "$name" 1 "$needle" --theme "$work/good.css" "$work/bad.md"
}

design "$work/good.md"
theme "$work/good.css" "$LIGHT" "$DARK"
run "AC-4: the good pair passes" 0 "design-md-check: ok" --theme "$work/good.css" "$work/good.md"

# AC-1: the shape, rule by rule. Each known-bad file names the rule and the key.
bad "AC-1: a duplicate key is a finding" "duplicate-key" "$COLORS
  border: \"#dddddd\""
bad "AC-1: a reference to nothing is a finding" "bad-reference" "${COLORS/\{colors.foreground\}/\{colors.nothing\}}"
bad "AC-1: a token group missing is a finding" "missing-group" "$COLORS" "$TYPOGRAPHY" "$SPACING" OMIT
bad "AC-1: a token group that isn't a mapping is a finding" "not-a-mapping" "$COLORS" "$TYPOGRAPHY" "  - 1rem"
bad "AC-1: a bad key is a finding" "bad-key" "$COLORS
  Card_Two: \"#ffffff\"
  dark-Card_Two: \"#000000\""
bad "AC-1: a colour without its dark value is a finding" "colour-without-dark" "$COLORS
  accent: \"#336699\""
bad "AC-1: a dark value without its light is a finding" "dark-without-light" "$COLORS
  dark-accent: \"#336699\""
bad "AC-1: a value that isn't hex or oklch() is a finding" "not-a-colour" "${COLORS/\"#dddddd\"/\"rgb(221 221 221)\"}"
bad "AC-1: a required colour missing is a finding" "missing-colour" "${COLORS/  border: \"#dddddd\"/}"
bad "AC-1: no typography.body.fontFamily is a finding" "missing-font" "$COLORS" "${TYPOGRAPHY/    fontFamily: \"system-ui, sans-serif\"/}"
bad "AC-1: an empty fontFamily is a finding" "empty-font" "$COLORS" "${TYPOGRAPHY/\"ui-monospace, monospace\"/\"\"}"
bad "AC-1: a role named sans is a finding" "bad-key" "$COLORS" "$TYPOGRAPHY
  sans:
    fontFamily: \"system-ui, sans-serif\""
bad "AC-1: an empty spacing is a finding" "empty-group" "$COLORS" "$TYPOGRAPHY" "  # nothing"
bad "AC-1: a spacing value that isn't a length is a finding" "not-a-length" "$COLORS" "$TYPOGRAPHY" "${SPACING/1rem/1 rem}"
bad "AC-1: a rounded value that isn't a length is a finding" "not-a-length" "$COLORS" "$TYPOGRAPHY" "$SPACING" "  default: round"
bad "AC-1: no rounded.default is a finding" "missing-default" "$COLORS" "$TYPOGRAPHY" "$SPACING" "  sm: 0.25rem"
bad "AC-1: no Decisions section is a finding" "no-decisions" "$COLORS" "$TYPOGRAPHY" "$SPACING" "$ROUNDED" "
## Overview

No decisions here."
bad "AC-1: an empty Decisions section is a finding" "no-decisions" "$COLORS" "$TYPOGRAPHY" "$SPACING" "$ROUNDED" "
## Decisions

## Overview

Text."
bad "AC-1: a Decisions heading inside a code fence doesn't count" "no-decisions" "$COLORS" "$TYPOGRAPHY" "$SPACING" "$ROUNDED" "
## Overview

\`\`\`md
## Decisions
- not one
\`\`\`"

# AC-2: the derivation, both ways.
theme "$work/missing.css" "${LIGHT/--space-4: 1rem;/}" "$DARK"
run "AC-2: a token the theme lacks is a finding" 1 "theme-missing-token" --theme "$work/missing.css" "$work/good.md"
grep -q -- "--space-4" <<<"$(node "$check" --theme "$work/missing.css" "$work/good.md" 2>&1)" || fail "$spec AC-2: the missing token isn't named"
theme "$work/light.css" "${LIGHT/--border: #dddddd;/--border: #dddddc;}" "$DARK"
run "AC-2: a light value that differs is a finding" 1 "theme-differs" --theme "$work/light.css" "$work/good.md"
theme "$work/dark.css" "$LIGHT" "${DARK/--border: #333333;/--border: #333334;}"
run "AC-2: a dark value that differs in both dark rules is a finding" 1 "theme-differs" --theme "$work/dark.css" "$work/good.md"
cat >"$work/onedark.css" <<EOT
:root { $LIGHT }
:root[data-theme="dark"] { $DARK }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { ${DARK/--border: #333333;/--border: #333334;} }
}
EOT
run "AC-2: a dark value that differs in one dark rule is a finding" 1 "system-dark" --theme "$work/onedark.css" "$work/good.md"
theme "$work/sans.css" "${LIGHT/--font-sans: system-ui, sans-serif;/--font-sans: Inter, sans-serif;}" "$DARK"
run "AC-2: a body family that differs from --font-sans is a finding" 1 "--font-sans" --theme "$work/sans.css" "$work/good.md"
theme "$work/mono.css" "${LIGHT/--font-mono: ui-monospace, monospace;/--font-mono: Menlo, monospace;}" "$DARK"
run "AC-2: a mono family that differs from --font-mono is a finding" 1 "--font-mono" --theme "$work/mono.css" "$work/good.md"
theme "$work/display.css" "${LIGHT/Georgia, serif;/serif;}" "$DARK"
run "AC-2: a role's family that differs from --font-<role> is a finding" 1 "--font-display" --theme "$work/display.css" "$work/good.md"
theme "$work/space.css" "${LIGHT/--space-4: 1rem;/--space-4: 1.25rem;}" "$DARK"
run "AC-2: a spacing step that differs is a finding" 1 "--space-4" --theme "$work/space.css" "$work/good.md"
theme "$work/radius.css" "${LIGHT/--radius: 0.5rem;/--radius: 0.75rem;}" "$DARK"
run "AC-2: a radius that differs is a finding" 1 "--radius" --theme "$work/radius.css" "$work/good.md"
theme "$work/hex.css" "$LIGHT --extra: #123456;" "$DARK --extra: #654321;"
run "AC-2: a literal hex colour the front matter doesn't name is a finding" 1 "theme-not-in-design" --theme "$work/hex.css" "$work/good.md"
theme "$work/oklch.css" "$LIGHT --extra: oklch(0.5 0.1 100);" "$DARK --extra: oklch(0.7 0.1 100);"
run "AC-2: a literal oklch colour the front matter doesn't name is a finding" 1 "--extra" --theme "$work/oklch.css" "$work/good.md"
theme "$work/rgb.css" "$LIGHT --extra: rgb(1 2 3);" "$DARK --extra: rgb(3 2 1);"
run "AC-2: a literal rgb() colour the front matter doesn't name is a finding" 1 "--extra" --theme "$work/rgb.css" "$work/good.md"
theme "$work/mix.css" "$LIGHT --extra: color-mix(in oklch, red, blue);" "$DARK --extra: color-mix(in oklch, red, white);"
run "AC-2: a color-mix() the front matter doesn't name is a finding" 1 "--extra" --theme "$work/mix.css" "$work/good.md"
theme "$work/named.css" "$LIGHT --extra: white;" "$DARK --extra: black;"
run "AC-2: a named colour the front matter doesn't name is a finding" 1 "--extra" --theme "$work/named.css" "$work/good.md"
theme "$work/darkonly.css" "$LIGHT" "$DARK --extra: #654321;"
run "AC-2: a dark-rule colour the front matter doesn't name is a finding" 1 "--extra" --theme "$work/darkonly.css" "$work/good.md"
theme "$work/space2.css" "$LIGHT --space-2: 0.5rem;" "$DARK"
run "AC-2: a --space-* token the front matter doesn't name is a finding" 1 "--space-2" --theme "$work/space2.css" "$work/good.md"
theme "$work/radius2.css" "$LIGHT --radius-sm: 0.25rem;" "$DARK"
run "AC-2: a --radius* token the front matter doesn't name is a finding" 1 "--radius-sm" --theme "$work/radius2.css" "$work/good.md"
theme "$work/font2.css" "$LIGHT --font-label: Inter, sans-serif;" "$DARK"
run "AC-2: a --font-* family list the front matter doesn't name is a finding" 1 "--font-label" --theme "$work/font2.css" "$work/good.md"
theme "$work/font3.css" "$LIGHT --font-heading: 'Instrument Serif';" "$DARK"
run "AC-2: a quoted single family under --font-* is a family list too" 1 "--font-heading" --theme "$work/font3.css" "$work/good.md"
# Values match through var() aliases, {path} references, whitespace, quote style and case; a
# --font-* weight or size is not a family list (the good pair holds --font-weight-display: 400).
theme "$work/loose.css" "${LIGHT/--primary: oklch(0.45 0.2 260);/--primary:   OKLCH( 0.45  0.2  260 );}" "$DARK"
sed -i "s/--font-display: \"Instrument Serif\", Georgia, serif;/--font-display: 'Instrument Serif',Georgia,  serif;/" "$work/loose.css"
grep -q "'Instrument Serif',Georgia" "$work/loose.css" || fail "$spec AC-2: the loose theme wasn't written"
run "AC-2: values match through case, whitespace and quote style; a --font-* weight is no finding" 0 "" --theme "$work/loose.css" "$work/good.md"
sed -i 's/--font-display: "Instrument Serif", Georgia, serif;/--font-display: Instrument Serif, Georgia, serif;/' "$work/good.css"
run "AC-2: a bare family name matches its quoted spelling" 0 "" --theme "$work/good.css" "$work/good.md"
theme "$work/good.css" "$LIGHT" "$DARK"
theme "$work/alias.css" "${LIGHT/--card-foreground: var(--foreground);/--card-foreground: #111111;}" "$DARK"
run "AC-2: a {path} reference matches the literal it resolves to" 0 "" --theme "$work/alias.css" "$work/good.md"
theme "$work/half.css" "${LIGHT/--primary: oklch(0.45 0.2 260);/--primary: oklch(0.450 0.2 260);}" "$DARK"
run "AC-2: equality is textual: 0.450 against 0.45 differs" 1 "theme-differs" --theme "$work/half.css" "$work/good.md"

# AC-3: can't judge, never a pass.
run "AC-3: no arguments can't be judged" 2 "usage"
run "AC-3: no --theme can't be judged" 2 "usage" "$work/good.md"
run "AC-3: an empty --theme can't be judged" 2 "names no file" --theme "" "$work/good.md"
run "AC-3: two DESIGN.md paths can't be judged" 2 "usage" --theme "$work/good.css" "$work/good.md" "$work/good.md"
run "AC-3: a missing DESIGN.md can't be judged" 2 "missing.md" --theme "$work/good.css" "$work/missing.md"
run "AC-3: a missing theme can't be judged" 2 "nofile.css" --theme "$work/nofile.css" "$work/good.md"
printf '# Design\n\n## Colour\n\n| Token | Light |\n| --- | --- |\n' >"$work/prose.md"
run "AC-3: a DESIGN.md with no front matter can't be judged" 2 "front matter" --theme "$work/good.css" "$work/prose.md"
{ printf 'name: Prose\ncolors:\n  background: "#ffffff"\n---\n'; printf '%s\n' "$BODY"; } >"$work/noopen.md"
run "AC-3: a file that doesn't open with --- can't be judged even when a --- line follows" 2 "open with a --- line" \
  --theme "$work/good.css" "$work/noopen.md"
design "$work/open.md"
sed -i '0,/^---$/! {/^---$/d}' "$work/open.md"
[ "$(grep -c '^---$' "$work/open.md")" = 1 ] || fail "$spec AC-3: the unclosed file wasn't written"
run "AC-3: front matter with no closing --- can't be judged" 2 "closing" --theme "$work/good.css" "$work/open.md"
design "$work/flow.md" "${COLORS/  border: \"#dddddd\"/  border: {light: \"#dddddd\"}}"
run "AC-3: a flow mapping can't be judged" 2 "flow" --theme "$work/good.css" "$work/flow.md"
design "$work/anchor.md" "${COLORS/\"#dddddd\"/&b \"#dddddd\"}"
run "AC-3: an anchor can't be judged" 2 "anchor" --theme "$work/good.css" "$work/anchor.md"
design "$work/tab.md" "$(printf '\t%s' "${COLORS#  }")"
run "AC-3: a tab indent can't be judged" 2 "tab" --theme "$work/good.css" "$work/tab.md"
printf ':root { %s }\n' "$LIGHT" >"$work/nodark.css"
run "AC-3: a theme without the dark rules can't be judged" 2 "dark" --theme "$work/nodark.css" "$work/good.md"
printf '.card { color: red; }\n' >"$work/noroot.css"
run "AC-3: a theme without :root can't be judged" 2 ":root" --theme "$work/noroot.css" "$work/good.md"
theme "$work/shape.css" "$LIGHT" "$DARK" '.card { --card-gap: 1rem; }'
run "AC-3: a custom property in another block can't be judged" 2 ".card" --theme "$work/shape.css" "$work/good.md"
# Read, not can't judge: a byte-order mark, CRLF endings, a trailing comment, a block scalar.
{ printf '\xef\xbb\xbf'; sed 's/$/\r/' "$work/good.md"; } >"$work/bom.md"
run "AC-3: a BOM and CRLF endings are read" 0 "" --theme "$work/good.css" "$work/bom.md"
design "$work/comment.md" "${COLORS/\"#dddddd\"/\"#dddddd\"   # the edges}"
sed -i 's/^description: A test file.$/description: >\n  A test file, folded\n  over two lines./' "$work/comment.md"
grep -q '^description: >$' "$work/comment.md" || fail "$spec AC-3: the block scalar wasn't written"
run "AC-3: a trailing comment and a > block scalar are read" 0 "" --theme "$work/good.css" "$work/comment.md"

# AC-4: the committed fixtures: the baseline's own base.css, and the ledger pair.
run "AC-4: the baseline fixture passes against base.css" 0 "design-md-check: ok" \
  --theme "$ui/base.css" "$fixtures/baseline/DESIGN.md"
run "AC-4: the ledger fixture passes against its theme" 0 "design-md-check: ok" \
  --theme "$fixtures/ledger/theme.css" "$fixtures/ledger/DESIGN.md"
