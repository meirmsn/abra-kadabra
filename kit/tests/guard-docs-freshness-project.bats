#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-docs-freshness-project.sh
# Layer-1 deterministic docs-freshness hook for project repos:
#   New page/route/wrapper → CLAUDE.md must be staged
#   New posthog.capture / Sentry.captureException call site → METRICS.md must be staged
#   DELETE source while doc still references it → BLOCK
# Bypass via git -c devshop.docsFreshnessReviewed (Layer 2 — adversarial-review.sh docsFreshnessProject).

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-docs-freshness-project.sh"
  cd "$TEST_REPO"
  # Always seed the docs (committed, not staged) so freshness checks have something to read
  echo "# CLAUDE.md" > "$TEST_REPO/CLAUDE.md"
  echo "# METRICS.md" > "$TEST_REPO/METRICS.md"
  git -C "$TEST_REPO" add CLAUDE.md METRICS.md
  git -C "$TEST_REPO" commit -q -m "seed docs"
}

run_script() {
  run bash "$SCRIPT"
}

# --- early-exit: devshop self mode ---

@test "exits 0 when run in devshop-self mode (kit/ is real dir)" {
  mkdir -p "$TEST_REPO/kit"
  echo placeholder > "$TEST_REPO/kit/anything"
  git -C "$TEST_REPO" add kit/anything
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- new page/route requires CLAUDE.md update ---

@test "BLOCK: new page.tsx without CLAUDE.md staged" {
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  run_script
  assert_failure
  assert_output --partial "BLOCKING: New surface added that requires CLAUDE.md"
  assert_output --partial "apps/web/app/list/page.tsx"
}

@test "PASS: new page.tsx with CLAUDE.md also staged" {
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  echo "# CLAUDE.md\n## Where Things Happen\n- list at apps/web/app/list/page.tsx" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_success
}

@test "BLOCK: new layout.tsx without CLAUDE.md staged" {
  stage_file apps/web/app/auth/layout.tsx "export default function L() {}"
  run_script
  assert_failure
  assert_output --partial "apps/web/app/auth/layout.tsx"
}

@test "BLOCK: new route.ts without CLAUDE.md staged" {
  stage_file apps/web/app/api/health/route.ts "export function GET() {}"
  run_script
  assert_failure
  assert_output --partial "apps/web/app/api/health/route.ts"
}

@test "BLOCK: new packages API wrapper without CLAUDE.md staged" {
  stage_file packages/core/src/api/orders.ts "export const fetchOrders = async () => {}"
  run_script
  assert_failure
  assert_output --partial "packages/core/src/api/orders.ts"
}

@test "PASS: new packages API wrapper test file is NOT a trigger" {
  stage_file packages/core/src/api/orders.test.ts "test('x', () => {})"
  run_script
  assert_success
}

# --- new event call site requires METRICS.md update ---

@test "BLOCK: new posthog.capture call site without METRICS.md staged" {
  stage_file apps/web/components/Foo.tsx "import { posthog } from '..';
posthog.capture('thing_done', { x: 1 });"
  # CLAUDE.md is NOT a trigger for component additions, but METRICS.md is required for capture
  run_script
  assert_failure
  assert_output --partial "METRICS.md"
}

@test "PASS: new posthog.capture call site with METRICS.md staged" {
  stage_file apps/web/components/Foo.tsx "import { posthog } from '..';
posthog.capture('thing_done', { x: 1 });"
  cat > "$TEST_REPO/METRICS.md" <<EOF
# Metrics
| Event | When |
| --- | --- |
| thing_done | when foo |
EOF
  git -C "$TEST_REPO" add METRICS.md
  run_script
  assert_success
}

@test "BLOCK: new Sentry.captureException call site without METRICS.md staged" {
  stage_file apps/web/lib/error.ts "import * as Sentry from '@sentry/nextjs';
export const handle = (e) => Sentry.captureException(e);"
  run_script
  assert_failure
  assert_output --partial "METRICS.md"
}

# --- stale reference on DELETE ---

@test "BLOCK: source deleted but CLAUDE.md still references its path" {
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  echo "# CLAUDE.md\n- list at apps/web/app/list/page.tsx" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add apps/web/app/list/page.tsx CLAUDE.md
  git -C "$TEST_REPO" commit -q -m "add list"
  git -C "$TEST_REPO" rm apps/web/app/list/page.tsx -q
  # Don't update CLAUDE.md — should block on stale ref
  run_script
  assert_failure
  assert_output --partial "Source paths deleted but still referenced"
}

@test "PASS: source deleted and CLAUDE.md ref also removed in same commit" {
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  echo "# CLAUDE.md\n- list at apps/web/app/list/page.tsx" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add apps/web/app/list/page.tsx CLAUDE.md
  git -C "$TEST_REPO" commit -q -m "add list"
  git -C "$TEST_REPO" rm apps/web/app/list/page.tsx -q
  echo "# CLAUDE.md" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_success
}

# --- per-project override ---

@test "PASS when triggering path is in .devshop-docs-freshness-exempt" {
  stage_file apps/web/app/internal-only/page.tsx "export default function P() {}"
  echo 'apps/web/app/internal-only/page.tsx' > "$TEST_REPO/.devshop-docs-freshness-exempt"
  git -C "$TEST_REPO" add .devshop-docs-freshness-exempt
  run_script
  assert_success
}

@test "override file accepts trailing inline comment after path" {
  stage_file apps/web/app/internal-only/page.tsx "export default function P() {}"
  cat > "$TEST_REPO/.devshop-docs-freshness-exempt" <<EOF
apps/web/app/internal-only/page.tsx  # internal-only, no public surface
EOF
  git -C "$TEST_REPO" add .devshop-docs-freshness-exempt
  run_script
  assert_success
}

# --- no-op path ---

@test "no-op when only README.md staged" {
  stage_file README.md "x"
  run_script
  assert_success
}

@test "no-op when only test files staged" {
  stage_file apps/web/lib/util.test.ts "test('x', () => {})"
  run_script
  assert_success
}

@test "no-op when modifying existing page.tsx (only ADD triggers CLAUDE.md requirement)" {
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  git -C "$TEST_REPO" add apps/web/app/list/page.tsx
  git -C "$TEST_REPO" commit -q -m "add page"
  echo 'export default function P() { return null; }' > "$TEST_REPO/apps/web/app/list/page.tsx"
  git -C "$TEST_REPO" add apps/web/app/list/page.tsx
  run_script
  assert_success
}

# --- multi-trigger ---

@test "BLOCK lists all triggers when multiple surfaces added" {
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  stage_file packages/core/src/api/orders.ts "export const fetchOrders = async () => {}"
  run_script
  assert_failure
  assert_output --partial "apps/web/app/list/page.tsx"
  assert_output --partial "packages/core/src/api/orders.ts"
}
