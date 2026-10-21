#!/usr/bin/env bash
# Tests runtime/templates/check-fast.sh, a project's fast CI tier, as a project would copy it: it
# runs the secret scan with the base and the spec check (runtime/scripts/spec-check.py, the real
# one) over specs/ with the tests under TEST_DIRS, every part even after one fails, and exits with
# the worst. A test that loses its AC-<n> name fails it (F-NEW-37); a missing spec-check.py, no
# python3, no specs/ or a spec that can't be read make it exit 2, never pass. The contract check and
# lint are parts too (specs/project-contract.md AC-3), stubbed here: the real contract check is proven
# by tests/contract-check.test.sh and, inside a placed project, tests/new-project.test.sh.
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
