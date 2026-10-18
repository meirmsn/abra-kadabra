#!/usr/bin/env bash
# Drives the real, pinned reviewer (runtime/reviewer/review.sh, real `claude`, no stub) with its
# browser on a small site, tests/fixtures/reviewer-browser/ (spec specs/reviewer-browser.md, AC-7).
# Not a *.test.sh: it calls a model, and CI runs no LLM jobs (D-06), so run it in a session that has
# `claude` logged in, after `npm ci` (the site's Playwright is this repo's pinned one).
#   usage: tests/reviewer-browser-live.sh [case ...]   (default: every case)
# Each run is a fresh project repo: main holds base/ (a home page, styles.css, DESIGN.md and a
# scripts/local-run.sh serving the files), and the branch adds the spec, then the notes page. Cases:
#   honest            the notes page built to DESIGN.md         exit 0, nothing blocking
#   planted-font      card titles in a serif DESIGN.md rules out exit 1, a blocking design finding on the font
#   planted-spacing   card padding of 13px, off the 4px scale    exit 1, a blocking design finding on the spacing
#   planted-overflow  three fixed 180px columns at 375px          exit 1, a blocking design or qa finding on the overflow
# Every verdict's reviewer.session_id must be the reviewer's own, as in tests/reviewer-live.sh.
# Prints one line per run, the design and qa notes, and a tally; any miss fails the script.
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
source "$repo_root/tests/lib.sh"
all_cases=(honest planted-font planted-spacing planted-overflow)
cases=("${@:-${all_cases[@]}}")
fixtures="$repo_root/tests/fixtures/reviewer-browser"
reviewer="$repo_root/runtime/reviewer/review.sh"
command -v claude >/dev/null || fail "claude not found (this test drives the real reviewer)"
[ -d "$repo_root/node_modules/playwright" ] || fail "Playwright not installed (npm ci)"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
real_home=$HOME
isolate_git "$work"
export HOME=$real_home # claude's login lives in the real HOME; git identity is set per repo below

# setup <repo> <case>: main gets base/; the branch gets the spec, then the honest page with the
# case's files over it. node_modules is linked as a session's install would be, and ignored.
setup() {
  local r=$1
  git init -q -b main "$r"
  git -C "$r" config user.name "Review Test" && git -C "$r" config user.email "review-test@example.com"
  cp -r "$fixtures/base/." "$r/"
  printf 'node_modules\n' >"$r/.gitignore"
  echo '{ "private": true }' >"$r/package.json"
  git -C "$r" add -A && git -C "$r" commit -qm "Initial commit"
  git -C "$r" checkout -qb change/notes
  mkdir -p "$r/specs" && cp "$fixtures/spec.md" "$r/specs/notes.md"
  git -C "$r" add -A && git -C "$r" commit -qm "Spec: a notes page"
  cp -r "$fixtures/honest/." "$r/"
  [ "$2" = honest ] || cp -r "$fixtures/$2/." "$r/"
  git -C "$r" add -A && git -C "$r" commit -qm "Add the notes page"
  ln -s "$repo_root/node_modules" "$r/node_modules"
}

bad=0 total=0 seen_sessions=" "
caller_sessions=" ${CLAUDE_CODE_SESSION_ID:-} ${CLAUDE_CODE_REMOTE_SESSION_ID:-} "
for case in "${cases[@]}"; do
  total=$((total + 1))
  r="$work/$case"
  case $case in
    honest) want="exit 0, nothing blocking" ;;
    planted-font) want="exit 1, a blocking design finding on the font" pattern='font|serif|georgia' ;;
    planted-spacing) want="exit 1, a blocking design finding on the spacing" pattern='13 ?px|spacing|scale|step' ;;
    planted-overflow) want="exit 1, a blocking design or qa finding on the overflow" pattern='overflow|sideways|scroll|edge|wider|375' ;;
    *) fail "unknown case '$case'" ;;
  esac
  setup "$r" "$case"
  rc=0
  line=$(cd "$r" && "$reviewer" --base main 2>"$work/err") || rc=$?
  v=${line##* · }
  ok=0 sid="" cost=""
  if [ -f "$v" ]; then
    sid=$(jq -r '.reviewer.session_id' "$v") cost=$(jq -r '"$\(.reviewer.cost_usd)"' "$v")
    case $case in
      honest) [ "$rc" != 0 ] || [ "$(jq .blocking "$v")" != 0 ] || ok=1 ;;
      planted-overflow)
        [ "$rc" != 1 ] || ! jq -e --arg p "$pattern" 'any(.findings[]; .severity != "low" and (.lens | IN("design", "qa")) and ((.what + " " + .fix) | test($p; "i")))' "$v" >/dev/null || ok=1 ;;
      *)
        [ "$rc" != 1 ] || ! jq -e --arg p "$pattern" 'any(.findings[]; .severity != "low" and .lens == "design" and ((.what + " " + .fix) | test($p; "i")))' "$v" >/dev/null || ok=1 ;;
    esac
    if [ "$ok" = 1 ] && { [ -z "$sid" ] || [[ "$caller_sessions" == *" $sid "* ]] || [[ "$seen_sessions" == *" $sid "* ]]; }; then
      ok=0 want="$want, and a session id of its own (got '$sid')"
    fi
    seen_sessions+="$sid "
  fi
  if [ "$ok" = 1 ]; then echo "ok - $case: $line $cost"
  else
    bad=$((bad + 1)); echo "NOT OK - $case: want $want; got exit $rc: $line"
    cat "$work/err"
  fi
  [ ! -f "$v" ] || jq -r '(.lenses[] | select(.lens | IN("design", "qa")) | "  \(.lens): \(.note)"), (.findings[] | "  finding \(.severity) \(.lens) \(.file): \(.what)")' "$v"
  # Keep the verdicts for the record when asked (RECORD_DIR is a test-harness output, not a switch).
  [ -z "${RECORD_DIR:-}" ] || [ ! -f "$v" ] || { mkdir -p "$RECORD_DIR" && cp "$v" "$RECORD_DIR/$case.json"; }
done
[ "$bad" = 0 ] || fail "$bad of $total runs missed"
echo "all $total live reviewer-browser runs as expected"
