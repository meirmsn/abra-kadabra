#!/usr/bin/env bash
# The sanctioned repair of the devshop's pinned tools (specs/pinned-tools-survive-outage.md): installs
# the tools in install/tools.pin, at the local devshop copy's default ref, that are missing from
# /opt/devshop-tools/bin, with ../tools.sh in its repair mode: the pinned URL and sha256 only, at
# most a minute. The plugin's dispatcher runs it at session start; a session runs it by hand, with
# no arguments, when a tool is still missing (the plugin's Bash gate lets exactly this command
# through when dcg is missing). Prints "repair-tools: repaired <name>", "repair-tools: missing
# <name>" or "repair-tools: unreadable <why>"; exit 0 when no tool is missing afterwards, else 1.
# Takes no arguments and reads no DEVSHOP_* setting, so a caller can't change what it installs; a
# session that can write /opt can, though: feedback, not a wall. Log: /tmp/devshop-tools-repair.log.
set -uo pipefail
export PATH=/usr/bin:/bin
[ "$#" = 0 ] || { echo "repair-tools: takes no arguments" >&2; exit 2; }
MIRROR=/opt/devshop.git
DEFAULT_REF=/opt/devshop-plugin/versions/default-ref
tools_sh=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools.sh
ref=$(cat "$DEFAULT_REF" 2>/dev/null)
case $ref in
  '') echo "repair-tools: unreadable no default ref in $DEFAULT_REF"; exit 1 ;;
  -* | *[!A-Za-z0-9._/-]*) echo "repair-tools: unreadable default ref '$ref' is not a ref"; exit 1 ;;
esac
pin=$(mktemp /tmp/devshop-tools-pin.XXXXXX) || { echo "repair-tools: unreadable no temporary file for the pin"; exit 1; }
trap 'rm -f "$pin"' EXIT
git --git-dir="$MIRROR" show "$ref:install/tools.pin" >"$pin" 2>/dev/null \
  || { echo "repair-tools: unreadable no install/tools.pin at $ref"; exit 1; }
rc=0
out=$(bash "$tools_sh" repair "$pin" /opt/devshop-tools /usr/local/bin /tmp/devshop-tools-repair.log) || rc=$?
[ -z "$out" ] || while IFS= read -r line; do echo "repair-tools: $line"; done <<<"$out"
[ "$rc" = 0 ] || exit 1
exit 0
