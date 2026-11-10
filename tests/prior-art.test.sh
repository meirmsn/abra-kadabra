#!/usr/bin/env bash
# Tests scripts/prior-art.py (spec specs/prior-art-registry.md): `check <url>` says whether an outside
# repo is new, seen at upstream's head, or seen at an older commit, from the index and `git ls-remote`.
# Upstreams are local repos, so the test never touches the network; whatever it can't read is exit 2,
# never "new".
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/prior-art.py"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"
prettier="$repo_root/node_modules/.bin/prettier"
[ -x "$prettier" ] || fail "prettier not found at $prettier (run npm ci)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

# Two upstreams: `up` gets a row at its head, `old` a row at a commit it has since moved past.
new_repo "$work/up"
new_repo "$work/old"
old_sha=$(git -C "$work/old" rev-parse HEAD)
commit_file "$work/old" more.txt "later"
up_sha=$(git -C "$work/up" rev-parse HEAD)
old_head=$(git -C "$work/old" rev-parse HEAD)
up_url="file://$work/up"
old_url="file://$work/old"
git init -q --bare "$work/empty.git" # a remote with no HEAD commit
new_repo "$work/fresh"                # a remote with no row

# index <file> <rows...>: an index in the registry's format, one table row per argument.
index() {
  local f=$1
  shift
  {
    printf '# Prior art\n\nSome prose, and a table that is not the index:\n\n| a | b |\n| - | - |\n| 1 | 2 |\n\n'
    printf '## Index\n\nA paragraph before the table.\n\n'
    printf '| Repo | Commit | Commit date | Tag | Analysed | Verdict | Note |\n'
    printf '| --- | --- | --- | --- | --- | --- | --- |\n'
    printf '%s\n' "$@"
    printf '\n## After the index\n\nMore prose.\n'
  } >"$f"
}
# shellcheck disable=SC2016 # the backticks are Markdown, printed as they are
row() { printf '| %s | `%s` | 2026-10-29 | no tag | 2026-11-10 | a verdict | [%s](%s.md) |' "$1" "$2" "$3" "$3"; }

index "$work/index.md" "$(row "$up_url" "$up_sha" up)" "$(row "$old_url" "$old_sha" old)"

# expect <name> <exit> <out pattern> -- <args...>: stdout and stderr together match the pattern.
expect() {
  local name=$1 want=$2 pat=$3 rc=0
  shift 4
  "$script" "$@" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: expected exit $want, got $rc"; }
  grep -qE -- "$pat" "$work/out.log" || { cat "$work/out.log" >&2; fail "$name: output lacks /$pat/"; }
  if [ "$want" != 0 ] && grep -q 'PRIOR-ART: new' "$work/out.log"; then fail "$name: printed new on exit $want"; fi
  echo "ok - $name"
}
# expect_line <name> <exact stdout> -- <args...>: exit 0 and exactly this one line on stdout.
expect_line() {
  local name=$1 want=$2 rc=0
  shift 3
  "$script" "$@" >"$work/out.log" 2>"$work/err.log" || rc=$?
  [ "$rc" = 0 ] || { cat "$work/out.log" "$work/err.log" >&2; fail "$name: expected exit 0, got $rc"; }
  [ "$(cat "$work/out.log")" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: expected exactly: $want"; }
  echo "ok - $name"
}

idx=(--index "$work/index.md")
up_note="$work/up.md"
old_note="$work/old.md"

# prior-art-registry AC-1: a URL with no row is new.
expect_line "prior-art-registry AC-1: a URL with no row is new" \
  "PRIOR-ART: new file://$work/fresh" -- check "file://$work/fresh" "${idx[@]}"
expect_line "prior-art-registry AC-1: a local path with no row is new" \
  "PRIOR-ART: new $work/fresh" -- check "$work/fresh" "${idx[@]}"

# prior-art-registry AC-2: a row at upstream's HEAD is seen and current, with its note.
expect_line "prior-art-registry AC-2: a row at upstream's head is current" \
  "PRIOR-ART: seen $up_url at ${up_sha:0:12}, current · $up_note" -- check "$up_url" "${idx[@]}"

# prior-art-registry AC-3: a row at an older commit names upstream's head.
expect_line "prior-art-registry AC-3: a row behind upstream names its head" \
  "PRIOR-ART: seen $old_url at ${old_sha:0:12}; upstream is now ${old_head:0:12} · $old_note" -- check "$old_url" "${idx[@]}"

# prior-art-registry AC-4: host or path case, a trailing .git and a trailing / match the same row.
# Each spelling must also reach the upstream: https://example.com/ is mapped to local repos with git's
# insteadOf (in the isolated HOME), in both host cases; a symlink gives a bare repo a name without
# .git; another gives a directory a lower-case name.
mkdir -p "$work/hosted/o" "$work/CASE"
git clone -q --bare "$work/up" "$work/hosted/o/r.git"
ln -s "$work/hosted/o/r.git" "$work/hosted/o/r"
git clone -q --bare "$work/up" "$work/CASE/r.git"
ln -s "$work/CASE" "$work/case"
git config --global url."file://$work/hosted/".insteadOf "https://example.com/"
git config --global --add url."file://$work/hosted/".insteadOf "https://EXAMPLE.COM/"
expect_seen() { # expect_seen <name> <row URL> <checked URL>
  index "$work/ac4.md" "$(row "$2" "$up_sha" r)"
  expect_line "prior-art-registry AC-4: $1" "PRIOR-ART: seen $3 at ${up_sha:0:12}, current · $work/r.md" -- check "$3" --index "$work/ac4.md"
}
expect_seen "an https URL matches its own row" "https://example.com/o/r" "https://example.com/o/r"
expect_seen "host case matches" "https://example.com/o/r" "https://EXAMPLE.COM/o/r"
expect_seen "a missing .git matches a row with one" "https://example.com/o/r.git" "https://example.com/o/r"
expect_seen "a .git and a trailing / match a row with neither" "https://example.com/o/r" "https://example.com/o/r.git/"
expect_seen "a trailing / matches" "https://example.com/o/r.git" "https://example.com/o/r.git/"
expect_seen "path case matches" "file://$work/case/r.git" "file://$work/CASE/r.git"

# prior-art-registry AC-5: what can't be read is exit 2 with the reason, never new.
expect "prior-art-registry AC-5: an unreachable remote can't run" 2 "can't read" -- check "file://$work/nowhere" "${idx[@]}"
expect "prior-art-registry AC-5: an unknown https repo can't run" 2 "can't read" -- check "https://example.com/o/missing" "${idx[@]}"
expect "prior-art-registry AC-5: a remote with no HEAD can't run" 2 "no HEAD" -- check "file://$work/empty.git" "${idx[@]}"
expect "prior-art-registry AC-5: http:// can't run" 2 "only https://" -- check "http://example.com/a/b" "${idx[@]}"
expect "prior-art-registry AC-5: an ssh URL can't run" 2 "only https://" -- check "ssh://git@example.com/a/b" "${idx[@]}"
expect "prior-art-registry AC-5: scp-style git@host: can't run" 2 "only https://" -- check "git@example.com:a/b.git" "${idx[@]}"
expect "prior-art-registry AC-5: a missing index can't run" 2 "no index" -- check "$up_url" --index "$work/missing.md"
index "$work/bad-sha.md" "$(row "$up_url" "abc123" up)"
expect "prior-art-registry AC-5: a short SHA can't run" 2 "40-hex" -- check "file://$work/fresh" --index "$work/bad-sha.md"
index "$work/bad-sha2.md" "$(row "$up_url" "${up_sha:0:39}g" up)"
expect "prior-art-registry AC-5: a non-hex SHA can't run" 2 "40-hex" -- check "file://$work/fresh" --index "$work/bad-sha2.md"
index "$work/bad-cells.md" "| $up_url | \`$up_sha\` | 2026-10-29 | no tag | 2026-11-10 | [up](up.md) |"
expect "prior-art-registry AC-5: a missing cell can't run" 2 "7 cells" -- check "file://$work/fresh" --index "$work/bad-cells.md"
index "$work/empty-cell.md" "| $up_url | \`$up_sha\` | 2026-10-29 |  | 2026-11-10 | a verdict | [up](up.md) |"
expect "prior-art-registry AC-5: an empty cell can't run" 2 "empty" -- check "file://$work/fresh" --index "$work/empty-cell.md"
index "$work/bad-note.md" "| $up_url | \`$up_sha\` | 2026-10-29 | no tag | 2026-11-10 | a verdict | up.md |"
expect "prior-art-registry AC-5: a note cell that isn't a link can't run" 2 "link" -- check "file://$work/fresh" --index "$work/bad-note.md"
index "$work/bad-url.md" "$(row "git@example.com:a/b" "$up_sha" up)"
expect "prior-art-registry AC-5: a row with a URL form not accepted can't run" 2 "only https://" -- check "file://$work/fresh" --index "$work/bad-url.md"
index "$work/dup.md" "$(row "$up_url" "$up_sha" up)" "$(row "$up_url.git/" "$old_sha" up2)"
expect "prior-art-registry AC-5: two rows for the same repo can't run" 2 "two rows" -- check "file://$work/fresh" --index "$work/dup.md"
printf '# Prior art\n\nNo index heading.\n' >"$work/no-table.md"
expect "prior-art-registry AC-5: an index with no table can't run" 2 "no index table" -- check "file://$work/fresh" --index "$work/no-table.md"
printf '## Index\n\nProse, then another section holds the table.\n\n## Other\n\n| Repo | Commit | Commit date | Tag | Analysed | Verdict | Note |\n| --- | --- | --- | --- | --- | --- | --- |\n' >"$work/later-table.md"
expect "prior-art-registry AC-5: a table under a later heading isn't the index" 2 "no index table" -- check "file://$work/fresh" --index "$work/later-table.md"
sed 's/^| Repo | Commit |/| Commit | Repo |/' "$work/index.md" >"$work/swapped.md"
grep -q '^| Commit | Repo |' "$work/swapped.md" || fail "test setup: the header wasn't swapped"
expect "prior-art-registry AC-5: a table with other columns can't run" 2 "no index table" -- check "file://$work/fresh" --index "$work/swapped.md"
expect "no command can't run" 2 "usage" --
expect "an unknown command can't run" 2 "usage" -- list
expect "no URL can't run" 2 "usage" -- check

# prior-art-registry AC-6: the index parses the same after Prettier formats it.
cp "$work/index.md" "$work/pretty.md"
"$prettier" --write "$work/pretty.md" >/dev/null
cmp -s "$work/index.md" "$work/pretty.md" && fail "prior-art-registry AC-6: test setup: Prettier changed nothing"
expect_line "prior-art-registry AC-6: a formatted index still finds the current row" \
  "PRIOR-ART: seen $up_url at ${up_sha:0:12}, current · $up_note" -- check "$up_url" --index "$work/pretty.md"
expect_line "prior-art-registry AC-6: a formatted index still finds the older row" \
  "PRIOR-ART: seen $old_url at ${old_sha:0:12}; upstream is now ${old_head:0:12} · $old_note" -- check "$old_url" --index "$work/pretty.md"

# The repo's own index parses, and its rows' notes exist (the default index, run from the repo root).
(cd "$repo_root" && "$script" check "file://$work/fresh") >"$work/out.log" 2>&1 ||
  { cat "$work/out.log" >&2; fail "the repo's index doesn't parse"; }
grep -qx "PRIOR-ART: new file://$work/fresh" "$work/out.log" || { cat "$work/out.log" >&2; fail "the repo's index: unexpected output"; }
echo "ok - the repo's own index parses"

# prior-art-registry AC-7: the docs map links the index and this spec and has a Layout row for the
# notes; the index links a note for each row, and each note exists (docs-map-check proves the rest).
docs="$repo_root/docs/README.md"
grep -qF '](../kit/notes/prior-art/README.md)' "$docs" || fail "prior-art-registry AC-7: docs/README.md doesn't link the index"
grep -qF '](../specs/prior-art-registry.md)' "$docs" || fail "prior-art-registry AC-7: docs/README.md doesn't link the spec"
# shellcheck disable=SC2016 # the backticks are Markdown
grep -qE '^\| \[`kit/notes/prior-art/`\]' "$docs" || fail "prior-art-registry AC-7: docs/README.md has no Layout row for kit/notes/prior-art/"
notes=$(sed -n '/^## Index/,$p' "$repo_root/kit/notes/prior-art/README.md" | grep -oE '\| \[[^]]+\]\([^)]+\.md\) \|$' | sed -E 's/.*\(([^)]+)\).*/\1/')
[ -n "$notes" ] || fail "prior-art-registry AC-7: the index links no note"
for n in $notes; do
  [ -f "$repo_root/kit/notes/prior-art/$n" ] || fail "prior-art-registry AC-7: the index links $n, which doesn't exist"
done
echo "ok - prior-art-registry AC-7: the docs map links the index, the spec and the Layout row; every note exists"
