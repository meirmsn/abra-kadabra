#!/usr/bin/env bats
# Tests for kit/scripts/preship-router-shim.sh
# Pre-ship dismissal-log helpers: scoped parse of the `## Dismissals` section,
# short-circuit on body=None, CSO JSON → dismissals shim, adversarial review
# wiring.

setup() {
  load helpers/setup
  setup_mock_bin
  SCRIPT="$SCRIPTS_DIR/preship-router-shim.sh"
}

# Make a wrapper copy of the shim with the internal reference to
# adversarial-review.sh redirected to the MOCK_BIN copy. Matches the pattern
# used by guard-commit.bats — we can't overwrite the real script in kit/scripts/.
make_shim_wrapper() {
  WRAPPER="$BATS_TEST_TMPDIR/preship-router-shim.sh"
  cp "$SCRIPT" "$WRAPPER"
  sed -i "s|bash \"\$SCRIPT_DIR/adversarial-review.sh\"|bash \"$MOCK_BIN/adversarial-review.sh\"|" "$WRAPPER"
  chmod +x "$WRAPPER"
}

# --- Scoped parse: is-empty / extract ---

@test "is-empty: returns 0 when Dismissals body is exactly None" {
  local f="$BATS_TEST_TMPDIR/report.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

some content

## Dismissals

None

## Next section
EOF
  run bash "$SCRIPT" is-empty "$f"
  assert_success
}

@test "is-empty: returns 1 when Dismissals body is a bulleted list" {
  local f="$BATS_TEST_TMPDIR/report.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

## Dismissals

- edge case X: rationale: out of scope per spec
- finding Y: rationale: tracked in TODOS

## End
EOF
  run bash "$SCRIPT" is-empty "$f"
  assert_failure 1
}

@test "is-empty: does NOT false-positive on 'None' appearing elsewhere in report" {
  # The word 'None' appears in a finding description, but the Dismissals body
  # itself is a bulleted list. Scoped parse must look only at the Dismissals
  # section body.
  local f="$BATS_TEST_TMPDIR/report.md"
  cat > "$f" <<'EOF'
## Gate 8: design-review

### Finding

None of the 1440 viewports failed, but there's a polish issue on mobile.

## Dismissals

- polish item A: rationale: not in core user story

## End
EOF
  run bash "$SCRIPT" is-empty "$f"
  assert_failure 1
}

@test "is-empty: returns 1 when Dismissals section is missing" {
  local f="$BATS_TEST_TMPDIR/report.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

No Dismissals section at all.
EOF
  run bash "$SCRIPT" is-empty "$f"
  assert_failure 1
}

@test "extract: returns the body between Dismissals heading and next ##" {
  local f="$BATS_TEST_TMPDIR/report.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

## Dismissals

- first finding: rationale here
- second finding: another rationale

## Gate 10: benchmark
EOF
  run bash "$SCRIPT" extract "$f"
  assert_success
  assert_output --partial "- first finding: rationale here"
  assert_output --partial "- second finding: another rationale"
  # Must NOT include the next section's heading
  refute_output --partial "Gate 10: benchmark"
}

# --- CSO JSON → dismissals shim ---

@test "cso-to-dismissals: maps TENTATIVE findings to auto-dismissal bullets" {
  local f="$BATS_TEST_TMPDIR/cso.json"
  cat > "$f" <<'EOF'
{
  "findings": [
    { "severity": "CRITICAL", "category": "secrets", "title": "API key in logs" },
    { "severity": "TENTATIVE", "category": "supply-chain", "title": "pkg@1.0.0 has unresolved advisory" },
    { "severity": "HIGH", "category": "LLM", "title": "prompt injection surface" },
    { "severity": "TENTATIVE", "category": "CI", "title": "GitHub Actions uses :latest tag" }
  ]
}
EOF
  run bash "$SCRIPT" cso-to-dismissals "$f"
  assert_success
  assert_output --partial "pkg@1.0.0 has unresolved advisory"
  assert_output --partial "GitHub Actions uses :latest tag"
  assert_output --partial "TENTATIVE per /cso confidence tier"
  # CRITICAL and HIGH findings must NOT be dismissed (they stay as findings)
  refute_output --partial "API key in logs"
  refute_output --partial "prompt injection surface"
}

@test "cso-to-dismissals: returns 'None' when no TENTATIVE findings" {
  local f="$BATS_TEST_TMPDIR/cso.json"
  cat > "$f" <<'EOF'
{
  "findings": [
    { "severity": "CRITICAL", "category": "secrets", "title": "API key in logs" }
  ]
}
EOF
  run bash "$SCRIPT" cso-to-dismissals "$f"
  assert_success
  assert_output "None"
}

@test "cso-to-dismissals: returns 'None' when JSON file missing" {
  run bash "$SCRIPT" cso-to-dismissals "$BATS_TEST_TMPDIR/does-not-exist.json"
  assert_success
  assert_output "None"
}

# --- review: orchestrates short-circuit + adversarial ---

@test "review: skips adversarial when Dismissals body is None" {
  mock_adversarial_review FAIL  # would fail if called — but it shouldn't be
  make_shim_wrapper
  local f="$BATS_TEST_TMPDIR/review.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

## Dismissals

None
EOF
  run bash "$WRAPPER" review "qa" "$f"
  assert_success
  assert_output --partial "None (scoped parse)"
  assert_output --partial "adversarial review skipped"
}

@test "review: invokes adversarial when Dismissals body has bullets — accepted" {
  mock_adversarial_review PASS
  make_shim_wrapper
  local f="$BATS_TEST_TMPDIR/review.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

## Dismissals

- edge case: rationale: tracked in TODOS § v1-disambig-cap with issue #42
EOF
  run bash "$WRAPPER" review "qa" "$f"
  assert_success
  assert_output --partial "PASS"
}

@test "review: invokes adversarial when Dismissals body has bullets — rejected" {
  mock_adversarial_review FAIL
  make_shim_wrapper
  local f="$BATS_TEST_TMPDIR/review.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

## Dismissals

- issue X: rationale: minor
EOF
  run bash "$WRAPPER" review "qa" "$f"
  assert_failure 1
  assert_output --partial "FAIL"
}

@test "review: errors when review.md file is missing" {
  run bash "$SCRIPT" review "qa" "$BATS_TEST_TMPDIR/nonexistent.md"
  assert_failure 1
  assert_output --partial "not found"
}

# --- Escape hatch: DEVSHOP_SKIP_ADVERSARIAL ---

@test "review: DEVSHOP_SKIP_ADVERSARIAL=1 bypasses adversarial even with bulleted body" {
  # Override the real adversarial-review.sh — it checks the env var early and
  # exits 0 with a bypass message. The wrapper trick isn't needed; we're
  # testing the real adversarial script's env-var short-circuit.
  local f="$BATS_TEST_TMPDIR/review.md"
  cat > "$f" <<'EOF'
## Gate 9: qa

## Dismissals

- anything: rationale: anything
EOF
  DEVSHOP_SKIP_ADVERSARIAL=1 run bash "$SCRIPT" review "qa" "$f"
  assert_success
  assert_output --partial "DEVSHOP_SKIP_ADVERSARIAL"
}

# --- CLI dispatch ---

@test "unknown subcommand exits 2" {
  run bash "$SCRIPT" make-coffee
  assert_failure 2
  assert_output --partial "unknown subcommand"
}

@test "no subcommand shows help" {
  run bash "$SCRIPT"
  assert_success
  assert_output --partial "Subcommands"
}
