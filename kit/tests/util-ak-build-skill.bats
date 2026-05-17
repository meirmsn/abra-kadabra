#!/usr/bin/env bats
# Tests for .claude/skills/devshop/build/SKILL.md — the two text fixes
# bundled as ak-build-text-fixes:
#   (A) Phase 0.4 tracker-prefix convention — every sub-task's TaskCreate
#       subject must prefix its parent phase as `<Phase X> / <sub-unit>`.
#   (B) Step 0 branch-prefix heuristic — count `feat/*` vs `feature/*` to
#       pick the prevailing project convention; default `feat/` greenfield.
#
# The skill is a pure LLM prompt (no shell-script implementation), so these
# are mostly content-validation tests: grep distinctive phrases the fixes
# introduced to confirm the prose still reflects the canonical convention.
#
# Section C goes further: extracts the actual bash heuristic block from
# SKILL.md and runs it against fixture git repos with different `feat/*`
# vs `feature/*` branch combos, asserting the PREFIX choice matches
# expectation. That catches logic regressions (e.g. someone flipping `>`
# to `<`, or removing the greenfield default) the snapshot tests can't see.
#
# Behavior tests of the LLM-side (does Claude actually emit the prefix?)
# are out of scope; this proves the prompt content + the script logic.

setup() {
  load helpers/setup
  SKILL_FILE="/devshop/.claude/skills/devshop/build/SKILL.md"
  WORKFLOW_FILE="/devshop/kit/docs/guide/workflow.md"
  # Do NOT defensively skip when files are missing — a delete/move is
  # precisely the regression these tests exist to catch.
}

# === File presence ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

@test "workflow.md exists at the expected path" {
  [ -f "$WORKFLOW_FILE" ]
}

# === Section A — Fix (A): Phase 0.4 tracker-prefix convention ===

@test "Phase 0.4 section header present" {
  grep -qE '^### 0\.4: Start the live tracker' "$SKILL_FILE"
}

@test "Phase 0.4 declares Subject-prefix convention as canonical (not parenthetical)" {
  # The fix flipped "(or prefixed)" from fallback to canonical. Assert the
  # canonical phrasing is present AND the old fallback wording is gone.
  grep -q 'Subject-prefix convention' "$SKILL_FILE"
  grep -qE 'must.*prefix.*parent phase' "$SKILL_FILE"
  # Old wording would have said "indented (or prefixed)" — that's gone.
  ! grep -q 'indented (or prefixed)' "$SKILL_FILE"
}

@test "Phase 0.4 example list covers each sub-task site" {
  # The convention applies to multiple sites; each should be named so a
  # future edit that drops a site is caught.
  grep -qE '`Phase 2 / Task N:' "$SKILL_FILE"
  grep -qE '`Phase 3 / Finding:' "$SKILL_FILE"
  grep -qE '`Phase 5 / Fix attempt' "$SKILL_FILE"
  grep -qE '`Phase 5\.8 / Audit N' "$SKILL_FILE"
  grep -qE '`Phase 5\.9 / Visual refresh' "$SKILL_FILE"
}

@test "Phase 0.4 explains why the prefix is load-bearing (flat task list)" {
  # The rationale (harness has no parent field) is what makes the
  # convention defensible against future "let's just indent" rewrites.
  grep -qiE 'flat.*no real parent field' "$SKILL_FILE"
}

@test "Phase 0.2 tracker preview example uses prefix form" {
  # The preview the operator sees at Phase 0.2 must match the convention
  # Phase 0.4 instantiates — otherwise they're inconsistent.
  grep -qE '^Phase 2 / Task 1:' "$SKILL_FILE"
  grep -qE '^Phase 2 / Task N:' "$SKILL_FILE"
  # Old indented form (`  - Task 1:`) is gone.
  ! grep -qE '^  - Task 1:' "$SKILL_FILE"
}

@test "workflow.md mirrors the prefix convention" {
  # Guide-level prose must mention the prefix mechanic so the user-facing
  # description matches what /ak-build actually emits. Newlines collapsed
  # so the regex can span a wrapped line ("...as `<Phase X> /\n<sub-unit>`").
  tr '\n' ' ' < "$WORKFLOW_FILE" \
    | grep -qE 'prefix their parent phase as .<Phase X> / +<sub-unit>'
}

# === Section B — Fix (B): Step 0 branch-prefix heuristic ===

@test "Step 0 contains the FEAT_COUNT / FEATURE_COUNT heuristic" {
  grep -q 'FEAT_COUNT=' "$SKILL_FILE"
  grep -q 'FEATURE_COUNT=' "$SKILL_FILE"
}

@test "Step 0 defaults to feat/ on greenfield (else branch picks feat/)" {
  # The heuristic must give feat/ when both counts are equal (greenfield),
  # which the script achieves by using `-gt` (strict greater-than) so the
  # tie falls through to the else branch.
  grep -qE 'FEATURE_COUNT.*-gt.*FEAT_COUNT' "$SKILL_FILE"
  grep -qE 'PREFIX="feat/"' "$SKILL_FILE"
  # Sanity: old hardcoded "feature/" default is gone.
  ! grep -qE 'git checkout -b feature/<name>' "$SKILL_FILE"
}

@test "Step 0 FEATURE-name extraction strips all three prefixes" {
  # The sed must strip feat/, feature/, fix/ — in that order doesn't
  # matter to correctness, but all three patterns must be present.
  grep -qE 's\|\^feat/\|\|' "$SKILL_FILE"
  grep -qE 's\|\^feature/\|\|' "$SKILL_FILE"
  grep -qE 's\|\^fix/\|\|' "$SKILL_FILE"
}

@test "Step 0 resume check enumerates all three branch prefixes" {
  # If a session is already on a `feat/*`, `feature/*`, or `fix/*` branch,
  # Step 0 should skip the create-branch path. All three forms must be named.
  grep -qE 'feat/\*.*feature/\*.*fix/\*|feat/\*.*fix/\*.*feature/' "$SKILL_FILE"
}

@test "workflow.md mentions the feat/feature heuristic" {
  # Guide-level prose must explain the prefix-detection behavior so the
  # user understands why their branch got a particular prefix. Newlines
  # collapsed so the regex can span a wrapped line ("counting existing\n
  # `feat/*` vs `feature/*` branches...").
  tr '\n' ' ' < "$WORKFLOW_FILE" \
    | grep -qiE 'counting existing .feat/\*. vs .feature/\*. branches'
}

# === Section C — Behavioral test: extract + run the heuristic ===
#
# Extracts the bash heuristic block from SKILL.md, sources it against
# fixture git repos, and asserts the PREFIX choice. If a future edit
# changes the comparison operator or the default-on-tie behavior in a
# way the snapshot tests above don't catch, this section fires.

# Extract the heuristic block from SKILL.md into a callable function.
# Looks for the FEAT_COUNT line through the end of the if/fi block.
extract_heuristic() {
  awk '
    /FEAT_COUNT=\$\(git branch/ { in_block=1 }
    in_block { print }
    in_block && /^   fi$/ { exit }
  ' "$SKILL_FILE"
}

# Run the heuristic in a given test repo, return the chosen PREFIX.
run_heuristic_in() {
  local repo="$1"
  # The snippet uses `git branch --list --all` which respects cwd.
  ( cd "$repo" && eval "$(extract_heuristic)" && echo "$PREFIX" )
}

# Build a fixture repo with N feat/* and M feature/* branches.
make_fixture() {
  local feat_count="$1" feature_count="$2"
  local repo="$BATS_TEST_TMPDIR/fixture-${feat_count}-${feature_count}"
  rm -rf "$repo"
  git init -q "$repo"
  git -C "$repo" config user.email t@t.t
  git -C "$repo" config user.name t
  git -C "$repo" commit -q --allow-empty -m init
  local i
  for i in $(seq 1 "$feat_count"); do
    git -C "$repo" branch "feat/topic-$i" >/dev/null
  done
  for i in $(seq 1 "$feature_count"); do
    git -C "$repo" branch "feature/topic-$i" >/dev/null
  done
  echo "$repo"
}

@test "heuristic extraction recovers a non-empty bash block" {
  block="$(extract_heuristic)"
  [ -n "$block" ]
  echo "$block" | grep -q 'FEAT_COUNT='
  echo "$block" | grep -q 'PREFIX='
}

@test "heuristic: greenfield (0 feat, 0 feature) → feat/" {
  repo="$(make_fixture 0 0)"
  result="$(run_heuristic_in "$repo")"
  [ "$result" = "feat/" ]
}

@test "heuristic: mostly feat (3 feat, 1 feature) → feat/" {
  repo="$(make_fixture 3 1)"
  result="$(run_heuristic_in "$repo")"
  [ "$result" = "feat/" ]
}

@test "heuristic: mostly feature (1 feat, 3 feature) → feature/" {
  repo="$(make_fixture 1 3)"
  result="$(run_heuristic_in "$repo")"
  [ "$result" = "feature/" ]
}

@test "heuristic: exact tie (2 feat, 2 feature) defaults to feat/" {
  # The skill picks `feat/` as the greenfield/short-form default; the
  # comparison `FEATURE_COUNT -gt FEAT_COUNT` is strict so a tie falls
  # through to feat/. This protects against a future edit flipping
  # `-gt` to `-ge`.
  repo="$(make_fixture 2 2)"
  result="$(run_heuristic_in "$repo")"
  [ "$result" = "feat/" ]
}

@test "heuristic: only feat/ branches → feat/" {
  repo="$(make_fixture 5 0)"
  result="$(run_heuristic_in "$repo")"
  [ "$result" = "feat/" ]
}

@test "heuristic: only feature/ branches → feature/" {
  repo="$(make_fixture 0 5)"
  result="$(run_heuristic_in "$repo")"
  [ "$result" = "feature/" ]
}
