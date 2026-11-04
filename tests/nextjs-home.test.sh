#!/usr/bin/env bash
# Tests the Next.js stack home's UI defaults (specs/react-home-ui-defaults.md): its theme file
# (runtime/stacks/nextjs-supabase/globals.css) has the baseline's token rules and passes the token and
# DESIGN.md checks; scripts/ui-tokens.sh, called by one line in the template's check-fast.sh, runs the
# real token check over the project's code and fails or can't run on each known-bad input; place.sh
# places the home's files one by one and never overwrites; shadcn-add.mjs copies components at the
# project's own shadcn version from synthetic sources, with a stub npm. No network, no browser.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
home="$repo_root/runtime/stacks/nextjs-supabase"
ui="$repo_root/runtime/templates/ui"
theme="$home/globals.css"
for f in "$theme" "$home/ui-tokens.sh" "$home/place.sh" "$home/shadcn-add.mjs"; do
  [ -f "$f" ] || fail "missing $f"
done
command -v node >/dev/null || fail "node not found"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# ---- AC-1: the token rules are base.css's; both checks pass on the file ----
python3 - "$theme" "$ui/base.css" <<'EOF' || fail "react-home-ui-defaults AC-1: the token rules aren't base.css's"
import sys
def rules(path):
    s = open(path).read()
    out = []
    for head in (":root {", ":root[data-theme='dark'] {", "@media (prefers-color-scheme: dark) {"):
        i = s.index("\n" + head) + 1
        depth, j = 0, s.index("{", i)
        while True:
            if s[j] == "{": depth += 1
            elif s[j] == "}":
                depth -= 1
                if depth == 0: break
            j += 1
        out.append(s[i:j + 1])
    return out
a, b = rules(sys.argv[1]), rules(sys.argv[2])
for x, y, name in zip(a, b, ("light", "dark", "system dark")):
    if x != y:
        print(f"the {name} rule differs from base.css's", file=sys.stderr); sys.exit(1)
EOF
echo "ok - react-home-ui-defaults AC-1: the three token rules are base.css's, text for text"
out=$(node "$ui/tokens-check.mjs" --theme "$theme" "$theme" 2>&1) || { echo "$out" >&2; fail "react-home-ui-defaults AC-1: tokens-check doesn't pass the theme"; }
echo "ok - react-home-ui-defaults AC-1: tokens-check passes the theme (custom properties only where it reads them)"
out=$(node "$ui/design-md-check.mjs" --theme "$theme" "$repo_root/tests/fixtures/design-md/baseline/DESIGN.md" 2>&1) ||
  { echo "$out" >&2; fail "react-home-ui-defaults AC-1: design-md-check doesn't derive the theme from the baseline DESIGN.md"; }
echo "ok - react-home-ui-defaults AC-1: design-md-check derives the theme from the baseline's DESIGN.md"

# ---- AC-2: imports, the bridge, the dark variant, the base layer ----
python3 - "$theme" "$ui/base.css" <<'EOF' || fail "react-home-ui-defaults AC-2: the theme's shape is wrong"
import re, sys
s = open(sys.argv[1]).read()
base = open(sys.argv[2]).read()
flat = lambda t: re.sub(r"\s+", " ", t).strip()
def bad(msg):
    print(msg, file=sys.stderr); sys.exit(1)
code = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
imports = re.findall(r"^@import ([^;]+);", code, re.M)
if imports[:2] != ["'tailwindcss'", "'tw-animate-css'"] or not code.lstrip().startswith("@import 'tailwindcss';"):
    bad(f"it doesn't open with the two imports: {imports}")
m = re.search(r"@theme inline \{(.*?)\n\}", code, re.S)
if not m: bad("no @theme inline block")
bridge = dict(re.findall(r"^\s*(--[a-z0-9*-]+):\s*([^;]+);", m.group(1), re.M))
root = code[code.index("\n:root {"):]
root = root[:root.index("}")]
colours = [n for n, v in re.findall(r"^\s*--([a-z0-9-]+):\s*([^;]+);", root, re.M)
           if re.fullmatch(r"#[0-9a-fA-F]{3,8}|oklch\([^)]*\)", v.strip())]
want = {f"--color-{c}": f"var(--{c})" for c in colours}
got = {k: v for k, v in bridge.items() if k.startswith("--color-")}
if got != want: bad(f"the colour bridge isn't one line per colour token: extra {set(got)-set(want)}, missing {set(want)-set(got)}")
for k in ("--radius-sm", "--radius-md", "--radius-lg", "--radius-xl"):
    if bridge.get(k) != "var(--radius)": bad(f"{k} isn't var(--radius)")
if bridge.get("--spacing") != "var(--space-1)": bad("--spacing isn't var(--space-1)")
variant = """@custom-variant dark {
  &:where([data-theme='dark'], [data-theme='dark'] *) {
    @slot;
  }
  @media (prefers-color-scheme: dark) {
    &:where(:root:not([data-theme='light']), :root:not([data-theme='light']) *) {
      @slot;
    }
  }
}"""
if flat(variant).replace("( ", "(").replace(" )", ")") not in flat(code).replace("( ", "(").replace(" )", ")"):
    bad("the dark variant isn't the spec's")
layer = code[code.index("@layer base {"):]
if not re.search(r"\[data-slot='button'\],\s*\[data-slot='input'\],\s*\[data-slot='select-trigger'\]\s*\{\s*min-height: var\(--tap\);", layer):
    bad("no 44 px min-height on the button, input and select-trigger slots")
if not re.search(r"\[data-slot='button'\]\s*\{\s*min-width: var\(--tap\);", layer):
    bad("no 44 px min-width on the button slot")
busy = base[base.index("[aria-busy='true'] {"):base.index("/* Forms */")]
busy = busy.replace(":where(button, .btn)", "[data-slot='button']")
if flat(busy) not in flat(layer): bad("the base layer lacks base.css's busy rules for the button slot")
motion = base[base.index("@media (prefers-reduced-motion: reduce) {"):]
if flat(motion) not in flat(layer): bad("the base layer lacks base.css's reduced-motion rule")
EOF
echo "ok - react-home-ui-defaults AC-2: two imports, the bridge per colour token, radius, spacing, the dark variant, the base layer"

# ---- The scratch project: the template's check-fast.sh with the home's line, stubs for the rest ----
p="$work/project"
mkdir -p "$p/scripts" "$p/specs" "$p/app" "$p/components/ui"
"$home/place.sh" "$p" >/dev/null || fail "place.sh couldn't place into an empty project"
cp "$repo_root/runtime/templates/check-fast.sh" "$p/scripts/"
sed -i 's|^THEME_CSS=""|THEME_CSS="app/globals.css"|' "$p/scripts/check-fast.sh"
# shellcheck disable=SC2016  # the line as the project's file holds it
sed -i 's|^# --- Stack parts (from the stack home).*|&\npart scripts/ui-tokens.sh "$THEME_CSS" components/ui|' "$p/scripts/check-fast.sh"
# shellcheck disable=SC2016  # the line as the project's file holds it
grep -q '^part scripts/ui-tokens.sh "$THEME_CSS" components/ui$' "$p/scripts/check-fast.sh" || fail "the stack part line wasn't added"
for s in secret-scan.sh spec-check.py contract-check.py; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"%s/ran"\n' "$s" "$work" >"$p/scripts/$s"
  chmod +x "$p/scripts/$s"
done
cat >"$p/app/page.tsx" <<'TSX'
export default function Home() {
  return <main className="mx-auto max-w-[var(--page-max)] p-4">Hello</main>;
}
TSX
cat >"$p/components/ui/select.tsx" <<'TSX'
export const C = () => <div className="h-[var(--radix-select-trigger-height)]" />;
TSX
printf '# not checked\n' >"$p/README.md"
(cd "$p" && git init -q && git add -A && git commit -qm start)

# tier: run the project's check-fast.sh; prints its exit code; its output is in $work/out.
tier() {
  local rc=0
  rm -f "$work/ran"
  (cd "$p" && scripts/check-fast.sh b4se) >"$work/out" 2>&1 || rc=$?
  echo "$rc"
}
want() { # want <exit> <name> [text the output must hold]
  [ "$got" = "$1" ] || { cat "$work/out" >&2; fail "$2: want exit $1, got $got"; }
  [ -z "${3:-}" ] || grep -qF -- "$3" "$work/out" || { cat "$work/out" >&2; fail "$2: output doesn't hold '$3'"; }
  echo "ok - $2"
}
commit() { (cd "$p" && git add -A && git commit -qm "$1"); }

# ---- AC-3: the fast tier's token part ----
got=$(tier)
want 0 "react-home-ui-defaults AC-3: the tier passes on the home's theme and a page using its tokens" "tokens-check: ok"
grep -qF "1 file(s)" "$work/out" || { cat "$work/out" >&2; fail "react-home-ui-defaults AC-3: the check didn't get exactly the page (theme and library left out)"; }
echo "ok - react-home-ui-defaults AC-3: the theme and components/ui/ are left out, so a Radix runtime variable passes"
printf '.x { color: var(--brand); }\n' >"$p/app/extra.css"
printf 'export const k = "var(--brand-2)";\n' >"$p/app/k.ts"
commit "a page using tokens the theme lacks"
got=$(tier)
want 1 "react-home-ui-defaults AC-3: a page using a token the theme lacks fails the tier" "--brand is not defined"
grep -qF -- "--brand-2 is not defined" "$work/out" || fail "react-home-ui-defaults AC-3: a .ts file wasn't checked"
grep -q '^contract-check.py' "$work/ran" || fail "react-home-ui-defaults AC-3: the other parts didn't run beside the failing token part"
echo "ok - react-home-ui-defaults AC-3: .css and .ts files are checked and the other parts still run"
(cd "$p" && git rm -q app/extra.css app/k.ts && git commit -qm back)
cp "$p/app/globals.css" "$work/globals.keep"
sed -i 's|^  --spacing: var(--space-1);|&\n  --color-chart-1: var(--chart-1);|' "$p/app/globals.css"
got=$(tier)
want 1 "react-home-ui-defaults AC-3: a bridge entry naming a token the theme lacks fails" "--chart-1 is not defined"
cp "$work/globals.keep" "$p/app/globals.css"
python3 - "$p/app/globals.css" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("  --ring: oklch(0.6 0.17 262);", "  --ring: oklch(0.6 0.17 262);\n  --sidebar: oklch(0.98 0 0);", 1)
open(p, "w").write(s)
EOF
got=$(tier)
want 1 "react-home-ui-defaults AC-3: a light-only colour added to :root fails" "light-only-colour: --sidebar"
cp "$work/globals.keep" "$p/app/globals.css"
printf '\n.dark {\n  --background: oklch(0.1 0 0);\n}\n' >>"$p/app/globals.css"
got=$(tier)
want 2 "react-home-ui-defaults AC-3: a .dark block in the theme can't run, never passes" "'.dark' declares custom properties"
cp "$work/globals.keep" "$p/app/globals.css"
mv "$p/scripts/ui/tokens-check.mjs" "$work/"
got=$(tier)
want 2 "react-home-ui-defaults AC-3: a missing tokens-check copy can't run" "no scripts/ui/tokens-check.mjs"
mv "$work/tokens-check.mjs" "$p/scripts/ui/"
mv "$p/app/globals.css" "$work/globals.moved"
got=$(tier)
want 2 "react-home-ui-defaults AC-3: a missing theme can't run" "no theme at app/globals.css"
mv "$work/globals.moved" "$p/app/globals.css"
rc=0
(cd "$p" && scripts/ui-tokens.sh app/globals.css) >"$work/out" 2>&1 || rc=$?
got=$rc
want 2 "react-home-ui-defaults AC-3: a missing argument can't run" "usage"
mv "$p/.git" "$work/dotgit"
got=$(tier)
want 2 "react-home-ui-defaults AC-3: no git repository can't run" "git ls-files failed"
mv "$work/dotgit" "$p/.git"
got=$(tier)
want 0 "react-home-ui-defaults AC-3: back to clean"

# ---- AC-4: with a DESIGN.md, the template's design part derives the home's theme ----
cp "$repo_root/tests/fixtures/design-md/baseline/DESIGN.md" "$p/DESIGN.md"
got=$(tier)
want 0 "react-home-ui-defaults AC-4: the baseline's DESIGN.md derives the home's theme in the tier" "design-md-check: ok"
python3 - "$p/app/globals.css" <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("  --ring: oklch(0.6 0.17 262);", "  --ring: oklch(0.6 0.17 262);\n  --brand: oklch(0.6 0.2 30);", 1)
s = s.replace("  --ring: oklch(0.68 0.14 262);", "  --ring: oklch(0.68 0.14 262);\n    --brand: oklch(0.7 0.2 30);", 2)
open(p, "w").write(s)
EOF
got=$(tier)
want 1 "react-home-ui-defaults AC-4: a colour token DESIGN.md doesn't name fails" "theme-not-in-design: --brand"
cp "$work/globals.keep" "$p/app/globals.css"
rm "$p/DESIGN.md"

# ---- AC-5: place.sh, file by file ----
q="$work/fresh"
mkdir -p "$q"
rc=0
"$home/place.sh" "$q" >"$work/out" 2>&1 || rc=$?
got=$rc
want 0 "react-home-ui-defaults AC-5: place.sh places the six files in an empty project" "placed: app/globals.css"
for f in app/globals.css public/theme.js scripts/ui-tokens.sh scripts/ui/tokens-check.mjs scripts/ui/render-check.mjs scripts/ui/design-md-check.mjs; do
  [ -f "$q/$f" ] || fail "react-home-ui-defaults AC-5: $f wasn't placed"
done
[ -x "$q/scripts/ui-tokens.sh" ] && [ -x "$q/scripts/ui/design-md-check.mjs" ] || fail "react-home-ui-defaults AC-5: a script lost its executable bit"
cmp -s "$q/public/theme.js" "$ui/theme.js" || fail "react-home-ui-defaults AC-5: theme.js isn't the baseline's"
echo "ok - react-home-ui-defaults AC-5: each file at its path, the scripts executable, theme.js the baseline's"
sum() { (cd "$q" && find . -type f -exec sha256sum {} + | sort) ; }
before=$(sum)
rc=0
"$home/place.sh" "$q" >"$work/out" 2>&1 || rc=$?
got=$rc
want 0 "react-home-ui-defaults AC-5: run again, place.sh changes nothing" "same: app/globals.css"
[ "$(sum)" = "$before" ] || fail "react-home-ui-defaults AC-5: the second run changed a file"
rm "$q/public/theme.js"
printf '/* the project own theme */\n' >"$q/app/globals.css"
rc=0
"$home/place.sh" "$q" >"$work/out" 2>&1 || rc=$?
got=$rc
want 1 "react-home-ui-defaults AC-5: a differing file is shown and left, the others placed" "differs: app/globals.css"
[ "$(cat "$q/app/globals.css")" = "/* the project own theme */" ] || fail "react-home-ui-defaults AC-5: the differing file was changed"
[ -f "$q/public/theme.js" ] || fail "react-home-ui-defaults AC-5: the missing file wasn't placed beside a differing one"
grep -q '^+@import .tailwindcss.;' "$work/out" || fail "react-home-ui-defaults AC-5: no diff shown"
rc=0
"$home/place.sh" "$work/nope" >"$work/out" 2>&1 || rc=$?
got=$rc
want 2 "react-home-ui-defaults AC-5: a project that isn't a directory can't run" "not a directory"

# ---- AC-6: shadcn-add.mjs against synthetic sources and a stub npm ----
src="$work/src/v4.9.1"
mkdir -p "$src/ui" "$src/hooks" "$src/lib" "$work/bin"
cat >"$src/ui/dialog.tsx" <<'TSX'
"use client"
import * as React from "react"
import { createPortal } from "react-dom"
import Link from "next/link"
import { Dialog as D } from "radix-ui"
import { X } from "lucide-react"
import { cn } from "cn"
import { Button } from "@/registry/new-york-v4/ui/button"
import { useMobile } from "@/registry/new-york-v4/hooks/use-mobile"
export function Dialog() { return <D.Root className={cn("p-4")}><Button /><X /></D.Root> }
TSX
cat >"$src/ui/button.tsx" <<'TSX'
import { cva } from "class-variance-authority"
import { cn } from "@/registry/new-york-v4/lib/utils"
export function Button() { return <button data-slot="button" className={cn(cva("h-9")())} /> }
TSX
printf 'import * as React from "react"\nexport function useMobile() { return false }\n' >"$src/hooks/use-mobile.ts"
printf 'export { cn } from "cn"\n' >"$src/lib/utils.ts"
cat >"$src/ui/odd.tsx" <<'TSX'
import { x } from "@/registry/new-york-v4/blocks/x"
TSX
printf 'import { x } from "@/registry/new-york-v4/ui/../../escape"\n' >"$src/ui/climb.tsx"
printf 'import { x } from "@/registry/new-york-v4/hooks/../x"\n' >"$src/ui/climbhook.tsx"
printf 'import { x } from "--registry=example.com"\n' >"$src/ui/flag.tsx"
printf 'import { x } from "./local"\n' >"$src/ui/relative.tsx"
# The stub npm records its arguments and exits with npm.rc's number.
# shellcheck disable=SC2016  # the stub's source
printf '#!/usr/bin/env bash\necho "npm $*" >>"%s/npm-ran"\nexit "$(cat "%s/npm.rc")"\n' "$work" "$work" >"$work/bin/npm"
chmod +x "$work/bin/npm"
export SHADCN_SOURCE="$work/src/v{version}"
s="$work/app"
fresh_app() { # fresh_app <shadcn version or ''>
  rm -rf "$s"
  mkdir -p "$s"
  if [ -n "$1" ]; then
    printf '{\n  "dependencies": { "next": "16.2.4", "react": "19.2.5", "radix-ui": "1.8.1" },\n  "devDependencies": { "shadcn": "%s" }\n}\n' "$1" >"$s/package.json"
  else
    printf '{\n  "dependencies": { "next": "16.2.4" }\n}\n' >"$s/package.json"
  fi
  echo 0 >"$work/npm.rc"
  rm -f "$work/npm-ran"
}
add() { # add <component>...: runs it in $s with the stub npm; prints the exit code
  local rc=0
  PATH="$work/bin:$PATH" node "$home/shadcn-add.mjs" "$s" "$@" >"$work/out" 2>&1 || rc=$?
  echo "$rc"
}
fresh_app 4.9.1
got=$(add dialog)
want 0 "react-home-ui-defaults AC-6: a component and what it imports are added at the project's version" "from shadcn@4.9.1"
for f in components/ui/dialog.tsx components/ui/button.tsx hooks/use-mobile.ts lib/utils.ts; do
  [ -f "$s/$f" ] || { cat "$work/out" >&2; fail "react-home-ui-defaults AC-6: $f wasn't copied"; }
done
{ grep -q 'from "@/components/ui/button"' "$s/components/ui/dialog.tsx" &&
  grep -q 'from "@/hooks/use-mobile"' "$s/components/ui/dialog.tsx" &&
  grep -q 'import { cn } from "@/lib/utils"' "$s/components/ui/dialog.tsx" &&
  grep -q 'import { cn } from "@/lib/utils"' "$s/components/ui/button.tsx"; } ||
  fail "react-home-ui-defaults AC-6: the imports weren't rewritten: $(cat "$s/components/ui/dialog.tsx")"
grep -q 'export { cn } from "cn"' "$s/lib/utils.ts" || fail "react-home-ui-defaults AC-6: lib/utils.ts was rewritten into itself"
! grep -q 'registry' "$s/components/ui/dialog.tsx" "$s/components/ui/button.tsx" || fail "react-home-ui-defaults AC-6: a registry import is left"
echo "ok - react-home-ui-defaults AC-6: imports rewritten to @/components/ui/, @/hooks/ and @/lib/utils"
[ "$(cat "$work/npm-ran")" = "npm install --save-exact --no-audit --no-fund -- class-variance-authority cn lucide-react" ] ||
  fail "react-home-ui-defaults AC-6: npm wasn't asked for exactly the missing packages, once, exact: $(cat "$work/npm-ran")"
echo "ok - react-home-ui-defaults AC-6: the missing packages installed once with --save-exact; radix-ui (present), react-dom and next/link (the app's own) not"
printf '// the project own button\n' >"$s/components/ui/button.tsx"
rm "$s/components/ui/dialog.tsx"
rm -f "$work/npm-ran"
got=$(add dialog)
want 1 "react-home-ui-defaults AC-6: a differing file is shown and nothing is written" "differs: components/ui/button.tsx"
[ ! -e "$s/components/ui/dialog.tsx" ] || fail "react-home-ui-defaults AC-6: a file was written beside a differing one"
[ ! -e "$work/npm-ran" ] || fail "react-home-ui-defaults AC-6: npm ran beside a differing file"
echo "ok - react-home-ui-defaults AC-6: no file written and no install beside a differing file"
fresh_app ''
rm "$s/package.json"
got=$(add button)
want 2 "react-home-ui-defaults AC-6: no package.json can't run" "package.json"
fresh_app ''
got=$(add button)
want 2 "react-home-ui-defaults AC-6: no shadcn in package.json can't run" "has no \`shadcn\`"
fresh_app '^4.9.1'
got=$(add button)
want 2 "react-home-ui-defaults AC-6: a range in place of a version can't run" "not an exact version"
fresh_app 4.9.2
got=$(add button)
want 2 "react-home-ui-defaults AC-6: a version the source lacks can't run" "has no component 'button'"
fresh_app 4.9.1
got=$(add nope)
want 2 "react-home-ui-defaults AC-6: a component the source lacks can't run" "has no component 'nope'"
got=$(add odd)
want 2 "react-home-ui-defaults AC-6: an @/ import it doesn't know can't run" "doesn't know how to place"
got=$(add relative)
want 2 "react-home-ui-defaults AC-6: a relative import can't run" "doesn't know how to place"
got=$(add climb)
want 2 "react-home-ui-defaults AC-6: a component name with '..' from a downloaded file can't run" "isn't a component name"
got=$(add climbhook)
want 2 "react-home-ui-defaults AC-6: a hook name with '..' can't run" "isn't a hook name"
got=$(add flag)
want 2 "react-home-ui-defaults AC-6: an import that would be an npm option can't run" "isn't an npm package name"
[ ! -e "$s/components" ] || fail "react-home-ui-defaults AC-6: files written before a can't-run"
echo 1 >"$work/npm.rc"
got=$(add button)
want 2 "react-home-ui-defaults AC-6: a failed install can't run, and writes nothing" "npm install failed"
[ ! -e "$s/components" ] || fail "react-home-ui-defaults AC-6: files written though the install failed"

echo "PASS: the Next.js home's theme, fast-tier part, place.sh and shadcn-add.mjs"
