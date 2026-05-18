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

# === Section F — Phase 1 audit ===

@test "Phase 1 invokes /ak-check-docs-and-tests (orchestrator, not /ak-tests-review directly)" {
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" | grep -qE 'ak-check-docs-and-tests'
}

@test "Phase 1 halts on high-severity findings" {
  awk '/^## Phase 1:/,/^## Phase 2:/' "$SKILL_FILE" \
    | grep -qE '[Hh]igh-severity.*halt|halt.*high'
}

# === Section G — Phase 2 worktree-routed squash ===

@test "Phase 2 introduces GIT_CMD that routes via -C when WORKTREE_PATH set" {
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'GIT_CMD="git"'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'GIT_CMD="git -C \$WORKTREE_PATH"'
}

@test "Phase 2 uses \$GIT_CMD on rebase + reset --soft + commit" {
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE '\$GIT_CMD rebase origin/main'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE '\$GIT_CMD reset --soft origin/main'
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE '\$GIT_CMD commit -F'
}

@test "Phase 2 explains why worktree-routing sidesteps phantom rebase error" {
  awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qiE 'phantom|virtiofs|stat-cache'
}

@test "Phase 2 does NOT use git merge --squash (legacy on-main approach)" {
  # The old pre-soft-reset shape ran `git merge --squash <branch>` while on
  # main and then `git commit -F`. That triggered check-branch-not-main.sh
  # and forced an operator handoff. The new shape avoids both.
  ! awk '/^## Phase 2:/,/^## Phase 3:/' "$SKILL_FILE" \
    | grep -qE 'git merge --squash'
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
