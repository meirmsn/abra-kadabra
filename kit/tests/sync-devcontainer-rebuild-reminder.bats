#!/usr/bin/env bats
# Tests for from-devshop.sh's post-sync devcontainer rebuild advisory
# (report_devcontainer_rebuild).
#
# The sync rsync excludes [locked] .devcontainer leaves (init-devshop.sh owns
# them, refreshing from template on every container start), so they never show
# up in `git diff` after a sync. report_devcontainer_rebuild content-diffs the
# project's in-tree locked leaves against the template to predict whether the
# next container start (rebuild) will change anything, and prints:
#   - a loud "Rebuild needed" block listing the drifted files, OR
#   - a one-line "No .devcontainer changes" note (conditional + always-note).
#
# Validates:
#   - drift in a locked leaf → reminder names the file
#   - identical locked leaves → no-rebuild note, no reminder
#   - project missing a locked leaf the template has → drift
#   - a change to a NON-locked (synced) .devcontainer file does not trigger

setup() {
  load helpers/setup

  PREVIEW_LIB="$SCRIPTS_DIR/sync/lib/preview-confirm.sh"
  PARSE_LIB="$SCRIPTS_DIR/sync/lib/parse-manifest.sh"
  FROM_SCRIPT="$SCRIPTS_DIR/sync/from-devshop.sh"

  FIXTURE_PROJECT="$BATS_TEST_TMPDIR/project"
  FIXTURE_DEVSHOP="$BATS_TEST_TMPDIR/devshop"
  FIXTURE_TEMPLATE="$FIXTURE_DEVSHOP/template"

  mkdir -p "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib"
  mkdir -p "$FIXTURE_TEMPLATE/.devcontainer"
  mkdir -p "$FIXTURE_PROJECT/.devcontainer"
  mkdir -p "$FIXTURE_DEVSHOP/.git" "$FIXTURE_DEVSHOP/kit"
  echo "1.0.0" > "$FIXTURE_DEVSHOP/kit/version"

  cp "$PREVIEW_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/preview-confirm.sh"
  cp "$PARSE_LIB" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/lib/parse-manifest.sh"
  cp "$FROM_SCRIPT" "$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh"
  FIXTURE_FROM="$FIXTURE_PROJECT/.devshopkit/scripts/sync/from-devshop.sh"

  # .devcontainer is a [sync] dir whose Dockerfile + devcontainer.json leaves
  # are [locked] (excluded from the rsync, owned by init-devshop.sh). README.md
  # is a plain synced leaf.
  cat > "$FIXTURE_PROJECT/.devshopkit/manifest.txt" <<'M'
.devcontainer/ [sync]
.devcontainer/Dockerfile [locked]
.devcontainer/devcontainer.json [locked]
M

  # A baseline synced (non-locked) file so rsync of the [sync] dir is exercised.
  echo "template readme" > "$FIXTURE_TEMPLATE/.devcontainer/README.md"
}

# Helper: set the locked-leaf contents on both sides.
#   set_dockerfile <template-content> <project-content>
# Pass "" as project-content to leave the project copy absent.
set_dockerfile() {
  printf '%s\n' "$1" > "$FIXTURE_TEMPLATE/.devcontainer/Dockerfile"
  printf '%s\n' "FROM base" > "$FIXTURE_TEMPLATE/.devcontainer/devcontainer.json"
  printf '%s\n' "FROM base" > "$FIXTURE_PROJECT/.devcontainer/devcontainer.json"
  if [ -n "$2" ]; then
    printf '%s\n' "$2" > "$FIXTURE_PROJECT/.devcontainer/Dockerfile"
  fi
}

@test "drift in a locked .devcontainer leaf prints a rebuild reminder naming the file" {
  set_dockerfile "FROM node:22" "FROM node:20"
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success
  assert_output --partial "Rebuild needed"
  assert_output --partial "Dockerfile"
}

@test "identical locked leaves print the no-rebuild note and no reminder" {
  set_dockerfile "FROM node:22" "FROM node:22"
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success
  assert_output --partial "No .devcontainer changes"
  refute_output --partial "Rebuild needed"
}

@test "project missing a locked leaf the template has is treated as drift" {
  set_dockerfile "FROM node:22" ""   # no project Dockerfile
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success
  assert_output --partial "Rebuild needed"
  assert_output --partial "Dockerfile"
}

@test "a change to a non-locked synced .devcontainer file does not trigger a rebuild" {
  # Locked leaves identical → no rebuild; only the synced README differs.
  set_dockerfile "FROM node:22" "FROM node:22"
  echo "project readme (stale)" > "$FIXTURE_PROJECT/.devcontainer/README.md"
  echo "template readme (new)"  > "$FIXTURE_TEMPLATE/.devcontainer/README.md"
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success
  assert_output --partial "No .devcontainer changes"
  refute_output --partial "Rebuild needed"
}

@test "locked-only drift with NO synced changes still prints the rebuild reminder" {
  # The critical case: a devshop release that bumps only a [locked] leaf
  # (Dockerfile) and no synced files. The preview reports "No changes to apply"
  # (rc 2) because locked leaves are excluded from it — but the advisory must
  # still fire, otherwise the operator never learns a rebuild is needed.
  # Make every synced path identical so total==0.
  set_dockerfile "FROM node:22" "FROM node:20"
  echo "same readme" > "$FIXTURE_TEMPLATE/.devcontainer/README.md"
  echo "same readme" > "$FIXTURE_PROJECT/.devcontainer/README.md"
  DEVSHOP_DIR="$FIXTURE_DEVSHOP" run bash "$FIXTURE_FROM" --yes
  assert_success
  assert_output --partial "No changes to apply"
  assert_output --partial "Rebuild needed"
  assert_output --partial "Dockerfile"
}

@test "user-declined sync stays silent — no rebuild advisory on abort (rc 1)" {
  # rc-1 path: a synced (non-locked) README change makes the preview non-empty,
  # so the script reaches the confirm prompt; the operator then declines
  # (setsid detaches the controlling terminal + empty stdin → the prompt's
  # `read < /dev/tty` fails → abort). Even with a drifted locked leaf, the
  # advisory must stay SILENT on decline — only rc 0 (apply) and rc 2 (no synced
  # changes) surface it. This guards the rc 1 vs rc 2 distinction that is the
  # whole reason preview-confirm.sh's return code was split: a regression that
  # reorders report_devcontainer_rebuild ahead of the abort check, or collapses
  # rc 1 into rc 2, would leak the advisory after a decline with the suite green.
  set_dockerfile "FROM node:22" "FROM node:20"   # locked leaf drifted
  echo "template readme (new)"  > "$FIXTURE_TEMPLATE/.devcontainer/README.md"
  echo "project readme (stale)" > "$FIXTURE_PROJECT/.devcontainer/README.md"
  run setsid bash -c "
    DEVSHOP_DIR='$FIXTURE_DEVSHOP' \
    bash '$FIXTURE_FROM' < /dev/null 2>&1
  "
  assert_success
  assert_output --partial "Aborted"
  refute_output --partial "Rebuild needed"
  refute_output --partial "No .devcontainer changes"
}
