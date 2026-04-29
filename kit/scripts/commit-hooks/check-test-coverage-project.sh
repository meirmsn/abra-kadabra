#!/bin/bash
# What: Pre-commit check (project repos) — flags new/removed source files without paired tests
# Why: Closes the test-deletion + missing-test-on-add gap that /ak-test-review only catches at ship time
# Does NOT: Verify test quality/coverage depth (that's /ak-test-review). Does NOT block test-only diffs.
#
# Layered design:
#   Layer 1 (this script): deterministic ADD-without-test → BLOCK; orphan-after-DELETE → BLOCK; MODIFY without test → WARN
#   Layer 2 (adversarial-review.sh testCoverageProject): judges modify-cases with bypass reason
#
# Bypass: git -c devshop.testCoverageReviewed="<why>" commit ...
#
# Per-project override: .devshop-test-coverage-exempt at repo root (one path per line, # comments allowed)

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

# Project-repo only. Devshop self has its own check-test-coverage.sh.
if [ -d "$GIT_ROOT/kit" ] && [ ! -L "$GIT_ROOT/kit" ]; then
  exit 0
fi
[ "$GIT_ROOT" = "/devshop" ] && exit 0

# Globs of paths under enforcement (project source dirs).
SOURCE_GLOBS='^(apps/[^/]+/(src|app|components|lib|hooks)/|packages/[^/]+/src/)'

# Filenames the convention exempts (page entry-points, type defs, configs, barrels).
# A filename here is bypassed wherever it appears; case-sensitive.
EXEMPT_FILENAMES=(
  "index.ts"
  "index.tsx"
  "page.tsx"
  "layout.tsx"
  "loading.tsx"
  "error.tsx"
  "not-found.tsx"
  "global-error.tsx"
  "template.tsx"
  "default.tsx"
  "head.tsx"
  "icon.tsx"
  "robots.ts"
  "sitemap.ts"
  "manifest.ts"
  "middleware.ts"
)

# Path patterns the convention exempts wholesale.
EXEMPT_PATH_PATTERNS=(
  '\.d\.ts$'
  '\.config\.(ts|tsx|mjs|cjs)$'
  '\.test\.(ts|tsx)$'
  '\.integration\.test\.(ts|tsx)$'
  '\.spec\.(ts|tsx)$'
  '/e2e/'
  '/tests/'
  '/__tests__/'
  '/__mocks__/'
  '/types\.ts$'
  '/types/.*\.ts$'
)

# Per-project override file (gitignore-style — one path per line).
OVERRIDE_FILE="$GIT_ROOT/.devshop-test-coverage-exempt"

is_filename_exempt() {
  local name; name=$(basename "$1")
  for ex in "${EXEMPT_FILENAMES[@]}"; do
    [ "$name" = "$ex" ] && return 0
  done
  return 1
}

is_path_exempt() {
  local p="$1"
  for pat in "${EXEMPT_PATH_PATTERNS[@]}"; do
    if echo "$p" | grep -qE "$pat"; then return 0; fi
  done
  return 1
}

is_override() {
  local p="$1"
  [ -f "$OVERRIDE_FILE" ] || return 1
  # Strip comments + blank lines, then exact-match
  grep -v '^[[:space:]]*#' "$OVERRIDE_FILE" 2>/dev/null \
    | grep -v '^[[:space:]]*$' \
    | grep -Fxq "$p"
}

# Find an adjacent test for $1 (foo.ts → foo.test.ts | foo.integration.test.ts | foo.spec.ts in same dir).
has_adjacent_test() {
  local src="$1"
  local dir; dir=$(dirname "$src")
  local stem; stem=$(basename "$src" | sed -E 's/\.(tsx|ts)$//')
  for variant in "test.ts" "test.tsx" "integration.test.ts" "spec.ts" "spec.tsx"; do
    [ -f "$GIT_ROOT/$dir/$stem.$variant" ] && return 0
  done
  # Fallback: any *.test.ts in the same dir that mentions the filename (covers grouped specs)
  if [ -d "$GIT_ROOT/$dir" ]; then
    if grep -rlE "$stem(['\"]|\\.|\\b)" "$GIT_ROOT/$dir"/*.test.* 2>/dev/null | head -1 | grep -q .; then
      return 0
    fi
  fi
  return 1
}

# Find the test paired with a deleted source ($1 = removed src path), if any.
orphan_test_for() {
  local src="$1"
  local dir; dir=$(dirname "$src")
  local stem; stem=$(basename "$src" | sed -E 's/\.(tsx|ts)$//')
  for variant in "test.ts" "test.tsx" "integration.test.ts" "spec.ts" "spec.tsx"; do
    local candidate="$dir/$stem.$variant"
    [ -f "$GIT_ROOT/$candidate" ] && echo "$candidate" && return 0
  done
  return 1
}

# Staged sets. Use --diff-filter to split add/modify/delete.
ADDED=$(git diff --cached --name-only --diff-filter=A 2>/dev/null | grep -E '\.(ts|tsx)$' | grep -E "$SOURCE_GLOBS" || true)
MODIFIED=$(git diff --cached --name-only --diff-filter=M 2>/dev/null | grep -E '\.(ts|tsx)$' | grep -E "$SOURCE_GLOBS" || true)
DELETED=$(git diff --cached --name-only --diff-filter=D 2>/dev/null | grep -E '\.(ts|tsx)$' | grep -E "$SOURCE_GLOBS" || true)

[ -z "$ADDED" ] && [ -z "$MODIFIED" ] && [ -z "$DELETED" ] && exit 0

BLOCK_ADDED=""
BLOCK_ORPHAN=""
WARN_MODIFIED=""

# --- ADD: block if no paired test ---
while IFS= read -r src; do
  [ -z "$src" ] && continue
  is_filename_exempt "$src" && continue
  is_path_exempt "$src" && continue
  is_override "$src" && continue
  if ! has_adjacent_test "$src"; then
    BLOCK_ADDED+="    $src"$'\n'
  fi
done <<< "$ADDED"

# --- DELETE: block if paired test still present (orphan) ---
while IFS= read -r src; do
  [ -z "$src" ] && continue
  is_filename_exempt "$src" && continue
  is_path_exempt "$src" && continue
  if orphan=$(orphan_test_for "$src"); then
    # Test will be orphaned unless it's also being deleted in this commit.
    if ! echo "$DELETED" | grep -Fxq "$orphan"; then
      BLOCK_ORPHAN+="    $src (test still present: $orphan)"$'\n'
    fi
  fi
done <<< "$DELETED"

# --- MODIFY: warn if no test diff staged alongside non-trivial source change ---
# "Non-trivial" is judged by Layer 2 when the operator passes a bypass reason.
# Default: WARN only — never block on Layer 1 for modifications.
TEST_PATHS_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -E '\.(test|spec|integration\.test)\.(ts|tsx)$' || true)
while IFS= read -r src; do
  [ -z "$src" ] && continue
  is_filename_exempt "$src" && continue
  is_path_exempt "$src" && continue
  is_override "$src" && continue
  if ! has_adjacent_test "$src"; then
    WARN_MODIFIED+="    $src (modified without paired test file)"$'\n'
    continue
  fi
  # Has an adjacent test — check whether the test is also staged.
  dir=$(dirname "$src")
  stem=$(basename "$src" | sed -E 's/\.(tsx|ts)$//')
  test_staged=false
  for variant in test.ts test.tsx integration.test.ts spec.ts spec.tsx; do
    if echo "$TEST_PATHS_STAGED" | grep -Fxq "$dir/$stem.$variant"; then
      test_staged=true; break
    fi
  done
  if [ "$test_staged" = false ]; then
    WARN_MODIFIED+="    $src (source modified, paired test not in this commit)"$'\n'
  fi
done <<< "$MODIFIED"

FAILED=false

if [ -n "$BLOCK_ADDED" ]; then
  echo ""
  echo "✖ BLOCKING: New source files without paired tests:"
  echo -n "$BLOCK_ADDED"
  echo "  Convention: every new file under apps/*/src|app|components|lib|hooks/"
  echo "  or packages/*/src/ needs an adjacent .test.ts (or .integration.test.ts /"
  echo "  .spec.ts). See guide/conventions.md § Test Presence."
  echo ""
  echo "  Options:"
  echo "    1. Add the paired test file alongside the source"
  echo "    2. Add the path to .devshop-test-coverage-exempt (commit it with reason)"
  echo "    3. Bypass with reviewer:"
  echo "       git -c devshop.testCoverageReviewed=\"<why this file legitimately ships without a test>\" commit ..."
  FAILED=true
fi

if [ -n "$BLOCK_ORPHAN" ]; then
  echo ""
  echo "✖ BLOCKING: Source files removed but paired tests still present:"
  echo -n "$BLOCK_ORPHAN"
  echo "  Stage the test deletion in the same commit (or add a bypass reason"
  echo "  if the test legitimately covers a different path now):"
  echo "    git -c devshop.testCoverageReviewed=\"<why orphan stays>\" commit ..."
  FAILED=true
fi

# --- Bypass-reason path (Layer 2 adversarial review) ---
if [ "$FAILED" = true ]; then
  REASON=$(git config --get devshop.testCoverageReviewed 2>/dev/null || true)
  if [ -n "$REASON" ]; then
    SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
    DIFF_STAT=$(git diff --cached --stat 2>/dev/null | head -40 || true)
    DIFF_FULL=$(git diff --cached 2>/dev/null | head -300 || true)
    REVIEW_CONTEXT="Project test-coverage hook is blocking. Developer's reason:
$REASON

Blocked items:
${BLOCK_ADDED}${BLOCK_ORPHAN}
Staged diff (stat):
$DIFF_STAT

Staged diff (first 300 lines):
$DIFF_FULL"
    echo ""
    echo "⏳ Test-coverage bypass: reviewing reason with adversarial agent..."
    if RESULT=$(bash "$SCRIPT_DIR/../adversarial-review.sh" testCoverageProject "$REVIEW_CONTEXT" 2>&1); then
      echo "✓ Test-coverage bypass: adversarial review accepted."
      FAILED=false
    else
      echo ""
      echo "✖ ADVERSARIAL REVIEW REJECTED the bypass reason."
      echo "  $RESULT"
    fi
  fi
fi

if [ -n "$WARN_MODIFIED" ] && [ "$FAILED" = false ]; then
  echo ""
  echo "⚠ Modified source files without staged test changes:"
  echo -n "$WARN_MODIFIED"
  echo "  This is a warning — commit will proceed. /ak-test-review will judge"
  echo "  whether the existing test still covers the new behavior."
fi

[ "$FAILED" = true ] && exit 1
exit 0
