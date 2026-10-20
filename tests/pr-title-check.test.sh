#!/usr/bin/env bash
# Tests scripts/pr-title-check.py (spec specs/devshop-releases.md): a PR title, or the subject it
# becomes on main, starts with a Conventional Commit type and stays within 72 characters before
# GitHub's " (#n)". Bad titles fail with a reason; no title can't run.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/scripts/pr-title-check.py"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# expect <name> <exit> <out pattern> -- <args...>
expect() {
  local name=$1 want=$2 pat=$3 rc=0
  shift 4
  "$script" "$@" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: expected exit $want, got $rc"; }
  grep -qE -- "$pat" "$work/out.log" || { cat "$work/out.log" >&2; fail "$name: output lacks /$pat/"; }
  echo "ok - $name"
}

# AC-1: the agreed form passes, for every type, with a scope, with `!`, and at exactly 72 characters
# followed by GitHub's " (#123)".
for type in feat fix perf revert docs test ci build refactor style chore; do
  expect "type $type passes" 0 'ok' -- "$type: add a thing"
done
expect "a scope passes" 0 'ok' -- "fix(install): keep the token out of the remote URL"
# specs/project-contract.md AC-8: the script is a devshop copy every project carries, so it names no
# file that exists only in the devshop.
if grep -nE 'release\.py|devshop-releases' "$script"; then fail "project-contract AC-8: pr-title-check.py names a devshop-only file"; fi
echo "ok - project-contract AC-8: pr-title-check.py names no devshop-only file"
expect "breaking with ! passes" 0 'ok' -- "feat!: projects pin a release tag"
expect "breaking with a scope and ! passes" 0 'ok' -- "feat(upgrade)!: write the tag"
t72="feat: $(printf 'x%.0s' $(seq 66))"
[ ${#t72} = 72 ] || fail "test setup: t72 is ${#t72} characters"
expect "72 characters plus (#123) passes" 0 'ok' -- "$t72 (#123)"
expect "72 characters passes" 0 'ok' -- "$t72"

# AC-1: each bad title fails with its reason.
expect "no prefix fails" 1 'no Conventional Commit type' -- "Every repo keeps a roadmap"
expect "an unknown type fails" 1 "unknown type 'feature'" -- "feature: add a thing"
expect "an upper-case type fails" 1 "unknown type 'Feat'" -- "Feat: add a thing"
expect "no space after the colon fails" 1 'no Conventional Commit type' -- "feat:add a thing"
expect "an empty subject fails" 1 'no Conventional Commit type|empty subject' -- "feat: "
expect "a blank subject fails" 1 'empty subject' -- "feat:    "
expect "73 characters fails" 1 '73 characters' -- "${t72}x"
expect "73 characters plus (#123) fails" 1 '73 characters' -- "${t72}x (#123)"
expect "a second line fails" 1 'one line' -- "$(printf 'feat: a\nb')"
expect "an empty scope fails" 1 'no Conventional Commit type' -- "feat(): add a thing"

# AC-1: no title is a check that couldn't run, never a pass.
expect "no argument can't run" 2 'usage' --
expect "an empty title can't run" 2 'no title' -- ""

# AC-2: CI's fast job runs the check on the PR's title (on a push: the head commit's subject), through
# env, with no `if` or `continue-on-error`; its command, run as CI would, fails a bad title.
python3 -c 'import yaml' 2>/dev/null || fail "PyYAML not found (CI installs it from .github/requirements-ci.txt)"
python3 - "$repo_root/.github/workflows/ci.yml" "$work/step.sh" <<'PY' || fail "AC-2: ci.yml's title step"
import sys, yaml
w = yaml.safe_load(open(sys.argv[1]))
steps = [s for s in w["jobs"]["fast"]["steps"] if "pr-title-check.py" in s.get("run", "")]
assert len(steps) == 1, steps
s = steps[0]
assert "if" not in s and "continue-on-error" not in s, s
assert s["env"]["TITLE"] == "${{ github.event.pull_request.title || github.event.head_commit.message }}", s["env"]
assert "${{" not in s["run"], s["run"]
open(sys.argv[2], "w").write(s["run"])
PY
step() { (cd "$repo_root" && TITLE=$1 bash -e "$work/step.sh") >"$work/out.log" 2>&1; }
step "feat: a feature" || { cat "$work/out.log" >&2; fail "AC-2: the step fails a good title"; }
step "$(printf 'fix: a commit subject (#12)\n\nIts body.')" || { cat "$work/out.log" >&2; fail "AC-2: the step fails a good commit message"; }
! step "A title without a type" || fail "AC-2: the step passes a title without a type"
echo "ok - AC-2: CI's fast job checks the title through env, and its command fails a bad one"
