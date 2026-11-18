#!/usr/bin/env bash
# F-NEW-163: every PR ran CI twice on one head (the `opened` and `synchronize` events of one push).
# Both workflows, this repo's and the project template, put a PR's runs in one group per PR that
# cancels the older run, and give every run on `main` a group of its own that cancels nothing, so a
# merge's deploy and comment jobs are never cancelled or dropped as a pending run.
# shellcheck disable=SC2016  # the workflows' ${{ }} expressions are GitHub's, never expanded here
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
python3 -c 'import yaml' 2>/dev/null || fail "PyYAML is not installed"

# check <workflow>: exit 0 when its top-level concurrency has the shape, else the reason on stderr.
check() {
  python3 - "$1" <<'PY'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
c = wf.get("concurrency")
if not isinstance(c, dict):
    sys.exit("no top-level concurrency group")
want_group = "ci-${{ github.event_name == 'pull_request' && github.event.pull_request.number || github.run_id }}"
want_cancel = "${{ github.event_name == 'pull_request' }}"
if c.get("group") != want_group:
    sys.exit(f"group is {c.get('group')!r}, want {want_group!r}")
if c.get("cancel-in-progress") != want_cancel:
    sys.exit(f"cancel-in-progress is {c.get('cancel-in-progress')!r}, want {want_cancel!r}")
PY
}

for wf in .github/workflows/ci.yml runtime/templates/ci.yml; do
  check "$repo_root/$wf" || fail "F-NEW-163: $wf: PR runs on one head aren't deduplicated (above)"
done
echo "ok - F-NEW-163: both workflows cancel an older run of the same PR and never a run on main"

# The check itself fails on a known-bad workflow: none, a per-ref group that would queue main's runs,
# and cancel-in-progress true on every event.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
bad() { printf '%s\n' "$2" >"$work/wf.yml"; ! check "$work/wf.yml" 2>/dev/null || fail "the check passed $1"; }
bad "no concurrency" 'on: [pull_request]'
bad "a group per ref" $'concurrency:\n  group: ci-${{ github.ref }}\n  cancel-in-progress: ${{ github.event_name == \'pull_request\' }}'
bad "cancel on main too" $'concurrency:\n  group: ci-${{ github.event_name == \'pull_request\' && github.event.pull_request.number || github.run_id }}\n  cancel-in-progress: true'
echo "ok - the concurrency check fails a workflow without the shape"
