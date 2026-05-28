#!/bin/bash
# sync-from-devshop.sh — pull build tooling updates from the devshop repo into this project.
#
# Show-first-confirm-then-apply: previews proposed changes via a dry-run diff,
# then applies only after operator confirmation. --yes / -y bypasses the prompt.
#
# The devshop repo (abra-kadabra) is bind-mounted at /devshop. This script copies
# files listed in manifest.txt from the devshop's template/ directory. Injected
# files (skills, settings, etc.) are handled by init-devshop.sh — this script only
# syncs build tooling (turbo.json, eslint, etc.).
#
# Before running: make sure the devshop repo is up to date on the host side
# (git pull in the abra-kadabra directory).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Three levels up: the script is invoked via the .devshopkit symlink, so its
# logical path is <project>/.devshopkit/scripts/sync/from-devshop.sh — 3 path
# components stand between scripts/sync/ and the project root, not 2.
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MANIFEST="$PROJECT_ROOT/.devshopkit/manifest.txt"
DEVSHOP_DIR="${DEVSHOP_DIR:-/devshop}"

# --- Parse args (--yes / -y extracted by preview-confirm lib) ---
source "$SCRIPT_DIR/lib/preview-confirm.sh"
preview_confirm_parse_args "$@"
set -- "${PREVIEW_CONFIRM_REMAINING_ARGS[@]}"

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

# --- package.json merge: preserve project identity fields across sync ---
# The template's package.json carries canonical scripts/devDependencies/pnpm/
# lint-staged fields. The project's name/version/packageManager must survive.
merge_package_json() {
  local template="$1" project="$2" output="$3"
  if [ ! -f "$project" ] || ! echo '{}' | jq '.' &>/dev/null; then
    cp "$template" "$output"
    return
  fi
  jq -s '
    .[0] as $tmpl | .[1] as $proj |
    $tmpl + {
      name: $proj.name,
      version: ($proj.version // $tmpl.version),
      packageManager: ($proj.packageManager // $tmpl.packageManager)
    }
  ' "$template" "$project" > "$output"
}

# --- Build rsync exclude args for a directory (three-source model) ---
build_rsync_excludes() {
  local path="$1"
  RSYNC_EXCLUDES=()
  for excl in "${EXCLUDES[@]:-}"; do
    [ -z "$excl" ] && continue
    if [[ "$excl" == "$path"* ]]; then
      local rel="${excl#$path}"
      RSYNC_EXCLUDES+=(--exclude "$rel")
    fi
  done
  while IFS= read -r locked_rel; do
    [ -n "$locked_rel" ] && RSYNC_EXCLUDES+=(--exclude "$locked_rel")
  done < <(manifest_locked_under "$path")
  while IFS= read -r scaffold_rel; do
    [ -n "$scaffold_rel" ] && RSYNC_EXCLUDES+=(--exclude "$scaffold_rel")
  done < <(manifest_scaffold_once_under "$path")
}

# --- Devcontainer rebuild advisory ---
# The sync rsync excludes [locked] .devcontainer leaves — init-devshop.sh owns
# them, refreshing each from $DEVSHOP/template/<path> via `install` on every
# container start. So a locked .devcontainer change NEVER shows up in `git diff`
# after a sync; only a content diff of the project's in-tree copy against the
# template predicts what the next container start (rebuild) will apply.
# Conditional + always-note: loud block on drift, one-line note when clean.
report_devcontainer_rebuild() {
  local drifted=() rel src dst
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    src="$DEVSHOP_DIR/template/.devcontainer/$rel"
    dst="$PROJECT_ROOT/.devcontainer/$rel"
    # Skip leaves the template lacks (host-supabase / skip projects legitimately
    # omit some). cmp -s is non-zero when content differs OR dst is missing —
    # both mean the next rebuild would change the project copy.
    [ -f "$src" ] || continue
    if ! cmp -s "$src" "$dst"; then
      drifted+=("$rel")
    fi
  done < <(manifest_locked_under .devcontainer)

  echo ""
  if [ "${#drifted[@]}" -eq 0 ]; then
    echo "No .devcontainer changes — container rebuild not needed."
  else
    echo "Rebuild needed — .devcontainer changed (${#drifted[@]} file(s)):"
    for rel in "${drifted[@]}"; do
      echo "    $rel"
    done
    echo "  Rebuild the devcontainer to apply them:"
    echo "    VS Code → Cmd/Ctrl+Shift+P → \"Dev Containers: Rebuild Container\""
    echo "  (Init scripts also refresh on any container start; image files —"
    echo "   Dockerfile, devcontainer.json, compose.yml — strictly need a rebuild.)"
  fi
}

# --- Dry-run: stage proposed changes to temp dir ---
preview_confirm_init
echo "Preparing sync preview (${#PATHS[@]} paths from devshop to project)..."

for path in "${PATHS[@]}"; do
  src="$DEVSHOP_DIR/template/$path"

  if [ -d "$src" ]; then
    build_rsync_excludes "$path"
    preview_confirm_stage_dir "$src" "$PROJECT_ROOT/$path" "$path" "${RSYNC_EXCLUDES[@]}"
  elif [ -f "$src" ]; then
    if [ "$path" = "package.json" ] && [ -f "$PROJECT_ROOT/$path" ]; then
      merge_package_json "$src" "$PROJECT_ROOT/$path" "$_PC_STAGING_DIR/merged-pkg.json"
      preview_confirm_stage_file "$_PC_STAGING_DIR/merged-pkg.json" "proposed/$path"
    else
      preview_confirm_stage_file "$src" "proposed/$path"
    fi
    if [ -f "$PROJECT_ROOT/$path" ]; then
      preview_confirm_stage_file "$PROJECT_ROOT/$path" "current/$path"
    fi
  else
    echo "WARNING: $path not found in devshop, skipping"
  fi
done

# --- Show preview and prompt ---
# rc 0 = apply, 1 = user aborted, 2 = no synced-file changes. On rc 2 the synced
# tooling is already current, but [locked] .devcontainer leaves (excluded from
# the preview) may still have drifted — surface the rebuild advisory so a
# locked-only devshop release (Dockerfile/firewall bump with no synced delta)
# doesn't slip past silently. On rc 1 the operator declined; stay quiet.
pc_rc=0
preview_confirm_show_and_ask "$PROJECT_ROOT" || pc_rc=$?
if [ "$pc_rc" -eq 2 ]; then
  report_devcontainer_rebuild
  exit 0
elif [ "$pc_rc" -ne 0 ]; then
  exit 0
fi

# --- Read old version before apply (for propagation hint) ---
OLD_DEVSHOP_VERSION=""
if [ -f "$PROJECT_ROOT/.devshop-version" ]; then
  OLD_DEVSHOP_VERSION=$(cat "$PROJECT_ROOT/.devshop-version" | tr -d '[:space:]')
fi

# --- Apply: copy files from devshop to project ---
echo ""
echo "Applying changes..."
for path in "${PATHS[@]}"; do
  src="$DEVSHOP_DIR/template/$path"
  dst="$PROJECT_ROOT/$path"

  if [ -d "$src" ]; then
    build_rsync_excludes "$path"
    mkdir -p "$dst"
    rsync -ac --delete "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/"
  elif [ -f "$src" ]; then
    mkdir -p "$(dirname "$dst")"
    if [ "$path" = "package.json" ] && [ -f "$dst" ]; then
      merge_package_json "$src" "$dst" "$dst.tmp"
      mv "$dst.tmp" "$dst"
    else
      cp "$src" "$dst"
    fi
  fi
done

DEVSHOP_VERSION=$(cat "$DEVSHOP_DIR/kit/version" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
cp "$DEVSHOP_DIR/kit/version" "$PROJECT_ROOT/.devshop-version"
echo ""
echo "Synced to devshop v$DEVSHOP_VERSION. To commit:"
echo "  git add -A && git commit -m 'chore: sync from devshop v$DEVSHOP_VERSION'"

PROPAGATION="$DEVSHOP_DIR/kit/docs/PROPAGATION.md"
if [ -n "$OLD_DEVSHOP_VERSION" ] && [ "$OLD_DEVSHOP_VERSION" != "$DEVSHOP_VERSION" ] \
   && [ -f "$PROPAGATION" ]; then
  echo ""
  echo "Check .devshopkit/docs/PROPAGATION.md for manual steps since v$OLD_DEVSHOP_VERSION"
fi

report_devcontainer_rebuild
