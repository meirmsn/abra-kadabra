#!/usr/bin/env bash
# Secret scan run by CI: the commits a change adds, then the working tree, with /.gitleaks.toml.
# Usage: scripts/secret-scan.sh [base-sha]   (run from the repo to scan)
#   base-sha given → scans base..HEAD; empty or all zeros (new branch) → scans all of HEAD's history.
# Exit 0 = no leaks; non-zero = leaks found or gitleaks failed (a missing gitleaks fails, never passes).
set -euo pipefail

config=$(cd "$(dirname "$0")/.." && pwd)/.gitleaks.toml
gitleaks=${GITLEAKS:-gitleaks}
base=${1:-}

command -v "$gitleaks" >/dev/null || { echo "FAIL: gitleaks not found" >&2; exit 2; }

if [ -z "$base" ] || [ "$base" = 0000000000000000000000000000000000000000 ]; then
  range=HEAD
else
  git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "FAIL: unknown base $base" >&2; exit 2; }
  range="$base..HEAD"
fi

echo "secret-scan: commits $range"
"$gitleaks" git . --config "$config" --redact --no-banner --log-opts="$range"
echo "secret-scan: working tree"
"$gitleaks" dir . --config "$config" --redact --no-banner
