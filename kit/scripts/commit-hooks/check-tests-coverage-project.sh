#!/bin/bash
# What: Pre-commit check (project repos) — flags new/removed source files without paired tests
# Why: Closes the test-deletion + missing-test-on-add gap that audit-time `/ak-tests-review`
#      catches at ship time (so commits get useful blast-radius signal at commit time too).
# Does NOT: Verify test quality/coverage depth (that's `/ak-tests-review`, fired at
#           audit time via `/ak-check-docs-and-tests`). Does NOT block test-only diffs.
#
# Layer 1 only. Per-commit Sonnet judgment was removed alongside the audit-time
# migration (see kit/ROADMAP.md § PR-C). Bypass via
# `git -c devshop.testsCoverageReason="<why>"` accepts the commit without an LLM
# round-trip; the bypass is recorded as a `Tests-Coverage-Bypass:` trailer by
# the prepare-commit-msg hook (kit/scripts/commit-hooks/append-bypass-trailers.sh)
# and harvested at audit time by `/ak-tests-review`.
#
# Per-project override: .devshop-test-coverage-exempt at repo root (one path per line, # comments allowed)

set -euo pipefail

GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$GIT_ROOT" ] && exit 0

# Project-repo only. Devshop self has its own check-tests-coverage-devshop.sh.
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
  "instrumentation.ts"
  "instrumentation-client.ts"
  "vitest.setup.ts"
  "providers.tsx"
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
  # Strip whole-line comments, trailing inline comments, surrounding whitespace,
  # and blank lines; then exact-match. Both `path` and `path  # reason` work.
  sed -E 's/[[:space:]]*#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' "$OVERRIDE_FILE" 2>/dev/null \
    | grep -v '^$' \
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
# "Non-trivial" is judged by audit-time `/ak-tests-review` (Layer 2 lives there now,
# not per-commit). Layer 1 keeps modifications WARN-only — never block.
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
  echo "    3. Bypass for this commit (recorded as a Tests-Coverage-Bypass: trailer):"
  echo "       git -c devshop.testsCoverageReason=\"<why this file legitimately ships without a test>\" commit ..."
  FAILED=true
fi

if [ -n "$BLOCK_ORPHAN" ]; then
  echo ""
  echo "✖ BLOCKING: Source files removed but paired tests still present:"
  echo -n "$BLOCK_ORPHAN"
  echo "  Stage the test deletion in the same commit, OR bypass for this commit"
  echo "  (recorded as a Tests-Coverage-Bypass: trailer):"
  echo "    git -c devshop.testsCoverageReason=\"<why orphan stays>\" commit ..."
  FAILED=true
fi

# --- Bypass: accept on flag presence (no LLM call). Trailer emission is the
# --- prepare-commit-msg hook's job — see append-bypass-trailers.sh.
if [ "$FAILED" = true ]; then
  REASON=$(git config --get devshop.testsCoverageReason 2>/dev/null || true)
  if [ -n "$REASON" ]; then
    echo ""
    echo "⚠ Tests-coverage block bypassed: $REASON"
    echo "  → recorded as Tests-Coverage-Bypass: trailer; will be revisited at audit time."
    FAILED=false
  fi
fi

if [ -n "$WARN_MODIFIED" ] && [ "$FAILED" = false ]; then
  echo ""
  echo "⚠ Modified source files without staged test changes:"
  echo -n "$WARN_MODIFIED"
  echo "  This is a warning — commit will proceed. Audit-time /ak-tests-review will"
  echo "  judge whether the existing test still covers the new behavior."
fi

[ "$FAILED" = true ] && exit 1
exit 0
