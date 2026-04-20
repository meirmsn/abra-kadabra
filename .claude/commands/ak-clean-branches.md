Delete merged branches both locally and on origin — handles squash-merged PRs where commit hashes differ, AND stragglers on origin when the repo doesn't auto-delete merged branches.

## Phase 1 — Refresh state

Switch to main and pull latest so merge info is up to date. Also run `git remote prune origin` to clean stale remote-tracking refs (these are separate from actual remote branches — pruning just drops local `origin/*` refs for branches that no longer exist on the remote).

## Phase 2 — Identify deletion candidates

### Local branches

For each local branch (excluding `main`, `master`, or any protected default):

1. Check if `gh pr list --head <branch> --state merged --limit 1` finds a merged PR. If yes, the branch is safe to delete locally.
2. If no merged PR found, check if the branch tip's tree diff against main is empty (`git diff main...<branch> --quiet`). If yes, all changes are already on main.
3. If neither, keep the branch and report it as still active.

### Remote branches still on origin

Independent of the local check: walk recently-merged PRs for branches the remote never deleted (common when the repo doesn't have GitHub's "auto-delete head branches" enabled, or when a merge went through external tooling).

```bash
gh pr list --state merged --limit 50 --json headRefName,mergeCommit,baseRefName
```

For each row:

- Skip if `headRefName` is `main` / `master` / any protected default (defensive — a malformed PR could have the wrong `headRefName`).
- Skip if `baseRefName` is anything other than the repo's default base (e.g., a feature-into-feature merge — don't touch those).
- Check `git ls-remote origin refs/heads/<headRefName>`. If the ref still exists on origin, it's a deletion candidate.

Surface the count as a stat ("N merged PRs with branches still on origin") — useful for repo hygiene audits even when the local side is already clean.

## Phase 3 — Edge case: currently-checked-out branch

If any deletion candidate (local OR remote) matches the currently-checked-out branch, `git checkout main` first. Git refuses to delete the branch you're HEAD of, which silently no-ops the cleanup — this is how the 2026-04-20 `chore/close-auth-build-log` leftover was missed (the command appeared to succeed but didn't delete the branch).

Print a one-line notice when this happens: "Switched to main (was on <branch>, which is in the deletion set)."

## Phase 4 — Confirm + delete

Show the user the combined list:

- **Local branches to delete** — each with detection method (merged PR #N vs empty diff vs both)
- **Remote branches to delete** (on origin) — each with PR #N reference
- **Branches kept** (and why, e.g., "no merged PR found, diff against main is non-empty")

Ask for confirmation. On approval:

- Local: `git branch -D <branch>` for each
- Remote: `git push origin --delete <branch>` for each

## Phase 5 — Report

- Local branches deleted (list + count)
- Remote branches deleted (list + count)
- Stale tracking refs pruned (count from Phase 1)
- Branches kept active (list + reason)
