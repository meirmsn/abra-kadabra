#!/usr/bin/env bash
# What: Create devshop symlinks in the project workspace
# Why: Injected infrastructure (skills, settings, commands, docs) needs to be
#      accessible at workspace-relative paths for Claude Code and hooks to work.
#      Symlinks are gitignored and can be lost by git operations — this script
#      is idempotent and safe to re-run.
# Does NOT: Copy security files (settings.json, .dcg.toml — root-owned copies
#           managed by init-devshop.sh), generate CLAUDE.md, create .hooks/,
#           install deps, or lock files.

set -euo pipefail

DEVSHOP="${DEVSHOP:-/devshop}"
WS="${WS:-/workspace}"

# Bail if devshop isn't mounted
[ -d "$DEVSHOP/.devshop" ] || exit 0

# --- Symlink .devshop/ into workspace ---
ln -sfn "$DEVSHOP/.devshop" "$WS/.devshop"

# NOTE: .dcg.toml and settings.json are NOT created here.
# They are root-owned COPIES managed by init-devshop.sh only.

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
  # Copy symlinks (preserves relative targets like "devshop/build" or "gstack/browse").
  # rm first: if the target already exists as a symlink to a directory, cp -a
  # follows it and copies INTO the directory instead of replacing the symlink.
  if [ -L "$link" ]; then
    rm -f "$WS/.claude/skills/$name"
    cp -a "$link" "$WS/.claude/skills/$name"
  fi
done

# Commands and README — symlinked (settings.json is a copy, see init-devshop.sh)
ln -sfn "$DEVSHOP/.claude/commands" "$WS/.claude/commands"
[ -f "$DEVSHOP/.claude/README.md" ] && ln -sfn "$DEVSHOP/.claude/README.md" "$WS/.claude/README.md"
