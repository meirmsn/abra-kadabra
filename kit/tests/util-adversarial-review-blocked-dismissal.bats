#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh's dismissalLog fast-path:
# dismissals on a `blocked` gate are categorically invalid because `blocked`
# is a tooling-gap signal, not a reviewable finding. The fast-path runs
# BEFORE the LLM call so a `claude` mock that returns PASS cannot rescue an
# invalid dismissal.
#
# Codified from home-os PR #15 (2026-05-14): Gate 9 /qa reported `blocked: 1`,
# the dismissal-shim cascaded the blocked past review, and the PR shipped
# with placeholder hero shots in the body instead of the actual feature.
# Spec: kit/ROADMAP.md § /ak-pre-ship LLM-mediated gate contract § Fix D.1.

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"

  # Mock `claude` to return PASS. If the fast-path is missing, FAIL output
  # will be the mocked PASS — the test relies on the fast-path running
  # BEFORE the LLM call, so the captured prompt should NOT exist for
  # blocked-without-n/a-per-scope cases.
  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
# Drain args (incl. --model X)
while [ \$# -gt 0 ]; do shift; done
cat > "$CAPTURED_PROMPT"
echo "PASS - mocked"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  create_test_repo
  mkdir -p "$TEST_REPO/kit/docs/guide"
  echo "# conventions" > "$TEST_REPO/kit/docs/guide/conventions.md"
  mkdir -p "$TEST_REPO/specs/feat"
}

# Helper: build a review.md fixture with the gate section under test.
write_review_md() {
  local result_line="$1"
  cat > "$TEST_REPO/specs/feat/review.md" <<EOF
# Pre-ship review: feat

## Gate 9: /qa

- $result_line
- Findings: see below
- Notes: gate exercised the happy-path walk

## Dismissals

- Finding F1 — rationale: deferred per scope review

## Router Summary
EOF
}

# === Fast-path FAILs when result is plain `blocked` ===

@test "dismissalLog: blocked gate without n/a-per-scope → fast-path FAIL" {
  cd "$TEST_REPO"
  write_review_md "Result: blocked (Supabase Kong unreachable)"
  run bash "$REVIEW" dismissalLog "deferred — local stack is down" qa specs/feat/review.md
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL: dismissals on a blocked gate are invalid"
  echo "$output" | grep -q "Gate: qa"
  echo "$output" | grep -q "tooling-gap signal"
}

@test "dismissalLog: fast-path FAILs BEFORE the LLM call (mock never invoked)" {
  cd "$TEST_REPO"
  write_review_md "Result: blocked (Chromium not available)"
  run bash "$REVIEW" dismissalLog "deferred" qa specs/feat/review.md
  [ "$status" -eq 1 ]
  # The prompt file is only written when the mock `claude` is called.
  # Fast-path exits before that — so the file MUST NOT exist.
  [ ! -f "$CAPTURED_PROMPT" ]
}

@test "dismissalLog: bullet-formatted blocked line (with leading dash) is recognized" {
  cd "$TEST_REPO"
  cat > "$TEST_REPO/specs/feat/review.md" <<EOF
## Gate 9: /qa

- Result: blocked (browser unreachable)

## Dismissals

- Finding F1 — rationale: deferred
EOF
  run bash "$REVIEW" dismissalLog "deferred" qa specs/feat/review.md
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL: dismissals on a blocked gate"
}

@test "dismissalLog: bold-formatted Result line is recognized" {
  cd "$TEST_REPO"
  cat > "$TEST_REPO/specs/feat/review.md" <<EOF
## Gate 9: /qa

**Result:** blocked (no supabase stack)

## Dismissals

- Finding F1 — rationale: deferred
EOF
  run bash "$REVIEW" dismissalLog "deferred" qa specs/feat/review.md
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "FAIL: dismissals on a blocked gate"
}

# === Fast-path ACCEPTs `blocked (n/a per scope: ...)` and routes to the LLM ===

@test "dismissalLog: blocked (n/a per scope: ...) → fast-path passes through to LLM" {
  cd "$TEST_REPO"
  write_review_md "Result: blocked (n/a per scope: no UI files in diff)"
  run bash "$REVIEW" dismissalLog "n/a per scope — diff is supabase/migrations/** only" design-review specs/feat/review.md
  [ "$status" -eq 0 ]
  # The LLM mock returns PASS; the captured prompt must exist (proving the
  # fast-path forwarded the call).
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: dismissalLog" "$CAPTURED_PROMPT"
}

# === Fast-path is a no-op for non-blocked gates ===

@test "dismissalLog: non-blocked gate (findings) → fast-path passes through to LLM" {
  cd "$TEST_REPO"
  write_review_md "Result: findings (2) pending"
  run bash "$REVIEW" dismissalLog "specific rationale per finding" qa specs/feat/review.md
  [ "$status" -eq 0 ]
  [ -f "$CAPTURED_PROMPT" ]
}

@test "dismissalLog: pass-result gate (no dismissals expected, but safe) → fast-path no-op" {
  cd "$TEST_REPO"
  write_review_md "Result: pass"
  run bash "$REVIEW" dismissalLog "n/a" review specs/feat/review.md
  [ "$status" -eq 0 ]
}

# === Robustness: fast-path is silent when GATE_SECTION can't be extracted ===

@test "dismissalLog: review.md path missing → fast-path skipped, LLM runs normally" {
  cd "$TEST_REPO"
  # Path points at a file that doesn't exist — GATE_SECTION will be empty.
  run bash "$REVIEW" dismissalLog "specific rationale" qa specs/feat/missing-review.md
  [ "$status" -eq 0 ]
  [ -f "$CAPTURED_PROMPT" ]
}

# === Prompt instructions are aware of the fast-path ===

@test "dismissalLog: rule #4 NOTE mentions the fast-path for awareness" {
  cd "$TEST_REPO"
  write_review_md "Result: findings (1) pending"
  run bash "$REVIEW" dismissalLog "specific rationale" qa specs/feat/review.md
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "blocked.* outcome.*rejected by a fast-path" "$CAPTURED_PROMPT"
}
