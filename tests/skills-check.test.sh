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
# The install's own skills (W10.4.8): the plugin's upgrade skill has the same shape, and no runtime
# skill shares its name (a version's skill would otherwise shadow or duplicate it).
plugin_upgrade="$repo_root/install/plugin/devshop/upgrade"
[ -f "$plugin_upgrade/skills/devshop-upgrade/SKILL.md" ] || fail "install/plugin/devshop/upgrade/skills/devshop-upgrade/SKILL.md is missing"
# Checked against this version's runtime: the /opt/devshop-current/ paths it names (ship.sh) come
# from the pinned version, which a session always has.
mkdir -p "$work/plugin-view"
for e in "$repo_root"/runtime/*; do [ "$(basename "$e")" = skills ] || ln -s "$e" "$work/plugin-view/"; done
ln -s "$plugin_upgrade/skills" "$work/plugin-view/skills"
check "the plugin's own skills (devshop-upgrade)" 0 "$work/plugin-view"
for d in "$plugin_upgrade"/skills/*/; do
  [ ! -e "$repo_root/runtime/skills/$(basename "$d")" ] || fail "runtime/skills/$(basename "$d") shares its name with the plugin's skill"
done
[ ! -e "$repo_root/runtime/skills/upgrade" ] || fail "runtime/skills/upgrade is still there (moved to the plugin as devshop-upgrade)"
echo "ok - no runtime skill shares a name with the plugin's"

# AC-6 (specs/ui-baseline.md): the build skill's disciplines line sends a UI with no baseline to the
# UI templates, a path skills-check (above) proves this version has.
# shellcheck disable=SC2016 # literal backticks: the skill's Markdown
grep -E '^- \*\*Disciplines:\*\*' -A2 "$repo_root/runtime/skills/build/SKILL.md" | tr '\n' ' ' |
  grep -qE 'UI with no baseline: `/opt/devshop-current/templates/ui/`' ||
  fail "AC-6: the build skill's disciplines line doesn't send a UI with no baseline to /opt/devshop-current/templates/ui/"
[ -f "$repo_root/runtime/templates/ui/base.css" ] || fail "AC-6: runtime/templates/ui/ has no base.css"
echo "ok - AC-6: build sends a UI with no baseline to the UI templates"
