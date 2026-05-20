#!/usr/bin/env bash
# What: Capture a browser screenshot to a final path under .gstack/ or specs/,
#       routing through /tmp to dodge the gstack browse daemon's screenshot
#       allow-list (which validates output paths against [TEMP_DIR, process.cwd()]
#       and rejects writes to <git-root>/.gstack/ or <git-root>/specs/ unless the
#       daemon happens to be cwd'd at a parent).
# Why:  gstack is upstream-owned (.claude/skills/gstack/**) — we cannot extend
#       the daemon's allow-list at source without losing the change on the next
#       /gstack-upgrade. This wrapper lives outside the gstack tree, takes the
#       desired final path, screenshots to /tmp via `browse`, then cp's to the
#       final path. Callers get one-call semantics; the 2-step is internal.
# Does NOT: launch the browse daemon, navigate, set viewport — caller must
#           already have run `browse goto <url>` (and any sizing). This wrapper
#           ONLY handles the screenshot + cp pair.
#
# Usage:
#   bash kit/scripts/capture-screenshot.sh <final-path> [browse-flags...]
#
# Examples:
#   bash kit/scripts/capture-screenshot.sh specs/<feature>/hero/signin.png --full-page
#   bash kit/scripts/capture-screenshot.sh .gstack/qa-reports/screenshots/landing.png
#
# Exit codes: 0 ok, 2 usage error, 3 browse failure, 4 cp failure.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: capture-screenshot.sh <final-path> [browse-flags...]" >&2
  echo "       final-path may be absolute or relative to cwd" >&2
  exit 2
fi

FINAL_PATH="$1"
shift

# Resolve to absolute; the browse daemon needs an absolute path regardless of
# cwd, and `cp` is happiest with one too. realpath -m doesn't require the file
# to exist yet (the screenshot we're about to write).
ABS_FINAL=$(realpath -m "$FINAL_PATH")

FINAL_DIR=$(dirname "$ABS_FINAL")
mkdir -p "$FINAL_DIR"

# Stage under /tmp — always inside the daemon's allow-list. Use mktemp so
# concurrent callers (parallel /qa runs, multiple hero shots) don't collide.
BASENAME=$(basename "$ABS_FINAL")
EXT="${BASENAME##*.}"
STAGE_PATH=$(mktemp --tmpdir "capture-screenshot.XXXXXX.${EXT}")
# mktemp pre-creates the file; remove so `browse screenshot` writes a fresh PNG
# (some browse builds refuse to overwrite an existing target).
rm -f "$STAGE_PATH"

# Locate browse — prefer $PATH, fall back to gstack vendored install.
BROWSE_BIN=""
if command -v browse >/dev/null 2>&1; then
  BROWSE_BIN="browse"
elif [ -x /devshop/.claude/skills/gstack/browse/browse ]; then
  BROWSE_BIN="/devshop/.claude/skills/gstack/browse/browse"
fi

if [ -z "$BROWSE_BIN" ]; then
  echo "error: 'browse' binary not found on PATH or at /devshop/.claude/skills/gstack/browse/browse" >&2
  echo "       (run 'cd .claude/skills/gstack && ./setup' to install)" >&2
  exit 3
fi

# Screenshot to /tmp staging path, passing through any caller flags
# (--full-page, --viewport=..., etc.).
if ! "$BROWSE_BIN" screenshot "$STAGE_PATH" "$@" >/dev/null; then
  echo "error: browse screenshot failed for $STAGE_PATH" >&2
  rm -f "$STAGE_PATH"
  exit 3
fi

if [ ! -s "$STAGE_PATH" ]; then
  echo "error: browse screenshot produced an empty or missing file at $STAGE_PATH" >&2
  rm -f "$STAGE_PATH"
  exit 3
fi

# cp (not mv) so /tmp keeps its copy for the rest of the run if the caller
# needs to re-fetch; tmpreaper / container teardown will sweep it.
if ! cp "$STAGE_PATH" "$ABS_FINAL"; then
  echo "error: cp $STAGE_PATH -> $ABS_FINAL failed" >&2
  rm -f "$STAGE_PATH"
  exit 4
fi

echo "ok: captured $ABS_FINAL ($(stat -c '%s' "$ABS_FINAL") bytes via $STAGE_PATH)"
