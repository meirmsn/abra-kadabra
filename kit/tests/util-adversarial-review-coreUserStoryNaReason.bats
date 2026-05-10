#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh's coreUserStoryNaReason check-type.
# Added by qa-na-tightening — judges the rationale body of a spec's
# `## Core user story: N/A — <reason>` declaration when Gate 9's per-verb
# artifact assertion is being skipped. Sibling to localTestSkipReason; fires
# at pre-ship time (verify-story.sh), not at commit-time.
# Spec: specs/qa-na-tightening/spec.md § Tests, Decisions D1, D3-D5.

setup() {
  load helpers/setup
  setup_mock_bin
  REVIEW="$SCRIPTS_DIR/adversarial-review.sh"
  CAPTURED_PROMPT="$BATS_TEST_TMPDIR/captured-prompt.txt"
  CAPTURED_MODEL="$BATS_TEST_TMPDIR/captured-model.txt"

  # Mock `claude` to capture stdin + the --model arg, and return whatever
  # MOCK_CLAUDE_VERDICT says (default PASS).
  cat > "$MOCK_BIN/claude" <<EOF
#!/bin/bash
# Capture --model argument
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
  # Make the test repo look devshop-self by adding a real kit/ dir with
  # both conventions.md (the existing repo-mode probe target) AND
  # workflow.md (the new convention-inlining target for coreUserStoryNaReason).
  mkdir -p "$TEST_REPO/kit/docs/guide"
  echo "# conventions" > "$TEST_REPO/kit/docs/guide/conventions.md"

  # Bake the canonical `## Core user story requirement` body from
  # /devshop/kit/docs/guide/workflow.md (lines 181-191 of the real file at
  # the time of this PR) into the workflow.md fixture VERBATIM. Per spec
  # Gotcha #5: the BATS grep-assertion in test #3 targets a literal phrase
  # from this body; if the test fixture differs from the real file, the
  # test passes against fixture text but the real shipped behavior never
  # gets validated. Lift this body if workflow.md is rewritten.
  cat > "$TEST_REPO/kit/docs/guide/workflow.md" <<'WORKFLOW_EOF'
# Workflow

## Step 4: `/ak-build` (devshop skill) — autonomous pipeline

Some preceding text.

**New (Phase 1-B landing — Core user story requirement)**: every spec
produced by `/ak-spec` MUST include a `## Core user story` section — 2-4
imperative verbs describing the product's primary flow end-to-end, OR the
literal body `N/A — <reason>` for non-user-facing PRs (migration-only,
internal refactor). Gate 9 enforces that every verb has a matching artifact
at `specs/<feature>/qa-walk/verb-<N>-<slug>.{png,json}` proving the action
completed — missing / empty artifact blocks Gate 9 with a per-verb
diagnostic. The `N/A — <reason>` rationale is itself adversarially reviewed
at pre-ship time (`coreUserStoryNaReason` check-type): interpretive prose
("no visible UI change", "cosmetic only") fails; verifiable file/path
claims ("diff is `supabase/migrations/**` only", "no `.tsx` files modified")
pass — bare `N/A` with no rationale auto-fails.

**Some other unrelated bolded section**: this is a different sub-section
that should not be in the inlined block.
WORKFLOW_EOF
}

# === New check-type wired correctly (no "unknown") ===

@test "coreUserStoryNaReason: case statement recognized (no 'unknown check type')" {
  cd "$TEST_REPO"
  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  # MUST NOT fall through to the unknown-check-type branch.
  refute_output --partial "unknown check type"
}

@test "coreUserStoryNaReason: prompt header includes 'Check type: coreUserStoryNaReason'" {
  cd "$TEST_REPO"
  run bash "$REVIEW" coreUserStoryNaReason "diff is supabase/migrations/** only"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Check type: coreUserStoryNaReason" "$CAPTURED_PROMPT"
}

@test "coreUserStoryNaReason: convention block inlines workflow.md § Core user story requirement" {
  cd "$TEST_REPO"
  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  [ -f "$CAPTURED_PROMPT" ]
  # Load-bearing phrase from workflow.md's bolded sub-section. Asserts the
  # new convention-inlining branch resolves to workflow.md (not conventions.md)
  # AND that extract_bold_section() correctly extracts the body (not empty).
  grep -q "Every spec" "$CAPTURED_PROMPT" || \
    grep -q "every spec" "$CAPTURED_PROMPT"
  grep -q "Core user story" "$CAPTURED_PROMPT"
  grep -q "non-user-facing PRs" "$CAPTURED_PROMPT"
}

@test "coreUserStoryNaReason: prompt context includes the diff-paths section" {
  cd "$TEST_REPO"
  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Diff paths" "$CAPTURED_PROMPT"
}

# === Sonnet routing ===

@test "coreUserStoryNaReason: routes to Sonnet (interpretive judgment)" {
  cd "$TEST_REPO"
  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  [ -f "$CAPTURED_MODEL" ]
  grep -q "sonnet" "$CAPTURED_MODEL"
}

# === Survived narrowing test (no longer "unknown" but old narrowing assertions also hold) ===

@test "coreUserStoryNaReason: enumerated in unknown-check-type fallback message" {
  cd "$TEST_REPO"
  # Trigger the unknown-check-type branch and assert coreUserStoryNaReason is now in the surviving list.
  run bash "$REVIEW" madeUpCheck "x"
  assert_failure
  assert_output --partial "coreUserStoryNaReason"
}

# === ACCEPT vocabulary (verbatim phrases from kit/ROADMAP.md lines 1973-1974) → PASS ===

@test "coreUserStoryNaReason: 'no .tsx files modified' → PASS when reviewer accepts" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="PASS"
  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  assert_success
}

@test "coreUserStoryNaReason: 'diff is supabase/migrations/** only' → PASS when reviewer accepts" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="PASS"
  run bash "$REVIEW" coreUserStoryNaReason "diff is supabase/migrations/** only"
  assert_success
}

@test "coreUserStoryNaReason: 'apps/web/components/** untouched' → PASS when reviewer accepts" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="PASS"
  run bash "$REVIEW" coreUserStoryNaReason "apps/web/components/** untouched"
  assert_success
}

@test "coreUserStoryNaReason: spec's own dogfooded ACCEPT example → PASS" {
  cd "$TEST_REPO"
  # The literal body that this spec uses for its own Core user story (the
  # eat-your-own-dogfood example from specs/qa-na-tightening/spec.md § Core
  # user story).
  export MOCK_CLAUDE_VERDICT="PASS"
  run bash "$REVIEW" coreUserStoryNaReason "devshop pipeline tightening; touches kit/scripts/adversarial-review.sh, kit/scripts/preship/verify-story.sh, kit/tests/, kit/docs/guide/hooks.md, .claude/skills/devshop/pre-ship/SKILL.md only; no apps/** or packages/** files in diff."
  assert_success
}

# === REJECT vocabulary (verbatim phrases from kit/ROADMAP.md lines 1973-1974) → FAIL ===

@test "coreUserStoryNaReason: 'no visible UI change' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: 'no visible UI change' is interpretive — name a verifiable file/path claim"
  run bash "$REVIEW" coreUserStoryNaReason "no visible UI change"
  assert_failure
  assert_output --partial "FAIL"
}

@test "coreUserStoryNaReason: 'nothing user-facing changed' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: 'nothing user-facing changed' is interpretive — name a verifiable file/path claim"
  run bash "$REVIEW" coreUserStoryNaReason "nothing user-facing changed"
  assert_failure
  assert_output --partial "FAIL"
}

@test "coreUserStoryNaReason: 'cosmetic only' → FAIL when reviewer rejects" {
  cd "$TEST_REPO"
  export MOCK_CLAUDE_VERDICT="FAIL: 'cosmetic only' is interpretive — name a verifiable file/path claim"
  run bash "$REVIEW" coreUserStoryNaReason "cosmetic only"
  assert_failure
  assert_output --partial "FAIL"
}

# === Diff path enumeration in context ===

@test "coreUserStoryNaReason: stages a diff path into context when origin/main exists" {
  cd "$TEST_REPO"
  # Set up origin/main → first commit; HEAD has a stack-needing path.
  echo "base" > base.md
  git add base.md
  git commit -q -m "baseline"
  git update-ref refs/remotes/origin/main HEAD
  mkdir -p apps/web/components
  echo "x" > apps/web/components/Foo.tsx
  git add -A
  git commit -q -m "add Foo"

  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "apps/web/components/Foo.tsx" "$CAPTURED_PROMPT"
}

@test "coreUserStoryNaReason: graceful degrade when origin/main is missing (HEAD~1 fallback)" {
  cd "$TEST_REPO"
  # Two commits, no origin/main. HEAD~1 exists.
  mkdir -p apps/web/components
  echo "x" > apps/web/components/Foo.tsx
  git add -A
  git commit -q -m "add Foo"

  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "apps/web/components/Foo.tsx" "$CAPTURED_PROMPT"
}

# === Prompt-rule presence ===

@test "coreUserStoryNaReason: prompt rules include rule #11 with ACCEPT/REJECT examples" {
  cd "$TEST_REPO"
  run bash "$REVIEW" coreUserStoryNaReason "no .tsx files modified"
  [ -f "$CAPTURED_PROMPT" ]
  # Rule 11 sits in the prompt's per-check-type rule list, mirroring
  # localTestSkipReason's rule-10 shape.
  grep -q "^11\. For coreUserStoryNaReason" "$CAPTURED_PROMPT"
  # ACCEPT vocab presence — at least one verbatim phrase from D3.
  grep -q "no .tsx files modified" "$CAPTURED_PROMPT"
  # REJECT vocab presence — at least one verbatim phrase from D3.
  grep -q "no visible UI change" "$CAPTURED_PROMPT"
}
