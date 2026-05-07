#!/usr/bin/env bash
# What: Path classifier helper for the cheap-test-gates-local feature. Two
#       subcommands:
#         classify <path>          — print "stack-needing" or "not-stack-needing"
#         diff-needs-stack [<base>] — exit 0 if any path in the diff vs base
#                                     classifies as stack-needing; exit 1 otherwise.
# Why:  Single source of truth for the "does this diff need the local Supabase
#       stack to be healthy?" question. Used by:
#         - changed-tests-local.sh (sub-fix 1) for `n/a` scope detection.
#         - supabase-bootstrap.sh up (sub-fix 3) for the D6 promotion rule
#           that turns degraded-stack `pass-with-note` into hard `blocked` on
#           stack-needing diffs.
# Does NOT: shell out to git for `classify` (pure path-string match), parse
#       gitignore, or know about per-project overrides (deferred to sub-fix 2
#       stage 2's .devshop/test-impact.json — see kit/ROADMAP.md).
#
# Usage:
#   path-classifier.sh classify <path>
#   path-classifier.sh diff-needs-stack [<base-ref>]
#
# Spec: specs/cheap-test-gates-local/spec.md § D4, § Files to create / modify.

set -euo pipefail

# --- classify <path> — pure path-string match against D4's hardcoded table ---
#
# Hardcoded glob list (spec D4):
#   apps/**                                       → stack-needing
#   packages/core/**, packages/ui/**              → stack-needing
#   *.integration.test.ts                         → stack-needing (any depth)
#   apps/*/e2e/*.spec.ts                          → stack-needing (matches apps/** anyway)
#   supabase/migrations/**, supabase/functions/** → stack-needing
#   anything else                                 → not-stack-needing
#
# Returns 0 always (read-only classification); stdout is the verdict.
classify_path() {
  local p="$1"
  # Edge case: empty path → not-stack-needing (defensive).
  if [ -z "$p" ]; then
    echo "not-stack-needing"
    return 0
  fi
  case "$p" in
    apps/*) echo "stack-needing"; return 0 ;;
    packages/core/*) echo "stack-needing"; return 0 ;;
    packages/ui/*) echo "stack-needing"; return 0 ;;
    *.integration.test.ts) echo "stack-needing"; return 0 ;;
    supabase/migrations/*) echo "stack-needing"; return 0 ;;
    supabase/functions/*) echo "stack-needing"; return 0 ;;
    *) echo "not-stack-needing"; return 0 ;;
  esac
}

# --- diff-needs-stack [<base-ref>] — exit 0 if diff has any stack-needing path ---
#
# Default base ref is `origin/main`. Reads `git diff --name-only --diff-filter=AM
# <base>...HEAD`. Exit codes:
#   0 — at least one changed path classifies as stack-needing
#   1 — no stack-needing paths (pure-docs / outside the table's globs)
#   2 — git error (e.g. base ref doesn't exist)
diff_needs_stack() {
  local base="${1:-origin/main}"
  local diff
  if ! diff=$(git diff --name-only --diff-filter=AM "$base"...HEAD 2>/dev/null); then
    return 2
  fi
  # Empty diff → no stack-needing paths.
  [ -z "$diff" ] && return 1
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    if [ "$(classify_path "$p")" = "stack-needing" ]; then
      return 0
    fi
  done <<<"$diff"
  return 1
}

# --- CLI dispatch ---

case "${1:-}" in
  classify)
    if [ -z "${2:-}" ]; then
      echo "usage: $0 classify <path>" >&2
      exit 64  # EX_USAGE
    fi
    classify_path "$2"
    ;;
  diff-needs-stack)
    diff_needs_stack "${2:-origin/main}"
    ;;
  *)
    echo "usage: $0 {classify <path> | diff-needs-stack [<base-ref>]}" >&2
    exit 64
    ;;
esac
