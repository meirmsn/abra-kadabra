---
name: new-project
description: Set up a new project repo from the devshop: place its files, open the first PR with green CI, and walk the owner through the steps only they can do. Use in a repo with no .devshop-version and no CI yet.
---

# New project

The first session in a repo the owner just created. This is set-up, not a change: no spec. The
steps only the owner can do are in `/opt/devshop-current/templates/new-project-steps.md`; the owner
did its part 1 before this session.

## 1. Check, and stop with the reason on any miss

- `origin/main` exists. An empty repo has none: the owner creates the repo with a README.
- No `.devshop-version` and no `.github/workflows/ci.yml`: else this isn't a new project; go to
  `devshop:intent`.
- A clean tree, on a fresh branch cut from `origin/main`.
- `gitleaks` and `python3` run.

## 2. Place the files

- Ask the owner for their GitHub user name (it goes in `.github/CODEOWNERS`).
- Run, from the project root:
  `/opt/devshop-current/scripts/project-files.py init --devshop-git /opt/devshop.git --version <release> --project . --codeowner <name>`,
  where `<release>` is what `/opt/devshop-plugin/devshop/upgrade/latest-release.sh --devshop-git /opt/devshop.git`
  prints: the newest devshop release (`vX.Y.Z`). It exits 1 when the environment's copy predates
  the first release: the owner rebuilds the environment. Never pin a branch or a commit SHA.
- A refusal writes nothing: say what it named, stop. A failure after a write lists what it wrote:
  delete those files, then stop.
- Run `scripts/check-fast.sh origin/main` and `scripts/check-slow.sh`. Both pass, or stop: a fresh
  project that fails its own checks is a devshop bug, so give the owner the output.

## 3. The first PR

- One commit, "Start from the devshop"; then `devshop:pr`. The body's **What you should know**
  carries the owner's part 2 of the steps, filled in with this repo's exact names.
- Leave it unmerged until the owner has done part 2 (protection on `main` names the checks CI's
  first run created). Then check each step from outside as the list says, and ask for the
  approval. A check that fails goes back to the owner with what you saw.

## 4. After the merge

The stack comes with the first change: the owner's next request goes through `devshop:intent`, and
its spec names the stack. That stack's home (`/opt/devshop-current/stacks/`) has a `## Set-up`
section with its own owner steps, given to the owner the same way.
