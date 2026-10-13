#!/usr/bin/env bash
# Tallies one eval run's verdicts (W10.6.8): precision, recall, every blocking finding of each
# planted fail (to check by eye that it names the plant), any finding about not running the tests or
# confirming CI, verdicts that mention a refused command, and the session ids (all distinct, none the
# caller's: pass the caller's ids as arguments).
#   usage: tally.sh <results dir> [<caller session id> ...]
set -euo pipefail
dir=$1; shift
honest=("$dir"/h-*.verdict.json) planted=("$dir"/p-*.verdict.json)
count() { jq -s --arg o "$1" '[.[] | select(.outcome == $o)] | length' "${@:2}"; }
hp=$(count pass "${honest[@]}") hf=$(count fail "${honest[@]}")
pp=$(count pass "${planted[@]}") pf=$(count fail "${planted[@]}")
echo "honest: ${#honest[@]} runs, $hp pass, $hf fail · planted: ${#planted[@]} runs, $pf fail, $pp pass"
echo "precision: $pf / $((pf + hf)) · recall: $pf / ${#planted[@]}"
echo "unsure findings: $(jq -s '[.[].findings[] | select(.severity == "unsure")] | length' "$dir"/*.verdict.json)"
echo "cost: \$$(jq -s '[.[].reviewer.cost_usd // 0] | add * 100 | round / 100' "$dir"/*.verdict.json)"
echo "== blocking items of each planted run"
for f in "${planted[@]}"; do
  jq -r --arg id "$(basename "$f" .verdict.json)" '"\($id) [\(.outcome)]: " +
    ([(.acceptance[] | select(.met | not) | "unmet \(.item)"), (.findings[] | select(.severity != "low") | "\(.severity)/\(.lens): \(.what[0:110])")] | join(" | "))' "$f"
done
echo "== findings about running the tests or confirming CI (any severity)"
jq -r 'input_filename as $f | .findings[] | select((.what + " " + .fix) | test("(could ?n.t|cannot|unable to|not able to) run (the )?tests|run the (test suite|tests)|confirm.{0,20}(CI|green)|CI (run|result)s? (is|are) green"; "i"))
  | "\($f | split("/")[-1]): \(.severity)/\(.lens): \(.what[0:120]) -> \(.fix[0:80])"' "$dir"/*.verdict.json || true
echo "== verdicts that mention a refused command"
grep -liE "refused|denied|not (allowed|permitted)|permission" "$dir"/*.verdict.json | xargs -r -n1 basename || true
echo "== session ids"
ids=$(jq -r '.reviewer.session_id' "$dir"/*.verdict.json)
echo "$(wc -l <<<"$ids") verdicts, $(sort -u <<<"$ids" | wc -l) distinct, $(grep -c '^$' <<<"$ids" || true) empty"
for c in "$@"; do ! grep -qxF "$c" <<<"$ids" || echo "CALLER'S SESSION ID FOUND: $c"; done
