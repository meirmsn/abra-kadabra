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
trap 'echo "init-devshop.sh FAILED at line $LINENO (exit $?): $(sed -n "${LINENO}p" "$0")" >&2' ERR

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

# --- Devshop GitHub token ---
# Reads GITHUB_TOKEN (or GH_TOKEN) from devshop .env → exports as DEVSHOP_GITHUB_TOKEN
# via /etc/devshop-env. release.sh sources this to push and create GitHub releases.
# SSH remote stays untouched — release.sh constructs a transient HTTPS URL for push.
if [ -f "$DEVSHOP/.devcontainer/.env" ]; then
  _TOKEN=$(grep -E '^(GH_TOKEN|GITHUB_TOKEN)=' "$DEVSHOP/.devcontainer/.env" 2>/dev/null | head -1 | cut -d= -f2 || true)
  _TOKEN=$(echo "$_TOKEN" | tr -d "\"'" || true)
  if [ -n "$_TOKEN" ]; then
    echo "DEVSHOP_GITHUB_TOKEN=$_TOKEN" > /etc/devshop-env
    chmod 644 /etc/devshop-env
  fi
  unset _TOKEN
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
DEVSHOP="$DEVSHOP" WS="$WS" bash "$DEVSHOP/kit/scripts/sync/create-devshop-symlinks.sh"

# --- Copy security-critical files (real files, not symlinks) ---
# Symlinks are fragile: git ops delete them, node can replace them.
# Root-owned copies survive git ops and can't be modified by node.
# Freshness is checked by check-security-files-freshness.sh in pre-commit.
# Devshop settings.json uses kit/ paths (works from /devshop/ cwd).
# Workspace copy needs .devshopkit/ paths (works from /workspace/ cwd).
# Hooks run from the shell's cwd, which differs per repo.
[ -L "$WS/.claude/settings.json" ] && rm "$WS/.claude/settings.json"
bash "$DEVSHOP/kit/scripts/sync/normalize-devshop-paths.sh" < "$DEVSHOP/.claude/settings.json" > "$WS/.claude/settings.json"

[ -L "$WS/.dcg.toml" ] && rm "$WS/.dcg.toml"
[ -f "$DEVSHOP/.dcg.toml" ] && cp "$DEVSHOP/.dcg.toml" "$WS/.dcg.toml"


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
# To edit any of these: sudo nano <file>
#
# Workspace [locked] files (template-derived) are sourced from kit/manifest.txt
# via the shared parser at kit/scripts/sync/lib/parse-manifest.sh — single source
# of truth. install -m 644 -o root -g root atomically refreshes content + chowns
# + chmods, so a new template/<file> propagates on the next container start
# without a parallel hardcoded list (this is the .husky/pre-push fix).
#
# Devshop-self locks (the $DEVSHOP/... and $DEVSHOP/template/... lists below) and
# project-only locks (settings.json, settings.local.json, .dcg.toml, .env,
# .claude dir) stay hardcoded — they're devshop-bootstrap or operator-secret
# files outside the project-workspace lifecycle the manifest describes.
#
# See kit/docs/guide/architecture.md § File lifecycle for the model.

# Manifest-driven [locked] files: refresh content from template/ + chown root.
source "$DEVSHOP/kit/scripts/sync/lib/parse-manifest.sh"
parse_manifest "$DEVSHOP/kit/manifest.txt"
while IFS= read -r path; do
  [ -z "$path" ] && continue
  src="$DEVSHOP/template/$path"
  dst="$WS/$path"
  if [ -f "$src" ]; then
    install -D -m 644 -o root -g root "$src" "$dst"
  fi
done < <(manifest_paths_by locked)

# Manifest-driven [locked-dir]s: sticky bit on workspace dirs.
while IFS= read -r d; do
  [ -z "$d" ] && continue
  [ -d "$WS/$d" ] && chmod 1755 "$WS/$d"
done < <(manifest_paths_by locked-dir)

# Devshop-self + project-special locks (NOT in manifest by design):
#   settings.json        — copied via normalize-devshop-paths.sh above; not template-derived
#   settings.local.json  — operator-created additional permissions; project-only
#   .dcg.toml            — copied from $DEVSHOP/.dcg.toml above; not template-derived
#   .devcontainer/.env   — operator-created secrets; project-only
#   $DEVSHOP/...         — devshop-self bootstrap protection
#   $DEVSHOP/template/...— template-source integrity (read by ak-new-project)
for f in \
  "$WS/.claude/settings.json" \
  "$WS/.claude/settings.local.json" \
  "$WS/.dcg.toml" \
  "$WS/.devcontainer/.env" \
  "$DEVSHOP/kit/scripts/init-devshop.sh" \
  "$DEVSHOP/.devcontainer/devcontainer.json" \
  "$DEVSHOP/.devcontainer/init-devshop.sh" \
  "$DEVSHOP/.devcontainer/init-firewall.sh" \
  "$DEVSHOP/.devcontainer/Dockerfile" \
  "$DEVSHOP/.devcontainer/checksums.sha256" \
  "$DEVSHOP/.devcontainer/.env" \
  "$DEVSHOP/.husky/pre-commit" \
  "$DEVSHOP/.husky/pre-push" \
  "$DEVSHOP/.husky/prepare-commit-msg" \
  "$DEVSHOP/template/.devcontainer/devcontainer.json" \
  "$DEVSHOP/template/.devcontainer/init-devshop.sh" \
  "$DEVSHOP/template/.devcontainer/init-firewall.sh" \
  "$DEVSHOP/template/.devcontainer/Dockerfile" \
  "$DEVSHOP/template/.devcontainer/checksums.sha256" \
  "$DEVSHOP/template/.husky/pre-commit" \
  "$DEVSHOP/template/.husky/pre-push" \
  "$DEVSHOP/template/.husky/prepare-commit-msg" \
  "$DEVSHOP/.claude/settings.json" \
  "$DEVSHOP/.dcg.toml" \
  ; do
  [ -e "$f" ] && chown root:root "$f" && chmod 644 "$f"
done
# Lock all devshop scripts (recursive — covers root + subfolders like
# preship/, commit-hooks/, sync/; future scripts are auto-protected)
find "$DEVSHOP/kit/scripts/" -type f -name '*.sh' -print0 | \
  while IFS= read -r -d '' f; do
    chown root:root "$f" && chmod 644 "$f"
  done

# Sticky bit on dirs not covered by manifest [locked-dir] (devshop-self + .claude).
# Workspace [locked-dir]s (.husky, .devcontainer) are handled by the manifest
# loop above. .claude is project-special: it contains symlinks (skills, commands)
# and locked copies (settings.json) but isn't in template/, so it stays here.
for d in \
  "$WS/.claude" \
  "$DEVSHOP/.claude" \
  "$DEVSHOP/.devcontainer" \
  "$DEVSHOP/.husky" \
  "$DEVSHOP/template/.devcontainer" \
  "$DEVSHOP/template/.husky" \
  ; do
  [ -d "$d" ] && chmod 1755 "$d"
done
