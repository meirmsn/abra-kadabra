# Hook Migration — Post-Landing Verification Plan

**Status**: to be executed in a new clean-context session.
**Parent plan**: [`kit/notes/roadmap/hook-migration-plan.md`](hook-migration-plan.md) (landed in v1.10.0, 2026-04-19).
**Why a separate doc**: partial verification ran in-session during the migration itself. The most important test — the subagent-noise smoke that validates the ORIGINAL motivating bug is gone — needs a **clean-context session** to spawn a fresh subagent without the current session's cached settings or conversational baggage.
**Authoring date**: 2026-04-19
**Current devshop version at authoring**: v1.10.2 on `main` (rollback + empty-changelog fixes on top of the migration; irrelevant to this verification).

---

## Context to load first (in order, before touching any tools)

1. **This doc** (you're reading it) — the full verification protocol.
2. [`kit/notes/roadmap/hook-migration-plan.md`](hook-migration-plan.md) — rationale + alternatives + original verification protocol (Smokes 1-12; this doc's "Remaining" section is a subset of those).
3. [`kit/docs/guide/hooks.md`](../../docs/guide/hooks.md) §3 ("Husky pre-push") and the "Why workflow nudges live at the git layer" section — the current architectural design.
4. `/devshop/.husky/pre-push` — the hook body. Note the sh→bash re-exec guard at the top (husky v9 invokes hooks via `sh -e "$hook"` regardless of shebang).
5. `/devshop/kit/scripts/adversarial-review.sh` — grep for `prDescStaleReason` and `dirtyPushReason` case arms.

Skim. No need to memorize. Come back to this doc as the source of truth on what to run.

---

## State at migration landing (baseline the test assumes)

If any of these are not true, **stop and reconcile before running tests** — the migration may have been partially reverted or subsequently changed.

```bash
# Verify on /devshop main
cat /devshop/kit/version                                         # expect 1.10.2 or later
test -f /devshop/.husky/pre-push && echo "pre-push exists"       # expect: exists
test -f /devshop/kit/scripts/check-dirty-after-commit.sh || echo "old script deleted"  # expect: deleted
test -f /devshop/kit/scripts/check-pr-description.sh || echo "old script deleted"      # expect: deleted
grep -c "prDescStaleReason\|dirtyPushReason" /devshop/kit/scripts/adversarial-review.sh  # expect ≥ 2
jq '.hooks | has("PostToolUse")' /devshop/.claude/settings.json  # expect: false
jq '.hooks | has("PostToolUse")' /workspace/.claude/settings.json  # expect: false
test -L /devshop/.claude/skills/ak-release-devshop && echo "skill symlinked"  # expect: exists
```

If all green, proceed.

---

## Already-verified smokes — do NOT re-run

Tabulated so the new session doesn't waste time on paths already exercised in the 2026-04-19 migration session.

| #                           | What                                                                                                               | How it was verified                                                                 | Result |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- | ------ |
| Pre-push A                  | Dirty tree + no bypass → adversarial `FAIL` → exit 1 with structured error                                         | Ran hook directly with synthesized stdin in /devshop session                        | ✅     |
| Pre-push B                  | Dirty tree + specific bypass (`GIT_CONFIG_PARAMETERS='devshop.dirtyPushReason=...'`) → adversarial `PASS` → exit 0 | Ran hook directly with env-injected config                                          | ✅     |
| Pre-push C                  | Branch deletion (zero-sha in stdin col 2) → short-circuit exit 0                                                   | `echo "refs/heads/test 0{40} refs/heads/test 0{40}" \| bash .husky/pre-push origin` | ✅     |
| Sh compat                   | Husky v9 shim invokes via `sh -e`; bash re-exec guard works on dash                                                | `sh -e /tmp/pre-push origin` → exit 0 after re-exec                                 | ✅     |
| Integration push            | Feature branch's first push → "no PR + clean tree + no stash" short-circuit path                                   | Actual `git push` of `feature/hook-architecture-migration`                          | ✅     |
| Settings.json postmigration | No PostToolUse key in either /devshop or /workspace settings.json after container rebuild                          | `jq '.hooks \| keys'` showed only `PreToolUse` + `SessionStart`                     | ✅     |
| PreToolUse unchanged        | `check-branch-not-main.sh` still blocks Claude on main                                                             | Direct `git commit` on main during release was blocked exactly as before            | ✅     |
| Bats wiring                 | All 174 structural invariants + guards + util tests pass post-migration                                            | Ran in pre-commit chain on v1.10.0 + v1.10.1 + v1.10.2                              | ✅     |

---

## Remaining smokes — run these in the new session

Ordered by importance. Smoke 1 is the key test — the whole migration hinges on it.

### Smoke 1 — Subagent-noise problem ELIMINATED (the original motivating bug) 🔑

**THIS IS THE KEY TEST.** The migration was motivated by subagents receiving PostToolUse Bash hooks demanding parent-scope actions ("BLOCKING: commit your dirty tree", "MANDATORY: review PR"). Subagents either ignored (burning tokens deciding each time) or partially complied (acting outside their mandate). This smoke validates that no PostToolUse hooks fire in a subagent context anymore.

**Preconditions:**

- Fresh Claude Code session (otherwise cached settings from pre-migration state may bias the test).
- Either /workspace or /devshop is fine as the working repo. /workspace is more representative of real use.
- On a feature branch (not main — the branch-not-main hook would block commits anyway, but we want to isolate the PostToolUse question).
- Tree is intentionally DIRTY with one or two uncommitted files — this is the scenario that _previously_ triggered the PostToolUse `check-dirty-after-commit.sh` noise in subagents.

**Setup (~1 minute):**

```bash
cd /workspace
git checkout -b test/subagent-noise-smoke main 2>/dev/null || git checkout test/subagent-noise-smoke
echo "// smoke marker $(date -Iseconds)" > .smoke-marker-a
echo "// smoke marker $(date -Iseconds)" > .smoke-marker-b
git add .smoke-marker-a
# Leaves .smoke-marker-a staged and .smoke-marker-b untracked — dirty tree.
```

**Steps:**

1. Spawn a subagent via the Agent tool with **narrow scope** and instructions to commit just one of the staged files:
   ```
   Agent({
     description: "Subagent noise smoke",
     subagent_type: "general-purpose",
     prompt: "In /workspace, run: git commit -m 'smoke: add marker a'. Then report back the exit code and anything unusual you observed. Do NOT commit, stage, or edit any files other than what's already staged. Do not push. Report under 100 words."
   })
   ```
2. Wait for the subagent to return.
3. Inspect the subagent's returned text carefully.

**Expected:**

- Subagent's output contains NO mention of:
  - "BLOCKING:" / "MANDATORY:" / "⚠️" / "You MUST"
  - "Working tree still dirty"
  - "release.sh" prompt
  - "PR description" review nudge
- Subagent commits cleanly and returns under 100 words.
- Husky pre-commit gates _do_ fire (lint-staged, gitleaks, bats, devshop-commit-guard) — those are git-layer, agent-agnostic, and SHOULD fire for subagents too.

**FAIL conditions (any → migration regressed):**

- Any of the banned strings appears in subagent output.
- Subagent burned >200 tokens deciding how to respond to a hook-injected nudge.
- Subagent commits the untracked `.smoke-marker-b` file (acting outside its mandate — old bug).

**Cleanup:**

```bash
cd /workspace
git reset --hard HEAD~1 2>/dev/null  # undo the subagent's commit — only if the smoke branch is the current branch and HEAD is the smoke commit
rm -f .smoke-marker-a .smoke-marker-b 2>/dev/null
git checkout main
git branch -D test/subagent-noise-smoke
```

**Why this is the key test**: the entire migration's benefit is that subagents in pipelines like `/ak-build` or `/ak-pre-ship` don't get hijacked by parent-scope PostToolUse. If this smoke fails, PR 3 (`/ak-build core-flows`) will hit the same bug that motivated the migration.

---

### Smoke 2 — Pre-push: stale PR description → adversarial FAIL (+ bypass path PASS)

Tests the `prDescStaleReason` end-to-end path, including the adversarial-review.sh case arm and the hook's integration with `gh pr view`.

**Preconditions:**

- `gh` CLI authenticated against a repo where you can open throwaway PRs (workspace/lalista or devshop both fine — workspace is less noisy).
- If running against /devshop: the devcontainer PAT used for push auth works for PR creation too (tested in the migration session via `GH_TOKEN=$DEVSHOP_GITHUB_TOKEN`).

**Setup (~2 minutes):**

```bash
cd /workspace                                        # or /devshop
git checkout -b test/stale-pr-desc main
echo "// stale-pr test $(date -Iseconds)" > .stale-pr-test.txt
git add .stale-pr-test.txt
git commit -m "feat: introduce a thing that is clearly NOT a typo fix"
git push -u origin test/stale-pr-desc
# Create the PR with DELIBERATELY misleading description
gh pr create --title "chore: fix typo" --body "Small typo fix in README." \
  --base main --head test/stale-pr-desc
```

**Step 1: push WITHOUT bypass → expect BLOCK**

```bash
echo "// second commit $(date -Iseconds)" >> .stale-pr-test.txt
git commit -am "feat: add another non-typo-fix thing"
git push
```

**Expected:**

- Hook output: `❌ Pre-push: PR #N description appears stale relative to commits.`
- Reviewer assessment cites the mismatch between "typo fix" description and the `feat:` commits.
- Exit 1, push does not go through.

**Step 2: push WITH generic bypass → expect BLOCK**

```bash
git -c devshop.prDescStaleReason="later" push
git -c devshop.prDescStaleReason="WIP" push
```

**Expected:** both blocked. Adversarial reviewer rejects generic reasons.

**Step 3: push WITH specific bypass → expect PASS**

```bash
git -c devshop.prDescStaleReason="intentionally batching — will squash-update the PR title/body to match the feat: commits after final review" push
```

**Expected:** push succeeds. Reviewer accepts the structural reason.

**Cleanup:**

```bash
gh pr close $(gh pr list --head test/stale-pr-desc --json number --jq '.[0].number')
git push origin --delete test/stale-pr-desc
git checkout main
git branch -D test/stale-pr-desc
rm -f .stale-pr-test.txt
```

---

### Smoke 3 — Pre-push: conventional-commit-only push → short-circuit skips LLM review

Validates the `chore:/docs:/style:/test:/ci:/build:/perf:`-only short-circuit. Cheap to run because the skip means NO adversarial LLM call (so sub-second instead of ~30s).

**Preconditions:** same repo with an open PR as Smoke 2 OR a fresh one.

**Setup:**

```bash
cd /workspace
git checkout -b test/trivial-only main
echo "// docs-only $(date -Iseconds)" > .trivial-test.txt
git add .trivial-test.txt
git commit -m "docs: add a note"
git push -u origin test/trivial-only
gh pr create --title "docs: add a note" --body "Adds a note." --base main --head test/trivial-only
```

**Step: push another trivial commit**

```bash
echo "// more docs $(date -Iseconds)" >> .trivial-test.txt
git commit -am "docs: expand the note"
time git push
```

**Expected:**

- Push succeeds in well under 5 seconds (no LLM call).
- No "Pre-push: PR description..." output — conventional-commit short-circuit hit before the adversarial review.
- Test by timing: if push takes >15s it means LLM was called, which means short-circuit failed.

**Cleanup:** same as Smoke 2.

---

### Smoke 4 — Pre-push: stash-only (clean tree + stash entries)

The dirty-tree path is already verified (Pre-push A). The stash-only path is the same condition (`-n "$DIRTY" || "$STASH_COUNT" -gt 0`) but with the right-hand disjunct true.

**Setup:**

```bash
cd /workspace                  # or /devshop
git checkout -b test/stash-smoke main
echo "// something" > .stash-test.txt
git stash push -u -m "smoke-stash"   # pushes untracked file into stash
git status --porcelain               # expect: empty
git stash list                       # expect: 1 entry
```

**Step: push**

```bash
# Need a real commit to push. Make one that's independent of the stash.
echo "// commit content" > .commit-content.txt
git add .commit-content.txt
git commit -m "fix: add commit content for stash smoke"
git push -u origin test/stash-smoke
```

**Expected:**

- Hook blocks: `❌ Pre-push: local state is not clean at push time.` — cites stash count > 0.
- Bypass path: `git -c devshop.dirtyPushReason="stashed smoke marker for test, will drop after" push` → PASS.

**Cleanup:**

```bash
git stash drop   # drop the smoke stash
gh pr close ... # if a PR was opened
git push origin --delete test/stash-smoke
git checkout main
git branch -D test/stash-smoke
rm -f .commit-content.txt .stash-test.txt
```

---

### Smoke 5 — Pre-push: push to main → short-circuit

Currently trustable by code inspection (`[ "$BRANCH" = "main" ] && exit 0` at the top of the hook). Runtime test only needed if Smoke 1 passes and you want to cover the last uncovered short-circuit path.

**Light verification:** on /devshop after a release (when a legitimate push to main happens), observe that `release.sh`'s internal push does NOT invoke an adversarial review. v1.10.1 and v1.10.2 releases in the migration session both succeeded — so this is _de facto_ verified, but not with a controlled test.

**Controlled test (optional, low priority):**

```bash
cd /workspace
# Temporarily rename a feature branch to mimic main — requires human in raw terminal
# because Claude can't commit on main via normal path.
# OR: use a tmp clone and manually rename.
# Skip unless Smoke 1 fails and we need to rule out other paths.
```

Mark as N/A unless there's reason to suspect regression.

---

### Smoke 6 — SessionStart: cross-repo WIP heads-up fires on dirty state

Validates the `session-start.sh` additive change — the replacement for the old `check-dirty-after-commit.sh`'s cross-repo reminder.

**Preconditions:**

- Able to start a new Claude Code session (either `/clear` OR fresh `claude` invocation).

**Setup (in current session, before new session starts):**

```bash
cd /workspace
echo "// session-warn test $(date -Iseconds)" > .wip-marker.txt
cd /devshop                                              # optional: also dirty the devshop
echo "// another wip marker" > .wip-devshop.txt
```

Either repo alone is sufficient; both is a stronger test of the "either repo" branch.

**Step:**

1. In the terminal, run `/clear` (or exit + `claude` fresh).
2. When the session starts, observe the session briefing output.

**Expected:** briefing contains a block like:

```
 ⚠ Heads up — WIP from a previous session:
   project (or abra-kadabra) has uncommitted changes:
     ?? .wip-marker.txt
```

**FAIL conditions:**

- No "⚠ Heads up" block appears → `session-start.sh` change didn't land or is broken.
- Block appears but misses a dirty repo → loop logic bug.
- Block crashes the session or produces malformed JSON.

**Cleanup:**

```bash
cd /workspace && rm -f .wip-marker.txt
cd /devshop && rm -f .wip-devshop.txt
```

---

### Smoke 7 — SessionStart: stash-only heads-up

Same as Smoke 6 but replacing "dirty file" with "stash entry" to exercise the stash-count branch.

**Setup:**

```bash
cd /workspace
echo "// stash marker" > .stash-hu.txt
git stash push -u -m "session-start-smoke"
git status --porcelain                                   # expect: empty
git stash list                                           # expect: 1 entry
```

**Step:** `/clear` → observe session briefing.

**Expected:** briefing contains:

```
 ⚠ Heads up — WIP from a previous session:
   project has 1 stash entrie(s):
     stash@{0}: On main: session-start-smoke
```

**Cleanup:**

```bash
git stash drop
```

---

### Smoke 8 — `/ak-release-devshop` skill works end-to-end

The skill was written in the migration but never actually _invoked_ during the migration session — release.sh was called directly. Validate the skill's wrapper logic.

**Caveat:** a successful end-to-end run would cut a real release (v1.10.3 or later). **Don't run this unless there's a legitimate release to cut.** For pure skill-logic validation without a release, use Phase 1 only (assessment phase).

**Dry-run test (no release):**

1. Invoke `/ak-release-devshop` with the user (session human) present.
2. Phase 1 assesses: lists commits since last tag, categorizes, proposes bump level.
3. When the skill asks "Proceed?" — **decline**. ("No, this was a dry-run.")
4. Verify: no new commit, no tag, no kit/version change.

**Expected:** skill categorizes commits correctly (e.g., if all commits since last tag are `chore:`/`docs:`, skill says "No release needed — all commits are trivial."). If there's a mix, picks the highest-impact bump.

**Full run test (if legitimate release):**

- Run when there are actual commits on main that should be released. Let Phase 1 → Phase 2 → Phase 3 complete. Verify tag + GitHub release + downstream repos can pin to new version.

---

## Rollup

After running Smokes 1-8, produce a status line per smoke:

- ✅ pass: expected behavior observed, no regressions.
- ⚠ warn: technically worked but had unexpected output / timing.
- ❌ fail: hook didn't fire, or fired wrong way, or produced subagent noise.

If any ❌ or too many ⚠, file findings as a follow-up plan in this same directory (e.g., `kit/notes/roadmap/hook-migration-hotfix-v2.md`) and assess whether to release a patch.

If all ✅: update the parent plan ([`hook-migration-plan.md`](hook-migration-plan.md)) to add a "Verification COMPLETE 2026-XX-XX" line in the Status block, citing this doc.

---

## What this verification does NOT cover

Out of scope for this test run — tracked separately:

- **Bats test infrastructure for `.husky/pre-push`**: deferred per the parent plan line 501 (ROADMAP "Devshop testing → Hook tests"). Manual smokes above substitute for that infrastructure on this one release.
- **Adversarial-review.sh new case arm coverage**: no engine-level tests for `prDescStaleReason` or `dirtyPushReason` — matches the existing untested case arm pattern (docsVerified, dirtyTreeReason, etc.). Same ROADMAP deferral.
- **`release.sh` rollback behavior**: separately covered in [`release-rollback-plan.md`](release-rollback-plan.md) (v1.10.1 + v1.10.2 releases verified the rollback + empty-changelog guard).
- **Hooks in project repos (`/workspace`)**: if the project repo ever gets different hook configs from /devshop, add Smoke 1b/2b/etc. targeting /workspace specifically. Currently both repos share the same hook via normalized settings.json — no divergence to test.

---

## Quick reference — commands cheat sheet

```bash
# Is the migration still applied?
jq '.hooks | has("PostToolUse")' /devshop/.claude/settings.json          # expect: false
jq '.hooks | has("PostToolUse")' /workspace/.claude/settings.json        # expect: false
test -f /devshop/.husky/pre-push && echo ok                              # expect: ok
grep -c prDescStaleReason /devshop/kit/scripts/adversarial-review.sh     # expect: > 0

# Run the pre-push hook directly (for smokes that synthesize stdin)
echo "<refs>" | bash /devshop/.husky/pre-push origin

# Override a bypass flag for one invocation (non-persistent)
GIT_CONFIG_PARAMETERS="'devshop.dirtyPushReason=<reason>'" bash /devshop/.husky/pre-push origin

# Verify session-start additions
bash /devshop/kit/scripts/session-start.sh | jq -r .systemMessage | head -20
```

If the script outputs don't match expectations: re-read [`hook-migration-plan.md`](hook-migration-plan.md) for the original design intent, then diff the current state against it.
