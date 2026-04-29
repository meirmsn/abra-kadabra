#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh — context gathering + prompt construction.
# These are deterministic checks of what the LLM SEES (the prompt content), not
# tests of LLM behavior. Behavior tests live in the per-guard bats files via mocks.

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"

  # Mock `claude` to capture stdin and return PASS so the script exits 0
  # but writes the would-be-LLM-prompt to a file we can inspect.
  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
cat > "$CAPTURED_PROMPT"
echo "PASS - mocked"
exit 0
EOF
  chmod +x "$MOCK_BIN/claude"

  create_test_repo
  # Make the test repo look devshop-self by adding a real kit/ dir.
  mkdir -p "$TEST_REPO/kit/docs/guide"
  mkdir -p "$TEST_REPO/kit/scripts/commit-hooks"
  echo "# OVERVIEW" > "$TEST_REPO/kit/docs/OVERVIEW.md"
  echo "# MODEL"    > "$TEST_REPO/kit/docs/MODEL.md"
  echo "# FAQ"      > "$TEST_REPO/kit/docs/FAQ.md"
  echo "# README"   > "$TEST_REPO/README.md"
  echo "# CLAUDE"   > "$TEST_REPO/CLAUDE.md"
  (cd "$TEST_REPO" && git add . && git -c user.email=t@t -c user.name=t commit -q -m base)
}

# === docsReviewed context: renamed/deleted file surface ===

@test "docsReviewed: prompt includes rename info when a file is renamed in the staged diff" {
  # Stage a rename: kit/scripts/old-name.sh → kit/scripts/new-name.sh
  echo "echo old" > "$TEST_REPO/kit/scripts/old-name.sh"
  (cd "$TEST_REPO" && git add kit/scripts/old-name.sh && git -c user.email=t@t -c user.name=t commit -q -m "add old-name.sh")
  (cd "$TEST_REPO" && git mv kit/scripts/old-name.sh kit/scripts/new-name.sh && git add -u)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Renamed/moved/deleted in this commit" "$CAPTURED_PROMPT"
  grep -q "old-name.sh" "$CAPTURED_PROMPT"
  grep -q "new-name.sh" "$CAPTURED_PROMPT"
}

@test "docsReviewed: prompt notes 'none' when nothing renamed/deleted" {
  echo "echo new" > "$TEST_REPO/kit/scripts/added-file.sh"
  (cd "$TEST_REPO" && git add kit/scripts/added-file.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Renamed/moved/deleted in this commit" "$CAPTURED_PROMPT"
  grep -q "no files renamed, moved, or deleted" "$CAPTURED_PROMPT"
}

@test "docsReviewed: prompt includes rule (d) — rename/move/delete drift sweep" {
  echo "x" > "$TEST_REPO/kit/scripts/anything.sh"
  (cd "$TEST_REPO" && git add kit/scripts/anything.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  # Rule (d) heading + the historical-notes carve-out
  grep -q "Rename/move/delete drift sweep" "$CAPTURED_PROMPT"
  grep -q "Historical notes under kit/notes/" "$CAPTURED_PROMPT"
}

@test "docsReviewed: prompt surfaces deleted file in rename-detection block" {
  echo "echo doomed" > "$TEST_REPO/kit/scripts/doomed.sh"
  (cd "$TEST_REPO" && git add kit/scripts/doomed.sh && git -c user.email=t@t -c user.name=t commit -q -m "add doomed.sh")
  (cd "$TEST_REPO" && git rm kit/scripts/doomed.sh >/dev/null)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "doomed.sh" "$CAPTURED_PROMPT"
  # Format is "<status>\t<old-path>" — D for delete, so 'D\tkit/scripts/doomed.sh'
  grep -qE "^D[[:space:]]+kit/scripts/doomed\.sh" "$CAPTURED_PROMPT"
}
