#!/bin/bash
# What: Pre-commit check (devshop self) — runs bats tests affected by this commit
# Why: Ensures scripts and tests that changed in this commit still pass.
#      Full suite (~76s) is too slow for every commit; this runs only the
#      affected test files (typically 2-10s).
# Does NOT: Replace the full `bats kit/tests/` CI run — it catches the common
#           case (changed script/test breaks) without blocking flow.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
SCRIPTS_DIR="$DEVSHOP/kit/scripts"
TESTS_DIR="$DEVSHOP/kit/tests"
BATS="$DEVSHOP/kit/tests/lib/bats-core/bin/bats"

[ -d "$TESTS_DIR" ] || exit 0
[ -x "$BATS" ] || exit 0

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then
  : # devshop-self mode
elif [ "$GIT_ROOT" = "/devshop" ]; then
  : # devshop repo
else
  exit 0
fi

CHANGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)
[ -z "$CHANGED_FILES" ] && exit 0

BATS_FILES=()

collect() { BATS_FILES+=("$1"); }

# 1. Changed .bats files → run them directly
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [[ "$f" == kit/tests/*.bats ]]; then
    full="$DEVSHOP/$f"
    [ -f "$full" ] && collect "$full"
  fi
done <<< "$CHANGED_FILES"

# 2. Changed .sh scripts → find .bats files that reference them
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [[ "$f" == kit/scripts/*.sh ]]; then
    name=$(basename "$f")
    while IFS= read -r bats_file; do
      [ -n "$bats_file" ] && collect "$bats_file"
    done < <(grep -rl "$name" "$TESTS_DIR"/*.bats 2>/dev/null || true)
  fi
done <<< "$CHANGED_FILES"

# 3. Changed template files → run structural-invariants
while IFS= read -r f; do
  [ -z "$f" ] && continue
  if [[ "$f" == template/* ]]; then
    si="$TESTS_DIR/structural-invariants.bats"
    [ -f "$si" ] && collect "$si"
    break
  fi
done <<< "$CHANGED_FILES"

[ ${#BATS_FILES[@]} -eq 0 ] && exit 0

# Deduplicate
declare -A SEEN
UNIQUE_FILES=()
for bf in "${BATS_FILES[@]}"; do
  if [ -z "${SEEN[$bf]+_}" ]; then
    SEEN[$bf]=1
    UNIQUE_FILES+=("$bf")
  fi
done

echo "Running ${#UNIQUE_FILES[@]} affected bats file(s)..."
FAILED=false
FAILURE_OUTPUT=""
for bats_file in "${UNIQUE_FILES[@]}"; do
  echo "  $(basename "$bats_file")"
  _bats_out=$("$BATS" "$bats_file" --print-output-on-failure 2>&1) || {
    FAILED=true
    FAILURE_OUTPUT+="$_bats_out"$'\n'
  }
  echo "$_bats_out"
done

if [ "$FAILED" = true ]; then
  # Bypass: adversarial-reviewed batsSkipReason
  REASON=$(git config --get devshop.batsSkipReason 2>/dev/null || true)
  if [ -n "$REASON" ]; then
    echo "⏳ Bats skip: reviewing reason with adversarial agent..."
    _bats_failures=$(echo "$FAILURE_OUTPUT" | grep '^not ok ' | head -20 || true)
    REVIEW_RESULT=$(bash "$SCRIPTS_DIR/adversarial-review.sh" \
      batsSkipReason "$REASON" "$_bats_failures" 2>&1) || {
      echo ""
      echo "✖ ADVERSARIAL REVIEW REJECTED your bats skip reason."
      echo "  $REVIEW_RESULT"
      echo ""
      echo "  Address the finding above, then update your reason and retry."
      exit 1
    }
    echo "✓ Bats skip: adversarial review accepted."
    echo "  → recorded as Bats-Skip-Reason: trailer."
    exit 0
  fi

  echo ""
  echo "✖ BLOCKING: Bats tests failed for changed scripts/tests."
  echo ""
  echo "  Options:"
  echo "    1. Fix the failing tests"
  echo "    2. Bypass for this commit (adversarial-reviewed, recorded as a Bats-Skip-Reason: trailer):"
  echo "       git -c devshop.batsSkipReason=\"<name failing tests + why skipping is safe>\" commit ..."
  exit 1
fi
