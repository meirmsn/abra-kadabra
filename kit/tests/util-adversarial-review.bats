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
  # Rule (d) heading + the historical-archives carve-out (now a single
  # end-of-rule-4 line covering both kit/notes/** and project equivalents).
  grep -q "Rename/move/delete drift sweep" "$CAPTURED_PROMPT"
  grep -q "kit/notes/" "$CAPTURED_PROMPT"
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

# === testReviewSkipReason context: /ak-build Phase 5.8 halt override ===

# Helper: seed a feature branch with specs/<feature>/review.md containing a
# `## Audit N` section so the testReviewSkipReason context-gathering switch
# has a file to read. Post-PR-B model: findings live in review.md (collapsed
# two-file model — no separate test-review-followup.md).
_seed_review() {
  local feature="$1" audited_at="$2" body="$3"
  local dir="$TEST_REPO/specs/$feature"
  mkdir -p "$dir"
  cat > "$dir/review.md" <<EOF
# Review — $feature

## Gate 5: Pre-polish docs + tests audit (2026-05-06)

(prior gate output — not the section under override)

## Audit 1: pre-polish (2026-05-06)

<!-- audited-at: aaaa1111bbbb2222 -->
<!-- range: origin/main..aaaa1111bbbb2222 -->

findings: high=0 medium=1 low=2

### Docs findings
- (none)
### Tests findings
- [med] apps/web/example.test.ts:1 — placeholder
### Bypass trailer audit
- (none)

## Audit 2: post-polish (2026-05-06)

<!-- audited-at: $audited_at -->
<!-- range: aaaa1111bbbb2222..$audited_at -->

findings: high=1 medium=2 low=0

### Docs findings
- (none)

### Tests findings
$body

### Bypass trailer audit
- (none)
EOF
  (cd "$TEST_REPO" && git checkout -q -b "feature/$feature" 2>/dev/null \
    || git -c user.email=t@t -c user.name=t checkout -q "feature/$feature")
  (cd "$TEST_REPO" && git add "specs/$feature/review.md" \
    && git -c user.email=t@t -c user.name=t commit -q -m "seed review")
}

@test "testReviewSkipReason: prompt includes the audited-at SHA from the latest Audit N section" {
  _seed_review "auth-rework" "deadbeef1234567" \
    "- [high] AwaitingConfirmationCard.tsx:42 — onEdit prop is untested"

  (cd "$TEST_REPO" && bash "$REVIEW" testReviewSkipReason \
    "tracked at TODOS.md § follow-up-tests" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "audited-at" "$CAPTURED_PROMPT"
  grep -q "deadbeef1234567" "$CAPTURED_PROMPT"
  # Ensure the prior Audit 1 stamp is NOT what got harvested (must be the
  # latest audit, not the first).
  ! grep -q "aaaa1111bbbb2222" "$CAPTURED_PROMPT" \
    || (grep -q "deadbeef1234567" "$CAPTURED_PROMPT" \
        && [ "$(grep -c "audited-at: deadbeef1234567" "$CAPTURED_PROMPT")" -ge 1 ])
}

@test "testReviewSkipReason: prompt includes the latest Audit body verbatim" {
  _seed_review "feature-x" "abcdef1234567" \
    "- [high] AwaitingConfirmationCard.tsx:42 — onEdit prop is untested"

  (cd "$TEST_REPO" && bash "$REVIEW" testReviewSkipReason "any reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "AwaitingConfirmationCard.tsx:42" "$CAPTURED_PROMPT"
  grep -q "onEdit prop is untested" "$CAPTURED_PROMPT"
}

@test "testReviewSkipReason: prompt includes the findings summary line (space-separated post-PR-B format)" {
  _seed_review "feature-y" "1111111aaaaaa" "- [high] file:1 — a gap"

  (cd "$TEST_REPO" && bash "$REVIEW" testReviewSkipReason "x" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -qE "findings: high=1 medium=2 low=0" "$CAPTURED_PROMPT"
}

@test "testReviewSkipReason: prompt includes per-finding engagement rule" {
  _seed_review "feature-z" "2222222bbbbbb" "- [high] file:1 — gap"

  (cd "$TEST_REPO" && bash "$REVIEW" testReviewSkipReason "x" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Per-finding engagement" "$CAPTURED_PROMPT"
  grep -q "No core-flow dismissal" "$CAPTURED_PROMPT"
  grep -q "No security-boundary skips" "$CAPTURED_PROMPT"
}

@test "testReviewSkipReason: prompt warns loudly when review.md is missing" {
  (cd "$TEST_REPO" && git checkout -q -b feature/no-review)

  (cd "$TEST_REPO" && bash "$REVIEW" testReviewSkipReason "x" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "review.md not found" "$CAPTURED_PROMPT"
  grep -q "suspicious" "$CAPTURED_PROMPT"
}

@test "testReviewSkipReason: prompt warns loudly when review.md exists but lacks an Audit N section" {
  (cd "$TEST_REPO" && git checkout -q -b feature/no-audit-section)
  mkdir -p "$TEST_REPO/specs/no-audit-section"
  cat > "$TEST_REPO/specs/no-audit-section/review.md" <<EOF
# Review — no-audit-section

## Gate 1: Docs check (2026-05-06)

(prior gate output, but no Audit N section yet)
EOF
  (cd "$TEST_REPO" && git add specs/no-audit-section/review.md \
    && git -c user.email=t@t -c user.name=t commit -q -m "seed review no audit")

  (cd "$TEST_REPO" && bash "$REVIEW" testReviewSkipReason "x" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "no '## Audit N' section" "$CAPTURED_PROMPT"
  grep -q "suspicious" "$CAPTURED_PROMPT"
}
