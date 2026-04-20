# Hook Architecture Migration: PostToolUse → Git Layer + Skill Ownership

**Status**: **EXECUTED 2026-04-19** on branch `feature/hook-architecture-migration`. See git log for the landing commit.
**Verification**: **COMPLETE 2026-04-19** per [`hook-migration-test.md`](hook-migration-test.md). Migration objective (subagent-noise elimination — Smoke 1) validated. One ⚠ actionable follow-up tracked in `kit/TODOS.md` (prDescStaleReason blank-reason auto-reject) — non-blocking UX issue, not a correctness regression. No hotfix plan warranted.
**Scope delivered**: ~350 LoC across 9 files, one PR. `adversarial-review.sh` extended with two new check types (`prDescStaleReason`, `dirtyPushReason`) rather than a stdin-prompt interface (plan assumed the latter — the real engine is argument-based with internal context-gathering). `kit/notes/subagent-hook-scope.md` step #8 was a no-op: the file was already consolidated into `kit/notes/lalista-migration-resume.md` before this migration started. All other scope items landed as planned.
**Authoring date**: 2026-04-18

---

## Context

During lalista PR 2's `/ak-pre-ship` run, two parent-scope `PostToolUse Bash` hooks (`check-dirty-after-commit.sh`, `check-pr-description.sh`) fired ~8× inside a subagent with `BLOCKING`/`MANDATORY` wording demanding actions outside the subagent's mandate (commit parent's WIP, edit PR description). The subagent correctly ignored them but burned tokens deciding each time, and the wrong-response failure mode is real (compliance = acting outside scope; partial compliance = inconsistent output). A third hook — the inline release reminder in `settings.json:142` that prompts on every `git commit` in `abra-kadabra` — has the same audience problem.

The same risk recurs in PR 3's `/ak-build` runs, which lean heavily on subagents. Fixing this **blocks PR 3** — once landed, PR 3's subagents stop getting hijacked, and we can re-run PR 2's `/ak-pre-ship` cleanly to close PR #10's four unchecked boxes legitimately.

### Alternatives considered (and rejected)

| Alt                                        | Approach                                                                                                | Verdict                                                                                                                                                                                                                                     |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Softening                                  | Replace `BLOCKING`/`MANDATORY` with `Note`/`Reminder` + dedup by HEAD SHA                               | **Rejected** — trades subagent noise for parent reliability; hooks stop being authoritative                                                                                                                                                 |
| Subagent-context skip                      | Detect subagent context in PostToolUse Bash payload, exit 0 early                                       | **Rejected** — verified that PostToolUse Bash payload does NOT include `agent_id`/`agent_type`/`agent_transcript_path`. Only `SubagentStop` payload does. Infeasible without an upstream Claude Code feature                                |
| Stop-hook conversion                       | Convert PostToolUse Bash hooks to Stop hooks (parent-only by construction)                              | **Rejected** after deeper analysis: requires per-session state tracking complexity (`~/.cache/ak/turn-state-${session_id}.json`), doesn't address redundancy with husky pre-commit, doesn't strengthen enforcement, accumulates state files |
| **Git-layer migration (this plan, Alt A)** | Move workflow nudges to husky pre-push + skill ownership; delete PostToolUse Bash workflow hooks        | **Chosen** — eliminates audience problem categorically, removes redundancy, strengthens enforcement (blocking pre-push > advisory PostToolUse), no state files                                                                              |
| Self-correcting workflow (Alt B)           | Hooks auto-take the action (auto-update PR description, auto-stage leftovers, etc.) instead of alerting | **Deferred to ROADMAP v+** as "Self-correcting workflow patterns" — long-term vision; doesn't fit single PR; bigger scope per concern                                                                                                       |

---

## Architectural shift

### Today (3 layers)

- **Pre-commit (husky / git)**: gates. Block bad commits via `check-clean-tree.sh`, `cross-repo`, `lint-staged`, `gitleaks`, `devshop-commit-guard.sh`, etc. Strict, with adversarially-reviewed bypass flags (`dirtyTreeReason`, `docsVerified`, `docSyncReason`, etc.).
- **PostToolUse Bash hooks (Claude Code)**: advisory workflow nudges. Audience-confused (fires in subagents that legitimately commit/push).
- **Skill-embedded steps**: each skill handles its own pre/post action steps internally.

### After (2 layers)

- **Pre-commit + pre-push + SessionStart (husky / git + Claude Code SessionStart)**: gates AND workflow checks. All workflow enforcement at git/SessionStart layer.
- **Skill-embedded steps**: skills own concerns that need confirmation flows or context (e.g., release flow → `/ak-release-devshop`).
- **Claude Code PostToolUse Bash workflow hooks**: GONE. Audience problem categorically eliminated.

### Why this works

Git hooks fire at git invocation regardless of which agent ran git. Subagents that legitimately commit/push pass through the same gates as the parent agent — they just satisfy them in their narrow context. No audience confusion possible because there's no agent-specific reasoning baked into the hook trigger.

The PreToolUse hooks (`dcg`, `check-hook-bypass.sh`, `check-branch-not-main.sh`, `check-memory-created.sh`) are **unchanged** — they're agent-agnostic invariants that should fire for any agent. Their audience-correctness was never the problem.

### What about the redundancy with husky?

`check-dirty-after-commit.sh` is largely redundant with husky pre-commit:

- **Same-repo dirty**: husky `check-clean-tree.sh` ALREADY blocks it pre-commit. The post-commit re-warn fires only when pre-commit was bypassed via adversarially-reviewed `dirtyTreeReason` — re-warning the agent who just justified the bypass is ungenerous.
- **Cross-repo dirty**: husky `cross-repo` (in `devshop-commit-guard.sh`) ALREADY blocks it pre-commit. Same redundancy.

Deleting `check-dirty-after-commit.sh` outright (rather than migrating it to a Stop hook) removes the redundancy without losing coverage.

---

## Scope (8 changes)

1. **DELETE** `/devshop/kit/scripts/check-dirty-after-commit.sh` (root-owned — user removes via sudo).
2. **NEW** `/devshop/.husky/pre-push` hook with three checks:
   - PR-description staleness (adversarial-LLM-review pattern, matches `docs-drift`/`doc-consistency`)
   - Tree-cleanliness (block if dirty)
   - Stash-cleanliness (block if stash entries exist)
3. **EXTEND** `/devshop/kit/scripts/session-start.sh` to warn (NOT block) on dirty/stashed state in either repo at session start.
4. **DELETE** the inline release reminder (lines 137–145) in `/devshop/.claude/settings.json`.
5. **NEW** `/devshop/.claude/skills/devshop/release-devshop/SKILL.md` skill (`/ak-release-devshop`) that owns the release.sh flow.
6. **REMOVE** all three PostToolUse Bash entries from `/devshop/.claude/settings.json` (no Stop replacement).
7. **UPDATE** `/devshop/kit/docs/guide/hooks.md` to reflect the new architecture.
8. **MARK RESOLVED** `/devshop/kit/notes/subagent-hook-scope.md`; close `/devshop/kit/TODOS.md` lines 76, 77, 78.

---

## File-by-file changes (detailed)

### 1. DELETE `/devshop/kit/scripts/check-dirty-after-commit.sh`

**Rationale**: redundant with husky pre-commit guards as explained above.

**User action required**: file is root-owned (per `Edit(/devshop/kit/scripts/*)` in deny list).

```bash
sudo rm /devshop/kit/scripts/check-dirty-after-commit.sh
```

### 2. NEW `/devshop/.husky/pre-push`

**Rationale**: pre-push fires at git layer, agent-agnostic, blocking-capable. Right place for "before pushing, verify PR description is current AND tree is clean."

**Body** (full implementation; user installs via sudo):

```bash
#!/usr/bin/env bash
# Pre-push hook: three checks before allowing the push.
#   1. PR description staleness (adversarial review)
#   2. Tree cleanliness (block if dirty in current repo)
#   3. Stash cleanliness (block if stash entries exist)
#
# Bypass flags (all adversarially reviewed):
#   git -c devshop.prDescStaleReason="<reason>"  - acknowledges PR description is intentionally not yet updated
#   git -c devshop.dirtyPushReason="<reason>"    - acknowledges legitimate WIP/stash at push time
set -euo pipefail

# pre-push receives ref info on stdin: <local-ref> <local-sha> <remote-ref> <remote-sha>
INPUT=$(cat)

# Get current branch and remote
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
REMOTE_NAME="${1:-origin}"

# --- Check 0: short-circuit conditions ---
[ -z "$BRANCH" ] && exit 0                    # detached HEAD: skip
[ "$BRANCH" = "main" ] && exit 0              # pushes to main: release.sh territory
[ "$BRANCH" = "master" ] && exit 0

# Detect branch deletion (--delete sends zero local sha)
echo "$INPUT" | awk '{print $2}' | grep -q '^0\{40\}$' && exit 0

# --- Check 1: PR description staleness ---
PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty' 2>/dev/null || echo "")

if [ -n "$PR" ]; then
  # Get commits being pushed (local..remote diff)
  COMMITS=$(git log --oneline "${REMOTE_NAME}/${BRANCH}..HEAD" 2>/dev/null || git log --oneline -10 HEAD)
  COMMIT_SUBJECTS=$(echo "$COMMITS" | sed 's/^[a-f0-9]* //')

  # Conventional-commit short-circuit: skip LLM review if all commits are trivial
  ALL_TRIVIAL=true
  while IFS= read -r subj; do
    [ -z "$subj" ] && continue
    if ! echo "$subj" | grep -qE '^(chore|docs|style|test|ci|build|perf):'; then
      ALL_TRIVIAL=false
      break
    fi
  done <<< "$COMMIT_SUBJECTS"

  if [ "$ALL_TRIVIAL" = "false" ]; then
    # Non-trivial commits — check PR description sync via adversarial review
    PR_DATA=$(gh pr view "$PR" --json title,body 2>/dev/null || echo "{}")
    PR_TITLE=$(echo "$PR_DATA" | jq -r '.title // ""')
    PR_BODY=$(echo "$PR_DATA" | jq -r '.body // ""')

    BYPASS_REASON=$(git config --get devshop.prDescStaleReason 2>/dev/null || echo "")

    # Invoke adversarial review (same pattern as docs-drift/doc-consistency)
    # bash kit/scripts/adversarial-review.sh expects: prompt on stdin, exits 0=pass, 2=block
    REVIEW_INPUT=$(cat <<EOF
You are an adversarial reviewer. The user is pushing commits to a branch with an open PR.

PR title: $PR_TITLE

PR body (first 5 lines):
$(echo "$PR_BODY" | head -5)

New commits being pushed (this push):
$COMMITS

Bypass reason provided (may be empty):
$BYPASS_REASON

Your job: try to REJECT the push as stale-PR-description. The PR title/body should describe the actual scope of all commits in the PR. If the new commits introduce features, fixes, or refactors that aren't reflected in the PR description, the description is stale and needs updating.

If a bypass reason was provided, try to find any flaw or weakness in the reason. Generic reasons ("WIP", "later", "fine") should be rejected. Strong reasons that explain WHY the description is intentionally lagging (e.g., "rebasing branch, will update description after squash") should pass.

Respond with: PASS or BLOCK followed by a one-line explanation.
EOF
)

    REVIEW_RESULT=$(echo "$REVIEW_INPUT" | bash /devshop/kit/scripts/adversarial-review.sh 2>&1 || echo "BLOCK: review failed (fail-closed)")

    if echo "$REVIEW_RESULT" | grep -q '^BLOCK'; then
      echo "❌ Pre-push: PR description appears stale relative to commits being pushed." >&2
      echo "" >&2
      echo "Reviewer assessment:" >&2
      echo "$REVIEW_RESULT" >&2
      echo "" >&2
      echo "Options:" >&2
      echo "  1. Update PR title/body via 'gh pr edit $PR --title \"...\" --body \"...\"', then retry the push" >&2
      echo "  2. Bypass with: git -c devshop.prDescStaleReason=\"<thorough reason>\" push ..." >&2
      exit 1
    fi
  fi
fi

# --- Check 2: Tree cleanliness ---
DIRTY=$(git status --porcelain 2>/dev/null | head -10 || echo "")
STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ' || echo "0")

if [ -n "$DIRTY" ] || [ "$STASH_COUNT" -gt 0 ]; then
  BYPASS_REASON=$(git config --get devshop.dirtyPushReason 2>/dev/null || echo "")

  REVIEW_INPUT=$(cat <<EOF
You are an adversarial reviewer. The user is pushing while the local working tree is not clean.

Dirty files (porcelain output):
$DIRTY

Stash count: $STASH_COUNT

Bypass reason provided (may be empty):
$BYPASS_REASON

Your job: try to REJECT the push as dirty-state. Pushing while you have uncommitted work or unmerged stashes typically means you forgot to commit something or are about to lose track of WIP. The bypass reason should explain WHY this dirty state is intentional (e.g., "stashed feature X temporarily to push hotfix Y", "untracked log files from local debug, not part of project").

Generic reasons should be rejected. Strong specific reasons should pass.

Respond with: PASS or BLOCK followed by a one-line explanation.
EOF
)

  REVIEW_RESULT=$(echo "$REVIEW_INPUT" | bash /devshop/kit/scripts/adversarial-review.sh 2>&1 || echo "BLOCK: review failed (fail-closed)")

  if echo "$REVIEW_RESULT" | grep -q '^BLOCK'; then
    echo "❌ Pre-push: working tree is dirty or stash entries exist." >&2
    echo "" >&2
    [ -n "$DIRTY" ] && { echo "Dirty files:"; echo "$DIRTY"; } >&2
    [ "$STASH_COUNT" -gt 0 ] && echo "Stash entries: $STASH_COUNT" >&2
    echo "" >&2
    echo "Reviewer assessment:" >&2
    echo "$REVIEW_RESULT" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1. Commit or stash-and-push your changes first" >&2
    echo "  2. Drop stashes with 'git stash drop' if no longer needed" >&2
    echo "  3. Bypass with: git -c devshop.dirtyPushReason=\"<thorough reason>\" push ..." >&2
    exit 1
  fi
fi

exit 0
```

**Notes**:

- Uses the existing `/devshop/kit/scripts/adversarial-review.sh` — same pattern as `docs-drift` / `doc-consistency` / `release-coverage`. **Verify** this script exists and accepts prompt-on-stdin / outputs `PASS|BLOCK`-prefixed lines. If the actual interface differs, adapt accordingly.
- Conventional-commit short-circuit (Check 1) skips LLM review on trivial commits to keep `chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:` pushes fast.
- Both bypass flags are adversarially reviewed — the reviewer judges the reason text. Generic reasons fail; strong specific reasons pass.
- Pre-push hook receives stdin per git docs: `<local-ref> <local-sha> <remote-ref> <remote-sha>` per line. We use it for branch-deletion detection.
- Pushes to `main`/`master` are short-circuited (release.sh handles those via the existing `release-coverage` adversarial check at pre-commit time).

**User action required**: file goes in `/devshop/.husky/`. The `.husky/` directory may need creation. Husky should auto-make it executable; verify with `ls -la /devshop/.husky/pre-push` after install.

```bash
sudo cp /tmp/pre-push.sh /devshop/.husky/pre-push
sudo chmod 755 /devshop/.husky/pre-push
```

### 3. EXTEND `/devshop/kit/scripts/session-start.sh`

**Rationale**: catches dirty/stashed state at session boundaries. Warns (not blocks) because the user might legitimately be resuming WIP. Closes TODO 76.

**Addition** (append to existing logic; user installs via sudo):

```bash
# --- Cross-repo dirty/stash check at session start (warning only) ---
SESSION_WARNINGS=()

for REPO_DIR in /workspace /devshop; do
  [ ! -d "$REPO_DIR/.git" ] && continue
  REPO_NAME=$(basename "$REPO_DIR")
  [ "$REPO_NAME" = "devshop" ] && REPO_NAME="devshop (abra-kadabra)"

  DIRTY=$(git -C "$REPO_DIR" status --porcelain 2>/dev/null | head -5 || echo "")
  STASH_COUNT=$(git -C "$REPO_DIR" stash list 2>/dev/null | wc -l | tr -d ' ' || echo "0")

  if [ -n "$DIRTY" ]; then
    SESSION_WARNINGS+=("$REPO_NAME has uncommitted changes:
$DIRTY")
  fi

  if [ "$STASH_COUNT" -gt 0 ]; then
    STASH_LIST=$(git -C "$REPO_DIR" stash list 2>/dev/null | head -3)
    SESSION_WARNINGS+=("$REPO_NAME has $STASH_COUNT stash entrie(s):
$STASH_LIST")
  fi
done

# Append warnings to systemMessage if any
if [ ${#SESSION_WARNINGS[@]} -gt 0 ]; then
  COMBINED_WARNINGS=$(printf '%s\n\n' "${SESSION_WARNINGS[@]}")
  # Append to whatever session-start.sh emits as systemMessage
  # (exact integration depends on current session-start.sh structure — see existing emit logic)
fi
```

**Notes**:

- Implementer must inspect current `session-start.sh` to determine the exact integration point for appending to its existing systemMessage output. Don't blindly append — read the script first.
- Warning text should be informational, not imperative. Suggested phrasing: "Heads up: <repo> has uncommitted/stashed work from a previous session. If this is intentional WIP, continue. If you don't recognize it, investigate before making new changes."
- Closes `/devshop/kit/TODOS.md:76` ("Session-start uncommitted changes check").

**User action required**: file is root-owned. Edit and sudo cp.

### 4. DELETE inline release reminder in `/devshop/.claude/settings.json`

**Lines to remove**: 137–145 (the entire first PostToolUse Bash hook entry). Specifically, the entry whose command starts with `if git remote get-url origin 2>/dev/null | grep -q 'abra-kadabra'`.

**Replacement**: NONE in settings.json. Release responsibility moves to the new `/ak-release-devshop` skill (item 5).

**User action required**: settings.json is root-owned and write-denied. User edits via sudo.

### 5. NEW `/ak-release-devshop` skill

**Path**: `/devshop/.claude/skills/devshop/release-devshop/SKILL.md`

**Purpose**: prompts the agent through the devshop release flow (the abra-kadabra-specific `release.sh` workflow), replacing the deleted inline post-commit reminder. Triggered by user invocation (`/ak-release-devshop`) or by a higher-level skill (e.g., post-merge in a future `/ak-go-live-devshop`).

**Body sketch** (~100 lines of skill markdown):

```markdown
---
description: Run the devshop (abra-kadabra) release flow — bump version, update changelog, tag, push.
  Use when asked to "release the devshop", "release abra-kadabra", "bump version", "cut a release",
  or after merging changes to abra-kadabra main.
  Proactively suggest after a PR merges to abra-kadabra main with feat: or fix: commits.
---

# /ak-release-devshop

Owns the devshop release workflow.

## When to invoke

- After merging a PR to abra-kadabra `main` that contains `feat:`, `fix:`, or `BREAKING CHANGE:` commits
- When the user explicitly asks to release / bump version / cut a release on the devshop
- When `release.sh` would otherwise need to be remembered

## Phase 1: Assess

1. Verify current branch is `main` in `/devshop`
2. Run `git log $(git describe --tags --abbrev=0)..HEAD --oneline` to see commits since last tag
3. Categorize commits:
   - `feat:` → minor bump
   - `fix:` → patch bump
   - `BREAKING CHANGE:` or `feat!:`/`fix!:` → major bump
   - `chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:` → no version impact
4. Propose version bump to user (display current version + proposed). Ask to confirm or override.

## Phase 2: Execute

1. Stage `kit/version` and `kit/CHANGELOG.md` updates
2. Adversarial-reviewed `release-coverage` guard fires at commit (existing pre-commit check)
3. Tag: `git tag v<X.Y.Z>`
4. Push: `git push origin main && git push origin v<X.Y.Z>`

## Phase 3: Confirm

- Confirm tag visible on GitHub
- Confirm any downstream consumers (projects pinning to a version) are aware

## Skipping

If commits since last tag are all trivial (no `feat:`/`fix:`/`BREAKING CHANGE:`), tell the user "No release needed — commits since last tag are all trivial. Run anyway with --force if you really want to bump version." and exit.
```

**User action required**: skill files live under `/devshop/.claude/skills/`. Verify whether this directory is in deny list. (Per settings.json: `Edit(.claude/**)` is allowed and `Edit(/devshop/.claude/settings.json)` is the only `.claude/` deny — the skills directory should be writable. Verify before assuming.)

### 6. REMOVE three PostToolUse Bash entries from `/devshop/.claude/settings.json`

**Lines to remove**: 135–166 (the entire `PostToolUse` array, all three entries).

**Replacement**: omit the `PostToolUse` key entirely (or leave as `"PostToolUse": []`). No new Stop hook entry needed.

**User action required**: settings.json is root-owned and write-denied. User edits via sudo.

### 7. UPDATE `/devshop/kit/docs/guide/hooks.md`

**Edits required**:

- **Lines 7–17 (Claude Code Hooks table)**: remove these three rows (they're going away):
  - `release.sh reminder | PostToolUse (git commit)`
  - `dirty tree check | PostToolUse (git commit)`
  - `PR description update | PostToolUse (git push)`
- **Lines 56–58 (commit flow diagram §4)**: remove "PostToolUse hooks" entirely from the diagram. Replace with:
  ```
  4. Pre-push hooks (git):
     └─ .husky/pre-push: PR description staleness + dirty tree + stash checks
        (adversarially reviewed, blocking with bypass flags)
  ```
- **Lines 119–125 (PostToolUse table §3)**: replace section heading with "After git push (Husky pre-push)" and rewrite table to describe the new pre-push hook's three checks + bypass flags.
- **New section**: add "## Why workflow nudges live at the git layer" with a 1-paragraph explanation referencing `kit/notes/subagent-hook-scope.md` for history. Cover: PostToolUse Bash fires for any agent including subagents; subagents have narrow mandates that can't act on parent-scope nudges; git layer is agent-agnostic by construction.
- **Update lines 131-135** (Commit Convention / On Push sections): align with new pre-push behavior (blocking adversarially-reviewed check, not advisory PostToolUse).

### 8. MARK RESOLVED + close TODOs

**`/devshop/kit/notes/subagent-hook-scope.md`**: prepend at top:

```markdown
## UPDATE 2026-04-18 — RESOLVED via git-layer migration

This investigation note is **historical** as of 2026-04-18. The subagent-hooks problem was resolved not via the originally-proposed approaches (a) softening or (b) subagent-context-skip, but via a deeper architectural shift: moving workflow nudges from `PostToolUse Bash` hooks (Claude Code, fires in subagents) to the husky pre-push hook + skill ownership (git layer, agent-agnostic by construction).

See `/devshop/kit/notes/roadmap/hook-migration-plan.md` for the migration plan and rationale.

The investigation protocol below remains useful for any future similar problem (audience-confused hooks). Keeping the body for reference.

---
```

**`/devshop/kit/TODOS.md` lines 76, 77, 78**: mark all three `[x]` with rationale:

- Line 76 ("Session-start uncommitted changes check"): "RESOLVED 2026-04-18: implemented in `session-start.sh` as part of hook architecture migration. See `kit/notes/roadmap/hook-migration-plan.md`."
- Line 77 ("Make `check-pr-description.sh` blocking"): "RESOLVED 2026-04-18: replaced by `.husky/pre-push` blocking check with adversarial review. See `kit/notes/roadmap/hook-migration-plan.md`."
- Line 78 ("Make `check-dirty-after-commit.sh` blocking"): "RESOLVED 2026-04-18: deleted as redundant with husky pre-commit guards (`check-clean-tree.sh` + `cross-repo`). The `.husky/pre-push` hook adds an additional blocking layer at push time. See `kit/notes/roadmap/hook-migration-plan.md`."

---

## Existing patterns being reused

- **Adversarial review pattern**: `kit/scripts/adversarial-review.sh` — invoked by `docs-drift`, `doc-consistency`, `release-coverage`, etc. Used for the new pre-push hook's PR-description and dirty-push checks.
- **Bypass flag convention**: `git -c devshop.<flagName>="<reason>"` — same pattern as `dirtyTreeReason`, `docsVerified`, `docSyncReason`. New flags: `prDescStaleReason`, `dirtyPushReason`.
- **Output format**: blocking hooks emit error message to stderr + exit non-zero (husky picks this up).
- **Conventional commit categorization**: `feat:`/`fix:`/`chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:` — already used elsewhere in the devshop.

---

## Verification protocol

Manual smokes after the migration lands. Both repos clean to start. Run from `/workspace` and `/devshop` as appropriate.

### Smoke 1: Subagent-noise problem eliminated (the original bug)

1. Spawn a general-purpose subagent that runs `git commit --allow-empty -m "test from subagent"` in `/workspace` and returns.
2. Verify: NO PostToolUse output appears in subagent context. Subagent simply commits and returns.
3. **Expected**: subagent context is clean. The audience problem is gone.

### Smoke 2: Pre-push blocks stale PR description

1. Branch `feature/test-stale-pr` with an open PR titled "fix: typo in README" and matching body.
2. Add a commit with `feat: implement entire payment system`.
3. Push.
4. **Expected**: pre-push hook blocks with adversarial review BLOCK output. Bypass works: `git -c devshop.prDescStaleReason="<reason>" push`.

### Smoke 3: Pre-push allows trivial pushes (conventional-commit short-circuit)

1. Branch with an open PR.
2. Add only `chore:` and `docs:` commits.
3. Push.
4. **Expected**: pre-push runs no LLM review. Push succeeds quickly.

### Smoke 4: Pre-push blocks dirty push

1. Make a change without committing.
2. Push (any branch with open PR).
3. **Expected**: dirty-push check fires. Bypass works.

### Smoke 5: Pre-push blocks stash entries

1. `git stash push -m "test stash"`.
2. Push.
3. **Expected**: stash check fires. `git stash drop` clears it. Bypass works.

### Smoke 6: Pre-push allows pushes to main

1. On `main`, push (assuming you can — use `--allow-unrelated-histories` workaround in test env).
2. **Expected**: pre-push hook short-circuits (release.sh handles main).

### Smoke 7: Pre-push allows branch deletions

1. `git push origin --delete <some-stale-branch>`.
2. **Expected**: pre-push detects zero-sha (deletion), exits 0, deletion proceeds.

### Smoke 8: SessionStart warns on dirty state

1. Leave `/workspace` with an uncommitted file. End the session.
2. Start a new session.
3. **Expected**: session-start systemMessage includes "Heads up: workspace has uncommitted changes" warning. Session is not blocked.

### Smoke 9: SessionStart warns on stash state

1. `git stash push -m "test"` in `/devshop`. End session.
2. Start new session.
3. **Expected**: session-start systemMessage includes "Heads up: devshop has 1 stash entry" warning.

### Smoke 10: Inline release reminder is gone

1. Commit in `/devshop`.
2. **Expected**: NO post-commit message about release.sh. The inline hook is deleted.

### Smoke 11: `/ak-release-devshop` skill works

1. Make `feat:` and `fix:` commits to abra-kadabra main (test env).
2. Invoke `/ak-release-devshop`.
3. **Expected**: skill assesses commits, proposes minor bump, walks through release.sh flow.

### Smoke 12: PreToolUse hooks unchanged

1. Try to commit on `main` (any repo).
2. **Expected**: `check-branch-not-main.sh` blocks (unchanged).
3. Try `git commit --no-verify`.
4. **Expected**: `check-hook-bypass.sh` blocks (unchanged).

**Pass criteria**: all 12 smokes match expected behavior.

---

## Out of scope

- **Self-correcting workflow patterns (Alt B)**: deferred to ROADMAP v+. See "Self-correcting workflow patterns" entry in `/devshop/kit/ROADMAP.md`.
- **`bats` tests for the new hooks**: existing hooks have no automated tests. Adding test infrastructure is its own scope (already in ROADMAP v+ "Devshop testing → Hook tests").
- **Template changes**: `/devshop/template/` ships no `.claude/settings.json` — no template update needed.
- **PreToolUse hooks**: unchanged (`dcg`, `check-hook-bypass.sh`, `check-branch-not-main.sh`, `check-memory-created.sh`).
- **`SubagentStop` hooks**: not adding any.
- **`Stop` hooks**: not adding any (rejected this approach).
- **Release auto-trigger on PR merge**: out of scope — `/ak-release-devshop` is invoked manually or by a future skill chain. Auto-trigger is a separate consideration.
- **Smarter post-commit nudges in skills**: each skill can add its own post-commit awareness if needed. Not bundled here.

---

## Open implementation decisions to confirm

1. **Adversarial-review.sh interface**: this plan assumes the script accepts prompt-on-stdin and outputs `PASS|BLOCK`-prefixed lines. **Verify the actual interface before implementing** — if it differs, adapt the pre-push hook calls. Read `/devshop/kit/scripts/adversarial-review.sh` first.
2. **Husky directory layout**: this plan assumes `/devshop/.husky/pre-push` is the right location for a husky pre-push hook in the devshop's setup. **Verify** by checking existing `/devshop/.husky/` (e.g., is there a pre-commit there? same pattern).
3. **session-start.sh integration point**: read the current script before extending. The cross-repo warning needs to integrate with whatever existing systemMessage emit pattern is in place.
4. **Skills directory permissions**: `/devshop/.claude/skills/` may or may not be writable. Verify before creating `/ak-release-devshop`.
5. **Bypass flag naming**: `prDescStaleReason` and `dirtyPushReason` — confirm naming consistency with existing `dirtyTreeReason` style.

---

## Critical files (quick reference)

- **NEW**: `/devshop/.husky/pre-push` (root-owned install via sudo)
- **NEW**: `/devshop/.claude/skills/devshop/release-devshop/SKILL.md`
- **MODIFY (root-owned, sudo)**: `/devshop/.claude/settings.json`, `/devshop/kit/scripts/session-start.sh`
- **DELETE (root-owned, sudo)**: `/devshop/kit/scripts/check-dirty-after-commit.sh`, `/devshop/kit/scripts/check-pr-description.sh`
- **MODIFY**: `/devshop/kit/docs/guide/hooks.md`, `/devshop/kit/notes/subagent-hook-scope.md`, `/devshop/kit/TODOS.md`

## What this PR enables

Once landed, this PR unblocks:

1. **Re-run PR 2's `/ak-pre-ship` cleanly** — subagents in pre-ship gates won't get hijacked anymore. Allows closing PR #10's four unchecked boxes legitimately.
2. **PR 3 (`/ak-build core-flows`)** — autonomous build pipeline relies heavily on subagents. Without this fix, every subagent invocation would hit the same noise.
3. **Future devshop work using `/ak-build`** — same benefit.

---

## Devshop commit conventions for this PR

Per `/devshop/kit/docs/guide/hooks.md` and existing devshop discipline:

- Branch: `feature/hook-architecture-migration` on devshop (abra-kadabra, separate from `/workspace`).
- Commit structure: probably one commit (cohesive architectural change). If splitting: (1) new pre-push + delete old scripts + settings.json, (2) session-start.sh + release skill, (3) docs + notes + TODOs.
- Adversarial reviewers will fire: `docs-drift` (tooling changed → reviews docs), possibly `doc-consistency` (hooks.md is reference doc). Have `docsVerified` and `docSyncReason` reasons ready, covering each of the 7 top-level docs (MODEL.md, OVERVIEW.md, kit/docs/guide/, CLAUDE.md, FAQ.md, project CLAUDE.md, README.md).
- Test the new pre-push hook BEFORE committing — the new hook will fire on the commit's eventual push, so smoke-test it to avoid getting blocked.
- Use `https://github.com/<owner>/<repo>/raw/<branch>/<path>` URL form for any image links in PR body (raw.githubusercontent.com 404s for private repos).
