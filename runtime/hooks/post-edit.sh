#!/usr/bin/env bash
# This devshop version's per-edit nudge (the plugin's PostToolUse hook on Claude's edit tools runs
# it): runs the repo's own `scripts/lint-file.sh <repo-relative path>` on the file just edited, with
# the devshop's pinned tools first on PATH. Exit 0 = clean (silent); findings or "couldn't run" go
# back to Claude in the same turn (exit 2, stderr). A repo without scripts/lint-file.sh gets no
# nudge. Feedback only: the pre-push hook and required CI run the full checks.
input=$(cat)
command -v jq >/dev/null || { echo "devshop post-edit: jq not found, so the edited file couldn't be checked" >&2; exit 2; }
file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")
[ -n "$file" ] || exit 0
top=$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
abs=$(realpath -m -- "$file")
case $abs in "$top"/*) rel=${abs#"$top"/} ;; *) exit 0 ;; esac
[ -x "$top/scripts/lint-file.sh" ] || exit 0
out=$(cd "$top" && PATH="/opt/devshop-tools/bin:$PATH" scripts/lint-file.sh "$rel" 2>&1)
case $? in
  0) exit 0 ;;
  1) printf '%s\n' "$out" >&2; exit 2 ;;
  *) printf '%s\ndevshop post-edit: scripts/lint-file.sh couldn'"'"'t run on %s (output above)\n' "$out" "$rel" >&2; exit 2 ;;
esac
