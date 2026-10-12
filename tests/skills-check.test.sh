#!/usr/bin/env bash
# Tests scripts/skills-check.py, the shape check for the devshop's own skills (runtime/skills/): each
# SKILL.md names itself after its directory, has a description, fits on one page, and every
# /opt/devshop-current/<path> it names exists in the same runtime. Then runs it on the real
# runtime/, which must hold the v2 skills (W10.6.1).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/skills-check.py"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# check <name> <want exit> <runtime dir> [problem the output must name]
check() {
  local rc=0
  "$script" "$3" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $rc"; }
  [ -z "${4:-}" ] || grep -qF -- "$4" "$work/out.log" || { cat "$work/out.log" >&2; fail "$1: output doesn't name '$4'"; }
  echo "ok - $1"
}
# runtime <name> <SKILL.md content>: a runtime dir with one skill "demo" and one script; echo its path.
runtime() {
  local d="$work/$1"
  mkdir -p "$d/skills/demo" "$d/scripts"
  touch "$d/scripts/tool.py"
  printf '%s\n' "$2" >"$d/skills/demo/SKILL.md"
  echo "$d"
}
# shellcheck disable=SC2016  # literal backticks in the skill's text
good='---
name: demo
description: A demo skill. Use when testing.
---

Run `/opt/devshop-current/scripts/tool.py` and read /opt/devshop-current/skills/demo/SKILL.md.'

check "a well-formed skill passes" 0 "$(runtime good "$good")"
check "a skill named unlike its directory fails" 1 "$(runtime name "${good/name: demo/name: other}")" "name"
check "a skill without a description fails" 1 "$(runtime desc "${good/description: A demo skill. Use when testing./description:}")" "description"
check "a skill without frontmatter fails" 1 "$(runtime nofm "Just text.")" "frontmatter"
check "a path the runtime lacks fails" 1 \
  "$(runtime dangling "$good Then /opt/devshop-current/scripts/missing.sh.")" "/opt/devshop-current/scripts/missing.sh"
long=$good$'\n'$(for i in $(seq 1 70); do echo "Line $i."; done)
check "a skill over one page (lines) fails" 1 "$(runtime lines "$long")" "lines"
wordy=$good$'\n'$(for i in $(seq 1 40); do echo "word word word word word word word word word word word word word word word word"; done)
check "a skill over one page (words) fails" 1 "$(runtime words "$wordy")" "words"
mkdir -p "$work/empty"
check "a runtime with no skills can't run" 2 "$work/empty" "no skills"
check "a missing runtime can't run" 2 "$work/nope"

# The real runtime: every skill passes, and the v2 skills are there.
for s in intent build devshop-version; do
  [ -f "$repo_root/runtime/skills/$s/SKILL.md" ] || fail "runtime/skills/$s/SKILL.md is missing"
done
check "the real runtime's skills (intent, build, devshop-version)" 0 "$repo_root/runtime"
