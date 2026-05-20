#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh's advisorBypassReason check-type.
# Added alongside the advisor-clean pre-ship gate (Gate 2g) — judges bypass
# reasons for the DB-hardening advisor probe (pnpm db:advisor against 9
# pg_catalog lints). Spec: kit/docs/guide/security.md § DB hardening.

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"
  CAPTURED_MODEL="$BATS_TEST_TMPDIR/captured-model.txt"

  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--model" ]; then
    echo "\$2" > "$CAPTURED_MODEL"
    shift 2
    continue
  fi
  shift
done
cat > "$CAPTURED_PROMPT"
echo "\${MOCK_CLAUDE_VERDICT:-PASS - mocked}"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  create_test_repo
  # Make the test repo look devshop-self by adding a real kit/ dir + the
  # convention file the script inlines for advisorBypassReason.
  mkdir -p "$TEST_REPO/kit/docs/guide"
  cat > "$TEST_REPO/kit/docs/guide/conventions.md" <<'CONV'
## Supabase Hardening Defaults

Migration-time policy conventions: every SECURITY DEFINER pins search_path;
RLS policies wrap auth.uid() as `(select auth.uid())`; every FK has a backing
index (or an ADVISOR-EXEMPT comment).
CONV
}

# === Case recognized (no "unknown") ===

@test "advisorBypassReason: case statement recognized (no 'unknown check type')" {
  cd "$TEST_REPO"
  run bash "$REVIEW" advisorBypassReason "extension_in_public per project D4 (pgcrypto move would break call sites); tracked at TODOS.md L42"
  refute_output --partial "unknown check type"
}

@test "advisorBypassReason: prompt header includes 'Check type: advisorBypassReason'" {
  cd "$TEST_REPO"
  run bash "$REVIEW" advisorBypassReason "per-finding rationale + TODOS pointer"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: advisorBypassReason" "$CAPTURED_PROMPT"
}

@test "advisorBypassReason: prompt context names the advisor-clean gate" {
  cd "$TEST_REPO"
  run bash "$REVIEW" advisorBypassReason "per-finding rationale"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "advisor-clean" "$CAPTURED_PROMPT"
}

@test "advisorBypassReason: prompt context names the 9 advisor lints" {
  cd "$TEST_REPO"
  run bash "$REVIEW" advisorBypassReason "per-finding rationale"
  [ -f "$CAPTURED_PROMPT" ]
  # One representative lint from the enumeration in the case branch.
  grep -q "function search_path" "$CAPTURED_PROMPT"
  grep -q "auth_rls_initplan" "$CAPTURED_PROMPT"
  grep -q "unindexed FK" "$CAPTURED_PROMPT"
}

@test "advisorBypassReason: prompt surfaces the bypass reason verbatim" {
  cd "$TEST_REPO"
  run bash "$REVIEW" advisorBypassReason "extension_in_public per pgcrypto migration risk; tracked at TODOS.md L42"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "extension_in_public per pgcrypto migration risk; tracked at TODOS.md L42" "$CAPTURED_PROMPT"
}

# === Sonnet routing ===

@test "advisorBypassReason: routes to Sonnet (judgment-heavy)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" advisorBypassReason "per-finding rationale"
  [ -f "$CAPTURED_MODEL" ]
  # The script writes the model name; Sonnet is currently sonnet-4-6 or similar.
  grep -qi "sonnet" "$CAPTURED_MODEL"
}

# === Convention inlining ===

@test "advisorBypassReason: inlines Supabase Hardening Defaults convention" {
  cd "$TEST_REPO"
  run bash "$REVIEW" advisorBypassReason "per-finding rationale"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Supabase Hardening Defaults" "$CAPTURED_PROMPT"
  # Confirm the body (not just the heading) is inlined.
  grep -q "search_path" "$CAPTURED_PROMPT"
}

# === Verdict routing ===

@test "advisorBypassReason: claude PASS verdict → exit 0" {
  cd "$TEST_REPO"
  MOCK_CLAUDE_VERDICT="PASS - rationale acceptable" run bash "$REVIEW" advisorBypassReason "per-finding rationale"
  [ "$status" -eq 0 ]
}

@test "advisorBypassReason: claude FAIL verdict → exit non-zero" {
  cd "$TEST_REPO"
  MOCK_CLAUDE_VERDICT="FAIL - generic dismissal" run bash "$REVIEW" advisorBypassReason "we'll fix it later"
  [ "$status" -ne 0 ]
}

# === DEVSHOP_SKIP_ADVERSARIAL escape hatch ===

@test "advisorBypassReason: DEVSHOP_SKIP_ADVERSARIAL=1 short-circuits to PASS" {
  cd "$TEST_REPO"
  DEVSHOP_SKIP_ADVERSARIAL=1 run bash "$REVIEW" advisorBypassReason "anything"
  [ "$status" -eq 0 ]
  assert_output --partial "bypassed via DEVSHOP_SKIP_ADVERSARIAL=1"
}
