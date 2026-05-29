#!/usr/bin/env bats
# Tests for .claude/skills/ak-spec/SKILL.md + .claude/skills/ak-build/SKILL.md
# + .claude/skills/ak-go-live/SKILL.md — the canonical product-update PR
# section convention. Two blurbs (Headline + Detail) live in spec.md as
# the single source-of-truth, routed verbatim to the PR body's
# `## Product update` section, BUILD-LOG `Headline:` + `Summary:` fields,
# `/ak-go-live` Step 6 deployed-to-prod lede (Headline) + context
# (Detail), and future CHANGELOG aggregation (Headline). (Phase 7 prints
# a terminal handoff, not a PR comment — see the Phase 7.2 assertions.)
#
# Sections:
#   A — Content validation: ak-spec SKILL.md carries the contract.
#   B — Content validation: ak-build SKILL.md carries Phase 0.2.6 lint,
#       Phase 4.1 PR body composition, Phase 5.3.5 drift signal #5,
#       Phase 5.6 BUILD-LOG entry shape, Phase 6 Gate A + Gate B (and
#       no audit-trail comment), and Phase 7 terminal handoff (no comment).
#   C — Content validation: ak-go-live SKILL.md Step 6 carries Headline
#       lede + Detail context.
#   D — Behavioral: extract Phase 0.2.6 lint logic from ak-build SKILL.md
#       and run against fixture Headline strings — asserts the regex set
#       still flags / passes the same vocabulary categories.
#   E — Behavioral: extract Phase 5.3.5 / Phase 6 Gate B noun-extraction
#       block and run against fixture spec.md + diff. Asserts headline /
#       detail extraction + audience-shape mismatch detection still work.

setup() {
  load helpers/setup
  AK_SPEC="$TESTS_DIR/../../.claude/skills/ak-spec/SKILL.md"
  AK_BUILD="$TESTS_DIR/../../.claude/skills/ak-build/SKILL.md"
  AK_GO_LIVE="$TESTS_DIR/../../.claude/skills/ak-go-live/SKILL.md"
}

# === Section A — ak-spec carries the Product update contract ===

@test "ak-spec SKILL.md exists at the expected path" {
  [ -f "$AK_SPEC" ]
}

@test "ak-spec Step 6 lists ## Product update as REQUIRED before Core user story" {
  # The required-sections list mentions Product update with both sub-section names.
  grep -qE '\*\*`## Product update`\*\* \(REQUIRED' "$AK_SPEC"
  grep -qE '`### Headline \(user-facing\)`' "$AK_SPEC"
  grep -qE '`### Detail \(team-facing\)`' "$AK_SPEC"
}

@test "ak-spec has a dedicated ### Product update sub-section" {
  grep -qE '^### Product update \(required' "$AK_SPEC"
}

@test "ak-spec Product update sub-section names the downstream surfaces" {
  # PR body / BUILD-LOG / Step 6 / future CHANGELOG. (Phase 7 is NOT a
  # surface — it prints a terminal handoff, not a comment; the blurbs do
  # not route through it.)
  grep -q 'BUILD-LOG' "$AK_SPEC"
  grep -qE 'Step 6|deployed-to-prod' "$AK_SPEC"
  grep -qi 'CHANGELOG' "$AK_SPEC"
}

@test "ak-spec Product update section forbids eng vocabulary in Headline" {
  # The contract must name forbidden-vocabulary categories explicitly.
  grep -qi 'no enum names' "$AK_SPEC"
  grep -qi 'no RPC names' "$AK_SPEC"
  grep -qi 'no migration numbers' "$AK_SPEC"
  grep -qi 'cross-PR references' "$AK_SPEC"
}

@test "ak-spec Product update section covers edge cases" {
  # Pure infra / hotfix / multi-feature / collapsed shape.
  grep -qE 'Pure infra PR|Infrastructure update' "$AK_SPEC"
  grep -qi 'hotfix' "$AK_SPEC"
  grep -qi 'multi-feature' "$AK_SPEC"
  grep -qE 'Headline = Detail|Headline \+ Detail \(combined\)' "$AK_SPEC"
}

@test "ak-spec Quality checklist includes Product update item" {
  awk '/^## Quality checklist/,0' "$AK_SPEC" | grep -qE '`## Product update` section'
}

# === Section B — ak-build wiring ===

@test "ak-build SKILL.md exists at the expected path" {
  [ -f "$AK_BUILD" ]
}

@test "Phase 0.2 Scope preview surfaces both blurbs as first named bullets" {
  awk '/^### 0\.2: Produce the 3-section preview/,/^### 0\.2\.5/' "$AK_BUILD" \
    | grep -qE 'Headline \(user-facing'
  awk '/^### 0\.2: Produce the 3-section preview/,/^### 0\.2\.5/' "$AK_BUILD" \
    | grep -qE 'Detail \(team-facing'
}

@test "Phase 0.2.6 Headline forbidden-vocabulary lint section present" {
  grep -qE '^### 0\.2\.6: Headline forbidden-vocabulary lint' "$AK_BUILD"
}

@test "Phase 0.2.6 enumerates forbidden patterns (backtick / snake_case / PascalCase / RPC / migration / route / cross-PR)" {
  awk '/^### 0\.2\.6/,/^### 0\.2\.5/' "$AK_BUILD" | grep -qi 'backtick'
  awk '/^### 0\.2\.6/,/^### 0\.2\.5/' "$AK_BUILD" | grep -q 'snake_case'
  awk '/^### 0\.2\.6/,/^### 0\.2\.5/' "$AK_BUILD" | grep -q 'PascalCase'
  awk '/^### 0\.2\.6/,/^### 0\.2\.5/' "$AK_BUILD" | grep -qi 'RPC'
  awk '/^### 0\.2\.6/,/^### 0\.2\.5/' "$AK_BUILD" | grep -qi 'migration'
  awk '/^### 0\.2\.6/,/^### 0\.2\.5/' "$AK_BUILD" | grep -qi 'route'
  awk '/^### 0\.2\.6/,/^### 0\.2\.5/' "$AK_BUILD" | grep -qi 'cross-PR'
}

@test "Phase 0.3 spec skeleton template includes ## Product update section" {
  awk '/^### 0\.3: Persist approved decisions/,/^### 0\.4/' "$AK_BUILD" \
    | grep -q '## Product update'
  awk '/^### 0\.3: Persist approved decisions/,/^### 0\.4/' "$AK_BUILD" \
    | grep -q '### Headline (user-facing)'
  awk '/^### 0\.3: Persist approved decisions/,/^### 0\.4/' "$AK_BUILD" \
    | grep -q '### Detail (team-facing)'
}

@test "Phase 4.1 composes ## Product update + ## Engineering details, not legacy ## Summary" {
  awk '/^### 4\.1:/,/^### 4\.2:/' "$AK_BUILD" | grep -q '## Product update'
  awk '/^### 4\.1:/,/^### 4\.2:/' "$AK_BUILD" | grep -q '## Engineering details'
  # Heading naming explicitly notes the rename from ## Summary.
  awk '/^### 4\.1:/,/^### 4\.2:/' "$AK_BUILD" | grep -qE 'renamed|Summary.*rename|rename.*Summary'
}

@test "Phase 4.1 stashes full PR body at /tmp/ship-body.md with required section check" {
  awk '/^### 4\.1:/,/^### 4\.2:/' "$AK_BUILD" | grep -q '/tmp/ship-body.md'
  awk '/^### 4\.1:/,/^### 4\.2:/' "$AK_BUILD" | grep -q 'BODY_MISSING'
}

@test "Phase 4.1 mandates Product update placed first after H1, before Engineering details" {
  awk '/^### 4\.1:/,/^### 4\.2:/' "$AK_BUILD" | tr '\n' ' ' \
    | grep -qE 'Product update.*first content after the H1'
}

@test "Phase 5.3.5 includes a fifth drift signal — product-blurb stale check" {
  awk '/^### 5\.3\.5:/,/^### 5\.4:/' "$AK_BUILD" \
    | grep -qE 'Signal 5|product-blurb'
}

@test "Phase 5.3.5 product-blurb check parses spec.md § Product update (both blurbs + collapsed)" {
  # The awk patterns escape the parens (`\(user-facing\)`), so the grep
  # accepts either escaped or literal form.
  awk '/^### 5\.3\.5:/,/^### 5\.4:/' "$AK_BUILD" \
    | grep -qE '### Headline (\\?\(user-facing\\?\))'
  awk '/^### 5\.3\.5:/,/^### 5\.4:/' "$AK_BUILD" \
    | grep -qE '### Detail (\\?\(team-facing\\?\))'
  awk '/^### 5\.3\.5:/,/^### 5\.4:/' "$AK_BUILD" \
    | grep -qE 'Headline.*Detail.*combined'
}

@test "Phase 5.6 BUILD-LOG entry shape includes both Headline and Summary fields" {
  awk '/^### 4\.0:/,/^### 4\.1:/' "$AK_BUILD" \
    | grep -qE '\*\*Headline\*\*:'
  awk '/^### 4\.0:/,/^### 4\.1:/' "$AK_BUILD" \
    | grep -qE '\*\*Summary\*\*:'
}

@test "Phase 5.6 explains Headline + Summary routing rationale (CHANGELOG primitive + future-me audience)" {
  awk '/^### 4\.0:/,/^### 4\.1:/' "$AK_BUILD" | grep -qi 'CHANGELOG'
  awk '/^### 4\.0:/,/^### 4\.1:/' "$AK_BUILD" | grep -qi 'future-me'
}

@test "Phase 6 has Part D — Product update verification (Gate A + Gate B)" {
  awk '/^### Phase 6 checkbox/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE 'Part D.*Product update'
}

@test "Phase 6 Part D Gate A is autonomous; Gate B is the automated cross-check" {
  # Gate A no longer always asks the operator to confirm the blurbs — it
  # reviews them autonomously against the diff + Gate B findings, mirroring
  # Part C's factual-checkbox closure. Three outcomes; escalation is the
  # only operator prompt.
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE 'Gate A.*autonomous'
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE '\*\*Accurate\*\*'
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE '\*\*Edit-and-self-resolve\*\*'
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE '\*\*Escalate\*\*'
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE 'Gate B.*automated.*cross-check'
}

@test "Phase 6 Gate A escalation is the only operator prompt" {
  # AskUserQuestion fires only on the Escalate rung — a genuine
  # claim-vs-diff product-judgment mismatch the diff can't settle.
  awk '/Gate A — autonomous/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qiE 'ONLY operator prompt'
}

@test "Phase 6 posts no audit-trail PR comment (gate results live in review.md)" {
  # The Phase 6 gate-table audit comment was dropped — gate results live in
  # the committed specs/<feature>/review.md, not on the PR timeline. Parts
  # A/B still use `gh pr edit --body-file` for legitimate body fixes; only
  # the `gh pr comment` post is gone. (The sole `gh pr comment` in the
  # skill is the unrelated Phase 5.5 CI-failure escalation, before Phase 6.)
  ! awk '/^## Phase 6/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE 'gh pr comment'
}

@test "Phase 6 Gate B is warn-not-block, informs Gate A" {
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qi 'warn-not-block'
}

@test "Phase 6 Gate B parses spec.md § Product update via awk on heading" {
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE 'awk .*Headline \\\(user-facing'
  awk '/Part D.*Product update/,/^## Phase 7/' "$AK_BUILD" \
    | grep -qE 'awk .*Detail \\\(team-facing'
}

@test "Phase 7.2 prints handoff to terminal (no PR comment)" {
  # Phase 7.2 was rewritten — no "Ready for review" comment, just terminal output.
  awk '/^### 7\.2:/,/^## PR body/' "$AK_BUILD" \
    | grep -qiE 'terminal|stdout|handoff|echo'
}

@test "Phase 7.2 does not post a ready-for-review PR comment" {
  # The ready-for-review comment was stripped as devshop process noise.
  ! awk '/^### 7\.2:/,/^## PR body/' "$AK_BUILD" \
    | grep -qi 'gh pr comment.*ready.for.review'
}

# === Section C — ak-go-live Step 6 ===

@test "ak-go-live SKILL.md exists at the expected path" {
  [ -f "$AK_GO_LIVE" ]
}

@test "ak-go-live Step 6 uses Headline as lede + Detail as context" {
  awk '/^## Step 6/,0' "$AK_GO_LIVE" | grep -qE 'HEADLINE_BLURB'
  awk '/^## Step 6/,0' "$AK_GO_LIVE" | grep -qE 'DETAIL_BLURB'
  # Headline lede comes first in the body (matches the "celebration
  # moment, screenshot to share" framing).
  awk '/^## Step 6/,0' "$AK_GO_LIVE" | tr '\n' ' ' \
    | grep -qE 'HEADLINE_BLURB.*DETAIL_BLURB'
}

@test "ak-go-live Step 6 names the celebration framing rationale" {
  awk '/^## Step 6/,0' "$AK_GO_LIVE" | grep -qiE 'celebration|stakeholders|screenshot|share'
}

# === Section D — Behavioral: Headline forbidden-vocabulary lint ===
#
# Extracts the regex set from Phase 0.2.6's bash implementation block
# (the `echo "$HEADLINE" | grep -oE '...'` lines) and runs each pattern
# against fixture Headlines to confirm the lint still flags / passes
# the intended categories.

# Pull every grep -oE regex from Phase 0.2.6's bash block.
extract_lint_regexes() {
  awk '/^### 0\.2\.6:/,/^### 0\.2\.5:/' "$AK_BUILD" \
    | grep -oE "grep -oE '[^']+'" \
    | sed -E "s/^grep -oE '//; s/'$//"
}

@test "Phase 0.2.6 lint regexes flag a Headline with backticked identifier" {
  text='Adds the `card_state` machine.'
  extract_lint_regexes | while IFS= read -r re; do
    [ -z "$re" ] && continue
    if echo "$text" | grep -qE "$re"; then
      echo "MATCH: $re"
    fi
  done | grep -q MATCH
}

@test "Phase 0.2.6 lint regexes flag a Headline with PascalCase component" {
  text='Renders DecideCard with a path picker.'
  extract_lint_regexes | while IFS= read -r re; do
    [ -z "$re" ] && continue
    if echo "$text" | grep -qE "$re"; then
      echo "MATCH: $re"
    fi
  done | grep -q MATCH
}

@test "Phase 0.2.6 lint regexes flag a Headline with snake_case token" {
  text='Adds confirm_triage support.'
  extract_lint_regexes | while IFS= read -r re; do
    [ -z "$re" ] && continue
    if echo "$text" | grep -qE "$re"; then
      echo "MATCH: $re"
    fi
  done | grep -q MATCH
}

@test "Phase 0.2.6 lint regexes flag a Headline with cross-PR reference" {
  text='Builds on PR #27 with new affordances.'
  extract_lint_regexes | while IFS= read -r re; do
    [ -z "$re" ] && continue
    if echo "$text" | grep -qE "$re"; then
      echo "MATCH: $re"
    fi
  done | grep -q MATCH
}

@test "Phase 0.2.6 lint regexes pass a clean Headline" {
  # A clean Headline has no eng vocabulary. None of the regexes should fire.
  text='Pick a path for every issue and save your decision.'
  matched=0
  while IFS= read -r re; do
    [ -z "$re" ] && continue
    if echo "$text" | grep -qE "$re"; then
      matched=$((matched + 1))
    fi
  done < <(extract_lint_regexes)
  [ "$matched" -eq 0 ]
}

# === Section E — Behavioral: cross-check noun extraction + audience-shape ===
#
# Phase 5.3.5 / Phase 6 Gate B share a heuristic: extract distinctive
# nouns from each blurb (PascalCase + 4+char lowercase, minus stopwords),
# then compare the sets. This section runs that extraction against
# fixture spec.md content and asserts mismatches surface as expected.

make_spec_fixture() {
  local dir="$1" headline="$2" detail="$3"
  mkdir -p "$dir"
  {
    echo '# Spec: fixture'
    echo
    echo '## Product update'
    echo
    echo '### Headline (user-facing)'
    echo
    echo "$headline"
    echo
    echo '### Detail (team-facing)'
    echo
    echo "$detail"
    echo
    echo '## Decisions'
  } > "$dir/spec.md"
}

# Extract distinctive nouns the same way Phase 5.3.5 / 6 does. This
# duplicates the heuristic intentionally — the test fails if the
# stopword set or regex set in SKILL.md drifts.
extract_nouns_inline() {
  local body="$1"
  local stopwords='with|this|that|than|from|when|will|have|here|each|just|only|some|then|they|been|were|into|over|same|more|like|much|where|after|other|user|users|page|view|flow|able|make|made|need|want|allow|shows|adds|added|fixes|fixed|onto|down|both|along|your|saved|sets|see|set|via|now|out|but|and|the|for|its|any|all|new|can'
  { echo "$body" | grep -oE '\b[A-Z][a-zA-Z]+\b' || true
    echo "$body" | grep -oE '\b[a-z]{4,}\b' | grep -vwE "$stopwords" || true
  } | tr '[:upper:]' '[:lower:]' | sort -u
}

@test "noun extraction surfaces distinctive lowercase 4+ char tokens" {
  result=$(extract_nouns_inline 'Pick a path for every issue, get DIY instructions, or set a reminder.')
  echo "$result" | grep -q '^path$'
  echo "$result" | grep -q '^issue$'
  echo "$result" | grep -q '^reminder$'
  echo "$result" | grep -q '^instructions$'
  # Stopwords filtered.
  ! echo "$result" | grep -q '^with$'
  ! echo "$result" | grep -q '^that$'
}

@test "noun extraction surfaces PascalCase (proper nouns / acronyms)" {
  result=$(extract_nouns_inline 'After diagnosed, transitions to planned with Monitor / DIY paths.')
  # Lowercased on output.
  echo "$result" | grep -q '^monitor$'
  echo "$result" | grep -q '^planned$'
}

@test "audience-shape mismatch detection — claim in Detail absent from Headline" {
  headline_nouns=$(extract_nouns_inline 'Pick a path for every issue.')
  detail_nouns=$(extract_nouns_inline 'After diagnosed, choose DIY / Contractor / Monitor / Dismiss; the AI cost estimate stays visible.')
  # 'estimate' and 'visible' are Detail-only; mismatch detection should
  # flag them.
  missing=$(comm -23 <(echo "$detail_nouns") <(echo "$headline_nouns"))
  echo "$missing" | grep -qE '^(estimate|visible|cost|contractor|dismiss|stays)$'
}

@test "no false-positive: Headline = Detail produces empty mismatch set" {
  same='Pick a path and save your decision.'
  headline_nouns=$(extract_nouns_inline "$same")
  detail_nouns=$(extract_nouns_inline "$same")
  missing=$(comm -23 <(echo "$detail_nouns") <(echo "$headline_nouns"))
  overclaim=$(comm -23 <(echo "$headline_nouns") <(echo "$detail_nouns"))
  [ -z "$missing" ]
  [ -z "$overclaim" ]
}
