#!/bin/bash
# check-file-headers.sh — verify staged .ts/.tsx files under src/ or app/ have a // What: header.
# Created for /pre-ship convention checks. NOT wired into pre-commit (mechanical enforcement
# produces mechanical documentation — /pre-ship judges which files benefit from headers).
# Exit 1 with offending filename if missing.
set -euo pipefail

MISSING=()

for file in $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(ts|tsx)$' | grep -E '(^|/)src/|(^|/)app/' || true); do
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
