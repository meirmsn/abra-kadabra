#!/usr/bin/env bash
# What: Gate roster completeness check — verifies every scope-expected gate
#       produced a sink file, and hero capture (PNGs or valid SKIP.md) exists.
# Why:  Replaces inline orchestrator prose at SKILL.md § 3.3.1. A missing sink
#       means the orchestrator silently skipped a gate — the exact failure mode
#       the per-gate decomposition exists to prevent (home-os PR #36).
# Does NOT: run any gates itself, judge gate outcomes (pass/fail/blocked), or
#       replace the Phase 3→4 handoff logic (which also checks blocked counts
#       and forbidden n/a).
#
# Usage:
#   roster-check.sh <preflight-sink-path> <gates-dir> <hero-dir>
#
# Exit codes:
#   0 — all expected gates have sinks, hero capture present
#   1 — one or more expected gates missing, or hero capture invalid
#  64 — usage error
#
# Spec: specs/local-env-pillar/spec.md § T2, § D3, § D6.

set -euo pipefail

# --- Args ---

if [ $# -lt 3 ]; then
  echo "Usage: $0 <preflight-sink-path> <gates-dir> <hero-dir>" >&2
  exit 64
fi

PREFLIGHT_SINK="$1"
GATES_DIR="$2"
HERO_DIR="$3"

if [ ! -f "$PREFLIGHT_SINK" ]; then
  echo "error: preflight sink not found at $PREFLIGHT_SINK" >&2
  exit 1
fi

# --- Step 1: Parse scope variables from preflight sink ---
# Format: "- TOUCHES_UI=<value>" (leading "- " bullet per SKILL.md § 3.0).

read_scope_var() {
  local key="$1"
  grep -- "- ${key}=" "$PREFLIGHT_SINK" 2>/dev/null | sed "s/.*- ${key}=//" | head -1
}

TOUCHES_UI=$(read_scope_var "TOUCHES_UI")
TOUCHES_MIGRATIONS=$(read_scope_var "TOUCHES_MIGRATIONS")
TOUCHES_FUNCTIONS=$(read_scope_var "TOUCHES_FUNCTIONS")
TOUCHES_KIT=$(read_scope_var "TOUCHES_KIT")
TOUCHES_CODE=$(read_scope_var "TOUCHES_CODE")
TOUCHES_USER_CODE=$(read_scope_var "TOUCHES_USER_CODE")
HAS_TURBO=$(read_scope_var "HAS_TURBO")

# --- Step 2: Derive expected roster from scope predicates ---
# Mirrors SKILL.md § 3.3.1 Step 1 exactly.

EXPECTED_GATES=""

# Always-run:
EXPECTED_GATES+=" simplify docs-and-tests-review review cso qa convention"
EXPECTED_GATES+=" slow-job-lifecycle design-conformance"

# Conditional:
[ -n "$TOUCHES_UI" ] && EXPECTED_GATES+=" responsive-theme design-review benchmark"
[ -n "$HAS_TURBO" ] && EXPECTED_GATES+=" fast-job-local preflight-final"
[ -n "$TOUCHES_KIT" ] && EXPECTED_GATES+=" docs-check"
[ -n "$TOUCHES_MIGRATIONS" ] && EXPECTED_GATES+=" rls-coverage migration-rollback-roundtrip"
([ -n "${TOUCHES_MIGRATIONS:-}" ] || [ -n "${TOUCHES_FUNCTIONS:-}" ]) && EXPECTED_GATES+=" advisor-clean"
[ -n "$TOUCHES_CODE" ] && EXPECTED_GATES+=" changed-tests-local"
[ -n "$TOUCHES_USER_CODE" ] && EXPECTED_GATES+=" metrics-check"

# --- Step 3: Check each expected gate's sink exists ---

MISSING_GATES=""
for gate in $EXPECTED_GATES; do
  if [ ! -f "${GATES_DIR}/${gate}.md" ]; then
    MISSING_GATES+="  $gate\n"
  fi
done

# --- Step 4: Hero capture check ---
# PNGs present = ok; SKIP.md with valid reason = ok; otherwise = fail.

HERO_ISSUE=""

if ! ls "${HERO_DIR}/"*.png >/dev/null 2>&1; then
  if [ -f "${HERO_DIR}/SKIP.md" ]; then
    # SKIP.md exists — validate the Reason line (T5 hardens this further).
    REASON_LINE=$(grep -E '^-?\s*Reason:' "${HERO_DIR}/SKIP.md" 2>/dev/null || true)
    if [ -z "$REASON_LINE" ]; then
      HERO_ISSUE="  hero-capture (SKIP.md present but missing Reason: line)\n"
    else
      # Extract the reason value after "Reason: " (handles both "Reason: X" and "- Reason: X").
      REASON_VALUE=$(echo "$REASON_LINE" | sed 's/^-\?\s*Reason:\s*//')
      case "$REASON_VALUE" in
        "non-UI PR"*|"Chromium unavailable"*)
          # Known-valid skip reasons — accepted (trailing context after the
          # class name is allowed, e.g. "non-UI PR (TOUCHES_UI empty — ...)").
          ;;
        *)
          HERO_ISSUE="  hero-capture (SKIP.md has unknown reason: '$REASON_VALUE')\n"
          ;;
      esac
    fi
  else
    HERO_ISSUE="  hero-capture (no PNGs and no SKIP.md)\n"
  fi
fi

# --- Step 5: Report ---

ALL_MISSING="${MISSING_GATES}${HERO_ISSUE}"

if [ -n "$ALL_MISSING" ]; then
  echo "ROSTER INCOMPLETE — expected gate(s) or artifacts missing:"
  echo -e "$ALL_MISSING"
  echo ""
  echo "  A missing sink means the orchestrator skipped the gate dispatch."
  echo "  Re-invoke /ak-build to re-enter Phase 3; the resume check picks"
  echo "  up at Phase 3 and re-dispatches all gates."
  exit 1
fi

echo "ROSTER COMPLETE: all expected gates present, hero capture valid"
exit 0
