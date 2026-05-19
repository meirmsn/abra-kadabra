#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-docs-coverage-project.sh
# Layer-1 deterministic docs-coverage hook for project repos:
#   New page/route/wrapper → CLAUDE.md must be staged
#   New posthog.capture / Sentry.captureException call site → METRICS.md must be staged
#   DELETE source while doc still references it → BLOCK
# Bypass via `git -c devshop.docsCoverageReason="<why>"` accepts on flag presence
# (no LLM call). Trailer emission is the prepare-commit-msg hook's job; audit-time
# `/ak-docs-review` harvests the trailer (PR-C migration — see kit/ROADMAP.md).

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-docs-coverage-project.sh"
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

# Tests for the legacy CLAUDE.md-as-destination behavior were removed 2026-05-18
# (CLAUDE.md architecture migration — per kit/docs/guide/claude-md.md). New
# surfaces now demand the AREA README (apps/<x>/README.md, packages/<x>/README.md,
# supabase/functions/README.md) instead of CLAUDE.md. Per-area README coverage
# is tested below (search for "per-package README (opt-in by package)" section).

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

# Stale-reference scan covered post-migration by the per-area-README tests below
# (search for "stale reference now scans per-package READMEs"). CLAUDE.md is
# still in the scan target list — pre-migration entries citing deleted source
# paths still surface — but legacy CLAUDE.md-as-destination tests removed.

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

@test "no-op when modifying existing page.tsx (only ADD triggers area README requirement)" {
  mkdir -p "$TEST_REPO/apps/web"
  echo "# apps/web" > "$TEST_REPO/apps/web/README.md"
  git -C "$TEST_REPO" add apps/web/README.md
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  git -C "$TEST_REPO" add apps/web/README.md apps/web/app/list/page.tsx
  git -C "$TEST_REPO" commit -q -m "add page"
  echo 'export default function P() { return null; }' > "$TEST_REPO/apps/web/app/list/page.tsx"
  git -C "$TEST_REPO" add apps/web/app/list/page.tsx
  run_script
  assert_success
}

# --- multi-trigger ---

@test "BLOCK lists all triggers when multiple surfaces added" {
  # Seed area READMEs so the area-README triggers fire for both surfaces.
  mkdir -p "$TEST_REPO/apps/web" "$TEST_REPO/packages/core"
  echo "# apps/web" > "$TEST_REPO/apps/web/README.md"
  echo "# packages/core" > "$TEST_REPO/packages/core/README.md"
  git -C "$TEST_REPO" add apps/web/README.md packages/core/README.md
  git -C "$TEST_REPO" commit -q -m "seed READMEs"
  stage_file apps/web/app/list/page.tsx "export default function P() {}"
  stage_file packages/core/src/api/orders.ts "export const fetchOrders = async () => {}"
  run_script
  assert_failure
  assert_output --partial "apps/web/app/list/page.tsx"
  assert_output --partial "packages/core/src/api/orders.ts"
}

# --- OVERVIEW.md / ARCHITECTURE.md (opt-in: trigger only fires when file exists) ---

@test "PASS: new page when OVERVIEW.md does not exist (opt-in not engaged)" {
  stage_file apps/web/app/about/page.tsx "export default function P() {}"
  echo "# CLAUDE.md\n- about at apps/web/app/about/page.tsx" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  # OVERVIEW.md absent → trigger silent
  run_script
  assert_success
}

@test "BLOCK: new page when OVERVIEW.md exists but is NOT staged" {
  echo "# OVERVIEW" > "$TEST_REPO/OVERVIEW.md"
  git -C "$TEST_REPO" add OVERVIEW.md
  git -C "$TEST_REPO" commit -q -m "seed OVERVIEW"
  stage_file apps/web/app/about/page.tsx "export default function P() {}"
  echo "# CLAUDE.md\n- about at apps/web/app/about/page.tsx" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_failure
  assert_output --partial "OVERVIEW.md NOT staged"
}

@test "PASS: new page when OVERVIEW.md exists AND is staged" {
  echo "# OVERVIEW" > "$TEST_REPO/OVERVIEW.md"
  git -C "$TEST_REPO" add OVERVIEW.md
  git -C "$TEST_REPO" commit -q -m "seed OVERVIEW"
  stage_file apps/web/app/about/page.tsx "export default function P() {}"
  echo "# CLAUDE.md\n- about at apps/web/app/about/page.tsx" > "$TEST_REPO/CLAUDE.md"
  echo "# OVERVIEW\n- about flow" > "$TEST_REPO/OVERVIEW.md"
  git -C "$TEST_REPO" add CLAUDE.md OVERVIEW.md
  run_script
  assert_success
}

@test "BLOCK: new page when ARCHITECTURE.md exists but is NOT staged" {
  echo "# ARCH" > "$TEST_REPO/ARCHITECTURE.md"
  git -C "$TEST_REPO" add ARCHITECTURE.md
  git -C "$TEST_REPO" commit -q -m "seed ARCH"
  stage_file apps/web/app/about/page.tsx "export default function P() {}"
  echo "# CLAUDE.md\n- about at apps/web/app/about/page.tsx" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_failure
  assert_output --partial "ARCHITECTURE.md NOT staged"
}

@test "PASS: new packages/<x>/src/ file does NOT trigger ARCHITECTURE.md (only entrypoint surfaces do)" {
  echo "# ARCH" > "$TEST_REPO/ARCHITECTURE.md"
  git -C "$TEST_REPO" add ARCHITECTURE.md
  git -C "$TEST_REPO" commit -q -m "seed ARCH"
  stage_file packages/core/src/util/format.ts "export const fmt = (s: string) => s"
  run_script
  assert_success
}

# --- per-package README (opt-in by package) ---

@test "PASS: new file under apps/web/ when apps/web/README.md does NOT exist" {
  stage_file apps/web/components/Button.tsx "export const Button = () => null"
  # No apps/web/README.md → trigger silent
  run_script
  assert_success
}

@test "BLOCK: new file under apps/web/ when apps/web/README.md exists but is NOT staged" {
  mkdir -p "$TEST_REPO/apps/web"
  echo "# apps/web" > "$TEST_REPO/apps/web/README.md"
  git -C "$TEST_REPO" add apps/web/README.md
  git -C "$TEST_REPO" commit -q -m "seed apps/web README"
  stage_file apps/web/components/Button.tsx "export const Button = () => null"
  run_script
  assert_failure
  assert_output --partial "apps/web/README.md"
  assert_output --partial "apps/web/components/Button.tsx"
}

@test "PASS: new file under apps/web/ when apps/web/README.md is staged" {
  mkdir -p "$TEST_REPO/apps/web"
  echo "# apps/web" > "$TEST_REPO/apps/web/README.md"
  git -C "$TEST_REPO" add apps/web/README.md
  git -C "$TEST_REPO" commit -q -m "seed apps/web README"
  stage_file apps/web/components/Button.tsx "export const Button = () => null"
  echo "# apps/web\n- Button" > "$TEST_REPO/apps/web/README.md"
  git -C "$TEST_REPO" add apps/web/README.md
  run_script
  assert_success
}

@test "PASS: test files under apps/web/ do NOT trigger per-package README requirement" {
  mkdir -p "$TEST_REPO/apps/web"
  echo "# apps/web" > "$TEST_REPO/apps/web/README.md"
  git -C "$TEST_REPO" add apps/web/README.md
  git -C "$TEST_REPO" commit -q -m "seed apps/web README"
  stage_file apps/web/lib/util.test.ts "test('x', () => {})"
  run_script
  assert_success
}

@test "BLOCK: new file under packages/core/src/ when packages/core/README.md exists but NOT staged" {
  mkdir -p "$TEST_REPO/packages/core"
  echo "# packages/core" > "$TEST_REPO/packages/core/README.md"
  git -C "$TEST_REPO" add packages/core/README.md
  git -C "$TEST_REPO" commit -q -m "seed packages/core README"
  stage_file packages/core/src/api/orders.ts "export const fetchOrders = async () => {}"
  echo "# CLAUDE.md\n- orders at packages/core/src/api/orders.ts" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_failure
  assert_output --partial "packages/core/README.md"
}

@test "BLOCK: new file under supabase/functions/ when supabase/functions/README.md exists but NOT staged" {
  mkdir -p "$TEST_REPO/supabase/functions"
  echo "# functions" > "$TEST_REPO/supabase/functions/README.md"
  git -C "$TEST_REPO" add supabase/functions/README.md
  git -C "$TEST_REPO" commit -q -m "seed functions README"
  stage_file supabase/functions/add-item/index.ts "Deno.serve(() => new Response('ok'))"
  run_script
  assert_failure
  assert_output --partial "supabase/functions/README.md"
}

@test "PASS: new file in packages/<other> does not trigger another package's README" {
  # Only packages/core/README.md exists; adding to packages/ui should be silent.
  mkdir -p "$TEST_REPO/packages/core"
  echo "# core" > "$TEST_REPO/packages/core/README.md"
  git -C "$TEST_REPO" add packages/core/README.md
  git -C "$TEST_REPO" commit -q -m "seed core README"
  stage_file packages/ui/src/Button.tsx "export const Button = () => null"
  run_script
  assert_success
}

# --- stale reference now scans per-package READMEs ---

@test "BLOCK: source delete leaves stale reference in apps/<x>/README.md" {
  mkdir -p "$TEST_REPO/apps/web"
  stage_file apps/web/components/Button.tsx "export const Button = () => null"
  cat > "$TEST_REPO/apps/web/README.md" <<EOF
# apps/web
- Button at apps/web/components/Button.tsx
EOF
  git -C "$TEST_REPO" add apps/web/components/Button.tsx apps/web/README.md
  git -C "$TEST_REPO" commit -q -m "add Button"
  git -C "$TEST_REPO" rm apps/web/components/Button.tsx -q
  # Don't update apps/web/README.md → stale ref
  run_script
  assert_failure
  assert_output --partial "apps/web/components/Button.tsx referenced in apps/web/README.md"
}

# --- Layer 1 bypass: flag-presence (no LLM call) ---

@test "bypass: flag presence accepts new posthog.capture without METRICS.md (no LLM call)" {
  stage_file apps/web/lib/foo.ts "import { posthog } from '..'; posthog.capture('event', {});"
  git -C "$TEST_REPO" config devshop.docsCoverageReason "deferring METRICS.md taxonomy entry to end of feature"
  run_script
  assert_success
  assert_output --partial "Docs-coverage block bypassed"
  assert_output --partial "Docs-Coverage-Bypass: trailer"
}

@test "bypass: empty flag value still blocks" {
  stage_file apps/web/lib/foo.ts "import { posthog } from '..'; posthog.capture('event', {});"
  git -C "$TEST_REPO" config devshop.docsCoverageReason ""
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}
