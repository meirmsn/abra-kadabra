#!/usr/bin/env bash
# What: Pre-ship gate that runs the cheap halves of integration + E2E test
#       execution locally so a developer discovers a broken Playwright spec or
#       a degraded local Supabase stack 30 seconds before pushing instead of
#       8–10 minutes after. Four steps: parse-check → changed E2E execution →
#       changed integration execution → smoke set. Wallclock-bounded; CI still
#       runs the full matrix.
# Why:  CI's slow-job catches the same failures, but the loop is "push → wait
#       8 min → red CI → fix → push again." Running the cheap subset locally
#       collapses that loop to seconds. See kit/ROADMAP.md § Shift cheap test
#       gates from CI-only to local pre-push for the full motivation.
# Does NOT: replace the CI slow-job, run the full multi-viewport matrix, or
#       manage `pnpm dev` lifecycle (delegated to Playwright's webServer block
#       per Gotcha 2). Read-only-ish: the only side effect is
#       briefly running the project's existing tests.
#
# Usage: changed-tests-local.sh [PROJECT_ROOT]
#        Stdout follows the canonical gate shape (outcome line, finding bullets,
#        ## Dismissals section). Exits 0 except on internal error.
#
# Wallclock budgets (from spec D5; tunable via env):
#   PARSE_CHECK_TIMEOUT_S=30        — Step 1: playwright --list
#   E2E_CHANGED_TIMEOUT_S=120       — Step 2: changed E2E specs
#   INTEGRATION_CHANGED_TIMEOUT_S=60 — Step 3: changed integration tests
#   SMOKE_SET_TIMEOUT_S=120         — Step 4: *-qa-walk smoke set
#
# Bypass: `git config devshop.localTestSkipReason "<why>"` short-circuits the
#         gate after invoking adversarial-review.sh's localTestSkipReason
#         check-type on the reason.

set -euo pipefail

PROJECT_ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
DEVSHOP="${DEVSHOP:-/devshop}"

# Wallclock budgets — env-overridable for tests / tuning, otherwise spec-D5 defaults.
PARSE_CHECK_TIMEOUT_S="${PARSE_CHECK_TIMEOUT_S:-30}"
E2E_CHANGED_TIMEOUT_S="${E2E_CHANGED_TIMEOUT_S:-120}"
INTEGRATION_CHANGED_TIMEOUT_S="${INTEGRATION_CHANGED_TIMEOUT_S:-60}"
SMOKE_SET_TIMEOUT_S="${SMOKE_SET_TIMEOUT_S:-120}"

# Default base ref against which "changed" is computed. Tests override.
BASE_REF="${LOCAL_TESTS_BASE_REF:-origin/main}"

# Path classifier — use env override (test path) or canonical sibling helper.
PATH_CLASSIFIER="${PATH_CLASSIFIER_SCRIPT:-$DEVSHOP/kit/scripts/preship/path-classifier.sh}"
if [ ! -x "$PATH_CLASSIFIER" ] && [ -f "$PATH_CLASSIFIER" ]; then
  PATH_CLASSIFIER="bash $PATH_CLASSIFIER"
fi
ADVERSARIAL_REVIEW_SH="${ADVERSARIAL_REVIEW_SCRIPT:-$DEVSHOP/kit/scripts/adversarial-review.sh}"

# --- Helpers ---

# Emit final report. Args: outcome-line, finding-bullets-blob, dismissals-body.
# Both blobs may be empty.
emit_report() {
  local outcome="$1"
  local findings="${2:-}"
  local dismissals="${3:-None}"
  echo "$outcome"
  if [ -n "$findings" ]; then
    # Each non-empty line gets the "  - " prefix, unless already prefixed.
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

# Compute changed paths (added or modified) since BASE_REF, filtered by extension/path.
# Args: base-ref, path-glob (extended-regex matched against path).
# Outputs newline-separated paths; empty when nothing matches.
changed_paths_matching() {
  local base="$1"
  local pattern="$2"
  cd "$PROJECT_ROOT"
  # diff-filter=AM excludes deletions, renames, etc.
  git diff --name-only --diff-filter=AM "$base"...HEAD 2>/dev/null \
    | grep -E "$pattern" || true
}

# True if the diff contains any path classified as stack-needing.
diff_needs_stack() {
  local base="$1"
  if [ -x "$DEVSHOP/kit/scripts/preship/path-classifier.sh" ]; then
    "$DEVSHOP/kit/scripts/preship/path-classifier.sh" diff-needs-stack "$base" >/dev/null 2>&1
    return $?
  fi
  # Fallback: inline classifier (matches D4's table). Returns 0 if any
  # changed path matches a stack-needing glob.
  local diff
  diff=$(cd "$PROJECT_ROOT" && git diff --name-only --diff-filter=AM "$base"...HEAD 2>/dev/null || true)
  [ -z "$diff" ] && return 1
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in
      apps/*) return 0 ;;
      packages/core/*|packages/ui/*) return 0 ;;
      *.integration.test.ts) return 0 ;;
      apps/*/e2e/*.spec.ts) return 0 ;;
      supabase/migrations/*|supabase/functions/*) return 0 ;;
    esac
  done <<<"$diff"
  return 1
}

# --- Bypass-flag handling (early exit) ---

SKIP_REASON="$(cd "$PROJECT_ROOT" && git config --get devshop.localTestSkipReason 2>/dev/null || true)"
if [ -n "$SKIP_REASON" ]; then
  # Adversarial review the reason. PASS → skipped pass; FAIL → findings (1) pending.
  if [ -x "$ADVERSARIAL_REVIEW_SH" ] || [ -f "$ADVERSARIAL_REVIEW_SH" ]; then
    if VERDICT=$(bash "$ADVERSARIAL_REVIEW_SH" localTestSkipReason "$SKIP_REASON" 2>&1); then
      emit_report "pass (skipped — adversarially reviewed)" "" "skipped via devshop.localTestSkipReason: $SKIP_REASON"
      exit 0
    else
      emit_report "findings (1) pending" "localTestSkipReason rejected by adversarial review: $VERDICT" "None"
      exit 0
    fi
  else
    # No reviewer available — fail-open with a note, don't silently skip.
    emit_report "pass (skipped — adversarial-review.sh unavailable)" "" "skipped via devshop.localTestSkipReason: $SKIP_REASON"
    exit 0
  fi
fi

# --- Scope detection: n/a if no stack-needing paths in diff ---

if ! diff_needs_stack "$BASE_REF"; then
  emit_report "n/a (no stack-needing paths in diff)" "" "None"
  exit 0
fi

# --- Step 1: parse-check (playwright test --list) ---

cd "$PROJECT_ROOT"

findings=()
budget_exceeded=0

PLAYWRIGHT_CONFIG=""
for cfg in playwright.config.ts playwright.config.js apps/web/playwright.config.ts; do
  if [ -f "$PROJECT_ROOT/$cfg" ]; then
    PLAYWRIGHT_CONFIG="$cfg"
    break
  fi
done

PARSE_CHECK_RAN=0
if [ -n "$PLAYWRIGHT_CONFIG" ]; then
  PARSE_CHECK_RAN=1
  # Run parse-check from the directory containing the config so relative paths resolve.
  PLAYWRIGHT_DIR="$(cd "$PROJECT_ROOT/$(dirname "$PLAYWRIGHT_CONFIG")" && pwd)"
  if ! ( cd "$PLAYWRIGHT_DIR" && timeout --kill-after=10s "${PARSE_CHECK_TIMEOUT_S}s" pnpm exec playwright test --list >/dev/null 2>&1 ); then
    PARSE_RC=$?
    if [ "$PARSE_RC" = "124" ]; then
      findings+=("parse-check (playwright --list) exceeded ${PARSE_CHECK_TIMEOUT_S}s budget — Playwright config may have a load-time error or the install is incomplete")
      budget_exceeded=1
    else
      findings+=("parse-check failed (pnpm exec playwright test --list, exit $PARSE_RC) — fix the Playwright config / spec-load error before re-running")
    fi
    # Parse failure short-circuits before execution steps.
    emit_report "findings (${#findings[@]})$( [ "$budget_exceeded" = "1" ] && echo " [budget exceeded]")" "$(printf '%s\n' "${findings[@]}")" "None"
    exit 0
  fi
fi

# --- Step 2: changed E2E execution ---

CHANGED_E2E=$(changed_paths_matching "$BASE_REF" '^apps/[^/]+/e2e/.*\.spec\.ts$' || true)
E2E_RAN_COUNT=0
E2E_DEFERRED_COUNT=0
if [ -n "$CHANGED_E2E" ] && [ -n "$PLAYWRIGHT_CONFIG" ]; then
  E2E_FILES_REL=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    E2E_FILES_REL+=("$f")
  done <<<"$CHANGED_E2E"
  E2E_TOTAL=${#E2E_FILES_REL[@]}
  PLAYWRIGHT_DIR="$(cd "$PROJECT_ROOT/$(dirname "$PLAYWRIGHT_CONFIG")" && pwd)"
  # Translate paths to be relative to the playwright config dir.
  E2E_ARGS=()
  for f in "${E2E_FILES_REL[@]}"; do
    # Strip the playwright dir prefix so the arg is relative to it.
    rel="${f#"$(realpath --relative-to="$PROJECT_ROOT" "$PLAYWRIGHT_DIR" 2>/dev/null || echo "")/"}"
    [ "$rel" = "$f" ] && rel="$(realpath --relative-to="$PLAYWRIGHT_DIR" "$PROJECT_ROOT/$f" 2>/dev/null || echo "$f")"
    E2E_ARGS+=("$rel")
  done

  if ! ( cd "$PLAYWRIGHT_DIR" && timeout --kill-after=10s "${E2E_CHANGED_TIMEOUT_S}s" \
       pnpm exec playwright test --project=chromium --max-failures=1 --workers=1 "${E2E_ARGS[@]}" >/dev/null 2>&1 ); then
    RC=$?
    if [ "$RC" = "124" ]; then
      E2E_RAN_COUNT=0
      E2E_DEFERRED_COUNT=$E2E_TOTAL
      findings+=("changed E2E execution exceeded ${E2E_CHANGED_TIMEOUT_S}s budget — found $E2E_TOTAL specs; 0 ran, $E2E_TOTAL deferred to CI")
      budget_exceeded=1
    else
      findings+=("changed E2E specs failed (exit $RC across $E2E_TOTAL spec(s)) — re-run \`pnpm exec playwright test --project=chromium\` to see failures")
    fi
  else
    E2E_RAN_COUNT=$E2E_TOTAL
  fi
fi

# --- Step 3: changed integration execution ---

CHANGED_INTEGRATION=$(changed_paths_matching "$BASE_REF" '\.integration\.test\.ts$' || true)
if [ -n "$CHANGED_INTEGRATION" ]; then
  INT_FILES=()
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    INT_FILES+=("$f")
  done <<<"$CHANGED_INTEGRATION"
  INT_TOTAL=${#INT_FILES[@]}
  if ! ( cd "$PROJECT_ROOT" && VITEST_INTEGRATION=1 timeout --kill-after=10s "${INTEGRATION_CHANGED_TIMEOUT_S}s" \
       pnpm vitest run "${INT_FILES[@]}" >/dev/null 2>&1 ); then
    RC=$?
    if [ "$RC" = "124" ]; then
      findings+=("changed integration execution exceeded ${INTEGRATION_CHANGED_TIMEOUT_S}s budget — found $INT_TOTAL specs; 0 ran, $INT_TOTAL deferred to CI")
      budget_exceeded=1
    else
      findings+=("changed integration tests failed (exit $RC across $INT_TOTAL file(s)) — re-run \`VITEST_INTEGRATION=1 pnpm vitest run\` to see failures")
    fi
  fi
fi

# --- Step 4: smoke set (apps/web/e2e/*-qa-walk.spec.ts ∪ apps/web/e2e/qa-walk.spec.ts) ---

SMOKE_RAN_COUNT=0
SMOKE_DEFERRED_COUNT=0
if [ -n "$PLAYWRIGHT_CONFIG" ]; then
  # Detect smoke-set membership at the project repo root, not relative to config.
  SMOKE_FILES=()
  if [ -d "$PROJECT_ROOT/apps/web/e2e" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      SMOKE_FILES+=("$f")
    done < <(find "$PROJECT_ROOT/apps/web/e2e" -maxdepth 1 -type f \
                 \( -name '*-qa-walk.spec.ts' -o -name 'qa-walk.spec.ts' \) 2>/dev/null \
                 | sort)
  fi
  SMOKE_TOTAL=${#SMOKE_FILES[@]}

  if [ "$SMOKE_TOTAL" -gt 0 ]; then
    PLAYWRIGHT_DIR="$(cd "$PROJECT_ROOT/$(dirname "$PLAYWRIGHT_CONFIG")" && pwd)"
    SMOKE_ARGS=()
    for f in "${SMOKE_FILES[@]}"; do
      rel="$(realpath --relative-to="$PLAYWRIGHT_DIR" "$f" 2>/dev/null || echo "$f")"
      SMOKE_ARGS+=("$rel")
    done
    if ! ( cd "$PLAYWRIGHT_DIR" && timeout --kill-after=10s "${SMOKE_SET_TIMEOUT_S}s" \
         pnpm exec playwright test --project=chromium --max-failures=1 --workers=1 "${SMOKE_ARGS[@]}" >/dev/null 2>&1 ); then
      RC=$?
      if [ "$RC" = "124" ]; then
        SMOKE_DEFERRED_COUNT=$SMOKE_TOTAL
        findings+=("smoke set exceeded ${SMOKE_SET_TIMEOUT_S}s budget — found $SMOKE_TOTAL specs; 0 ran, $SMOKE_TOTAL deferred to CI")
        budget_exceeded=1
      else
        findings+=("smoke set failed (exit $RC across $SMOKE_TOTAL spec(s)) — re-run the *-qa-walk specs locally")
      fi
    else
      SMOKE_RAN_COUNT=$SMOKE_TOTAL
    fi
  fi
fi

# --- Final outcome ---

if [ ${#findings[@]} -eq 0 ]; then
  emit_report "pass" "" "None"
  exit 0
fi

OUTCOME="findings (${#findings[@]})"
if [ "$budget_exceeded" = "1" ]; then
  OUTCOME="$OUTCOME [budget exceeded]"
fi

# When budget exceeded, the deferred specs are dismissals (CI will exercise them).
DISMISSALS_BODY="None"
if [ "$budget_exceeded" = "1" ]; then
  DISMISSALS_BODY="- specs deferred to CI slow-job — rationale: wallclock budget exceeded; CI will exercise these in slow-job"
fi

emit_report "$OUTCOME" "$(printf '%s\n' "${findings[@]}")" "$DISMISSALS_BODY"
exit 0
