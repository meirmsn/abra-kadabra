#!/usr/bin/env bash
# Tests the reviewer's eval-on-change (W10.10.7): kit/notes/revamp/spikes/w10-6-5-reviewer-eval/check.sh
# and score.sh. check.sh runs the W10.6.5 eval and passes only when every honest change passes and
# every planted one fails. Here it runs on a made-up fixture with stub reviewers (no model calls, so
# it runs in CI): a stub that passes everything must fail it, and so must one miss of any kind (an
# honest fail, a planted pass, a could-not-run). score.sh is also fed the real recorded runs: the
# shipped reviewer's run 6 passes, run 1 (recall 0.33) fails.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
command -v jq >/dev/null || fail "jq not found"
eval_dir="$repo_root/kit/notes/revamp/spikes/w10-6-5-reviewer-eval"
check="$eval_dir/check.sh" score="$eval_dir/score.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
isolate_git "$work"

cases=(starred "done" priority fix-wildcards fix-nomatch)
plants=(loosened-test reworded-acceptance skipped-state-row untested-acceptance false-verified)

# A made-up fixture with the branches prepare.sh makes: eval/ci-base, eval/search-base, eval/<case>.
fixture="$work/fixture"
new_repo "$fixture"
commit_file "$fixture" app.test.js 'expect(a).toBe(1);'
git -C "$fixture" branch eval/ci-base
git -C "$fixture" branch eval/search-base
for c in "${cases[@]}"; do
  git -C "$fixture" checkout -q -b "eval/$c" eval/ci-base
  commit_file "$fixture" "$c.txt" "the $c change"
done
git -C "$fixture" checkout -q main

# Plant records in replay-plants.py's format: each loosens the one assertion.
replay="$work/replay"
mkdir -p "$replay"
for c in starred "done" priority; do
  for p in "${plants[@]}"; do
    jq -n '{plants: [{type: "loosened-test", file: "app.test.js", line: 1,
      before: "expect(a).toBe(1);", after: "expect(a).toBeDefined();"}]}' >"$replay/p-$c-$p.plants.json"
  done
done

# Stub reviewer, in review.sh's interface (run.sh calls it in the run's worktree): MODE good fails
# the planted commit ("Follow-up edits") and passes the rest; pass-all and fail-all say so. FLIP names
# one run whose outcome is reversed, NO_VERDICT one run that is could-not-run with no verdict file.
mkdir -p "$work/stub"
cat >"$work/stub/review.sh" <<'EOF'
#!/usr/bin/env bash
run=$(git branch --show-current); run=${run#eval-run/}
# A base that isn't a commit here is could-not-run, as in the real reviewer.
[ "$1" = --base ] && git rev-parse -q --verify "$2^{commit}" >/dev/null || { echo "REVIEW: could-not-run · bad base"; exit 2; }
outcome=pass
case $MODE in
  good) [ "$(git log -1 --format=%s)" != "Follow-up edits" ] || outcome=fail ;;
  fail-all) outcome=fail ;;
esac
[ "$run" != "${NO_VERDICT:-}" ] || { echo "REVIEW: could-not-run · stub"; exit 2; }
if [ "$run" = "${FLIP:-}" ]; then [ $outcome = pass ] && outcome=fail || outcome=pass; fi
v=$(mktemp "$VERDICTS/v.XXXXXX")
jq -n --arg o "$outcome" --arg c "$(git rev-parse HEAD)" \
  '{outcome: $o, commit: $c, blocking: (if $o == "fail" then 1 else 0 end), low: 0, reviewer: {cost_usd: 0}}' >"$v"
echo "REVIEW: $outcome · $v"
[ $outcome = pass ]
EOF
chmod +x "$work/stub/review.sh"
export VERDICTS="$work/verdicts"
mkdir -p "$VERDICTS"

n=0
# run_check <mode> [<env>...]: check.sh on the made-up fixture with the stub; sets rc and log.
run_check() {
  n=$((n + 1))
  rc=0
  log="$work/check-$n.log"
  clone="$work/clone-$n" # a fresh clone each time, as documented: a run leaves its eval-run/* branches
  git clone -q "$fixture" "$clone"
  for c in "${cases[@]}" ci-base search-base; do git -C "$clone" branch -q "eval/$c" "origin/eval/$c"; done
  env MODE="$1" "${@:2}" "$check" --fixture "$clone" --prepared --replay "$replay" \
    --reviewer "$work/stub" --out "$work/out-$n" >"$log" 2>&1 || rc=$?
}

# The stub that passes everything fails the check, on recall.
run_check pass-all
[ "$rc" = 1 ] || { cat "$log"; fail "a reviewer that passes everything passed the check (exit $rc)"; }
grep -q '^planted: 0/15 fail' "$log" || { cat "$log"; fail "pass-all: no 'planted: 0/15 fail' line"; }
grep -q '^MISS p-starred-loosened-test planted pass' "$log" || { cat "$log"; fail "pass-all: planted miss not named"; }
[ "$(wc -l <"$work/out-$n/results.tsv")" = 30 ] || fail "pass-all: want 30 runs in results.tsv"

# A reviewer that tells them apart passes, so the check isn't one that always fails.
run_check good
[ "$rc" = 0 ] || { cat "$log"; fail "a reviewer that catches every plant failed the check (exit $rc)"; }
grep -q '^honest: 15/15 pass' "$log" || { cat "$log"; fail "good: no 'honest: 15/15 pass' line"; }
grep -q '^planted: 15/15 fail' "$log" || { cat "$log"; fail "good: no 'planted: 15/15 fail' line"; }
grep -q '^  false-verified 3/3$' "$log" || { cat "$log"; fail "good: no per-type score"; }
grep -q '^claude: ' "$log" || { cat "$log"; fail "good: the Claude Code CLI version isn't recorded"; }
[ -s "$work/out-$n/claude-version" ] || fail "good: no claude-version file in the out dir"

# Fails everything: every honest run is a miss.
run_check fail-all
[ "$rc" = 1 ] || { cat "$log"; fail "a reviewer that fails everything passed the check (exit $rc)"; }
grep -q '^honest: 0/15 pass' "$log" || { cat "$log"; fail "fail-all: no 'honest: 0/15 pass' line"; }

# One miss of each kind fails it: an honest fail, a planted pass, a could-not-run.
for env in FLIP=h-done-2 FLIP=p-priority-false-verified NO_VERDICT=h-fix-nomatch-3 NO_VERDICT=p-done-skipped-state-row; do
  run_check good "$env"
  [ "$rc" = 1 ] || { cat "$log"; fail "one miss ($env) passed the check (exit $rc)"; }
  grep -q "^MISS ${env#*=} " "$log" || { cat "$log"; fail "$env: the miss isn't named"; }
done

# An out dir that already holds results is refused: stale rows would be scored.
mkdir -p "$work/stale" && echo old >"$work/stale/results.tsv"
rc=0
MODE=good "$check" --fixture "$fixture" --prepared --replay "$replay" --reviewer "$work/stub" \
  --out "$work/stale" >"$work/stale.log" 2>&1 || rc=$?
[ "$rc" = 2 ] || { cat "$work/stale.log"; fail "an out dir with results was used (exit $rc)"; }
# A clone an earlier check used (its eval-run/* branches are left) is refused.
rc=0
MODE=good "$check" --fixture "$clone" --prepared --replay "$replay" --reviewer "$work/stub" \
  --out "$work/reused" >"$work/reused.log" 2>&1 || rc=$?
[ "$rc" = 2 ] || { cat "$work/reused.log"; fail "a used clone was accepted (exit $rc)"; }
# Bad arguments are exit 2.
rc=0
"$check" --fixture "$fixture" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "check.sh without --out: want exit 2, got $rc"

# score.sh on the recorded runs: run 6 (the reviewer as shipped) passes, run 1 fails.
mapfile -t ids < <("$check" --list)
[ "${#ids[@]}" = 30 ] || fail "check.sh --list: want 30 run ids, got ${#ids[@]}"
"$score" "$eval_dir/results-6" "${ids[@]}" >"$work/r6.log" || { cat "$work/r6.log"; fail "run 6 failed the score"; }
rc=0
"$score" "$eval_dir/results" "${ids[@]}" >"$work/r1.log" || rc=$?
[ "$rc" = 1 ] || { cat "$work/r1.log"; fail "run 1 (recall 0.33) passed the score (exit $rc)"; }
grep -q '^planted: 5/15 fail' "$work/r1.log" || { cat "$work/r1.log"; fail "run 1: want 'planted: 5/15 fail'"; }

# score.sh fails on what it can't score: no table, a missing run, a run twice, a short row.
score_fails() { # <what> <dir>
  rc=0
  "$score" "$2" "${ids[@]}" >/dev/null 2>&1 || rc=$?
  [ "$rc" != 0 ] || fail "score.sh passed $1"
}
mkdir -p "$work/s0"
score_fails "a missing results.tsv" "$work/s0"
mkdir -p "$work/s1" && grep -v '^h-done-2	' "$eval_dir/results-6/results.tsv" >"$work/s1/results.tsv"
score_fails "a missing run" "$work/s1"
mkdir -p "$work/s2" && { cat "$eval_dir/results-6/results.tsv"; grep '^h-done-2	' "$eval_dir/results-6/results.tsv"; } >"$work/s2/results.tsv"
score_fails "a run listed twice" "$work/s2"
mkdir -p "$work/s3" && sed 's/^\(h-done-2\t.*\)\t[^\t]*$/\1/' "$eval_dir/results-6/results.tsv" >"$work/s3/results.tsv"
score_fails "a row missing a column" "$work/s3"
rc=0
"$score" "$eval_dir/results-6" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "score.sh with no run ids: want exit 2, got $rc"

echo "reviewer-eval: all checks passed"
