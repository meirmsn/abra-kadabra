#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-claude-md-classification.sh
# Pre-commit gate that blocks CLAUDE.md additions/modifications unless a
# `claudeMdClassification` bypass flag classifies each entry.
#
# Fires in BOTH devshop and project repos. Pure deletions pass trivially.
# Bypass via `git -c devshop.claudeMdClassification="trap: <entry> — <why>"`.

setup() {
  load helpers/setup
  setup_mock_bin
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-claude-md-classification.sh"

  # Create a devshop-like test repo (real kit/ directory → devshop-self mode)
  TEST_REPO="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$TEST_REPO/kit/scripts/commit-hooks" \
           "$TEST_REPO/kit/docs/guide"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"

  # Seed CLAUDE.md so modifications can produce a diff
  echo "# CLAUDE.md" > "$TEST_REPO/CLAUDE.md"
  echo "" >> "$TEST_REPO/CLAUDE.md"
  echo "## Existing Section" >> "$TEST_REPO/CLAUDE.md"
  echo "Some content here." >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "seed"

  cd "$TEST_REPO"
}

stage() {
  local path="$1" content="${2:-x}"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add "$path"
}

run_script() {
  run bash "$SCRIPT"
}

# --- Test 1: PASS — no CLAUDE.md in staged files ---

@test "PASS: no CLAUDE.md in staged files — exits 0 immediately" {
  stage "README.md" "# readme"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- Test 2: PASS — CLAUDE.md staged but only deletions ---

@test "PASS: CLAUDE.md staged with only deletions passes trivially" {
  # Remove a line from CLAUDE.md (pure deletion)
  printf "# CLAUDE.md\n" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}

# --- Test 3: BLOCK — CLAUDE.md staged with additions, no bypass flag ---

@test "BLOCK: CLAUDE.md with additions and no bypass flag blocks" {
  echo "## New Footgun" >> "$TEST_REPO/CLAUDE.md"
  echo "This is a new trap entry." >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
  assert_output --partial "claudeMdClassification"
}

# --- Test 3b: BLOCK message surfaces the placement requirement ---

@test "BLOCK: guidance instructs declaring placement (section / new-section)" {
  echo "## New Footgun" >> "$TEST_REPO/CLAUDE.md"
  echo "This is a new trap entry." >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_failure
  assert_output --partial "placement"
  assert_output --partial "NEW section"
  # Pin the operator-facing usage string to the new placement-aware shape, so a
  # regression back to the old `trap: <entry>` format can't pass on the word
  # "placement" appearing elsewhere in the guidance.
  assert_output --partial "placement: <extends|NEW>"
}

# --- Test 4: PASS — bypass flag + adversarial PASS ---

@test "PASS: bypass flag + adversarial PASS accepts commit" {
  echo "## New Trap" >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md

  # Mock adversarial-review.sh to return PASS
  mock_adversarial_review PASS

  # Point the script at the mock by making kit/scripts resolve to mock-bin
  # The script resolves adversarial-review.sh via $GIT_ROOT/kit/scripts/
  mkdir -p "$TEST_REPO/kit/scripts"
  cp "$MOCK_BIN/adversarial-review.sh" "$TEST_REPO/kit/scripts/adversarial-review.sh"

  git -C "$TEST_REPO" config devshop.claudeMdClassification "trap → § Known Footguns: New Trap — silent wrong work if forgotten; placement: extends — closest home, distinct from neighbors"
  run_script
  assert_success
  assert_output --partial "PASS"
}

# --- Test 5: BLOCK — bypass flag + adversarial FAIL ---

@test "BLOCK: bypass flag + adversarial FAIL blocks commit" {
  echo "## New Entry" >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md

  # Mock adversarial-review.sh to return FAIL
  mock_adversarial_review FAIL

  mkdir -p "$TEST_REPO/kit/scripts"
  cp "$MOCK_BIN/adversarial-review.sh" "$TEST_REPO/kit/scripts/adversarial-review.sh"

  git -C "$TEST_REPO" config devshop.claudeMdClassification "trap: vague reason"
  run_script
  assert_failure
  assert_output --partial "FAIL"
}

# --- Test 6: BLOCK — empty bypass flag treated as absent ---

@test "BLOCK: empty bypass flag value still blocks" {
  echo "## New Entry" >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  git -C "$TEST_REPO" config devshop.claudeMdClassification ""
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

# --- Test 7: BLOCK — fires in devshop-self mode ---

@test "BLOCK: fires in devshop-self mode (repo with real kit/ directory)" {
  # TEST_REPO already has a real kit/ directory — devshop-self mode
  echo "## Devshop Trap" >> "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

# --- Test 8: PASS — fires in project mode (/workspace) ---

@test "PASS: fires in project mode (symlinked kit/)" {
  # Create a project-like repo with kit/ as a symlink
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  git -C "$project" init -q
  git -C "$project" config user.email "test@test.com"
  git -C "$project" config user.name "Test"
  echo "# CLAUDE.md" > "$project/CLAUDE.md"
  ln -s /tmp/nowhere "$project/kit"
  git -C "$project" add CLAUDE.md
  git -C "$project" commit -q -m "seed"

  echo "## New Entry" >> "$project/CLAUDE.md"
  git -C "$project" add CLAUDE.md
  run bash -c "cd '$project' && bash '$SCRIPT'"
  assert_failure
  assert_output --partial "BLOCKING"
}

# --- Test 9: carve-out — non-CLAUDE.md files do not fire ---

@test "carve-out: non-CLAUDE.md files do not trigger the gate" {
  stage "kit/docs/guide/hooks.md" "# updated hooks"
  stage "README.md" "# readme"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
  refute_output --partial "classification"
}

# --- Test 10: PASS — mixed commit with CLAUDE.md deletions only + other files ---

@test "PASS: CLAUDE.md deletions only + other files staged does not fire" {
  # Remove lines from CLAUDE.md (pure deletion)
  printf "# CLAUDE.md\n" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  # Also stage an unrelated file
  stage "README.md" "# readme"
  run_script
  assert_success
  refute_output --partial "BLOCKING"
}
