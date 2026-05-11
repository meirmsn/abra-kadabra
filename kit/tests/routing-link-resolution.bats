#!/usr/bin/env bats
# routing-link-resolution.bats — D7 invariant 1 of feature/context-aware-guideline-routing.
# Parses kit/docs/guide/README.md's routing index and asserts every (file, anchor)
# link resolves to a real H2/H3 header in the target file. Catches drift when a
# guide section is renamed without a paired routing-index update.
#
# Heading-slug algorithm matches GitHub's: lowercase, replace runs of non-word
# characters with single hyphens, collapse consecutive hyphens, strip leading/
# trailing hyphens. Section anchors with em-dashes / slashes / colons / parens
# in the human-readable name still resolve under this rule.
#
# Two intentional skips: (1) skill-invocation targets (e.g. /cso) — the rule is
# encoded in the routing-row Notes column as prose, not as a markdown link; (2)
# block-quoted template skeleton H2s in conventions.md (## What's here,
# ## <Surface map>, ## Conventions, ## See also near the file tail) — these
# headers exist inside an HTML-comment block as a per-package README skeleton,
# not as real sections, so they must not be matched by the slug resolver.

setup() {
  load helpers/setup
  GUIDE_DIR="$TESTS_DIR/../docs/guide"
  README="$GUIDE_DIR/README.md"
  SKILLS_DIR="$TESTS_DIR/../../.claude/skills"
  [ -f "$README" ] || skip "routing index not present at $README"
}

# slugify: GitHub-style anchor slug for a header text line.
# Strips leading "## " / "### "; lowercases; replaces non-[a-z0-9] runs with
# a single hyphen; strips leading/trailing hyphens.
slugify() {
  local text="$1"
  # Strip leading heading markers
  text="${text#"${text%%[![:space:]]*}"}"
  text="${text##\#\#\#\#\#\# }"
  text="${text##\#\#\#\#\# }"
  text="${text##\#\#\#\# }"
  text="${text##\#\#\# }"
  text="${text##\#\# }"
  text="${text##\# }"
  # GitHub: lowercase; preserve word chars + hyphens; drop everything else;
  # collapse multiple spaces to single hyphen.
  printf '%s' "$text" | awk '{
    out=tolower($0)
    # Replace any char NOT in [a-z0-9 _-] with empty (drops backticks, parens,
    # colons, slashes, etc.). Preserve spaces, underscores, hyphens for the
    # space-to-hyphen pass.
    gsub(/[^a-z0-9 _-]/, "", out)
    # Replace spaces with hyphens.
    gsub(/ /, "-", out)
    # Collapse runs of dashes from punctuation+space combos.
    # GitHub keeps consecutive dashes ("a / b" → "a--b"), so do NOT collapse.
    # Trim leading/trailing dashes.
    sub(/^-+/, "", out)
    sub(/-+$/, "", out)
    print out
  }'
}

# Build the set of real (file, slug) tuples — every routable H2/H3 in every
# guide file, excluding block-quoted skeleton headers in conventions.md.
build_real_anchors() {
  REAL_ANCHORS_FILE="$BATS_TEST_TMPDIR/real-anchors"
  : > "$REAL_ANCHORS_FILE"
  local f
  for f in "$GUIDE_DIR"/*.md; do
    [ -f "$f" ] || continue
    local base
    base=$(basename "$f")
    # Skip block-quoted skeleton headers — present only at the tail of
    # conventions.md inside an HTML comment that mimics a per-package README
    # template. Detect by H2 line text.
    local in_skeleton=0
    local skeleton_pat='^## (What.s here|<Surface map|Conventions$|See also$)'
    while IFS= read -r line; do
      if [[ "$base" == "conventions.md" && "$line" =~ $skeleton_pat ]]; then
        in_skeleton=1
        continue
      fi
      # H2 / H3 only (the routing index links never point at H4 or deeper)
      if [[ "$line" =~ ^##[[:space:]] ]] || [[ "$line" =~ ^###[[:space:]] ]]; then
        if [ "$in_skeleton" -eq 1 ]; then
          # Once in skeleton territory, every subsequent H2 inside conventions.md
          # is also block-quoted — they're all part of the same skeleton block.
          continue
        fi
        local slug
        slug=$(slugify "$line")
        printf '%s\t%s\n' "$base" "$slug" >> "$REAL_ANCHORS_FILE"
      fi
    done < "$f"
  done
}

# Extract every (file, anchor) link from README.md's routing rows.
# Matches markdown links of the form [text](./file.md#anchor) and
# [text](./file.md). Skips anchor-less plain-text targets (skill invocations).
extract_routing_links() {
  EXTRACTED_FILE="$BATS_TEST_TMPDIR/extracted-links"
  : > "$EXTRACTED_FILE"
  # Match (./file.md) or (./file.md#anchor). Capture file + optional anchor.
  grep -oE '\(\./[A-Za-z0-9_-]+\.md(#[A-Za-z0-9_-]+)?\)' "$README" \
    | sed -e 's/^(//' -e 's/)$//' -e 's|^\./||' \
    | sort -u > "$EXTRACTED_FILE"
}

@test "build: every README.md routing link parses to (file, anchor)" {
  extract_routing_links
  run wc -l < "$EXTRACTED_FILE"
  assert_success
  # Floor — there must be at least 10 link tuples per spec § Acceptance criterion 1.
  [ "$output" -ge 10 ]
}

@test "build: real-anchor index assembled from kit/docs/guide/*.md" {
  build_real_anchors
  run wc -l < "$REAL_ANCHORS_FILE"
  assert_success
  # Floor — the new routing index targets at least a dozen H2/H3 anchors.
  [ "$output" -ge 12 ]
}

@test "every (file, anchor) routing link resolves to a real H2/H3" {
  extract_routing_links
  build_real_anchors
  local unresolved=0
  local detail=""
  while IFS= read -r link; do
    local file anchor
    if [[ "$link" == *"#"* ]]; then
      file="${link%%#*}"
      anchor="${link#*#}"
    else
      file="$link"
      anchor=""
    fi
    # Anchor-less (file) link → assert the file exists.
    if [ -z "$anchor" ]; then
      if [ ! -f "$GUIDE_DIR/$file" ]; then
        unresolved=$((unresolved+1))
        detail+="  - missing file: $file"$'\n'
      fi
      continue
    fi
    # (file, anchor) → assert the anchor is in the real-anchors index for the file.
    if ! grep -qF $'\n'"${file}"$'\t'"${anchor}"$'\n' <(printf '\n'; cat "$REAL_ANCHORS_FILE"; printf '\n'); then
      unresolved=$((unresolved+1))
      detail+="  - unresolved: $file#$anchor"$'\n'
    fi
  done < "$EXTRACTED_FILE"
  if [ "$unresolved" -ne 0 ]; then
    echo "FAIL: $unresolved unresolved routing link(s):"
    echo "$detail"
    return 1
  fi
}

@test "block-quoted skeleton H2s in conventions.md are NOT in the real-anchor index" {
  build_real_anchors
  # ## What's here → slug "whats-here"; ## See also → "see-also"; etc.
  # If these slugs ever appear in the real-anchor list for conventions.md, the
  # skeleton-skip logic above is broken and routing rows could falsely resolve.
  run grep -F $'conventions.md\twhats-here' "$REAL_ANCHORS_FILE"
  [ "$status" -ne 0 ]
  run grep -F $'conventions.md\tsee-also' "$REAL_ANCHORS_FILE"
  [ "$status" -ne 0 ]
}

@test "skill-invocation rows: every referenced skill exists at .claude/skills/<name>/" {
  # The routing index names two skills as targets: `/cso` (gstack) and the
  # devshop ones already covered by the SKILL.md edits in Task 7/8 — we don't
  # need to enumerate from grep here because the existing wiring tests already
  # verify .claude/skills/* layout. This test is a defensive backstop: if a
  # future routing row names a non-existent skill, the line `Skill: /<name>`
  # in README.md must resolve to a real skill directory.
  #
  # Match `Skill: /<name>` patterns in the routing index Notes/Target columns.
  local missing=0
  while IFS= read -r skill; do
    # Strip leading slash.
    local name="${skill#/}"
    # Skip empty matches.
    [ -z "$name" ] && continue
    # Look for either the symlink at .claude/skills/ak-<name> or the dir at
    # .claude/skills/<area>/<name>/. Use a recursive search bounded to depth 3.
    if ! find "$SKILLS_DIR" -maxdepth 3 -type d -name "$name" 2>/dev/null | grep -q . \
       && ! find "$SKILLS_DIR" -maxdepth 2 -type l -name "ak-$name" 2>/dev/null | grep -q . \
       && ! find "$SKILLS_DIR" -maxdepth 2 -type l -name "$name" 2>/dev/null | grep -q .; then
      missing=$((missing+1))
      echo "  - skill not found on disk: /$name"
    fi
  done < <(grep -oE 'Skill: /[a-z-]+' "$README" | sed -E 's/Skill: //' | sort -u)
  [ "$missing" -eq 0 ]
}
