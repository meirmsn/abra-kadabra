#!/bin/bash
# sync-from-devshop.sh — pull build tooling updates from the devshop repo into this project.
#
# The devshop repo (abra-kadabra) is bind-mounted at /devshop. This script copies
# files listed in manifest.txt from the devshop's template/ directory and shows a
# diff for review. Injected files (skills, settings, etc.) are handled by
# init-devshop.sh — this script only syncs build tooling (turbo.json, eslint, etc.).
#
# Before running: make sure the devshop repo is up to date on the host side
# (git pull in the abra-kadabra directory).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Three levels up: the script is invoked via the .devshopkit symlink, so its
# logical path is <project>/.devshopkit/scripts/sync/from-devshop.sh — 3 path
# components stand between scripts/sync/ and the project root, not 2. Bug from
# the 2026-04-30 manifest-driven refactor (commit 0cb378b) — undetected for 3
# weeks because no bats coverage; surfaced today on a home-os sync attempt.
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.devshopkit/manifest.txt"
DEVSHOP_DIR="${DEVSHOP_DIR:-/devshop}"

# --- Guards ---
if [ ! -d "$DEVSHOP_DIR" ]; then
  echo "ERROR: $DEVSHOP_DIR does not exist."
  echo ""
  echo "The devshop repo (abra-kadabra) must be bind-mounted into the devcontainer."
  echo "Setup (one-time):"
  echo "  1. On host: git clone <devshop-url> as sibling to this project"
  echo "  2. Add to .devcontainer/devcontainer.json mounts:"
  echo '     "source=${localWorkspaceFolder}/../abra-kadabra,target=/devshop,type=bind,consistency=delegated"'
  echo "  3. Rebuild devcontainer"
  exit 1
fi

if [ ! -d "$DEVSHOP_DIR/.git" ]; then
  echo "ERROR: $DEVSHOP_DIR is not a git repository."
  exit 1
fi

if [ ! -f "$MANIFEST" ]; then
  echo "ERROR: .devshopkit/manifest.txt not found."
  exit 1
fi

# --- Read manifest (only [sync] entries — skip [locked], [symlink], [scaffold-once]) ---
# [locked] is owned by init-devshop.sh on every container start (template→workspace).
# [symlink] is owned by sync/create-devshop-symlinks.sh.
# [scaffold-once] is project narrative — copying from template would clobber it.
source "$SCRIPT_DIR/lib/parse-manifest.sh"
parse_manifest "$MANIFEST"
PATHS=()
EXCLUDES=()
while IFS= read -r path; do
  [ -n "$path" ] && PATHS+=("$path")
done < <(manifest_paths_by sync)
for excl in "${MANIFEST_EXCLUDES[@]:-}"; do
  [ -n "$excl" ] && EXCLUDES+=("$excl")
done

# --- Copy files from devshop to project ---
echo "Syncing ${#PATHS[@]} paths from devshop to project..."
for path in "${PATHS[@]}"; do
  src="$DEVSHOP_DIR/template/$path"
  dst="$PROJECT_ROOT/$path"

  if [ -d "$src" ]; then
    # Build rsync exclude args for this directory. Three exclusion sources,
    # all derived from the manifest — mirrors sync/to-devshop.sh:
    #  - explicit !path entries (e.g. !.devcontainer/.env, !.husky/_)
    #  - [locked] leaves under this dir (owned by init-devshop.sh; rsyncing the
    #    template's copy over the project's would round-trip a template->live
    #    refresh that init-devshop.sh already handles on every container start)
    #  - [scaffold-once] leaves under this dir (project narrative, e.g.
    #    .devcontainer/firewall-extra-domains; clobbering loses the project's
    #    customizations)
    # Without these excludes, rsync -a --delete would also wipe gitignored
    # project state living under a [sync] directory (e.g. .devcontainer/.env,
    # which carries LOCAL_WORKSPACE_FOLDER + per-project port overrides).
    RSYNC_EXCLUDES=()
    for excl in "${EXCLUDES[@]:-}"; do
      [ -z "$excl" ] && continue
      if [[ "$excl" == "$path"* ]]; then
        rel="${excl#$path}"
        RSYNC_EXCLUDES+=(--exclude "$rel")
      fi
    done
    while IFS= read -r locked_rel; do
      [ -n "$locked_rel" ] && RSYNC_EXCLUDES+=(--exclude "$locked_rel")
    done < <(manifest_locked_under "$path")
    while IFS= read -r scaffold_rel; do
      [ -n "$scaffold_rel" ] && RSYNC_EXCLUDES+=(--exclude "$scaffold_rel")
    done < <(manifest_scaffold_once_under "$path")
    mkdir -p "$dst"
    rsync -a --delete "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/"
  elif [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  else
    echo "WARNING: $path not found in devshop, skipping"
  fi
done


# --- Show what changed ---
echo ""
echo "=== Changes from devshop sync ==="
cd "$PROJECT_ROOT"
git diff

DEVSHOP_VERSION=$(cat "$DEVSHOP_DIR/kit/version" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
echo ""
echo "Review the changes above. If they look good:"
echo "  git add -A && git commit -m 'chore: sync from devshop v$DEVSHOP_VERSION'"
