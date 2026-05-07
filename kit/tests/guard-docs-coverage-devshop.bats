#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-docs-coverage-devshop.sh
# Layer-1 deterministic surface→doc mapping for devshop self.
#   Surface touched without paired guide / orientation doc → BLOCK
# Bypass via `git -c devshop.docsCoverageReason="<why>"` accepts on flag presence
# (no LLM call). Trailer emission is the prepare-commit-msg hook's job; audit-time
# `/ak-docs-review` harvests the trailer (PR-C migration — see kit/ROADMAP.md § PR-C § A).

setup() {
  load helpers/setup
  setup_mock_bin
  TEST_REPO="$BATS_TEST_TMPDIR/devshop"
  mkdir -p "$TEST_REPO/kit/scripts/commit-hooks" \
           "$TEST_REPO/kit/scripts/preship" \
           "$TEST_REPO/kit/scripts/sync" \
           "$TEST_REPO/kit/scripts/notify" \
           "$TEST_REPO/kit/hooks" \
           "$TEST_REPO/kit/docs/guide" \
           "$TEST_REPO/kit/notes" \
           "$TEST_REPO/kit/tests" \
           "$TEST_REPO/.claude/skills/devshop" \
           "$TEST_REPO/template/.husky" \
           "$TEST_REPO/template/.devcontainer" \
           "$TEST_REPO/.devcontainer"
  git -C "$TEST_REPO" init -q
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "Test"
  # Seed reference docs so they exist (not staged in each test).
  for g in workflow conventions hooks architecture security ops supabase-ssr-boilerplate; do
    echo "# $g" > "$TEST_REPO/kit/docs/guide/$g.md"
  done
  echo "# CLAUDE.md" > "$TEST_REPO/CLAUDE.md"
  echo "# manifest" > "$TEST_REPO/kit/manifest.txt"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -q -m "seed"
  SCRIPT="$SCRIPTS_DIR/commit-hooks/check-docs-coverage-devshop.sh"
  cd "$TEST_REPO"
}

run_script() {
  run bash "$SCRIPT"
}

stage() {
  local path="$1" content="${2:-x}"
  mkdir -p "$TEST_REPO/$(dirname "$path")"
  echo "$content" > "$TEST_REPO/$path"
  git -C "$TEST_REPO" add "$path"
}

# --- Surface: kit/scripts/commit-hooks/** → guide/hooks.md ---

@test "BLOCK: kit/scripts/commit-hooks/** without guide/hooks.md staged" {
  stage kit/scripts/commit-hooks/new-guard.sh
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
  assert_output --partial "guide/hooks.md"
}

@test "PASS: kit/scripts/commit-hooks/** with guide/hooks.md staged" {
  stage kit/scripts/commit-hooks/new-guard.sh
  echo "# updated" > "$TEST_REPO/kit/docs/guide/hooks.md"
  git -C "$TEST_REPO" add kit/docs/guide/hooks.md
  run_script
  assert_success
}

# --- Surface: kit/scripts/preship/** → pre-ship SKILL.md OR any guide ---

@test "BLOCK: kit/scripts/preship/** without pre-ship SKILL.md or any guide" {
  stage kit/scripts/preship/new-router.sh
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

@test "PASS: kit/scripts/preship/** with pre-ship SKILL.md staged" {
  stage kit/scripts/preship/new-router.sh
  stage .claude/skills/devshop/pre-ship/SKILL.md "# pre-ship"
  # Staging the SKILL.md itself fires the `.claude/skills/**/SKILL.md` surface,
  # which independently requires guide/workflow.md OR CLAUDE.md. Stage CLAUDE.md
  # to satisfy that — the preship surface is satisfied by the SKILL.md itself.
  echo "# updated" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_success
}

@test "PASS: kit/scripts/preship/** with any guide doc staged" {
  stage kit/scripts/preship/new-router.sh
  echo "# updated" > "$TEST_REPO/kit/docs/guide/workflow.md"
  git -C "$TEST_REPO" add kit/docs/guide/workflow.md
  run_script
  assert_success
}

# --- Surface: kit/scripts/**.sh → CLAUDE.md OR any guide ---

@test "BLOCK: kit/scripts/foo.sh without CLAUDE.md or any guide" {
  stage kit/scripts/foo.sh
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
  assert_output --partial "CLAUDE.md"
}

@test "PASS: kit/scripts/foo.sh with CLAUDE.md staged" {
  stage kit/scripts/foo.sh
  echo "# updated" > "$TEST_REPO/CLAUDE.md"
  git -C "$TEST_REPO" add CLAUDE.md
  run_script
  assert_success
}

# --- Surface: kit/hooks/** → guide/hooks.md OR CLAUDE.md ---

@test "BLOCK: kit/hooks/** without guide/hooks.md or CLAUDE.md" {
  stage kit/hooks/foo.sh
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

@test "PASS: kit/hooks/** with guide/hooks.md staged" {
  stage kit/hooks/foo.sh
  echo "# updated" > "$TEST_REPO/kit/docs/guide/hooks.md"
  git -C "$TEST_REPO" add kit/docs/guide/hooks.md
  run_script
  assert_success
}

# --- Surface: .claude/skills/**/SKILL.md → guide/workflow.md OR CLAUDE.md ---

@test "BLOCK: skill change without workflow.md / CLAUDE.md" {
  stage .claude/skills/devshop/foo/SKILL.md "# foo"
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

@test "PASS: skill change with workflow.md staged" {
  stage .claude/skills/devshop/foo/SKILL.md "# foo"
  echo "# updated" > "$TEST_REPO/kit/docs/guide/workflow.md"
  git -C "$TEST_REPO" add kit/docs/guide/workflow.md
  run_script
  assert_success
}

# --- Surface: template/** (excl. .env) → architecture/security/ops ---

@test "BLOCK: template/.husky change without architecture/security/ops" {
  stage template/.husky/pre-commit "x"
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

@test "PASS: template/** with guide/architecture.md staged" {
  stage template/.husky/pre-commit "x"
  echo "# updated" > "$TEST_REPO/kit/docs/guide/architecture.md"
  git -C "$TEST_REPO" add kit/docs/guide/architecture.md
  run_script
  assert_success
}

@test "carve-out: template/.devcontainer/.env does NOT fire" {
  stage template/.devcontainer/.env "FOO=bar"
  run_script
  assert_success
}

# --- Surface: .devcontainer/** (excl. .env) → security/ops ---

@test "BLOCK: .devcontainer change without security/ops" {
  stage .devcontainer/devcontainer.json "{}"
  run_script
  assert_failure
}

@test "PASS: .devcontainer/** with guide/security.md staged" {
  stage .devcontainer/devcontainer.json "{}"
  echo "# updated" > "$TEST_REPO/kit/docs/guide/security.md"
  git -C "$TEST_REPO" add kit/docs/guide/security.md
  run_script
  assert_success
}

@test "carve-out: .devcontainer/.env does NOT fire" {
  stage .devcontainer/.env "FOO=bar"
  run_script
  assert_success
}

# --- Surface: kit/manifest.txt → guide/architecture.md ---

@test "BLOCK: kit/manifest.txt without guide/architecture.md" {
  echo "newpath [locked]" >> "$TEST_REPO/kit/manifest.txt"
  git -C "$TEST_REPO" add kit/manifest.txt
  run_script
  assert_failure
  assert_output --partial "guide/architecture.md"
}

@test "PASS: kit/manifest.txt with guide/architecture.md staged" {
  echo "newpath [locked]" >> "$TEST_REPO/kit/manifest.txt"
  echo "# updated" > "$TEST_REPO/kit/docs/guide/architecture.md"
  git -C "$TEST_REPO" add kit/manifest.txt kit/docs/guide/architecture.md
  run_script
  assert_success
}

# --- Carve-outs: never fire ---

@test "carve-out: kit/notes/** does not fire" {
  stage kit/notes/some-note.md "# note"
  run_script
  assert_success
}

@test "carve-out: kit/ROADMAP.md does not fire" {
  echo "# roadmap" > "$TEST_REPO/kit/ROADMAP.md"
  git -C "$TEST_REPO" add kit/ROADMAP.md
  run_script
  assert_success
}

@test "carve-out: kit/TODOS.md does not fire" {
  echo "# todos" > "$TEST_REPO/kit/TODOS.md"
  git -C "$TEST_REPO" add kit/TODOS.md
  run_script
  assert_success
}

@test "carve-out: kit/tests/** does not fire" {
  stage kit/tests/new.bats "# tests"
  run_script
  assert_success
}

@test "carve-out: kit/docs/** does not fire (audit handles guide-only commits)" {
  echo "# updated" > "$TEST_REPO/kit/docs/guide/conventions.md"
  git -C "$TEST_REPO" add kit/docs/guide/conventions.md
  run_script
  assert_success
}

@test "carve-out: kit/version does not fire" {
  echo "1.2.3" > "$TEST_REPO/kit/version"
  git -C "$TEST_REPO" add kit/version
  run_script
  assert_success
}

# --- Cross-repo isolation ---

@test "exits 0 when run in project repo (kit/ is symlink)" {
  local project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project"
  git -C "$project" init -q
  git -C "$project" config user.email t@t
  git -C "$project" config user.name t
  echo init > "$project/.gitkeep"
  git -C "$project" add .gitkeep
  git -C "$project" commit -q -m init
  ln -s /tmp/nowhere "$project/kit"
  run bash -c "cd '$project' && bash '$SCRIPT'"
  assert_success
}

# --- Layer 1 bypass: flag-presence (no LLM call) ---

@test "bypass: flag presence accepts blocked add (no LLM call)" {
  stage kit/scripts/commit-hooks/new-guard.sh
  git -C "$TEST_REPO" config devshop.docsCoverageReason "guide/hooks.md update batched with PR-D follow-up"
  run_script
  assert_success
  assert_output --partial "Docs-coverage block bypassed"
  assert_output --partial "Docs-Coverage-Bypass: trailer"
}

@test "bypass: empty flag value still blocks" {
  stage kit/scripts/commit-hooks/new-guard.sh
  git -C "$TEST_REPO" config devshop.docsCoverageReason ""
  run_script
  assert_failure
  assert_output --partial "BLOCKING"
}

# --- Multi-surface ---

@test "BLOCK lists all unsatisfied surface groups when multiple touched" {
  stage kit/scripts/commit-hooks/new-guard.sh
  stage .claude/skills/devshop/foo/SKILL.md "# foo"
  run_script
  assert_failure
  assert_output --partial "commit-hooks"
  assert_output --partial "skills"
}
