#!/bin/bash
# What: Pre-commit check (project repos) — adversarially reviews additions to
#       .devshop-test-coverage-exempt / .devshop-docs-freshness-exempt.
# Why: Adding entries to these exempt files bypasses the test-presence /
#      docs-freshness gates. Without review, anyone can append paths with
#      vague reasons (or no reason at all), silently eroding the coverage /
#      freshness invariants those gates enforce.
# Does NOT: Review removals (relaxing exemptions is always safe). Does NOT
#           run on devshop self (devshop has its own check-test-coverage.sh
#           with no project-style exempt-list mechanism).
#
# Pre-flight (deterministic): any path-like token in an inline reason
# (e.g. "covered by e2e/foo.spec.ts") must exist on disk. A cited
# spec/test that doesn't exist is a hard block — no adversarial bypass.
#
# Layer 2: the inline `# reason` after each path is fed to adversarial-review
# (check-type=exemptAddition). The reviewer judges per-entry specificity.
# No check-specific bypass flag — humanReviewed (terminal-only) is the
# universal override if the reviewer is wrong.

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

# Project-repo only. Devshop-self detection mirrors check-test-coverage-project.sh.
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then exit 0; fi
[ "$GIT_ROOT" = "/devshop" ] && exit 0

EXEMPT_FILES=(.devshop-test-coverage-exempt .devshop-docs-freshness-exempt)
STAGED=$(git diff --cached --name-only 2>/dev/null || true)

# Collect added lines (non-comment, non-blank) from each staged exempt file.
ADDITIONS=""
for f in "${EXEMPT_FILES[@]}"; do
  echo "$STAGED" | grep -Fxq "$f" || continue

  # `git diff --cached -- <file>` shows added lines starting with `+` (and
  # `+++ b/<file>` as the header). Strip the header line, then keep only
  # `+` lines, strip the leading `+`, strip blanks/comments.
  ADDED=$(git diff --cached -- "$f" 2>/dev/null \
    | grep -E '^\+[^+]' \
    | sed 's/^+//' \
    | grep -v '^[[:space:]]*$' \
    | grep -v '^[[:space:]]*#' || true)

  if [ -n "$ADDED" ]; then
    ADDITIONS+="
=== $f ===
$ADDED
"
  fi
done

[ -z "$ADDITIONS" ] && exit 0

# --- Pre-flight: cited paths must exist on disk ---
# Each entry is `path  # reason`. The LHS path is the EXEMPT target (often
# does not exist yet OR is being staged in the same commit) and must NOT be
# treated as a "cited covering file". Only the reason after `#` is scanned
# for path-like tokens (e.g. "covered by e2e/foo.spec.ts", "see specs/auth/spec.md").
CITED_MISSING=""
CITED_FOUND=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  # Strip the section header lines emitted into ADDITIONS (`=== <file> ===`)
  case "$line" in '==='*) continue ;; esac
  # Extract the reason: everything after the first `#`. If no `#` present,
  # there's no inline reason — skip pre-flight and let Layer 2 reject it.
  case "$line" in
    *'#'*) reason="${line#*#}" ;;
    *) continue ;;
  esac
  for token in $(echo "$reason" | grep -oE '[a-zA-Z0-9_./-]+\.(integration\.test\.ts|test\.ts|spec\.ts|spec\.tsx|tsx|ts|md)' || true); do
    # Strip leading "./" if present
    clean=${token#./}
    if [ -e "$GIT_ROOT/$clean" ]; then
      CITED_FOUND+="    $clean (exists)"$'\n'
    else
      CITED_MISSING+="    $clean (cited in: $(echo "$line" | sed 's/[[:space:]]*$//'))"$'\n'
    fi
  done
done <<< "$ADDITIONS"

if [ -n "$CITED_MISSING" ]; then
  echo ""
  echo "✖ BLOCKING: Exempt-file addition cites file(s) that don't exist:"
  echo -n "$CITED_MISSING"
  echo ""
  echo "  Either create the cited file in this commit, or update the inline"
  echo "  reason to point at a covering spec/test that actually exists."
  echo ""
  echo "  This is a hard block — no adversarial bypass. A cited covering file"
  echo "  that doesn't exist is the exact problem this check exists to catch."
  exit 1
fi

# --- Layer 2: adversarial review of inline reasons ---
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
REVIEW_CONTEXT="Exempt-file additions staged in this commit:
$ADDITIONS

Cited paths verified to exist on disk:
${CITED_FOUND:-(no path-like tokens cited in any reason)}"

echo "⏳ Exempt-file addition: reviewing inline reasons with adversarial agent..."
if RESULT=$(bash "$SCRIPT_DIR/../adversarial-review.sh" exemptAddition "$REVIEW_CONTEXT" 2>&1); then
  echo "✓ Exempt-file addition: adversarial review accepted."
  exit 0
else
  echo ""
  echo "✖ ADVERSARIAL REVIEW REJECTED one or more exempt-file additions."
  echo "  $RESULT"
  echo ""
  echo "  Improve the inline reason for each rejected entry. The reason must"
  echo "  name a specific covering spec/test/scope that a future reviewer could"
  echo "  verify in 30 seconds. Generic reasons ('low risk', 'TODO test',"
  echo "  'covered elsewhere') will not pass."
  exit 1
fi
