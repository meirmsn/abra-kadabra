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

@test "pass when slow-job is correctly configured (integration tests + canonical predicate + retry + invocation + skip-filter)" {
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  fast:
    runs-on: ubuntu-latest
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

@test "pass when E2E specs trigger threshold and slow-job invokes playwright (with skip-filter)" {
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
  # Includes the canonical skip-on-docs-only filter wiring so Check 6 stays
  # silent — this fixture is intentionally testing the legacy 3-gap shape.
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
    if: always() && needs.changes.outputs.runtime == 'true'
    runs-on: ubuntu-latest
    needs: [fast, changes]
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

# --- D3: skip-on-docs-only filter (Check 6) ---

@test "pass when slow-job has skip-on-docs-only filter present in canonical shape" {
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
      - run: echo "Edge runtime probe loop"
      - run: pnpm test:integration
YML
  run_script
  assert_success
  assert_output "pass"
}

@test "findings: filter absent on uncommented slow-job (no changes: job)" {
  add_integration_test
  write_ci_yml <<'YML'
name: CI
jobs:
  slow:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - run: echo "Edge runtime probe loop"
      - run: pnpm test:integration
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "missing skip-on-docs-only filter"
  # Remediation message points at the conventions.md sub-section.
  assert_output --partial "Skip-on-docs-only filter"
}

@test "findings: changes: job exists but slow-job's needs: not wired" {
  add_integration_test
  # Partial wire — changes: job is live with runtime output, slow-job's `if:`
  # references the runtime gate, but `needs:` lacks `changes`. The classify
  # job runs but the slow-job doesn't depend on it, so docs-only PRs won't
  # get the skip behavior even though the predicate is in place.
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
      - run: echo "Edge runtime probe loop"
      - run: pnpm test:integration
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "needs:' does not include 'changes'"
}

@test "findings: changes: job exists but slow-job's if: does not reference runtime" {
  add_integration_test
  # Partial wire — changes: job is live, needs: includes changes, but the
  # slow-job's `if:` predicate doesn't reference the runtime gate. The
  # changes-job runs and the slow-job depends on it (so it waits for changes
  # to finish), but the gating is silently bypassed.
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
      - run: echo "Edge runtime probe loop"
      - run: pnpm test:integration
YML
  run_script
  assert_success
  assert_output --partial "findings"
  assert_output --partial "if:' does not reference 'needs.changes.outputs.runtime'"
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

# --- branch-protection sub-check (gh-dependent) ---
# Helper for these tests: the script does `gh repo view` then `gh api branches/main`.
# Stub responds to both call shapes; the test repo doesn't need to be a github clone.

# Helper: write a well-formed slow-job ci.yml so the only finding source under
# test is the branch-protection sub-check. Includes the canonical skip-on-docs-
# only filter (changes: job + slow-job's needs/if wiring) so Check 6 doesn't fire.
write_good_slow_job_yml() {
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
      - run: echo "Edge runtime probe loop"
      - run: pnpm test:integration
YML
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

@test "branch-protection: PAT lacks admin (HTTP 403 on /protection endpoint) → no false-positive (regression test for v1.22.1)" {
  write_good_slow_job_yml
  # The /branches/main endpoint succeeds even with read-only PAT; if the
  # repo IS protected but the PAT can't read /protection, the response still
  # carries .protection. Simulate the case where the response simply lacks
  # the protection key (e.g. unprotected branch, or read scope sufficient
  # but admin probe declined). Script must NOT false-flag.
  stub_gh_with_branch_response '{"name":"main","protected":false}'
  run_script
  assert_success
  assert_output "pass"
  refute_output --partial "branch protection"
}

@test "branch-protection: gh returns error JSON {message: ...} (legacy /protection 403) → no false-positive" {
  write_good_slow_job_yml
  # Belt-and-suspenders test: if some future change reverts to a privileged
  # endpoint, ensure the error-shaped response still doesn't false-flag.
  # Without `.protection.required_status_checks`, the check skips.
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
