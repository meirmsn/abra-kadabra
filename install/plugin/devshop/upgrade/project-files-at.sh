#!/usr/bin/env bash
# Runs a devshop version's own runtime/scripts/project-files.py, read from a devshop git dir (the
# session's local copy, /opt/devshop.git), so an upgrade uses the target version's code and
# manifest rules, not the pinned version's (W10.4.8). Part of the installed plugin, read from main
# at the environment's cache build.
#   usage: project-files-at.sh --devshop-git <dir> --at <version> <check|plan|apply> [args...]
# The script gets `<command> --devshop-git <dir> [args...]`; its exit status is passed through.
# Exit 2 = can't run (bad arguments, no git dir, a version not in the copy or without the script,
# no python3).
set -uo pipefail
usage="usage: project-files-at.sh --devshop-git <dir> --at <version> <check|plan|apply> [args...]"
cant() { echo "project-files-at: $*" >&2; exit 2; }

gitdir='' at=''
while [ $# -gt 0 ]; do
  case $1 in
    --devshop-git) [ $# -ge 2 ] || cant "$usage"; gitdir=$2; shift 2 ;;
    --at) [ $# -ge 2 ] || cant "$usage"; at=$2; shift 2 ;;
    *) break ;;
  esac
done
[ -n "$gitdir" ] && [ -n "$at" ] && [ $# -ge 1 ] || cant "$usage"
cmd=$1
shift
[ -d "$gitdir" ] || cant "no devshop git dir at $gitdir"
case $at in -*) cant "'$at' is not a devshop version (a release tag or commit SHA)" ;; esac
command -v python3 >/dev/null || cant "python3 not found"
sha=$(git --git-dir="$gitdir" rev-parse -q --verify "$at^{commit}" 2>/dev/null) \
  || cant "version '$at' is not in the devshop copy $gitdir; it refreshes when the environment's cache rebuilds: rebuild the environment, then retry"
tmp=$(mktemp) || cant "can't make a temporary file"
trap 'rm -f "$tmp"' EXIT
git --git-dir="$gitdir" show "$sha:runtime/scripts/project-files.py" >"$tmp" 2>/dev/null \
  || cant "version ${sha:0:12} has no runtime/scripts/project-files.py (older than W10.4.7)"
python3 "$tmp" "$cmd" --devshop-git "$gitdir" "$@"
