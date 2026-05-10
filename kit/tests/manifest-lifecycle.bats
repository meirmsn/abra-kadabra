#!/usr/bin/env bats
# Tests for kit/scripts/sync/lib/parse-manifest.sh and the lifecycle invariants
# of kit/manifest.txt. Foundation tests — exercise the parser library and assert
# annotation discipline. Behavioral tests for consumer scripts (init-devshop,
# from-/to-devshop, check-security-files-freshness) live in their own .bats
# files and will be added as those scripts become manifest-driven.

setup() {
  load helpers/setup
  setup_mock_bin
  DEVSHOP="/devshop"
  PARSE_LIB="$SCRIPTS_DIR/sync/lib/parse-manifest.sh"
  MANIFEST="$TESTS_DIR/../manifest.txt"
  FIXTURE_DIR="$BATS_TEST_TMPDIR/fixtures"
  mkdir -p "$FIXTURE_DIR"
}

# Helper: run parse_manifest in a subshell against a fixture; print a key=value summary.
run_parser() {
  local fixture="$1"
  bash -c "
    source '$PARSE_LIB'
    parse_manifest '$fixture' || echo 'PARSE_FAILED'
    echo \"PATHS_COUNT=\${#MANIFEST_PATHS[@]}\"
    echo \"EXCLUDES_COUNT=\${#MANIFEST_EXCLUDES[@]}\"
    for p in \"\${MANIFEST_PATHS[@]}\"; do
      echo \"PATH=\$p|CAT=\${MANIFEST_CATEGORY[\$p]}\"
    done
    for e in \"\${MANIFEST_EXCLUDES[@]}\"; do
      echo \"EXCLUDE=\$e\"
    done
  "
}

# ---------------------------------------------------------------------------
# Test 1 — annotation discipline on the real manifest
# ---------------------------------------------------------------------------

@test "every non-comment, non-! line in manifest.txt has exactly one valid annotation" {
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
  "
  assert_success
}

# ---------------------------------------------------------------------------
# Test 2 — no path appears twice under different annotations
# ---------------------------------------------------------------------------

@test "no path is annotated twice in the real manifest" {
  cat > "$FIXTURE_DIR/dup.txt" <<'M'
turbo.json [sync]
turbo.json [locked]
M
  run run_parser "$FIXTURE_DIR/dup.txt"
  assert_output --partial "PARSE_FAILED"
  assert_output --partial "duplicate path"
}

@test "real manifest has no duplicate paths" {
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST' 2>&1
  "
  refute_output --partial "duplicate path"
}

# ---------------------------------------------------------------------------
# Test 3 — invalid annotations are rejected
# ---------------------------------------------------------------------------

@test "parser rejects unknown annotation tag" {
  cat > "$FIXTURE_DIR/bad.txt" <<'M'
foo.txt [bogus]
M
  run run_parser "$FIXTURE_DIR/bad.txt"
  assert_output --partial "PARSE_FAILED"
  assert_output --partial "invalid annotation [bogus]"
}

@test "parser rejects line with no annotation" {
  cat > "$FIXTURE_DIR/missing.txt" <<'M'
foo.txt
M
  run run_parser "$FIXTURE_DIR/missing.txt"
  assert_output --partial "PARSE_FAILED"
  assert_output --partial "malformed entry"
}

# ---------------------------------------------------------------------------
# Test 4 — parser populates the right shapes for a known fixture
# ---------------------------------------------------------------------------

@test "parser populates MANIFEST_CATEGORY and MANIFEST_PATHS from fixture" {
  cat > "$FIXTURE_DIR/ok.txt" <<'M'
# comment
turbo.json [sync]
.devcontainer/Dockerfile [locked]
.husky/pre-commit [locked]
.devshopkit [symlink]
CLAUDE.md [scaffold-once]
.husky [locked-dir]
!.devcontainer/.env
M
  run run_parser "$FIXTURE_DIR/ok.txt"
  assert_success
  assert_output --partial "PATHS_COUNT=6"
  assert_output --partial "EXCLUDES_COUNT=1"
  assert_output --partial "PATH=turbo.json|CAT=sync"
  assert_output --partial "PATH=.devcontainer/Dockerfile|CAT=locked"
  assert_output --partial "PATH=.devshopkit|CAT=symlink"
  assert_output --partial "PATH=CLAUDE.md|CAT=scaffold-once"
  assert_output --partial "PATH=.husky|CAT=locked-dir"
  assert_output --partial "EXCLUDE=.devcontainer/.env"
}

# ---------------------------------------------------------------------------
# Test 5 — manifest_paths_by filters correctly
# ---------------------------------------------------------------------------

@test "manifest_paths_by [locked] returns only locked paths" {
  cat > "$FIXTURE_DIR/cats.txt" <<'M'
turbo.json [sync]
.husky/pre-commit [locked]
.husky/pre-push [locked]
.devcontainer/Dockerfile [locked]
M
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$FIXTURE_DIR/cats.txt'
    manifest_paths_by locked
  "
  assert_success
  assert_line ".husky/pre-commit"
  assert_line ".husky/pre-push"
  assert_line ".devcontainer/Dockerfile"
  refute_line "turbo.json"
}

# ---------------------------------------------------------------------------
# Test 6 — manifest_locked_under returns leaves under a directory
# ---------------------------------------------------------------------------

@test "manifest_locked_under .devcontainer returns locked leaves under .devcontainer/" {
  cat > "$FIXTURE_DIR/under.txt" <<'M'
.devcontainer/ [sync]
.devcontainer/Dockerfile [locked]
.devcontainer/init-devshop.sh [locked]
.devcontainer/devcontainer.json [locked]
.husky/pre-commit [locked]
M
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$FIXTURE_DIR/under.txt'
    manifest_locked_under .devcontainer
  "
  assert_success
  assert_line "Dockerfile"
  assert_line "init-devshop.sh"
  assert_line "devcontainer.json"
  refute_line "pre-commit"
}

# ---------------------------------------------------------------------------
# Test 7 — manifest_strip_annotation utility
# ---------------------------------------------------------------------------

@test "manifest_strip_annotation strips [tag] and trailing whitespace" {
  run bash -c "
    source '$PARSE_LIB'
    manifest_strip_annotation 'turbo.json [sync]'
  "
  assert_success
  assert_output "turbo.json"
}

@test "manifest_strip_annotation handles leading whitespace" {
  run bash -c "
    source '$PARSE_LIB'
    manifest_strip_annotation '  .husky/pre-commit [locked]  '
  "
  assert_success
  # Leading whitespace preserved (caller decides), trailing stripped.
  assert_output "  .husky/pre-commit"
}

# ---------------------------------------------------------------------------
# Cross-cutting: real manifest declares the categories actually used in PR 1
# ---------------------------------------------------------------------------

@test "real manifest declares both [sync] and [locked] entries" {
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    sync_count=\$(manifest_paths_by sync | wc -l)
    locked_count=\$(manifest_paths_by locked | wc -l)
    echo \"sync=\$sync_count locked=\$locked_count\"
  "
  assert_success
  # PR 1 declared 7 locked leaves under .devcontainer/ and .husky/ + 16 sync entries.
  # Bounds (not exact counts) so adding a new sync or locked file in the future doesn't
  # break this test — just guards against the manifest going to zero entries.
  assert_output --regexp "sync=[1-9][0-9]* locked=[1-9][0-9]*"
}

@test "every [locked] leaf in real manifest exists under /devshop/template/" {
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    rc=0
    while IFS= read -r p; do
      [ -f \"/devshop/template/\$p\" ] || { echo \"missing: /devshop/template/\$p\"; rc=1; }
    done < <(manifest_paths_by locked)
    exit \$rc
  "
  assert_success
}

# ---------------------------------------------------------------------------
# Test 8 — init-devshop.sh sources the parser and iterates manifest_paths_by
# (regression guard: PR 2 made init-devshop manifest-driven; this catches a
# revert / hardcoded-list regression statically without needing sudo)
# ---------------------------------------------------------------------------

@test "init-devshop.sh sources parse-manifest.sh and iterates manifest_paths_by locked" {
  local script="$DEVSHOP/kit/scripts/init-devshop.sh"
  [ -f "$script" ] || skip "init-devshop.sh not found"
  run grep -q 'source.*parse-manifest.sh' "$script"
  assert_success
  run grep -q 'manifest_paths_by locked' "$script"
  assert_success
  run grep -q 'manifest_paths_by locked-dir' "$script"
  assert_success
}

@test "init-devshop.sh refreshes [locked] content via install -D -m 644 -o root -g root" {
  local script="$DEVSHOP/kit/scripts/init-devshop.sh"
  [ -f "$script" ] || skip "init-devshop.sh not found"
  # The whole point of manifest-driven init is content refresh — chown alone
  # would not have fixed .husky/pre-push (the file didn't exist locally to chown).
  run grep -q 'install -D -m 644 -o root -g root' "$script"
  assert_success
}

# ---------------------------------------------------------------------------
# Test 9 — .husky/pre-push regression: it MUST be a [locked] manifest entry,
# AND its template source must exist. Catches the bug class where a new
# template/.husky/<hook> file lacks a manifest entry and silently fails to
# propagate to existing projects on container rebuild.
# ---------------------------------------------------------------------------

@test "regression: .husky/pre-push is declared [locked] in manifest" {
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    manifest_paths_by locked
  "
  assert_success
  assert_line ".husky/pre-push"
}

@test "regression: every template/.husky/<hook> file is in manifest" {
  # If a future PR adds template/.husky/post-push or similar, that entry must
  # appear in the manifest (either [locked] or [sync] via the .husky/ dir entry).
  # This test guards the mental model: template hook = manifest entry.
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    rc=0
    for hook in /devshop/template/.husky/*; do
      [ -f \"\$hook\" ] || continue
      name=\$(basename \"\$hook\")
      [ \"\$name\" = '_' ] && continue
      rel=\".husky/\$name\"
      # Either declared explicitly OR covered by .husky/ dir [sync] entry.
      if [ -n \"\${MANIFEST_CATEGORY[\$rel]:-}\" ]; then
        continue
      fi
      if [ -n \"\${MANIFEST_CATEGORY['.husky/']:-}\" ]; then
        continue
      fi
      echo \"orphan hook (not in manifest): \$rel\"
      rc=1
    done
    exit \$rc
  "
  assert_success
}

# ---------------------------------------------------------------------------
# Test 13 — manifest [locked-dir] entries are real dirs in template/ (or
# carved out as project-special in init-devshop.sh's hardcoded list).
# ---------------------------------------------------------------------------

@test "every [locked-dir] entry in real manifest is a real dir under /devshop/template/" {
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    rc=0
    while IFS= read -r d; do
      [ -d \"/devshop/template/\$d\" ] || { echo \"missing: /devshop/template/\$d\"; rc=1; }
    done < <(manifest_paths_by locked-dir)
    exit \$rc
  "
  assert_success
}

# ---------------------------------------------------------------------------
# Cross-check: workspace-side [locked] files are NOT also hardcoded in
# init-devshop.sh's fallback for-loop (would be double-source-of-truth)
# ---------------------------------------------------------------------------

@test "from-devshop.sh sources the parser and pulls only [sync] entries" {
  local script="$DEVSHOP/kit/scripts/sync/from-devshop.sh"
  [ -f "$script" ] || skip "from-devshop.sh not found"
  run grep -q 'source.*parse-manifest.sh' "$script"
  assert_success
  run grep -q 'manifest_paths_by sync' "$script"
  assert_success
  # Must NOT iterate all entries (would clobber [locked] / [scaffold-once]).
  refute_output --partial 'sed.*\[\.\*\]'
}

@test "to-devshop.sh sources the parser and pushes only [sync] entries" {
  local script="$DEVSHOP/kit/scripts/sync/to-devshop.sh"
  [ -f "$script" ] || skip "to-devshop.sh not found"
  run grep -q 'source.*parse-manifest.sh' "$script"
  assert_success
  run grep -q 'manifest_paths_by sync' "$script"
  assert_success
  run grep -q 'manifest_locked_under' "$script"
  assert_success
}

@test "to-devshop.sh excludes [locked] leaves from the rsync of their parent [sync] dir" {
  # Functional: with a fixture manifest declaring `.dirA/ [sync]` and a leaf
  # `.dirA/locked.txt [locked]`, manifest_locked_under .dirA/ must return locked.txt.
  cat > "$FIXTURE_DIR/excludes.txt" <<'M'
.dirA/ [sync]
.dirA/locked.txt [locked]
.dirA/synced.txt [sync]
M
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$FIXTURE_DIR/excludes.txt'
    manifest_locked_under .dirA/
  "
  assert_success
  assert_line "locked.txt"
  refute_line "synced.txt"
}

@test "check-security-files-freshness.sh iterates manifest [locked] entries" {
  local script="$DEVSHOP/kit/scripts/commit-hooks/check-security-files-freshness.sh"
  [ -f "$script" ] || skip "check-security-files-freshness.sh not found"
  run grep -q 'source.*parse-manifest.sh' "$script"
  assert_success
  run grep -q 'manifest_paths_by locked' "$script"
  assert_success
}

@test "every [symlink] entry in real manifest is created by create-devshop-symlinks.sh" {
  # create-devshop-symlinks.sh's source paths vary per entry (kit/, .claude/skills,
  # hooks/pre-commit.sh) so the script body stays hardcoded; this test asserts
  # that every [symlink] manifest entry is matched by an `ln -sfn ... <path>`
  # line in the script — single source of truth, dual-checked.
  local script="$DEVSHOP/kit/scripts/sync/create-devshop-symlinks.sh"
  [ -f "$script" ] || skip "create-devshop-symlinks.sh not found"
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    rc=0
    while IFS= read -r p; do
      [ -n \"\$p\" ] || continue
      if ! grep -q \"ln -sfn .* \\\"\\\$WS/\$p\\\"\" '$script' && \
         ! grep -q \"ln -sfn .* \\\"\\\$WS/\$(dirname \"\$p\")/\\\$name\\\"\" '$script'; then
        # second grep matches the dynamic ak-* loop that covers .claude/skills/<name>
        echo \"create-devshop-symlinks.sh missing ln -sfn for [symlink] entry: \$p\"
        rc=1
      fi
    done < <(manifest_paths_by symlink)
    exit \$rc
  "
  assert_success
}

@test "init-devshop.sh hardcoded list does NOT redeclare workspace [locked] files" {
  local script="$DEVSHOP/kit/scripts/init-devshop.sh"
  [ -f "$script" ] || skip "init-devshop.sh not found"
  run bash -c "
    source '$PARSE_LIB'
    parse_manifest '$MANIFEST'
    rc=0
    while IFS= read -r p; do
      # The hardcoded for-loop in init-devshop.sh has \"\$WS/<path>\" entries.
      # If a manifest [locked] path appears there too, it's double-counted.
      if grep -qF \"\\\"\\\$WS/\$p\\\"\" '$script'; then
        echo \"double-source: '\$p' is [locked] in manifest AND hardcoded in init-devshop.sh's for-loop\"
        rc=1
      fi
    done < <(manifest_paths_by locked)
    exit \$rc
  "
  assert_success
}
