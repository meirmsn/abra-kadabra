#!/usr/bin/env bash
# What: Rebuild the gstack browse + find-browse binaries and the Node server
#       bundle from devshop source, then copy them into a project's gstack
#       install at .claude/skills/gstack/browse/dist/.
# Why:  Project devcontainers ship gstack as binaries-only (dist/ without src/),
#       so a stale or runtime-incompatible binary can't be rebuilt in place from
#       the project tree. virtiofs also blocks Bun's --compile rename across
#       device boundaries — this script builds in /tmp and copies back.
# Does NOT: install Bun, install Chromium, manage the Playwright cache. Run
#       populate-playwright-cache.sh after this if the project hasn't already
#       symlinked /usr/bin/chromium into ~/.cache/ms-playwright.
#
# Usage: rebuild-browse.sh [TARGET_PROJECT_ROOT]
#        TARGET_PROJECT_ROOT defaults to the current git toplevel.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
SRC_ROOT="$DEVSHOP/.claude/skills/gstack"
SRC_DIR="$SRC_ROOT/browse/src"

if [ ! -d "$SRC_DIR" ]; then
  echo "error: gstack source not found at $SRC_DIR — set DEVSHOP=/path/to/devshop" >&2
  exit 2
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "error: bun not on PATH — install via the devcontainer Dockerfile" >&2
  exit 2
fi

TARGET_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TARGET_DIST="$TARGET_ROOT/.claude/skills/gstack/browse/dist"

if [ ! -d "$TARGET_DIST" ]; then
  echo "error: gstack browse dist not found at $TARGET_DIST" >&2
  echo "       (is $TARGET_ROOT a project with gstack installed?)" >&2
  exit 2
fi

echo "Rebuilding browse binaries from $SRC_DIR → $TARGET_DIST"

# 1. Compile binaries in /tmp (virtiofs blocks Bun's --compile rename across mounts).
cd /tmp
bun build --compile "$SRC_DIR/cli.ts" --outfile /tmp/browse-bin
bun build --compile "$SRC_DIR/find-browse.ts" --outfile /tmp/find-browse-bin

# 2. Rebuild the Node-compatible server bundle in devshop's dist/.
bash "$SRC_ROOT/browse/scripts/build-node-server.sh"

# 3. Copy everything into the project's dist/.
cp /tmp/browse-bin "$TARGET_DIST/browse"
cp /tmp/find-browse-bin "$TARGET_DIST/find-browse"
cp "$SRC_ROOT/browse/dist/server-node.mjs" "$TARGET_DIST/server-node.mjs"
cp "$SRC_ROOT/browse/dist/bun-polyfill.cjs" "$TARGET_DIST/bun-polyfill.cjs"
chmod +x "$TARGET_DIST/browse" "$TARGET_DIST/find-browse"

# 4. Stamp the version so health-check version-mismatch detection works.
git -C "$SRC_ROOT" rev-parse HEAD > "$TARGET_DIST/.version"

# 5. Smoke test: --help must succeed (resolves SERVER_SCRIPT or NODE_SERVER_SCRIPT).
if ! "$TARGET_DIST/browse" --help >/dev/null 2>&1; then
  echo "error: rebuilt browse binary failed --help — investigate $TARGET_DIST/browse" >&2
  exit 3
fi

echo "ok: browse + find-browse + server-node.mjs rebuilt at $TARGET_DIST"
echo "    next: ensure ~/.cache/ms-playwright has chromium-<rev>/chrome-linux/{chrome,headless_shell}"
echo "          symlinked to \$PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH (see populate-playwright-cache.sh)"
