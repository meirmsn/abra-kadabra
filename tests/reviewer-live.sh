#!/usr/bin/env bash
# Drives the real, pinned reviewer (runtime/reviewer/review.sh, real `claude`, no stub) on the A-04
# fixtures (L-12: at least one test runs the real reviewer path). Not a *.test.sh: it calls a model,
# and CI runs no LLM jobs (D-06), so run it in a session that has `claude` logged in.
#   usage: tests/reviewer-live.sh [runs per case, default 1]
# Each run is a fresh project repo: the base commit holds the spec, the branch adds the case's files
# (src/, test/, package.json). Planted ("seeded": AC-4 skipped, no type check, no test) must fail with exactly AC-4
# unmet; honest must pass with no blocking findings. Prints one line per run and a tally; any miss,
# could-not-run or ask-owner fails the script.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
runs=${1:-1}
[[ "$runs" =~ ^[1-9][0-9]*$ ]] || fail "runs must be a positive integer"
fixtures="$repo_root/tests/fixtures/reviewer"
reviewer="$repo_root/runtime/reviewer/review.sh"
command -v claude >/dev/null || fail "claude not found (this test drives the real reviewer)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
real_home=$HOME
isolate_git "$work"
export HOME=$real_home # claude's login lives in the real HOME; git identity is set per repo below

bad=0
for case in seeded honest; do
  for n in $(seq "$runs"); do
    r="$work/$case-$n"
    git init -q -b main "$r"
    git -C "$r" config user.name "Review Test" && git -C "$r" config user.email "review-test@example.com"
    mkdir -p "$r/specs" && cp "$fixtures/spec.md" "$r/specs/slugify.md"
    git -C "$r" add -A && git -C "$r" commit -qm "Spec: slugify"
    git -C "$r" checkout -qb change/slugify
    cp -r "$fixtures/$case/." "$r/"
    git -C "$r" add -A && git -C "$r" commit -qm "Add slugify()"
    rc=0
    line=$(cd "$r" && "$reviewer" --base main --spec specs/slugify.md 2>"$work/err") || rc=$?
    v=${line##* · }
    unmet="(no verdict)" cost=""
    if [ -f "$v" ]; then
      unmet=$(jq -r '[.acceptance[] | select(.met | not) | .item] | join(",")' "$v")
      cost=$(jq -r '"$\(.reviewer.cost_usd)"' "$v")
    fi
    ok=0
    if [ "$case" = seeded ]; then
      want="exit 1, unmet AC-4"; [ "$rc" != 1 ] || [ "$unmet" != AC-4 ] || ok=1
    else
      want="exit 0, nothing unmet"; [ "$rc" != 0 ] || [ -n "$unmet" ] || ok=1
    fi
    if [ "$ok" = 1 ]; then echo "ok - $case #$n: $line [unmet: ${unmet:-none}] $cost"
    else
      bad=$((bad + 1)); echo "NOT OK - $case #$n: want $want; got exit $rc: $line [unmet: ${unmet:-none}]"
      cat "$work/err"; [ ! -f "$v" ] || jq '{findings, reason}' "$v"
    fi
    # Keep the verdicts for the record when asked (RECORD_DIR is a test-harness output, not a switch).
    [ -z "${RECORD_DIR:-}" ] || [ ! -f "$v" ] || { mkdir -p "$RECORD_DIR" && cp "$v" "$RECORD_DIR/$case-$n.json"; }
  done
done
[ "$bad" = 0 ] || fail "$bad of $((2 * runs)) runs missed"
echo "all $((2 * runs)) live reviewer runs as expected"
