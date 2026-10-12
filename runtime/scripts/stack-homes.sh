#!/usr/bin/env bash
# Picks the stack homes a change in a project loads (TARGET § L3 Build 2 and Reach): each stack
# home is a directory <stack>/ under this devshop version's stacks/, with a README.md (the home)
# and a `detect` file listing project-relative paths or globs, one per line (# comments allowed).
# A line may be `<path>: <pattern>`: then the file must also have a line matching the grep -E
# pattern (e.g. `package.json: "next" *:`). A stack applies when any of its lines matches.
# Usage: stack-homes.sh <project root>
# Prints one line `STACKS: <stacks, comma-separated>` (or `STACKS: none`), the record of what was
# loaded, then the README.md of each applying stack, one per line, for Claude to read.
# Exit 0 = done; 2 = can't run: no project, or a stack home that can't be judged (no README.md or
# detect, a detect with no paths, a path that is absolute or leaves the project, or a pattern grep
# can't read). Never skips one.
set -uo pipefail

root=${1:-}
[ -n "$root" ] || { echo "usage: stack-homes.sh <project root>" >&2; exit 2; }
[ -d "$root" ] || { echo "stack-homes: project root '$root' is not a directory" >&2; exit 2; }
stacks="$(cd "$(dirname "$0")/.." && pwd)/stacks"
shopt -s nullglob

found=()
for dir in "$stacks"/*/; do
  dir=${dir%/}
  s=${dir##*/}
  [ -f "$dir/README.md" ] || { echo "stack-homes: $s: no README.md" >&2; exit 2; }
  [ -f "$dir/detect" ] || { echo "stack-homes: $s: no detect file" >&2; exit 2; }
  paths=0 hit=0
  while IFS= read -r p || [ -n "$p" ]; do
    p=${p%%#*}
    p=${p#"${p%%[![:space:]]*}"}
    p=${p%"${p##*[![:space:]]}"}
    [ -n "$p" ] || continue
    pat=
    case "$p" in
      *:*)
        pat=${p#*:} && pat=${pat#"${pat%%[![:space:]]*}"} && p=${p%%:*} && p=${p%"${p##*[![:space:]]}"}
        rc=2
        [ -z "$pat" ] || { grep -Eq -- "$pat" /dev/null 2>/dev/null; rc=$?; }
        [ "$rc" = 1 ] || { echo "stack-homes: $s: detect pattern '$pat' for '$p' is empty or not a grep -E pattern" >&2; exit 2; }
        ;;
    esac
    case "/$p/" in
      //* | */../*) echo "stack-homes: $s: detect path '$p' is absolute or leaves the project" >&2; exit 2 ;;
    esac
    paths=$((paths + 1))
    while IFS= read -r f; do
      if [ -z "$pat" ] || { [ -f "$f" ] && grep -Eq -- "$pat" "$f"; }; then hit=1; fi
    done < <(compgen -G "$root/$p")
  done <"$dir/detect"
  [ "$paths" -gt 0 ] || { echo "stack-homes: $s: detect lists no paths" >&2; exit 2; }
  [ "$hit" = 0 ] || found+=("$s")
done

if [ ${#found[@]} -eq 0 ]; then
  echo "STACKS: none"
  exit 0
fi
(
  IFS=,
  echo "STACKS: ${found[*]}" | sed 's/,/, /g'
)
for s in "${found[@]}"; do echo "$stacks/$s/README.md"; done
