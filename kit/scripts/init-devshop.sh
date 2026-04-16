#!/usr/bin/env bash
# Devshop injection — runs as root via sudo on every container start.
# Also called from .husky/pre-commit if symlinks are missing (git ops can lose them).
# Symlinks devshop infrastructure from /devshop into /workspace so
# Claude Code sees it, but git doesn't track it (gitignored in project repo).
#
# Security role: this script is the mechanism that prevents Claude from
# trivially escalating via sudo. It reads DEVCONTAINER_ROOT_PASSWORD from
# .devcontainer/.env, sets root/node passwords, configures sudo with password
# requirement (replaces default passwordless sudo), and locks all security-
# critical files to root ownership (chown root:root + chmod 644).

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

# --- Devshop-self guard ---
# When the workspace IS the devshop (opened directly in VS Code as a devcontainer),
# skip injection. kit/ is a real directory in the devshop repo but always
# a symlink (.devshopkit) in project repos. Without this guard, symlink creation
# would replace the real kit/ directory with a self-referential symlink (destructive).
if [ -d "$WS/kit" ] && [ ! -L "$WS/kit" ]; then
  (cd "$DEVSHOP" && su node -c 'pnpm install --frozen-lockfile 2>/dev/null || pnpm install') || true
  # Lock essentials even in devshop-self mode (prevents security freshness warnings)
  for f in "$WS/.claude/settings.json" "$WS/.dcg.toml"; do
    [ -e "$f" ] && chown root:root "$f" && chmod 644 "$f"
  done
  exit 0
fi

# --- Create devshop symlinks ---
# Extracted to create-devshop-symlinks.sh so it can also be called from
# session-start.sh and .husky/pre-commit when symlinks are lost by git ops.
DEVSHOP="$DEVSHOP" WS="$WS" bash "$DEVSHOP/kit/scripts/create-devshop-symlinks.sh"

# --- Copy security-critical files (real files, not symlinks) ---
# Symlinks are fragile: git ops delete them, node can replace them.
# Root-owned copies survive git ops and can't be modified by node.
# Freshness is checked by check-security-files-freshness.sh in pre-commit.
# Devshop settings.json uses kit/ paths (works from /devshop/ cwd).
# Workspace copy needs .devshopkit/ paths (works from /workspace/ cwd).
# Hooks run from the shell's cwd, which differs per repo.
[ -L "$WS/.claude/settings.json" ] && rm "$WS/.claude/settings.json"
bash "$DEVSHOP/kit/scripts/normalize-devshop-paths.sh" < "$DEVSHOP/.claude/settings.json" > "$WS/.claude/settings.json"

[ -L "$WS/.dcg.toml" ] && rm "$WS/.dcg.toml"
[ -f "$DEVSHOP/.dcg.toml" ] && cp "$DEVSHOP/.dcg.toml" "$WS/.dcg.toml"


# --- Create BUILD-LOG.md if missing (session-start hook reads it) ---
if [ ! -f "$WS/BUILD-LOG.md" ]; then
  cp "$DEVSHOP/template/BUILD-LOG.md" "$WS/BUILD-LOG.md"
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
# Two layers: (1) deny rules in settings.json block Edit/Write tools,
# (2) chown root:root + chmod 644 blocks Bash workarounds.
# Devshop repo files are explicitly included — they're copies, not symlinks.
# To edit any of these: sudo nano <file>
# Security-critical files locked below (both workspace and devshop repo):
#   settings.json        — deny list, DCG hook, permission mode
#   settings.local.json  — additional permissions grants
#   devcontainer.json    — DinD config, env var loading, container setup
#   init-devshop.sh      — injection script (runs as root via sudo)
#   init-firewall.sh     — network egress allowlist
#   Dockerfile           — base image, binary installs, system packages
#   checksums.sha256     — integrity verification for pinned binaries
#   .env                 — secrets and credentials
#   .dcg.toml            — destructive command guard configuration
#   kit/scripts/*        — commit guard scripts (breaks circularity: the
#                          scripts that watch settings.json must survive
#                          settings.json disappearing)
for f in \
  "$WS/.claude/settings.json" \
  "$WS/.claude/settings.local.json" \
  "$WS/.devcontainer/devcontainer.json" \
  "$WS/.devcontainer/init-devshop.sh" \
  "$WS/.devcontainer/init-firewall.sh" \
  "$WS/.devcontainer/Dockerfile" \
  "$WS/.devcontainer/checksums.sha256" \
  "$WS/.devcontainer/.env" \
  "$WS/.dcg.toml" \
  "$DEVSHOP/kit/scripts/init-devshop.sh" \
  "$DEVSHOP/.devcontainer/devcontainer.json" \
  "$DEVSHOP/.devcontainer/init-devshop.sh" \
  "$DEVSHOP/.devcontainer/init-firewall.sh" \
  "$DEVSHOP/.devcontainer/Dockerfile" \
  "$DEVSHOP/.devcontainer/checksums.sha256" \
  "$DEVSHOP/template/.devcontainer/devcontainer.json" \
  "$DEVSHOP/template/.devcontainer/init-devshop.sh" \
  "$DEVSHOP/template/.devcontainer/init-firewall.sh" \
  "$DEVSHOP/template/.devcontainer/Dockerfile" \
  "$DEVSHOP/template/.devcontainer/checksums.sha256" \
  "$DEVSHOP/.claude/settings.json" \
  "$DEVSHOP/.dcg.toml" \
  ; do
  [ -e "$f" ] && chown root:root "$f" && chmod 644 "$f"
done
# Lock all devshop scripts (glob — future scripts are auto-protected)
for f in "$DEVSHOP/kit/scripts/"*.sh; do
  [ -e "$f" ] && chown root:root "$f" && chmod 644 "$f"
done

# Sticky bit on .claude/: prevents node from deleting root-owned files
# (settings.json). Without this, directory write permission lets node delete
# any file regardless of ownership. Sticky bit restricts deletion to file owner.
[ -d "$WS/.claude" ] && chmod 1755 "$WS/.claude"
