#!/usr/bin/env bash
# preview-confirm.sh — shared library for dry-run preview + confirm gate.
#
# Used by from-devshop.sh and to-devshop.sh to show proposed changes before
# applying them. Two-pass flow:
#   1. Dry-run: copy to a temp staging dir, diff against the live target
#   2. Confirm: y/N/diff prompt via /dev/tty
#   3. Apply: only on "y"
#
# Public API:
#   preview_confirm_init             → set up temp staging dir
#   preview_confirm_stage_file <src> <rel_path>  → stage a single file
#   preview_confirm_stage_dir <src_dir> <dst_dir> <rel_path> <rsync_excludes...>
#                                    → stage a directory via rsync dry-run
#   preview_confirm_show_and_ask <target_root>   → show diff, prompt, return
#                                    0=apply, 1=user aborted, 2=no changes to apply
#   preview_confirm_cleanup          → remove temp staging dir

# Globals set by preview_confirm_init
_PC_STAGING_DIR=""
_PC_AUTO_YES=false

# preview_confirm_parse_args <args...>
# Call before init. Sets _PC_AUTO_YES if --yes or -y is present.
# Returns remaining args via PREVIEW_CONFIRM_REMAINING_ARGS array.
preview_confirm_parse_args() {
  PREVIEW_CONFIRM_REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) _PC_AUTO_YES=true; shift ;;
      *) PREVIEW_CONFIRM_REMAINING_ARGS+=("$1"); shift ;;
    esac
  done
}

preview_confirm_init() {
  _PC_STAGING_DIR=$(mktemp -d "/tmp/sync-preview-$$.XXXXXX")
  trap 'preview_confirm_cleanup' EXIT
}

preview_confirm_stage_file() {
  local src="$1" rel_path="$2"
  local staged="$_PC_STAGING_DIR/$rel_path"
  mkdir -p "$(dirname "$staged")"
  if [ -f "$src" ]; then
    cp "$src" "$staged"
  fi
}

# Stage a directory using rsync to the staging dir.
# Args: <src_dir> <dst_dir_for_diffing> <rel_path> [rsync_exclude_args...]
# The dst_dir is used later for diffing — we copy the CURRENT state of dst
# into a separate "current" tree so the diff is clean.
preview_confirm_stage_dir() {
  local src_dir="$1" dst_dir="$2" rel_path="$3"
  shift 3
  local rsync_excludes=("$@")
  local staged="$_PC_STAGING_DIR/proposed/$rel_path"
  mkdir -p "$staged"
  rsync -a --delete "${rsync_excludes[@]}" "$src_dir/" "$staged/"
}

# Show the diff between proposed changes and current state, then prompt.
# Args: <target_root> — the live directory being synced into
# Returns: 0 if user confirmed (apply), 1 if user aborted, 2 if no changes to
#          apply. Callers that only gate the apply pass can treat any nonzero as
#          "don't apply"; from-devshop.sh distinguishes 2 (still surface the
#          post-sync devcontainer rebuild advisory) from 1 (silent abort).
preview_confirm_show_and_ask() {
  local target_root="$1"
  local proposed_root="$_PC_STAGING_DIR/proposed"

  # Build the "current" snapshot for files that exist in the proposed tree
  local current_root="$_PC_STAGING_DIR/current"
  mkdir -p "$current_root"

  # Mirror the proposed tree structure but with current file contents
  while IFS= read -r rel_file; do
    local current_file="$target_root/$rel_file"
    local snapshot="$current_root/$rel_file"
    mkdir -p "$(dirname "$snapshot")"
    if [ -f "$current_file" ]; then
      cp "$current_file" "$snapshot"
    fi
  done < <(cd "$proposed_root" && find . -type f | sed 's|^\./||')

  # Compute summary stats — only count files in the proposed tree.
  # Files absent from proposed but present in target are rsync-excluded
  # (locked, scaffold-once, !path) and won't be touched by the apply pass.
  local added=0 modified=0
  while IFS= read -r f; do
    if [ ! -f "$current_root/$f" ]; then
      added=$((added + 1))
    elif ! cmp -s "$current_root/$f" "$proposed_root/$f"; then
      modified=$((modified + 1))
    fi
  done < <(cd "$proposed_root" && find . -type f | sed 's|^\./||')

  local total=$((added + modified))

  if [ "$total" -eq 0 ]; then
    echo ""
    echo "No changes to apply."
    return 2
  fi

  echo ""
  echo "=== Sync preview ==="
  echo "$total file(s) would change ($modified modified, $added added)"
  echo ""

  _pc_show_diff "$current_root" "$proposed_root"

  if [ "$_PC_AUTO_YES" = true ]; then
    echo ""
    echo "(--yes flag: auto-confirming)"
    return 0
  fi

  _pc_prompt_loop "$current_root" "$proposed_root"
}

_pc_show_diff() {
  local current_root="$1" proposed_root="$2"
  # Use diff -ru with labels stripped to relative paths
  diff -ru "$current_root" "$proposed_root" \
    --label "current" --label "proposed" 2>/dev/null \
    | sed "s|$current_root/||g; s|$proposed_root/||g" \
    || true
}

_pc_prompt_loop() {
  local current_root="$1" proposed_root="$2"
  while true; do
    echo ""
    printf "Apply these changes? [y/N/diff] "
    local answer
    read -r answer < /dev/tty 2>/dev/null || answer=""
    case "${answer,,}" in
      y|yes)
        return 0
        ;;
      d|diff)
        echo ""
        _pc_show_diff "$current_root" "$proposed_root"
        ;;
      *)
        echo "Aborted — no changes applied."
        return 1
        ;;
    esac
  done
}

preview_confirm_cleanup() {
  [ -n "$_PC_STAGING_DIR" ] && rm -rf "$_PC_STAGING_DIR"
}
