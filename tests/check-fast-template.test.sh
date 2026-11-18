#!/usr/bin/env bash
# Tests runtime/templates/check-fast.sh, a project's fast CI tier, as a project would copy it: it
# runs the secret scan with the base and the spec check (runtime/scripts/spec-check.py, the real
# one) over specs/ with the tests under TEST_DIRS, every part even after one fails, and exits with
# the worst. A test that loses its AC-<n> name fails it (F-NEW-37); a missing spec-check.py, no
# python3, no specs/ or a spec that can't be read make it exit 2, never pass. The contract check and
# lint are parts too (specs/project-contract.md AC-3), stubbed here: the real contract check is proven
# by tests/contract-check.test.sh and, inside a placed project, tests/new-project.test.sh. The
# DESIGN.md shape check is a part when the project has a DESIGN.md (specs/design-md-check.md AC-5),
# stubbed here too; the real one is proven by tests/ui-design-md-check.test.sh. The count check
# runs for each collection the project declares (specs/parallel-safe-shared-files.md AC-8), the
# real one, proven by tests/count-check.test.sh.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
p="$work/project"
mkdir -p "$p/scripts" "$p/specs" "$p/tests"
cp "$repo_root/runtime/templates/check-fast.sh" "$p/scripts/"
cp "$repo_root/runtime/scripts/spec-check.py" "$p/scripts/"
# The secret scan is a stub that records its arguments and exits with secret-scan.rc's number.
# shellcheck disable=SC2016  # the stub's source
printf '#!/usr/bin/env bash\necho "secret-scan $*" >>"%s/ran"\nexit "$(cat "%s/secret-scan.rc")"\n' "$work" "$work" \
  >"$p/scripts/secret-scan.sh"
chmod +x "$p/scripts/secret-scan.sh"
# The contract check is a stub too: it records that it ran and exits with contract-check.rc's number.
# shellcheck disable=SC2016  # the stub's source
printf '#!/usr/bin/env bash\necho "contract-check $*" >>"%s/ran"\nexit "$(cat "%s/contract-check.rc")"\n' "$work" "$work" \
  >"$p/scripts/contract-check.py"
chmod +x "$p/scripts/contract-check.py"
cat >"$p/specs/notes.md" <<'SPEC'
# Notes

**Go:** "go", owner, 2026-10-13

## Intent

"Let me keep notes."

## Decisions

- Plain text only; rejected: markdown (no renderer yet).

## Acceptance items

- **AC-1** A saved note is listed.
- **AC-2** An empty note is refused.
- **AC-3** The list reads well on a phone — verified by review: open it at 375 px wide.

## Out of scope

- Sharing notes.
SPEC
cat >"$p/tests/notes.test.sh" <<'T'
echo "ok - notes AC-1: a saved note is listed"
echo "ok - notes AC-2: an empty note is refused"
T

# run [env assignments...]: run the copy with base "b4se" (secret scan passing); echo its exit code.
run() {
  local rc=0
  echo 0 >"$work/secret-scan.rc"
  echo 0 >"$work/contract-check.rc"
  rm -f "$work/ran"
  (cd "$p" && env "$@" scripts/check-fast.sh b4se) >"$work/out" 2>&1 || rc=$?
  echo "$rc"
}
want() { # want <exit> <name> [text the output must hold]
  [ "$got" = "$1" ] || { cat "$work/out" >&2; fail "$2: want exit $1, got $got"; }
  [ -z "${3:-}" ] || grep -qF -- "$3" "$work/out" || { cat "$work/out" >&2; fail "$2: output doesn't hold '$3'"; }
  echo "ok - $2"
}

got=$(run)
want 0 "every acceptance item named by a test passes" "no scripts/lint.sh: lint is the stack's part"
[ "$(head -1 "$work/ran")" = "secret-scan b4se" ] || fail "the secret scan didn't get the base: $(cat "$work/ran")"
grep -q '^contract-check $' "$work/ran" || fail "AC-3: the contract check didn't run: $(cat "$work/ran")"
echo "ok - AC-3: the secret scan runs with the base, the contract check after the spec check, and no lint is said"

# AC-3: a failing contract check fails the tier with the other parts still run; a missing one can't run.
echo 1 >"$work/contract-check.rc"
(cd "$p" && scripts/check-fast.sh b4se) >"$work/out" 2>&1 && got=0 || got=$?
want 1 "AC-3: a failing contract check fails the tier" "scripts/contract-check.py failed"
grep -q "secret-scan b4se" "$work/ran" || fail "AC-3: the secret scan didn't run beside the failing contract check"
mv "$p/scripts/contract-check.py" "$work/"
got=$(run)
want 2 "AC-3: a missing contract-check.py can't run (2), never passes" "scripts/contract-check.py couldn't run"
mv "$work/contract-check.py" "$p/scripts/"

# AC-3: lint runs as a part when the project has it executable, with the base; its exits count.
# shellcheck disable=SC2016  # the stub's source
printf '#!/usr/bin/env bash\necho "lint $*" >>"%s/ran"\nexit "$(cat "%s/lint.rc")"\n' "$work" "$work" >"$p/scripts/lint.sh"
chmod +x "$p/scripts/lint.sh"
echo 1 >"$work/lint.rc"
got=$(run)
want 1 "AC-3: lint findings fail the tier" "scripts/lint.sh failed"
grep -q '^lint b4se$' "$work/ran" || fail "AC-3: lint didn't get the base: $(cat "$work/ran")"
echo 2 >"$work/lint.rc"
got=$(run)
want 2 "AC-3: lint that can't run can't run the tier" "scripts/lint.sh couldn't run"
echo 0 >"$work/lint.rc"
got=$(run)
want 0 "AC-3: clean lint passes"
grep -q "no scripts/lint.sh" "$work/out" && fail "AC-3: the no-lint line printed with lint present"
rm "$p/scripts/lint.sh"

# design-md-check AC-5: without a DESIGN.md the tier says the baseline is the design and runs no
# check; with one, the shape check is a part, called with --theme and DESIGN.md, whose exits count,
# and a missing copy can't run.
got=$(run)
want 0 "design-md-check AC-5: without a DESIGN.md the tier says the baseline is the design" "no DESIGN.md: the baseline is the design"
grep -q "design-md-check" "$work/ran" 2>/dev/null && fail "design-md-check AC-5: the shape check ran without a DESIGN.md"
printf -- '---\nname: x\n---\n' >"$p/DESIGN.md"
sed -i 's|^THEME_CSS=""|THEME_CSS="src/theme.css"|' "$p/scripts/check-fast.sh"
grep -q '^THEME_CSS="src/theme.css"' "$p/scripts/check-fast.sh" || fail "design-md-check AC-5: THEME_CSS isn't a variable the project fills"
got=$(run)
want 2 "design-md-check AC-5: a DESIGN.md without the check's copy can't run, never passes" "scripts/ui/design-md-check.mjs couldn't run"
mkdir -p "$p/scripts/ui"
# shellcheck disable=SC2016  # the stub's source
printf '#!/usr/bin/env bash\necho "design-md-check $*" >>"%s/ran"\nexit "$(cat "%s/design-md-check.rc")"\n' "$work" "$work" \
  >"$p/scripts/ui/design-md-check.mjs"
chmod +x "$p/scripts/ui/design-md-check.mjs"
echo 1 >"$work/design-md-check.rc"
got=$(run)
want 1 "design-md-check AC-5: shape findings fail the tier" "scripts/ui/design-md-check.mjs failed"
grep -q '^design-md-check --theme src/theme.css DESIGN.md$' "$work/ran" || fail "design-md-check AC-5: the check didn't get --theme and DESIGN.md: $(cat "$work/ran")"
grep -q '^contract-check $' "$work/ran" || fail "design-md-check AC-5: the contract check didn't run beside the failing shape check"
grep -q "no DESIGN.md" "$work/out" && fail "design-md-check AC-5: the no-DESIGN.md line printed with one present"
echo 2 >"$work/design-md-check.rc"
got=$(run)
want 2 "design-md-check AC-5: a shape check that can't judge can't run the tier" "scripts/ui/design-md-check.mjs couldn't run"
echo 0 >"$work/design-md-check.rc"
got=$(run)
want 0 "design-md-check AC-5: a clean shape check passes"
rm "$p/DESIGN.md" "$p/scripts/ui/design-md-check.mjs"
rmdir "$p/scripts/ui"

# parallel-safe-shared-files AC-8: an empty COLLECTIONS list runs no count check and says so; a
# declared collection runs the real scripts/count-check.py over TEST_DIRS, and a test that
# hard-codes its count fails the tier; a missing copy can't run.
got=$(run)
want 0 "parallel-safe-shared-files AC-8: an empty COLLECTIONS list says there is nothing to count" "no COLLECTIONS: no count check"
grep -q '^COLLECTIONS=()' "$p/scripts/check-fast.sh" || fail "parallel-safe-shared-files AC-8: COLLECTIONS isn't an empty list the project fills"
mkdir -p "$p/items"
touch "$p/items/a" "$p/items/b" "$p/items/c"
sed -i 's|^COLLECTIONS=()|COLLECTIONS=(items)|' "$p/scripts/check-fast.sh"
got=$(run)
want 2 "parallel-safe-shared-files AC-8: a declared collection without the check's copy can't run" "scripts/count-check.py couldn't run"
cp "$repo_root/runtime/scripts/count-check.py" "$p/scripts/"
got=$(run)
want 0 "parallel-safe-shared-files AC-8: a declared collection with no hard-coded count passes" "count-check: no hard-coded count"
printf 'expect(tiles).toHaveLength(3);\n' >"$p/tests/tiles.test.js"
got=$(run)
want 1 "parallel-safe-shared-files AC-8: a test that hard-codes the collection's count fails the tier" "tests/tiles.test.js:1:"
grep -q '^contract-check $' "$work/ran" || fail "parallel-safe-shared-files AC-8: the contract check didn't run beside the failing count check"
rm "$p/tests/tiles.test.js" "$p/items/a" "$p/items/b" "$p/items/c" "$p/scripts/count-check.py"
rmdir "$p/items"
sed -i 's|^COLLECTIONS=(items)|COLLECTIONS=()|' "$p/scripts/check-fast.sh"

sed -i 's/notes AC-2: an empty/an empty/' "$p/tests/notes.test.sh"
got=$(run)
want 1 "a test that lost its AC name fails the tier, naming the item" "AC-2: no test names it"
grep -q "secret-scan b4se" "$work/ran" || fail "the secret scan didn't run"
sed -i 's/ok - an empty/ok - notes AC-2: an empty/' "$p/tests/notes.test.sh"

echo 1 >"$work/secret-scan.rc"
(cd "$p" && scripts/check-fast.sh b4se) >"$work/out" 2>&1 && got=0 || got=$?
want 1 "a failing secret scan fails the tier, and the spec check still runs" "== scripts/spec-check.py"

printf '# Bad\n\xff\n' >"$p/specs/bad.md"
got=$(run)
want 2 "a spec that can't be read can't run (2), never passes" "couldn't run"
rm "$p/specs/bad.md"

mv "$p/specs" "$p/specs.away"
got=$(run)
want 2 "no specs/ directory can't run (2), never passes" "couldn't run"
mv "$p/specs.away" "$p/specs"

mv "$p/scripts/spec-check.py" "$work/"
got=$(run)
want 2 "a missing spec-check.py can't run (2), never passes" "couldn't run"
mv "$work/spec-check.py" "$p/scripts/"

# No python3: a PATH holding only what the tier and the stub need.
mkdir -p "$work/bin"
for t in bash env dirname cat; do ln -s "$(command -v "$t")" "$work/bin/$t"; done
got=$(run PATH="$work/bin")
want 2 "no python3 can't run (2), never passes" "couldn't run"

got=$(run)
want 0 "back to clean, it passes again"
