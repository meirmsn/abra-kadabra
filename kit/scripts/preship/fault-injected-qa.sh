#!/usr/bin/env bash
# What: Gate 9 fault-injection sub-step. Detects Tier A2 surfaces in the
#       feature spec (or via heuristic grep), verifies each has a matching
#       Playwright harness, runs the harnesses with page.route().abort()
#       semantics, aggregates outcome.
# Why:  Happy-path /qa misses banner/Undo/Retry regressions under failure
#       (lalista PR #49 — overlay intercepted Undo, shipped past pre-ship,
#       caught only by CI slow-job). Closes the failure-path coverage gap.
# Does NOT: write the Playwright harness for you (recipe in SKILL.md);
#       run when no Tier A2 surfaces are declared (emits scope-exempt
#       `pass` instead — see D3).
#
# Subcommands:
#   detect-surfaces --spec <path> [--root <dir>] [--diff-range <range>]
#     Print one line per detected Tier A2 surface:
#       <slug>\t<source-hint>\t<route-hint>
#     Primary: parse spec's `## Surface mapping` table for `Tier == A2`.
#     Fallback (only when primary returns zero rows): grep diff (or src
#     tree when --diff-range omitted) for `useOptimisticMutation` +
#     `failureMode: 'banner'`. Exit 0 with no output → n/a (no surfaces).
#
#   verify-harness --slugs <s1,s2,...> --root <dir>
#     Exit 0 if every slug has a matching apps/web/e2e/fault-injected/<slug>.spec.ts.
#     Exit non-zero with comma-separated missing slugs on stderr otherwise.
#
#   run --feature <name> --spec <path> [--root <dir>] [--diff-range <range>]
#     Orchestrate: detect → verify → invoke Playwright (when present) →
#     emit final outcome line as the script's LAST stdout line:
#       pass (no Tier A2 surfaces in scope)
#       blocked (missing fault-injected harness: <slug-list>)
#       pass
#       findings (N) — <per-surface detail>
#     Per-surface JSON output (when invoked) lands at
#       specs/<feature>/gates/fault-injected-<slug>.json
#
# Env overrides:
#   PLAYWRIGHT_BIN   override `pnpm exec playwright` (bats sets a stub).
#   FAULT_QA_DEBUG   set to print detection diagnostics to stderr.
#
# Spec: specs/fault-injected-qa-gate/spec.md.

set -euo pipefail

log() {
  [ -n "${FAULT_QA_DEBUG:-}" ] && echo "[fault-injected-qa] $*" >&2
  return 0
}

die() {
  echo "[fault-injected-qa] error: $*" >&2
  exit 2
}

# --- detect-surfaces ---

# Extract Tier A2 rows from a `## Surface mapping` or `### Surface mapping`
# table in the spec. The table format (per latency-feedback.md):
#   | Surface | Tier | Notes |
#   |---------|------|-------|
#   | <name>  | A2   | useOptimisticMutation({ failureMode: 'banner' }) [route:/api/x] |
#
# Output per match (tab-separated): <slug>\t<notes-text>\troute-hint
# Slug = lowercase first column, non-alphanumerics → `-`, trimmed.
# Route hint = content of `[route:...]` annotation if present, else empty.
parse_spec_surface_mapping() {
  local spec="$1"
  [ -f "$spec" ] || return 0
  # Scope: between the first `## Surface mapping` or `### Surface mapping`
  # heading and the next heading of equal-or-greater depth.
  awk '
    /^#{2,3} Surface mapping[[:space:]]*$/ {
      in_section = 1
      section_depth = match($0, /#{2,3}/) ? RLENGTH : 0
      next
    }
    in_section && /^#{1,6} / {
      this_depth = match($0, /#{1,6}/) ? RLENGTH : 99
      if (this_depth <= section_depth) { in_section = 0 }
    }
    in_section { print }
  ' "$spec" | awk -F'|' '
    # Skip header (Surface) and divider (---) rows; require ≥4 pipe fields.
    NF < 4 { next }
    $2 ~ /Surface/ { next }
    $2 ~ /^[[:space:]]*-+[[:space:]]*$/ { next }
    {
      surface = $2; tier = $3; notes = $4
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", surface)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", tier)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", notes)
      if (tier == "A2") {
        # camelCase / PascalCase split: walk chars, insert dash between
        # lowercase/digit and uppercase. awk has no backreferences in
        # gsub replacements, so a manual walk is the simplest path.
        out = ""; prev = ""
        for (i = 1; i <= length(surface); i++) {
          c = substr(surface, i, 1)
          if (c ~ /[A-Z]/ && prev ~ /[a-z0-9]/) out = out "-" c
          else out = out c
          prev = c
        }
        slug = tolower(out)
        gsub(/[^a-z0-9]+/, "-", slug)
        gsub(/^-+|-+$/, "", slug)
        route = ""
        if (match(notes, /\[route:[^]]+\]/)) {
          route = substr(notes, RSTART + 7, RLENGTH - 8)
        }
        printf "%s\t%s\t%s\n", slug, notes, route
      }
    }
  '
}

# Heuristic fallback: grep for useOptimisticMutation with failureMode:'banner'.
# Looks across the diff range (when given) or the project src tree.
# Emits one line per call-site: <slug>\t<filepath>\t<route-hint-from-filename>
#
# Slug derivation: filename basename minus extension; e.g., AddItemSheet.tsx
# → add-item-sheet. The route hint defaults to empty (we don't try to
# infer endpoints from the call body — too brittle for v0).
grep_useoptimistic_callsites() {
  local root="$1" diff_range="${2:-}"
  local files=()
  if [ -n "$diff_range" ]; then
    # Only TS/TSX files in the diff range.
    while IFS= read -r f; do
      [ -n "$f" ] && [ -f "$root/$f" ] && files+=("$root/$f")
    done < <(git -C "$root" diff --name-only --diff-filter=AM "$diff_range" -- '*.ts' '*.tsx' 2>/dev/null || true)
  else
    # Full tree scan — bounded to apps/ and packages/ to avoid sweeping node_modules.
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$root/apps" "$root/packages" -type f \( -name '*.ts' -o -name '*.tsx' \) -print0 2>/dev/null || true)
  fi
  [ ${#files[@]} -eq 0 ] && return 0
  # Match call sites where useOptimisticMutation appears within ~10 lines
  # of failureMode: 'banner' or failureMode: "banner".
  local f
  for f in "${files[@]}"; do
    # Quick prefilter: must contain both tokens at all.
    grep -q 'useOptimisticMutation' "$f" 2>/dev/null || continue
    grep -qE "failureMode:[[:space:]]*['\"]banner['\"]" "$f" 2>/dev/null || continue
    # Confirm proximity: failureMode:'banner' within 10 lines of useOptimisticMutation.
    if awk '
      /useOptimisticMutation/ { hot = NR }
      hot && NR - hot <= 10 && /failureMode:[[:space:]]*['"'"'"]banner['"'"'"]/ { found = 1; exit }
      END { exit !found }
    ' "$f"; then
      local base slug
      base=$(basename "$f")
      slug="${base%.*}"
      # camelCase / PascalCase → kebab-case.
      slug=$(echo "$slug" | sed -E 's/([a-z0-9])([A-Z])/\1-\2/g' | tr '[:upper:]' '[:lower:]')
      slug=$(echo "$slug" | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
      [ -z "$slug" ] && continue
      printf "%s\t%s\t\n" "$slug" "${f#$root/}"
    fi
  done
}

cmd_detect_surfaces() {
  local spec="" root="" diff_range=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --spec) spec="$2"; shift 2 ;;
      --root) root="$2"; shift 2 ;;
      --diff-range) diff_range="$2"; shift 2 ;;
      *) die "detect-surfaces: unknown arg $1" ;;
    esac
  done
  [ -n "$spec" ] || die "detect-surfaces: --spec is required"
  [ -n "$root" ] || root=$(pwd)
  log "detect-surfaces spec=$spec root=$root diff-range=${diff_range:-<none>}"

  local primary
  primary=$(parse_spec_surface_mapping "$spec")
  if [ -n "$primary" ]; then
    log "primary detection hit ($(echo "$primary" | wc -l | tr -d ' ') rows)"
    printf '%s\n' "$primary"
    return 0
  fi

  log "primary detection empty — falling back to grep"
  grep_useoptimistic_callsites "$root" "$diff_range"
}

# --- verify-harness ---

cmd_verify_harness() {
  local slugs_csv="" root=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --slugs) slugs_csv="$2"; shift 2 ;;
      --root) root="$2"; shift 2 ;;
      *) die "verify-harness: unknown arg $1" ;;
    esac
  done
  [ -n "$slugs_csv" ] || die "verify-harness: --slugs is required"
  [ -n "$root" ] || root=$(pwd)

  local IFS=','
  read -ra slugs <<<"$slugs_csv"
  local missing=()
  local slug
  for slug in "${slugs[@]}"; do
    slug=$(echo "$slug" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [ -z "$slug" ] && continue
    local harness="$root/apps/web/e2e/fault-injected/${slug}.spec.ts"
    if [ ! -f "$harness" ]; then
      missing+=("$slug")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    local csv
    csv=$(IFS=,; echo "${missing[*]}")
    echo "$csv" >&2
    return 1
  fi
  return 0
}

# --- run ---

cmd_run() {
  local feature="" spec="" root="" diff_range=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --feature) feature="$2"; shift 2 ;;
      --spec) spec="$2"; shift 2 ;;
      --root) root="$2"; shift 2 ;;
      --diff-range) diff_range="$2"; shift 2 ;;
      *) die "run: unknown arg $1" ;;
    esac
  done
  [ -n "$feature" ] || die "run: --feature is required"
  [ -n "$spec" ] || die "run: --spec is required"
  [ -n "$root" ] || root=$(pwd)

  # Detect.
  local detected
  detected=$(cmd_detect_surfaces --spec "$spec" --root "$root" ${diff_range:+--diff-range "$diff_range"})
  if [ -z "$detected" ]; then
    echo "pass (no Tier A2 surfaces in scope)"
    return 0
  fi

  # Collect slugs.
  local slugs=()
  while IFS=$'\t' read -r slug _notes _route; do
    [ -n "$slug" ] && slugs+=("$slug")
  done <<<"$detected"

  local slugs_csv
  slugs_csv=$(IFS=,; echo "${slugs[*]}")

  # Verify harness presence.
  local missing
  if ! missing=$(cmd_verify_harness --slugs "$slugs_csv" --root "$root" 2>&1); then
    echo "blocked (missing fault-injected harness: $missing)"
    return 0
  fi

  # Run Playwright per surface.
  local pw="${PLAYWRIGHT_BIN:-pnpm exec playwright}"
  local gates_dir="$root/specs/$feature/gates"
  mkdir -p "$gates_dir"

  local fail_count=0
  local fail_detail=()
  local slug
  for slug in "${slugs[@]}"; do
    local harness="apps/web/e2e/fault-injected/${slug}.spec.ts"
    local out="$gates_dir/fault-injected-${slug}.json"
    log "running $harness → $out"
    if ! $pw test "$harness" --reporter=json >"$out" 2>&1; then
      fail_count=$((fail_count + 1))
      fail_detail+=("$slug")
    fi
  done

  if [ "$fail_count" -gt 0 ]; then
    local detail
    detail=$(IFS=', '; echo "${fail_detail[*]}")
    echo "findings ($fail_count) — failed: $detail"
    return 0
  fi
  echo "pass"
}

# --- dispatch ---

main() {
  local sub="${1:-}"
  case "$sub" in
    detect-surfaces) shift; cmd_detect_surfaces "$@" ;;
    verify-harness)  shift; cmd_verify_harness "$@" ;;
    run)             shift; cmd_run "$@" ;;
    "" | -h | --help)
      cat <<'USAGE'
fault-injected-qa.sh — Gate 9 fault-injection sub-step

Subcommands:
  detect-surfaces --spec <path> [--root <dir>] [--diff-range <range>]
  verify-harness  --slugs <csv> --root <dir>
  run             --feature <name> --spec <path> [--root <dir>] [--diff-range <range>]

See header comment for full contract.
USAGE
      ;;
    *) die "unknown subcommand: $sub" ;;
  esac
}

main "$@"
