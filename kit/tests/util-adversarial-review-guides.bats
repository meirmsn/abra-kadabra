#!/usr/bin/env bats
# Tests for kit/scripts/adversarial-review.sh — guide-doc selective inlining.
# Verifies the GUIDES_TO_INCLUDE map routes correctly based on staged-paths,
# that the inlined bodies appear in the prompt under the documented header,
# and that prompt rule 4(e) — addition drift sweep — is included.
#
# Companion to util-adversarial-review.bats. Like the sibling file these are
# deterministic checks of what the LLM SEES (the prompt content), not tests
# of LLM behavior.

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
  # Devshop-self mode: real kit/ dir at repo root (not a symlink).
  mkdir -p "$TEST_REPO/kit/docs/guide"
  mkdir -p "$TEST_REPO/kit/scripts/commit-hooks"
  mkdir -p "$TEST_REPO/kit/scripts/preship"
  mkdir -p "$TEST_REPO/kit/scripts/sync"
  mkdir -p "$TEST_REPO/kit/hooks"
  mkdir -p "$TEST_REPO/template/.husky"
  mkdir -p "$TEST_REPO/.devcontainer"
  mkdir -p "$TEST_REPO/.claude"

  # Reference docs the docsReviewed CONTEXT block reads — keep minimal.
  echo "# OVERVIEW" > "$TEST_REPO/kit/docs/OVERVIEW.md"
  echo "# MODEL"    > "$TEST_REPO/kit/docs/MODEL.md"
  echo "# FAQ"      > "$TEST_REPO/kit/docs/FAQ.md"
  echo "# README"   > "$TEST_REPO/README.md"
  echo "# CLAUDE"   > "$TEST_REPO/CLAUDE.md"

  # Guide-doc fixtures with sentinel strings the tests grep for. The inliner
  # routes solely off the staged-path patterns; what gets inlined is whatever
  # is at the routed file path. Keeping fixtures self-contained means the
  # tests don't break when the real guide docs are restructured.
  cat > "$TEST_REPO/kit/docs/guide/hooks.md" <<'GUIDE'
# Hooks & Commit Flow

## Husky pre-commit (during git commit)

SENTINEL_HOOKS_BODY: hooks.md content that should be selectively inlined.
GUIDE

  cat > "$TEST_REPO/kit/docs/guide/architecture.md" <<'GUIDE'
# Architecture

## File lifecycle

SENTINEL_ARCH_LIFECYCLE: only this section should be inlined.

## Other section

SENTINEL_ARCH_OTHER: must NOT appear when only File lifecycle was requested.
GUIDE

  cat > "$TEST_REPO/kit/docs/guide/security.md" <<'GUIDE'
# Security

## Devcontainer + firewall

SENTINEL_SECURITY_BODY: security.md content that should be inlined.
GUIDE

  (cd "$TEST_REPO" && git add . && git -c user.email=t@t -c user.name=t commit -q -m base)
}

# === Positive routing: each map entry fires on its trigger paths ===

@test "guides inline: hooks.md (FULL) when kit/scripts/commit-hooks/ added" {
  echo "# new guard" > "$TEST_REPO/kit/scripts/commit-hooks/check-new.sh"
  (cd "$TEST_REPO" && git add kit/scripts/commit-hooks/check-new.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Relevant guide doc bodies" "$CAPTURED_PROMPT"
  grep -q "=== hooks.md ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_HOOKS_BODY" "$CAPTURED_PROMPT"
}

@test "guides inline: hooks.md (FULL) when kit/hooks/ touched" {
  echo "# pre-push wrapper" > "$TEST_REPO/kit/hooks/pre-push.sh"
  (cd "$TEST_REPO" && git add kit/hooks/pre-push.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "=== hooks.md ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_HOOKS_BODY" "$CAPTURED_PROMPT"
}

@test "guides inline: hooks.md (FULL) when kit/scripts/preship/ touched" {
  echo "# new gate" > "$TEST_REPO/kit/scripts/preship/router-shim.sh"
  (cd "$TEST_REPO" && git add kit/scripts/preship/router-shim.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "=== hooks.md ===" "$CAPTURED_PROMPT"
}

@test "guides inline: hooks.md (FULL) when .claude/settings.json staged" {
  echo "{}" > "$TEST_REPO/.claude/settings.json"
  (cd "$TEST_REPO" && git add .claude/settings.json)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "=== hooks.md ===" "$CAPTURED_PROMPT"
}

@test "guides inline: architecture.md § File lifecycle when template/ touched" {
  echo "# scaffold" > "$TEST_REPO/template/CLAUDE.md"
  (cd "$TEST_REPO" && git add template/CLAUDE.md)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "=== architecture.md § File lifecycle ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_ARCH_LIFECYCLE" "$CAPTURED_PROMPT"
  # Section-scoped extraction — sibling sections must NOT leak in.
  run grep "SENTINEL_ARCH_OTHER" "$CAPTURED_PROMPT"
  [ "$status" -ne 0 ]
}

@test "guides inline: security.md (FULL) when .devcontainer/ touched" {
  echo "FROM scratch" > "$TEST_REPO/.devcontainer/Dockerfile"
  (cd "$TEST_REPO" && git add .devcontainer/Dockerfile)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "=== security.md ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_SECURITY_BODY" "$CAPTURED_PROMPT"
}

# === Composition: multiple map entries fire on a single commit ===

@test "guides inline: multiple guides inline together when diff spans areas" {
  echo "# new"          > "$TEST_REPO/kit/scripts/commit-hooks/check-new.sh"
  echo "FROM scratch"   > "$TEST_REPO/.devcontainer/Dockerfile"
  (cd "$TEST_REPO" && git add kit/scripts/commit-hooks/check-new.sh .devcontainer/Dockerfile)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "=== hooks.md ===" "$CAPTURED_PROMPT"
  grep -q "=== security.md ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_HOOKS_BODY" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_SECURITY_BODY" "$CAPTURED_PROMPT"
}

# === Negative cases ===

@test "guides inline: irrelevant project changes do NOT trigger any inline" {
  mkdir -p "$TEST_REPO/apps/web/app"
  echo "export default function Page() {}" > "$TEST_REPO/apps/web/app/page.tsx"
  (cd "$TEST_REPO" && git add apps/web/app/page.tsx)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  # Grep on the context-block-only parenthetical, not "Relevant guide doc bodies"
  # — that substring also appears inside rule 4(e)'s text, which is included for
  # every docsReviewed call regardless of whether anything was actually inlined.
  run grep "selectively inlined based on staged diff" "$CAPTURED_PROMPT"
  [ "$status" -ne 0 ]
}

@test "guides inline: only fires for docsReviewed (not other check-types)" {
  # Same diff that would trigger hooks.md inline under docsReviewed —
  # for dirtyTreeReason it must be ignored.
  echo "# new" > "$TEST_REPO/kit/scripts/commit-hooks/check-new.sh"
  (cd "$TEST_REPO" && git add kit/scripts/commit-hooks/check-new.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" dirtyTreeReason "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  # Grep on the context-block-only parenthetical, not "Relevant guide doc bodies"
  # — that substring also appears inside rule 4(e)'s text, which is included for
  # every docsReviewed call regardless of whether anything was actually inlined.
  run grep "selectively inlined based on staged diff" "$CAPTURED_PROMPT"
  [ "$status" -ne 0 ]
  run grep "=== hooks.md ===" "$CAPTURED_PROMPT"
  [ "$status" -ne 0 ]
}

# === Prompt rule 4(e) — addition drift sweep ===

@test "docsReviewed: prompt includes rule (e) — addition drift sweep" {
  echo "# new" > "$TEST_REPO/kit/scripts/commit-hooks/check-new.sh"
  (cd "$TEST_REPO" && git add kit/scripts/commit-hooks/check-new.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Addition drift sweep" "$CAPTURED_PROMPT"
  grep -q "STRUCTURED ENUMERATION" "$CAPTURED_PROMPT"
  # Mirrors the (d) carve-out so historical-notes traffic doesn't trip it.
  grep -q "Historical notes under kit/notes/" "$CAPTURED_PROMPT"
}
