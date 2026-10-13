#!/usr/bin/env bash
# The PR's words in one canonical form (W10.6.7): ship.sh writes review.sh's --pr file with it, and
# canonicalizes the PR's title and body as GitHub returns them, so the reviewed words and the PR's
# compare byte for byte (a body GitHub changed after ship set it shows).
#   usage: pr-words.sh < <one JSON object with a string "title" and a string or null "body">
# Stdout: {"title":...,"body":...} on one line (a null body as ""). Other keys are dropped, so a PR
# as GitHub's API returns it works. Exit 0 = done; 2 = not such an object (nothing printed).
set -uo pipefail

jq -cs 'if length == 1 and (.[0] | type == "object" and (.title | type == "string")
      and (.body == null or (.body | type == "string")))
    then .[0] | {title, body: (.body // "")} else error("not one {title, body} object") end' 2>/dev/null \
  || { echo "pr-words.sh: input is not one JSON object with a string title and a string or null body" >&2; exit 2; }
