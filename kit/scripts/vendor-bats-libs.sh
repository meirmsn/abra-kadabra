#!/usr/bin/env bash
# What: Re-vendor the three bats test libraries (bats-core, bats-support,
#       bats-assert) into kit/tests/lib/<lib>/ as plain checked-in files,
#       pinned to the SHAs in the `pin` table below. Clones each lib at its
#       pinned SHA into a temp dir, copies only the runtime subset into place,
#       strips any .git metadata, writes kit/tests/lib/VENDORED-VERSIONS, then
#       self-verifies by running the full bats suite against the freshly-placed
#       files.
# Why:  The bats libs used to be git submodules; `git submodule update --remote`
#       was the upstream-bump mechanism, but the submodule machinery
#       intermittently corrupted the shared /devshop/.git/config. The libs are
#       now plain files (no submodules), so this script replaces
#       `git submodule update` as the reproducible, audited bump path. The
#       pinned-SHA table here + the emitted VENDORED-VERSIONS manifest are the
#       audit trail for what version is vendored.
# Does NOT: bump to newer upstream on its own (edit the `pin` table to bump),
#           touch any tree other than kit/tests/lib/<lib>, run network installs
#           beyond the per-lib clone, or modify .git config (there are no
#           submodules left to configure).
#
# Usage:
#   bash kit/scripts/vendor-bats-libs.sh
#
# To bump a lib: edit its SHA in the `pin` table below, re-run, commit the
# resulting kit/tests/lib/ delta + the updated VENDORED-VERSIONS.

set -euo pipefail

# --- pin table: <lib> <repo-url> <sha> -------------------------------------
# Currently-vendored SHAs (matches the pre-de-submodule gitlinks).
PINS=(
  "bats-core https://github.com/bats-core/bats-core.git d9faff0d7bc32e7adebc6552446f978118d3ab3b"
  "bats-support https://github.com/bats-core/bats-support.git 0954abb9925cad550424cebca2b99255d4eabe96"
  "bats-assert https://github.com/bats-core/bats-assert.git 697471b7a89d3ab38571f38c6c7c4b460d1f5e35"
)

# --- runtime subset per lib (space-separated paths relative to the clone) ----
# These are the only paths the bats harness loads at runtime; everything else
# (test/ docs/ man/ contrib/ docker/ build scaffolding) is dropped to keep the
# vendored tree minimal and free of third-party noise / gitleaks false positives.
runtime_subset() {
  case "$1" in
    bats-core) echo "bin libexec lib LICENSE.md" ;;
    bats-support) echo "load.bash src LICENSE" ;;
    bats-assert) echo "load.bash src LICENSE" ;;
    *) echo "" ;;
  esac
}

# Resolve repo root (this script lives at kit/scripts/, so root is two up).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LIB_DIR="$REPO_ROOT/kit/tests/lib"
MANIFEST="$LIB_DIR/VENDORED-VERSIONS"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "Re-vendoring bats libs into $LIB_DIR"

# Fresh manifest (rewritten each run from the pin table).
: > "$MANIFEST"

for entry in "${PINS[@]}"; do
  # shellcheck disable=SC2086
  set -- $entry
  lib="$1"
  url="$2"
  sha="$3"
  subset="$(runtime_subset "$lib")"

  if [ -z "$subset" ]; then
    echo "ERROR: no runtime subset declared for $lib" >&2
    exit 1
  fi

  echo "  $lib @ $sha"
  clone="$TMP_ROOT/$lib"
  git clone --quiet "$url" "$clone"
  git -C "$clone" checkout --quiet "$sha"

  # Strip the clone's .git so no submodule/gitlink metadata can leak in.
  rm -rf "$clone/.git"

  dest="$LIB_DIR/$lib"
  # Replace the destination's contents with the runtime subset only.
  rm -rf "$dest"
  mkdir -p "$dest"
  for path in $subset; do
    if [ ! -e "$clone/$path" ]; then
      echo "ERROR: $lib runtime path '$path' missing from upstream clone" >&2
      exit 1
    fi
    # -a preserves executable bits (bin/bats + libexec scripts).
    cp -a "$clone/$path" "$dest/"
  done

  echo "$lib $sha" >> "$MANIFEST"
done

echo "Wrote manifest: $MANIFEST"

# --- self-verify: run the full bats suite against the freshly-vendored files --
echo "Self-verifying: running full bats suite against vendored files..."
"$LIB_DIR/bats-core/bin/bats" "$REPO_ROOT/kit/tests/"

echo "vendor-bats-libs.sh: done — suite green against vendored files."
