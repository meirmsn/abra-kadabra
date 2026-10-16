#!/usr/bin/env bash
# Tests scripts/release.py and .github/workflows/release.yml (spec specs/devshop-releases.md) in a
# scratch repo: the first release is v2.0.0 whatever v1's tags; the bump follows main's first-parent
# Conventional Commit subjects; prepare writes VERSION and CHANGELOG.md; tag-plan plans the tag on
# the release commit, does nothing on a re-run and refuses a VERSION or notes main no longer gives;
# the workflow's own commands, run here with a fake gh, create the tag once.
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
release_commit() { git -C "$r" add -A && git -C "$r" commit -qm "chore(release): v$(cat "$r/VERSION") (#$1)"; }
# fake_github_tag <tag> <sha>: what GitHub does on `gh release create --target`.
fake_github_tag() { git -C "$r" tag "$1" "$2"; }

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

# AC-5: prepare refuses a dirty tree, writing nothing; then writes VERSION and CHANGELOG.md.
echo dirty >"$r/scratch.txt"
run "prepare, dirty" 2 scripts/release.py prepare
[ ! -e "$r/VERSION" ] && [ ! -e "$r/CHANGELOG.md" ] || fail "prepare wrote files on a dirty tree"
rm "$r/scratch.txt"
ok "AC-5: prepare refuses uncommitted changes and writes nothing"
run "prepare v2.0.0" 0 scripts/release.py prepare
[ "$(cat "$r/VERSION")" = 2.0.0 ] || fail "VERSION is '$(cat "$r/VERSION")', want 2.0.0"
grep -qE '^## v2\.0\.0 \([0-9]{4}-[0-9]{2}-[0-9]{2}\)$' "$r/CHANGELOG.md" || fail "CHANGELOG.md has no v2.0.0 heading"
grep -qF -- "- thing one (#3)" "$r/CHANGELOG.md" || fail "CHANGELOG.md lacks the notes"
ok "AC-5: prepare writes VERSION and a dated CHANGELOG.md section"

# AC-6: before the release commit lands there's nothing (no VERSION on main); then it plans the tag
# on the release commit.
git -C "$r" stash -q -u
run "tag-plan, no VERSION" 0 scripts/release.py tag-plan --notes-file "$work/notes.md"
lacks "no VERSION" "tag="
git -C "$r" stash pop -q >/dev/null
release_commit 5
rel1=$(git -C "$r" rev-parse HEAD)
c "docs: a later doc (#6)" # a push holding more than the release commit
run "tag-plan v2.0.0" 0 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "tag-plan v2.0.0" "tag=v2.0.0"
has "tag-plan v2.0.0" "sha=$rel1"
grep -qF -- "- thing one (#3)" "$work/notes.md" || fail "the notes file lacks the notes"
ok "AC-6: tag-plan plans v2.0.0 on the release commit, not the pushed tip"

# AC-7: the workflow's shape, then its own commands run here with a fake gh.
python3 - "$repo_root/.github/workflows/release.yml" "$work/steps" <<'EOF' || fail "AC-7: release.yml's shape"
import sys, yaml, os
w = yaml.safe_load(open(sys.argv[1]))
on = w.get("on", w.get(True))
assert on == {"push": {"branches": ["main"]}}, on
assert w["permissions"] == {"contents": "write"}, w["permissions"]
assert w["concurrency"]["group"] and w["concurrency"]["cancel-in-progress"] is False
(job,) = w["jobs"].values()
assert "if" not in job and "continue-on-error" not in job
co, plan, create = job["steps"]
assert co["uses"].startswith("actions/checkout@") and co["with"]["fetch-depth"] == 0
assert "scripts/release.py tag-plan" in plan["run"] and '>>"$GITHUB_OUTPUT"' in plan["run"]
assert "if" not in plan and "continue-on-error" not in plan
assert create["if"] == "steps.plan.outputs.tag != ''", create.get("if")
assert create["env"]["TAG"] == "${{ steps.plan.outputs.tag }}"
assert create["env"]["SHA"] == "${{ steps.plan.outputs.sha }}"
assert create["run"].startswith('gh release create "$TAG"') and '--target "$SHA"' in create["run"]
os.makedirs(sys.argv[2])
open(f"{sys.argv[2]}/plan.sh", "w").write(plan["run"])
open(f"{sys.argv[2]}/create.sh", "w").write(create["run"])
EOF
ok "AC-7: release.yml runs on push to main with contents: write, one at a time, full clone, tags only when planned"
mkdir -p "$work/bin"
cat >"$work/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$work/gh.log"
# gh release create <tag> ... --target <sha>: GitHub makes the tag.
tag=\$3; sha=\$(sed -n 's/.*--target \([0-9a-f]*\).*/\1/p' <<<"\$*")
git -C "$r" tag "\$tag" "\$sha"
EOF
chmod +x "$work/bin/gh"
# workflow_run: the plan step, then the create step only if a tag was planned (its `if`).
workflow_run() {
  local out tag sha
  out="$work/gh-output"; : >"$out"; mkdir -p "$work/runner"
  (cd "$r" && RUNNER_TEMP="$work/runner" GITHUB_OUTPUT="$out" bash -e "$work/steps/plan.sh") >"$work/out.log" 2>&1 \
    || { cat "$work/out.log" >&2; return 1; }
  tag=$(sed -n 's/^tag=//p' "$out"); sha=$(sed -n 's/^sha=//p' "$out")
  [ -n "$tag" ] || return 0
  (cd "$r" && PATH="$work/bin:$PATH" RUNNER_TEMP="$work/runner" GITHUB_REPOSITORY=example/devshop TAG=$tag SHA=$sha \
    bash -e "$work/steps/create.sh") >>"$work/out.log" 2>&1
}
workflow_run || fail "AC-7: the workflow's steps failed"
[ "$(git -C "$r" rev-parse "v2.0.0^{commit}")" = "$rel1" ] || fail "AC-7: v2.0.0 isn't on the release commit"
grep -qF -- "release create v2.0.0 --repo example/devshop --target $rel1 --title v2.0.0 --notes-file $work/runner/release-notes.md" "$work/gh.log" \
  || { cat "$work/gh.log" >&2; fail "AC-7: gh wasn't called as expected"; }
grep -qF -- "- thing one (#3)" "$work/runner/release-notes.md" || fail "AC-7: the release notes lack the notes"
workflow_run || fail "AC-7: a re-run failed"
[ "$(wc -l <"$work/gh.log")" = 1 ] || fail "AC-7: a re-run called gh again"
ok "AC-7: the workflow's commands tag the release commit once; a re-run does nothing"

# AC-6: with the tag in place, a re-run plans nothing.
run "tag-plan, tagged" 0 scripts/release.py tag-plan --notes-file "$work/notes.md"
lacks "tagged" "tag="
ok "AC-6: tag-plan plans nothing once the tag is on the release commit"

# AC-3: the bump after a release; nothing for non-bumping types or unprefixed subjects.
c "test: a test (#7)"
c "An unprefixed subject (#8)"
run "next, nothing" 1 scripts/release.py next
has "nothing" "nothing to release"
run "prepare, nothing" 1 scripts/release.py prepare
git -C "$r" diff --quiet || fail "prepare with nothing to release changed files"
ok "AC-3 AC-5: nothing to release exits 1 and prepare writes nothing"
c "perf: faster (#9)"
run "next, patch" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v2.0.1 || { cat "$work/out.log" >&2; fail "perf isn't a patch"; }
c "revert: undo a thing (#10)"
run "next, patch" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v2.0.1 || fail "revert isn't a patch"
c "feat(upgrade): a feature (#11)"
run "next, minor" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v2.1.0 || fail "feat isn't minor"
ok "AC-3: perf and revert are a patch, feat is minor"

# AC-5, AC-6: main moves after prepare → tag-plan refuses; another release PR regenerates the section.
run "prepare v2.1.0" 0 scripts/release.py prepare
grep -c '^## v' "$r/CHANGELOG.md" | grep -qx 2 || fail "CHANGELOG.md lost its earlier section"
python3 - "$r/CHANGELOG.md" <<'EOF' || fail "AC-5: sections aren't newest first"
import sys; t = open(sys.argv[1]).read(); assert t.index("## v2.1.0") < t.index("## v2.0.0")
EOF
git -C "$r" stash -q -u
c "feat!: a breaking change lands first (#12)"
git -C "$r" stash pop -q >/dev/null
release_commit 13
run "tag-plan, version moved" 2 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "version moved" "gives 3.0.0"
run "next after the refused release" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v3.0.0 || fail "the breaking change isn't major"
has "breaking group" "### Breaking changes"
has "breaking group" "- a breaking change lands first (#12)"
ok "AC-3 AC-6: a ! is major; tag-plan refuses a VERSION main no longer gives"
run "prepare over the untagged section" 0 scripts/release.py prepare
[ "$(cat "$r/VERSION")" = 3.0.0 ] || fail "prepare didn't move VERSION to 3.0.0"
! grep -q '^## v2\.1\.0' "$r/CHANGELOG.md" || fail "the untagged v2.1.0 section is still there"
grep -q '^## v2\.0\.0' "$r/CHANGELOG.md" || fail "the tagged v2.0.0 section is gone"
release_commit 14
run "tag-plan v3.0.0" 0 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "tag-plan v3.0.0" "tag=v3.0.0"
ok "AC-5 AC-6: prepare replaces an untagged section, and the new release PR plans"
fake_github_tag v3.0.0 "$(git -C "$r" rev-parse HEAD)"

# AC-6: the notes moved but the version didn't → refused.
c "fix: a fix (#15)"
run "prepare v3.0.1" 0 scripts/release.py prepare
git -C "$r" stash -q -u
c "docs: a doc lands first (#16)"
git -C "$r" stash pop -q >/dev/null
release_commit 17
run "tag-plan, notes moved" 2 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "notes moved" "section differs"
ok "AC-6: tag-plan refuses notes main no longer gives"

# AC-6: each other refusal.
printf '3.1\n' >"$r/VERSION" && git -C "$r" commit -qam "chore: bad VERSION"
run "tag-plan, malformed" 2 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "malformed" "not X.Y.Z"
printf '3.0.0\n' >"$r/VERSION" && git -C "$r" commit -qam "chore: VERSION back to a released one"
run "tag-plan, on another commit" 2 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "another commit" "is tagged on"
git -C "$r" tag v3.2.0 HEAD~3
git -C "$r" tag v3.10.0 HEAD~3
printf '3.1.0\n' >"$r/VERSION" && git -C "$r" commit -qam "chore: VERSION below a release"
run "tag-plan, not above" 2 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "not above" "isn't above the existing release v3.10.0"
printf '3.12.0\n' >"$r/VERSION" && git -C "$r" commit -qam "feat: VERSION with no section"
run "tag-plan, no section" 2 scripts/release.py tag-plan --notes-file "$work/notes.md"
has "no section" "no section for v3.12.0"
ok "AC-6: tag-plan refuses a malformed VERSION, a tag elsewhere, a version not above, a missing section"

# AC-3: versions compare as numbers, not text.
git -C "$r" tag v3.9.0 HEAD
c "x" && git -C "$r" tag v3.11.0 HEAD
c "fix: after v3.11.0 (#18)"
run "next, numeric" 0 scripts/release.py next
head -1 "$work/out.log" | grep -qx v3.11.1 || { cat "$work/out.log" >&2; fail "v3.10.0 isn't above v3.9.0"; }
ok "AC-3: v3.11.0 is above v3.9.0"

run "usage" 2 scripts/release.py
has "usage" "usage:"
ok "no command can't run"
