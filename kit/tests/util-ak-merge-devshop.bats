#!/usr/bin/env bats
# Tests for .claude/skills/devshop/merge-devshop/SKILL.md — the worktree-aware
# devshop merge skill (audit + squash-merge + push + worktree-teardown + cleanup).
#
# The skill is a pure LLM prompt (Markdown), so these are content-validation
# tests: grep its required sections, parser one-liners, and bash logic blocks
# to confirm the prose reflects the contract documented in `/devshop/CLAUDE.md
# § Devshop shipping flow` + `§ Parallel work via linked worktrees`,
# `kit/docs/guide/architecture.md § Doing devshop work`, and
# `kit/docs/guide/workflow.md § Devshop Skill Map`.
#
# Sections:
#   A — Frontmatter + inputs (--branch flag, when-to-invoke shapes).
#   B — Phase 0.1 worktree detection (scans worktree list, filters to feature
#       branches ahead of origin/main, handles zero/one/multi candidates).
#   C — Phase 0.2 FEATURE regex (regression: six prefixes, # delimiter not |,
#       empty-FEATURE guard — codified by Audit 1, 2026-05-07).
#   D — Phase 0.3 format spec (bullet-led, compressed per-commit list, git reflog
#       recoverability) + 0.3 mechanical commands address branch by name.
#   E — Phase 0.5 approval gate (approve/edit/cancel).
#   F — Phase 1 invokes the audit orchestrator.
#   G — Phase 2 squash routed via $GIT_CMD ($WORKTREE_PATH-aware); NOT
#       legacy `git merge --squash` on main.
#   H — Phase 3 ff-merges + pushes + workflow-scope detection.
#   I — Phase 4.1 tree-equality + 4.2 worktree teardown ORDERED before
#       branch -D, --force required after deinit.
#   J — Phase 5 release-hint handoff.
#   K — Cross-doc coherence: CLAUDE.md / workflow.md / architecture.md
#       reflect the worktree-aware flow.
#
# Behavior tests (running the LLM end-to-end) are out of scope; this proves
# the prompt reflects the contract.

setup() {
  load helpers/setup
  # Canonical location: /devshop/.claude/skills/devshop/<short-name>/SKILL.md
  # (symlinked to /devshop/.claude/skills/ak-<short-name> for /-autocomplete
  # discovery via kit/scripts/sync/create-devshop-symlinks.sh).
  SKILL_FILE="$TESTS_DIR/../../.claude/skills/devshop/merge-devshop/SKILL.md"
  CLAUDE_FILE="$TESTS_DIR/../../CLAUDE.md"
  WORKFLOW_FILE="$TESTS_DIR/../docs/guide/workflow.md"
  ARCHITECTURE_FILE="$TESTS_DIR/../docs/guide/architecture.md"
  # Do NOT defensively skip when SKILL.md is missing — a rename/move/delete is
  # precisely the regression this file exists to catch.
}

# === SKILL.md exists ===

@test "SKILL.md exists at the expected path" {
  [ -f "$SKILL_FILE" ]
}

# === Section A — Frontmatter + inputs ===

@test "frontmatter name is ak-merge-devshop (drives slash-command autocomplete)" {
  grep -qE '^name: ak-merge-devshop$' "$SKILL_FILE"
}

@test "frontmatter description names bullet-led summary (not 'prose summary')" {
  awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'bullet-led'
  ! awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'prose summary'
}

@test "frontmatter description names compressed per-commit bullet list (not 'verbatim per-commit history')" {
  awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'compressed per-commit bullet list'
  ! awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'verbatim per-commit history'
}

@test "frontmatter description names git reflog as the SHA recovery path" {
  awk '/^---$/{c++; next} c==1' "$SKILL_FILE" | grep -q 'git reflog'
}

@test "Inputs section documents --branch <name> flag" {
  awk '/^## Inputs/,/^---/' "$SKILL_FILE" | grep -qE '\*\*`--branch <name>`\*\*'
}

@test "Inputs explains --branch is for multi-worktree disambiguation" {
  awk '/^## Inputs/,/^---/' "$SKILL_FILE" | grep -qiE 'multiple|disambiguat'
}

@test "Inputs section documents --source-worktree <path> flag" {
  awk '/^## Inputs/,/^---/' "$SKILL_FILE" | grep -qE '\*\*`--source-worktree <path>`\*\*'
}

@test "Inputs --source-worktree names the bypass scenario (parallel WIP blocks branch-switch)" {
  awk '/^## Inputs/,/^---/' "$SKILL_FILE" | grep -qiE 'parallel.*session|WIP.*blocks|cannot be.*cleanly switched'
}

@test "Phase 0.1 implements --source-worktree short-circuit (BRANCH derives from worktree HEAD)" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE '\$SOURCE_WORKTREE_ARG'
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'git -C "?\$WORKTREE_PATH"? branch --show-current'
}

@test "Phase 0.1 --source-worktree refuses when path is not a registered worktree" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE 'not a registered git worktree|worktree list --porcelain'
}

@test "Phase 0.1 --source-worktree refuses when path does not exist on disk" {
  # First of three guard predicates — the path must exist as a directory
  # before any other check runs. Otherwise downstream `git -C` calls would
  # silently no-op against the wrong working tree.
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE '! -d "\$SOURCE_WORKTREE_ARG"|path does not exist'
}

@test "Phase 0.1 --source-worktree refuses when the worktree is on main/master/detached HEAD" {
  # Second guard — the worktree must be on a feature branch (NOT main, NOT
  # master, NOT detached HEAD). Auditing the worktree's HEAD via `git -C
  # branch --show-current` and refusing on empty/main/master.
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE 'must be on a feature branch|"\$BRANCH" = "main"|detached HEAD'
}

@test "Phase 0.1 --source-worktree refuses when the worktree has no commits ahead of origin/main" {
  # Third guard — refuse when nothing to merge. Defense-in-depth even though
  # the operator presumably wouldn't pass --source-worktree on an unchanged
  # branch; the empty-range check is cheap.
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE 'no commits ahead of origin/main|rev-list --count "origin/main\.\.\$BRANCH"'
}

@test "Phase 3 has a --source-worktree branch that pushes via git -C WORKTREE_PATH push origin HEAD:main" {
  awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" \
    | grep -qE 'git -C "?\$WORKTREE_PATH"? push origin HEAD:main'
}

@test "Phase 3 --source-worktree path skips the /devshop checkout main + ff-merge" {
  # The default path runs `git checkout main` + `git merge --ff-only`. The
  # --source-worktree path must NOT do that — /devshop's branch stays
  # untouched. Verify the Phase 3 narrative names this contract explicitly.
  # Three independent `grep -q` calls (NOT a single OR) so any missing
  # dimension fails the test — mirrors the Phase 4.2 test's shape and avoids
  # the same loose-OR anti-pattern the same commit refactored away from.
  # `tr -d '\n'` to collapse multi-line markdown prose into a single line
  # so multi-line phrases like "never touch\n  /devshop" still match.
  local section
  section=$(awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" | tr -d '\n')

  # Dimension 1: explicit promise that /devshop's branch stays untouched.
  echo "$section" | grep -qiE 'never touch.*devshop|stays untouched|won.t touch' \
    || { echo "Phase 3 missing '/devshop never touched' guarantee"; false; }

  # Dimension 2: explicit description of the direct-push mechanism.
  echo "$section" | grep -qiE 'push.*directly.*from.*worktree|push origin HEAD:main' \
    || { echo "Phase 3 missing 'push directly from worktree' mechanism"; false; }

  # Dimension 3: explicit skip-the-checkout-and-ff branching.
  echo "$section" | grep -qiE 'skip the checkout|skip.*ff-merge|two-path' \
    || { echo "Phase 3 missing 'skip checkout + ff-merge' branching"; false; }
}

@test "When-to-invoke describes three auto-detection shapes" {
  # /devshop on the feature branch directly (legacy direct-checkout)
  awk '/^## When to invoke/,/^## Inputs/' "$SKILL_FILE" \
    | grep -qiE 'feature branch directly|main worktree'
  # /devshop on main with a linked worktree
  awk '/^## When to invoke/,/^## Inputs/' "$SKILL_FILE" \
    | grep -qiE 'linked worktree.*feature|on `main`.*linked worktree'
  # Multiple linked worktrees → --branch required
  awk '/^## When to invoke/,/^## Inputs/' "$SKILL_FILE" \
    | grep -qiE 'multiple.*worktree'
}

@test "Do-NOT-invoke list dropped the 'already on main' refusal (worktree-aware now)" {
  # Old line ("Already on main — there's nothing to merge") is gone; main is
  # now a legitimate starting point when a feature worktree is present.
  ! awk '/^Do NOT invoke when:/,/^The skill auto-detects/' "$SKILL_FILE" \
    | grep -qiE 'Already on .?main'
}

@test "Do-NOT-invoke list still warns about dirty trees + non-/devshop repos" {
  awk '/^Do NOT invoke when:/,/^The skill auto-detects/' "$SKILL_FILE" \
    | grep -qiE 'working tree dirty'
  awk '/^Do NOT invoke when:/,/^The skill auto-detects/' "$SKILL_FILE" \
    | grep -qiE 'project.*repo.*not.*/devshop|/devshop.*projects use'
}

# === Section B — Phase 0.1 worktree detection ===

@test "Phase 0.1 header mentions worktree detection" {
  grep -qE '^### 0\.1: .*[Ww]orktree' "$SKILL_FILE"
}

@test "Phase 0.1 scans git worktree list --porcelain" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'git worktree list --porcelain'
}

@test "Phase 0.1 filters to feature-typed branches (six known prefixes)" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE '\(feat\|.*feature\|.*fix\|.*docs\|.*chore\|.*refactor\)'
}

@test "Phase 0.1 filters to branches ahead of origin/main" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'rev-list --count.*origin/main'
}

@test "Phase 0.1 excludes /devshop's main worktree itself from the scan" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'wt != "/devshop"|skipping.*main worktree'
}

@test "Phase 0.1 handles zero candidates (explicit refusal message)" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE 'no feature worktree|N -eq 0'
}

@test "Phase 0.1 handles single candidate (implicit selection)" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'N.*-eq.*1|single|exactly one|elif \[ "\$N" -eq 1'
}

@test "Phase 0.1 handles multi-candidate (require --branch)" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE 'multiple feature worktrees|pass --branch'
}

@test "Phase 0.1 still refuses on dirty working tree (now via git -C \$TARGET)" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'git -C "?\$TARGET"? status --porcelain'
}

@test "Phase 0.1 still refuses when branch has nothing to squash" {
  # Defense-in-depth check for the direct-checkout (legacy) path.
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'rev-list --count.*MERGE_BASE'
}

@test "Phase 0.1 sets both BRANCH and WORKTREE_PATH variables" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE '^BRANCH=|BRANCH="\$'
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qE 'WORKTREE_PATH=""|WORKTREE_PATH=\$'
}

@test "Phase 0.1 documents the post-condition (BRANCH + WORKTREE_PATH downstream consumers)" {
  awk '/^### 0\.1:/,/^### 0\.2:/' "$SKILL_FILE" \
    | grep -qiE 'subsequent phases consult|After 0\.1.*BRANCH'
}

# === Section C — Phase 0.2 FEATURE regex (regression from Audit 1) ===

@test "Phase 0.2 FEATURE regex handles all six known type prefixes" {
  awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE 'feat\|feature\|fix\|docs\|chore\|refactor'
}

@test "Phase 0.2 sed uses # delimiter (not |) to avoid alternation conflict" {
  # The bug Audit 1 (2026-05-07) codified: sed -E 's|^(feat|...)/||' parses
  # the inner | as the delimiter. The fix uses # instead.
  awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE "sed -E 's#\^.*\)/##'"
  ! awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE "sed -E 's\|\^.*\)/\|\|'"
}

@test "Phase 0.2 has empty-FEATURE guard (fails loudly on unrecognized prefix)" {
  awk '/### 0\.2:/,/### 0\.3:/' "$SKILL_FILE" \
    | grep -qE '\[ -z "\$FEATURE" \].*\[ "\$FEATURE" = "\$BRANCH" \]'
}

# === Section D — Phase 0.3 format spec + worktree-safe commands ===

@test "Phase 0.3 format spec describes bullet-led summary sections" {
  awk '/### 0\.3:/,/### 0\.4:/' "$SKILL_FILE" | grep -q 'bullet-led'
}

@test "Phase 0.3 format spec mentions ## Squashed commits section header" {
  awk '/### 0\.3:/,/### 0\.4:/' "$SKILL_FILE" | grep -q '## Squashed commits'
}

@test "Phase 0.3 format spec mentions git reflog for SHA recovery" {
  awk '/### 0\.3:/,/### 0\.4:/' "$SKILL_FILE" | grep -q 'git reflog'
}

@test "Phase 0.3 explanatory section explicitly retires verbatim format" {
  grep -qE '#### Why compressed bullets, not verbatim bodies' "$SKILL_FILE"
}

@test "Phase 0.3 mechanical commands address branch by name (\$BRANCH not HEAD)" {
  # The composer's reference commands and the 'For mechanical input' block
  # must use $BRANCH because /devshop's HEAD is on main when WORKTREE_PATH set.
  awk '/^For mechanical input:/,/^```$/' "$SKILL_FILE" \
    | grep -qE 'origin/main\.\.\$BRANCH|origin/main\.\.\."?\$BRANCH'
  ! awk '/^For mechanical input:/,/^```$/' "$SKILL_FILE" \
    | grep -qE 'origin/main\.\.HEAD'
}

# === Section E — Phase 0.5 approval gate ===

@test "Phase 0.5 uses AskUserQuestion with approve/edit/cancel options" {
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -q 'AskUserQuestion'
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -qE '\*\*Approve\*\*'
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -qE '\*\*Edit\*\*'
  awk '/### 0\.5:/,/^---$|^## /' "$SKILL_FILE" | grep -qE '\*\*Cancel\*\*'
}

# === Section E0 — Phase 0.4.5 adversarial readability check ===

@test "Phase 0.4.5 exists as a sub-phase header between 0.4 and 0.5" {
  grep -qE '^### 0\.4\.5: .*[Aa]dversarial.*readability' "$SKILL_FILE"
  # Ordering: 0.4.5 must appear after 0.4 and before 0.5
  local h45 h5
  h45=$(grep -nE '^### 0\.4\.5:' "$SKILL_FILE" | head -1 | cut -d: -f1)
  h5=$(grep -nE '^### 0\.5:' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$h45" ]
  [ -n "$h5" ]
  [ "$h45" -lt "$h5" ]
}

@test "Phase 0.4.5 invokes the SHARED adversarial-review.sh engine (no duplicated logic)" {
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qE 'adversarial-review\.sh'
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qE 'prTextHygieneReason'
}

@test "Phase 0.4.5 selects the squash surface via DEVSHOP_HYGIENE_SURFACE=squash env var" {
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qE 'DEVSHOP_HYGIENE_SURFACE=squash'
}

@test "Phase 0.4.5 passes the tempfile + branch via DEVSHOP_HYGIENE_MESSAGE_FILE + DEVSHOP_HYGIENE_BRANCH" {
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qE 'DEVSHOP_HYGIENE_MESSAGE_FILE=.*squash-message-\$\{FEATURE\}\.txt'
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qE 'DEVSHOP_HYGIENE_BRANCH=.*BRANCH'
}

@test "Phase 0.4.5 captures verdict into HYGIENE_VERDICT (PASS/FAIL) for Phase 0.5" {
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qE 'HYGIENE_VERDICT'
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qE 'HYGIENE_OUTPUT'
}

@test "Phase 0.4.5 explains WHY (one place, no duplication) — and names what it catches" {
  # Surfaces jargon (Tier B / Phase N / polish) + >72 chars + mechanism-led
  # subjects as the specific failure modes; explains the shared-engine
  # rationale so a future editor doesn't fork the rule into a second engine.
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qiE 'mechanism-led|internal jargon|72.?char'
  awk '/^### 0\.4\.5:/,/^### 0\.5:/' "$SKILL_FILE" \
    | grep -qiE 'shared|same.*engine|one place'
}

@test "Phase 0.5 routes on HYGIENE_VERDICT (PASS vs FAIL framing)" {
  awk '/### 0\.5:/,/^---$|^## Phase 1/' "$SKILL_FILE" \
    | grep -qE 'HYGIENE_VERDICT.*PASS|`HYGIENE_VERDICT=PASS`'
  awk '/### 0\.5:/,/^---$|^## Phase 1/' "$SKILL_FILE" \
    | grep -qE 'HYGIENE_VERDICT.*FAIL|`HYGIENE_VERDICT=FAIL`'
}

@test "Phase 0.5 FAIL branch offers 'Approve anyway' as the explicit override" {
  awk '/### 0\.5:/,/^---$|^## Phase 1/' "$SKILL_FILE" \
    | grep -qE 'Approve anyway'
}

@test "Phase 0.5 'Approve anyway' lands a Hygiene-Override trailer in the commit body" {
  awk '/### 0\.5:/,/^---$|^## Phase 1/' "$SKILL_FILE" \
    | grep -qE 'Hygiene-Override:'
}

@test "Phase 0.5 Edit loop re-runs Phase 0.4.5 after each edit (verdict can flip)" {
  awk '/### 0\.5:/,/^---$|^## Phase 1/' "$SKILL_FILE" \
    | grep -qE 're-run.*0\.4\.5|re-runs the hygiene check'
}

# === Section F — Phase 1 audit ===

@test "Phase 1 invokes /ak-check-docs-and-tests (orchestrator, not /ak-tests-review directly)" {
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" | grep -qE 'ak-check-docs-and-tests'
}

@test "Phase 1 halts on high-severity findings" {
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qE '[Hh]igh-severity.*halt|halt.*high'
}

@test "Phase 1 interactively pauses on medium-severity findings (devshop Phase 5.8 equivalent)" {
  # Devshop branches don't run /ak-build Phase 5.8 (project-only). The
  # equivalent catch-rung lives here — Phase 1 fires AskUserQuestion on
  # medium findings so the operator can polish in-branch before the squash.
  # Codified from home-os-skill-polish-batch merge (2026-05-20).
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qiE 'medium-severity|interactive pause|AskUserQuestion'
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qE 'DEVSHOP_AUDIT_MEDIUM_POLICY|Phase 5\.8'
}

# === Section F2 — Phase 1.0 rebase-before-audit (ak-merge-rebase-before-audit) ===

@test "Phase 1.0 rebases onto the merge target BEFORE the audit invocation (ordering)" {
  # Core invariant: a stale-base worktree must be rebased BEFORE
  # /ak-check-docs-and-tests runs, or the audit's two-dot range diffs across
  # diverged histories and reports phantom reverts. Codified from the
  # go-live-prod-url-extraction merge (2026-05-28). The rebase is now driven by
  # the virtiofs-rebase.sh helper call (mechanized ladder); assert the helper
  # call precedes the audit.
  local rebase_line audit_line
  rebase_line=$(grep -nE 'virtiofs-rebase\.sh "\$ANCHOR" "\$WORKTREE_PATH"' "$SKILL_FILE" | head -1 | cut -d: -f1)
  audit_line=$(grep -nE 'skill: "ak-check-docs-and-tests"' "$SKILL_FILE" | head -1 | cut -d: -f1)
  [ -n "$rebase_line" ]
  [ -n "$audit_line" ]
  [ "$rebase_line" -lt "$audit_line" ]
}

@test "Phase 1.0 invokes the virtiofs-rebase.sh helper with \$ANCHOR + \$WORKTREE_PATH" {
  # The mechanized ladder (rebase → checkStat-retry → merge-fallback) lives in
  # kit/scripts/virtiofs-rebase.sh; Phase 1.0 calls it with the pre-selected
  # anchor (arg1) and the worktree path (arg2, empty → git runs in cwd).
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qE 'bash /devshop/kit/scripts/virtiofs-rebase\.sh "\$ANCHOR" "\$WORKTREE_PATH"'
}

@test "Phase 1.0 anchor-selects between origin/main and local main" {
  # Same anchor detection that used to live in Phase 2 — moved ahead of the
  # audit so the rebase target is decided before the audit range is computed.
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qE 'git rev-list --count origin/main\.\.main'
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qE 'ANCHOR=(origin/main|main)'
}

@test "Phase 1.0 documents the virtiofs phantom-error → mechanized merge fallback" {
  # The phantom 'local changes would be overwritten' recovery (checkStat retry →
  # merge fallback) is now mechanized in virtiofs-rebase.sh; Phase 1.0 still
  # documents the flake + names the merge fallback as part of the helper's ladder.
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qiE 'phantom|virtiofs|stat-cache'
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qE 'git merge "\$ANCHOR" --no-edit'
}

@test "Phase 1.0 handles the helper's conflict exit codes (10 rebase / 11 merge)" {
  # The helper returns genuine conflicts to the caller: exit 10 = rebase
  # conflict (resolve → add → rebase --continue); exit 11 = merge-fallback
  # conflict (resolve → add → commit -F merge-msg). Assert both branches exist
  # so a future edit can't silently drop the caller-side resolution path.
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qE '"\$\{GIT_CMD\[@\]\}" rebase --continue'
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qE '"\$\{GIT_CMD\[@\]\}" commit -F /tmp/merge-commit-msg\.txt'
}

@test "Phase 1.0 documents the inline checkStat=minimal retry as part of the helper ladder" {
  # The checkStat=minimal -c core.trustctime=false rebase retry is the FIRST
  # rung of the helper's recovery ladder for the virtiofs phantom flake; the
  # merge fallback is the second. Inline -c form only — never repo-global config.
  # Codified from merge-rebase-racy-git-remedy (2026-05-29), mechanized in
  # virtiofs-rebase-auto-switch.
  awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -qE 'core\.checkStat=minimal -c core\.trustctime=false'
  # Ordering invariant: the checkStat retry precedes the merge fallback in the
  # prose describing the helper's ladder.
  local checkstat_line merge_line
  checkstat_line=$(awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -nE 'core\.checkStat=minimal -c core\.trustctime=false' \
    | head -1 | cut -d: -f1)
  merge_line=$(awk '/^### 1\.0:/,/^### 1\.1:/' "$SKILL_FILE" \
    | grep -nE 'git merge "\$ANCHOR" --no-edit' | head -1 | cut -d: -f1)
  [ -n "$checkstat_line" ]
  [ -n "$merge_line" ]
  [ "$checkstat_line" -lt "$merge_line" ]
}

@test "Phase 1.1 audit is cwd-independent: resolved SHA range + absolute feature-dir" {
  # The Bash tool's cwd can reset to /devshop between calls, so a bare
  # cd-into-the-worktree does NOT persist into the sub-skill. Phase 1.1 drives
  # the audit by explicit absolute paths + a resolved SHA range instead.
  # Resolves $ANCHOR and the worktree HEAD to SHAs:
  awk '/^### 1\.1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qE 'ANCHOR_SHA=\$\(git rev-parse "\$ANCHOR"\)'
  awk '/^### 1\.1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qE 'HEAD_SHA=\$\(git -C "\$TARGET" rev-parse HEAD\)'
  # Passes the absolute feature-dir + resolved SHA range to the audit skill
  # (\-\- so grep doesn't read the leading dashes as options):
  awk '/^### 1\.1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qE '\-\-feature-dir \$\{FEATURE_DIR_ABS\}'
  awk '/^### 1\.1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qE '\-\-range \$\{ANCHOR_SHA\}\.\.\$\{HEAD_SHA\}'
}

@test "Phase 1.1 documents the cwd-reset hazard (do not rely on cd persisting)" {
  awk '/^### 1\.1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qiE 'cwd.*reset|reset.*cwd|did NOT persist|does not reliably persist'
}

# === Section G — Phase 2 worktree-routed squash ===

@test "Phase 2 introduces the GIT_CMD array that routes via -C when WORKTREE_PATH set" {
  # Array form (not a string) — zsh does not word-split an unquoted string var,
  # so a string GIT_CMD="git -C path" makes "$GIT_CMD ..." exec a bogus binary
  # (exit 127). See the regression guard below.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'GIT_CMD=\(git\)'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'GIT_CMD=\(git -C "\$WORKTREE_PATH"\)'
}

@test "Phase 2 uses the GIT_CMD array on reset --soft + commit (no rebase — that moved to Phase 1.0)" {
  # The rebase moved to Phase 1.0 (rebase-before-audit). Phase 2 only collapses
  # the already-rebased branch via soft-reset + commit. The anchor can be
  # `origin/main` or `"$ANCHOR"` — the test pins the GIT_CMD-array invariant.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE '"\$\{GIT_CMD\[@\]\}" reset --soft (origin/main|"\$ANCHOR")'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE '"\$\{GIT_CMD\[@\]\}" commit -F'
  # Regression guard: the rebase must NOT be in Phase 2 anymore.
  ! awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE '^"\$\{GIT_CMD\[@\]\}" rebase'
}

@test "regression: no bash code fence uses the string form \$GIT_CMD (zsh word-split bug)" {
  # zsh — the Bash tool's shell — does NOT word-split an unquoted string var, so
  # `GIT_CMD="git -C path"` + `$GIT_CMD rebase` execs a binary literally named
  # "git -C path" and fails with exit 127 (worked incidents 3dc73689, 47b0ac95).
  # Every executable usage must be the array form "${GIT_CMD[@]}". This guard
  # scans ONLY bash code fences (prose counter-examples are allowed to mention
  # the broken string form). The string expansion is `$GIT_CMD` (no brace); the
  # array is `${GIT_CMD[@]}` (brace), so `\$GIT_CMD` matches only the bad form.
  ! awk '/^```bash/{f=1;next} /^```/{f=0} f' "$SKILL_FILE" \
    | grep -qE '\$GIT_CMD'
  # And the broken string assignment must never reappear in a bash fence:
  ! awk '/^```bash/{f=1;next} /^```/{f=0} f' "$SKILL_FILE" \
    | grep -qE 'GIT_CMD="git'
}

@test "Phase 2 anchor-selects between origin/main and local main" {
  # When local main carries unpushed commits (release-in-flight), the squash
  # anchor MUST be local main — otherwise Phase 3's FF-merge fails after the
  # squash sits on the wrong base. Codified from home-os-skill-polish-batch
  # merge (2026-05-20). The detection block uses `git rev-list --count
  # origin/main..main` to pick the anchor.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'git rev-list --count origin/main\.\.main'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'ANCHOR=(origin/main|main)'
}

@test "Phase 2 documents that the rebase already ran in Phase 1.0" {
  # Phase 2's soft-reset is correct only because Phase 1.0 rebased the branch
  # onto $ANCHOR first. The phantom-error recipe itself lives in Phase 1.0
  # (see Section F2); Phase 2 records the dependency.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qiE 'already rebased the branch|rebased .* onto .ANCHOR|Phase 1\.0 already'
}

@test "Phase 2 does NOT use git merge --squash (legacy on-main approach)" {
  # The old pre-soft-reset shape ran `git merge --squash <branch>` while on
  # main and then `git commit -F`. That triggered check-branch-not-main.sh
  # and forced an operator handoff. The new shape avoids both.
  ! awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'git merge --squash'
}

# === Section G2 — Phase 2.5 full-suite loud-failure gate ===

@test "Phase 2.5 computes the verdict from a not-ok count (not eyeballed output)" {
  # Codified from the 2026-05-27 incident: a buried `not ok` in a ~1500-line
  # suite read as a pass because the tail was green, leaving main red. The
  # gate must grep a count, not rely on the agent reading output.
  local section
  section=$(awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE")
  echo "$section" | grep -qE 'FAILED=.*grep -c'
  echo "$section" | grep -q 'not ok'
}

@test "Phase 2.5 halts (exit 1) when any test fails" {
  local section
  section=$(awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE")
  echo "$section" | grep -qE 'FAILED'
  echo "$section" | grep -qE 'exit 1'
}

@test "Phase 2.5 documents the pre-existing-failure → separate fix branch rule" {
  awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qiE 'pre-existing on .?origin/main|separate .?fix/.? branch'
}

@test "Phase 2.5 resolves \$BATS_CWD to an absolute path when WORKTREE_PATH is set" {
  # HEAD-pin guard half 1: never let `--show-toplevel` re-resolve implicitly
  # at run time (it would follow whatever /devshop currently points at under a
  # parallel merge). `pwd -P` resolves symlinks so the SHA comparison is
  # tree-exact.
  awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'cd "\$WORKTREE_PATH" && pwd -P'
}

@test "Phase 2.5 pins EXPECTED_SHA to the \$BRANCH squash commit" {
  # HEAD-pin guard half 2: the squash Phase 2 created IS the branch tip;
  # `git rev-parse <branch>` resolves the ref regardless of current checkout.
  awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'EXPECTED_SHA=\$\(git -C "\$BATS_CWD" rev-parse "\$BRANCH"\)'
}

@test "Phase 2.5 asserts HEAD == EXPECTED_SHA BEFORE the suite" {
  # A wrong checkout should never run at all. The before-assertion lives above
  # the bats invocation (BATS_OUT=$(mktemp)).
  local section before_line bats_line
  section=$(awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE")
  before_line=$(echo "$section" | grep -nE 'HEAD_NOW=\$\(git -C "\$BATS_CWD" rev-parse HEAD\)' | head -1 | cut -d: -f1)
  bats_line=$(echo "$section" | grep -nE 'kit/tests/lib/bats-core/bin/bats kit/tests/' | head -1 | cut -d: -f1)
  [ -n "$before_line" ]
  [ -n "$bats_line" ]
  [ "$before_line" -lt "$bats_line" ]
}

@test "Phase 2.5 re-asserts HEAD == EXPECTED_SHA AFTER the suite (mid-flow flip)" {
  # The ~60-90s suite is the largest race window; a before-only check misses a
  # flip that lands during the run. The after-assertion lives below the bats
  # invocation and halts on mismatch ("verdict untrustworthy" / "HEAD moved").
  local section after_line bats_line
  section=$(awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE")
  bats_line=$(echo "$section" | grep -nE 'kit/tests/lib/bats-core/bin/bats kit/tests/' | head -1 | cut -d: -f1)
  after_line=$(echo "$section" | grep -nE 'HEAD_AFTER=\$\(git -C "\$BATS_CWD" rev-parse HEAD\)' | head -1 | cut -d: -f1)
  [ -n "$after_line" ]
  [ -n "$bats_line" ]
  [ "$after_line" -gt "$bats_line" ]
  echo "$section" | grep -qiE 'HEAD moved during the suite|verdict untrustworthy'
}

@test "Phase 2.5 documents the parallel-merge HEAD-flip race rationale" {
  # Names the race and points at a worked incident (1d343bf, 2026-05-28) +
  # the Phase 3 mirror (calibration-and-task-phases, 2026-05-20).
  awk '/^## Phase 2\.5:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qiE 'parallel.merge|1d343bf|calibration-and-task-phases'
}

# === Section H — Phase 3 ff-merge + push ===

@test "Phase 3 fast-forwards main to the feature branch's squash commit" {
  awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" \
    | grep -qE 'git merge --ff-only "\$BRANCH"|git merge --ff-only \$BRANCH'
}

@test "Phase 3 explains why ff-merge dodges the on-main commit hook" {
  awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" \
    | grep -qE 'does not create a new commit|no NEW commit|no new commit|never fires'
}

@test "Phase 3 pushes to origin/main" {
  awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" | grep -qE 'git push origin main'
}

@test "Phase 3 has workflow-scope detection mirroring /ak-build Phase 5.4" {
  awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" \
    | grep -qE '\.github/workflows/'
}

# === Section I — Phase 4 tree-equality + worktree teardown + cleanup ===

@test "Phase 4.1 keeps the tree-equality check (trivially true under ff-merge, but defense-in-depth)" {
  awk '/### 4\.1:/,/### 4\.2:/' "$SKILL_FILE" | grep -qE 'git diff.*main.*BRANCH'
}

@test "Phase 4.2 tears down worktree BEFORE branch -D when WORKTREE_PATH set" {
  # Locate canonical code-block commands and assert ordering. Filter out
  # backticked prose mentions (which appear inline as `git branch -D`) so
  # only actual bash invocations match. Pattern: line begins with optional
  # whitespace followed by `git ` (no leading backtick).
  local section deinit_line worktree_remove_line branch_d_line
  section=$(awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE")
  deinit_line=$(echo "$section" | grep -nE '^[[:space:]]*git -C [^`]*submodule deinit' | head -1 | cut -d: -f1)
  worktree_remove_line=$(echo "$section" | grep -nE '^[[:space:]]*git worktree remove --force' | head -1 | cut -d: -f1)
  branch_d_line=$(echo "$section" | grep -nE '^[[:space:]]*git branch -D' | head -1 | cut -d: -f1)
  [ -n "$deinit_line" ]
  [ -n "$worktree_remove_line" ]
  [ -n "$branch_d_line" ]
  [ "$deinit_line" -lt "$worktree_remove_line" ]
  [ "$worktree_remove_line" -lt "$branch_d_line" ]
}

@test "Phase 4.2 uses git -C \$WORKTREE_PATH for the submodule deinit" {
  awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" \
    | grep -qE 'git -C "?\$WORKTREE_PATH"? submodule deinit'
}

@test "Phase 4.2 submodule deinit uses -f --all flag" {
  awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" \
    | grep -qE 'submodule deinit -f --all'
}

@test "Phase 4.2 spells out --force on worktree remove" {
  awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" \
    | grep -qE 'git worktree remove --force'
}

@test "Phase 4.2 explains why --force is required after deinit" {
  awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" \
    | grep -qiE 'per-worktree submodule registry|safety check.*independently of'
}

@test "Phase 4.2 warns operators to run each teardown step as a separate Bash call (DCG push-force-short false-positive)" {
  # The DCG core.git:push-force-short rule false-positives on compound commands
  # containing BOTH `git push` (any variant) AND a separate `-f` flag elsewhere
  # (rm -f, submodule deinit -f, etc.) — even when no `git push -f` exists in
  # the command. The teardown legitimately uses both (`submodule deinit -f`,
  # `worktree remove --force`) per git-API contract, and may follow a
  # `git push origin --delete` — so the chained shape false-positives reliably.
  # The skill must instruct operators to split — codified from home-os-skill-
  # polish-batch teardown (2026-05-20) where the chained block got DCG-blocked.
  #
  # Three independent `grep -q` calls (NOT a single OR) so any missing dimension
  # of the contract fails the test. The previous OR-shape would pass when only
  # one keyword survived a doc rewrite. Codified from ak-merge-devshop-hardening
  # Audit 2 low finding (2026-05-20).
  local section
  section=$(awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE")

  # Dimension 1: the false-positive framing (not generic "pattern-match").
  echo "$section" | grep -qiE 'false-positive' \
    || { echo "Phase 4.2 missing 'false-positive' framing"; false; }

  # Dimension 2: the named DCG rule (so `dcg explain` resolves it).
  echo "$section" | grep -qE 'push-force-short' \
    || { echo "Phase 4.2 missing 'push-force-short' rule name"; false; }

  # Dimension 3: the separation-of-Bash-calls operator instruction.
  echo "$section" | grep -qiE 'separate.*Bash.*tool call|do not chain' \
    || { echo "Phase 4.2 missing 'separate Bash tool call'/'do not chain' instruction"; false; }
}

@test "Phase 4.2 only runs worktree teardown when WORKTREE_PATH is set" {
  awk '/^### 4\.2:/,/^---$/' "$SKILL_FILE" \
    | grep -qE 'if \[ -n "?\$WORKTREE_PATH"? \]'
}

@test "Phase 4 force-deletes the local feature branch (git branch -D)" {
  awk '/^## Phase 4:/,/^## Phase 5:/' "$SKILL_FILE" | grep -qE 'git branch -D'
}

@test "Phase 4 cleans up the remote branch (git push origin --delete)" {
  awk '/^## Phase 4:/,/^## Phase 5:/' "$SKILL_FILE" | grep -qE 'git push origin --delete'
}

# === Section J — Phase 5 release-hint handoff ===

@test "Phase 5 surfaces release-candidate hint based on conventional-commit prefixes since last tag" {
  awk '/^## Phase 5:/,/^---$|^##.*Idempotence/' "$SKILL_FILE" \
    | grep -qE 'feat|fix|BREAKING'
  awk '/^## Phase 5:/,/^---$|^##.*Idempotence/' "$SKILL_FILE" \
    | grep -qE 'ak-release-devshop'
}

# === Section K — Cross-doc coherence ===

@test "CLAUDE.md § Parallel work via linked worktrees describes worktree-aware merging" {
  grep -qE '\*\*Merging is worktree-aware\*\*' "$CLAUDE_FILE"
}

@test "CLAUDE.md no longer says 'merging requires the main worktree' (retired prose)" {
  ! grep -qE '\*\*Merging requires the main worktree\*\*' "$CLAUDE_FILE"
}

@test "CLAUDE.md does not instruct operator to manually 'git worktree remove' before merging" {
  # Old line: "switch back to /devshop, run /ak-merge-devshop, then `git worktree remove .worktrees/<topic>`"
  ! grep -qE 'run /ak-merge-devshop, then `git worktree remove' "$CLAUDE_FILE"
}

@test "CLAUDE.md mentions --branch <name> for multi-worktree disambiguation" {
  awk '/^\*\*Parallel work via linked worktrees/,/^Bump levels/' "$CLAUDE_FILE" \
    | grep -qE '`--branch <name>`'
}

@test "workflow.md skill table entry mentions worktree-aware detection" {
  grep -E '\/ak-merge-devshop' "$WORKFLOW_FILE" \
    | grep -qiE 'worktree-aware|worktree list|git -C.*WORKTREE_PATH'
}

@test "architecture.md devshop-work section mentions worktree-merge alternative" {
  awk '/^## Doing devshop work/,/^## When devshop changes take effect/' "$ARCHITECTURE_FILE" \
    | grep -qiE 'auto-detect|linked worktree.*git worktree add'
}

# === Section L — Phase 2 rename-plus-symlink detection ===

@test "Phase 2 has a rename-plus-symlink detection block between soft-reset and commit" {
  # The detection block must exist between `reset --soft` and `commit -F` in
  # Phase 2. Verify ordering by line number: soft-reset < detection < commit.
  local section soft_line detect_line commit_line
  section=$(awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE")
  soft_line=$(echo "$section" | grep -nE 'reset --soft' | head -1 | cut -d: -f1)
  detect_line=$(echo "$section" | grep -nE 'Rename-plus-symlink detection' | head -1 | cut -d: -f1)
  commit_line=$(echo "$section" | grep -nE '"\$\{GIT_CMD\[@\]\}" commit -F' | head -1 | cut -d: -f1)
  [ -n "$soft_line" ]
  [ -n "$detect_line" ]
  [ -n "$commit_line" ]
  [ "$soft_line" -lt "$detect_line" ]
  [ "$detect_line" -lt "$commit_line" ]
}

@test "Phase 2 detection scans git diff --cached --name-status for R (rename) entries" {
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'diff --cached --name-status --diff-filter=R'
}

@test "Phase 2 detection compares rename source paths against A (added) entries" {
  # Both --diff-filter=R and --diff-filter=A must appear; comm -12 or similar
  # set-intersection logic must be present.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'diff-filter=R'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'diff-filter=A'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'comm -12'
}

@test "Phase 2 detection unstages on hit via git reset (not git reset --hard)" {
  # On detection, the block runs $GIT_CMD reset (soft unstage), NOT
  # $GIT_CMD reset --hard (which would destroy working tree).
  local section
  section=$(awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE")
  # Must have "${GIT_CMD[@]}" reset inside the detection block
  echo "$section" | grep -qE '"\$\{GIT_CMD\[@\]\}" reset   # unstage'
  # Must NOT have "${GIT_CMD[@]}" reset --hard in the detection block
  # (--hard appears elsewhere in Phase 2 prose, so scope to the detection block)
  local detect_block
  detect_block=$(echo "$section" | awk '/Rename-plus-symlink detection/,/^fi/')
  ! echo "$detect_block" | grep -qE '"\$\{GIT_CMD\[@\]\}" reset --hard'
}

@test "Phase 2 detection surfaces the lint-staged stash bug explanation" {
  local detect_block
  detect_block=$(awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | awk '/Rename-plus-symlink detection/,/^fi/')
  echo "$detect_block" | grep -qiE 'lint-staged'
  echo "$detect_block" | grep -qE 'beyond a symbolic link'
}

@test "Phase 2 detection offers git merge --ff-only as fallback" {
  local detect_block
  detect_block=$(awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | awk '/Rename-plus-symlink detection/,/^fi/')
  echo "$detect_block" | grep -qE 'ff-only|ff-merge'
}

@test "Phase 2 detection requires operator confirmation before ff-merge (not auto-fallback)" {
  # AskUserQuestion or equivalent interactive prompt must appear in the
  # detection flow (per D2: prompt the operator, not auto-fallback).
  local detect_block
  detect_block=$(awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | awk '/Rename-plus-symlink detection/,/^fi/')
  echo "$detect_block" | grep -qiE 'AskUserQuestion'
}

@test "Phase 2 runs a gitleaks compensating gate on the staged squash delta before commit" {
  # (d) defense-in-depth: even an off-convention worktree that skipped `pnpm
  # install` (so in-worktree hooks never armed) can't land a secret on main —
  # Phase 2 scans the staged delta with gitleaks before creating the squash
  # commit. Mirrors .husky/pre-commit's `gitleaks protect --staged --redact`.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'gitleaks protect --staged'
}

@test "Phase 2 gitleaks gate is ordered before the commit -F (halt-before-commit)" {
  # The gate must run AFTER `reset --soft` stages the delta and BEFORE `commit
  # -F`, so a finding halts the merge with nothing committed. Assert line order
  # within the Phase 2 range: the gitleaks line precedes the commit -F line.
  local block gitleaks_line commit_line
  block=$(awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE")
  gitleaks_line=$(printf '%s\n' "$block" | grep -nE 'gitleaks protect --staged' | head -1 | cut -d: -f1)
  commit_line=$(printf '%s\n' "$block" | grep -nE '"\$\{GIT_CMD\[@\]\}" commit -F' | head -1 | cut -d: -f1)
  [ -n "$gitleaks_line" ]
  [ -n "$commit_line" ]
  [ "$gitleaks_line" -lt "$commit_line" ]
}

@test "Phase 2 squash gitleaks gate is cwd-pinned to \$WORKTREE_PATH via a cd subshell" {
  # Regression guard for the Gate 5 low finding: a future edit that drops the
  # `( cd "$WORKTREE_PATH" && gitleaks protect --staged` subshell would make
  # the scan read /devshop's (empty, on-main) index and false-pass when the
  # squash lives in a worktree. Pin the exact cwd-subshell form so that's
  # caught. The literal must contain the cd-into-worktree + the protect call.
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE '\( cd "\$WORKTREE_PATH" && gitleaks protect --staged'
}

@test "Phase 3 ff-merge fallback runs a gitleaks history scan over the constituent range" {
  # The rename-plus-symlink collision corner routes Phase 2 to Phase 3's
  # ff-merge, which lands the branch's commits WITHOUT staging them — so
  # `protect --staged` can't cover it. Phase 3 must scan the commit RANGE
  # ($ANCHOR..$BRANCH) with `gitleaks git --log-opts` before the ff-merge, so
  # the secret net stays unconditional even on this path. Pin the history-scan
  # invocation in the Phase 3 range.
  awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE" \
    | grep -qE 'gitleaks git --redact --log-opts "\$ANCHOR\.\.\$BRANCH"'
}

@test "Phase 3 ff-merge gitleaks scan is ordered before the git merge --ff-only \$BRANCH" {
  # A finding must HALT the ff-merge — assert the scan line precedes the
  # `git merge --ff-only "$BRANCH"` line within the Phase 3 range.
  local block gitleaks_line ffmerge_line
  block=$(awk '/^## Phase 3:/,/^## Phase 4:/' "$SKILL_FILE")
  gitleaks_line=$(printf '%s\n' "$block" | grep -nE 'gitleaks git --redact --log-opts' | head -1 | cut -d: -f1)
  ffmerge_line=$(printf '%s\n' "$block" | grep -nE 'git merge --ff-only "\$BRANCH"' | head -1 | cut -d: -f1)
  [ -n "$gitleaks_line" ]
  [ -n "$ffmerge_line" ]
  [ "$gitleaks_line" -lt "$ffmerge_line" ]
}

@test "Known limitations section notes rename-plus-symlink is now auto-detected" {
  awk '/^## Known limitations/,/^---/' "$SKILL_FILE" \
    | grep -qiE 'auto-detect|detected automatically|now auto-detects'
}

@test "Known limitations section preserves the recovery recipe" {
  # The recovery recipe with git reset + git merge --ff-only must still be
  # present as a fallback reference for manual operations outside the skill.
  local section
  section=$(awk '/^## Known limitations/,/^---/' "$SKILL_FILE")
  echo "$section" | grep -qE 'git reset'
  echo "$section" | grep -qE 'git merge --ff-only'
}
