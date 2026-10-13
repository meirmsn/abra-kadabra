#!/usr/bin/env bash
# This repo's fast CI tier (spec specs/ci-fast-slow-tiers.md): CI's `fast` job runs it. Static checks
# and unit tests: the secret scan and lint over what the change adds since <base>, then every test
# file not marked slow. The pre-push hook runs the lint part, scripts/lint.sh, and its own gitleaks.
# Usage: scripts/check-fast.sh [base-sha]   (base as for secret-scan.sh and lint.sh)
# Every part runs even after one fails. Exit 0 = clean; 1 = failures; 2 = a part couldn't run.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
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
part scripts/secret-scan.sh "${1:-}"
part scripts/lint.sh "${1:-}"
part tests/run.sh fast
exit "$worst"
