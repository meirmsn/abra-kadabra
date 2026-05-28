#!/usr/bin/env bash
# What: Check review.md for forbidden n/a outcomes on LLM-mediated gates.
# Why:  Extracted from the inline awk block at SKILL.md § Phase 3→4 handoff
#       Rung 3 (lines 1360-1379). Making it a standalone script turns a prose-
#       level enforcement into a first-class testable surface with mawk-portable
#       syntax (closed the kit/TODOS.md entry for this gap).
# Does NOT: run any gates, modify review.md, or judge blocked/findings counts
#       (those are separate rungs in the Phase 3→4 handoff).
#
# Usage:
#   check-llm-mediated-na.sh <review.md path>
#
# Exit codes:
#   0 — no forbidden n/a found (clean)
#   1 — one or more LLM-mediated gates emitted bare n/a
#  64 — usage error
#
# mawk portability: uses ($|[^a-z-]) instead of \b for word boundaries.
# Tested with mawk explicitly in bats (spec § T3 Gotcha 3).
#
# Spec: specs/local-env-pillar/spec.md § T3.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <review.md path>" >&2
  exit 64
fi

REVIEW_FILE="$1"

if [ ! -f "$REVIEW_FILE" ]; then
  echo "error: review.md not found at $REVIEW_FILE" >&2
  exit 64
fi

# The awk script detects forbidden n/a on LLM-mediated gates (review, cso,
# design-review, qa). These gates MUST emit pass|findings|blocked — never n/a.
# Scope exemptions use "blocked (n/a per scope: ...)" which is NOT matched
# by the "- Result: n/a" pattern (the "blocked" prefix excludes it).
#
# mawk-portable: no \b word boundaries. Use ($|[^a-z-]) to anchor after
# gate names so "design-review" doesn't false-match on "design-review-extra".
# AWK_CMD is passed to the awk binary selected at runtime.

AWK_CMD='
  /^## Gate [0-9]+: \/(review|cso|design-review|qa)($|[^a-z-])/ { in_section=1; gate=$0; next }
  in_section && /^## Gate / { in_section=0 }
  in_section && /^- Result: *n\/a/ { print gate }
  in_section && /^\*?\*?Result:\*?\*? *n\/a/ { print gate }
'

# Prefer mawk for consistency (devcontainer ships both); fall back to awk.
AWK_BIN="${AWK_BIN:-}"
if [ -z "$AWK_BIN" ]; then
  if command -v mawk >/dev/null 2>&1; then
    AWK_BIN="mawk"
  else
    AWK_BIN="awk"
  fi
fi

FORBIDDEN_NA=$("$AWK_BIN" "$AWK_CMD" "$REVIEW_FILE")

if [ -n "$FORBIDDEN_NA" ]; then
  echo "FORBIDDEN n/a: LLM-mediated gate(s) emitted n/a (forbidden per"
  echo "  ak-pre-ship § Outcome semantics § n/a is not legal for LLM-mediated gates):"
  echo "$FORBIDDEN_NA" | sed 's/^/    /'
  echo ""
  echo "  Scope exemptions must use 'blocked (n/a per scope: <reason>)' so the"
  echo "  dismissalLog adversarial reviewer judges the rationale."
  exit 1
fi

echo "CLEAN: no forbidden n/a on LLM-mediated gates"
exit 0
