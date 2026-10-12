#!/usr/bin/env bash
# Shell lint run by CI: shellcheck over every shell script git knows of (tracked, or new and not
# ignored), found by extension (.sh, .bash) or by a sh/bash shebang. Spikes kept as notes
# (kit/notes/revamp/spikes/) are records, not live code, and are skipped.
# Usage: scripts/shellcheck.sh   (run from the repo to check)
#   $SHELLCHECK overrides the shellcheck binary (tests); CI installs the version pinned in ci.yml.
# Exit 0 = clean; 1 = findings; 2 = can't run (missing shellcheck, not a git repo, no scripts).
set -euo pipefail

shellcheck=${SHELLCHECK:-shellcheck}
command -v "$shellcheck" >/dev/null || { echo "FAIL: shellcheck not found" >&2; exit 2; }
listed=$(git ls-files -z --cached --others --exclude-standard --deduplicate | tr '\0' '\n') ||
  { echo "FAIL: not inside a git repository" >&2; exit 2; }

scripts=()
while IFS= read -r f; do
  case "$f" in kit/notes/revamp/spikes/*) continue ;; esac
  [ -f "$f" ] || continue
  case "$f" in
    *.sh | *.bash) scripts+=("$f") ;;
    *) head -n1 -- "$f" | grep -qE '^#!.*[/ ](ba|da)?sh([[:space:]]|$)' && scripts+=("$f") ;;
  esac
done <<<"$listed"
[ ${#scripts[@]} -gt 0 ] || { echo "FAIL: no shell scripts found to check" >&2; exit 2; }

echo "shellcheck: ${#scripts[@]} scripts"
"$shellcheck" --external-sources -- "${scripts[@]}" || exit 1
