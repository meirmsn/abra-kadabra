# shellcheck shell=bash
# Shared by the devshop's git hooks (sourced, not run).

# project_hook <name> [args]: run the project's own hook of that name, if it has one, with this
# hook's stdin; return its status. Only hooks the project configured in this clone run, as git would
# run them: devshop.chainHooksPath (its core.hooksPath before the devshop's session start set ours,
# e.g. husky's after `npm install`), else git's default <common git dir>/hooks. Hook scripts that are
# merely committed (e.g. .husky/* without husky set up) never run: git never runs committed hooks,
# so checking out an untrusted branch must not run its code.
project_hook() {
  local name=$1 top chain dir
  shift
  top=$(git rev-parse --show-toplevel) || return 1
  chain=$(git config --get devshop.chainHooksPath || true)
  if [ -n "$chain" ]; then
    case $chain in /*) dir=$chain ;; *) dir=$top/$chain ;; esac
  else
    dir=$(git rev-parse --path-format=absolute --git-common-dir)/hooks
  fi
  # Never back into the devshop's own hooks.
  [ "$(readlink -f "$dir")" != "$(readlink -f "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")" ] || return 0
  [ -x "$dir/$name" ] || return 0
  "$dir/$name" "$@"
}
