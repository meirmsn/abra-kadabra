#!/usr/bin/env bash
# Commit identity check run by CI (L-41): rejects commits made under a test identity, i.e. an author
# or committer email at a domain reserved for examples and tests (RFC 2606/6761: example.com/.net/
# .org and their subdomains, the .example .test .invalid .localhost TLDs, localhost), or at test.com,
# the domain of v1's fixture identity that leaked 19 commits into v1's history. Tests commit as such
# an identity (tests/lib.sh), so a test that leaks commits into a real repo is caught.
# Usage: scripts/commit-identity-check.sh [base-sha]   (run from the repo to check)
#   base-sha given → checks base..HEAD; empty or all zeros (new branch) → all of HEAD's history.
# Exit 0 = none found; 1 = test-identity commits found; 2 = can't run (unknown base, not a repo).
set -euo pipefail

base=${1:-}
git rev-parse -q --verify 'HEAD^{commit}' >/dev/null 2>&1 || { echo "FAIL: not in a git repository with commits" >&2; exit 2; }
if [ -z "$base" ] || [ "$base" = 0000000000000000000000000000000000000000 ]; then
  range=HEAD
else
  git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "FAIL: unknown base $base" >&2; exit 2; }
  range="$base..HEAD"
fi

reserved='@((.+\.)?example\.(com|net|org)|(.+\.)?localhost|.+\.(example|test|invalid)|test\.com)$'
log=$(git log --format='%h%x09%ae%x09%ce%x09%s' "$range") || { echo "FAIL: git log $range failed" >&2; exit 2; }
# The regex goes in through ENVIRON: gawk would turn its `\.` into `.` if passed with -v.
bad=$(RESERVED=$reserved awk -F'\t' '
  BEGIN { re = ENVIRON["RESERVED"] }
  { a = tolower($2); c = tolower($3) }
  a ~ re || c ~ re { printf "%s author <%s> committer <%s>: %s\n", $1, $2, $3, $4 }' <<<"$log")

count=$(grep -c . <<<"$log" || true)
if [ -n "$bad" ]; then
  echo "commit-identity: commits in $range made under a test identity (L-41):"
  echo "$bad"
  exit 1
fi
echo "commit-identity: $count commits in $range, none under a test identity"
