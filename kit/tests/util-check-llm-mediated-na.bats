#!/usr/bin/env bats
# Tests for kit/scripts/preship/check-llm-mediated-na.sh
# Track B awk extraction: mawk-portable forbidden n/a detection.
# See specs/local-env-pillar/spec.md § T3, § Tests.

setup() {
  load helpers/setup
  SCRIPT="$SCRIPTS_DIR/preship/check-llm-mediated-na.sh"
  REVIEW_FILE="$BATS_TEST_TMPDIR/review.md"
}

# --- Test 1: plain n/a on Gate 8 (design-review) — detected, exit 1 ---

@test "detects plain n/a on Gate 8 design-review (mawk regression target)" {
  cat > "$REVIEW_FILE" <<'EOF'
<!-- audited-at: abc1234 -->

## Gate 6: /review

- Result: pass

## Dismissals

None

## Gate 7: /cso

- Result: pass

## Dismissals

None

## Gate 8: /design-review

- Result: n/a

## Dismissals

None

## Gate 9: /qa

- Result: pass

## Dismissals

None
EOF

  run bash "$SCRIPT" "$REVIEW_FILE"
  assert_failure
  assert_output --partial "FORBIDDEN n/a"
  assert_output --partial "Gate 8"
  assert_output --partial "design-review"
}

# --- Test 2: blocked (n/a per scope: ...) on Gate 9 — NOT detected, exit 0 ---

@test "allows 'blocked (n/a per scope: ...)' on Gate 9 (scope-exempt shape)" {
  cat > "$REVIEW_FILE" <<'EOF'
<!-- audited-at: abc1234 -->

## Gate 6: /review

- Result: pass

## Gate 7: /cso

- Result: pass

## Gate 8: /design-review

- Result: blocked (n/a per scope: non-UI PR, no design surface)

## Gate 9: /qa

- Result: blocked (n/a per scope: sandbox environment, no local Supabase)

EOF

  run bash "$SCRIPT" "$REVIEW_FILE"
  assert_success
  assert_output --partial "CLEAN"
}

# --- Test 3: non-LLM-mediated gate n/a (Gate 3) — NOT detected, exit 0 ---

@test "ignores n/a on non-LLM-mediated gate (Gate 3 responsive-theme)" {
  cat > "$REVIEW_FILE" <<'EOF'
<!-- audited-at: abc1234 -->

## Gate 3: responsive-theme

- Result: n/a

## Gate 6: /review

- Result: pass

## Gate 7: /cso

- Result: pass

## Gate 8: /design-review

- Result: pass

## Gate 9: /qa

- Result: pass

EOF

  run bash "$SCRIPT" "$REVIEW_FILE"
  assert_success
  assert_output --partial "CLEAN"
}

# --- Test 4: clean review.md with all gates pass — exit 0 ---

@test "clean review.md with all LLM-mediated gates passing exits 0" {
  cat > "$REVIEW_FILE" <<'EOF'
<!-- audited-at: abc1234 -->

## Gate 6: /review

- Result: pass

## Dismissals

None

## Gate 7: /cso

- Result: findings (2) pending

## Dismissals

None

## Gate 8: /design-review

- Result: pass

## Dismissals

None

## Gate 9: /qa

- Result: pass

## Dismissals

None
EOF

  run bash "$SCRIPT" "$REVIEW_FILE"
  assert_success
  assert_output --partial "CLEAN"
}

# --- Test 5: run with mawk explicitly to catch GNU-awk-only constructs ---

@test "mawk explicit: detects n/a on Gate 6 /review" {
  # Skip if mawk not available.
  command -v mawk >/dev/null 2>&1 || skip "mawk not installed"

  cat > "$REVIEW_FILE" <<'EOF'
## Gate 6: /review

- Result: n/a

## Gate 9: /qa

- Result: pass
EOF

  run env AWK_BIN="mawk" bash "$SCRIPT" "$REVIEW_FILE"
  assert_failure
  assert_output --partial "FORBIDDEN n/a"
  assert_output --partial "Gate 6"
}

@test "mawk explicit: passes on clean review.md" {
  command -v mawk >/dev/null 2>&1 || skip "mawk not installed"

  cat > "$REVIEW_FILE" <<'EOF'
## Gate 6: /review

- Result: pass

## Gate 7: /cso

- Result: pass

## Gate 8: /design-review

- Result: pass

## Gate 9: /qa

- Result: pass
EOF

  run env AWK_BIN="mawk" bash "$SCRIPT" "$REVIEW_FILE"
  assert_success
  assert_output --partial "CLEAN"
}

# --- Test 6: bold Result format detection ---

@test "detects bold **Result:** n/a format on Gate 7 /cso" {
  cat > "$REVIEW_FILE" <<'EOF'
## Gate 6: /review

- Result: pass

## Gate 7: /cso

**Result:** n/a

## Gate 8: /design-review

- Result: pass

## Gate 9: /qa

- Result: pass
EOF

  run bash "$SCRIPT" "$REVIEW_FILE"
  assert_failure
  assert_output --partial "FORBIDDEN n/a"
  assert_output --partial "Gate 7"
}

# --- Usage ---

@test "exits 64 on missing arguments" {
  run bash "$SCRIPT"
  assert_failure
  [ "$status" -eq 64 ]
  assert_output --partial "Usage:"
}

@test "exits 64 when file does not exist" {
  run bash "$SCRIPT" "/nonexistent/review.md"
  assert_failure
  [ "$status" -eq 64 ]
}
