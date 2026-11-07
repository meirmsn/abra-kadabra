#!/usr/bin/env bash
# The skills eval's model tier (specs/skills-eval.md): runs the devshop's skills, as a commit has
# them, in a real devshop session on a scratch project, and grades each run. Not a *.test.sh: it
# calls a model, and CI runs no LLM jobs (D-06). Run it when the skills change, in a cloud session
# where `claude` is logged in; the free tier (skills-check.py --rules) runs in CI on its own.
#   usage: tests/skills-eval.sh [runs, default 1] [case, default trigger]
#   env:   SKILLS_EVAL_REF     the commit under test (default HEAD; then runtime/ must be committed)
#          SKILLS_EVAL_MODEL   a model for the child (default: the CLI's own)
#          SKILLS_EVAL_BUDGET  dollars per owner turn (default 5)
#          DEVSHOP_GIT, DEVSHOP_CURRENT, SKILLS_EVAL_RECORD: the local devshop copy, the shared
#          runtime link and the record of its target (defaults: the environment's; tests override)
# Each run: a fresh `mktemp -d` project placed by project-files.py at the copy's newest release,
# pinned to the commit (fetched into the copy as refs/eval/head) with its devshop copies re-applied,
# committed as the base; then the case's owner turns (tests/skills-eval/cases/<case>.turns), each a
# `claude -p` turn (--resume after the first) in permission mode auto, with the session-tie and
# GitHub credential variables removed (a mitigation: the proxy may still authenticate; the token's
# scope is the wall). tests/skills-eval/grade.py grades it. Results stay in the temp dir, never the
# repo: transcripts carry session ids.
# Prints one line per run, "PASS|FAIL|CNR <case> run <i> sha=<12> model=<id> cli=<v> cost=$<x>
# time=<s>s refused=<n> <reason>", a tally, and "link restored: <target>".
# Exit 1 on any FAIL, else 2 on any CNR (could-not-run), else 0.
# The child's session-start hook re-points the shared runtime link for every session in the
# container (F-NEW-144): the link's target is recorded first, restored on exit, and a record a
# crashed run left is restored before anything else; a link that isn't back is could-not-run.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=${SKILLS_EVAL_REPO:-$(cd "$here/.." && pwd)}
eval_dir="$here/skills-eval"
fixture="$here/fixtures/skills-eval/greeter"
DEVSHOP_GIT=${DEVSHOP_GIT:-/opt/devshop.git}
DEVSHOP_CURRENT=${DEVSHOP_CURRENT:-/opt/devshop-current}
record=${SKILLS_EVAL_RECORD:-$DEVSHOP_CURRENT.skills-eval-record}
budget=${SKILLS_EVAL_BUDGET:-5}
runs=${1:-1}
case=${2:-trigger}

cnr() { echo "CNR $case: $1"; exit 2; }
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || cnr "runs must be a positive integer, got '$runs'"
[[ "$case" =~ ^[a-z0-9-]+$ ]] || cnr "a case name is lower-case letters, digits and dashes"
turns_file="$eval_dir/cases/$case.turns"
[ -f "$turns_file" ] || cnr "unknown case (no $turns_file)"
mapfile -t turns < <(grep -v '^#' "$turns_file" | grep -v '^[[:space:]]*$')
[ ${#turns[@]} -gt 0 ] || cnr "$turns_file has no owner turns"
for tool in claude git jq python3; do command -v "$tool" >/dev/null || cnr "$tool not found"; done
[ -d "$DEVSHOP_GIT" ] || cnr "no local devshop copy at $DEVSHOP_GIT"

ref=${SKILLS_EVAL_REF:-HEAD}
sha=$(git -C "$repo" rev-parse -q --verify "$ref^{commit}") || cnr "'$ref' is not a commit"
if [ -z "${SKILLS_EVAL_REF:-}" ]; then
  dirty=$(git -C "$repo" status --porcelain -- runtime/)
  [ -z "$dirty" ] || cnr "runtime/ has changes HEAD lacks; commit them to test them: $(echo "$dirty" | head -3 | tr '\n' ' ')"
fi

# The shared link: restore a crashed run's record, then record the current target.
if [ -f "$record" ]; then
  stale=$(cat "$record")
  ln -sfn "$stale" "$DEVSHOP_CURRENT" && rm -f "$record" && echo "restored the link a crashed run left: $stale"
fi
orig=$(readlink "$DEVSHOP_CURRENT") || cnr "$DEVSHOP_CURRENT is not a symlink"
printf '%s\n' "$orig" >"$record" || cnr "can't write the link record $record"
work=$(mktemp -d)
# shellcheck disable=SC2329 # invoked by the EXIT trap
restore() {
  ln -sfn "$orig" "$DEVSHOP_CURRENT" 2>/dev/null
  if [ "$(readlink "$DEVSHOP_CURRENT" 2>/dev/null)" = "$orig" ]; then
    rm -f "$record"
    echo "link restored: $orig"
  else
    echo "CNR the link $DEVSHOP_CURRENT is not back at $orig (record kept: $record)"
    exit_code=2
  fi
  rm -rf "$work"
  exit "$exit_code"
}
exit_code=2
trap restore EXIT
trap 'exit' INT TERM HUP

git --git-dir="$DEVSHOP_GIT" fetch -q "$repo" "+$sha:refs/eval/head" 2>"$work/fetch.err" ||
  cnr "couldn't fetch $sha into $DEVSHOP_GIT: $(tr '\n' ' ' <"$work/fetch.err")"
release=$("$repo/install/plugin/devshop/upgrade/latest-release.sh" --devshop-git "$DEVSHOP_GIT" 2>/dev/null) ||
  cnr "no devshop release in $DEVSHOP_GIT to place the project from"
pf="$repo/runtime/scripts/project-files.py"

# place <dir>: the scratch project at the commit under test, committed as the base.
place() {
  local p=$1 f
  mkdir -p "$p" && cp -r "$fixture/." "$p/" || return 1
  git -C "$p" init -q -b main && git -C "$p" config user.name "Eval Owner" &&
    git -C "$p" config user.email "eval-owner@example.com" || return 1
  "$pf" init --devshop-git "$DEVSHOP_GIT" --version "$release" --project "$p" --codeowner eval-owner >/dev/null || return 1
  printf '%s\n' "$sha" >"$p/.devshop-version"
  for f in $("$pf" check --devshop-git "$DEVSHOP_GIT" --version "$sha" --project "$p" | cut -d: -f1); do
    "$pf" apply --devshop-git "$DEVSHOP_GIT" --version "$sha" --project "$p" --file "$f" >/dev/null || return 1
  done
  "$pf" check --devshop-git "$DEVSHOP_GIT" --version "$sha" --project "$p" >/dev/null || return 1
  git -C "$p" add -A && git -C "$p" commit -qm "Initial commit"
}
# turn <project> <stream> <message> [session id]: one owner turn, appended to the stream.
turn() {
  (
    cd "$1" || exit 1
    for v in $(compgen -e); do
      case $v in
        CLAUDE_CODE_*SESSION* | *INGRESS* | *MESSAGING* | CLAUDE_CODE_*SDK* | GH_TOKEN | GITHUB_TOKEN | GIT_ASKPASS | GIT_CONFIG_*) unset "$v" ;;
      esac
    done
    args=(-p "$3" --output-format stream-json --verbose --permission-mode auto --max-budget-usd "$budget")
    [ -z "${SKILLS_EVAL_MODEL:-}" ] || args+=(--model "$SKILLS_EVAL_MODEL")
    [ -z "${4:-}" ] || args+=(--resume "$4")
    CLAUDE_PROJECT_DIR=$1 timeout 3000 claude "${args[@]}" >>"$2" 2>>"$2.err"
  )
}

pass=0 failed=0 couldnt=0 total_cost=0
for i in $(seq "$runs"); do
  p="$work/run-$i/greeter" s="$work/run-$i/stream.jsonl"
  if ! place "$p" >"$work/place.log" 2>&1; then
    line="CNR couldn't place the scratch project: $(tail -c 300 "$work/place.log" | tr '\n' ' ')"
  else
    base=$(git -C "$p" rev-parse HEAD) sid=""
    for msg in "${turns[@]}"; do
      turn "$p" "$s" "$msg" "$sid"
      sid=$(jq -r 'select(.type=="result") | .session_id' "$s" 2>/dev/null | tail -1)
    done
    line=$(python3 "$eval_dir/grade.py" grade --case "$case" --stream "$s" --sha "$sha" --repo "$p" \
      --base "$base" --spec-check "$p/scripts/spec-check.py")
  fi
  facts=$(python3 "$eval_dir/grade.py" facts --stream "$s" 2>/dev/null) ||
    facts="model=? cli=? cost=? time=? refused=?"
  outcome=${line%% *} reason=${line#* }
  cost=$(sed -n 's/.*cost=\([0-9.]*\).*/\1/p' <<<"$facts")
  [ -z "$cost" ] || total_cost=$(python3 -c "print(round($total_cost + $cost, 2))")
  facts=$(sed -e 's/cost=/cost=$/' -e 's/time=\([^ ]*\)/time=\1s/' <<<"$facts")
  echo "$outcome $case run $i sha=${sha:0:12} $facts $reason"
  case $outcome in PASS) pass=$((pass + 1)) ;; FAIL) failed=$((failed + 1)) ;; *) couldnt=$((couldnt + 1)) ;; esac
done
echo "tally: $case: $pass pass, $failed fail, $couldnt could-not-run of $runs; cost \$$total_cost"
if [ "$failed" -gt 0 ]; then exit_code=1; elif [ "$couldnt" -gt 0 ]; then exit_code=2; else exit_code=0; fi
exit "$exit_code"
