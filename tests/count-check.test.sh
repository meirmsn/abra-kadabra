#!/usr/bin/env bash
# Tests runtime/scripts/count-check.py (specs/parallel-safe-shared-files.md): a test line that
# asserts a collection's current item count as a number literal fails, one known-bad file per
# assertion form; the count taken from the collection, another number, the number outside a count
# assertion and a line marked `count-check: allow` pass; a collection is a directory, a JSON array or
# an array under a top-level key; fewer than 2 items is too small to check; whatever can't be read
# exits 2, never 0. COUNT_CHECK overrides the script, for the mutant run.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="${COUNT_CHECK:-$repo_root/runtime/scripts/count-check.py}" # the override is for the mutant run
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# check <name> <want exit> <text the output must hold, or ""> <args...>
check() {
  local name=$1 want=$2 text=$3 rc=0
  shift 3
  python3 "$script" "$@" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$text" ] || grep -qF -- "$text" "$work/out.log" || { cat "$work/out.log" >&2; fail "$name: output doesn't hold '$text'"; }
  echo "ok - $name"
}

# Collections of 5 items: a directory (with a dot-file that doesn't count, and a subdirectory that
# does), a JSON array, and an array under a top-level key.
mkdir -p "$work/items/e"
touch "$work/items/a.json" "$work/items/b.json" "$work/items/c.json" "$work/items/d.json" "$work/items/.keep"
echo '["a","b","c","d","e"]' >"$work/items.json"
echo '{"name":"x","items":[1,2,3,4,5],"other":{}}' >"$work/site.json"

# parallel-safe-shared-files AC-5: each assertion form, with the literal 5, fails and names file and line.
forms=(
  'expect(tiles).toHaveLength(5);'
  'await expect(page.locator(".tile")).toHaveCount(5);'
  'expect(items.length).toBe(5);'
  'expect(items.length).toEqual(5);'
  'if (items.length === 5) throw new Error("x");'
  'ok(items.length == 5);'
  'ok(5 === items.length);'
  'expect(await tiles.count()).toBe(5);'
  'assert.equal(items.length, 5);'
  'assert.strictEqual(list.length, 5);'
  '    assert len(items) == 5'
  '    assert 5 == len(items)'
  '        self.assertEqual(len(items), 5)'
)
i=0
for form in "${forms[@]}"; do
  i=$((i + 1))
  mkdir -p "$work/bad$i"
  printf 'line one\n%s\n' "$form" >"$work/bad$i/site.test.js"
  for c in "$work/items" "$work/items.json" "$work/site.json#items"; do
    check "parallel-safe-shared-files AC-5: form $i ($form) over ${c##*/} fails, naming file:line and the marker" 1 \
      "bad$i/site.test.js:2:" --tests "$work/bad$i" "$c"
    grep -qF 'count-check: allow' "$work/out.log" || fail "AC-5: form $i's message doesn't name the allow marker"
  done
done

# parallel-safe-shared-files AC-6: the count from the collection, another number, the number outside
# a count assertion, and a marked line pass.
mkdir -p "$work/good"
cat >"$work/good/site.test.js" <<'JS'
const items = require("../items.json");
expect(tiles).toHaveLength(items.length);
expect(tiles).toHaveLength(4);
expect(items.length).toBe(6);
expect(items.length).toBe(15);
assert.equal(items.length, 50);
const timeoutMs = 5;
expect(score).toBe(5);
expect(tiles).toHaveLength(5); // count-check: allow, the five fixed tabs
JS
check "parallel-safe-shared-files AC-6: counts from the collection, other numbers and marked lines pass" 0 "" \
  --tests "$work/good" "$work/items.json"

# Several collections and paths: each collection's count is checked, one failure fails.
mkdir -p "$work/three"
for n in a b c; do touch "$work/three/$n"; done
check "parallel-safe-shared-files AC-7: every collection is checked; one failure fails" 1 "bad1/site.test.js:2:" \
  --tests "$work/good" --tests "$work/bad1" "$work/three" "$work/items.json"

# parallel-safe-shared-files AC-7: fewer than 2 items is too small to check, and passes saying so.
mkdir -p "$work/one" && touch "$work/one/only"
printf 'expect(tiles).toHaveLength(1);\n' >"$work/bad1/one.test.js"
check "parallel-safe-shared-files AC-7: a 1-item collection is too small to check" 0 "too small to check" \
  --tests "$work/bad1/one.test.js" "$work/one"
echo '[]' >"$work/empty.json"
check "parallel-safe-shared-files AC-7: an empty collection is too small to check" 0 "too small to check" \
  --tests "$work/good" "$work/empty.json"
echo '["a","b"]' >"$work/two.json"
printf 'expect(tiles).toHaveLength(2);\n' >"$work/bad1/two.test.js"
check "parallel-safe-shared-files AC-7: a 2-item collection is checked" 1 "two.test.js:1:" \
  --tests "$work/bad1/two.test.js" "$work/two.json"

# parallel-safe-shared-files AC-7: node_modules and dot-directories under a PATH are skipped.
mkdir -p "$work/skip/node_modules/x" "$work/skip/.cache"
cp "$work/bad1/site.test.js" "$work/skip/node_modules/x/"
cp "$work/bad1/site.test.js" "$work/skip/.cache/"
cp "$work/good/site.test.js" "$work/skip/"
check "parallel-safe-shared-files AC-7: node_modules and dot-directories are skipped" 0 "" --tests "$work/skip" "$work/items.json"

# parallel-safe-shared-files AC-7: what can't be read exits 2, never 0.
echo '{"items": [1, 2' >"$work/broken.json"
echo '{"items": 3}' >"$work/notarray.json"
echo 'a,b,c' >"$work/items.csv"
check "parallel-safe-shared-files AC-7: a missing collection can't run" 2 "no such collection" --tests "$work/good" "$work/nope"
check "parallel-safe-shared-files AC-7: JSON that doesn't parse can't run" 2 "doesn't parse" --tests "$work/good" "$work/broken.json"
check "parallel-safe-shared-files AC-7: a JSON object without a key can't run" 2 "not an array" --tests "$work/good" "$work/site.json"
check "parallel-safe-shared-files AC-7: a key that isn't an array can't run" 2 "not an array" --tests "$work/good" "$work/notarray.json#items"
check "parallel-safe-shared-files AC-7: a missing key can't run" 2 "not an array" --tests "$work/good" "$work/site.json#games"
check "parallel-safe-shared-files AC-7: a file that is neither a directory nor .json can't run" 2 "not a directory or a .json file" \
  --tests "$work/good" "$work/items.csv"
check "parallel-safe-shared-files AC-7: a missing tests path can't run" 2 "no such tests path" --tests "$work/nope" "$work/items.json"
mkdir -p "$work/none/.hidden" && touch "$work/none/.hidden/x.test.js"
check "parallel-safe-shared-files AC-7: no files under the tests paths can't run" 2 "no test files" --tests "$work/none" "$work/items.json"
check "parallel-safe-shared-files AC-7: no collection can't run" 2 "no collection" --tests "$work/good"
check "parallel-safe-shared-files AC-7: no tests path can't run" 2 "no --tests" "$work/items.json"
check "parallel-safe-shared-files AC-7: --tests without a PATH can't run" 2 "--tests needs a PATH" "$work/items.json" --tests
check "parallel-safe-shared-files AC-7: an unknown option can't run" 2 "unknown option --test" --test "$work/good" "$work/items.json"
mkdir -p "$work/dangling" && cp "$work/good/site.test.js" "$work/dangling/" && ln -s "$work/gone.js" "$work/dangling/gone.test.js"
check "parallel-safe-shared-files AC-7: a test file that can't be read can't run" 2 "can't read" --tests "$work/dangling" "$work/items.json"
