#!/bin/bash
# preship-router-shim.sh — Dismissal Log helpers for /ak-pre-ship.
#
# Subcommands:
#   is-empty <gate_report_path>
#     Parse the `## Dismissals` section of <gate_report_path>. Exit 0 if the
#     section body is exactly `None` (whitespace-normalized), exit 1 otherwise.
#     Used for the short-circuit that skips adversarial review when there's
#     nothing to review.
#
#   extract <gate_report_path>
#     Print the raw body of the `## Dismissals` section (stdout).
#
#   review <gate_name> <review_md_path>
#     Orchestrate: extract the Dismissals body; if empty, exit 0 (skipped);
#     otherwise invoke adversarial-review.sh dismissalLog. Exit 0 on
#     accepted/skipped, 1 on rejected.
#
#   cso-to-dismissals <cso_json_path>
#     Read a /cso report JSON and emit a rendered `## Dismissals` body for
#     findings that auto-dismiss (TENTATIVE severity). Stdout.
#
#   summary <feature_dir>
#     Aggregate every `## Gate ...` section's Dismissals across
#     <feature_dir>/review.md into a `## Router Summary` table. Stdout.
#
# Scoped parse is mandatory for is-empty / extract: the `## Dismissals` section
# body must be read between its heading and the next `## ` heading, then
# whitespace-normalized. A bare `grep ^None$` can false-positive on other
# report lines.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Extract the body of the `## Dismissals` section from a report file.
# Returns the raw content (with internal whitespace preserved) between the
# `## Dismissals` heading and the next `## ` heading.
extract_dismissals_body() {
  local report="$1"
  [ -f "$report" ] || { echo ""; return 0; }
  awk '
    /^## Dismissals$/     { in_section=1; next }
    in_section && /^## /  { exit }
    in_section            { print }
  ' "$report"
}

# Return 0 if the section body resolves to exactly `None` once all whitespace
# is stripped. Empty files, missing sections, or non-`None` content all
# return 1.
is_empty_dismissals() {
  local report="$1"
  local body
  body=$(extract_dismissals_body "$report")
  local trimmed
  trimmed=$(echo "$body" | tr -d '[:space:]')
  [ "$trimmed" = "None" ]
}

# Run adversarial review on a gate's dismissals. Skip if the section body is
# empty (exit 0). Otherwise hand off to adversarial-review.sh.
review_gate_dismissals() {
  local gate_name="$1"
  local review_md="$2"

  if [ ! -f "$review_md" ]; then
    echo "✗ review.md not found: $review_md" >&2
    return 1
  fi

  if is_empty_dismissals "$review_md"; then
    echo "✓ $gate_name dismissals: None (scoped parse) — adversarial review skipped"
    return 0
  fi

  local body
  body=$(extract_dismissals_body "$review_md")

  # Hand off. adversarial-review.sh respects DEVSHOP_SKIP_ADVERSARIAL +
  # PRESHIP_ADVERSARIAL_TIMEOUT; we don't need to re-check them here.
  bash "$SCRIPT_DIR/adversarial-review.sh" dismissalLog "$body" "$gate_name" "$review_md"
}

# Convert /cso JSON findings to a rendered Dismissals section body.
# Maps TENTATIVE-severity findings to auto-dismissals; CRITICAL/HIGH/MEDIUM
# stay as regular findings (not dismissed).
cso_json_to_dismissals() {
  local cso_json="$1"
  [ -f "$cso_json" ] || { echo "None"; return 0; }

  # jq extracts TENTATIVE-severity items, emits a bullet per finding.
  local bullets
  bullets=$(jq -r '
    .findings[]?
    | select(.severity == "TENTATIVE")
    | "- " + (.category // "uncategorized") + ": " + (.title // .description // "finding")
        + " (rationale: TENTATIVE per /cso confidence tier — self-verified only; escalates to finding if independent verification confirms)"
  ' "$cso_json" 2>/dev/null || true)

  if [ -z "$bullets" ]; then
    echo "None"
  else
    echo "$bullets"
  fi
}

# Aggregate every gate's Dismissals section in review.md into a Router Summary
# block. Walks `## Gate N: <name> ...` headings, extracts each gate's
# Dismissals body, classifies (None / listed), and emits a table.
render_router_summary() {
  local feature_dir="$1"
  local review_md="$feature_dir/review.md"

  if [ ! -f "$review_md" ]; then
    echo "(review.md missing — Router Summary unavailable)"
    return 0
  fi

  echo "## Router Summary"
  echo ""
  echo "Audit trail of what each gate surfaced-but-dismissed. Every gate's"
  echo "\`## Dismissals\` section is aggregated here so a reviewer can grep one"
  echo "place to see everything the pipeline considered non-actionable."
  echo ""
  echo "| Gate | Dismissals | Adversarial review |"
  echo "|------|------------|--------------------|"

  # Walk each Gate section and its nested Dismissals.
  awk '
    /^## Gate [0-9]+[: ]/ {
      # Extract gate display string (after "## ")
      sub(/^## /, "", $0)
      gate_label=$0
      in_gate=1
      in_dis=0
      dis_body=""
      next
    }
    in_gate && /^## Dismissals$/ { in_dis=1; next }
    in_dis && /^## / {
      # End of Dismissals section
      # Classify + print
      gsub(/[[:space:]]+/, "", dis_body)
      if (dis_body == "None" || dis_body == "") {
        print "| " gate_label " | None | skipped (scoped parse = None) |"
      } else {
        # Count bullets (rough)
        n = split(raw_body, arr, "\n")
        bullet_count = 0
        for (i in arr) if (arr[i] ~ /^- /) bullet_count++
        if (bullet_count == 0) bullet_count = 1
        print "| " gate_label " | " bullet_count " item(s) dismissed | see gate section |"
      }
      in_dis=0
      dis_body=""
      raw_body=""
      # fall through so the current `##` can start a new gate section if applicable
      if ($0 ~ /^## Gate [0-9]+[: ]/) {
        sub(/^## /, "", $0)
        gate_label=$0
        in_gate=1
      } else {
        in_gate=0
      }
      next
    }
    in_dis {
      dis_body = dis_body $0
      raw_body = raw_body $0 "\n"
    }
  ' "$review_md"
}

# --- CLI dispatch ---

CMD="${1:-}"
shift || true

case "$CMD" in
  is-empty)
    [ $# -ge 1 ] || { echo "usage: $0 is-empty <gate_report_path>" >&2; exit 2; }
    if is_empty_dismissals "$1"; then exit 0; else exit 1; fi
    ;;
  extract)
    [ $# -ge 1 ] || { echo "usage: $0 extract <gate_report_path>" >&2; exit 2; }
    extract_dismissals_body "$1"
    ;;
  review)
    [ $# -ge 2 ] || { echo "usage: $0 review <gate_name> <review_md_path>" >&2; exit 2; }
    review_gate_dismissals "$1" "$2"
    ;;
  cso-to-dismissals)
    [ $# -ge 1 ] || { echo "usage: $0 cso-to-dismissals <cso_json_path>" >&2; exit 2; }
    cso_json_to_dismissals "$1"
    ;;
  summary)
    [ $# -ge 1 ] || { echo "usage: $0 summary <feature_dir>" >&2; exit 2; }
    render_router_summary "$1"
    ;;
  ""|-h|--help)
    sed -n '2,30p' "$0"
    ;;
  *)
    echo "unknown subcommand: $CMD" >&2
    echo "try: $0 --help" >&2
    exit 2
    ;;
esac
