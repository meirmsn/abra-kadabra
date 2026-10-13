#!/usr/bin/env bash
# Drives the real, pinned reviewer (runtime/reviewer/review.sh, real `claude`, no stub) on the
# fixtures in tests/fixtures/reviewer/ (L-12: at least one test runs the real reviewer path). Not a
# *.test.sh: it calls a model, and CI runs no LLM jobs (D-06), so run it in a session that has
# `claude` logged in.
#   usage: tests/reviewer-live.sh [runs per case, default 1] [case ...]   (default: every case)
# Each run is a fresh project repo: main holds the case's base files, and the branch adds the
# change (and the spec, where the case has one). Cases and what each must give:
#   seeded         spec, AC-4 skipped (A-04)              exit 1, exactly AC-4 unmet
#   honest         spec, honest change, matching PR words  exit 0, nothing unmet
#   words-mismatch honest change, the PR body claims more  exit 1, nothing unmet, a blocking pr finding
#   no-spec        a new feature with no spec (W10.6.6)    exit 1, a blocking intent finding
#   bugfix         an honest bug fix with no spec          exit 0
#   two-specs      two spec files in the change            exit 2 (could-not-run, before any model call)
# Every verdict's reviewer.session_id must be the reviewer's own (W10.6.8, F-NEW-31): non-empty, not
# the calling session's (CLAUDE_CODE_SESSION_ID, CLAUDE_CODE_REMOTE_SESSION_ID) and not another run's,
# so an identity leak shows whatever its cause.
# Prints one line per run and a tally; any miss fails the script.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
runs=${1:-1}
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || fail "runs must be a positive integer"
shift || true
all_cases=(seeded honest words-mismatch no-spec bugfix two-specs)
cases=("${@:-${all_cases[@]}}")
fixtures="$repo_root/tests/fixtures/reviewer"
reviewer="$repo_root/runtime/reviewer/review.sh"
command -v claude >/dev/null || fail "claude not found (this test drives the real reviewer)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
real_home=$HOME
isolate_git "$work"
export HOME=$real_home # claude's login lives in the real HOME; git identity is set per repo below

# setup <repo> <case>: main gets the base files; the branch gets the spec (if any), then the change.
setup() {
  local r=$1 base="" change="" specs=()
  case $2 in
    seeded) change=seeded specs=(slugify) ;;
    honest | words-mismatch) change=honest specs=(slugify) ;;
    no-spec) change=honest ;;
    bugfix) base=bugfix/base change=bugfix/change ;;
    two-specs) change=honest specs=(slugify slugify-copy) ;;
    *) fail "unknown case '$2'" ;;
  esac
  git init -q -b main "$r"
  git -C "$r" config user.name "Review Test" && git -C "$r" config user.email "review-test@example.com"
  if [ -n "$base" ]; then cp -r "$fixtures/$base/." "$r/"; else echo "# app" >"$r/README.md"; fi
  git -C "$r" add -A && git -C "$r" commit -qm "Initial commit"
  git -C "$r" checkout -qb change/slugify
  if [ ${#specs[@]} -gt 0 ]; then
    mkdir -p "$r/specs"
    for s in "${specs[@]}"; do cp "$fixtures/spec.md" "$r/specs/$s.md"; done
    git -C "$r" add -A && git -C "$r" commit -qm "Spec: slugify"
  fi
  cp -r "$fixtures/$change/." "$r/"
  if [ "$2" = bugfix ]; then msg="Fix slugify turning double spaces into double dashes"; else msg="Add slugify()"; fi
  git -C "$r" add -A && git -C "$r" commit -qm "$msg"
}
# words <case>: the --pr file for the case, or nothing.
words() {
  case $1 in
    honest) echo "$fixtures/pr/honest.json" ;;
    words-mismatch) echo "$fixtures/pr/mismatch.json" ;;
    no-spec) echo "$fixtures/pr/feature.json" ;;
    bugfix) echo "$fixtures/pr/bugfix.json" ;;
  esac
}

bad=0 total=0 seen_sessions=" "
caller_sessions=" ${CLAUDE_CODE_SESSION_ID:-} ${CLAUDE_CODE_REMOTE_SESSION_ID:-} "
for case in "${cases[@]}"; do
  for n in $(seq "$runs"); do
    total=$((total + 1))
    r="$work/$case-$n"
    setup "$r" "$case"
    args=(--base main); w=$(words "$case"); [ -z "$w" ] || args+=(--pr "$w")
    rc=0
    line=$(cd "$r" && "$reviewer" "${args[@]}" 2>"$work/err") || rc=$?
    v=${line##* · }
    unmet="(no verdict)" blocking_lenses="" cost="" sid="" called=false
    if [ -f "$v" ]; then
      unmet=$(jq -r '[.acceptance[] | select(.met | not) | .item] | join(",")' "$v")
      blocking_lenses=$(jq -r '[.findings[] | select(.severity != "low") | .lens] | unique | join(",")' "$v")
      cost=$(jq -r '"$\(.reviewer.cost_usd)"' "$v")
      sid=$(jq -r '.reviewer.session_id' "$v") called=$(jq '.reviewer.cost_usd != null' "$v")
    fi
    has() { [[ ",$blocking_lenses," == *",$1,"* ]]; }
    ok=0
    case $case in
      seeded) want="exit 1, unmet AC-4"; [ "$rc" != 1 ] || [ "$unmet" != AC-4 ] || ok=1 ;;
      honest | bugfix) want="exit 0, nothing unmet"; [ "$rc" != 0 ] || [ -n "$unmet" ] || ok=1 ;;
      words-mismatch) want="exit 1, nothing unmet, a blocking pr finding"; [ "$rc" != 1 ] || [ -n "$unmet" ] || ! has pr || ok=1 ;;
      no-spec) want="exit 1, a blocking intent finding"; [ "$rc" != 1 ] || ! has intent || ok=1 ;;
      two-specs) want="exit 2, two spec files"; [ "$rc" != 2 ] || ! grep -q "2 spec files" "$work/err" || ok=1 ;;
    esac
    # A model was called (a verdict with a cost): its session id is the reviewer's own.
    if [ "$ok" = 1 ] && [ "$called" = true ]; then
      if [ -z "$sid" ] || [[ "$caller_sessions" == *" $sid "* ]] || [[ "$seen_sessions" == *" $sid "* ]]; then
        ok=0 want="$want, and a session id of its own (got '$sid')"
      fi
      seen_sessions+="$sid "
    fi
    if [ "$ok" = 1 ]; then echo "ok - $case #$n: $line [unmet: ${unmet:-none}; blocking: ${blocking_lenses:-none}] $cost"
    else
      bad=$((bad + 1)); echo "NOT OK - $case #$n: want $want; got exit $rc: $line [unmet: ${unmet:-none}; blocking: ${blocking_lenses:-none}]"
      cat "$work/err"; [ ! -f "$v" ] || jq '{findings, reason}' "$v"
    fi
    # Keep the verdicts for the record when asked (RECORD_DIR is a test-harness output, not a switch).
    [ -z "${RECORD_DIR:-}" ] || [ ! -f "$v" ] || { mkdir -p "$RECORD_DIR" && cp "$v" "$RECORD_DIR/$case-$n.json"; }
  done
done
[ "$bad" = 0 ] || fail "$bad of $total runs missed"
echo "all $total live reviewer runs as expected"
