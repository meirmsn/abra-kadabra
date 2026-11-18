#!/usr/bin/env bash
# Secret scan run by CI: the commits a change adds, then the working tree, with /.gitleaks.toml; and
# the lockfiles in both, which must resolve packages only from a public registry (F-NEW-146: a
# session's npm can copy a preinstalled tree's internal mirror URLs into one, and gitleaks' default
# allowlist skips lockfiles). A registry the project's committed .npmrc names is allowed too.
# Usage: scripts/secret-scan.sh [--lockfiles] [base-sha]   (run from the repo to scan)
#   base-sha given → scans base..HEAD; empty or all zeros (new branch) → scans all of HEAD's history.
#   --lockfiles: the lockfile check alone, no gitleaks (the devshop's pre-push hook runs it).
# Exit 0 = clean; 1 = leaks or a non-public registry found; 2 = can't run (a missing gitleaks fails,
# never passes). A host found is printed shortened, never whole: CI logs can be public.
set -uo pipefail

config=$(cd "$(dirname "$0")/.." && pwd)/.gitleaks.toml
gitleaks=${GITLEAKS:-gitleaks}
only_locks=0
[ "${1:-}" != --lockfiles ] || { only_locks=1; shift; }
base=${1:-}

[ "$only_locks" = 1 ] || command -v "$gitleaks" >/dev/null || { echo "FAIL: gitleaks not found" >&2; exit 2; }

if [ -z "$base" ] || [ "$base" = 0000000000000000000000000000000000000000 ]; then
  range=HEAD
else
  git rev-parse -q --verify "$base^{commit}" >/dev/null || { echo "FAIL: unknown base $base" >&2; exit 2; }
  range="$base..HEAD"
fi

LOCKS='(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock)$'
# lock_hosts: reads "<file>\t<line>" pairs; prints "<file>\t<host>" for each URL a line resolves from.
lock_hosts() {
  sed -nE 's#^([^\t]*)\t.*resolved"?:? *"https?://([^/"#:]+).*#\1\t\2#p'
}
# The lines to check: those the change's commits add to a lockfile, and every working-tree lockfile.
lock_lines() {
  git log -p --no-color --no-ext-diff --format= "$range" -- \
    ':(glob)**/package-lock.json' ':(glob)**/npm-shrinkwrap.json' ':(glob)**/yarn.lock' \
    | awk '/^\+\+\+ b\// { f = substr($0, 7); next } /^\+/ && f != "" { print f "\t" substr($0, 2) }' \
    || return 2
  local files
  files=$(git ls-files -co --exclude-standard) || return 2
  { grep -E "$LOCKS" <<<"$files" || true; } \
    | while IFS= read -r f; do [ ! -f "$f" ] || awk -v f="$f" '{ print f "\t" $0 }' "./$f" || exit 2; done
}
check_lockfiles() {
  local allowed found lines
  allowed=$'registry.npmjs.org\nregistry.yarnpkg.com'
  if git ls-files --error-unmatch .npmrc >/dev/null 2>&1; then
    allowed+=$'\n'$(sed -nE 's#^[[:space:]]*(@[^:]+:)?registry[[:space:]]*=[[:space:]]*https?://([^/:]+).*#\2#p' .npmrc)
  fi
  lines=$(lock_lines) || { echo "FAIL: can't read the lockfiles' history ($range)" >&2; return 2; }
  found=$(printf '%s\n' "$lines" | lock_hosts | sort -u | awk -F'\t' -v ok="$allowed" 'BEGIN { n = split(ok, a, "\n"); for (i = 1; i <= n; i++) good[a[i]] = 1 } !($2 in good)')
  if [ -n "$found" ]; then
    echo "secret-scan: a lockfile resolves from a registry that isn't public (regenerate it against the public registry, or name a registry the project uses in its committed .npmrc):"
    awk -F'\t' '{ h = $2; sub(/\..*/, ".…", h); print "  " $1 ": " h }' <<<"$found"
    return 1
  fi
  echo "secret-scan: lockfiles resolve only from allowed registries"
}

echo "secret-scan: lockfiles, commits $range and the working tree"
check_lockfiles; lrc=$?
[ "$only_locks" = 0 ] || exit "$lrc"
echo "secret-scan: commits $range"
grc=0
"$gitleaks" git . --config "$config" --redact --no-banner --log-opts="$range" || grc=$?
if [ "$grc" = 0 ]; then
  echo "secret-scan: working tree"
  "$gitleaks" dir . --config "$config" --redact --no-banner || grc=$?
fi
[ "$grc" = 0 ] || exit "$grc"
exit "$lrc"
