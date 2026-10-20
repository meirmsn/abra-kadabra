#!/usr/bin/env bash
# Tests runtime/scripts/ci-tiers-check.py, the shape check for a project's CI in two tiers (spec
# specs/ci-fast-slow-tiers.md). A workflow with a `fast` job running check-fast.sh "$BASE" and a
# `slow` job needing it and running check-slow.sh passes, and so does the template; each broken
# rule fails, naming it (AC-1, AC-2); a missing or unparseable file, or no PyYAML, can't run.
# specs/project-contract.md AC-7: `fast` also runs the PR title check, and a deploy's `needs` may
# reach the tiers through another job (F-NEW-108); a cycle or an unknown job terminates with 1.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
script="$repo_root/runtime/scripts/ci-tiers-check.py"
template="$repo_root/runtime/templates/ci.yml"
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"
python3 -c 'import yaml' 2>/dev/null || fail "PyYAML not found (CI installs the pinned one)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# check <name> <want exit> <workflow file> [problem the output must name]
check() {
  local rc=0
  "$script" "$3" >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$2" ] || { cat "$work/out.log" >&2; fail "$1: expected exit $2, got $rc"; }
  [ -z "${4:-}" ] || grep -qF -- "$4" "$work/out.log" || { cat "$work/out.log" >&2; fail "$1: output doesn't name '$4'"; }
  echo "ok - $1"
}
# variant <name> <python code changing w, the parsed good workflow>: write the changed copy, echo its path.
variant() {
  python3 -c 'import sys, yaml; w = yaml.safe_load(open(sys.argv[1])); exec(sys.argv[3]); yaml.safe_dump(w, open(sys.argv[2], "w"))' \
    "$work/good.yml" "$work/$1.yml" "$2"
  echo "$work/$1.yml"
}

cat >"$work/good.yml" <<'YAML'
name: ci
on:
  pull_request:
jobs:
  fast:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v5
      - name: PR title
        env:
          TITLE: ${{ github.event.pull_request.title || github.event.head_commit.message }}
        run: scripts/pr-title-check.py "$(head -n 1 <<<"$TITLE")"
      - name: Fast tier
        env:
          BASE: ${{ github.event.pull_request.base.sha || github.event.before }}
        run: scripts/check-fast.sh "$BASE"
  slow:
    needs: fast
    runs-on: ubuntu-24.04
    steps:
      - run: |
          echo "slow tier"
          scripts/check-slow.sh
  deploy:
    needs: [fast, slow]
    environment: production
    runs-on: ubuntu-24.04
    steps:
      - run: echo deploy
YAML

# AC-1: the good shape passes, `needs` as a string or a list.
check "AC-1: a workflow in the two-tier shape passes" 0 "$work/good.yml"
check "AC-1: slow needing fast as a list passes" 0 "$(variant needs-list 'w["jobs"]["slow"]["needs"] = ["fast"]')"
# AC-2: the template passes.
check "AC-2: runtime/templates/ci.yml passes" 0 "$template"

# AC-1: each broken rule fails and is named.
check "AC-1: no fast job fails" 1 "$(variant no-fast 'w["jobs"]["quick"] = w["jobs"].pop("fast"); w["jobs"]["slow"]["needs"] = "quick"')" "no job 'fast'"
check "AC-1: fast not running check-fast.sh fails" 1 "$(variant fast-other 'w["jobs"]["fast"]["steps"][2]["run"] = "npm test"')" "'fast' doesn't run scripts/check-fast.sh \"\$BASE\""
check "AC-1: fast running check-fast.sh without the base fails" 1 "$(variant fast-nobase 'w["jobs"]["fast"]["steps"][2]["run"] = "scripts/check-fast.sh"')" "'fast' doesn't run scripts/check-fast.sh \"\$BASE\""
# shellcheck disable=SC2016  # $BASE is workflow text, not expanded here
check "AC-1: check-fast.sh named only in a comment line fails" 1 "$(variant fast-comment 'w["jobs"]["fast"]["steps"][2]["run"] = "# scripts/check-fast.sh \"$BASE\"\nnpm test"')" "'fast' doesn't run"
# shellcheck disable=SC2016  # as above
check "AC-1: check-fast.sh named only inside another command fails" 1 "$(variant fast-echo 'w["jobs"]["fast"]["steps"][2]["run"] = "echo scripts/check-fast.sh \"$BASE\""')" "'fast' doesn't run"
check "AC-1: the running step with its own if: fails" 1 "$(variant fast-step-if 'w["jobs"]["fast"]["steps"][2]["if"] = "false"')" "'fast' doesn't run"
# specs/project-contract.md AC-7: the title check in fast, and needs followed through other jobs.
check "AC-7: fast without the title step fails, naming the rule" 1 "$(variant no-title 'del w["jobs"]["fast"]["steps"][1]')" "'fast' doesn't run scripts/pr-title-check.py"
check "AC-7: the title step with its own if: fails" 1 "$(variant title-if 'w["jobs"]["fast"]["steps"][1]["if"] = "github.event_name == \"pull_request\""')" "'fast' doesn't run scripts/pr-title-check.py"
check "AC-7: the title step with continue-on-error fails" 1 "$(variant title-coe 'w["jobs"]["fast"]["steps"][1]["continue-on-error"] = True')" "'fast' doesn't run scripts/pr-title-check.py"
check "AC-7: a canary with an environment needing only the deploy passes (F-NEW-108)" 0 "$(variant canary 'w["jobs"]["canary"] = {"needs": "deploy", "environment": "observability", "runs-on": "ubuntu-24.04", "steps": [{"run": "echo canary"}]}')"
check "AC-7: a canary whose needs reach neither tier fails" 1 "$(variant canary-none 'w["jobs"]["lint"] = {"runs-on": "ubuntu-24.04", "steps": [{"run": "echo lint"}]}; w["jobs"]["canary"] = {"needs": ["lint"], "environment": "observability", "runs-on": "ubuntu-24.04", "steps": [{"run": "echo canary"}]}')" "'canary' has an environment but doesn't need 'fast'"
check "AC-7: a needs cycle terminates with 1" 1 "$(variant cycle 'w["jobs"]["a"] = {"needs": "b", "runs-on": "x", "steps": []}; w["jobs"]["b"] = {"needs": "a", "environment": "e", "runs-on": "x", "steps": []}')" "'b' has an environment but doesn't need 'fast'"
check "AC-7: a needs naming a job the workflow lacks fails" 1 "$(variant ghost 'w["jobs"]["deploy"]["needs"] = ["fast", "slow", "ghost"]')" "'deploy' needs 'ghost', which is not a job"
check "AC-1: the running step with its own continue-on-error fails" 1 "$(variant slow-step-coe 'w["jobs"]["slow"]["steps"][0]["continue-on-error"] = True')" "'slow' doesn't run"
check "AC-1: no slow job fails" 1 "$(variant no-slow 'del w["jobs"]["slow"]; w["jobs"]["deploy"]["needs"] = ["fast"]')" "no job 'slow'"
check "AC-1: slow not running check-slow.sh fails" 1 "$(variant slow-other 'w["jobs"]["slow"]["steps"][0]["run"] = "npx playwright test"')" "'slow' doesn't run scripts/check-slow.sh"
check "AC-1: slow not needing fast fails" 1 "$(variant slow-noneeds 'del w["jobs"]["slow"]["needs"]')" "'slow' doesn't need 'fast'"
check "AC-1: slow needing something else fails" 1 "$(variant slow-wrongneeds 'w["jobs"]["slow"]["needs"] = ["lint"]')" "'slow' doesn't need 'fast'"
check "AC-1: a job-level if: on fast fails" 1 "$(variant fast-if 'w["jobs"]["fast"]["if"] = "github.event_name == \"push\""')" "'fast' has a job-level 'if'"
check "AC-1: a job-level if: on slow fails" 1 "$(variant slow-if 'w["jobs"]["slow"]["if"] = "false"')" "'slow' has a job-level 'if'"
check "AC-1: continue-on-error on fast fails" 1 "$(variant fast-coe 'w["jobs"]["fast"]["continue-on-error"] = True')" "'fast' has a job-level 'continue-on-error'"
check "AC-1: continue-on-error on slow fails" 1 "$(variant slow-coe 'w["jobs"]["slow"]["continue-on-error"] = True')" "'slow' has a job-level 'continue-on-error'"
check "AC-1: a deploy not needing slow fails" 1 "$(variant deploy-noslow 'w["jobs"]["deploy"]["needs"] = ["fast"]')" "'deploy' has an environment but doesn't need 'slow'"
check "AC-1: a deploy needing nothing fails" 1 "$(variant deploy-none 'del w["jobs"]["deploy"]["needs"]')" "'deploy' has an environment but doesn't need 'fast'"
check "AC-7: the template passes with its title step" 0 "$template"
grep -q 'scripts/pr-title-check.py' "$template" || fail "AC-7: the template has no title step"

# AC-1: can't run: a missing file, unparseable YAML, no jobs mapping, no PyYAML.
check "AC-1: a missing workflow can't run" 2 "$work/nope.yml" "can't read"
printf 'jobs: [unclosed\n' >"$work/bad.yml"
check "AC-1: unparseable YAML can't run" 2 "$work/bad.yml" "can't parse"
printf 'name: ci\n' >"$work/nojobs.yml"
check "AC-1: a workflow without jobs fails" 1 "$work/nojobs.yml" "no jobs"
mkdir -p "$work/noyaml/yaml"
printf 'raise ImportError("no PyYAML here")\n' >"$work/noyaml/yaml/__init__.py"
rc=0
PYTHONPATH="$work/noyaml" "$script" "$work/good.yml" >"$work/out.log" 2>&1 || rc=$?
{ [ "$rc" = 2 ] && grep -q "PyYAML" "$work/out.log"; } || { cat "$work/out.log" >&2; fail "AC-1: no PyYAML: expected exit 2 naming PyYAML, got $rc"; }
echo "ok - AC-1: no PyYAML can't run (never passes)"
rc=0
"$script" >"$work/out.log" 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "no argument: expected exit 2, got $rc"
echo "ok - no argument can't run"

# AC-6: this repo's own ci.yml passes the check, has the jobs fast and slow (and the deploy comment's), and each job
# sets up what its tier's tests need.
ci="$repo_root/.github/workflows/ci.yml"
check "AC-6: this repo's ci.yml passes" 0 "$ci"
python3 - "$ci" <<'PY' || fail "AC-6: this repo's ci.yml lacks a tier's job or tool (above)"
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))["jobs"]
# fast and slow, plus the deploy comment's jobs (specs/devshop-deploy-comment.md, which supersedes
# "exactly fast and slow").
want_jobs = {"fast", "slow", "announce", "deploy", "report"}
assert set(jobs) == want_jobs, f"jobs are {sorted(jobs)}, want {sorted(want_jobs)}"
want = {
    "fast": ["fetch-depth: 0", "gitleaks", "shellcheck", "dcg", "requirements-ci.txt", "npm ci",
             "apparmor_restrict_unprivileged_userns=0", 'scripts/check-fast.sh "$BASE"'],
    "slow": ["fetch-depth: 0", "apparmor_restrict_unprivileged_userns=0", "command -v jq",
             "scripts/check-slow.sh"],
}
for name, needles in want.items():
    text = yaml.safe_dump(jobs[name], width=1000)
    missing = [n for n in needles if n not in text]
    assert not missing, f"job {name} lacks {missing}"
PY
echo "ok - AC-6: this repo's ci.yml has fast and slow, each with its tier's tools, and the comment jobs"

echo "PASS: ci-tiers-check.py"
