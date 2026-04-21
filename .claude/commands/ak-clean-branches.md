Delete merged branches both locally and on origin — handles:

- **Squash-merged PRs** where commit hashes differ from main (PR-anchored detection)
- **Fast-forward-merged branches with no PR** (ancestry-anchored detection — needed for devshop's no-PR flow where landing = `git merge --ff-only`)
- **Stragglers on origin** when the repo doesn't auto-delete merged branches

Both detection methods run in sequence (PR-path → ancestry-path) for both local and remote branches. Either match = safe to delete; neither = keep active.

## Phase 1 — Refresh state

Switch to main and pull latest so merge info is up to date. Also run `git remote prune origin` to clean stale remote-tracking refs (these are separate from actual remote branches — pruning just drops local `origin/*` refs for branches that no longer exist on the remote).

**Origin must be reachable** for the remote-branch enumeration + ancestry fetches. If `origin` is SSH but the session lacks an SSH key, use an HTTPS-with-token override for the remote queries. For **abra-kadabra (devshop)** where origin is SSH by convention:

```bash
source /etc/devshop-env
# Pass the HTTPS URL to any command that hits the remote:
ORIGIN_URL="https://x-access-token:${DEVSHOP_GITHUB_TOKEN}@github.com/meirmsn/abra-kadabra.git"
git -c "remote.origin.url=$ORIGIN_URL" ls-remote origin 'refs/heads/*'
git fetch "$ORIGIN_URL" --prune
```

For projects where origin is already HTTPS (via a PAT in the git credential helper), use `origin` directly.

## Phase 2 — Identify deletion candidates

### Local branches

For each local branch (excluding `main`, `master`, or any protected default):

1. **Method A (PR-anchored)**: `gh pr list --head <branch> --state merged --limit 1` finds a merged PR → safe to delete.
2. **Method B (ancestry-anchored)**: `git diff main...<branch> --quiet` is empty → all commits are already on main (either squash-merged with the same content, or ff-merged) → safe to delete.
3. **Neither** → keep the branch and report it as still active.

Annotate each candidate with the method that matched (PR vs ancestry vs both — both fire when a feature was PR-merged AND its tip happens to equal main, e.g., an ff-merged PR).

### Remote branches still on origin

Enumerate all remote branches, then classify each with the same two-method test:

```bash
git ls-remote origin 'refs/heads/*' \
  | awk '{print $2}' \
  | sed 's|refs/heads/||' \
  | grep -vE '^(main|master)$'
```

For each remote branch `$b`:

1. **Method A (PR-anchored)**: `gh pr list --head "$b" --state merged --limit 1 --json number --jq '.[0].number'` returns a number → safe to delete on origin, record the PR ref. Skip rows where the merged PR's `baseRefName` isn't the repo's default (feature-into-feature merges don't count).
2. **Method B (ancestry-anchored)**: fetch the remote tip locally, then check `git merge-base --is-ancestor <tip> main`. If yes → safe to delete on origin (the branch's work is already on main via ff-merge). The fetch is cheap and idempotent:

   ```bash
   REMOTE_SHA=$(git ls-remote origin "refs/heads/$b" | awk '{print $1}')
   git fetch origin "$b:refs/remotes/origin/$b" 2>/dev/null || true
   git merge-base --is-ancestor "$REMOTE_SHA" main
   ```

3. **Neither** → keep active (branch has commits not on main and no merged PR — could be work-in-progress, could be abandoned with valuable unreachable state).

Surface the count as a stat: `"N remote branches — M via merged PR, K via ancestry, L kept active"`. Useful for repo hygiene audits even when the local side is already clean.

**Why both methods matter**:

- Projects with PRs (e.g., lalista): squash-merge creates a new commit on main. The feature branch's tip is NOT an ancestor of main, so Method B alone would miss it. Method A catches it via the merged-PR record.
- Projects without PRs (e.g., abra-kadabra devshop): ff-merge moves main's pointer to the feature-branch tip. There's no PR record to find, so Method A alone would miss it. Method B catches it via ancestry.

Both projects can have either situation (e.g., a project that sometimes ff-merges, sometimes squash-merges), so running both methods in both repos is correct.

## Phase 3 — Edge case: currently-checked-out branch

If any deletion candidate (local OR remote) matches the currently-checked-out branch, `git checkout main` first. Git refuses to delete the branch you're HEAD of, which silently no-ops the cleanup — this is how the 2026-04-20 `chore/close-auth-build-log` leftover was missed (the command appeared to succeed but didn't delete the branch).

Print a one-line notice when this happens: "Switched to main (was on <branch>, which is in the deletion set)."

## Phase 4 — Confirm + delete

Show the user the combined list:

- **Local branches to delete** — each with detection method (`merged PR #N`, `empty diff (ancestry)`, or `both`)
- **Remote branches to delete** (on origin) — each with detection method (`merged PR #N` or `tip ancestor of main (ff-merged, no PR)`)
- **Branches kept active** — with reason (`no merged PR, tip has commits not on main — possibly WIP or abandoned with unreachable state`)

Ask for confirmation. On approval:

- Local: `git branch -D <branch>` for each
- Remote: `git push origin --delete <branch>` for each (or `git push "$ORIGIN_URL" --delete <branch>` when using the HTTPS-token override from Phase 1)

## Phase 5 — Report

- Local branches deleted (list + count + detection-method breakdown)
- Remote branches deleted (list + count + detection-method breakdown)
- Stale tracking refs pruned (count from Phase 1)
- Branches kept active (list + reason) — **flag any "kept with unreachable state" branches for user attention** (could be accidentally-abandoned work worth investigating)
