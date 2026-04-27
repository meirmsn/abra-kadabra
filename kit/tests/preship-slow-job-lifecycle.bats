#!/usr/bin/env bats
# Tests for kit/scripts/preship/slow-job-lifecycle-check.sh
# Pre-ship gate that asserts CI's slow-job is correctly enabled once a project
# crosses Phase 1c (first integration test) or Phase 1g (first E2E spec).
# See kit/docs/guide/conventions.md § Slow-Job Lifecycle for the convention.

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

# Helper: cross the Phase 1c threshold by creating an integration test file.
add_integration_test() {
  mkdir -p "$TEST_REPO/packages/core/src"
  touch "$TEST_REPO/packages/core/src/foo.integration.test.ts"
}

# Helper: cross the Phase 1g threshold by creating an E2E spec file.
add_e2e_spec() {
  mkdir -p "$TEST_REPO/apps/web/e2e"
  touch "$TEST_REPO/apps/web/e2e/auth.spec.ts"
}

# --- n/a outcomes ---

@test "n/a when no .github/workflows/ci.yml" {
  run_script
  assert_success
  assert_output --partial "n/a (no .github/workflows/ci.yml)"
}

@test "n/a when CI yml exists but no integration tests or E2E specs (Phase 1c/1g threshold not crossed)" {
  write_ci_yml <<'YML'
name: CI
jobs:
  fast:
    runs-on: ubuntu-latest
YML
  run_script
  assert_success
  assert_output --partial "n/a (no integration tests or E2E specs"
}

# --- pass outcome ---

@test "pass when slow-job is correctly configured (integration tests + canonical predicate + retry + invocation)" {
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  fast:
    runs-on: ubuntu-latest
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Verify edge runtime healthy
        run: |
          probe_edge_runtime() { curl ...; }
          # Edge runtime probe loop
      - run: pnpm test:integration
YML
  # gh not in isolated PATH → branch-protection sub-check degrades silently.
  run_script
  assert_success
  assert_output "pass"
}

@test "pass when E2E specs trigger threshold and slow-job invokes playwright" {
  add_e2e_spec
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Edge runtime probe loop"
      - run: pnpm exec playwright test
YML
  run_script
  assert_success
  assert_output "pass"
}

# --- findings ---

@test "findings: slow-job still commented out past Phase 1c threshold" {
  add_integration_test
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
}

@test "findings: slow-job missing entirely (no commented stub either)" {
  add_integration_test
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

@test "findings: slow-job 'if:' predicate is wrong shape (not pull_request)" {
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: always()
    runs-on: ubuntu-latest
    steps:
      - run: echo "Edge runtime probe"
      - run: pnpm test:integration
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "predicate doesn't match canonical"
}

@test "findings: edge-runtime retry pattern stripped (no 'Edge runtime probe' phrase)" {
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: pnpm test:integration
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "missing edge-runtime health-check retry"
}

@test "findings: integration tests exist but slow-job doesn't invoke them" {
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Edge runtime probe"
      - run: pnpm test:unit
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "doesn't invoke them"
}

@test "findings: E2E specs exist but slow-job doesn't invoke playwright" {
  add_e2e_spec
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Edge runtime probe"
      - run: pnpm test:integration
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "doesn't invoke playwright"
}

@test "findings: multiple gaps reported together" {
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: always()
    runs-on: ubuntu-latest
    steps:
      - run: echo "no retry pattern here"
      - run: pnpm test:unit
YML
  run_script
  assert_success
  assert_output --partial "findings (3)"
  assert_output --partial "predicate doesn't match canonical"
  assert_output --partial "missing edge-runtime health-check retry"
  assert_output --partial "doesn't invoke them"
}

# --- threshold detection edge cases ---

@test "trigger detection: E2E spec under apps/*/e2e/ for non-web app crosses threshold" {
  # Verify the find pattern matches apps/<any>/e2e/, not just apps/web/e2e/
  mkdir -p "$TEST_REPO/apps/admin/e2e"
  touch "$TEST_REPO/apps/admin/e2e/dashboard.spec.ts"
  write_ci_yml <<'YML'
name: CI
jobs:
  fast:
    runs-on: ubuntu-latest
YML
  run_script
  assert_success
  # Threshold crossed → finding for "slow-job not present"
  assert_output --partial "findings"
  assert_output --partial "slow-job not present"
}

@test "trigger detection: integration test under packages/* crosses threshold" {
  mkdir -p "$TEST_REPO/packages/ui/src"
  touch "$TEST_REPO/packages/ui/src/component.integration.test.ts"
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
