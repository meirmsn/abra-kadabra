#!/usr/bin/env bash
# Places impeccable's design detector engine where gstack's design review finds it
# (specs/design-detector-in-bootstrap.md). Run by install/bootstrap.sh in every cloud environment and
# by CI's slow job; in a session from before this change, once by hand.
# Usage: install/impeccable.sh <pin file> <home>
#   <pin file>: install/impeccable.pin, "<version> <sha256 of package/bin/impeccable>" (and a
#               "gstack <commit>" line, which the bootstrap test reads, not this script).
#   <home>:     the engine goes to <home>/.impeccable/bin/<version>/impeccable, mode 0755.
# It fetches the npm platform package @impeccable/cli-linux-x64 at that version from
# registry.npmjs.org (the one host; never GitHub, which the cloud network blocks), extracts the one
# member package/bin/impeccable into a fresh temporary directory, checks its sha256 against the pin,
# and only then moves it into place, replacing what was there, and removes every other
# <home>/.impeccable/bin/<semver>/ directory (nothing else under bin/), so gstack's "newest
# version" choice is always the pinned engine. Always fetches: one path, and a wrong file in place is replaced.
# Prints "placed <path>" on success. A pin line that isn't "<version> <sha256>", a failed fetch, a
# tarball without the member or with one that isn't a regular file, a checksum mismatch, or a
# machine that isn't Linux x86_64 places nothing, removes nothing, says why on stderr and exits 1.
# Exit 0 = placed; 1 = not placed (reason on stderr); 2 = bad arguments or an unreadable pin.
set -uo pipefail

REGISTRY=https://registry.npmjs.org/@impeccable/cli-linux-x64/-
PKG=cli-linux-x64

usage() { echo "usage: install/impeccable.sh <pin file> <home>" >&2; exit 2; }
[ $# -eq 2 ] || usage
pin=$1 home=$2
[ -f "$pin" ] && [ -r "$pin" ] || { echo "impeccable: can't read the pin file $pin" >&2; exit 2; }
[ -d "$home" ] || { echo "impeccable: <home> $home is not a directory" >&2; exit 2; }
refuse() { echo "impeccable: $*" >&2; exit 1; }

# The one data line: comments, blank lines and the "gstack <commit>" line are skipped.
line=$(grep -Ev '^(#|gstack |[[:space:]]*$)' "$pin")
read -r version sum extra <<<"$line"
[ "$(wc -l <<<"$line")" = 1 ] && [[ -z ${extra:-} && ${version:-} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && ${sum:-} =~ ^[0-9a-f]{64}$ ]] \
  || refuse "install/impeccable.pin has no single '<version> <sha256>' line (got: ${line:-nothing})"

# The package is built for Linux x86_64; gstack's pins list the other platforms when one is needed.
os=$(uname -s) arch=$(uname -m)
[ "$os" = Linux ] && [ "$arch" = x86_64 ] || refuse "this is $os $arch; the pinned package is for Linux x86_64, nothing placed"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/impeccable.XXXXXX") || refuse "can't make a temporary directory"
trap 'rm -rf "$tmp"' EXIT

url="$REGISTRY/$PKG-$version.tgz"
curl -fsSL -o "$tmp/package.tgz" "$url" 2>"$tmp/curl.err" \
  || refuse "fetch of $url failed: $(tr '\n' ' ' <"$tmp/curl.err")"
# Only the one member, extracted as a plain file (no owner from the archive); a member that isn't a
# regular file (a symlink, a directory) is refused: sha256sum would follow a link.
tar --no-same-owner -xzf "$tmp/package.tgz" -C "$tmp" package/bin/impeccable 2>"$tmp/tar.err" \
  || refuse "the tarball at $url has no package/bin/impeccable: $(tr '\n' ' ' <"$tmp/tar.err")"
bin="$tmp/package/bin/impeccable"
[ -f "$bin" ] && [ ! -L "$bin" ] || refuse "package/bin/impeccable in $url is not a regular file, nothing placed"
got=$(sha256sum "$bin" | cut -d' ' -f1)
[ "$got" = "$sum" ] || refuse "checksum of package/bin/impeccable in $url is $got, the pin says $sum; nothing placed"

# Verified: into place, atomically, then prune the other versions.
dir="$home/.impeccable/bin/$version"
mkdir -p "$dir" || refuse "can't make $dir"
chmod 0755 "$bin" || refuse "can't set the mode on the engine"
mv -f "$bin" "$dir/impeccable" || refuse "can't move the engine into $dir"
for other in "$home/.impeccable/bin"/*/; do
  other=${other%/}
  # Only version directories go, and only real ones (an unmatched glob is the literal pattern).
  [ -d "$other" ] && [[ ${other##*/} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$other" != "$dir" ] || continue
  rm -rf -- "$other"
done
echo "placed $dir/impeccable"
