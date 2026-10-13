#!/usr/bin/env bash
# W10.6.8 re-run: rebuilds the eval's local fixture branches from the patches in changes/, in a fresh
# clone of the fixture, on a base that declares scripts/check-fast.sh (the CI tiers contract,
# specs/ci-fast-slow-tiers.md), so the reviewer is told the project's CI runs its tests.
#
#   usage: prepare.sh --fixture <clone> [--undeclared]
#
# Makes (local branches only; nothing is pushed):
#   eval/ci-base      baseline-2 plus one commit adding scripts/check-fast.sh (with --undeclared:
#                     baseline-2 itself, as runs 1-5 had it)
#   eval/search-base  eval/ci-base plus changes/search-base
#   eval/<case>       starred, done, priority on eval/ci-base; fix-* on eval/search-base
# The fixture's own CI doesn't run check-fast.sh until its tiers retrofit lands: this stands in for it.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
fixture="" declared=1
while [ $# -gt 0 ]; do
  case $1 in
    --fixture) fixture=$(cd "$2" && pwd); shift 2 ;;
    --undeclared) declared=0; shift ;;
    *) sed -n 6,7p "$0" >&2; exit 2 ;;
  esac
done
[ -n "$fixture" ] || { sed -n 6,7p "$0" >&2; exit 2; }
g() { git -C "$fixture" "$@"; }
g rev-parse -q --verify 'baseline-2^{commit}' >/dev/null || { echo "no baseline-2 in $fixture" >&2; exit 2; }
[ -z "$(g status --porcelain)" ] || { echo "$fixture has uncommitted changes" >&2; exit 2; }
# Commits are made as the eval's builder, never as anyone real.
export GIT_AUTHOR_NAME="Eval Builder" GIT_AUTHOR_EMAIL="eval-builder@example.com"
export GIT_COMMITTER_NAME="Eval Builder" GIT_COMMITTER_EMAIL="eval-builder@example.com"

g checkout -q --detach baseline-2
if [ "$declared" = 1 ]; then
  mkdir -p "$fixture/scripts"
  cat >"$fixture/scripts/check-fast.sh" <<'EOF'
#!/usr/bin/env bash
# The fast tier, which CI's fast job runs on every push: secret scan, lint, app tests, schema check
# and script tests. Usage: scripts/check-fast.sh <base>. Runs every part; non-zero if any fails.
set -uo pipefail
rc=0
scripts/secret-scan.sh "${1:?usage: scripts/check-fast.sh <base>}" || rc=1
npm run lint || rc=1
npm test || rc=1
scripts/schema-check.sh || rc=1
tests/run.sh || rc=1
exit "$rc"
EOF
  chmod +x "$fixture/scripts/check-fast.sh"
  g add scripts/check-fast.sh
  g commit -qm "Declare the fast tier CI runs: scripts/check-fast.sh"
fi
g branch -qf eval/ci-base HEAD

# build <branch> <from> <patch dir>: the branch is <from> plus the patches, applied as commits.
build() {
  g checkout -q --detach "$2"
  g am -q --committer-date-is-author-date "$here/changes/$3"/*.patch
  g branch -qf "$1" HEAD
}
build eval/search-base eval/ci-base search-base
for c in starred "done" priority; do build "eval/$c" eval/ci-base "$c"; done
for c in fix-wildcards fix-nomatch; do build "eval/$c" eval/search-base "$c"; done
g checkout -q --detach eval/ci-base
for b in ci-base search-base starred "done" priority fix-wildcards fix-nomatch; do
  printf '%s %s\n' "$(g rev-parse --short "eval/$b")" "eval/$b"
done
