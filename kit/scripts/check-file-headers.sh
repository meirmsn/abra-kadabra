#!/bin/bash
# check-file-headers.sh — verify .ts/.tsx files under src/ or app/ have a // What: header.
# Created for /pre-ship convention checks. NOT wired into pre-commit (mechanical enforcement
# produces mechanical documentation — /pre-ship judges which files benefit from headers).
#
# Usage:
#   check-file-headers.sh              # check staged files (pre-commit mode)
#   check-file-headers.sh main         # check files changed vs branch (pre-ship mode)
#
# Exit 1 with offending filenames if missing.
set -euo pipefail

BASE_BRANCH="${1:-}"
MISSING=()

if [ -n "$BASE_BRANCH" ]; then
  FILE_LIST=$(git diff --name-only --diff-filter=ACM "$BASE_BRANCH"...HEAD | grep -E '\.(ts|tsx)$' | grep -E '(^|/)src/|(^|/)app/' || true)
else
  FILE_LIST=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$' | grep -E '(^|/)src/|(^|/)app/' || true)
fi

for file in $FILE_LIST; do
  # Skip config files and type declarations
  [[ "$file" =~ \.config\. ]] && continue
  [[ "$file" =~ \.d\.ts$ ]] && continue

  # Check first 5 lines for // What:
  if ! head -n 5 "$file" | grep -q '// What:'; then
    MISSING+=("$file")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "Missing file header (// What: / // Why: / // Does NOT:):"
  for f in "${MISSING[@]}"; do
    echo "  $f"
  done
  exit 1
fi
