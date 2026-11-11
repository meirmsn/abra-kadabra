#!/usr/bin/env bash
# The fast CI tier (the devshop's template; copy to scripts/check-fast.sh). CI's `fast` job runs it
# (runtime/templates/ci.yml). Static checks and unit tests:
#   - the secret scan over what the change adds since <base>: scripts/secret-scan.sh, a copy of the
#     devshop's scripts/secret-scan.sh;
#   - the spec check: every spec in specs/ has the shape, and every AC-<n> not marked "verified by
#     review" is named by a test under TEST_DIRS (TARGET Verify): scripts/spec-check.py, a copy of
#     the devshop's runtime/scripts/spec-check.py (needs python3, on GitHub's runners);
#   - the project contract check: every file the tooling relies on is there and well-formed:
#     scripts/contract-check.py over scripts/project-contract.txt, both copies of the devshop's;
#   - lint, when the project has scripts/lint.sh (the stack home says what it runs);
#   - the DESIGN.md shape check, when the project has a DESIGN.md: its front matter has the shape
#     and the theme CSS (THEME_CSS below) is derived from it: scripts/ui/design-md-check.mjs, a copy
#     of the devshop's runtime/templates/ui/design-md-check.mjs (ui.md § Checks). Without a
#     DESIGN.md the baseline is the design and one line says so;
#   - the count check, for each collection in COLLECTIONS below: no test under TEST_DIRS hard-codes
#     how many items it holds (guidelines/parallel.md): scripts/count-check.py, a copy of the
#     devshop's runtime/scripts/count-check.py, placed when the project declares a collection;
#   - the stack's parts, from the stack home: unit tests, ...
# Copy the scripts with their executable bit (exit 126, "couldn't run", otherwise). Keep a specs/
# directory (a .gitkeep before the first spec): a missing one can't run.
# Usage: scripts/check-fast.sh [base-sha]   (base as for secret-scan.sh)
# Every part runs even after one fails. Exit 0 = clean; 1 = failures; 2 = a part couldn't run.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
TEST_DIRS=(tests) # where the project's tests live, e.g. (test tests)
worst=0
part() {
  local rc
  echo "== $*"
  "$@"
  rc=$?
  case $rc in
    0) ;;
    1) echo "$1 failed"; [ "$worst" -ge 1 ] || worst=1 ;;
    *) echo "$1 couldn't run (exit $rc)"; worst=2 ;;
  esac
}
tests=()
for d in "${TEST_DIRS[@]}"; do tests+=(--tests "$d"); done

part scripts/secret-scan.sh "${1:-}"
part scripts/spec-check.py "${tests[@]}" specs
part scripts/contract-check.py
if [ -x scripts/lint.sh ]; then part scripts/lint.sh "${1:-}"; else echo "no scripts/lint.sh: lint is the stack's part"; fi
THEME_CSS="" # the theme CSS the pages load, derived from DESIGN.md's tokens, e.g. src/ui/base.css
if [ -f DESIGN.md ]; then
  part scripts/ui/design-md-check.mjs --theme "$THEME_CSS" DESIGN.md
else
  echo "no DESIGN.md: the baseline is the design (ui.md § Design direction)"
fi
# Collections that parallel branches each add an item to: a directory of one file per item, a .json
# array, or <file>.json#<key> (guidelines/parallel.md), e.g. (content/items).
COLLECTIONS=()
if [ ${#COLLECTIONS[@]} -gt 0 ]; then
  part scripts/count-check.py "${tests[@]}" "${COLLECTIONS[@]}"
else
  echo "no COLLECTIONS: no count check"
fi
# --- Stack parts (from the stack home), e.g. part npm test ---
exit "$worst"
