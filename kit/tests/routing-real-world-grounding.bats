#!/usr/bin/env bats
# routing-real-world-grounding.bats — D7 invariant 3 of feature/context-aware-guideline-routing.
# Validates that the routing-row trigger signals named in
# kit/docs/guide/README.md aren't synthetic — i.e., that they actually fire on
# real specs. The probe corpus is lalista's /workspace/specs/*/spec.md tree
# under the devcontainer fixture; if /workspace isn't mounted (e.g., CI
# environment without the devcontainer fixture), the test skips with an
# explicit reason — never silently pass.
#
# Cross-boundary read: this test reads OUTSIDE /devshop. The /workspace dir is
# mounted by the devcontainer compose.yml; in the slow-job CI that runs from
# the devcontainer, the mount is present. In environments that lack the mount,
# the skip is the right behavior — the test would be meaningless without the
# probe corpus.

setup() {
  load helpers/setup
  GUIDE_DIR="$TESTS_DIR/../docs/guide"
  README="$GUIDE_DIR/README.md"
  LALISTA_SPECS_DIR="/workspace/specs"
  if [ ! -d "$LALISTA_SPECS_DIR" ]; then
    skip "/workspace not mounted — cross-boundary grounding check requires devcontainer fixture"
  fi
  [ -f "$README" ] || skip "routing index not present at $README"
}

# Build the set of trigger tokens drawn from routing-row Trigger columns.
# Routing rows are markdown table rows with at least 4 pipes. The Trigger
# column is the 2nd cell ($2 after `awk -F'|'`). We extract: backtick-quoted
# tokens (file globs + import names + keywords like `"RLS"`), bare keywords
# (PWA, Zod, realtime, etc.).
trigger_tokens() {
  awk '
    /^## (Out of routing|Alphabetical)/ { skip=1 }
    /^## / && !/^## (Out of routing|Alphabetical)/ { skip=0 }
    !skip { print }
  ' "$README" \
    | awk -F'|' '
        NF >= 4 && $1 == "" && $2 !~ /Trigger/ && $2 !~ /^[[:space:]]*-+[[:space:]]*$/ {
          print $2
        }' \
    | grep -oE '`[^`]+`' \
    | sed 's/^`//; s/`$//' \
    | sort -u
}

@test "build: at least 5 trigger tokens extracted from routing-index Trigger columns" {
  local tokens count
  tokens=$(trigger_tokens)
  count=$(printf '%s\n' "$tokens" | grep -c .)
  [ "$count" -ge 5 ]
}

@test "at least 3 trigger signals fire on at least one lalista spec" {
  local tokens fired=0 fired_detail=""
  tokens=$(trigger_tokens)
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    # Strip surrounding quotes if the token is a keyword like "RLS".
    local probe="${tok%\"}"
    probe="${probe#\"}"
    # Skip pure-glob fragments that grep-F would treat as literal — accept
    # them as-is; lalista uses these literal globs in spec ## Files sections.
    # Also skip the empty / one-char cases.
    [ ${#probe} -lt 3 ] && continue
    if grep -rqF "$probe" "$LALISTA_SPECS_DIR"/*/spec.md 2>/dev/null; then
      fired=$((fired+1))
      fired_detail+="  - $tok"$'\n'
    fi
  done <<<"$tokens"
  if [ "$fired" -lt 3 ]; then
    echo "FAIL: only $fired trigger signals fired on lalista specs (need ≥3)"
    echo "Triggers tested: $(printf '%s\n' "$tokens" | grep -c .)"
    echo "Triggers that fired:"
    echo "$fired_detail"
    return 1
  fi
}

@test "specific high-confidence routing-row triggers fire on lalista specs" {
  # Sanity-anchor: the audit named these triggers explicitly, and lalista
  # has shipped specs that should match each. A failure here means either
  # the audit's signal was wrong OR the spec it expected to match got
  # renamed / removed.
  local checks=(
    "supabase/migrations"      # db-hardening, auth specs
    "PostgREST"                # database-queries audit references this
    "optimistic mutation"      # app-snappiness mentions
    "PWA"                      # app-snappiness, ops mentions
  )
  local fired=0
  for c in "${checks[@]}"; do
    if grep -rqF "$c" "$LALISTA_SPECS_DIR"/*/spec.md 2>/dev/null; then
      fired=$((fired+1))
    fi
  done
  # At least 3 of the 4 high-confidence triggers must fire — gives the test
  # one degree of robustness if a single lalista spec name changes.
  [ "$fired" -ge 3 ]
}
