#!/usr/bin/env bash
# Runs every tests/*.test.sh; fails if any fails, or if there are none to run (L-17).
set -euo pipefail
cd "$(dirname "$0")"
shopt -s nullglob
tests=(*.test.sh)
[ ${#tests[@]} -gt 0 ] || { echo "FAIL: no tests found in tests/" >&2; exit 1; }
failed=0
for t in "${tests[@]}"; do
  echo "# $t"
  bash "$t" || { echo "FAILED: $t" >&2; failed=$((failed + 1)); }
done
[ "$failed" = 0 ] || { echo "$failed of ${#tests[@]} test files failed" >&2; exit 1; }
echo "all ${#tests[@]} test files passed"
