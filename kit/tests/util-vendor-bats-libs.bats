#!/usr/bin/env bats
# Paired test for kit/scripts/vendor-bats-libs.sh — the re-vendor script that
# replaced `git submodule update --remote` once the bats libs became plain
# checked-in files (de-submodule, 2026-06).
#
# These are cheap STRUCTURAL assertions only — no network re-clone. They pin:
#   - the script exists + is executable
#   - VENDORED-VERSIONS lists all three libs, each with a 40-hex-char SHA
#   - the runtime subset the script targets matches what's checked in on disk
#   - non-runtime dirs (the trim) are actually absent
# The full bats suite (this very runner) is the loud catch that the vendored
# runtime set is complete; here we pin the trim + manifest shape.

setup() {
  load helpers/setup
  SCRIPT="$TESTS_DIR/../scripts/vendor-bats-libs.sh"
  LIB_DIR="$TESTS_DIR/lib"
  MANIFEST="$LIB_DIR/VENDORED-VERSIONS"
}

# === Script presence ===

@test "vendor-bats-libs.sh exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "vendor-bats-libs.sh has the 3-line What/Why/Does NOT header" {
  grep -q '^# What:' "$SCRIPT"
  grep -q '^# Why:' "$SCRIPT"
  grep -q '^# Does NOT:' "$SCRIPT"
}

# === Manifest ===

@test "VENDORED-VERSIONS exists" {
  [ -f "$MANIFEST" ]
}

@test "VENDORED-VERSIONS lists all three libs" {
  grep -q '^bats-core ' "$MANIFEST"
  grep -q '^bats-support ' "$MANIFEST"
  grep -q '^bats-assert ' "$MANIFEST"
}

@test "VENDORED-VERSIONS pins each lib to a 40-hex-char SHA" {
  while IFS=' ' read -r lib sha; do
    [ -n "$lib" ] || continue
    [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || {
      echo "lib $lib has non-40-hex SHA: '$sha'"
      return 1
    }
  done < "$MANIFEST"
}

@test "VENDORED-VERSIONS SHAs match the script's pin table" {
  # Each manifest line's SHA must appear in the script's PINS array, so the
  # committed manifest can't silently drift from the bump mechanism.
  while IFS=' ' read -r lib sha; do
    [ -n "$lib" ] || continue
    grep -q "$lib .*$sha" "$SCRIPT" || {
      echo "manifest $lib@$sha not found in script pin table"
      return 1
    }
  done < "$MANIFEST"
}

# === Runtime subset present (the keep) ===

@test "bats-core runtime subset is present on disk" {
  [ -x "$LIB_DIR/bats-core/bin/bats" ]
  [ -d "$LIB_DIR/bats-core/libexec" ]
  [ -d "$LIB_DIR/bats-core/lib" ]
  [ -f "$LIB_DIR/bats-core/LICENSE.md" ]
}

@test "bats-support runtime subset is present on disk" {
  [ -f "$LIB_DIR/bats-support/load.bash" ]
  [ -d "$LIB_DIR/bats-support/src" ]
  [ -f "$LIB_DIR/bats-support/LICENSE" ]
}

@test "bats-assert runtime subset is present on disk" {
  [ -f "$LIB_DIR/bats-assert/load.bash" ]
  [ -d "$LIB_DIR/bats-assert/src" ]
  [ -f "$LIB_DIR/bats-assert/LICENSE" ]
}

# === Non-runtime dirs absent (the trim) ===

@test "bats-core non-runtime dirs are absent (trim asserted)" {
  [ ! -d "$LIB_DIR/bats-core/test" ]
  [ ! -d "$LIB_DIR/bats-core/docs" ]
  [ ! -d "$LIB_DIR/bats-core/man" ]
  [ ! -d "$LIB_DIR/bats-core/contrib" ]
  [ ! -d "$LIB_DIR/bats-core/docker" ]
}

@test "bats-support + bats-assert non-runtime dirs are absent (trim asserted)" {
  [ ! -d "$LIB_DIR/bats-support/test" ]
  [ ! -d "$LIB_DIR/bats-assert/test" ]
  [ ! -d "$LIB_DIR/bats-assert/docs" ]
}

# === No gitlink / submodule residue ===

@test "no .git pointer files remain under the vendored libs" {
  [ ! -e "$LIB_DIR/bats-core/.git" ]
  [ ! -e "$LIB_DIR/bats-support/.git" ]
  [ ! -e "$LIB_DIR/bats-assert/.git" ]
}
