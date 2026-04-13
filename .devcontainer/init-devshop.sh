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

# Commands, settings, README — all symlinked
ln -sfn "$DEVSHOP/.claude/commands" "$WS/.claude/commands"
ln -sfn "$DEVSHOP/.claude/settings.json" "$WS/.claude/settings.json"
[ -f "$DEVSHOP/.claude/README.md" ] && ln -sfn "$DEVSHOP/.claude/README.md" "$WS/.claude/README.md"

# --- Generate CLAUDE.md from devshop CLAUDE.md + project CLAUDE.project.md ---
cp "$DEVSHOP/CLAUDE.md" "$WS/CLAUDE.md"
if [ -f "$WS/CLAUDE.project.md" ]; then
  printf '\n' >> "$WS/CLAUDE.md"
  cat "$WS/CLAUDE.project.md" >> "$WS/CLAUDE.md"
fi

# --- Create BUILD-LOG.md if missing (session-start hook reads it) ---
if [ ! -f "$WS/BUILD-LOG.md" ]; then
  cat > "$WS/BUILD-LOG.md" << 'BUILDLOG'
# Build Log

Project build history. Updated by `/build` after each successful ship.

> **New session?** Run `/ak-status` to get oriented.

## Status

**Current phase**: Not started
BUILDLOG
  chown node:node "$WS/BUILD-LOG.md"
fi

# --- Claude memory symlink ---
# Claude writes memories to ~/.claude/projects/-workspace/memory/ (native path).
# Symlink redirects to /workspace/.claude/memory/ so memories are tracked in git.
# .gitignore uses ".claude/*" + "!.claude/memory/" to track only the memory dir.
MEMORY_DIR="$WS/.claude/memory"
MEMORY_LINK="/home/node/.claude/projects/-workspace/memory"
mkdir -p "$MEMORY_DIR" "$(dirname "$MEMORY_LINK")"
ln -sfn "$MEMORY_DIR" "$MEMORY_LINK"
chown -h node:node "$MEMORY_LINK"

# --- Install devshop dependencies (husky, lint-staged, prettier, eslint, etc.) ---
# Runs on every start so deps stay current when devshop is updated from another project.
# Fast no-op when lockfile and node_modules are in sync.
(cd "$DEVSHOP" && su node -c 'pnpm install --frozen-lockfile 2>/dev/null || pnpm install') || true

# --- Lock security-critical files (root-owned, world-readable, not writable by node) ---
# chown follows symlinks, so this locks the target files in /devshop/ too
for f in \
  "$WS/.claude/settings.json" \
  "$WS/.devcontainer/devcontainer.json" \
  "$WS/.devcontainer/init-firewall.sh" \
  "$WS/.devcontainer/Dockerfile" \
  "$WS/.devcontainer/checksums.sha256" \
  "$WS/.devcontainer/.env" \
  "$WS/.dcg.toml" \
  ; do
  [ -e "$f" ] && chown root:root "$f" && chmod 644 "$f"
done
