#!/usr/bin/env bash
# Renders one reviewer verdict file (devshop-review/2) as the PR comment that records it on the PR
# (W10.6.6, TARGET Verify 7, L-25): the result per lens and per acceptance item, tied to the full
# commit it reviewed. The first line is a machine-readable marker (with the sha256 of the PR words
# it reviewed, `words`, or null; W10.6.7); nothing else in the comment can form one, because
# text from the model or the repo has "<" escaped and newlines flattened; "@" and "[" are escaped
# too, so that text can't mention people or render markdown links and images (bare URLs and #123
# references still autolink). Values shown in code spans are kept literal. Short by default (owner,
# 2026-10-13): the headline line shows; spec, tables, findings and reviewer sit in one <details>
# block, which model text can't close early (its "<" is escaped).
#   usage: pr-comment.sh <verdict file>   → the comment's markdown on stdout
# Exit 0 = rendered; 2 = not a readable devshop-review/2 verdict (nothing printed).
set -uo pipefail

[ $# = 1 ] || { echo "usage: pr-comment.sh <verdict file>" >&2; exit 2; }
jq -e '.format == "devshop-review/2" and (.commit | type == "string" and test("^[0-9a-f]{40}$"))
  and (.outcome | IN("pass", "fail", "could-not-run", "ask-owner")) and (.round | type == "number")
  and (.acceptance | type == "array") and (.findings | type == "array") and (.lenses | type == "array")' \
  "$1" >/dev/null 2>&1 || { echo "pr-comment.sh: '$1' is not a devshop-review/2 verdict" >&2; exit 2; }

jq -r '
  # Text from the model or the repo: one line, no HTML, no table breaks, no @mentions, and no
  # markdown links or images ("@" and "[" become entities, which render as themselves). Bare URLs
  # and #123 references still autolink.
  def clean: tostring | gsub("[\r\n]+"; " ") | gsub("<"; "&lt;") | gsub("\\|"; "\\|")
    | gsub("@"; "&#64;") | gsub("\\["; "&#91;");
  # The same inside a code span, where markdown renders nothing and entities would show as typed:
  # one line, and no backtick to end the span early.
  def code: tostring | gsub("[\r\n]+"; " ") | gsub("`"; "\u0027");
  . as $v
  | ([$v.findings[] | select(.severity != "low")]) as $blocking
  | ($v.lenses | map(.lens)) as $named
  | ($v.lenses + [$v.findings[] | .lens | select(IN($named[]) | not) | {lens: ., applies: true, note: ""}]
     | unique_by(.lens) | sort_by(.lens as $l | ["intent","spec","tests","docs","code","security","design","qa","pr"] | index($l) // 99)) as $rows
  | "<!-- devshop-review \({format: $v.format, commit: $v.commit, outcome: $v.outcome, round: $v.round, words: ($v.pr.sha256? // null)} | tojson) -->",
    "**Reviewer: \($v.outcome)** · round \($v.round) · \($v.blocking // ($blocking | length)) blocking, \($v.low // 0) low · commit `\($v.commit[0:12])`",
    "", "<details>", "<summary>Spec, lenses, acceptance items, findings and reviewer</summary>", "",
    (if $v.spec != "" then "Spec: `\($v.spec | code)`"
     elif $v.intent == "pr" then "No spec: reviewed against the PR'"'"'s words"
     else "No spec: reviewed against the commit messages" end),
    (if ($v.reason // "") != "" then "", "Could not run: \($v.reason | clean)" else empty end),
    (if ($rows | length) > 0 then
      "", "| Lens | Applies | Result | Note |", "| --- | --- | --- | --- |",
      ($rows[] | .lens as $l
        | ([$v.findings[] | select(.lens == $l and .severity != "low")] | length) as $b
        | ([$v.findings[] | select(.lens == $l and .severity == "low")] | length) as $lo
        | "| \($l | clean) | \(if .applies then "yes" else "no" end) | \(
            if .applies | not then "—"
            elif $b > 0 then "\($b) blocking" + (if $lo > 0 then ", \($lo) low" else "" end)
            elif $lo > 0 then "\($lo) low" else "pass" end) | \(.note | clean) |")
     else empty end),
    (if ($v.acceptance | length) > 0 then
      "", "| Item | Result | Evidence |", "| --- | --- | --- |",
      ($v.acceptance[] | "| \(.item | clean) | \(if .met then "met" else "**unmet**" end) | \(.evidence | clean) |")
     else empty end),
    (if ($v.findings | length) > 0 then
      "", "Findings:",
      ($v.findings[] | "- **\(.severity | clean)** · \(.lens | clean)\(if (.item // "") != "" then " · " + (.item | clean) else "" end)\(if (.file // "") != "" then " · `" + (.file | code) + "`" else "" end): \(.what | clean) — fix: \(.fix | clean)")
     else empty end),
    "",
    "<sub>Independent reviewer · devshop \($v.reviewer.devshop | clean) · \($v.reviewer.model | clean) · session \($v.reviewer.session_id | clean) · $\($v.reviewer.cost_usd // "?" | clean)</sub>",
    "", "</details>"
' "$1" || { echo "pr-comment.sh: could not render '$1'" >&2; exit 2; }
