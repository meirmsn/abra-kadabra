#!/bin/bash
# preship-design-conformance.sh — Gate `design-conformance` implementation.
#
# Extracts normative claims from DESIGN.md, verifies each against the
# implementation, emits findings with severity weighted by claim strength.
# See /devshop/.claude/skills/devshop/design-conformance/SKILL.md for the
# contract; this script is the mechanics so bats can test it without an LLM.
#
# Subcommands:
#   extract-claims --design <path> --out <claims.json>
#     LLM-extract normative claims (explicit values, canonical examples,
#     imperative rules, component contracts) from DESIGN.md. Caches by
#     sha256(DESIGN.md) — re-extracts only when DESIGN.md changes.
#
#   verify-claims --claims <claims.json> --out <report.md> [--root <path>]
#     Per-claim verification: explicit_value → grep for the value; other
#     types → flag for human review. Emits a markdown report with per-claim
#     ✓/✖ + aggregated findings.
#
#   run --feature <name> --design <path> [--root <path>]
#     Orchestrate: extract-claims → verify-claims → write report to
#     specs/<feature>/design-conformance-report.md. Emits the `## Dismissals`
#     section with body `None` by default (Phase 3 compliance — findings
#     become pending items, not dismissals, unless the skill explicitly
#     chooses to dismiss).
#
# Env overrides:
#   CLAUDE_CLI          override path to `claude` binary (default: claude in PATH).
#                       Bats tests set this to a mock that emits canned JSON.
#   DESIGN_CLAIMS_MAX   max claims to extract per run (default 50, guards against runaway).
#
# DEVSHOP_SKIP_ADVERSARIAL=1 is honored by the dismissalLog adversarial
# review that fires on the emitted report's Dismissals section — see
# pre-ship SKILL.md § Dismissal Log.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE="${CLAUDE_CLI:-claude}"
MAX_CLAIMS="${DESIGN_CLAIMS_MAX:-50}"

# --- extraction prompt preamble (strict, rejects aspirational prose) ---
# Followed at runtime by a code-fenced literal DESIGN.md body (no interpolation
# into the preamble — shell substitution on multi-line markdown breaks on
# table pipes, backticks, and heredoc edge cases). Composed in write_prompt().
_build_prompt_preamble() {
  local max="$1"
  cat <<PROMPT
You are extracting NORMATIVE claims from a DESIGN.md file. A normative claim
is one a reviewer could objectively say was violated — NOT aspirational
language.

ACCEPT ONLY these claim types:
  explicit_value     — exact values: hex colors, pixel sizes, durations, line-heights,
                       radii, named tokens. E.g. "background is #FDFAF6", "min touch 44px".
  canonical_example  — literal text the doc specifies as archetypal. E.g. a voice
                       example with scare quotes: "say leche. it handles the rest."
                       The doc usually names these (e.g. "### Canonical examples" / "voice
                       example:" / "canonical voice:"). Extract the quoted text + its context.
  imperative_rule    — sentences using "must" / "should" / "always" / "never" that
                       make a concrete claim about code / UI / copy.
  component_contract — declarations about specific components: "Button min-h 44px",
                       "Input auto-focus on mount", etc.

REJECT:
  - Aspirational adjectives ("feels confident", "sparks delight", "warm")
  - Vague guidance without a specific action ("make it clean")
  - Brand positioning / market analysis
  - Section headers / intros

Return a JSON array. Each item: {
  "id": "claim-<N>",
  "type": "explicit_value" | "canonical_example" | "imperative_rule" | "component_contract",
  "description": "<human-readable one-line claim>",
  "evidence": "<verbatim excerpt from DESIGN.md that establishes this claim>",
  "search": "<the specific thing to look for in the implementation — a value, a string, a class name, an attribute>",
  "severity": "high" | "medium" | "low"
}

Severity guidance:
  high    — explicit_value miss, canonical_example contradiction, imperative_rule violation
  medium  — component_contract non-conformance
  low     — inferred / ambiguous claim (reviewer may promote or dismiss)

Cap at ${max} claims. Emit ONLY the JSON array, no prose.

DESIGN.md follows between the fences:
PROMPT
}

# --- helpers ---

# Compute sha256 of a file; empty string on failure.
_sha() {
  local f="$1"
  [ -f "$f" ] || { echo ""; return 0; }
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    shasum -a 256 "$f" | awk '{print $1}'
  fi
}

# Whether the claims cache is fresh for this DESIGN.md.
_cache_fresh() {
  local design="$1" out="$2"
  local sha_file="${out}.sha256"
  [ -f "$out" ] || return 1
  [ -f "$sha_file" ] || return 1
  local current cached
  current=$(_sha "$design")
  cached=$(cat "$sha_file" 2>/dev/null || echo "")
  [ -n "$current" ] && [ "$current" = "$cached" ]
}

# extract-claims: LLM → JSON array → file + sha256 cache
extract_claims() {
  local design="" out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --design) design="$2"; shift 2 ;;
      --out)    out="$2";    shift 2 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac
  done
  [ -n "$design" ] || { echo "--design required" >&2; return 2; }
  [ -n "$out" ]    || { echo "--out required"    >&2; return 2; }

  if [ ! -f "$design" ]; then
    echo "DESIGN.md not found at $design — emitting empty claims" >&2
    echo "[]" > "$out"
    _sha "$design" > "${out}.sha256"
    return 0
  fi

  if _cache_fresh "$design" "$out"; then
    echo "claims cache fresh (sha matches) — reusing $out"
    return 0
  fi

  # Compose the prompt: literal preamble + literal DESIGN.md body (no shell
  # substitution into markdown — pipes in tables and backticks in code fences
  # break sed's s|...| syntax). Write the preamble, open a code fence, append
  # DESIGN.md verbatim via cat, close the fence.
  local prompt_file
  prompt_file=$(mktemp)
  {
    _build_prompt_preamble "$MAX_CLAIMS"
    echo '```'
    cat "$design"
    echo '```'
  } > "$prompt_file"

  mkdir -p "$(dirname "$out")"

  # Call the LLM. The mock CLAUDE_CLI used by bats tests emits canned JSON.
  # Expect the output to be a JSON array; reject non-JSON.
  local raw
  raw=$(timeout 120 "$CLAUDE" -p --model sonnet < "$prompt_file" 2>/dev/null || true)
  rm -f "$prompt_file"

  # Strip common markdown fences that LLMs sometimes add around JSON.
  local cleaned
  cleaned=$(echo "$raw" | sed -E '/^```(json)?$/d; /^```$/d')

  if ! echo "$cleaned" | jq 'type == "array"' >/dev/null 2>&1; then
    echo "extraction did not return a JSON array — aborting" >&2
    echo "raw output (first 200 chars): ${raw:0:200}" >&2
    return 1
  fi

  echo "$cleaned" | jq '.' > "$out"
  _sha "$design" > "${out}.sha256"
  local count
  count=$(jq 'length' "$out")
  echo "extracted $count claims to $out (cached by sha256)"
}

# verify-claims: iterate claims, apply per-type strategy, emit report.
verify_claims() {
  local claims="" out="" root="${PWD}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --claims) claims="$2"; shift 2 ;;
      --out)    out="$2";    shift 2 ;;
      --root)   root="$2";   shift 2 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac
  done
  [ -n "$claims" ] || { echo "--claims required" >&2; return 2; }
  [ -n "$out" ]    || { echo "--out required"    >&2; return 2; }

  if [ ! -f "$claims" ]; then
    echo "claims file not found: $claims" >&2
    return 1
  fi

  mkdir -p "$(dirname "$out")"

  # Start the report
  {
    echo "## Gate design-conformance"
    echo ""
    echo "DESIGN.md contract verification. Every claim was checked against"
    echo "the implementation; \`findings\` below need human resolution unless"
    echo "tagged as \`(fixed inline)\`."
    echo ""
  } > "$out"

  local total pass_count fail_count
  total=$(jq 'length' "$claims")

  if [ "$total" = "0" ]; then
    {
      echo "### Outcome"
      echo ""
      echo "\`n/a\` — no normative claims extracted from DESIGN.md (may be"
      echo "absent or contain only aspirational prose)."
      echo ""
      echo "## Dismissals"
      echo ""
      echo "None"
    } >> "$out"
    echo "verified 0 claims → n/a"
    return 0
  fi

  pass_count=0; fail_count=0
  local findings_body=""
  local i
  for ((i=0; i<total; i++)); do
    local claim_type search description severity id
    claim_type=$(jq -r ".[$i].type" "$claims")
    search=$(jq -r ".[$i].search" "$claims")
    description=$(jq -r ".[$i].description" "$claims")
    severity=$(jq -r ".[$i].severity // \"medium\"" "$claims")
    id=$(jq -r ".[$i].id // \"claim-$i\"" "$claims")

    local verdict="" detail=""

    case "$claim_type" in
      explicit_value)
        # Grep for the exact search term across typical source roots.
        if _grep_hit "$root" "$search"; then
          verdict="pass"
          detail="found in source"
        else
          verdict="fail"
          detail="search term '$search' not found in source roots (apps/, packages/, supabase/, app/, components/)"
        fi
        ;;
      canonical_example|imperative_rule|component_contract)
        # These need LLM judgment against the PR diff. MVP: surface as
        # finding-pending so the reviewer can act. A future enhancement
        # wires the LLM judge; the scaffolding below is ready.
        verdict="needs_review"
        detail="requires human/LLM judgment against the implementation (MVP surfaces as pending)"
        ;;
      *)
        verdict="unknown_type"
        detail="unrecognized claim type '$claim_type' — skipping"
        ;;
    esac

    if [ "$verdict" = "pass" ]; then
      pass_count=$((pass_count + 1))
      echo "- ✓ **[$id $severity $claim_type]** $description — $detail" >> "$out"
    else
      fail_count=$((fail_count + 1))
      findings_body+="- ✖ [$id severity=$severity type=$claim_type] $description — $detail"$'\n'
      findings_body+="  - search: \`$search\`"$'\n'
    fi
  done

  {
    echo ""
    echo "### Findings"
    echo ""
    if [ -z "$findings_body" ]; then
      echo "None."
    else
      echo "$findings_body"
    fi
    echo ""
    echo "### Summary"
    echo ""
    echo "- Claims verified: $total"
    echo "- Passed: $pass_count"
    echo "- Needs resolution: $fail_count"
    echo ""
    echo "### Outcome"
    echo ""
    if [ "$fail_count" -eq 0 ]; then
      echo "\`pass\` — all $total claims honored by implementation."
    else
      echo "\`findings ($fail_count) pending\` — claims above need human review or code changes."
    fi
    echo ""
    echo "## Dismissals"
    echo ""
    echo "None"
  } >> "$out"

  echo "verified $total claims: $pass_count pass, $fail_count need resolution → wrote $out"
}

# Grep helper: return 0 if search term found in typical source roots.
# Honors \`--root\` — scoped to the project repo, not the filesystem.
_grep_hit() {
  local root="$1" term="$2"
  [ -d "$root" ] || return 1
  local roots=()
  for d in apps packages supabase app components src; do
    [ -d "$root/$d" ] && roots+=("$root/$d")
  done
  # Root-level files (page.tsx, layout.tsx, etc.) are common too
  local include_root=false
  if ls "$root"/*.{ts,tsx,js,jsx,css,html} >/dev/null 2>&1; then
    include_root=true
  fi
  [ ${#roots[@]} -eq 0 ] && [ "$include_root" = false ] && return 1

  # Use plain grep -r; avoid fancy flags for cross-platform safety.
  if [ ${#roots[@]} -gt 0 ]; then
    if grep -rq --include='*.ts' --include='*.tsx' --include='*.js' \
        --include='*.jsx' --include='*.css' --include='*.html' --include='*.mjs' \
        -F -- "$term" "${roots[@]}" 2>/dev/null; then
      return 0
    fi
  fi
  if [ "$include_root" = true ]; then
    if grep -lF -- "$term" "$root"/*.{ts,tsx,js,jsx,css,html,mjs} 2>/dev/null | head -1 | grep -q .; then
      return 0
    fi
  fi
  return 1
}

# run: orchestrator for a feature — extract + verify + write the report at
# specs/<feature>/design-conformance-report.md.
run_all() {
  local feature="" design="DESIGN.md" root="${PWD}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --feature) feature="$2"; shift 2 ;;
      --design)  design="$2";  shift 2 ;;
      --root)    root="$2";    shift 2 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac
  done
  [ -n "$feature" ] || { echo "--feature required" >&2; return 2; }

  # DESIGN.md absent → n/a, emit a minimal report + Dismissals: None.
  local feature_dir="$root/specs/$feature"
  mkdir -p "$feature_dir"
  local report="$feature_dir/design-conformance-report.md"
  if [ ! -f "$root/$design" ] && [ ! -f "$design" ]; then
    {
      echo "## Gate design-conformance"
      echo ""
      echo "\`n/a\` — no DESIGN.md at project root."
      echo ""
      echo "## Dismissals"
      echo ""
      echo "None"
    } > "$report"
    echo "n/a: no DESIGN.md found → $report"
    return 0
  fi

  local design_path="$design"
  [ -f "$root/$design" ] && design_path="$root/$design"

  local claims="$feature_dir/design-claims.json"
  extract_claims --design "$design_path" --out "$claims" || return 1
  verify_claims --claims "$claims" --out "$report" --root "$root" || return 1
}

# --- CLI dispatch ---

CMD="${1:-}"
shift || true

case "$CMD" in
  extract-claims) extract_claims "$@" ;;
  verify-claims)  verify_claims "$@" ;;
  run)            run_all "$@" ;;
  ""|-h|--help)
    sed -n '2,35p' "$0"
    ;;
  *)
    echo "unknown subcommand: $CMD" >&2
    echo "try: $0 --help" >&2
    exit 2
    ;;
esac
