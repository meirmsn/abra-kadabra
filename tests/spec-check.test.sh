#!/usr/bin/env bash
# Tests runtime/scripts/spec-check.py, the shape check for a spec written from
# runtime/templates/spec.md (TARGET § L3 Intent 2 and 6): a filled-in spec passes; the unfilled
# template, missing, empty, unknown or out-of-order sections, acceptance items not numbered AC-1..n,
# an AC-<n> named but not defined, a state section without a table and a "verified by review" mark
# without its step all fail; with --go, a spec without the owner's recorded "go" fails.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/runtime/scripts/spec-check.py"
template="$repo_root/runtime/templates/spec.md"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# check <name> <want exit> <spec file> [problem the output must name]   ($GO: add --go)
check() {
  local rc=0
  "$script" ${GO+--go} "$3" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $rc"; }
  [ -z "${4:-}" ] || grep -qF -- "$4" "$work/out.log" || { cat "$work/out.log" >&2; fail "$1: output doesn't name '$4'"; }
  echo "ok - $1"
}
# variant <name> <python code changing s, the good spec>: write the changed copy, echo its path.
variant() {
  python3 -c 'import sys; s = open(sys.argv[1]).read(); exec(sys.argv[3]); open(sys.argv[2], "w").write(s)' \
    "$work/good.md" "$work/$1.md" "$2"
  echo "$work/$1.md"
}

cat >"$work/good.md" <<'SPEC'
# Saved cart

**Go:** pending

## Intent

"I want my cart to still be there when I switch from my phone to my laptop."

## Decisions

- Carts expire after 30 days, the shop's return window; rejected: never expire (storage grows).

## Acceptance items

- **AC-1** A signed-in shopper's cart is the same on every device they sign in on.
- **AC-2** A cart untouched for 30 days is empty on next sign-in (see AC-1 for the signed-in case).
- **AC-3** The cart badge shows the item count after sign-in. — verified by review: sign in on a second browser and read the badge

## Core flow

1. Add an item on the phone.
2. Sign in on the laptop.
3. The item is in the cart.

## States

| State           | Badge     | Empty-cart note |
| --------------- | --------- | --------------- |
| signed out      | hidden    | shown           |
| signed in, 0    | hidden    | shown           |
| signed in, 1+   | the count | hidden          |

## Out of scope

- Guest carts across devices.
SPEC

check "a filled-in draft passes" 0 "$work/good.md"
GO=1 check "--go: a draft whose go is pending fails" 1 "$work/good.md" "still pending"
went=$(variant went 's = s.replace("**Go:** pending", "**Go:** \"go\", owner, 2026-10-12")')
GO=1 check "--go: the owner's recorded go passes" 0 "$went"
GO=1 check "--go: a go without its date fails" 1 \
  "$(variant nodate 's = s.replace("**Go:** pending", "**Go:** owner said go")')" "date"
check "no Go line fails" 1 "$(variant nogo 's = s.replace("**Go:** pending\n", "")')" "Go"
check "no optional UI sections passes" 0 \
  "$(variant noui 'import re; s = re.sub(r"## Core flow.*?(?=## Out of scope)", "", s, flags=re.S)')"

check "the unfilled template fails" 1 "$template" "placeholder"
check "a missing section fails" 1 "$(variant nodec 'import re; s = re.sub(r"## Decisions.*?(?=## Acceptance)", "", s, flags=re.S)')" "Decisions"
check "an empty section fails" 1 "$(variant empty 'import re; s = re.sub(r"(## Out of scope\n).*", r"\1", s, flags=re.S)')" "Out of scope"
check "sections out of order fail" 1 \
  "$(variant order 's = s.replace("## Intent", "## TMP").replace("## Decisions", "## Intent").replace("## TMP", "## Decisions")')" "order"
check "an unknown section fails" 1 "$(variant extra 's = s.replace("## Out of scope", "## Notes\n\nx\n\n## Out of scope")')" "Notes"
check "no title fails" 1 "$(variant notitle 's = s.replace("# Saved cart\n", "")')" "title"

check "no acceptance items fails" 1 "$(variant noac 'import re; s = re.sub(r"- \*\*AC-\d+\*\*", "-", s)')" "AC-"
check "items not starting at AC-1 fail" 1 "$(variant start 's = s.replace("AC-3", "AC-4").replace("AC-2", "AC-3").replace("AC-1", "AC-2")')" "AC-1"
check "a gap in the numbering fails" 1 "$(variant gap 's = s.replace("**AC-3**", "**AC-4**")')" "AC-3"
check "a duplicate item fails" 1 "$(variant dup 's = s.replace("**AC-3**", "**AC-2**")')" "AC-2"
check "an item with no text fails" 1 "$(variant notext 's = s.replace("**AC-1** A signed-in", "**AC-1**\n\nA signed-in")')" "AC-1"
check "an AC named but not defined fails" 1 "$(variant undef 's = s.replace("rejected: never", "AC-9; rejected: never")')" "AC-9"
check "a non-item line in Acceptance items fails" 1 \
  "$(variant loose 's = s.replace("- **AC-1**", "Some prose.\n\n- **AC-1**")')" "Acceptance items"
check "a verified-by-review mark without its step fails" 1 \
  "$(variant vbr 's = s.replace("verified by review: sign in on a second browser and read the badge", "verified by review")')" "verified by review"
check "a States section without a table fails" 1 \
  "$(variant notable 'import re; s = re.sub(r"(## States\n\n).*?(?=## Out)", r"\1Shown when signed in.\n\n", s, flags=re.S)')" "States"
# shellcheck disable=SC2016  # literal backticks in the spec
check "placeholders inside code are fine" 0 "$(variant code 's = s.replace("Guest carts across devices.", "Guest carts; template syntax `{{x}}` is not a placeholder.")')"

check "a missing file can't run" 2 "$work/nope.md"
rc=0; "$script" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "no argument: expected exit 2, got $rc"
echo "ok - no argument can't run"

# --tests: the acceptance→test check (TARGET Verify; F-NEW-37). Every AC-<n> not marked "verified
# by review" must be named, as "<spec> AC-<n>" with the spec's file name (F-NEW-92), in a file
# under a --tests path.
# tcheck <name> <want exit> [problem the output must name] -- <spec-check arguments>
tcheck() {
  local name=$1 want=$2 needle=$3 rc=0
  shift 4
  "$script" "$@" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: expected exit $want, got $rc"; }
  [ -z "$needle" ] || grep -qF -- "$needle" "$work/out.log" || { cat "$work/out.log" >&2; fail "$name: output doesn't name '$needle'"; }
  echo "ok - $name"
}
mkdir -p "$work/t/unit" "$work/t/unit/node_modules/dep" "$work/specs/sub"
cp "$work/good.md" "$work/cart.md"
cat >"$work/t/unit/cart.test.js" <<'T'
it("cart AC-1: the cart follows the shopper", () => {});
it("cart AC-2: a 30-day-old cart is empty", () => {});
T
cp "$work/cart.md" "$work/specs/cart.md"
tcheck "--tests: every item named by a test passes (AC-3 is verified by review)" 0 "" -- \
  --tests "$work/t" "$work/cart.md"
sed -i 's/cart AC-2: a 30/a 30/' "$work/t/unit/cart.test.js"
tcheck "--tests: an item whose test lost its name fails, naming it" 1 "cart AC-2" -- \
  --tests "$work/t" "$work/cart.md"
grep -q "AC-1" "$work/out.log" && fail "--tests: AC-1 has a test but is reported"
echo 'test("cart AC-21 is another item", () => {});' >"$work/t/unit/other.test.js"
tcheck "--tests: cart AC-21 doesn't count as cart AC-2" 1 "AC-2" -- --tests "$work/t" "$work/cart.md"
echo '// cart AC-2' >"$work/t/unit/node_modules/dep/index.js"
tcheck "--tests: a name under node_modules doesn't count" 1 "AC-2" -- --tests "$work/t" "$work/cart.md"
# Known-bad (F-NEW-92): an AC-2 without the spec's name, or with another spec's, names no item.
echo 'it("AC-2: expires", () => {});' >"$work/t/unit/bare.test.js"
tcheck "--tests: a bare AC-2, without the spec's name, doesn't count" 1 "cart AC-2" -- \
  --tests "$work/t" "$work/cart.md"
echo 'it("old-cart AC-2", () => {}); it("wishlist AC-2", () => {}); // mycart AC-2, cart  AC-2, cart.AC-2' \
  >"$work/t/unit/others.test.js"
tcheck "--tests: another spec's AC-2 (old-cart, mycart, wishlist) doesn't count as cart AC-2" 1 "cart AC-2" -- \
  --tests "$work/t" "$work/cart.md"
mkdir -p "$work/dot"
cp "$work/cart.md" "$work/dot/c.rt.md"
tcheck "--tests: a spec name is matched as written (c.rt's items aren't named by cart's tests)" 1 "c.rt AC-1" -- \
  --tests "$work/t" "$work/dot/c.rt.md"
rm "$work/t/unit/bare.test.js" "$work/t/unit/others.test.js"
echo 'it("cart AC-2: expires", () => {});' >"$work/t/expiry.test.js"
tcheck "--tests: a test in any --tests path counts" 0 "" -- --tests "$work/t/unit" --tests "$work/t" "$work/cart.md"
rm "$work/t/expiry.test.js"
# Two specs, each with an AC-1 and an AC-2: the first spec's tests don't name the second's items.
sed 's/^# Saved cart/# Wishlist/' "$work/cart.md" >"$work/wishlist.md"
echo 'it("cart AC-2: expires", () => {});' >"$work/t/unit/expiry.test.js"
tcheck "--tests: a second spec's items aren't named by the first spec's tests" 1 "wishlist.md: AC-1" -- \
  --tests "$work/t" "$work/cart.md" "$work/wishlist.md"
grep -q "cart.md:" "$work/out.log" && fail "--tests: cart.md's items are named but reported"
grep -q "wishlist.md: AC-2" "$work/out.log" || fail "--tests: wishlist.md's AC-2 is not reported"
echo 'it("wishlist AC-1", () => {}); it("wishlist AC-2", () => {});' >"$work/t/unit/wishlist.test.js"
tcheck "--tests: each spec's items named with its own name pass" 0 "" -- \
  --tests "$work/t" "$work/cart.md" "$work/wishlist.md"
rm "$work/t/unit/wishlist.test.js"
sed -i 's/AC-3\*\* The cart badge/AC-3** The cart\n  badge/' "$work/cart.md"
python3 - "$work/cart.md" <<'P'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("item count after sign-in. — verified by review: sign in", "item count after sign-in.\n  — verified by review: sign in")
open(p, "w").write(s)
P
tcheck "--tests: a 'verified by review' mark on the item's continuation line counts" 0 "" -- \
  --tests "$work/t" "$work/cart.md"
sed 's/ — verified by review: sign in on a second browser and read the badge//' "$work/specs/cart.md" >"$work/specs/sub/badge.md"
echo 'it("badge AC-1", () => {}); it("badge AC-2", () => {});' >"$work/t/unit/badge.test.js"
tcheck "--tests: a directory of specs is checked spec by spec, below it too" 1 "badge.md: AC-3" -- \
  --tests "$work/t" "$work/specs"
grep -q "badge AC-3" "$work/out.log" || fail "--tests: the problem doesn't give the name to use, 'badge AC-3'"
cp "$work/specs/cart.md" "$work/specs/sub/cart.md"
tcheck "--tests: two specs with the same file name fail (their tests' names would be shared)" 1 "same file name" -- \
  --tests "$work/t" "$work/specs"
check "two specs with the same file name fail without --tests too" 1 "$work/specs" "same file name"
rm "$work/specs/sub/cart.md"
mkdir -p "$work/nospecs"
tcheck "--tests: a directory with no specs passes and says so" 0 "no specs" -- --tests "$work/t" "$work/nospecs"
tcheck "--tests: a path that doesn't exist can't run" 2 "nope" -- --tests "$work/nope" "$work/cart.md"
mkdir -p "$work/empty"
tcheck "--tests: no test files under the paths can't run" 2 "no test files" -- --tests "$work/empty" "$work/cart.md"
tcheck "--tests: a missing spec can't run" 2 "nope.md" -- --tests "$work/t" "$work/nope.md"
printf '# Bad\n\xff\xfe\n' >"$work/bad.md"
tcheck "--tests: a spec that isn't UTF-8 can't run" 2 "bad.md" -- --tests "$work/t" "$work/bad.md"
tcheck "--tests: a spec without acceptance items fails" 1 "Acceptance items" -- \
  --tests "$work/t" "$(variant noacc 'import re; s = re.sub(r"## Acceptance items.*?(?=## Core flow)", "", s, flags=re.S)')"
tcheck "--tests without a value can't run" 2 "" -- "$work/cart.md" --tests
