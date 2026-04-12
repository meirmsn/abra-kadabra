#!/usr/bin/env bash
# Devshop injection — runs as root via sudo on every container start.
# Symlinks devshop infrastructure from /devshop into /workspace so
# Claude Code sees it, but git doesn't track it (gitignored in project repo).

set -euo pipefail

DEVSHOP=/devshop
WS=/workspace

# --- Password setup ---
if [ -f "$WS/.devcontainer/.env" ]; then
  ROOT_PASSWORD=$(grep '^DEVCONTAINER_ROOT_PASSWORD=' "$WS/.devcontainer/.env" | cut -d= -f2)
  if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:$ROOT_PASSWORD" | chpasswd
    echo "node:$ROOT_PASSWORD" | chpasswd
    echo "node ALL=(ALL:ALL) ALL" > /etc/sudoers.d/node
    chmod 0440 /etc/sudoers.d/node
  fi
fi

# --- Symlink .devshop/ into workspace ---
ln -sfn "$DEVSHOP/.devshop" "$WS/.devshop"

# --- Symlink .dcg.toml ---
[ -f "$DEVSHOP/.dcg.toml" ] && ln -sfn "$DEVSHOP/.dcg.toml" "$WS/.dcg.toml"

# --- Build .claude/ directory ---
mkdir -p "$WS/.claude/skills"

# Core skill directories (actual content)
ln -sfn "$DEVSHOP/.claude/skills/devshop" "$WS/.claude/skills/devshop"
ln -sfn "$DEVSHOP/.claude/skills/gstack" "$WS/.claude/skills/gstack"

# Recreate all skill symlinks (ak-*, gstack tools, etc.)
for link in "$DEVSHOP/.claude/skills/"*; do
  name=$(basename "$link")
  # Skip the actual directories — already linked above
  [ "$name" = "devshop" ] || [ "$name" = "gstack" ] && continue
  # Copy symlinks (preserves relative targets like "devshop/build" or "gstack/browse")
  if [ -L "$link" ]; then
    cp -a "$link" "$WS/.claude/skills/$name"
  fi
done

# Commands
ln -sfn "$DEVSHOP/.claude/commands" "$WS/.claude/commands"

# Settings (copy, not symlink — needs root ownership for security lockdown)
cp "$DEVSHOP/.claude/settings.json" "$WS/.claude/settings.json"

# README
[ -f "$DEVSHOP/.claude/README.md" ] && cp "$DEVSHOP/.claude/README.md" "$WS/.claude/README.md"

# --- Generate CLAUDE.md from devshop template + project-specific parts ---
cp "$DEVSHOP/CLAUDE.devshop.md" "$WS/CLAUDE.md"
if [ -f "$WS/CLAUDE.project.md" ]; then
  printf '\n' >> "$WS/CLAUDE.md"
  cat "$WS/CLAUDE.project.md" >> "$WS/CLAUDE.md"
fi

# --- Create BUILD-LOG.md if missing (session-start hook reads it) ---
if [ ! -f "$WS/BUILD-LOG.md" ]; then
  cat > "$WS/BUILD-LOG.md" << 'BUILDLOG'
# Build Log — $(basename "$WS")

Project build history. Updated by `/build` after each successful ship.

> **New session?** Run `/ak-status` to get oriented.

## Status

**Current phase**: Not started
**Last updated**: $(date +%Y-%m-%d)
BUILDLOG
  chown node:node "$WS/BUILD-LOG.md"
fi

# --- Lock security-critical files (root-owned, world-readable, not writable by node) ---
for f in \
  "$WS/.claude/settings.json" \
  "$WS/.devcontainer/devcontainer.json" \
  "$WS/.devcontainer/init-firewall.sh" \
  "$WS/.devcontainer/Dockerfile" \
  "$WS/.devcontainer/checksums.sha256" \
  "$WS/.devcontainer/.env" \
  "$WS/.dcg.toml" \
  ; do
  [ -f "$f" ] && chown root:root "$f" && chmod 644 "$f"
done
