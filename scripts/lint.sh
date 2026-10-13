#!/usr/bin/env bash
# This repo's lint, declared once for both CI's `fast` job (via scripts/check-fast.sh) and the devshop's
# pre-push hook, so the two run the same checks: formatting, shellcheck, the docs map, commit
# identities since <base>, and CI's own two-tier shape (runtime/scripts/ci-tiers-check.py).
# Usage: scripts/lint.sh [base-sha]   (run from the repo root; base as for commit-identity-check.sh)
# Every check runs even after one fails. Exit 0 = clean; 1 = findings; 2 = a check couldn't run.
set -uo pipefail

here=$(dirname "$0")
worst=0
check() {
  local name=$1 rc
  shift
  echo "== $name"
  "$here/$name" "$@"
  rc=$?
  case $rc in
    0) ;;
    1) echo "$name found problems"; [ "$worst" -ge 1 ] || worst=1 ;;
    *) echo "$name couldn't run (exit $rc)"; worst=2 ;;
  esac
}
check format-check.sh
check shellcheck.sh
check docs-map-check.py
check commit-identity-check.sh "${1:-}"
check ../runtime/scripts/ci-tiers-check.py .github/workflows/ci.yml
exit "$worst"
