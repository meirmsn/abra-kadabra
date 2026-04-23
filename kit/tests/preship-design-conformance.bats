#!/usr/bin/env bats
# Tests for kit/scripts/preship/design-conformance.sh
# Gate `design-conformance` — DESIGN.md contract verification.
# Mocks the `claude` CLI via CLAUDE_CLI env var so tests don't hit the API.

setup() {
  load helpers/setup
  setup_mock_bin
  SCRIPT="$SCRIPTS_DIR/preship/design-conformance.sh"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
}

# Helper: write a DESIGN.md with given body.
write_design() {
  cat > "$WORK/DESIGN.md" <<EOF
# Design System

$1
EOF
}

# Helper: install a mock claude CLI that emits given JSON on stdout.
# (Consumes stdin silently so extract-claims' prompt input is ignored.)
mock_claude_emit() {
  cat > "$MOCK_BIN/claude" <<STUB
#!/bin/bash
cat > /dev/null  # consume prompt
cat <<'JSON'
$1
JSON
STUB
  chmod +x "$MOCK_BIN/claude"
}

# --- extract-claims ---

@test "extract-claims: writes parsed JSON array to --out" {
  write_design "Background: #FDFAF6"
  mock_claude_emit '[{"id":"claim-1","type":"explicit_value","description":"bg","evidence":"Background: #FDFAF6","search":"#FDFAF6","severity":"high"}]'
  run env CLAUDE_CLI="$MOCK_BIN/claude" bash "$SCRIPT" extract-claims \
    --design "$WORK/DESIGN.md" --out "$WORK/claims.json"
  assert_success
  assert_output --partial "extracted 1 claims"
  # Output file is valid JSON array
  run jq '.[0].search' "$WORK/claims.json"
  assert_success
  assert_output '"#FDFAF6"'
}

@test "extract-claims: rejects non-JSON output from LLM" {
  write_design "irrelevant"
  cat > "$MOCK_BIN/claude" <<'STUB'
#!/bin/bash
cat > /dev/null
echo "I'm sorry, I cannot extract claims from this document."
STUB
  chmod +x "$MOCK_BIN/claude"
  run env CLAUDE_CLI="$MOCK_BIN/claude" bash "$SCRIPT" extract-claims \
    --design "$WORK/DESIGN.md" --out "$WORK/claims.json"
  assert_failure 1
  assert_output --partial "did not return a JSON array"
}

@test "extract-claims: strips markdown code fences from LLM output" {
  write_design "bg"
  # Build a mock that emits fenced JSON. Write the literal payload to a file
  # the mock cats back — avoids both backtick command-substitution (from
  # double-quoting the fences in a printf arg) and nested-heredoc pain.
  local payload="$WORK/mock-payload.txt"
  {
    echo '```json'
    echo '[{"id":"claim-1","type":"explicit_value","description":"x","evidence":"y","search":"#z","severity":"high"}]'
    echo '```'
  } > "$payload"
  cat > "$MOCK_BIN/claude" <<STUB
#!/bin/bash
cat > /dev/null
cat "$payload"
STUB
  chmod +x "$MOCK_BIN/claude"
  run env CLAUDE_CLI="$MOCK_BIN/claude" bash "$SCRIPT" extract-claims \
    --design "$WORK/DESIGN.md" --out "$WORK/claims.json"
  assert_success
  run jq '.[0].id' "$WORK/claims.json"
  assert_output '"claim-1"'
}

@test "extract-claims: caches by sha256 — second call with unchanged DESIGN.md skips LLM" {
  write_design "Background: #FDFAF6"
  mock_claude_emit '[{"id":"claim-1","type":"explicit_value","description":"bg","evidence":"x","search":"#FDFAF6","severity":"high"}]'
  env CLAUDE_CLI="$MOCK_BIN/claude" bash "$SCRIPT" extract-claims \
    --design "$WORK/DESIGN.md" --out "$WORK/claims.json" >/dev/null
  # Second call: replace mock with one that would fail if invoked
  cat > "$MOCK_BIN/claude" <<'STUB'
#!/bin/bash
echo "LLM should not be called!" >&2
exit 42
STUB
  chmod +x "$MOCK_BIN/claude"
  run env CLAUDE_CLI="$MOCK_BIN/claude" bash "$SCRIPT" extract-claims \
    --design "$WORK/DESIGN.md" --out "$WORK/claims.json"
  assert_success
  assert_output --partial "cache fresh"
}

@test "extract-claims: emits empty array when DESIGN.md is missing" {
  run env CLAUDE_CLI="$MOCK_BIN/claude" bash "$SCRIPT" extract-claims \
    --design "$WORK/NONEXISTENT.md" --out "$WORK/claims.json"
  assert_success
  run jq 'length' "$WORK/claims.json"
  assert_output "0"
}

# --- verify-claims ---

@test "verify-claims: explicit_value found in source → ✓ pass" {
  mkdir -p "$WORK/apps/web"
  echo "body { background: #FDFAF6; }" > "$WORK/apps/web/globals.css"
  cat > "$WORK/claims.json" <<'JSON'
[{"id":"claim-1","type":"explicit_value","description":"bg is FDFAF6","evidence":"x","search":"#FDFAF6","severity":"high"}]
JSON
  run bash "$SCRIPT" verify-claims --claims "$WORK/claims.json" --out "$WORK/report.md" --root "$WORK"
  assert_success
  assert_output --partial "1 pass, 0 need resolution"
  run cat "$WORK/report.md"
  assert_output --partial "✓"
  assert_output --partial "found in source"
  assert_output --partial "\`pass\`"
  # Every report emits ## Dismissals with body None per Phase 3 contract
  assert_output --partial "## Dismissals"
  assert_output --partial "None"
}

@test "verify-claims: explicit_value NOT in source → ✖ needs resolution" {
  cat > "$WORK/claims.json" <<'JSON'
[{"id":"claim-1","type":"explicit_value","description":"bg","evidence":"x","search":"#CAFEFE","severity":"high"}]
JSON
  run bash "$SCRIPT" verify-claims --claims "$WORK/claims.json" --out "$WORK/report.md" --root "$WORK"
  assert_success
  assert_output --partial "0 pass, 1 need resolution"
  run cat "$WORK/report.md"
  assert_output --partial "✖"
  assert_output --partial "findings (1) pending"
}

@test "verify-claims: canonical_example surfaces as needs_review (MVP)" {
  cat > "$WORK/claims.json" <<'JSON'
[{"id":"claim-1","type":"canonical_example","description":"voice ex","evidence":"x","search":"say leche","severity":"high"}]
JSON
  run bash "$SCRIPT" verify-claims --claims "$WORK/claims.json" --out "$WORK/report.md" --root "$WORK"
  assert_success
  run cat "$WORK/report.md"
  assert_output --partial "requires human/LLM judgment"
  assert_output --partial "findings (1) pending"
}

@test "verify-claims: imperative_rule and component_contract also surface as needs_review" {
  cat > "$WORK/claims.json" <<'JSON'
[
  {"id":"r1","type":"imperative_rule","description":"must warm background","evidence":"x","search":"warm","severity":"high"},
  {"id":"r2","type":"component_contract","description":"Button 44px","evidence":"x","search":"min-h-[44px]","severity":"medium"}
]
JSON
  run bash "$SCRIPT" verify-claims --claims "$WORK/claims.json" --out "$WORK/report.md" --root "$WORK"
  assert_success
  assert_output --partial "2 need resolution"
  run cat "$WORK/report.md"
  assert_output --partial "r1"
  assert_output --partial "r2"
}

@test "verify-claims: empty claims array → n/a outcome, Dismissals: None" {
  echo "[]" > "$WORK/claims.json"
  run bash "$SCRIPT" verify-claims --claims "$WORK/claims.json" --out "$WORK/report.md" --root "$WORK"
  assert_success
  assert_output --partial "verified 0 claims"
  run cat "$WORK/report.md"
  assert_output --partial "\`n/a\`"
  assert_output --partial "## Dismissals"
  assert_output --partial "None"
}

@test "verify-claims: errors when claims file missing" {
  run bash "$SCRIPT" verify-claims --claims "$WORK/nonexistent.json" --out "$WORK/report.md"
  assert_failure 1
  assert_output --partial "not found"
}

# --- run (orchestrator) ---

@test "run: no DESIGN.md → n/a report with Dismissals: None" {
  run bash "$SCRIPT" run --feature demo --design "$WORK/DESIGN.md" --root "$WORK"
  assert_success
  assert_output --partial "no DESIGN.md found"
  run cat "$WORK/specs/demo/design-conformance-report.md"
  assert_output --partial "\`n/a\`"
  assert_output --partial "## Dismissals"
  assert_output --partial "None"
}

@test "run: DESIGN.md present → extracts + verifies + writes report" {
  write_design "Background: #FDFAF6"
  mkdir -p "$WORK/apps/web"
  echo "bg: #FDFAF6" > "$WORK/apps/web/globals.css"
  mock_claude_emit '[{"id":"claim-1","type":"explicit_value","description":"bg","evidence":"x","search":"#FDFAF6","severity":"high"}]'
  run env CLAUDE_CLI="$MOCK_BIN/claude" bash "$SCRIPT" run \
    --feature demo --design "DESIGN.md" --root "$WORK"
  assert_success
  run cat "$WORK/specs/demo/design-conformance-report.md"
  assert_output --partial "\`pass\`"
  assert_output --partial "## Dismissals"
  # Claims are cached next to the report
  [ -f "$WORK/specs/demo/design-claims.json" ]
}

# --- CLI dispatch ---

@test "unknown subcommand exits 2" {
  run bash "$SCRIPT" make-coffee
  assert_failure 2
  assert_output --partial "unknown subcommand"
}

@test "no args shows help" {
  run bash "$SCRIPT"
  assert_success
  assert_output --partial "Subcommands"
}
