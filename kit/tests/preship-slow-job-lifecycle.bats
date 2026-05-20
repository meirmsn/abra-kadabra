#!/usr/bin/env bats
# Tests for kit/scripts/preship/slow-job-lifecycle-check.sh
#
# Pre-ship gate: regression guard for the day-one-active slow-job (since
# template-ci-overhaul, 2026-05-19). Asserts the slow + changes jobs are
# uncommented, the if: predicates carry the right gates, the edge-runtime
# retry is wired, per-step hashFiles guards are present where the project
# lacks the corresponding content, the Start local Supabase step is
# unguarded (ambient signal), and branch protection includes 'slow'.
# See kit/docs/guide/conventions.md § Slow-Job Lifecycle.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/slow-job-lifecycle-check.sh"
}

# Helper: run the script with isolated PATH so the gh-dependent branch-protection
# sub-check degrades silently (no real gh leakage from the host environment).
run_script() {
  run env PATH="$MOCK_BIN:/usr/bin:/bin" bash "$SCRIPT" "$TEST_REPO"
}

# Helper: write a ci.yml fixture under the test repo's .github/workflows/.
write_ci_yml() {
  mkdir -p "$TEST_REPO/.github/workflows"
  cat > "$TEST_REPO/.github/workflows/ci.yml"
}

# Helper: add an integration test file (content marker for Check 4 migration
# guard — actually we use add_migration() for that; this is for Check 5).
add_integration_test() {
  mkdir -p "$TEST_REPO/packages/core/src"
  touch "$TEST_REPO/packages/core/src/foo.integration.test.ts"
}

# Helper: add an E2E spec (controls Check 4 Playwright-guard scoping AND
# Check 5 playwright-invocation requirement).
add_e2e_spec() {
  mkdir -p "$TEST_REPO/apps/web/e2e"
  touch "$TEST_REPO/apps/web/e2e/auth.spec.ts"
}

# Helper: add a migration file (controls Check 4 migration-guard scoping).
add_migration() {
  mkdir -p "$TEST_REPO/supabase/migrations"
  touch "$TEST_REPO/supabase/migrations/001_init.sql"
}

# Helper: emit the canonical "active slow-job" YAML body that should pass on
# any project (empty-state or with content). The fixture includes all five
# hashFiles guards + the unguarded Start local Supabase + the changes-job
# wiring + the Edge runtime probe phrase. Used by Check-1..Check-6 tests
# where the focus is on a DIFFERENT regression and the slow-job-as-shipped
# must be otherwise canonical.
write_canonical_ci_yml() {
  write_ci_yml <<'YML'
name: CI
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
jobs:
  fast:
    runs-on: ubuntu-latest
  changes:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - name: Install Playwright browsers with deps (chromium + webkit)
        if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''
        run: pnpm --filter apps/web exec playwright install --with-deps chromium webkit
      - name: Start local Supabase (with edge-runtime health-check retry)
        run: |
          # Edge runtime probe loop
          echo "probe /functions/v1/"
      - name: Schema type-drift check
        if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-type-drift.sh
      - name: Migration rollback round-trip
        if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-rollback-explain.sh
      - name: Build web app for E2E
        if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''
        run: pnpm turbo run build --filter=apps/web
      - name: Start next + run Playwright E2E
        if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''
        run: pnpm --filter apps/web test:e2e
YML
}

# --- n/a outcomes ---

@test "n/a when no .github/workflows/ci.yml" {
  run_script
  assert_success
  assert_output --partial "n/a (no .github/workflows/ci.yml)"
}

# --- pass outcomes ---

@test "pass on empty-state project with canonical template shape (no content, all guards present)" {
  # Brand-new scaffolds: zero migrations, zero e2e specs, canonical guards
  # in place. The slow-job ships active from day one and short-circuits the
  # heavy steps via hashFiles guards — gate confirms the canonical shape.
  write_canonical_ci_yml
  run_script
  assert_success
  assert_output "pass"
}

@test "pass on project with E2E content + canonical guards" {
  add_e2e_spec
  write_canonical_ci_yml
  run_script
  assert_success
  assert_output "pass"
}

@test "pass on project with both content types + canonical guards" {
  add_e2e_spec
  add_migration
  write_canonical_ci_yml
  run_script
  assert_success
  assert_output "pass"
}

@test "pass on legacy project (uncommented slow-job + content + NO hashFiles guards — Check 4 content-scoped)" {
  # Lalista/home-os shape: slow-job was uncommented manually pre-overhaul,
  # both content types exist, but the hashFiles guards aren't in the YAML.
  # Check 4 is content-scoped — only fires when the matching content is
  # MISSING. Because both content types are present, the unguarded steps
  # would fire anyway and the absence of guards is a no-op. Gate passes.
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - name: Install Playwright browsers
        run: pnpm exec playwright install
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - run: bash scripts/ci-type-drift.sh
      - run: bash scripts/ci-rollback-explain.sh
      - run: pnpm test:e2e
YML
  run_script
  assert_success
  assert_output "pass"
}

# --- Check 1: slow-job uncommented ---

@test "findings: slow-job is commented out (re-comment regression)" {
  write_ci_yml <<'YML'
name: CI
jobs:
  fast:
    runs-on: ubuntu-latest
  # slow:
  #   if: github.event_name == 'pull_request'
  #   runs-on: ubuntu-latest
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "slow-job is commented out"
  # Message must point at the active-from-day-one model, not the old
  # "uncomment when threshold crossed" model.
  assert_output --partial "ships active from day one"
}

@test "findings: slow-job missing entirely (no commented stub either)" {
  write_ci_yml <<'YML'
name: CI
jobs:
  fast:
    runs-on: ubuntu-latest
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "slow-job not present"
}

# --- Check 2: slow-job if: predicate ---

@test "findings: slow-job 'if:' predicate missing pull_request gate (Check 2 — rescoped)" {
  # The rescoped Check 2 finds the slow-job's if: line via the
  # `needs.changes.outputs.runtime` reference (only the slow-job has that)
  # and asserts it also carries the pull_request gate. A broken predicate
  # (only runtime gate, no pull_request) now triggers the finding even
  # though the changes: job's if: matches pull_request elsewhere.
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - run: echo "Edge runtime probe loop"
      - run: pnpm test:e2e
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "missing the"
  assert_output --partial "github.event_name == 'pull_request'"
}

# --- Check 3: edge-runtime retry pattern wired ---

@test "findings: edge-runtime retry pattern stripped (no 'Edge runtime probe' phrase)" {
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - name: Start local Supabase
        run: pnpm test:e2e
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "missing edge-runtime health-check retry"
}

# --- Check 4: empty-state hashFiles guards (content-scoped) ---

@test "findings: Check 4 — content-less project missing Playwright hashFiles guard would crash slow-job" {
  # Empty-state project + slow-job lacks the Playwright hashFiles guard.
  # Unguarded `pnpm --filter apps/web exec playwright install` would crash
  # because apps/web doesn't exist yet. Gate raises the finding.
  # (No add_e2e_spec → HAS_E2E empty → Check 4 fires.)
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - name: Install Playwright
        run: pnpm exec playwright install
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-type-drift.sh
      - if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-rollback-explain.sh
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "empty-state guard on Playwright steps"
  assert_output --partial "apps/web/e2e/**/*.spec.ts"
}

@test "findings: Check 4 — content-less project missing migration hashFiles guard would crash slow-job" {
  # Empty-state project + slow-job lacks the migration hashFiles guard.
  # Unguarded `bash scripts/ci-type-drift.sh` crashes because supabase/
  # migrations/ doesn't exist yet. Gate raises the finding.
  # (No add_migration → HAS_MIGRATIONS empty → Check 4 fires.)
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''
        run: pnpm --filter apps/web exec playwright install
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - name: Schema type-drift check
        run: bash scripts/ci-type-drift.sh
      - name: Migration rollback round-trip
        run: bash scripts/ci-rollback-explain.sh
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "empty-state guard on migration steps"
  assert_output --partial "supabase/migrations/*.sql"
}

@test "no Check 4 finding: project with content + no guards (legacy lalista/home-os shape — content-scoped skip)" {
  # Same as the "pass on legacy project" test above; pinning here to
  # explicitly assert Check 4 does NOT fire when content is present.
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - run: pnpm exec playwright install
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - run: bash scripts/ci-type-drift.sh
      - run: pnpm test:e2e
YML
  run_script
  assert_success
  refute_output --partial "empty-state guard"
}

# --- Check 4b: Start local Supabase must NOT be guarded (ambient signal) ---

@test "findings: Check 4b — hashFiles guard added to Start local Supabase (ambient signal regression)" {
  # The Start local Supabase step is the unconditional heartbeat. If a
  # future tidy-up adds an `if: hashFiles(...)` directive right after the
  # step's name, the ambient signal is lost and brand-new projects can no
  # longer see Supabase boot. Check 4b reads the line immediately after
  # `- name: Start local Supabase` and refuses any hashFiles directive.
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - name: Install Playwright
        if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''
        run: pnpm exec playwright install
      - name: Start local Supabase
        if: hashFiles('supabase/config.toml') != ''
        run: |
          # Edge runtime probe loop
          echo probe
      - if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-type-drift.sh
      - if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-rollback-explain.sh
      - if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''
        run: pnpm test:e2e
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "'Start local Supabase' step has a hashFiles guard"
  assert_output --partial "ambient health signal"
}

# --- Check 5: slow-job invokes the test glob ---

@test "findings: integration tests exist but slow-job doesn't invoke them" {
  add_integration_test
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - run: pnpm test:unit
      - run: pnpm exec playwright test
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "doesn't invoke them"
}

@test "findings: E2E specs exist but slow-job doesn't invoke playwright" {
  # Check 5 grep is case-insensitive on 'playwright', so the fixture must
  # avoid the word entirely (including in echo strings, step names, or comments).
  add_e2e_spec
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - if: hashFiles('apps/web/e2e/**/*.spec.ts') != ''
        run: echo "(no browser-test invocation in this fixture)"
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-type-drift.sh
      - if: hashFiles('supabase/migrations/*.sql') != ''
        run: bash scripts/ci-rollback-explain.sh
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "doesn't invoke playwright"
}

# --- Check 6: skip-on-docs-only filter wired ---

@test "findings: filter absent on uncommented slow-job (no changes: job)" {
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - run: pnpm test:e2e
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "missing skip-on-docs-only filter"
  assert_output --partial "Skip-on-docs-only filter"
}

@test "findings: changes: job exists but slow-job's needs: not wired" {
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: fast
    steps:
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - run: pnpm test:e2e
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "needs:' does not include 'changes'"
}

@test "findings: changes: job exists but slow-job's if: does not reference runtime" {
  add_e2e_spec
  add_migration
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - name: Start local Supabase
        run: |
          # Edge runtime probe loop
          echo probe
      - run: pnpm test:e2e
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "if:' does not reference 'needs.changes.outputs.runtime'"
}

# --- Multi-gap: confirm multiple findings surface together ---

@test "findings: multiple gaps reported together (retry stripped + test glob missing on integration-tests + content-less Playwright guard)" {
  # Content-less project + slow-job missing the retry pattern + integration
  # tests exist but invocation is missing + Playwright guard missing. Three
  # findings should fire under the new check set.
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      runtime: ${{ steps.classify.outputs.runtime }}
    steps:
      - id: classify
        run: echo "runtime=true" >> "$GITHUB_OUTPUT"
  slow:
    if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
    steps:
      - run: echo "no retry pattern"
      - run: bash scripts/ci-type-drift.sh
      - run: bash scripts/ci-rollback-explain.sh
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "missing edge-runtime health-check retry"
  assert_output --partial "doesn't invoke them"
  assert_output --partial "empty-state guard"
}

# --- Branch-protection sub-check (gh-dependent) ---

# Helper: write a canonical well-formed slow-job ci.yml so the only finding
# source under test is the branch-protection sub-check.
write_good_slow_job_yml() {
  add_e2e_spec
  add_migration
  write_canonical_ci_yml
}

# Stub gh to respond to both call shapes the script makes.
# $1 = JSON to return on `gh api repos/.../branches/main`
stub_gh_with_branch_response() {
  local response="$1"
  cat > "$MOCK_BIN/gh" <<STUB
#!/bin/bash
case "\$*" in
  "repo view --json nameWithOwner --jq .nameWithOwner")
    echo "fake/repo"
    ;;
  *"repos/fake/repo/branches/main"*)
    cat <<'JSON'
$response
JSON
    ;;
  *)
    exit 1
    ;;
esac
STUB
  chmod +x "$MOCK_BIN/gh"
}

@test "branch-protection: PAT lacks admin (no .protection key in response) → no false-positive" {
  write_good_slow_job_yml
  stub_gh_with_branch_response '{"name":"main","protected":false}'
  run_script
  assert_success
  assert_output "pass"
  refute_output --partial "branch protection"
}

@test "branch-protection: gh returns error JSON {message: ...} (legacy /protection 403) → no false-positive" {
  write_good_slow_job_yml
  stub_gh_with_branch_response '{"message":"Resource not accessible by personal access token","status":"403"}'
  run_script
  assert_success
  assert_output "pass"
  refute_output --partial "branch protection"
}

@test "branch-protection: 'slow' present in .protection.required_status_checks.contexts (older format)" {
  write_good_slow_job_yml
  stub_gh_with_branch_response '{"protection":{"required_status_checks":{"contexts":["fast","slow"]}}}'
  run_script
  assert_success
  assert_output "pass"
}

@test "branch-protection: 'slow' present in .protection.required_status_checks.checks[].context (newer format)" {
  write_good_slow_job_yml
  stub_gh_with_branch_response '{"protection":{"required_status_checks":{"checks":[{"context":"fast","app_id":1},{"context":"slow","app_id":1}]}}}'
  run_script
  assert_success
  assert_output "pass"
}

@test "branch-protection: 'slow' missing from BOTH contexts and checks → finding fires" {
  write_good_slow_job_yml
  stub_gh_with_branch_response '{"protection":{"required_status_checks":{"contexts":["fast"],"checks":[{"context":"fast","app_id":1}]}}}'
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "branch protection on main does NOT include 'slow'"
}
