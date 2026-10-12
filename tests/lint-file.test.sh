#!/usr/bin/env bash
# shellcheck disable=SC2016  # the test scripts it writes hold literal $1
# Tests scripts/lint-file.sh, this repo's per-file lint (the devshop's per-edit nudge runs it on each
# file Claude edits): Prettier fixes formatting in place (--write, pinned version), shellcheck reports
# on shell scripts, ignored paths are left alone, and a missing tool exits 2 (never a pass).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
[ -x "$repo_root/node_modules/.bin/prettier" ] || fail "prettier not installed (run npm ci)"
command -v "${SHELLCHECK:-shellcheck}" >/dev/null || fail "shellcheck not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
# A scratch copy of the repo's lint setup (never the real tree, L-41).
r="$work/r"
new_repo "$r"
mkdir -p "$r/scripts" "$r/kit/notes/revamp/spikes/x" "$r/src"
cp "$repo_root/scripts/lint-file.sh" "$r/scripts/"
cp "$repo_root/package.json" "$repo_root/.prettierrc" "$repo_root/.prettierignore" "$r/"
ln -s "$repo_root/node_modules" "$r/node_modules"

# lint <file> [env assignments...]: run lint-file.sh on <file> from the repo root; echo the exit code.
lint() {
  local f=$1 rc=0
  shift
  (cd "$r" && env "$@" scripts/lint-file.sh "$f") >"$work/out" 2>&1 || rc=$?
  echo "$rc"
}

printf '# Title\n\n\n*  one\n*  two\n' >"$r/doc.md"
[ "$(lint doc.md)" = 0 ] || { cat "$work/out" >&2; fail "misformatted markdown: want 0 after fixing"; }
[ "$(cat "$r/doc.md")" = "$(printf '# Title\n\n- one\n- two')" ] || fail "prettier didn't fix doc.md: $(cat "$r/doc.md")"
echo "ok - formatting is fixed in place (prettier --write, pinned version)"

printf '#!/usr/bin/env bash\necho $1\n' >"$r/src/bad.sh"
{ [ "$(lint src/bad.sh)" = 1 ] && grep -q SC2086 "$work/out"; } || { cat "$work/out" >&2; fail "shellcheck finding: want 1 with SC2086"; }
printf '#!/usr/bin/env bash\necho hi\n' >"$r/src/noext"
printf '#!/usr/bin/env bash\necho "$1"\n' >"$r/src/good.sh"
[ "$(lint src/good.sh)" = 0 ] || { cat "$work/out" >&2; fail "clean script: want 0"; }
[ "$(lint src/noext)" = 0 ] || { cat "$work/out" >&2; fail "clean script found by shebang: want 0"; }
echo "ok - shellcheck findings are reported (1), clean scripts pass"

printf '#!/usr/bin/env bash\necho $1\n' >"$r/kit/notes/revamp/spikes/x/old.sh"
printf '#  messy\n\n\n' >"$r/kit/notes/revamp/spikes/x/notes.md"
{ [ "$(lint kit/notes/revamp/spikes/x/old.sh)" = 0 ] && [ "$(lint kit/notes/revamp/spikes/x/notes.md)" = 0 ]; } \
  || { cat "$work/out" >&2; fail "spikes are notes: want them left alone"; }
[ "$(cat "$r/kit/notes/revamp/spikes/x/notes.md")" = "$(printf '#  messy\n\n')" ] || fail "an ignored file was rewritten"
echo "ok - ignored paths (the spikes) are left alone"

[ "$(lint gone.md)" = 0 ] || fail "a deleted file: want 0"
echo "ok - a file that no longer exists is skipped"

[ "$(lint doc.md PRETTIER=/nonexistent/prettier)" = 2 ] || fail "missing prettier: want 2"
[ "$(lint src/good.sh SHELLCHECK=/nonexistent/shellcheck)" = 2 ] || fail "missing shellcheck: want 2"
echo "ok - a missing tool exits 2, never a pass"

echo "PASS: lint-file.sh"
