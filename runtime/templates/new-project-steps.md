# New project: the owner's steps

The steps only the owner can do to start a project from the devshop (the devshop's spec
`specs/new-project.md`). The new project's first session (the `new-project` skill) fills in the
exact names (`<owner>/<repo>`, the agent's user name) and gives part 2 in the first PR's body.
Each step says how that session checks it from outside, with the agent's Write access; a check that
fails goes back to the owner with what the session saw. The stack's own steps (accounts, tokens,
environments) come later, from its home's `## Set-up` section, with the first change that needs
them.

## Once, on the devshop's repo

0. **Release immutability:** Settings → General → Releases: "Enable release immutability". A
   project pins a devshop release tag (`vX.Y.Z` in `.devshop-version`, never a branch or a commit
   SHA); with immutable releases, a published release and its tag can't be changed or moved, so a
   pin always means the same files. Projects don't publish releases, so this is not a step per
   project. Check: `gh api repos/<devshop owner>/<devshop repo>/releases/latest --jq .immutable` is
   `true` (a session that can't reach the devshop's repo says so, and the owner confirms).

## Part 1: before the first session

1. **Create the repo:** a new private GitHub repo, with a README (so `main` exists for the first
   PR). Check: `gh api repos/<owner>/<repo> --jq .private` is `true`, and
   `git ls-remote origin main` names a commit.
2. **Squash merging only, titled by the PR:** Settings → General → Pull Requests: allow squash
   merging only (merge commits and rebase merging off), its default commit message "Pull request
   title". Under GitHub's default, a one-commit PR lands with its commit's subject instead of the
   reviewed title, and a merge commit or rebase would carry a PR's screenshots into `main`. Check:
   `gh api repos/<owner>/<repo>` has `allow_squash_merge` true, `allow_merge_commit` and
   `allow_rebase_merge` false, `squash_merge_commit_title` `PR_TITLE`.
3. **The agent as a collaborator:** invite the agent identity with Write access (not Admin), and
   accept the invitation as the agent. Check: `gh api repos/<owner>/<repo> --jq .permissions` has
   `push` true and `admin` false.
4. **The Claude GitHub App:** give it access to the new repo, so cloud sessions can clone and push.
   Check: the session's clone and its first push work.
5. **A cloud environment for the repo:** the same two-line setup script as the other projects'
   environments, and Limited network access with the package registries and GitHub allowed (a
   stack's hosts are added with its first change). Check: the session's first reply opens with
   the devshop's `DEVSHOP:` line.

Then open a session in the repo and ask to set up the new project.

## Part 2: after the first PR's CI has run

6. **Protect `main`:** a branch ruleset (Settings → Rules → Rulesets; not a classic protection
   rule, which the agent can't read) targeting `main`, active, with an empty bypass list: changes
   only by pull request; 1 approval; review from code owners; approval of the most recent push;
   stale approvals dismissed; conversations resolved; required status checks `fast` and `slow` (they can be picked
   once CI has run on the first PR); force pushes and deletion blocked. Check:
   `gh api repos/<owner>/<repo>/rules/branches/main` lists those rules (a rule GitHub doesn't list
   there is checked by its refusal below).
7. **Code owners read:** nothing to do unless the check fails. Check:
   `gh api repos/<owner>/<repo>/codeowners/errors --jq '.errors | length'` is `0` (GitHub ignores a
   code owner who doesn't exist or can't write, and code-owner review then protects nothing).
8. **The walls hold:** nothing to do; the session tries what GitHub must refuse. Check: a direct
   push to `main` is refused, and merging the first PR without an approval is refused.

Then approve the first PR. The project's next request is its first change.
