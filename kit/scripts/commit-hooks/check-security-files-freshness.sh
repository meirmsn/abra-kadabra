#!/usr/bin/env bash
# What: Check that security-critical files are present, are copies (not symlinks), and match source
# Why: settings.json and .dcg.toml are root-owned copies (not symlinks) for resilience.
#      If missing/stale/symlinked, security rules may not be active.
# Does NOT: Fix the files — runs as node, can't write root-owned files.
#           Blocks the commit and shows the fix command instead.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
WS="${WS:-/workspace}"
STALE=false

# Skip if devshop isn't mounted
[ -d "$DEVSHOP/.claude" ] || exit 0

# --- settings.json (devshop-self-derived; not in manifest) ---
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
  elif ! bash "$DEVSHOP/kit/scripts/sync/normalize-devshop-paths.sh" < "$SRC_FILE" | diff -q - "$WS_FILE" >/dev/null 2>&1; then
    echo "⚠ .claude/settings.json is stale (differs from devshop source)."
    STALE=true
  fi
fi

# --- .dcg.toml (devshop-self-derived; not in manifest) ---
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

# --- Manifest [locked] files (template-derived) ---
# Verify each [locked] entry in kit/manifest.txt is a real file matching its
# template/ source. Catches drift if init-devshop.sh failed to refresh, or if
# git ops created a symlink where a copy should be (Layer-2 erosion described
# in guide/security.md).
MANIFEST="$DEVSHOP/kit/manifest.txt"
if [ -f "$MANIFEST" ] && [ -f "$DEVSHOP/kit/scripts/sync/lib/parse-manifest.sh" ]; then
  source "$DEVSHOP/kit/scripts/sync/lib/parse-manifest.sh"
  parse_manifest "$MANIFEST" 2>/dev/null || true
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    src="$DEVSHOP/template/$path"
    dst="$WS/$path"
    [ -f "$src" ] || continue
    if [ -L "$dst" ]; then
      echo "⚠ $path is a SYMLINK (should be a root-owned copy)."
      STALE=true
    elif [ ! -f "$dst" ]; then
      echo "⚠ $path is MISSING. Security/hook integrity compromised."
      STALE=true
    elif ! diff -q "$src" "$dst" >/dev/null 2>&1; then
      echo "⚠ $path is stale (differs from /devshop/template/$path)."
      STALE=true
    fi
  done < <(manifest_paths_by locked)
fi

if [ "$STALE" = true ]; then
  echo "  Fix: sudo bash /devshop/kit/scripts/init-devshop.sh"
  exit 1
fi
