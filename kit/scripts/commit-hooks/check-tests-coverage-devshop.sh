#!/bin/bash
# What: Pre-commit check (devshop self) — flags kit/scripts changes that lack corresponding tests
# Why: Ensures new scripts get test coverage and modified scripts are considered.
#      New scripts without tests are blocked. Modified scripts without tests warn.
# Does NOT: Verify test quality or coverage depth — that's `/ak-tests-review`'s
#           job, fired at audit time via `/ak-check-docs-and-tests` (NOT per-commit).
#
# Layer 1 only. Per-commit Sonnet judgment was removed alongside the audit-time
# migration (see kit/ROADMAP.md § PR-C). Bypass via
# `git -c devshop.testsCoverageReason="<why>"` accepts the commit without an LLM
# round-trip; the bypass is recorded as a `Tests-Coverage-Bypass:` trailer by
# the prepare-commit-msg hook (kit/scripts/commit-hooks/append-bypass-trailers.sh)
# and harvested at audit time by `/ak-tests-review`.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
TESTS_DIR="$DEVSHOP/kit/tests"

# Only relevant in devshop repos (projects don't have kit/tests/)
[ -d "$TESTS_DIR" ] || exit 0
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then
  : # devshop-self mode, continue
elif [ "$GIT_ROOT" = "/devshop" ]; then
  : # devshop repo, continue
else
  exit 0
fi

# Scripts that are explicitly exempt from testing (with reasons)
EXEMPT_SCRIPTS=(
  "adversarial-review.sh"        # calls claude CLI — non-deterministic, mocked in all callers
  "init-devshop.sh"              # runs as root — needs integration test environment
  "session-start.sh"             # advisory output only, heavy fixture setup
  "from-devshop.sh"              # manual-run sync script, low blast radius
  "to-devshop.sh"                # manual-run sync script, low blast radius
  "statusline.sh"                # pure formatting, zero blast radius
  "release.sh"                   # manual, low frequency
)

is_exempt() {
  local script="$1"
  for exempt in "${EXEMPT_SCRIPTS[@]}"; do
    [ "$script" = "$exempt" ] && return 0
  done
  return 1
}

# Get staged script changes
ADDED_SCRIPTS=$(git diff --cached --name-only --diff-filter=A | grep '^kit/scripts/.*\.sh$' || true)
MODIFIED_SCRIPTS=$(git diff --cached --name-only --diff-filter=M | grep '^kit/scripts/.*\.sh$' || true)

[ -z "$ADDED_SCRIPTS" ] && [ -z "$MODIFIED_SCRIPTS" ] && exit 0

BLOCK=false
WARN=false
BLOCKED_LIST=""
WARNED_LIST=""

# Check new scripts — block if no test file exists
while IFS= read -r script; do
  [ -z "$script" ] && continue
  name=$(basename "$script")
  is_exempt "$name" && continue

  # Look for any .bats file that references this script name
  if ! grep -rl "$name" "$TESTS_DIR"/*.bats >/dev/null 2>&1; then
    BLOCK=true
    BLOCKED_LIST+="    $name (new — needs test file)\n"
  fi
done <<< "$ADDED_SCRIPTS"

# Check modified scripts — warn if no test file exists
while IFS= read -r script; do
  [ -z "$script" ] && continue
  name=$(basename "$script")
  is_exempt "$name" && continue

  if ! grep -rl "$name" "$TESTS_DIR"/*.bats >/dev/null 2>&1; then
    WARN=true
    WARNED_LIST+="    $name (modified — consider adding tests)\n"
  fi
done <<< "$MODIFIED_SCRIPTS"

if [ "$WARN" = true ]; then
  echo ""
  echo "⚠ Kit scripts modified without test coverage:"
  echo -e "$WARNED_LIST"
  echo "  These scripts have no corresponding .bats test file."
  echo "  Consider adding tests, or add the script to the exempt list"
  echo "  in check-tests-coverage-devshop.sh if testing isn't practical."
fi

if [ "$BLOCK" = true ]; then
  # Bypass: accept on flag presence (no LLM call). Trailer emission is the
  # prepare-commit-msg hook's job — see append-bypass-trailers.sh.
  REASON=$(git config --get devshop.testsCoverageReason 2>/dev/null || true)
  if [ -n "$REASON" ]; then
    echo ""
    echo "⚠ Tests-coverage block bypassed: $REASON"
    echo "  → recorded as Tests-Coverage-Bypass: trailer; will be revisited at audit time."
    exit 0
  fi

  echo ""
  echo "✖ BLOCKING: New kit scripts added without test coverage:"
  echo -e "$BLOCKED_LIST"
  echo "  Every new script needs a test file in kit/tests/."
  echo ""
  echo "  Options:"
  echo "    1. Write the .bats test alongside the script"
  echo "    2. Add the script to the exempt list in check-tests-coverage-devshop.sh"
  echo "    3. Bypass for this commit (recorded as a Tests-Coverage-Bypass: trailer):"
  echo "       git -c devshop.testsCoverageReason=\"<why a test won't be written in this commit>\" commit ..."
  exit 1
fi
