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
  # Derive from TESTS_DIR so tests fire against the actual worktree, not the
  # hardcoded `/devshop/...` path (which would silently bypass linked-worktree
  # edits).
  SKILL_FILE="$TESTS_DIR/../../.claude/skills/devshop/build/SKILL.md"
  WORKFLOW_FILE="$TESTS_DIR/../docs/guide/workflow.md"
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

# === Section D — Pipeline correctness: Phase 4.0 + 5.6 verify-only + 5.7 deleted ===

@test "Phase 4.0 exists — compose+commit BUILD-LOG before /ship" {
  grep -qE '^### 4\.0: Compose .{1,4} commit BUILD-LOG' "$SKILL_FILE"
}

@test "Phase 4.0 commits BUILD-LOG without pushing (push lives in /ship at 4.2)" {
  awk '/^### 4\.0:/,/^### 4\.1:/' "$SKILL_FILE" > /tmp/phase40-section.txt
  grep -qE 'git commit -m "chore\(build-log\): record' /tmp/phase40-section.txt
  grep -qiE 'No .git push' /tmp/phase40-section.txt
}

@test "Phase 4.0 new BUILD-LOG entry shape omits explicit PR row" {
  awk '/^### 4\.0:/,/^### 4\.1:/' "$SKILL_FILE" > /tmp/phase40-section.txt
  grep -qiE 'No PR row in new entries' /tmp/phase40-section.txt
}

@test "Phase 5.6 is verify-only (no longer the canonical compose path)" {
  grep -qE '^### 5\.6: Verify Phase 4\.0' "$SKILL_FILE"
}

@test "Phase 5.6 looks for the chore(build-log) commit via git log --grep" {
  awk '/^### 5\.6:/,/^## Phase 5\.8:/' "$SKILL_FILE" > /tmp/phase56-section.txt
  grep -qE 'git log .*origin/\$\{BASE\}\.\.HEAD' /tmp/phase56-section.txt
  grep -qE 'grep="\^chore\(build-log\): record"' /tmp/phase56-section.txt
}

@test "Phase 5.6 fallback path re-watches CI (preserved from old 5.7 logic)" {
  awk '/^### 5\.6:/,/^## Phase 5\.8:/' "$SKILL_FILE" > /tmp/phase56-section.txt
  grep -qE 'gh run watch' /tmp/phase56-section.txt
}

@test "Phase 5.7 section header is deleted (no '### 5.7:' subsection)" {
  ! grep -qE '^### 5\.7:' "$SKILL_FILE"
}

@test "Phase 5.7 has no top-level heading either (no '## Phase 5.7:')" {
  ! grep -qE '^## Phase 5\.7:' "$SKILL_FILE"
}

@test "Phase 5.3 carries the watch-every-push guarantee folded in from 5.7" {
  awk '/^### 5\.3:/,/^### 5\.3\.5:/' "$SKILL_FILE" > /tmp/phase53-section.txt
  grep -qiE 'watch.every.push guarantee' /tmp/phase53-section.txt
  grep -qiE 'folded in from defunct Phase 5\.7' /tmp/phase53-section.txt
}

@test "workflow.md diagram reflects 4.0 + dropped 5.7" {
  grep -qE '4\.0 .{0,10}compose .{0,5} commit BUILD-LOG' "$WORKFLOW_FILE"
  ! grep -qE '5\.7\s+re-watch CI after the 5\.6 push' "$WORKFLOW_FILE"
}

# === Section E — no-silent-scope-down prohibition block ===
#
# Guards the `## Non-negotiable: run the full pipeline` block (+ its Phase 0
# one-liner + the workflow.md coherence line) against a future edit silently
# deleting or weakening it. The load-bearing test is the anti-bias pair: the
# block must frame deviation as an EXCEPTION (positive grep) while the forbidden
# routine per-run applicability beat stays ABSENT (negative greps). All greps
# are pinned to the exact prose committed in Tasks 1 + 2.

@test "Section E: prohibition block header present" {
  grep -qE '^## Non-negotiable: run the full pipeline' "$SKILL_FILE"
}

@test "Section E: no-discretion phrasing present" {
  # The block removes the agent's discretion to hand-roll a lighter flow and
  # states the unconditional run-everything default.
  grep -qiE 'no discretion to hand-roll a lighter flow' "$SKILL_FILE"
  grep -qiE 'every phase, every task' "$SKILL_FILE"
  grep -qiE 'no matter how small' "$SKILL_FILE"
}

@test "Section E: anti-bias phrasing present AND forbidden step absent" {
  # Positive: deviation is framed strictly as an exception routed through
  # AskUserQuestion, never a routine gate.
  grep -qiE 'single exception' "$SKILL_FILE"
  grep -qiE 'ask, never act' "$SKILL_FILE"
  # Anchored to the block region — AskUserQuestion appears elsewhere in the
  # skill (Phase 3 halt etc.), so a file-wide grep would be trivially true.
  awk '/^## Non-negotiable: run the full pipeline/,/^## Architecture/' "$SKILL_FILE" \
    | grep -q 'AskUserQuestion'
  # Negative (load-bearing — D2/D5): no routine per-run applicability beat.
  ! grep -qiE 'assess pipeline applicability' "$SKILL_FILE"
  ! grep -qiE 'Step 0\.1' "$SKILL_FILE"
}

@test "Section E: AskUserQuestion template options present" {
  # All three ordered escape-hatch options must exist.
  grep -qE 'Run the full pipeline \(Recommended\)' "$SKILL_FILE"
  grep -qE 'Run a reduced flow' "$SKILL_FILE"
  # Option 2 requires enumerating exactly what gets dropped + why.
  grep -qiE 'enumerate.*EXACTLY which' "$SKILL_FILE"
  grep -qiE 'would be dropped and WHY' "$SKILL_FILE"
  grep -qE '^  3\. Abort' "$SKILL_FILE"
}

@test "Section E: Phase 0 one-liner restatement present" {
  # A line in the Phase 0 region cross-references the top-of-file block.
  awk '/^## Phase 0/,/^### 0\.1/' "$SKILL_FILE" \
    | grep -qE 'Non-negotiable: run the full pipeline'
}

@test "Section E: workflow.md notes full-pipeline-by-default + asks before deviating" {
  # Newlines collapsed so the regex can span wrapped lines (matches the
  # existing Section A/B workflow.md test pattern).
  tr '\n' ' ' < "$WORKFLOW_FILE" \
    | grep -qiE 'pipeline runs in full by default.*asks .*before deviating to a lighter flow'
}

# === Section F — resume-reconcile gate wiring (implement-resume-reconcile) ===
#
# Guards the Step 0 rung-2 reconcile wiring + the Phase 2 subagent-non-clean-
# return note against a future edit that silently drops either. The load-bearing
# pair: rung 2 must CALL the helper before skipping, and on mismatch must
# re-enter Phase 2 rather than skip to Phase 3. All greps pinned to the prose
# committed in Task 2.

@test "Section F: Step 0 rung 2 calls reconcile-task-commits.sh before skipping" {
  # The helper invocation must be present, scoped to the resume-check region
  # (rungs 2–6), not just mentioned somewhere in the file.
  awk '/^### Resume check/,/^## Phase 0/' "$SKILL_FILE" > /tmp/resume-section.txt
  grep -qE 'reconcile-task-commits\.sh "\$FEATURE_DIR"' /tmp/resume-section.txt
}

@test "Section F: rung 2 re-enters Phase 2 on mismatch (does NOT skip to Phase 3)" {
  awk '/^### Resume check/,/^## Phase 0/' "$SKILL_FILE" > /tmp/resume-section.txt
  # Exit 0 → skip to Phase 3; non-zero → do NOT skip, re-enter Phase 2.
  grep -qiE 'do NOT skip to Phase 3' /tmp/resume-section.txt
  grep -qiE 're-enter Phase 2' /tmp/resume-section.txt
  # The loud-surface diagnostic the operator sees.
  grep -qE 'Resume reconcile FAILED' /tmp/resume-section.txt
}

@test "Section F: reconcile trustworthy condition is clean-tree + impl-count >= done-count" {
  awk '/^### Resume check/,/^## Phase 0/' "$SKILL_FILE" > /tmp/resume-section.txt
  grep -qiE 'clean tree.*impl-commit-count|impl-commit-count.*done-count' /tmp/resume-section.txt
}

@test "Section F: Phase 2 note references the next-resume reconcile gate" {
  awk '/^## Phase 2: Implement/,/^## Phase 3:/' "$SKILL_FILE" > /tmp/phase2-section.txt
  # The note must name the gate + explain it lives at Step 0, not the live return.
  grep -qE 'reconcile-task-commits\.sh' /tmp/phase2-section.txt
  grep -qiE 'next.*/ak-build.*resume|next.*invocation.*Step 0|Step 0 rung 2' /tmp/phase2-section.txt
}

@test "Section F: resume-state table row 2 names the reconcile check shape" {
  grep -qE '\| 2 \|.*tasks\.md.*all tasks .done.*reconcile-task-commits\.sh' "$SKILL_FILE"
}

@test "Section F: workflow.md no longer claims tasks.md carries commit SHAs" {
  # The false "per-task status with commit SHAs" claim must be gone, and the
  # reconcile-on-resume behavior mentioned in its place.
  ! grep -qE 'per-task status with commit SHAs' "$WORKFLOW_FILE"
  tr '\n' ' ' < "$WORKFLOW_FILE" \
    | grep -qE 'reconcile-task-commits\.sh'
}

