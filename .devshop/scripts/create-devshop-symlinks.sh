#!/usr/bin/env bash
# What: Create devshop symlinks in the project workspace
# Why: Injected infrastructure (skills, settings, commands, docs) needs to be
#      accessible at workspace-relative paths for Claude Code and hooks to work.
#      Symlinks are gitignored and can be lost by git operations — this script
#      is idempotent and safe to re-run.
# Does NOT: Generate CLAUDE.md, create .hooks/, install deps, or lock files.
#           Those are init-devshop.sh responsibilities (container start only).

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
WS="${WS:-/workspace}"

# Bail if devshop isn't mounted
[ -d "$DEVSHOP/.devshop" ] || exit 0

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
