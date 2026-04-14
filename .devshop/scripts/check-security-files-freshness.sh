#!/usr/bin/env bash
# What: Check that security-critical files are present, are copies (not symlinks), and match source
# Why: settings.json and .dcg.toml are root-owned copies (not symlinks) for resilience.
#      If missing/stale/symlinked, security rules may not be active.
# Does NOT: Fix the files — runs as node, can't write root-owned files.
#           Warns with fix command instead.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
WS="${WS:-/workspace}"
STALE=false

# Skip if devshop isn't mounted
[ -d "$DEVSHOP/.claude" ] || exit 0

# --- settings.json ---
WS_FILE="$WS/.claude/settings.json"
SRC_FILE="$DEVSHOP/.claude/settings.json"

if [ -f "$SRC_FILE" ]; then
  if [ -L "$WS_FILE" ]; then
    echo "⚠ .claude/settings.json is a SYMLINK (should be a root-owned copy)."
    echo "  Symlinks are fragile — git ops can delete them, disabling all security rules."
    STALE=true
  elif [ ! -f "$WS_FILE" ]; then
    echo "⚠ .claude/settings.json is MISSING. Security rules not active!"
    STALE=true
  elif ! diff -q "$SRC_FILE" "$WS_FILE" >/dev/null 2>&1; then
    echo "⚠ .claude/settings.json is stale (differs from devshop source)."
    STALE=true
  fi
fi

# --- .dcg.toml ---
WS_DCG="$WS/.dcg.toml"
SRC_DCG="$DEVSHOP/.dcg.toml"

if [ -f "$SRC_DCG" ]; then
  if [ -L "$WS_DCG" ]; then
    echo "⚠ .dcg.toml is a SYMLINK (should be a root-owned copy)."
    STALE=true
  elif [ ! -f "$WS_DCG" ]; then
    echo "⚠ .dcg.toml is MISSING. DCG using defaults only."
    STALE=true
  elif ! diff -q "$SRC_DCG" "$WS_DCG" >/dev/null 2>&1; then
    echo "⚠ .dcg.toml is stale (differs from devshop source)."
    STALE=true
  fi
fi

if [ "$STALE" = true ]; then
  echo "  Fix: sudo bash /devshop/.devcontainer/init-devshop.sh"
fi

# Never block — node can't fix root-owned files
exit 0
