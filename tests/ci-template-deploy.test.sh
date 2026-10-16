#!/usr/bin/env bash
# Tests the deploy comment's wiring in runtime/templates/ci.yml (specs/deploy-and-metrics-comments.md):
# AC-4 (the deploy step with and without scripts/deploy.sh), and the job shapes of AC-8 and AC-9, which
# the reviewer also reads, and AC-10 (the copy a project keeps).
# shellcheck disable=SC2016  # a fake deploy.sh's source: expands when it runs, not here
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
template="$repo_root/runtime/templates/ci.yml"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

python3 -c 'import yaml' 2>/dev/null || fail "PyYAML is not installed"
# step <job> <step id or name>: the step's `run` script.
step() {
  python3 - "$template" "$1" "$2" <<'EOF'
import sys, yaml
jobs = yaml.safe_load(open(sys.argv[1]))["jobs"]
for s in jobs[sys.argv[2]]["steps"]:
    if sys.argv[3] in (s.get("id"), s.get("name")):
        print(s["run"]); break
else:
    sys.exit(f"no step {sys.argv[3]} in {sys.argv[2]}")
EOF
}

# AC-4: with no scripts/deploy.sh the deploy step writes none=yes and succeeds; with one, it runs it.
mkdir -p "$work/p/scripts"
step deploy deploy >"$work/deploy-step.sh"
(cd "$work/p" && GITHUB_OUTPUT="$work/out1" bash -e "$work/deploy-step.sh") >/dev/null || fail "AC-4: the deploy step failed with no deploy.sh"
[ "$(cat "$work/out1")" = "none=yes" ] || fail "AC-4: want none=yes with no deploy.sh, got: $(cat "$work/out1")"
printf '#!/usr/bin/env bash\necho "url=https://app.example.com" >>"$GITHUB_OUTPUT"\n' >"$work/p/scripts/deploy.sh"
chmod +x "$work/p/scripts/deploy.sh"
(cd "$work/p" && GITHUB_OUTPUT="$work/out2" bash -e "$work/deploy-step.sh") >/dev/null || fail "AC-4: the deploy step failed with a deploy.sh"
[ "$(cat "$work/out2")" = "url=https://app.example.com" ] || fail "AC-4: want deploy.sh's outputs only, got: $(cat "$work/out2")"
printf '#!/usr/bin/env bash\nexit 3\n' >"$work/p/scripts/deploy.sh"
! (cd "$work/p" && GITHUB_OUTPUT="$work/out3" bash -e "$work/deploy-step.sh") >/dev/null 2>&1 || fail "AC-4: a failing deploy.sh must fail the step"
echo "ok: AC-4 the deploy step runs scripts/deploy.sh, or writes none=yes without one"

# AC-8, AC-9 (and devshop-deploy AC-4 for this repo's own ci.yml): the jobs' shapes.
cat >"$work/shape.py" <<'EOF'
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
kind = sys.argv[2]  # template | devshop
script = "node scripts/deploy-comment.mjs" if kind == "template" else "node runtime/scripts/deploy-comment.mjs"
jobs = wf["jobs"]
problems = []
def want(cond, msg):
    if not cond: problems.append(msg)
main_if = "github.event_name == 'push' && github.ref == 'refs/heads/main'"
names = lambda j: [s.get("id") or s.get("name") or s.get("uses") for s in jobs[j]["steps"]]
runs = lambda j: [s.get("run", "") for s in jobs[j]["steps"]]
needs = lambda j: (lambda n: [n] if isinstance(n, str) else list(n or []))(jobs[j].get("needs"))
want(set(jobs) == {"fast", "slow", "announce", "deploy", "report"}, f"jobs: {sorted(jobs)}")
for t in ("fast", "slow"):
    want("if" not in jobs[t] and "continue-on-error" not in jobs[t], f"{t} has a job-level if or continue-on-error")
a = jobs["announce"]
want(a.get("if") == main_if and not needs("announce"), "announce: pushes to main only, no needs")
want(any(r.strip() == f"{script} merged" for r in runs("announce")), "announce runs merged")
d = jobs["deploy"]
want(d.get("if") == main_if and sorted(needs("deploy")) == ["fast", "slow"], "deploy: pushes to main, needs fast and slow")
if kind == "template":
    want((d.get("environment") or {}).get("name") == "production", "deploy: environment production")
else:
    want("environment" not in d, "deploy: no environment (nothing is deployed)")
want(d.get("concurrency") == {"group": "production", "cancel-in-progress": False}, "deploy: concurrency group production, not cancelling")
order = [r.strip() for r in runs("deploy")]
idx = lambda needle: next((i for i, r in enumerate(order) if needle in r), -1)
want(0 <= idx("deploy-comment.mjs deploying") < idx("scripts/deploy.sh") < idx("deploy-comment.mjs deployed") < idx("deploy-comment.mjs failed"),
     "deploy: deploying, then scripts/deploy.sh, then deployed and failed")
if kind == "template":
    want(0 <= idx("scripts/setup.sh") < idx("scripts/deploy.sh"), "deploy: scripts/setup.sh before scripts/deploy.sh")
else:
    want(idx("scripts/setup.sh") < 0, "deploy: no setup step (nothing is installed)")
    by_cmd = {c: next((st.get("env") or {} for st in jobs[j]["steps"] if f"deploy-comment.mjs {c}" in st.get("run", "")), {})
              for j, c in (("deploy", "deploying"), ("deploy", "deployed"), ("report", "report"))}
    want(by_cmd["deploying"].get("DEPLOYING_AS") == "Releasing on `main`", "deploy: deploying says Releasing on `main`")
    want(by_cmd["deployed"].get("LIVE_AS") == "Released on `main`" and by_cmd["report"].get("LIVE_AS") == "Released on `main`",
         "deployed and report say Released on `main`")
want(set(d.get("outputs", {})) >= {"url", "version", "previous_version", "rollback", "site_url", "site_smoke", "none"}, "deploy: exposes the slot's outputs")
r = jobs["report"]
want(r.get("if") == "always() && " + main_if and sorted(needs("report")) == ["deploy", "fast", "slow"], "report: if always() on main, needs fast, slow, deploy")
for k in ("FAST", "SLOW", "DEPLOY"):
    want(any(k in (s.get("env") or {}) for s in r["steps"]), f"report passes {k}")
for j in ("announce", "report"):
    want(jobs[j].get("continue-on-error") is True and jobs[j].get("timeout-minutes") == 2, f"{j}: continue-on-error and a 2-minute timeout")
for j in ("announce", "deploy", "report"):
    for s in jobs[j]["steps"]:
        if "deploy-comment.mjs" in s.get("run", ""):
            if j == "deploy":
                want(s.get("continue-on-error") is True and s.get("timeout-minutes") == 1, f"{j}: comment step '{s['name']}' continue-on-error with a 1-minute timeout")
            env = s.get("env") or {}
            want(not any("secrets." in str(v) for v in env.values()), f"{j}: comment step '{s.get('name')}' has a secret")
            want(env.get("GITHUB_TOKEN") == "${{ github.token }}", f"{j}: comment step '{s.get('name')}' uses the job's token")
perms = {j: jobs[j].get("permissions") for j in ("announce", "deploy", "report")}
want(perms["announce"] == {"contents": "read", "pull-requests": "write"}, f"announce permissions {perms['announce']}")
want(perms["deploy"] == {"contents": "read", "pull-requests": "write"}, f"deploy permissions {perms['deploy']}")
want(perms["report"] == {"contents": "read", "pull-requests": "write", "actions": "read"}, f"report permissions {perms['report']}")
text = open(sys.argv[1]).read()
for out in () if kind != "template" else ("url=", "version=", "previous_version=", "rollback=", "deployed=yes", "site_url=", "site_smoke="):
    want(out in text, f"the template's comment doesn't name the output {out}")
if kind == "template":
    want(text.count("# ---") >= 2 or text.count("--- ") >= 2, "the lines a project edits aren't marked")
for p in problems: print("problem:", p)
sys.exit(1 if problems else 0)
EOF
devshop_ci="$repo_root/.github/workflows/ci.yml"
python3 "$work/shape.py" "$template" template || fail "AC-8/AC-9: the template's jobs don't have the spec's shape (above)"
python3 "$repo_root/runtime/scripts/ci-tiers-check.py" "$template" >/dev/null || fail "AC-8: the template fails ci-tiers-check.py"
echo "ok: AC-8, AC-9 the template's comment jobs, deploy slot and outputs"
python3 "$work/shape.py" "$devshop_ci" devshop || fail "devshop-deploy AC-4: this repo's ci.yml doesn't have the shape (above)"
python3 "$repo_root/runtime/scripts/ci-tiers-check.py" "$devshop_ci" >/dev/null || fail "devshop-deploy AC-4: ci.yml fails ci-tiers-check.py"
echo "ok: devshop-deploy AC-4 this repo's ci.yml has the comment jobs"

# The shape check fails on known-bad copies: the template's report without always(), the devshop's
# deploy without its needs, or with the template's script path.
sed 's/if: always() \&\& /if: /' "$template" >"$work/bad.yml"
! python3 "$work/shape.py" "$work/bad.yml" template >/dev/null || fail "the shape check passed a report job without always()"
python3 -c 'import sys,yaml; d=yaml.safe_load(open(sys.argv[1])); d["jobs"]["deploy"].pop("needs"); yaml.safe_dump(d, open(sys.argv[2],"w"))' \
  "$devshop_ci" "$work/bad-devshop.yml"
! python3 "$work/shape.py" "$work/bad-devshop.yml" devshop >/dev/null || fail "devshop-deploy AC-4: the shape check passed a deploy without needs"
sed 's#node runtime/scripts/deploy-comment.mjs merged#node scripts/deploy-comment.mjs merged#' "$devshop_ci" >"$work/bad-devshop2.yml"
! python3 "$work/shape.py" "$work/bad-devshop2.yml" devshop >/dev/null || fail "devshop-deploy AC-4: the shape check passed the wrong script path"

# AC-10: the script is a devshop-owned file: project-files.py passes an identical copy (executable bit
# included) and reports one that differs. Run against this repo's HEAD, so it needs the change committed.
git -C "$repo_root" cat-file -e HEAD:runtime/scripts/deploy-comment.mjs 2>/dev/null \
  || fail "AC-10: runtime/scripts/deploy-comment.mjs isn't committed at HEAD"
grep -qE '^devshop +runtime/scripts/deploy-comment\.mjs +scripts/deploy-comment\.mjs$' "$repo_root/runtime/project-files.txt" \
  || fail "AC-10: runtime/project-files.txt doesn't list deploy-comment.mjs as devshop"
proj="$work/project"
mkdir -p "$proj"
git -C "$proj" init -q
while read -r owner src dst; do
  [ "$owner" = devshop ] || continue
  mkdir -p "$proj/$(dirname "$dst")"
  git -C "$repo_root" show "HEAD:$src" >"$proj/$dst"
  [ "$(git -C "$repo_root" ls-tree HEAD "$src" | cut -c1-6)" != 100755 ] || chmod +x "$proj/$dst"
done <"$repo_root/runtime/project-files.txt"
git -C "$proj" add -A
pf() { python3 "$repo_root/runtime/scripts/project-files.py" check --devshop-git "$(git -C "$repo_root" rev-parse --absolute-git-dir)" --version "$(git -C "$repo_root" rev-parse HEAD)" --project "$proj" >"$work/pf.log" 2>&1; }
pf || { cat "$work/pf.log" >&2; fail "AC-10: an identical copy didn't pass"; }
echo "// changed" >>"$proj/scripts/deploy-comment.mjs"
! pf || fail "AC-10: a changed copy passed"
grep -q 'scripts/deploy-comment.mjs' "$work/pf.log" || { cat "$work/pf.log" >&2; fail "AC-10: the report doesn't name the changed copy"; }
echo "ok: AC-10 deploy-comment.mjs is a devshop-owned copy"

echo "PASS: the template's deploy comment wiring"
