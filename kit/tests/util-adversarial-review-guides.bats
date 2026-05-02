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

# === Prompt rule 1(e) — addition drift sweep ===

@test "docsReviewed: prompt includes rule (e) — addition drift sweep" {
  echo "# new" > "$TEST_REPO/kit/scripts/commit-hooks/check-new.sh"
  (cd "$TEST_REPO" && git add kit/scripts/commit-hooks/check-new.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Addition drift sweep" "$CAPTURED_PROMPT"
  grep -q "STRUCTURED ENUMERATION" "$CAPTURED_PROMPT"
  # Historical-archives carve-out now applies to both (d) and (e) — single
  # line at the end of rule 1 covering kit/notes/** + project equivalents.
  grep -q "kit/notes/" "$CAPTURED_PROMPT"
}

# === Prompt rule 1(a) — sharpened: name specific edits + grep verification ===

@test "docsReviewed: prompt includes rule (a) — name distinctive phrase + grep verification" {
  echo "x" > "$TEST_REPO/kit/scripts/anything.sh"
  (cd "$TEST_REPO" && git add kit/scripts/anything.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  # Rule 1(a) — sharpened 2026-05-01: each AFFECTED-doc claim must name a
  # distinctive phrase from the edit, and the reviewer verifies via grep-on-diff.
  grep -q "Per-doc enumeration" "$CAPTURED_PROMPT"
  grep -q "distinctive phrase" "$CAPTURED_PROMPT"
  grep -q "searching the staged diff" "$CAPTURED_PROMPT"
}

# === Cross-repo inlining removed (devshop-side docsReviewed) ===

@test "docsReviewed (devshop): no longer inlines /workspace/CLAUDE.md cross-repo" {
  echo "# new" > "$TEST_REPO/kit/scripts/commit-hooks/check-new.sh"
  (cd "$TEST_REPO" && git add kit/scripts/commit-hooks/check-new.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  # Pre-2026-05-01 the prompt had a "=== CLAUDE.md (project) ===" block fed
  # from /workspace/CLAUDE.md head-100. Dropped — devshop docs review reads
  # only devshop docs.
  run grep -F "CLAUDE.md (project)" "$CAPTURED_PROMPT"
  [ "$status" -ne 0 ]
}

# === FULL CLAUDE.md inline (head-100 truncation removed) ===

@test "docsReviewed (devshop): inlines CLAUDE.md FULL — captures content past line 100" {
  # Build a CLAUDE.md that's longer than 100 lines, with a sentinel near the end.
  # Pre-2026-05-01 the inliner used `head -100`, which would silently drop the
  # sentinel; FULL inlining must surface it.
  {
    for i in $(seq 1 120); do echo "filler line $i"; done
    echo "SENTINEL_PAST_LINE_100: load-bearing gotcha that lives near the bottom"
  } > "$TEST_REPO/CLAUDE.md"
  (cd "$TEST_REPO" && git add CLAUDE.md && git -c user.email=t@t -c user.name=t commit -q -m "extend CLAUDE.md")

  echo "# new" > "$TEST_REPO/kit/scripts/commit-hooks/check-new.sh"
  (cd "$TEST_REPO" && git add kit/scripts/commit-hooks/check-new.sh)

  (cd "$TEST_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "=== CLAUDE.md (devshop, FULL) ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_PAST_LINE_100" "$CAPTURED_PROMPT"
}

# === Project-side docsReviewed (unified check-type, REPO_MODE=project) ===

@test "docsReviewed (project): inlines project doc catalog when run from non-devshop repo" {
  # Spin up a parallel "project" test repo (no kit/ dir → REPO_MODE=project).
  PROJECT_REPO="$BATS_TEST_TMPDIR/project"
  mkdir -p "$PROJECT_REPO/apps/web" "$PROJECT_REPO/packages/core"
  (cd "$PROJECT_REPO" && git init -q && git config user.email t@t && git config user.name t)
  cat > "$PROJECT_REPO/CLAUDE.md" <<'EOF'
# Project CLAUDE.md
SENTINEL_PROJECT_CLAUDE: project-side catalog should pick this up.
EOF
  cat > "$PROJECT_REPO/METRICS.md" <<'EOF'
# METRICS
SENTINEL_PROJECT_METRICS: events live here.
EOF
  cat > "$PROJECT_REPO/apps/web/README.md" <<'EOF'
# apps/web
SENTINEL_APPS_WEB_README: per-package README inlined FULL.
EOF
  (cd "$PROJECT_REPO" && git add . && git -c user.email=t@t -c user.name=t commit -q -m base)

  # Stage a project-side change.
  echo "export const x = 1" > "$PROJECT_REPO/packages/core/src.ts"
  (cd "$PROJECT_REPO" && git add packages/core/src.ts)

  (cd "$PROJECT_REPO" && bash "$REVIEW" docsReviewed "test reason" >/dev/null 2>&1) || true
  [ -f "$CAPTURED_PROMPT" ]
  grep -q "Repo: project" "$CAPTURED_PROMPT"
  grep -q "=== CLAUDE.md (project, FULL) ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_PROJECT_CLAUDE" "$CAPTURED_PROMPT"
  grep -q "=== METRICS.md (FULL) ===" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_PROJECT_METRICS" "$CAPTURED_PROMPT"
  grep -q "apps/web/README.md (FULL)" "$CAPTURED_PROMPT"
  grep -q "SENTINEL_APPS_WEB_README" "$CAPTURED_PROMPT"
  # Devshop-only sections must NOT appear on the project branch.
  run grep -F "kit/docs/guide/ section headers" "$CAPTURED_PROMPT"
  [ "$status" -ne 0 ]
}
