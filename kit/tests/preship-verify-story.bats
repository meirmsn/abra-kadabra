#!/usr/bin/env bats
# Tests for kit/scripts/preship/verify-story.sh
# Gate 9 Core-User-Story artifact assertion — enforces that every verb in
# the spec's `## Core user story` section produces a verifiable artifact.

setup() {
  load helpers/setup
  setup_mock_bin
  SCRIPT="$SCRIPTS_DIR/preship/verify-story.sh"
  FEATURE_DIR="$BATS_TEST_TMPDIR/feature"
  mkdir -p "$FEATURE_DIR"
  SPEC="$FEATURE_DIR/spec.md"
}

# Helper: write a spec with a given Core user story body
write_spec() {
  local body="$1"
  cat > "$SPEC" <<EOF
# Spec: feature (PR X)

## Core user story

$body

## In scope

Stuff.
EOF
}

# Helper: create an artifact for a given verb index (optionally non-empty)
stage_artifact() {
  local n="$1" content="${2:-fake screenshot}"
  mkdir -p "$FEATURE_DIR/qa-walk"
  echo "$content" > "$FEATURE_DIR/qa-walk/verb-${n}-step.png"
}

# --- extract-story ---

@test "extract-story: returns body between heading and next ##" {
  write_spec "1. First.
2. Second."
  run bash "$SCRIPT" extract-story "$SPEC"
  assert_success
  assert_output --partial "1. First."
  assert_output --partial "2. Second."
  refute_output --partial "In scope"
}

@test "extract-story: empty when section missing" {
  cat > "$SPEC" <<'EOF'
# Spec

## In scope

no core user story section here
EOF
  run bash "$SCRIPT" extract-story "$SPEC"
  assert_success
  assert_output ""
}

# --- is-na ---

@test "is-na: exit 0 when body starts with N/A" {
  write_spec "N/A — migration only"
  run bash "$SCRIPT" is-na "$SPEC"
  assert_success
}

@test "is-na: exit 0 for bare N/A" {
  write_spec "N/A"
  run bash "$SCRIPT" is-na "$SPEC"
  assert_success
}

@test "is-na: exit 0 for lowercase n/a with em dash" {
  write_spec "n/a — docs refactor, no user flow touched"
  run bash "$SCRIPT" is-na "$SPEC"
  assert_success
}

@test "is-na: exit 1 when body has real verbs" {
  write_spec "1. Sign in.
2. Add item."
  run bash "$SCRIPT" is-na "$SPEC"
  assert_failure 1
}

@test "is-na: exit 1 when body is empty" {
  write_spec ""
  run bash "$SCRIPT" is-na "$SPEC"
  assert_failure 1
}

@test "is-na: exit 1 when N/A appears mid-sentence, not at start" {
  write_spec "Adding an item is N/A when offline."
  run bash "$SCRIPT" is-na "$SPEC"
  assert_failure 1
}

# --- parse-verbs ---

@test "parse-verbs: extracts from numbered list" {
  write_spec "1. Sign in.
2. Tap FAB.
3. See item."
  run bash "$SCRIPT" parse-verbs "$SPEC"
  assert_success
  assert_line "Sign in."
  assert_line "Tap FAB."
  assert_line "See item."
}

@test "parse-verbs: extracts from bulleted list" {
  write_spec "- Sign in.
- Tap FAB.
- See item."
  run bash "$SCRIPT" parse-verbs "$SPEC"
  assert_success
  assert_line "Sign in."
  assert_line "Tap FAB."
  assert_line "See item."
}

@test "parse-verbs: handles parenthesized numbers like '2)'" {
  write_spec "1) Sign in.
2) Tap FAB."
  run bash "$SCRIPT" parse-verbs "$SPEC"
  assert_success
  assert_line "Sign in."
  assert_line "Tap FAB."
}

@test "parse-verbs: strips leading whitespace" {
  write_spec "  1. Sign in.
    2. Tap FAB."
  run bash "$SCRIPT" parse-verbs "$SPEC"
  assert_success
  assert_line "Sign in."
  assert_line "Tap FAB."
}

@test "parse-verbs: empty when section empty" {
  write_spec ""
  run bash "$SCRIPT" parse-verbs "$SPEC"
  assert_success
  assert_output ""
}

# --- verify-all ---

@test "verify-all: pass when all verbs have artifacts" {
  write_spec "1. Sign in.
2. Add item."
  stage_artifact 1
  stage_artifact 2
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_success
  assert_output --partial "pass: all 2 Core user story verb(s)"
}

@test "verify-all: blocked when some verbs missing artifacts" {
  write_spec "1. Sign in.
2. Add item.
3. See item."
  stage_artifact 1
  # verb 2 + 3 missing
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_failure 1
  assert_output --partial "blocked"
  assert_output --partial "verb 2"
  assert_output --partial "verb 3"
  refute_output --partial "✖ verb 1"  # verb 1 should pass
}

@test "verify-all: blocked when all verbs missing artifacts" {
  write_spec "1. Sign in.
2. Add item."
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_failure 1
  assert_output --partial "blocked"
  assert_output --partial "verb 1"
  assert_output --partial "verb 2"
}

@test "verify-all: skips assertion when Core user story is N/A and reviewer accepts" {
  # Mock `claude` so the adversarial review of the N/A rationale returns PASS
  # without making a real API call. Use a verifiable file/path claim that the
  # ACCEPT vocabulary in Rule #11 of `adversarial-review.sh` would normally
  # accept.
  cat > "$MOCK_BIN/claude" <<'EOF'
#!/bin/bash
# Drain stdin (the prompt) and return PASS verdict
cat > /dev/null
echo "PASS"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  write_spec "N/A — diff is supabase/migrations/** only; no apps/** or packages/** files"
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_success
  assert_output --partial "skipped"
}

@test "verify-all: blocks when N/A rationale is rejected by adversarial review" {
  # Mock `claude` so the reviewer returns FAIL — the rationale is interpretive
  # prose ("no visible UI change"), which Rule #11 (b) rejects. verify-story.sh
  # must propagate the FAIL verdict on stdout so it lands in review.md as the
  # fix recipe.
  cat > "$MOCK_BIN/claude" <<'EOF'
#!/bin/bash
cat > /dev/null
echo "FAIL: 'no visible UI change' is interpretive — name a verifiable file/path claim"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  write_spec "N/A — no visible UI change"
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_failure 1
  assert_output --partial "blocked: Core user story N/A rationale rejected"
  assert_output --partial "FAIL"
  assert_output --partial "interpretive"
}

@test "verify-all: blocked when spec lacks Core user story section" {
  cat > "$SPEC" <<'EOF'
# Spec

## In scope

no Core user story section
EOF
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_failure 1
  assert_output --partial "blocked: spec lacks"
}

@test "verify-all: blocked when Core user story section has no parseable verbs" {
  write_spec "just some paragraph text without a list structure"
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_failure 1
  assert_output --partial "no parseable verbs"
}

@test "verify-all: rejects empty-file artifacts" {
  write_spec "1. Sign in."
  # Empty file
  mkdir -p "$FEATURE_DIR/qa-walk"
  : > "$FEATURE_DIR/qa-walk/verb-1-signin.png"
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_failure 1
  assert_output --partial "empty"
}

@test "verify-all: accepts JSON state artifact in place of PNG" {
  write_spec "1. Check state."
  mkdir -p "$FEATURE_DIR/qa-walk"
  echo '{"ok":true}' > "$FEATURE_DIR/qa-walk/verb-1-state.json"
  run bash "$SCRIPT" verify-all --feature feature --spec "$SPEC"
  assert_success
  assert_output --partial "pass"
}

@test "verify-all: blocked when spec file is missing" {
  run bash "$SCRIPT" verify-all --feature feature --spec "$BATS_TEST_TMPDIR/nonexistent.md"
  assert_failure 1
  assert_output --partial "spec file missing"
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
