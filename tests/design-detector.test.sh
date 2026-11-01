#!/usr/bin/env bash
# tier: slow
# Tests the pinned design detector engine (spec specs/design-detector-in-bootstrap.md, AC-4): the
# engine install/impeccable.pin names, at gstack's READY path, in its own file-scan mode (no browser,
# network or Bun). A planted page reports the AI-slop rule ids; the UI template reports nothing; a
# missing target is exit 1; the binary is the pinned one. A missing engine is exit 2, never a skip
# (CLAUDE.md: a missing tool fails): the bootstrap places it in a cloud session, CI's slow job and a
# session from before this change place it with install/impeccable.sh. Slow tier: it runs a
# third-party binary over fixtures, as a design review does.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
spec="design-detector-in-bootstrap"
# shellcheck disable=SC2016  # the command as the reader types it; $HOME is theirs
place='install/impeccable.sh install/impeccable.pin "$HOME"'

# The pin: the one "<version> <sha256>" line of install/impeccable.pin (its "gstack <commit>" line
# is the bootstrap test's business).
pin="$repo_root/install/impeccable.pin"
[ -f "$pin" ] || { echo "FAIL: $spec AC-4: can't run: no $pin" >&2; exit 2; }
read -r version sum < <(grep -Ev '^(#|gstack |[[:space:]]*$)' "$pin") || true
[[ ${version:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && ${sum:-} =~ ^[0-9a-f]{64}$ ]] \
  || { echo "FAIL: $spec AC-4: can't run: $pin has no '<version> <sha256>' line" >&2; exit 2; }

# The engine, where gstack's probe looks: $IMPECCABLE_HOME, else ~/.impeccable, then
# bin/<version>/impeccable; the pinned version, not the newest, so this proves the pin.
engine="${IMPECCABLE_HOME:-$HOME/.impeccable}/bin/$version/impeccable"
if [ ! -x "$engine" ]; then
  echo "FAIL: $spec AC-4: can't run: no engine at $engine; place the pinned one with: $place" >&2
  exit 2
fi

# AC-4, the missing-engine case: this test, run again with IMPECCABLE_HOME at an empty directory,
# exits 2 and names the command, and never 0.
if [ -z "${DEVSHOP_TEST_INNER:-}" ]; then
  empty=$(mktemp -d)
  rc=0
  out=$(DEVSHOP_TEST_INNER=1 IMPECCABLE_HOME="$empty" bash "$0" 2>&1) || rc=$?
  rm -rf "$empty"
  [ "$rc" = 2 ] || fail "$spec AC-4: with no engine the test exited $rc, want 2: $out"
  grep -qF "$place" <<<"$out" || fail "$spec AC-4: the missing-engine message doesn't name the command that places one: $out"
  echo "ok - $spec AC-4: with no engine the test exits 2 and names install/impeccable.sh"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The binary is the pinned one.
got=$(sha256sum "$engine" | cut -d' ' -f1)
[ "$got" = "$sum" ] || fail "$spec AC-4: $engine has sha256 $got, the pin says $sum"
echo "ok - $spec AC-4: the engine at $engine has the pinned sha256"

# detect <dir> <args...>: runs the engine's file scan from <dir> (never from the repo, so it reads
# no project config), JSON on stdout; prints the exit status last.
detect() {
  local dir=$1 rc=0
  shift
  (cd "$dir" && "$engine" detect --json "$@" 2>"$work/stderr") || rc=$?
  echo "$rc"
}
# ids <json>: the rule ids ("antipattern") in the engine's JSON list, one per line, sorted.
ids() { python3 -I -c 'import json,sys; print("\n".join(sorted({f["antipattern"] for f in json.load(sys.stdin)})))' <<<"$1"; }

# The planted page: a purple-violet gradient hero with white on violet, Inter, a tracked ALL-CAPS
# eyebrow over an oversized h1, nested rounded cards. Exit 2 (primary findings) naming these ids.
mkdir -p "$work/planted"
cp "$repo_root/tests/fixtures/design-detector/planted.html" "$work/planted/"
out=$(detect "$work/planted" planted.html)
rc=${out##*$'\n'}
json=${out%"$rc"}
[ "$rc" = 2 ] || fail "$spec AC-4: the planted page exited $rc, want 2 (findings): $(cat "$work/stderr")"
found=$(ids "$json")
for id in ai-color-palette overused-font hero-eyebrow-chip; do
  grep -qx "$id" <<<"$found" || fail "$spec AC-4: the planted page's findings lack [$id]; got: $(tr '\n' ' ' <<<"$found")"
done
echo "ok - $spec AC-4: the planted page exits 2 with ai-color-palette, overused-font and hero-eyebrow-chip"

# The UI template, as a project would copy it: exit 0, which the engine documents as "no primary
# findings", and an empty list without advisories.
mkdir -p "$work/template"
cp "$repo_root/runtime/templates/ui/example.html" "$repo_root/runtime/templates/ui/base.css" \
  "$repo_root/runtime/templates/ui/theme.js" "$work/template/"
out=$(detect "$work/template" --no-advisory .)
rc=${out##*$'\n'}
json=${out%"$rc"}
[ "$rc" = 0 ] || fail "$spec AC-4: the UI template exited $rc, want 0: $(cat "$work/stderr")"
n=$(python3 -I -c 'import json,sys; print(len(json.load(sys.stdin)))' <<<"$json")
[ "$n" = 0 ] || fail "$spec AC-4: the UI template has $n primary findings, want none: $(ids "$json" | tr '\n' ' ')"
echo "ok - $spec AC-4: the UI template exits 0 with no primary finding"

# A target that doesn't exist: exit 1 (could not scan), never 0.
out=$(detect "$work" no-such-page.html)
rc=${out##*$'\n'}
[ "$rc" = 1 ] || fail "$spec AC-4: a missing target exited $rc, want 1"
echo "ok - $spec AC-4: a missing target exits 1"

echo "PASS: design detector $version"
