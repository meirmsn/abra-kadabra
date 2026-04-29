#!/usr/bin/env bats
# Tests for kit/scripts/commit-hooks/check-doc-script-refs.sh — devshop-self
# linter that catches broken kit/scripts/* and kit/hooks/* refs in active docs.

setup() {
  load helpers/setup
  setup_mock_bin
  CHECK="$SCRIPTS_DIR/commit-hooks/check-doc-script-refs.sh"

  # Build a fake devshop layout the linter will scan. Pattern mirrors how
  # adversarial guards are tested — make a temp DEVSHOP root with realistic
  # subdirs, run the script with DEVSHOP=<temp>.
  FAKE_DEVSHOP="$BATS_TEST_TMPDIR/fake-devshop"
  mkdir -p "$FAKE_DEVSHOP/kit/scripts/commit-hooks"
  mkdir -p "$FAKE_DEVSHOP/kit/scripts/sync"
  mkdir -p "$FAKE_DEVSHOP/kit/hooks"
  mkdir -p "$FAKE_DEVSHOP/kit/docs/guide"
  mkdir -p "$FAKE_DEVSHOP/kit/notes/design"
  mkdir -p "$FAKE_DEVSHOP/.claude/skills/devshop/build"
  # Create a real script + a hook so refs to them validate.
  touch "$FAKE_DEVSHOP/kit/scripts/commit-hooks/check-clean-tree.sh"
  touch "$FAKE_DEVSHOP/kit/hooks/pre-commit.sh"
  # Init a git repo at FAKE_DEVSHOP so check picks up devshop-self mode (kit/ is real dir).
  (cd "$FAKE_DEVSHOP" && git init -q -b main && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
}

run_check() {
  (cd "$FAKE_DEVSHOP" && DEVSHOP="$FAKE_DEVSHOP" bash "$CHECK")
}

# --- pass cases ---

@test "passes when active docs have no script refs at all" {
  echo "# Plain markdown" > "$FAKE_DEVSHOP/kit/docs/guide/README.md"
  run run_check
  [ "$status" -eq 0 ]
}

@test "passes when all script refs point at existing files" {
  cat > "$FAKE_DEVSHOP/kit/docs/guide/hooks.md" <<EOF
The kit/scripts/commit-hooks/check-clean-tree.sh blocks dirty trees.
The kit/hooks/pre-commit.sh dispatches checks.
EOF
  run run_check
  [ "$status" -eq 0 ]
}

@test "passes when broken ref is in kit/notes/ (historical, not scanned)" {
  cat > "$FAKE_DEVSHOP/kit/notes/design/old-design.md" <<EOF
We used to have kit/scripts/commit-hooks/check-pr-description.sh — deleted.
EOF
  run run_check
  [ "$status" -eq 0 ]
}

@test "passes when broken ref is exempt-listed" {
  cat > "$FAKE_DEVSHOP/kit/docs/guide/hooks.md" <<EOF
The kit/scripts/preship/future-feature.sh will block X (planned).
EOF
  cat > "$FAKE_DEVSHOP/.devshop-doc-script-refs-exempt" <<EOF
# Future-looking
^kit/scripts/preship/future-feature\.sh$
EOF
  run run_check
  [ "$status" -eq 0 ]
}

@test "passes when project repo (kit/ is a symlink, not a real dir) — no-op" {
  # Replace kit/ with a symlink to mimic a project repo.
  rm -rf "$FAKE_DEVSHOP/kit"
  ln -s /tmp/nonexistent "$FAKE_DEVSHOP/kit"
  run run_check
  [ "$status" -eq 0 ]
}

# --- block cases ---

@test "blocks when ROADMAP.md cites a renamed script that no longer exists" {
  cat > "$FAKE_DEVSHOP/kit/ROADMAP.md" <<EOF
The old kit/scripts/commit-hooks/old-renamed-script.sh has work pending.
EOF
  run run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "old-renamed-script.sh" ]]
  [[ "$output" =~ "ROADMAP.md" ]]
}

@test "blocks when guide doc cites a deleted hook" {
  cat > "$FAKE_DEVSHOP/kit/docs/guide/hooks.md" <<EOF
The kit/hooks/pre-commit.sh exists. The kit/hooks/post-merge.sh does NOT.
EOF
  run run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "post-merge.sh" ]]
}

@test "blocks when SKILL.md cites a missing script" {
  cat > "$FAKE_DEVSHOP/.claude/skills/devshop/build/SKILL.md" <<EOF
Run kit/scripts/sync/missing-script.sh to do the thing.
EOF
  run run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing-script.sh" ]]
  [[ "$output" =~ "SKILL.md" ]]
}

@test "blocks with /devshop/ prefix in the ref (absolute path style)" {
  cat > "$FAKE_DEVSHOP/kit/docs/guide/hooks.md" <<EOF
See /devshop/kit/scripts/commit-hooks/missing.sh for details.
EOF
  run run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing.sh" ]]
}

@test "lists multiple broken refs in a single failure" {
  cat > "$FAKE_DEVSHOP/kit/ROADMAP.md" <<EOF
Refs:
- kit/scripts/missing-one.sh
- kit/scripts/missing-two.sh
- kit/hooks/missing-hook.sh
EOF
  run run_check
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing-one.sh" ]]
  [[ "$output" =~ "missing-two.sh" ]]
  [[ "$output" =~ "missing-hook.sh" ]]
}

@test "exempt list ignores blank lines and # comments" {
  cat > "$FAKE_DEVSHOP/kit/docs/guide/hooks.md" <<EOF
The kit/scripts/preship/future.sh is planned.
EOF
  cat > "$FAKE_DEVSHOP/.devshop-doc-script-refs-exempt" <<EOF
# Top comment

# Another comment
^kit/scripts/preship/future\.sh$

EOF
  run run_check
  [ "$status" -eq 0 ]
}
