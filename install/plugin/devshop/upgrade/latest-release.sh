#!/usr/bin/env bash
# Prints the newest devshop release in a devshop git dir (the session's local copy, /opt/devshop.git),
# for the upgrade skill's default NEW (spec specs/devshop-releases.md). A release is a tag vX.Y.Z with
# X >= 2, made by CI; v1's tags and anything else (v2.1.0-rc.1, a branch) never count. Newest by
# version order: v2.10.0 is above v2.9.0. Part of the installed plugin, read from main at the
# environment's cache build.
#   usage: latest-release.sh --devshop-git <dir>
# Exit 0 = printed; 1 = the copy holds no release (use main); 2 = can't run.
set -uo pipefail
cant() { echo "latest-release: $*" >&2; exit 2; }
[ $# = 2 ] && [ "$1" = --devshop-git ] || cant "usage: latest-release.sh --devshop-git <dir>"
git --git-dir="$2" rev-parse -q --verify HEAD >/dev/null 2>&1 || cant "no devshop git dir at $2"
tags=$(git --git-dir="$2" tag -l 'v*') || cant "can't list the tags in $2"
newest=$(grep -Ex 'v([2-9]|[1-9][0-9]+)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)' <<<"$tags" | sort -V | tail -1)
[ -n "$newest" ] || { echo "latest-release: no release in $2 (use main)" >&2; exit 1; }
echo "$newest"
