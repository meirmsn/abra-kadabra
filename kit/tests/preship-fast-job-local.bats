#!/usr/bin/env bats
# Tests for kit/scripts/preship/fast-job-local.sh
# Layer 1 of /preflight — runs lint + typecheck + test:unit + build via turbo.

setup() {
  load helpers/setup
  setup_mock_bin
  create_test_repo
  SCRIPT="$SCRIPTS_DIR/preship/fast-job-local.sh"

  # Default `pnpm` stub: every step succeeds.
  cat > "$MOCK_BIN/pnpm" <<STUB
#!/bin/bash
echo "pnpm \$*" >> "$MOCK_BIN/pnpm.calls"
exit 0
STUB
  chmod +x "$MOCK_BIN/pnpm"
}

# Helper: invoke the script with a controlled PATH.
run_script() {
  run env PATH="$MOCK_BIN:/usr/bin:/bin" bash "$SCRIPT" "$TEST_REPO"
}

# Helper: create a turbo.json so the gate isn't n/a.
turbo_repo() {
  echo '{"$schema":"https://turbo.build/schema.json"}' > "$TEST_REPO/turbo.json"
  git -C "$TEST_REPO" add turbo.json
  git -C "$TEST_REPO" commit -q -m "add turbo.json"
}

# --- n/a outcomes ---

@test "n/a when project has no turbo.json" {
  run_script
  assert_success
  assert_output --partial "n/a (no turbo.json"
  assert_output --partial "## Dismissals"
  assert_output --partial "None"
}

# --- pass outcome ---

@test "pass when all four turbo tasks succeed" {
  turbo_repo
  run_script
  assert_success
  assert_output --partial "pass"
  assert_output --partial "## Dismissals"
  assert_output --partial "None"
  # All four steps invoked.
  run cat "$MOCK_BIN/pnpm.calls"
  assert_output --partial "turbo run lint"
  assert_output --partial "turbo run typecheck"
  assert_output --partial "turbo run test:unit"
  assert_output --partial "turbo run build"
}

# --- findings outcome ---

@test "findings when a turbo task exits non-zero" {
  turbo_repo
  # Replace pnpm stub to fail on `test:unit` only.
  cat > "$MOCK_BIN/pnpm" <<STUB
#!/bin/bash
echo "pnpm \$*" >> "$MOCK_BIN/pnpm.calls"
case "\$*" in
  *"test:unit"*) exit 2 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$MOCK_BIN/pnpm"
  run_script
  assert_success
  assert_output --partial "findings (1)"
  assert_output --partial "test:unit failed"
  assert_output --partial "re-run"
}

@test "findings count reflects multiple failing steps" {
  turbo_repo
  cat > "$MOCK_BIN/pnpm" <<STUB
#!/bin/bash
echo "pnpm \$*" >> "$MOCK_BIN/pnpm.calls"
case "\$*" in
  *"lint"*|*"build"*) exit 1 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$MOCK_BIN/pnpm"
  run_script
  assert_success
  assert_output --partial "findings (2)"
  assert_output --partial "lint failed"
  assert_output --partial "build failed"
}

# --- budget exceeded ---

@test "budget exceeded emits [budget exceeded] suffix + CI-deferral dismissal" {
  turbo_repo
  # Make `pnpm` hang past the budget. Use a tiny LINT_TIMEOUT_S to trigger fast.
  cat > "$MOCK_BIN/pnpm" <<STUB
#!/bin/bash
case "\$*" in
  *"lint"*) sleep 5 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$MOCK_BIN/pnpm"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      LINT_TIMEOUT_S=1 \
      bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "findings (1) [budget exceeded]"
  assert_output --partial "lint exceeded"
  assert_output --partial "deferred to CI fast-job"
}

# --- bypass-flag short-circuits ---

@test "bypass: fastJobSkipReason + adversarial PASS → skipped pass" {
  mock_adversarial_review PASS
  turbo_repo
  git -C "$TEST_REPO" config devshop.fastJobSkipReason "specific reason — see TODOS.md § X"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      ADVERSARIAL_REVIEW_SCRIPT="$MOCK_BIN/adversarial-review.sh" \
      bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "pass (skipped — adversarially reviewed)"
  assert_output --partial "skipped via devshop.fastJobSkipReason"
  # No turbo tasks ran.
  refute [ -f "$MOCK_BIN/pnpm.calls" ]
}

@test "bypass: fastJobSkipReason + adversarial FAIL → findings (1) pending" {
  mock_adversarial_review FAIL
  turbo_repo
  git -C "$TEST_REPO" config devshop.fastJobSkipReason "lazy skip"
  run env PATH="$MOCK_BIN:/usr/bin:/bin" \
      ADVERSARIAL_REVIEW_SCRIPT="$MOCK_BIN/adversarial-review.sh" \
      bash "$SCRIPT" "$TEST_REPO"
  assert_success
  assert_output --partial "findings (1) pending"
  assert_output --partial "fastJobSkipReason rejected"
}

# --- canonical gate shape ---

@test "always emits ## Dismissals section" {
  turbo_repo
  run_script
  assert_success
  assert_output --partial "## Dismissals"
}

@test "outcome line is first non-empty line of output" {
  turbo_repo
  run_script
  assert_success
  # Strip leading blanks; first line should be 'pass'.
  first_line="$(echo "$output" | awk 'NF{print; exit}')"
  [ "$first_line" = "pass" ]
}
