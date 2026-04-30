#!/usr/bin/env bash
# parse-manifest.sh — shared library for parsing kit/manifest.txt with lifecycle annotations.
#
# Each declared workspace path has an inline `[tag]` annotation:
#   turbo.json [sync]
#   .husky/pre-commit [locked]
#
# Annotations:
#   [symlink]       — node-owned symlink, always matches devshop
#   [locked]        — root-owned file copy, refreshed on every container start
#   [locked-dir]    — sticky-bit dir holding locked files
#   [sync]          — manual bidirectional sync via from-/to-devshop.sh
#   [scaffold-once] — copied once at /ak-new-project create time, project owns thereafter
#
# Exclusions (`!path`) carry no annotation.
#
# Public API (call parse_manifest first; subsequent calls populate globals):
#   parse_manifest <path>          → parses; populates MANIFEST_CATEGORY/PATHS/EXCLUDES
#   manifest_paths_by <category>   → prints declared paths matching <category>, one per line
#   manifest_locked_under <dir>    → prints [locked] leaves under <dir> (relative, no prefix)
#   manifest_strip_annotation <s>  → utility: strip [tag] + trailing whitespace from a string

# Valid annotations. Keep in sync with manifest.txt header and architecture.md.
MANIFEST_VALID_CATEGORIES=(symlink locked locked-dir sync scaffold-once)

# parse_manifest <path>
# Populates globals (zero-fills first):
#   MANIFEST_CATEGORY[path] = tag    — assoc array, every declared path
#   MANIFEST_PATHS[]                 — ordered list of declared paths (no exclusions)
#   MANIFEST_EXCLUDES[]              — ordered list of exclusion paths (with leading ! stripped)
# Writes parse errors to stderr; returns 1 if any line failed, else 0.
parse_manifest() {
  local manifest="${1:?usage: parse_manifest <path>}"
  declare -gA MANIFEST_CATEGORY=()
  declare -ga MANIFEST_PATHS=()
  declare -ga MANIFEST_EXCLUDES=()
  local lineno=0 line trimmed path tag rc=0 t valid
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    [[ -z "${line// /}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    trimmed="${line%"${line##*[![:space:]]}"}"
    if [[ "$trimmed" =~ ^! ]]; then
      MANIFEST_EXCLUDES+=("${trimmed#!}")
      continue
    fi
    if [[ "$trimmed" =~ ^([^[:space:]]+)[[:space:]]+\[([a-z-]+)\]$ ]]; then
      path="${BASH_REMATCH[1]}"
      tag="${BASH_REMATCH[2]}"
    else
      echo "parse-manifest: $manifest:$lineno: malformed entry (expected '<path> [tag]'): $line" >&2
      rc=1
      continue
    fi
    valid=0
    for t in "${MANIFEST_VALID_CATEGORIES[@]}"; do
      [ "$t" = "$tag" ] && valid=1 && break
    done
    if [ "$valid" -eq 0 ]; then
      echo "parse-manifest: $manifest:$lineno: invalid annotation [$tag] on '$path' (allowed: ${MANIFEST_VALID_CATEGORIES[*]})" >&2
      rc=1
      continue
    fi
    if [ -n "${MANIFEST_CATEGORY[$path]+x}" ]; then
      echo "parse-manifest: $manifest:$lineno: duplicate path '$path' (already annotated [${MANIFEST_CATEGORY[$path]}])" >&2
      rc=1
      continue
    fi
    MANIFEST_CATEGORY["$path"]="$tag"
    MANIFEST_PATHS+=("$path")
  done < "$manifest"
  return $rc
}

manifest_paths_by() {
  local cat="${1:?usage: manifest_paths_by <category>}"
  local p
  for p in "${MANIFEST_PATHS[@]}"; do
    [ "${MANIFEST_CATEGORY[$p]:-}" = "$cat" ] && printf '%s\n' "$p"
  done
}

manifest_locked_under() {
  local dir="${1:?usage: manifest_locked_under <dir>}"
  local prefix="${dir%/}/"
  local p rel
  for p in "${MANIFEST_PATHS[@]}"; do
    [ "${MANIFEST_CATEGORY[$p]:-}" = "locked" ] || continue
    [[ "$p" == "$prefix"* ]] || continue
    rel="${p#$prefix}"
    printf '%s\n' "$rel"
  done
}

manifest_strip_annotation() {
  local s="${1:-}"
  printf '%s' "$s" | sed 's/\[[^]]*\]//g' | sed 's/[[:space:]]*$//'
}
