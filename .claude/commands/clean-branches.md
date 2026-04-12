Delete local branches whose changes are already on main — handles squash-merged PRs where commit hashes differ.

First, switch to main and pull latest so merge info is up to date.

For each local branch (excluding main):

1. Check if `gh pr list --head <branch> --state merged` finds a merged PR. If yes, the branch is safe to delete.
2. If no merged PR found, check if the branch tip's tree diff against main is empty (`git diff main...<branch> --quiet`). If yes, all changes are on main.
3. If neither, keep the branch and report it as still active.

Also run `git remote prune origin` to clean stale remote-tracking refs.

Before deleting, show the user the list of branches that will be removed and which detection method matched (merged PR vs empty diff). Then delete them with `git branch -D`.

Report: branches deleted, branches kept (and why), remote refs pruned.
