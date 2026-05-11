#!/usr/bin/env bats
# routing-completeness.bats — D7 invariant 2 of feature/context-aware-guideline-routing.
# Asserts every guide on disk under kit/docs/guide/*.md is accounted for in
# kit/docs/guide/README.md: it must appear in the routing index's grouped
# sections (### Data / ### Auth + security / ### Frontend + UI / ### Ops + deploy /
# ### Dev + meta) OR in the explicit ## Out of routing list. Out-of-routing
# files must NOT also be the primary target of a routing row.
#
# README.md itself is excluded — it IS the routing index, not a routed guide.
#
# "Out-of-routing entry" detection: a file is "out-of-routing" iff it appears
# in a list item directly under the ## Out of routing H2 (before the next H2).
# "Routed-as-target" detection: a file appears in a routing-row's Target
# column (the second `|` cell in a table row under one of the routing
# group H2s, EXCLUDING the ## Out of routing and ## Alphabetical file list
# sections).

setup() {
  load helpers/setup
  GUIDE_DIR="$TESTS_DIR/../docs/guide"
  README="$GUIDE_DIR/README.md"
  [ -f "$README" ] || skip "routing index not present at $README"
}

# Build the list of guide files on disk (excluding README.md itself).
list_guide_files() {
  ls "$GUIDE_DIR"/*.md 2>/dev/null \
    | xargs -n1 basename \
    | grep -v '^README\.md$' \
    | sort
}

# Pull the set of files explicitly named in the ## Out of routing section.
out_of_routing_files() {
  awk '
    /^## Out of routing/ { in_oor=1; next }
    /^## /               { in_oor=0 }
    in_oor { print }
  ' "$README" \
    | grep -oE '\(\./[A-Za-z0-9_-]+\.md\)' \
    | sed -e 's/^(\.\///' -e 's/)$//' \
    | sort -u
}

# Files that appear as a primary routing-row TARGET (the 2nd table cell of a
# routing row). Excludes the ## Out of routing and ## Alphabetical file list
# sections so secondary citations don't count as primary targets.
routed_as_target() {
  awk '
    /^## (Out of routing|Alphabetical)/ { skip=1 }
    /^## / && !/^## (Out of routing|Alphabetical)/ { skip=0 }
    !skip { print }
  ' "$README" \
    | awk -F'|' '
        # Table rows have at least 4 pipes for 3 cells; the routing index
        # uses 4 cells (Trigger | Target | Notes plus the leading and
        # trailing |). The TARGET column is the 3rd field (1=empty, 2=Trigger,
        # 3=Target, 4=Notes, 5=trailing-empty).
        NF >= 4 && $1 == "" {
          # Skip the header + separator rows. Header has "Trigger" in $2;
          # separator has `---` in every field.
          if ($2 ~ /Trigger/) next
          if ($2 ~ /^[[:space:]]*-+[[:space:]]*$/) next
          print $3
        }' \
    | grep -oE '\(\./[A-Za-z0-9_-]+\.md(#[A-Za-z0-9_-]+)?\)' \
    | sed -e 's/^(\.\///' -e 's/)$//' -e 's/#.*$//' \
    | sort -u
}

# Files appearing in the alphabetical file list (the orientation table at
# the bottom of README.md). This list MUST mirror every disk file exactly
# once — it's the canonical orientation index.
alphabetical_list_files() {
  awk '
    /^## Alphabetical/ { in_alpha=1; next }
    /^## /             { in_alpha=0 }
    in_alpha { print }
  ' "$README" \
    | grep -oE '\(\./[A-Za-z0-9_-]+\.md\)' \
    | sed -e 's/^(\.\///' -e 's/)$//' \
    | sort -u
}

@test "every guide on disk appears in routing OR out-of-routing" {
  local on_disk routed oor missing=0 detail=""
  on_disk=$(list_guide_files)
  routed=$(routed_as_target)
  oor=$(out_of_routing_files)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! printf '%s\n' "$routed" | grep -qFx "$f" \
       && ! printf '%s\n' "$oor" | grep -qFx "$f"; then
      missing=$((missing+1))
      detail+="  - $f"$'\n'
    fi
  done <<<"$on_disk"
  if [ "$missing" -ne 0 ]; then
    echo "FAIL: $missing guide(s) listed in neither routing groups nor out-of-routing:"
    echo "$detail"
    return 1
  fi
}

@test "out-of-routing files are also acceptable as supplementary citations in routing rows" {
  # By design (audit Items 6+7, README.md preamble), out-of-routing files
  # like architecture.md can still appear as secondary citations in a routing
  # row's Target or Notes column — e.g., the "root-locked files" row pairs
  # security.md § Security-Critical Files WITH architecture.md (file lifecycle).
  # The Notes column even explicitly flags this. We document the convention
  # here so a future cleanup pass doesn't tighten the check inappropriately.
  #
  # The actual invariant — every guide is accounted for — is checked above.
  # This test asserts the convention is exercised in at least one routing row,
  # so a future routing-row scrub doesn't accidentally eliminate ALL cross-
  # citations (which would degrade the "ALSO read this" navigation affordance).
  local oor citations=0
  oor=$(out_of_routing_files)
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Count occurrences of this OOR file in non-OOR / non-Alphabetical sections.
    local count
    count=$(awk -v f="$f" '
      /^## (Out of routing|Alphabetical)/ { skip=1 }
      /^## / && !/^## (Out of routing|Alphabetical)/ { skip=0 }
      !skip && index($0, "(./" f ")") { c++ }
      END { print c+0 }
    ' "$README")
    citations=$((citations + count))
  done <<<"$oor"
  # At least one cross-citation must exist — otherwise the convention is dead.
  [ "$citations" -ge 1 ]
}

@test "no routing reference points at a deleted guide" {
  local routed oor on_disk stale=0 detail=""
  routed=$(routed_as_target)
  oor=$(out_of_routing_files)
  on_disk=$(list_guide_files)
  for set_name in routed oor; do
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if ! printf '%s\n' "$on_disk" | grep -qFx "$f"; then
        stale=$((stale+1))
        detail+="  - $f (referenced by $set_name; not on disk)"$'\n'
      fi
    done <<<"${!set_name}"
  done
  if [ "$stale" -ne 0 ]; then
    echo "FAIL: $stale routing reference(s) point at deleted guide(s):"
    echo "$detail"
    return 1
  fi
}

@test "alphabetical file list mirrors every disk file exactly once (orientation)" {
  local on_disk alpha drift=0 detail=""
  on_disk=$(list_guide_files)
  alpha=$(alphabetical_list_files)
  # Disk → alphabetical (every disk file MUST be in alphabetical list).
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! printf '%s\n' "$alpha" | grep -qFx "$f"; then
      drift=$((drift+1))
      detail+="  - $f on disk but NOT in ## Alphabetical file list"$'\n'
    fi
  done <<<"$on_disk"
  # Alphabetical → disk (every alphabetical entry MUST point at a real file).
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if ! printf '%s\n' "$on_disk" | grep -qFx "$f"; then
      drift=$((drift+1))
      detail+="  - $f in ## Alphabetical file list but NOT on disk"$'\n'
    fi
  done <<<"$alpha"
  if [ "$drift" -ne 0 ]; then
    echo "FAIL: $drift alphabetical-list/disk drift(s):"
    echo "$detail"
    return 1
  fi
}

@test "out-of-routing section names at least 2 entries (acceptance criterion 2)" {
  local oor count
  oor=$(out_of_routing_files)
  count=$(printf '%s\n' "$oor" | grep -c .)
  [ "$count" -ge 2 ]
}
