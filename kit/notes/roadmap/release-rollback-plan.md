# release.sh Atomic Rollback on Failure

**Status**: **EXECUTED 2026-04-19** on `feature/release-atomic-rollback` (fast-forwarded into main, released as v1.10.1 via `release.sh --bump patch`).
**Scope delivered**: ~50 LoC added to `/devshop/kit/scripts/release.sh`. One commit on the feature branch; a second commit in the same branch clarified the devshop shipping flow in CLAUDE.md.
**Deviation from plan**: `PHASE="committed"` is set _immediately after_ `git commit` (before `git tag`), so a tag failure falls into the `committed` phase (keep commit, retry manually) rather than the `modifying` phase (which would try to restore already-committed files). Rollback message lists the manual retry steps: tag (if needed) + push + `gh release create`.
**Verification**: 4-scenario isolated trap harness passed before install — `modifying-fail` restores files to HEAD; `tag-fail-after-commit` keeps commit, no tag; `push-fail-after-tag` keeps commit + tag; `success` no-ops the trap. Harness script at `/tmp/test-rollback.sh` (one-shot, not committed).
**Authoring date**: 2026-04-19

---

## Context

`release.sh` (at `/devshop/kit/scripts/release.sh`) bumps the devshop version, updates `kit/docs/CHANGELOG.md`, commits, tags, and pushes — in that order. The current implementation has a partial-state failure mode:

```bash
echo "$NEW_VERSION" > "$VERSION_FILE"             # 1. write version file
bash changelog-entry.sh ...                       # 2. update CHANGELOG
git add "$VERSION_FILE" "$CHANGELOG_PATH"         # 3. stage
git commit -m "..."                               # 4. commit ← can fail here
git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION"     # 5. tag
# 6. push (HTTPS+token if available)              # ← can also fail here
```

The commit at step 4 triggers the husky pre-commit chain: lint-staged → gitleaks → bats kit/tests/ (174 tests) → devshop-commit-guard.sh (clean-tree, manifest, test-coverage, docs-drift adversarial, doc-consistency, cross-repo, **release-coverage adversarial**). Any of these can reject.

**Failure mode today**: if the commit fails (tests fail, release-coverage adversarial rejects, network blip, etc.), `kit/version` is already overwritten on disk with the new version, `kit/docs/CHANGELOG.md` has a new entry, both files are staged. The user has a dirty tree with the bump partially applied. They have to manually `git restore --staged` and `git restore` the two files to reset to a clean state before retrying.

**This nearly bit during v1.9.0 release** — the release-coverage adversarial review could have rejected, leaving a dirty tree. It happened to accept on first try, so the bug stayed latent.

The push step (after commit/tag) is a separate failure mode: if the commit + tag succeed but push fails (auth issue, network), the local commit + tag are in a fine state but unpushed. We should NOT roll those back — adversarial review is expensive and re-running the whole flow would re-trigger it. User just needs to retry push.

## Approach

Shell `trap` on `EXIT` that inspects a `PHASE` variable and rolls back to the appropriate state:

| Phase       | When                                               | Rollback action                                                                                                 |
| ----------- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `init`      | Script just started, no modifications yet          | None (nothing to roll back)                                                                                     |
| `modifying` | Files written + staged but commit hasn't succeeded | Restore `kit/version` and `kit/docs/CHANGELOG.md` to HEAD via `git restore --staged` + `git restore`            |
| `committed` | Commit + tag succeeded, push step failed or after  | KEEP the local commit + tag (preserves the adversarial review work). Print instructions to retry push manually. |
| `completed` | Full success including push + GitHub release       | None (no-op)                                                                                                    |

The trap fires on every script exit (success OR failure), but the case statement makes only the relevant phase do work.

**Why this design** (rather than e.g. always rolling back commit + tag too):

- Adversarial release-coverage review is expensive (LLM call, ~5-10s) and represents real cognitive work judging coverage of changes since last tag.
- If push fails for a transient reason (network, auth blip), forcing the user to re-trigger that review wastes time and money.
- Commit + tag are local-only state that can be pushed later without semantic loss.
- Working tree dirty state, by contrast, IS a problem — it leaves the user mid-bump and creates confusion on next invocation.

So: roll back the dirty-tree problem, preserve the commit/tag work.

## Proposed code

Full content of the modified `/devshop/kit/scripts/release.sh`. The diff vs. the current version (v1.9.0 era):

- Added comment block in the header (lines 12-22) explaining the rollback semantics.
- Moved `CHANGELOG_PATH` definition earlier (line 55) so the trap function can reference it.
- Added rollback function + `trap rollback EXIT` (lines 120-150).
- Added `PHASE="modifying"`, `PHASE="committed"`, `PHASE="completed"` markers at the right points in the existing flow.

No behavior change in the success path — only error paths are affected.

```bash
#!/bin/bash
# release.sh — bump devshop version and tag. For direct devshop repo edits.
# Run from the devshop repo root (not a project repo).
# Shows changes since last version tag, suggests bump level, asks for confirmation.
#
# Test coverage review: the `release-coverage` check in devshop-commit-guard.sh
# fires on the bump commit (triggered by kit/version being staged) and runs an
# adversarial review of the changes since the last tag. Runs once per release,
# not per commit. Cannot be bypassed by skipping release.sh — any bump commit
# triggers it regardless of how the bump was made.
#
# Atomic rollback on failure: any step before the commit (incl. husky pre-commit
# tests + adversarial reviews) failing → kit/version and kit/docs/CHANGELOG.md
# are restored to HEAD via a shell trap, so re-running release.sh starts from a
# clean slate. If the commit + tag SUCCEED but the push fails, the local commit
# and tag are KEPT — adversarial review is expensive and we don't want to
# re-trigger it on retry. The trap inspects PHASE to know which mode to apply:
#   - modifying  → files written but commit failed → roll back fully
#   - committed  → commit + tag survived; push failed → keep, retry push only
#   - completed  → all good → no-op
# See PHASE/rollback below.
#
# Usage:
#   release.sh                # interactive (prompts for bump level + confirm)
#   release.sh --bump patch   # non-interactive (for Claude)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="kit/version"

# Parse args
ARG_BUMP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump) ARG_BUMP="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

if [ ! -f "$VERSION_FILE" ]; then
  echo "ERROR: $VERSION_FILE not found. Are you in the devshop repo root?"
  exit 1
fi

# Guard: releases only from main
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo "ERROR: Releases must be from main (currently on '$CURRENT_BRANCH')."
  echo "Merge or rebase to main first, then release."
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
LAST_TAG="v$CURRENT_VERSION"
CHANGELOG_PATH="$(pwd)/kit/docs/CHANGELOG.md"

echo "Current version: $CURRENT_VERSION"
echo ""

# Show changes since last tag
if git rev-parse "$LAST_TAG" &>/dev/null; then
  echo "Changes since $LAST_TAG:"
  git log --oneline "$LAST_TAG"..HEAD
  echo ""

else
  echo "No previous tag found. This will be the first tagged release."
fi

# Pre-release test coverage review runs in the commit guard — see the
# release-coverage check in kit/scripts/devshop-commit-guard.sh. Triggered by
# kit/version being staged, which happens below when release.sh writes the new
# version and calls `git commit`. The review covers all changes since $LAST_TAG
# via the adversarial agent. Cannot be bypassed by calling `git tag` directly
# without a bump commit.

if [ -n "$ARG_BUMP" ]; then
  BUMP="$ARG_BUMP"
elif [ -t 0 ]; then
  # Interactive — prompt the user
  read -p "Bump level (patch/minor/major): " BUMP
else
  echo "ERROR: --bump is required in non-interactive mode."
  echo "Analyze the changes since the last release to determine the level:"
  echo "  patch — bug fixes, doc updates, internal refactors"
  echo "  minor — new capabilities, structural changes, new scripts/skills"
  echo "  major — breaking changes that require project-side updates"
  exit 1
fi

# Calculate new version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case "$BUMP" in
  patch) PATCH=$((PATCH + 1)) ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
  *) echo "Invalid bump level: $BUMP"; exit 1 ;;
esac
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

echo ""
echo "Bumping $CURRENT_VERSION -> $NEW_VERSION"

if [ -z "$ARG_BUMP" ]; then
  # Interactive — confirm before proceeding
  read -p "Confirm? (y/n): " CONFIRM
  if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 1
  fi
fi

# Generate changelog message from commits since last tag
if git rev-parse "$LAST_TAG" &>/dev/null; then
  CHANGELOG_MSG=$(git log --oneline "$LAST_TAG"..HEAD | sed 's/^[a-f0-9]* /- /')
else
  CHANGELOG_MSG="- Initial release"
fi

# --- Atomic rollback on failure ---
# PHASE tracks how far we got. The trap on EXIT inspects PHASE and rolls back
# accordingly (see header comment for full intent):
#   modifying  → files written + staged but commit didn't succeed → restore
#                HEAD state for kit/version + CHANGELOG.md so re-running is clean.
#   committed  → commit + tag succeeded but push failed → KEEP commit + tag
#                (so user re-runs push only; preserves adversarial review work).
#   completed  → full success → no-op.
# This means a transient test failure or network blip doesn't leave a dirty tree.
PHASE="init"
rollback() {
  local exit_code=$?
  case "$PHASE" in
    modifying)
      echo ""
      echo "✖ Release failed before commit (exit $exit_code) — rolling back kit/version and CHANGELOG.md to HEAD."
      git restore --staged "$VERSION_FILE" "$CHANGELOG_PATH" 2>/dev/null || true
      git restore "$VERSION_FILE" "$CHANGELOG_PATH" 2>/dev/null || true
      ;;
    committed)
      echo ""
      echo "⚠ Commit + tag (v$NEW_VERSION) succeeded locally but a later step failed (exit $exit_code)."
      echo "   Local commit + tag are KEPT (so you don't re-trigger adversarial review on retry)."
      echo "   Retry just the push:  git push origin main --tags"
      echo "   Then if needed:       gh release create v$NEW_VERSION --notes \"\$CHANGELOG_MSG\""
      ;;
    completed) ;; # success, no-op
  esac
}
trap rollback EXIT

# Write new version, update changelog, commit, tag
PHASE="modifying"
echo "$NEW_VERSION" > "$VERSION_FILE"
bash "$SCRIPT_DIR/changelog-entry.sh" "$NEW_VERSION" "$CHANGELOG_MSG" "$CHANGELOG_PATH"
git add "$VERSION_FILE" "$CHANGELOG_PATH"
git commit -m "Bump devshop version to $NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "v$NEW_VERSION"
PHASE="committed"

# Push + create GitHub release (if devshop token is available)
# DEVSHOP_GITHUB_TOKEN is written to /etc/devshop-env by init-devshop.sh.
# Remote stays SSH — we construct a transient HTTPS URL just for the push.
source /etc/devshop-env 2>/dev/null || true
echo ""
if [ -n "$DEVSHOP_GITHUB_TOKEN" ]; then
  _REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  _REPO_PATH=$(echo "$_REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
  _PUSH_URL="https://x-access-token:${DEVSHOP_GITHUB_TOKEN}@github.com/${_REPO_PATH}.git"
  git push "$_PUSH_URL" HEAD --tags
  GH_TOKEN="$DEVSHOP_GITHUB_TOKEN" gh release create "v$NEW_VERSION" \
    --repo "$_REPO_PATH" \
    --title "v$NEW_VERSION" \
    --notes "$CHANGELOG_MSG"
  unset _REMOTE_URL _REPO_PATH _PUSH_URL
  echo "Done. v$NEW_VERSION pushed and released on GitHub."
else
  echo "Done. Version bumped to $NEW_VERSION and tagged v$NEW_VERSION."
  echo "Push with: git push (tags included if push.followTags is set)"
  echo "No DEVSHOP_GITHUB_TOKEN — run init-devshop.sh with .devcontainer/.env to enable."
fi

PHASE="completed"
```

## Steps to execute

Prerequisites:

- Devshop on `main` branch with clean working tree (`git -C /devshop status` empty)
- Sudo access (the target file is root-owned per `Edit(/devshop/kit/scripts/*)` deny rule)
- `DEVSHOP_GITHUB_TOKEN` set in `/etc/devshop-env` (it's already there — used by release.sh's existing push)

### Step 1 — Verify state + diff against current

```bash
# Confirm state
git -C /devshop status              # should be clean
git -C /devshop branch --show-current  # should be main

# Read the current release.sh first to confirm no other changes have landed
# since this plan was authored (2026-04-19). If the file has drifted, reconcile
# by reading both versions and merging carefully.
diff /devshop/kit/scripts/release.sh <(curl -fsSL ... )  # OR write the proposed code to /tmp first then diff
```

If the current release.sh has changed substantially since 2026-04-19, **pause and reconcile** rather than overwriting. The intent (PHASE-tracked trap rollback) should still apply but the integration points might shift.

### Step 2 — Write the proposed code to /tmp

Copy the full script body from § "Proposed code" above into `/tmp/release.sh`. Use the `Write` tool with the file content.

Then syntax-check:

```bash
bash -n /tmp/release.sh && echo "Syntax OK"
```

### Step 3 — Install (root-owned, needs sudo)

```bash
sudo cp /tmp/release.sh /devshop/kit/scripts/release.sh
sudo chmod 644 /devshop/kit/scripts/release.sh
sudo chown root:root /devshop/kit/scripts/release.sh
```

The `chmod 644` is per the bats wiring test ("all kit/scripts/\*.sh tracked as 644 (not 755)"). Scripts are run via `bash <path>` not directly executed.

### Step 4 — Commit on main

The `check-branch-not-main.sh` PreToolUse hook BLOCKS Claude from committing on main. The user must run the commit themselves from a terminal (or via `! <cmd>` prefix in this session).

The commit needs `devshop.docsVerified` because docs-drift fires on any kit/ change. Suggested reason (covers all 7 reference docs):

```
Atomic rollback added to release.sh — internal script behavior change in error paths only; success path unchanged (verified by diff). Reviewed all 7 ref docs: (1) MODEL.md — no model concept introduced (rollback is implementation detail). (2) OVERVIEW.md — release flow from outside is unchanged: bump → commit → tag → push. (3) kit/docs/guide/ — release.sh's behavior is documented inline in the script's header comment block, now expanded to cover rollback semantics; no guide doc currently describes 'manual cleanup if release fails' that needs updating. (4) CLAUDE.md (devshop) — no convention change. (5) FAQ.md — no design rationale change (ergonomic improvement to one script). (6) CLAUDE.md (project) — N/A, devshop-only. (7) README.md — release.sh isn't user-facing in README. Behavior contract for future readers is captured in the expanded script header comment.
```

Commit command (paste with `!` prefix or run from terminal):

```bash
cd /devshop && git add kit/scripts/release.sh && git -c devshop.docsVerified="<paste reason above>" commit -m "feat(release): atomic rollback on commit failure

Add trap-based rollback to release.sh: if any step before the bump commit fails (test failures, adversarial review rejection, etc.), restore kit/version and kit/docs/CHANGELOG.md to HEAD state. If commit + tag succeed but push fails, KEEP commit + tag locally so retry doesn't re-trigger adversarial review.

Three phases tracked via PHASE variable + EXIT trap:
- modifying: files written but commit failed → roll back fully
- committed: commit/tag survived; push failed → keep, retry push only
- completed: success → no-op

Header comment block expanded to document the intended behavior so future readers understand the rollback semantics without having to trace the trap function.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

The husky pre-commit chain will fire: lint-staged → gitleaks → bats kit/tests/ (174 tests, expected pass — release.sh modifications don't break any existing tests) → devshop-commit-guard.sh including docs-drift adversarial review of the `docsVerified` reason. If the adversarial review accepts, commit lands. If it rejects, you'll see the reviewer's complaint — iterate the reason and retry.

### Step 5 — Push via HTTPS+token

```bash
source /etc/devshop-env && git -C /devshop push "https://x-access-token:${DEVSHOP_GITHUB_TOKEN}@github.com/meirmsn/abra-kadabra.git" main
```

This is the same HTTPS+token push pattern release.sh uses internally. Since this is a regular code commit (not a release commit), no tag to push; just `main`.

## Verification

After the commit + push lands:

1. **Inspect the diff on GitHub** to confirm the new code matches the proposed body — especially the rollback function, trap registration, and PHASE markers.

2. **Test rollback behavior** without doing a real release. The cleanest way:
   - Make a no-op modification on a feature branch (so we're NOT on main, which release.sh refuses)
   - Temporarily edit release.sh's branch guard to allow the test branch (revert before committing)
   - Or: use a throwaway clone of the devshop in /tmp where you can experiment freely

3. **Trigger a real failure path** — easiest way is to check for the rollback by:
   - Cd to /devshop on main
   - Manually create a dirty file: `echo "junk" > /tmp/junk.txt && cp /tmp/junk.txt kit/`
   - Run `bash kit/scripts/release.sh --bump patch`
   - Husky pre-commit's `check-clean-tree.sh` should fail (untracked file)
   - Verify: `kit/version` is back to original (rollback fired)
   - Cleanup: `rm kit/junk.txt`

   Don't actually merge any of this — just verify the rollback works by inspecting state.

4. **Trigger a real release** when there's actual work to release. The success path is unchanged from current behavior; only error path is now safer.

## If something goes wrong

If the new release.sh is broken (syntax error, trap doesn't fire, etc.), restore the previous version from git history:

```bash
# Find the previous version (before this commit)
git -C /devshop log --oneline kit/scripts/release.sh | head -5

# Restore
git -C /devshop show <previous_commit>:kit/scripts/release.sh > /tmp/release.sh.bak
sudo cp /tmp/release.sh.bak /devshop/kit/scripts/release.sh
sudo chown root:root /devshop/kit/scripts/release.sh
sudo chmod 644 /devshop/kit/scripts/release.sh

# Then commit the revert (from terminal, on main)
cd /devshop && git add kit/scripts/release.sh && git -c devshop.docsVerified="Reverting broken atomic rollback change to release.sh — the rollback didn't behave as designed and the simpler manual-cleanup-on-failure UX is acceptable interim. See kit/notes/roadmap/release-rollback-plan.md for the original intent and a follow-up rework." commit -m "revert: roll back atomic-rollback in release.sh"
```

Then push as in Step 5.

## Out of scope

- Auto-retry of the push step if it fails (user retries manually per the `committed` phase message).
- Auto-creation of GitHub release if the `gh release create` step fails after a successful push (user runs `gh release create` manually).
- Generalizing the trap pattern to other scripts (each script's failure model differs; case-by-case).
- Updating `kit/docs/guide/` docs to describe the rollback (release.sh isn't currently documented there at the level of detail this would require; the in-script header comment is the right place).

## Critical files

- **MODIFY (root-owned, sudo)**: `/devshop/kit/scripts/release.sh`

That's it. One file change.

## Why direct-to-main (no PR)

Discussed and authorized: this is a small isolated improvement to one script with no external API/contract changes. Husky pre-commit + adversarial review still gate the commit. Authorized by the user as a tactical fix. The hook architecture migration (separate plan in `notes/roadmap/hook-migration-plan.md`) is the larger devshop change going through the normal PR flow.
