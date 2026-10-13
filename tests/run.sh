#!/usr/bin/env bash
# Runs the tests/*.test.sh of one tier, or all; fails if any fails, or if there are none to run (L-17).
# Usage: tests/run.sh [fast|slow]   (no tier: all)
# A file is slow (end to end, e.g. the whole install) when its leading comment block, after the
# shebang, has the exact line "# tier: slow"; every other file is fast (spec specs/ci-fast-slow-tiers.md).
set -euo pipefail
cd "$(dirname "$0")"
tier=${1:-all}
case $tier in fast | slow | all) ;; *) echo "FAIL: unknown tier '$tier' (fast, slow, or none for all)" >&2; exit 2 ;; esac

# is_slow <file>: the marker is in the comment block the file opens with.
is_slow() {
  local line
  while IFS= read -r line; do
    case $line in '#!'*) ;; '# tier: slow') return 0 ;; '#'*) ;; *) return 1 ;; esac
  done <"$1"
  return 1
}

shopt -s nullglob
tests=()
for t in *.test.sh; do
  case $tier in
    fast) is_slow "$t" || tests+=("$t") ;;
    slow) ! is_slow "$t" || tests+=("$t") ;;
    all) tests+=("$t") ;;
  esac
done
[ ${#tests[@]} -gt 0 ] || { echo "FAIL: no $tier tests found in tests/" >&2; exit 1; }
failed=0
for t in "${tests[@]}"; do
  echo "# $t"
  bash "$t" || { echo "FAILED: $t" >&2; failed=$((failed + 1)); }
done
[ "$failed" = 0 ] || { echo "$failed of ${#tests[@]} test files failed" >&2; exit 1; }
echo "all ${#tests[@]} $tier test files passed"
