---
name: upgrade
description: Upgrade the project's devshop version (.devshop-version) in one PR, bringing the project's copies of devshop files with it. Use when the owner asks to upgrade or re-pin the devshop, or a DEVSHOP line says the project's copies of devshop files differ.
---

# Upgrade the devshop version

One PR moves `.devshop-version` from OLD (the file's SHA; none means `HEAD`) to NEW and brings the
files the devshop places in the project along (L-49). The version's `project-files.txt` names each
one and its owner: `devshop` (an identical copy) or `seed` (the project's own, started from a
template). Run every step from the project root on a fresh branch from `main`. Abbreviations:
`PF=/opt/devshop-current/scripts/project-files.py`, `D=/opt/devshop.git`.

## 1. Pick NEW

- NEW is what the owner names, else the newest `main` in the local copy:
  `git --git-dir=$D rev-parse HEAD`. Show the commits: `git --git-dir=$D log --oneline OLD..NEW`.
- `plan` stops with "not in the devshop copy" when NEW is newer than the copy, which refreshes only
  when the environment's cache rebuilds. Tell the owner to rebuild the environment, then stop.

## 2. Show the plan

Run `$PF plan --devshop-git $D --from OLD --to NEW --project .` and show the owner its sections:

- **`devshop` files:** each diff from the project's copy to NEW. These come all or nothing: the
  owner takes them, or the upgrade waits. A copy the project needs to differ is a devshop bug (fix
  it in the devshop, or make the file a `seed` there), never a local edit.
- **`seed` files:** what the template changed and the commits that changed it. Don't apply the
  template's hunks: write the change to the project's own file that brings what it needs, show
  that diff, and ask the owner per file (apply, change, or skip with a reason).
- **Removed from the manifest:** the project keeps the file; ask whether to delete it.
- "Removals can't be listed" means OLD predates the manifest; say so, don't call it checked.

## 3. Apply what the owner confirmed

- Each `devshop` file: `$PF apply --devshop-git $D --version NEW --project . --file <path>`. It
  refuses seeds, unlisted paths and symlinks; a refusal is a stop, not a workaround.
- Each confirmed seed change: edit the project's file by hand, exactly as shown.
- Write NEW (the full SHA) to `.devshop-version`.
- Run `$PF check --devshop-git $D --version NEW --project .` (exit 0), then the project's
  `scripts/check-fast.sh origin/main`. A red check stops the upgrade: an owned script and the seed
  that calls it can change together.

## 4. Open the PR

Commit everything in one commit, then open the PR through `ship`
(`/opt/devshop-current/reviewer/ship.sh`). The title says what moves, e.g. "Pin the devshop to
<sha12>: <what the project gains>". The body lists each file with its owner and outcome (applied,
changed, skipped and why), any file removed from the manifest, and the checks you ran.

A project's formatter must leave `devshop` copies alone, or every session reports them as drift.
