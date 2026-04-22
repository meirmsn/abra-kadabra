#!/bin/bash
# preship-verify-story.sh — Gate 9 Core-User-Story artifact assertion.
#
# The spec's `## Core user story` section declares 2-4 imperative verbs that
# describe the product's primary flow. This script enforces that the qa-walk
# produced an artifact per verb (screenshot or state JSON), preventing the
# "open+Escape" silent no-op failure mode where /qa reports pass without
# actually completing the core flow.
#
# Subcommands:
#   extract-story <spec_path>
#     Print the body of the `## Core user story` section (scoped awk parse).
#
#   is-na <spec_path>
#     Exit 0 if the Core user story body starts with `N/A` (whitespace-
#     tolerant), exit 1 otherwise. Used to skip artifact assertion for
#     non-user-facing PRs.
#
#   parse-verbs <spec_path>
#     Print one line per verb extracted from the Core user story. Supports
#     both numbered (`1. Sign in.`) and bulleted (`- Sign in.`) lists.
#     Strips leading markers and trailing whitespace.
#
#   verify-all --feature <name> --spec <path>
#     Orchestrate: parse verbs, walk N=1..len, check that an artifact
#     matching `specs/<feature>/qa-walk/verb-<N>-*` exists and is non-empty.
#     Exit 0 on success (all verbs have artifacts OR body is N/A), exit 1
#     with per-verb diagnostics otherwise.

set -euo pipefail

# Extract the body between the `## Core user story` heading and the next
# `## ` heading. Preserves internal whitespace; does NOT trim outer lines.
extract_core_user_story() {
  local spec="$1"
  [ -f "$spec" ] || { echo ""; return 0; }
  awk '
    /^## Core user story$/ { in_section=1; next }
    in_section && /^## /   { exit }
    in_section             { print }
  ' "$spec"
}

# Return 0 if the Core user story body starts with `N/A` (with optional
# trailing context). Examples that match:
#   "N/A"
#   "N/A — database migration only"
#   "  N/A  "  (whitespace-tolerant)
is_na_core_story() {
  local spec="$1"
  local body
  body=$(extract_core_user_story "$spec")
  # Trim leading whitespace, take first non-empty line, lowercase first 3 chars
  local first_line
  first_line=$(echo "$body" | grep -m1 -v '^[[:space:]]*$' | sed -E 's/^[[:space:]]+//')
  [ -z "$first_line" ] && return 1  # empty body — NOT N/A (missing section)
  # Match either "N/A" or "N/A —..." / "N/A -..." / "N/A:" etc.
  echo "$first_line" | grep -qE '^[Nn]/?[Aa]([[:space:]:—-]|$)'
}

# Extract verbs from the Core user story body. Handles:
#   "1. Sign in."   →   "Sign in."
#   "- Sign in."    →   "Sign in."
#   "  2) Add item" →   "Add item"
# Skips blank lines and anything not matching a list item pattern.
parse_verbs() {
  local spec="$1"
  local body
  body=$(extract_core_user_story "$spec")
  [ -z "$body" ] && return 0
  # Regex: optional whitespace, then either "<n>." / "<n>)" / "-" / "*", then whitespace, then the verb
  echo "$body" | sed -nE 's/^[[:space:]]*(([0-9]+[.)]?)|[-*])[[:space:]]+(.+)$/\3/p' \
    | sed -E 's/[[:space:]]+$//'
}

# Check that AT LEAST ONE artifact matches `verb-<N>-*.{png,json}` in the
# feature's qa-walk directory. The slug component is caller-chosen; we only
# enforce the verb-number prefix. Artifact must be non-empty.
check_artifact() {
  local feature_dir="$1"
  local n="$2"
  local walk_dir="$feature_dir/qa-walk"
  if [ ! -d "$walk_dir" ]; then
    echo "no qa-walk dir at $walk_dir"
    return 1
  fi
  local matches
  matches=$(ls "$walk_dir"/verb-"$n"-*.png "$walk_dir"/verb-"$n"-*.json 2>/dev/null || true)
  if [ -z "$matches" ]; then
    echo "no artifact matching $walk_dir/verb-$n-*.{png,json}"
    return 1
  fi
  # At least one match; verify at least one is non-empty
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ -s "$f" ]; then
      return 0  # non-empty artifact found
    fi
  done <<< "$matches"
  echo "artifact(s) for verb-$n exist but all are empty"
  return 1
}

# Orchestrator: parse verbs, check each has a matching artifact. Emits a
# per-verb report on stdout. Exit 0 if all verbs have artifacts (or body
# is N/A); exit 1 with summary of missing artifacts otherwise.
verify_all() {
  local feature="" spec=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --feature) feature="$2"; shift 2 ;;
      --spec)    spec="$2"; shift 2 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac
  done

  [ -n "$feature" ] || { echo "--feature required" >&2; return 2; }
  [ -n "$spec" ]    || { echo "--spec required" >&2; return 2; }

  if [ ! -f "$spec" ]; then
    echo "blocked: spec file missing at $spec"
    return 1
  fi

  # N/A body → skip assertion
  if is_na_core_story "$spec"; then
    echo "Core user story is N/A — artifact assertion skipped for this PR"
    return 0
  fi

  # Section must exist (extract returns empty if missing)
  local body
  body=$(extract_core_user_story "$spec")
  if [ -z "$body" ] || ! echo "$body" | grep -qE '\S'; then
    echo "blocked: spec lacks '## Core user story' section"
    echo "         (required per /ak-spec Step 6; see guide/workflow.md)"
    return 1
  fi

  local verbs
  verbs=$(parse_verbs "$spec")
  if [ -z "$verbs" ]; then
    echo "blocked: '## Core user story' section has no parseable verbs"
    echo "         (expected numbered or bulleted list; see spec template)"
    return 1
  fi

  # Derive feature_dir from spec path (feature dir is parent of spec.md)
  local feature_dir
  feature_dir=$(dirname "$spec")

  local missing=""
  local n=0
  while IFS= read -r verb; do
    [ -z "$verb" ] && continue
    n=$((n + 1))
    local reason
    if reason=$(check_artifact "$feature_dir" "$n" 2>&1); then
      echo "✓ verb $n: \"$verb\" — artifact present"
    else
      echo "✖ verb $n: \"$verb\" — $reason"
      missing+="  verb $n (\"$verb\"): $reason"$'\n'
    fi
  done <<< "$verbs"

  if [ -n "$missing" ]; then
    echo ""
    echo "blocked: Core user story verb(s) not exercised — missing artifact(s):"
    echo "$missing"
    echo "Fix: extend the qa-walk harness to capture each verb's observable outcome."
    echo "     Artifact path: $feature_dir/qa-walk/verb-<N>-<slug>.{png,json}"
    return 1
  fi

  echo ""
  echo "pass: all $n Core user story verb(s) have artifacts"
  return 0
}

# --- CLI dispatch ---

CMD="${1:-}"
shift || true

case "$CMD" in
  extract-story)
    [ $# -ge 1 ] || { echo "usage: $0 extract-story <spec_path>" >&2; exit 2; }
    extract_core_user_story "$1"
    ;;
  is-na)
    [ $# -ge 1 ] || { echo "usage: $0 is-na <spec_path>" >&2; exit 2; }
    if is_na_core_story "$1"; then exit 0; else exit 1; fi
    ;;
  parse-verbs)
    [ $# -ge 1 ] || { echo "usage: $0 parse-verbs <spec_path>" >&2; exit 2; }
    parse_verbs "$1"
    ;;
  verify-all)
    verify_all "$@"
    ;;
  ""|-h|--help)
    sed -n '2,26p' "$0"
    ;;
  *)
    echo "unknown subcommand: $CMD" >&2
    echo "try: $0 --help" >&2
    exit 2
    ;;
esac
