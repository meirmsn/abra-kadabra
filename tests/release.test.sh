#!/usr/bin/env bash
# Tests scripts/release.py and .github/workflows/release.yml (spec specs/devshop-releases.md) in a
# scratch repo: the first release is v2.0.0 whatever v1's tags; the bump follows main's first-parent
# Conventional Commit subjects; plan names the tag for main's head and writes its notes, or says
# there's nothing to release; the workflow is a button only the repo's owner can press on main, and
# its own commands, run here with a fake gh, create the tag once.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v python3 >/dev/null || fail "python3 not found"
python3 -c 'import yaml' 2>/dev/null || fail "PyYAML not found (CI installs it from .github/requirements-ci.txt)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"
r="$work/repo"

# run <name> <want exit> <cmd...>: run in the scratch repo, output in $work/out.log.
run() {
  local name=$1 want=$2 rc=0
  shift 2
  (cd "$r" && "$@") >"$work/out.log" 2>&1 || rc=$?
  [ "$rc" = "$want" ] || { cat "$work/out.log" >&2; fail "$name: expected exit $want, got $rc"; }
}
has() { grep -qF -- "$2" "$work/out.log" || { cat "$work/out.log" >&2; fail "$1: output lacks '$2'"; }; }
lacks() { ! grep -qF -- "$2" "$work/out.log" || { cat "$work/out.log" >&2; fail "$1: output has '$2'"; }; }
ok() { echo "ok - $1"; }
c() { git -C "$r" commit -q --allow-empty -m "$1"; }

# A main with v1's history: v1 tags, then v2 subjects with and without prefixes, and a merge whose
# second parent holds a breaking subject that never landed on main's first-parent line.
git init -q "$r"
mkdir -p "$r/scripts"
cp "$repo_root/scripts/release.py" "$r/scripts/"
git -C "$r" add -A && git -C "$r" commit -qm "v1's last commit"
git -C "$r" tag v1.10.2
git -C "$r" tag v1-final
c "Old style subject without a prefix (#1)"
c "docs: a doc (#2)"
git -C "$r" checkout -qb side && c "feat!: only on a side branch" && git -C "$r" checkout -q main
git -C "$r" merge -q --no-ff -m "Merge branch side" side
c "feat: thing one (#3)"
c "fix(install): thing two (#4)"

# AC-3, AC-4: the first release is v2.0.0 (v1's tags don't count); notes in groups, prefixes off.
run "next, first release" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx 'v2.0.0' || { cat "$work/out.log" >&2; fail "first release isn't v2.0.0"; }
has "first release notes" "### Features"
has "first release notes" "- thing one (#3)"
has "first release notes" "### Fixes"
has "first release notes" "- thing two (#4)"
has "first release notes" "### Other changes"
has "first release notes" "- Old style subject without a prefix (#1)"
has "first release notes" "- a doc (#2)"
lacks "first release notes" "Breaking changes"
lacks "first release notes" "only on a side branch"
lacks "first release notes" "feat: thing one"
ok "AC-3 AC-4: the first release is v2.0.0, notes grouped in history order without prefixes, side commits left out"
python3 - "$work/out.log" <<'EOF' || fail "AC-4: groups out of order or subjects out of history order"
import sys
t = open(sys.argv[1]).read()
order = ["### Features", "### Fixes", "### Other changes"]
assert [t.index(g) for g in order] == sorted(t.index(g) for g in order)
assert t.index("Old style subject") < t.index("a doc (#2)") < t.index("Merge branch side")
EOF
ok "AC-4: groups in order, subjects in history order"

# AC-3: a clone with no tags or a shallow one can't run (each would cut the history short).
git clone -q --no-tags "file://$r" "$work/notags"
rc=0; (cd "$work/notags" && scripts/release.py next) >"$work/out.log" 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "a clone without tags: want exit 2, got $rc"
has "no tags" "git fetch --tags"
git clone -q --depth 2 "file://$r" "$work/shallow"
rc=0; (cd "$work/shallow" && git fetch -q --tags && scripts/release.py next) >"$work/out.log" 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "a shallow clone: want exit 2, got $rc"
has "shallow" "shallow"
ok "AC-3: a clone without tags or a shallow clone can't run"

# AC-5: plan names the tag for main's head and writes the notes.
run "plan v2.0.0" 0 scripts/release.py plan --notes-file "$work/notes.md"
has "plan v2.0.0" "tag=v2.0.0"
has "plan v2.0.0" "sha=$(git -C "$r" rev-parse HEAD)"
grep -qF -- "- thing one (#3)" "$work/notes.md" || fail "the notes file lacks the notes"
[ -z "$(git -C "$r" status --porcelain)" ] || fail "plan changed files in the repo"
ok "AC-5: plan prints the tag and main's head SHA, writes the notes, touches nothing in the repo"

# AC-6: no other command; nothing writes VERSION or CHANGELOG.md.
for cmd in prepare tag-plan; do
  run "no $cmd" 2 scripts/release.py "$cmd"
  has "no $cmd" "usage:"
done
[ ! -e "$r/VERSION" ] && [ ! -e "$r/CHANGELOG.md" ] || fail "AC-6: a VERSION or CHANGELOG.md appeared"
run "usage" 2 scripts/release.py
has "usage" "usage:"
ok "AC-6: next and plan are the only commands; no VERSION or CHANGELOG.md"

# AC-7: the workflow's shape.
python3 - "$repo_root/.github/workflows/release.yml" "$work/steps" <<'EOF' || fail "AC-7: release.yml's shape"
import sys, yaml, os
w = yaml.safe_load(open(sys.argv[1]))
on = w.get("on", w.get(True))
assert list(on) == ["workflow_dispatch"], on
assert w["permissions"] == {"contents": "write"}, w["permissions"]
assert w["concurrency"]["group"] and w["concurrency"]["cancel-in-progress"] is False
(job,) = w["jobs"].values()
assert "if" not in job and "continue-on-error" not in job
guard, co, plan, create = job["steps"]
for s in (guard, co, plan, create):
    assert "if" not in s and "continue-on-error" not in s, s
assert guard["env"] == {"REF": "${{ github.ref }}", "ACTOR": "${{ github.actor }}",
                        "TRIGGERING_ACTOR": "${{ github.triggering_actor }}",
                        "OWNER": "${{ github.repository_owner }}"}, guard["env"]
assert co["uses"].startswith("actions/checkout@") and co["with"]["fetch-depth"] == 0
assert plan["id"] == "plan" and "scripts/release.py plan" in plan["run"] and '>>"$GITHUB_OUTPUT"' in plan["run"]
assert create["env"]["TAG"] == "${{ steps.plan.outputs.tag }}"
assert create["env"]["SHA"] == "${{ steps.plan.outputs.sha }}"
assert create["run"].startswith('gh release create "$TAG"') and '--target "$SHA"' in create["run"]
for s in (guard, plan, create):
    assert "${{" not in s["run"], s["run"]
os.makedirs(sys.argv[2])
for name, s in (("guard", guard), ("plan", plan), ("create", create)):
    open(f"{sys.argv[2]}/{name}.sh", "w").write(s["run"])
EOF
ok "AC-7: release.yml is a button (workflow_dispatch), contents: write, one at a time, full clone, every value through env"

# AC-7: the guard lets only the owner release, from main; a re-run by someone else fails.
guard() { (REF=$1 ACTOR=$2 TRIGGERING_ACTOR=$3 OWNER=${4-owner-x} bash -e "$work/steps/guard.sh") >"$work/out.log" 2>&1; }
guard refs/heads/main owner-x owner-x || { cat "$work/out.log" >&2; fail "AC-7: the guard refuses the owner on main"; }
! guard refs/heads/main agent-y agent-y || fail "AC-7: the guard lets another actor release"
has "another actor" "only the repository's owner"
! guard refs/heads/main owner-x agent-y || fail "AC-7: the guard lets another actor re-run the owner's run"
! guard refs/heads/feature owner-x owner-x || fail "AC-7: the guard releases from a branch other than main"
has "another branch" "only from main"
! guard refs/heads/main agent-y owner-x || fail "AC-7: the guard lets the owner re-run another actor's run"
! guard refs/heads/main "" "" || fail "AC-7: the guard passes with no actor"
! guard refs/heads/main "" "" "" || fail "AC-7: the guard passes with no actor and no owner"
ok "AC-7: the guard passes only the owner on main; another actor, a re-run either way, another branch, no actor or no owner fail"

# AC-7: the workflow's commands, run here with a fake gh, create the tag once.
mkdir -p "$work/bin" "$work/runner"
cat >"$work/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$work/gh.log"
# gh release create <tag> ... --target <sha>: GitHub makes the tag.
tag=\$3; sha=\$(sed -n 's/.*--target \([0-9a-f]*\).*/\1/p' <<<"\$*")
git -C "$r" tag "\$tag" "\$sha"
EOF
chmod +x "$work/bin/gh"
# workflow_run: plan, then create (a failing step ends the run, as on GitHub).
workflow_run() {
  local out="$work/gh-output" tag sha
  : >"$out"
  (cd "$r" && RUNNER_TEMP="$work/runner" GITHUB_OUTPUT="$out" bash -e "$work/steps/plan.sh") >"$work/out.log" 2>&1 || return 1
  tag=$(sed -n 's/^tag=//p' "$out"); sha=$(sed -n 's/^sha=//p' "$out")
  (cd "$r" && PATH="$work/bin:$PATH" RUNNER_TEMP="$work/runner" GITHUB_REPOSITORY=example/devshop TAG=$tag SHA=$sha \
    bash -e "$work/steps/create.sh") >>"$work/out.log" 2>&1
}
head1=$(git -C "$r" rev-parse HEAD)
workflow_run || { cat "$work/out.log" >&2; fail "AC-7: the workflow's steps failed"; }
[ "$(git -C "$r" rev-parse "v2.0.0^{commit}")" = "$head1" ] || fail "AC-7: v2.0.0 isn't on main's head"
grep -qF -- "release create v2.0.0 --repo example/devshop --target $head1 --title v2.0.0 --notes-file $work/runner/release-notes.md" "$work/gh.log" \
  || { cat "$work/gh.log" >&2; fail "AC-7: gh wasn't called as expected"; }
grep -qF -- "- thing one (#3)" "$work/runner/release-notes.md" || fail "AC-7: the release notes lack the notes"
ok "AC-7: the workflow's commands tag main's head v2.0.0 with the notes"
! workflow_run || fail "AC-5 AC-7: a second run on a released head didn't fail"
has "second run" "nothing to release"
[ "$(wc -l <"$work/gh.log")" = 1 ] || fail "AC-7: a second run called gh again"
ok "AC-5 AC-7: a second run on the same head fails with nothing to release and creates nothing"

# AC-3: the bump after a release; nothing for non-bumping types or unprefixed subjects.
c "test: a test (#7)"
c "An unprefixed subject (#8)"
run "next, nothing" 1 scripts/release.py next
has "nothing" "nothing to release"
run "plan, nothing" 1 scripts/release.py plan --notes-file "$work/none.md"
[ ! -e "$work/none.md" ] || fail "plan wrote notes with nothing to release"
ok "AC-3 AC-5: nothing to release exits 1 and plan writes nothing"
c "perf: faster (#9)"
run "next, patch" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v2.0.1 || { cat "$work/out.log" >&2; fail "perf isn't a patch"; }
c "revert: undo a thing (#10)"
run "next, patch" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v2.0.1 || fail "revert isn't a patch"
c "feat(upgrade): a feature (#11)"
run "next, minor" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v2.1.0 || fail "feat isn't minor"
lacks "after a release" "thing one"
c "feat!: a breaking change (#12)"
run "next, major" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v3.0.0 || fail "a ! isn't major"
has "breaking group" "### Breaking changes"
has "breaking group" "- a breaking change (#12)"
ok "AC-3 AC-4: perf and revert are a patch, feat minor, ! major; notes start after the last release"

# AC-3: versions compare as numbers, not text.
git -C "$r" tag v3.9.0 HEAD
c "x" && git -C "$r" tag v3.11.0 HEAD
c "fix: after v3.11.0 (#13)"
run "next, numeric" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v3.11.1 || { cat "$work/out.log" >&2; fail "v3.11.0 isn't above v3.9.0"; }
ok "AC-3: v3.11.0 is above v3.9.0"

# AC-5: a computed tag that already exists elsewhere (main doesn't reach it) is refused, not reused.
git -C "$r" checkout -qb stray && c "stray" && git -C "$r" tag v3.11.1 && git -C "$r" checkout -q main
run "plan, tag exists elsewhere" 2 scripts/release.py plan --notes-file "$work/stray.md"
has "tag exists elsewhere" "v3.11.1 already exists"
ok "AC-5: plan refuses a version whose tag already exists on a commit main doesn't reach"
