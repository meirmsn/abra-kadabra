#!/usr/bin/env bash
# Formatting check run by CI: `prettier --check .` with the Prettier version package.json pins.
# Usage: scripts/format-check.sh   (run from the directory to check; honours its .prettierignore)
#   Prettier comes from this repo's node_modules (`npm ci`); $PRETTIER overrides it (tests).
# Exit 0 = formatted; 1 = files Prettier would change; 2 = can't run (missing or unpinned Prettier,
# nothing to check).
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
prettier=${PRETTIER:-$repo/node_modules/.bin/prettier}

command -v "$prettier" >/dev/null || { echo "FAIL: prettier not found at $prettier (run npm ci)" >&2; exit 2; }
want=$(node -p 'require(process.argv[1]).devDependencies.prettier' "$repo/package.json") ||
  { echo "FAIL: can't read the pinned prettier version from package.json" >&2; exit 2; }
got=$("$prettier" --version) || { echo "FAIL: $prettier --version failed" >&2; exit 2; }
[ "$got" = "$want" ] || { echo "FAIL: prettier is $got, package.json pins $want (run npm ci)" >&2; exit 2; }

exec "$prettier" --check .
