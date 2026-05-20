#!/usr/bin/env bats
# Structural + behavioral assertions for the gstack-projects symlink redirect.
#
# Five gstack skills (canary, ship, land-and-deploy, plan-ceo-review,
# plan-design-review) hardcode ~/.gstack/projects/$SLUG/... for their artifact
# writes instead of honoring $GSTACK_HOME. Editing those SKILL.md.tmpl files
# in-tree is forbidden (per CLAUDE.md § gstack — /gstack-upgrade wipes local
# edits with no warning), so the fix lives in init-devshop.sh: drop a symlink
# /home/node/.gstack/projects → /workspace/.gstack/projects so both write
# paths converge on one git-tracked tree.
#
# Pairs with the widened template/.gitignore — re-includes .md / .html / .png
# / .json at any depth under projects/ so the 5 hardcoded-path skills' design
# docs / ceo-plans / variant HTML / approval JSON / screenshots are all
# version-tracked.
#
# Background:
#   Operations: kit/docs/guide/ops.md § gstack runtime state
#   CLAUDE.md § gstack (vendored-install upgrade wipe)

setup() {
  load helpers/setup
  DEVSHOP="/devshop"
  INIT_DEVSHOP="$DEVSHOP/kit/scripts/init-devshop.sh"
  TEMPLATE_GITIGNORE="$DEVSHOP/template/.gitignore"
  # Test under the worktree if we're in one, otherwise main.
  if [ -f "$BATS_TEST_DIRNAME/../scripts/init-devshop.sh" ]; then
    INIT_DEVSHOP="$BATS_TEST_DIRNAME/../scripts/init-devshop.sh"
  fi
  if [ -f "$BATS_TEST_DIRNAME/../../template/.gitignore" ]; then
    TEMPLATE_GITIGNORE="$BATS_TEST_DIRNAME/../../template/.gitignore"
  fi
}

# =============================================================================
# init-devshop.sh contains the gstack-projects symlink block
# =============================================================================

@test "init-devshop.sh: declares GSTACK_PROJECTS_LINK at /home/node/.gstack/projects" {
  run grep -E 'GSTACK_PROJECTS_LINK="?/home/node/\.gstack/projects' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop.sh: declares GSTACK_PROJECTS_DIR under \$WS/.gstack/projects" {
  run grep -E 'GSTACK_PROJECTS_DIR="?\$WS/\.gstack/projects' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop.sh: creates the workspace projects dir with node ownership" {
  run grep -E 'mkdir -p "\$GSTACK_PROJECTS_DIR"' "$INIT_DEVSHOP"
  assert_success
  run grep -E 'chown -R node:node "\$WS/\.gstack"' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop.sh: drops the symlink with ln -sfn (idempotent)" {
  run grep -E 'ln -sfn "\$GSTACK_PROJECTS_DIR" "\$GSTACK_PROJECTS_LINK"' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop.sh: chown -h on the symlink so node owns it" {
  run grep -E 'chown -h node:node "\$GSTACK_PROJECTS_LINK"' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop.sh: migrates an existing real ~/.gstack/projects dir before linking" {
  # Guarded by [ -d ... ] && [ ! -L ... ] so it only fires the first time.
  run grep -E '\[ -d "\$GSTACK_PROJECTS_LINK" \] && \[ ! -L "\$GSTACK_PROJECTS_LINK" \]' "$INIT_DEVSHOP"
  assert_success
}

@test "init-devshop.sh: symlink block lands AFTER the devshop-self guard (line 67-ish exit)" {
  # Confirms we don't symlink in devshop-self mode (where /workspace == /devshop
  # and the symlink would point at the devshop tree itself).
  guard_line=$(grep -ni 'devshop-self guard' "$INIT_DEVSHOP" | head -1 | cut -d: -f1)
  symlink_line=$(grep -n 'Gstack projects symlink' "$INIT_DEVSHOP" | head -1 | cut -d: -f1)
  [ -n "$guard_line" ] && [ -n "$symlink_line" ]
  [ "$symlink_line" -gt "$guard_line" ]
}

# =============================================================================
# Behavioral: run the symlink block in a sandbox, assert resolution
# =============================================================================

@test "symlink block: a write to \$HOME/.gstack/projects/<slug>/foo.md lands under \$WS/.gstack/projects/<slug>/foo.md" {
  # Sandbox the block so it doesn't need root or touch real /workspace.
  SANDBOX="$BATS_TEST_TMPDIR/sandbox"
  mkdir -p "$SANDBOX/ws" "$SANDBOX/home"

  # Extract the symlink block and run it with sandboxed paths (no chown, since
  # we're not root in the test runner).
  WS="$SANDBOX/ws" HOME="$SANDBOX/home" bash -c '
    set -euo pipefail
    GSTACK_PROJECTS_DIR="$WS/.gstack/projects"
    GSTACK_PROJECTS_LINK="$HOME/.gstack/projects"
    mkdir -p "$GSTACK_PROJECTS_DIR"
    if [ -d "$GSTACK_PROJECTS_LINK" ] && [ ! -L "$GSTACK_PROJECTS_LINK" ]; then
      cp -an "$GSTACK_PROJECTS_LINK"/. "$GSTACK_PROJECTS_DIR"/ 2>/dev/null || true
      rm -rf "$GSTACK_PROJECTS_LINK"
    fi
    mkdir -p "$(dirname "$GSTACK_PROJECTS_LINK")"
    ln -sfn "$GSTACK_PROJECTS_DIR" "$GSTACK_PROJECTS_LINK"
  '

  # The symlink must resolve to the workspace projects dir.
  [ -L "$SANDBOX/home/.gstack/projects" ]
  link_target=$(readlink "$SANDBOX/home/.gstack/projects")
  [ "$link_target" = "$SANDBOX/ws/.gstack/projects" ]

  # A write through the symlink lands in the workspace dir.
  mkdir -p "$SANDBOX/home/.gstack/projects/myslug"
  echo "design doc" > "$SANDBOX/home/.gstack/projects/myslug/foo.md"
  [ -f "$SANDBOX/ws/.gstack/projects/myslug/foo.md" ]
  run cat "$SANDBOX/ws/.gstack/projects/myslug/foo.md"
  [ "$output" = "design doc" ]
}

@test "symlink block: migrates a pre-existing real ~/.gstack/projects dir, then symlinks" {
  SANDBOX="$BATS_TEST_TMPDIR/migrate-sandbox"
  mkdir -p "$SANDBOX/ws" "$SANDBOX/home/.gstack/projects/legacy-slug"
  echo "legacy content" > "$SANDBOX/home/.gstack/projects/legacy-slug/old.md"

  WS="$SANDBOX/ws" HOME="$SANDBOX/home" bash -c '
    set -euo pipefail
    GSTACK_PROJECTS_DIR="$WS/.gstack/projects"
    GSTACK_PROJECTS_LINK="$HOME/.gstack/projects"
    mkdir -p "$GSTACK_PROJECTS_DIR"
    if [ -d "$GSTACK_PROJECTS_LINK" ] && [ ! -L "$GSTACK_PROJECTS_LINK" ]; then
      cp -an "$GSTACK_PROJECTS_LINK"/. "$GSTACK_PROJECTS_DIR"/ 2>/dev/null || true
      rm -rf "$GSTACK_PROJECTS_LINK"
    fi
    mkdir -p "$(dirname "$GSTACK_PROJECTS_LINK")"
    ln -sfn "$GSTACK_PROJECTS_DIR" "$GSTACK_PROJECTS_LINK"
  '

  # Legacy content survived the migration.
  [ -f "$SANDBOX/ws/.gstack/projects/legacy-slug/old.md" ]
  run cat "$SANDBOX/ws/.gstack/projects/legacy-slug/old.md"
  [ "$output" = "legacy content" ]

  # And the symlink is now in place.
  [ -L "$SANDBOX/home/.gstack/projects" ]
}

# =============================================================================
# template/.gitignore re-include patterns
# =============================================================================

@test "template gitignore: ignores .gstack/* but re-includes projects/" {
  run grep -Fx '.gstack/*' "$TEMPLATE_GITIGNORE"
  assert_success
  run grep -Fx '!.gstack/projects/' "$TEMPLATE_GITIGNORE"
  assert_success
}

@test "template gitignore: blanket-ignores .gstack/projects/** for the deep traversal" {
  run grep -Fx '.gstack/projects/**' "$TEMPLATE_GITIGNORE"
  assert_success
}

@test "template gitignore: re-includes intermediate directories under projects/" {
  # Required for re-includes to traverse into subdirs.
  run grep -Fx '!.gstack/projects/**/' "$TEMPLATE_GITIGNORE"
  assert_success
}

@test "template gitignore: re-includes .md / .html / .png / .json at any depth" {
  run grep -Fx '!.gstack/projects/**/*.md' "$TEMPLATE_GITIGNORE"
  assert_success
  run grep -Fx '!.gstack/projects/**/*.html' "$TEMPLATE_GITIGNORE"
  assert_success
  run grep -Fx '!.gstack/projects/**/*.png' "$TEMPLATE_GITIGNORE"
  assert_success
  run grep -Fx '!.gstack/projects/**/*.json' "$TEMPLATE_GITIGNORE"
  assert_success
}

# =============================================================================
# Behavioral: spin up a throwaway git repo with the gitignore + sample artifacts
# =============================================================================

@test "gitignore behavior: tracks reviewable artifacts at any depth, excludes runtime noise" {
  REPO="$BATS_TEST_TMPDIR/gitignore-repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email "test@test.com"
  git -C "$REPO" config user.name "Test"
  # Copy the four lines of interest into the repo's gitignore.
  cp "$TEMPLATE_GITIGNORE" "$REPO/.gitignore"

  # Re-included artifacts at various depths (one-level + deep nested):
  mkdir -p "$REPO/.gstack/projects/myslug/ceo-plans"
  echo "x" > "$REPO/.gstack/projects/myslug/office-hours.md"
  echo "x" > "$REPO/.gstack/projects/myslug/ceo-plans/2026-05-20-plan.md"
  mkdir -p "$REPO/.gstack/projects/myslug/designs/home-20260520"
  echo "x" > "$REPO/.gstack/projects/myslug/designs/home-20260520/finalized.html"
  echo "x" > "$REPO/.gstack/projects/myslug/designs/home-20260520/variant-1.png"
  echo "x" > "$REPO/.gstack/projects/myslug/designs/home-20260520/approved.json"

  # Slash-in-branch stray subdir tolerance.
  mkdir -p "$REPO/.gstack/projects/myslug/fix/foo"
  echo "x" > "$REPO/.gstack/projects/myslug/fix/foo/notes.md"

  # Runtime noise that should stay ignored.
  echo "x" > "$REPO/.gstack/projects/myslug/learnings.jsonl"
  echo "x" > "$REPO/.gstack/projects/myslug/timeline.jsonl"
  echo "x" > "$REPO/.gstack/browse.json"
  mkdir -p "$REPO/.gstack/sessions"
  echo "x" > "$REPO/.gstack/sessions/abc.json"

  # check-ignore exits 0 when the path IS ignored, 1 when it is NOT ignored.
  # Re-included (NOT ignored) → exit 1:
  ! git -C "$REPO" check-ignore -q ".gstack/projects/myslug/office-hours.md"
  ! git -C "$REPO" check-ignore -q ".gstack/projects/myslug/ceo-plans/2026-05-20-plan.md"
  ! git -C "$REPO" check-ignore -q ".gstack/projects/myslug/designs/home-20260520/finalized.html"
  ! git -C "$REPO" check-ignore -q ".gstack/projects/myslug/designs/home-20260520/variant-1.png"
  ! git -C "$REPO" check-ignore -q ".gstack/projects/myslug/designs/home-20260520/approved.json"
  ! git -C "$REPO" check-ignore -q ".gstack/projects/myslug/fix/foo/notes.md"

  # Ignored → exit 0:
  git -C "$REPO" check-ignore -q ".gstack/projects/myslug/learnings.jsonl"
  git -C "$REPO" check-ignore -q ".gstack/projects/myslug/timeline.jsonl"
  # Sessions/ is outside projects/ entirely — covered by the leading .gstack/*
  git -C "$REPO" check-ignore -q ".gstack/sessions/abc.json"
  git -C "$REPO" check-ignore -q ".gstack/browse.json"
}
