#!/usr/bin/env bash
# What: Pre-ship gate that runs the project's CI fast-job equivalent locally —
#       lint, typecheck, unit tests, build — so deterministic failures land in
#       the iterate-fix loop instead of after a CI round-trip. Pairs with
#       changed-tests-local.sh as Layer 1 (this) + Layer 2 (that) of /preflight.
# Why:  Standard pre-PR mental model has been "trust CI, push, wait 8 min." Local
#       fast-job catches the cheapest 80% of failures in seconds. CI still runs
#       the full matrix; this is the early-warning floor.
# Does NOT: replace CI's fast-job, run slow-job stages, or manage dev-server
#       lifecycle. Assumes a turbo monorepo (turbo.json present); n/a otherwise.
#
# Usage: fast-job-local.sh [PROJECT_ROOT]
#        Stdout follows the canonical gate shape (outcome line, finding bullets,
#        ## Dismissals section). Exits 0 except on internal error.
#
# Wallclock budgets (env-overridable):
#   LINT_TIMEOUT_S=120         — pnpm turbo run lint
#   TYPECHECK_TIMEOUT_S=120    — pnpm turbo run typecheck
#   UNIT_TIMEOUT_S=180         — pnpm turbo run test:unit
#   BUILD_TIMEOUT_S=300        — pnpm turbo run build
#
# Bypass: `git config devshop.fastJobSkipReason "<why>"` short-circuits the gate
#         after invoking adversarial-review.sh on the reason. Same shape as
#         changed-tests-local.sh's devshop.localTestSkipReason — passes require
#         specific, time-bound rationale; default REJECT.

set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DEVSHOP="${DEVSHOP:-/devshop}"

LINT_TIMEOUT_S="${LINT_TIMEOUT_S:-120}"
TYPECHECK_TIMEOUT_S="${TYPECHECK_TIMEOUT_S:-120}"
UNIT_TIMEOUT_S="${UNIT_TIMEOUT_S:-180}"
BUILD_TIMEOUT_S="${BUILD_TIMEOUT_S:-300}"

ADVERSARIAL_REVIEW_SH="${ADVERSARIAL_REVIEW_SCRIPT:-$DEVSHOP/kit/scripts/adversarial-review.sh}"

emit_report() {
  local outcome="$1"
  local findings="${2:-}"
  local dismissals="${3:-None}"
  echo "$outcome"
  if [ -n "$findings" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      case "$line" in
        "  - "*) echo "$line" ;;
        *) echo "  - $line" ;;
      esac
    done <<<"$findings"
  fi
  echo
  echo "## Dismissals"
  echo "$dismissals"
}

# --- Bypass-flag handling (early exit) ---

SKIP_REASON="$(cd "$PROJECT_ROOT" && git config --get devshop.fastJobSkipReason 2>/dev/null || true)"
if [ -n "$SKIP_REASON" ]; then
  if [ -x "$ADVERSARIAL_REVIEW_SH" ] || [ -f "$ADVERSARIAL_REVIEW_SH" ]; then
    if VERDICT=$(bash "$ADVERSARIAL_REVIEW_SH" fastJobSkipReason "$SKIP_REASON" 2>&1); then
      emit_report "pass (skipped — adversarially reviewed)" "" "skipped via devshop.fastJobSkipReason: $SKIP_REASON"
      exit 0
    else
      emit_report "findings (1) pending" "fastJobSkipReason rejected by adversarial review: $VERDICT" "None"
      exit 0
    fi
  else
    emit_report "pass (skipped — adversarial-review.sh unavailable)" "" "skipped via devshop.fastJobSkipReason: $SKIP_REASON"
    exit 0
  fi
fi

# --- Scope detection: n/a if no turbo monorepo ---

if [ ! -f "$PROJECT_ROOT/turbo.json" ]; then
  emit_report "n/a (no turbo.json — fast-job script assumes a turbo monorepo)" "" "None"
  exit 0
fi

cd "$PROJECT_ROOT"

findings=()
budget_exceeded=0

run_step() {
  local label="$1"
  local budget="$2"
  shift 2
  local rerun="$*"
  local rc
  # `set +e` + explicit capture: `if ! cmd; then rc=$?` resets $? to 0 inside the
  # then-block (bash quirk — the `!` inverter's own exit overrides the inner cmd's).
  set +e
  timeout --kill-after=10s "${budget}s" "$@" >/dev/null 2>&1
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    if [ "$rc" = "124" ]; then
      findings+=("$label exceeded ${budget}s budget — raise the budget or split the work; CI fast-job will exercise this")
      budget_exceeded=1
    else
      findings+=("$label failed (exit $rc) — re-run \`$rerun\` to see the failure")
    fi
  fi
}

run_step "lint"      "$LINT_TIMEOUT_S"      pnpm turbo run lint
run_step "typecheck" "$TYPECHECK_TIMEOUT_S" pnpm turbo run typecheck
run_step "test:unit" "$UNIT_TIMEOUT_S"      pnpm turbo run test:unit
run_step "build"     "$BUILD_TIMEOUT_S"     pnpm turbo run build

if [ ${#findings[@]} -eq 0 ]; then
  emit_report "pass" "" "None"
  exit 0
fi

OUTCOME="findings (${#findings[@]})"
if [ "$budget_exceeded" = "1" ]; then
  OUTCOME="$OUTCOME [budget exceeded]"
fi

DISMISSALS_BODY="None"
if [ "$budget_exceeded" = "1" ]; then
  DISMISSALS_BODY="- steps deferred to CI fast-job — rationale: wallclock budget exceeded; CI will exercise these"
fi

emit_report "$OUTCOME" "$(printf '%s\n' "${findings[@]}")" "$DISMISSALS_BODY"
exit 0
