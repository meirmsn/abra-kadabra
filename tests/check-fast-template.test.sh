#!/usr/bin/env bash
# Tests runtime/templates/check-fast.sh, a project's fast CI tier, as a project would copy it: it
# runs the secret scan with the base and the spec check (runtime/scripts/spec-check.py, the real
# one) over specs/ with the tests under TEST_DIRS, every part even after one fails, and exits with
# the worst. A test that loses its AC-<n> name fails it (F-NEW-37); a missing spec-check.py, no
# python3, no specs/ or a spec that can't be read make it exit 2, never pass.
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
echo "ok - AC-1: a saved note is listed"
echo "ok - AC-2: an empty note is refused"
T

# run [env assignments...]: run the copy with base "b4se" (secret scan passing); echo its exit code.
run() {
  local rc=0
  echo 0 >"$work/secret-scan.rc"
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
want 0 "every acceptance item named by a test passes"
[ "$(cat "$work/ran")" = "secret-scan b4se" ] || fail "the secret scan didn't get the base: $(cat "$work/ran")"
echo "ok - the secret scan runs with the base"

sed -i 's/AC-2: an empty/an empty/' "$p/tests/notes.test.sh"
got=$(run)
want 1 "a test that lost its AC name fails the tier, naming the item" "AC-2: no test names it"
grep -q "secret-scan b4se" "$work/ran" || fail "the secret scan didn't run"
sed -i 's/ok - an empty/ok - AC-2: an empty/' "$p/tests/notes.test.sh"

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
