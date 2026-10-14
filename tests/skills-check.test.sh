#!/usr/bin/env bash
# Tests scripts/skills-check.py, the shape check for the devshop's own skills (runtime/skills/): each
# SKILL.md names itself after its directory, has a description, fits on one page, every
# /opt/devshop-current/<path> it names exists in the same runtime, and every `devshop:<skill>` it
# hands over to is a skill of the same runtime or the install's plugin; all the descriptions together,
# the plugin's included, stay within the always-loaded budget (TARGET Shape 2, W10.6.16, W10.6.18).
# Then runs it on the real runtime/ and plugin, which must hold the v2 skills (W10.6.1).
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/skills-check.py"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# check <name> <want exit> <runtime dir> [problem the output must name]
# check <name> <want exit> <runtime dir> [problem the output must name]; $PLUGIN, if set, is passed
# as --plugin-skills.
check() {
  local rc=0
  "$script" "$3" ${PLUGIN:+--plugin-skills "$PLUGIN"} >"$work/out.log" 2>&1 || rc=$?
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
check "a handover to a skill of the same runtime passes" 0 "$(runtime handover "$good Then invoke \`devshop:demo\`.")"
check "a handover to a skill the runtime lacks fails" 1 \
  "$(runtime dangling-skill "$good Then invoke \`devshop:missing\`.")" "devshop:missing"
# described <name> <words>: a runtime with one skill whose description has that many words.
described() {
  runtime "$1" "---
name: demo
description: $(for _ in $(seq 1 "$2"); do printf 'word '; done)
---

Text."
}
# A description on more than one line would be counted short: the check can't read it, so it fails.
check "a folded description fails" 1 "$(runtime folded "${good/description: A demo skill. Use when testing./description: >
  A demo skill.
  Use when testing.}")" "one line"
check "a description continued on the next line fails" 1 "$(runtime continued "${good/description: A demo skill. Use when testing./description: A demo skill.
  Use when testing.}")" "one line"
check "descriptions at the always-loaded budget pass" 0 "$(described budget 200)"
check "descriptions over the always-loaded budget fail" 1 "$(described over 201)" "always-loaded"
# The budget is for all the descriptions together: two skills of 101 words each are over it.
pair=$(described pair 101)
mkdir -p "$pair/skills/other"
sed 's/^name: demo$/name: other/' "$pair/skills/demo/SKILL.md" >"$pair/skills/other/SKILL.md"
check "two skills' descriptions over the budget together fail" 1 "$pair" "always-loaded"
# plugin <name> <skill name> <SKILL.md content>: a plugin skills dir holding one skill; echo its path.
plugin() {
  mkdir -p "$work/$1/$2"
  printf '%s\n' "$3" >"$work/$1/$2/SKILL.md"
  echo "$work/$1"
}
pgood=${good//name: demo/name: extra}
PLUGIN=$(plugin p-good extra "$pgood") check "a plugin skill of the same shape passes" 0 "$(runtime p-good-rt "$good")"
PLUGIN=$(plugin p-handover extra "$pgood Then invoke \`devshop:demo\`.") \
  check "a plugin skill handing over to a runtime skill passes" 0 "$(runtime p-handover-rt "$good")"
PLUGIN=$(plugin p-dangling extra "$pgood Then invoke \`devshop:missing\`.") \
  check "a plugin skill handing over to a skill nobody has fails" 1 "$(runtime p-dangling-rt "$good")" "devshop:missing"
PLUGIN=$(plugin p-shape extra "Just text.") check "a plugin skill without frontmatter fails" 1 "$(runtime p-shape-rt "$good")" "frontmatter"
PLUGIN=$(plugin p-clash demo "$good") check "a plugin skill named like a runtime skill fails" 1 "$(runtime p-clash-rt "$good")" "shares its name"
# The budget counts the plugin's descriptions too: 101 words in the runtime and 101 in the plugin.
over=$(described p-budget-rt 101)
PLUGIN=$(plugin p-budget extra "$(sed 's/^name: demo$/name: extra/' "$over/skills/demo/SKILL.md")") \
  check "runtime and plugin descriptions over the budget together fail" 1 "$over" "always-loaded"
PLUGIN="$work/nope-plugin" check "a missing plugin skills dir can't run" 2 "$(runtime p-missing-rt "$good")" "plugin"
mkdir -p "$work/empty"
check "a runtime with no skills can't run" 2 "$work/empty" "no skills"
check "a missing runtime can't run" 2 "$work/nope"

# The real runtime: every skill passes, and the v2 skills are there.
for s in intent build pr devshop-version; do
  [ -f "$repo_root/runtime/skills/$s/SKILL.md" ] || fail "runtime/skills/$s/SKILL.md is missing"
done
check "the real runtime's skills (intent, build, pr, devshop-version)" 0 "$repo_root/runtime"
# The install's own skills (W10.4.8), checked with the runtime's: the same shape, no shared name (a
# version's skill would otherwise shadow or duplicate it), and one always-loaded budget for all.
# The /opt/devshop-current/ paths a plugin skill names come from the pinned version, which a session
# always has, so they are checked against this version's runtime.
plugin_skills="$repo_root/install/plugin/devshop/upgrade/skills"
[ -f "$plugin_skills/upgrade/SKILL.md" ] || fail "install/plugin/devshop/upgrade/skills/upgrade/SKILL.md is missing"
grep -qx "name: upgrade" "$plugin_skills/upgrade/SKILL.md" || fail "the plugin's upgrade skill isn't named 'upgrade' (/devshop:upgrade)"
PLUGIN=$plugin_skills check "the real runtime's and plugin's skills together (upgrade)" 0 "$repo_root/runtime"
[ ! -e "$plugin_skills/devshop-upgrade" ] || fail "the plugin still has devshop-upgrade (renamed upgrade)"
[ ! -e "$repo_root/runtime/skills/upgrade" ] || fail "runtime/skills/upgrade would clash with the plugin's upgrade skill"
echo "ok - the plugin's skill is upgrade (/devshop:upgrade), and no runtime skill shares its name"

# AC-6 (specs/ui-baseline.md): the build skill's disciplines line sends a UI with no baseline to the
# UI templates, a path skills-check (above) proves this version has.
# shellcheck disable=SC2016 # literal backticks: the skill's Markdown
grep -E '^- \*\*Disciplines:\*\*' -A2 "$repo_root/runtime/skills/build/SKILL.md" | tr '\n' ' ' |
  grep -qE 'UI with no baseline: `/opt/devshop-current/templates/ui/`' ||
  fail "AC-6: the build skill's disciplines line doesn't send a UI with no baseline to /opt/devshop-current/templates/ui/"
[ -f "$repo_root/runtime/templates/ui/base.css" ] || fail "AC-6: runtime/templates/ui/ has no base.css"
echo "ok - AC-6: build sends a UI with no baseline to the UI templates"

# W10.6.16: Build hands the PR over to the pr skill, by the name a session can invoke.
# shellcheck disable=SC2016 # literal backticks: the skill's Markdown
grep -qF '`devshop:pr`' "$repo_root/runtime/skills/build/SKILL.md" ||
  fail "the build skill doesn't hand over to \`devshop:pr\`"
echo "ok - build hands the PR over to devshop:pr"

# W10.6.19 (F-NEW-56): the upgrade skill opens its PR through devshop:pr, which writes the body from the
# template, not through ship.sh with words of its own.
# shellcheck disable=SC2016 # literal backticks: the skill's Markdown
grep -qF '`devshop:pr`' "$plugin_skills/upgrade/SKILL.md" ||
  fail "upgrade doesn't hand its PR over to \`devshop:pr\`"
! grep -qF 'ship.sh' "$plugin_skills/upgrade/SKILL.md" ||
  fail "upgrade still runs ship.sh itself"
echo "ok - upgrade hands its PR over to devshop:pr"
