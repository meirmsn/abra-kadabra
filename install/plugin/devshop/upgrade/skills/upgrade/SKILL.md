---
name: upgrade
description: Upgrade the project's devshop version (.devshop-version) in one PR, bringing the project's copies of devshop files with it. Use when the owner asks to upgrade or re-pin the devshop, or a DEVSHOP line says the project's copies of devshop files differ.
---

# Upgrade the devshop version

One PR moves `.devshop-version` from OLD (the file's release tag or SHA; none means `HEAD`) to NEW and brings the
files the devshop places in the project along (L-49). NEW's `runtime/project-files.txt` names each
one and its owner: `devshop` (an identical copy; one marked `optional` is brought only where the
project has it) or `seed` (the project's own, started from a template). This skill comes with the
install, not the pinned version, so it works from any pin; its
wrapper runs NEW's own script. Run every step from the project root on a fresh branch from `main`.
Abbreviations: `D=/opt/devshop.git`,
`PF=/opt/devshop-plugin/devshop/upgrade/project-files-at.sh --devshop-git $D --at NEW`.

## 1. Pick NEW

- NEW is what the owner names, else the newest release in the local copy:
  `/opt/devshop-plugin/devshop/upgrade/latest-release.sh --devshop-git $D` (exit 1, no release yet:
  `main`, `git --git-dir=$D rev-parse HEAD`). Show what changed: the commits,
  `git --git-dir=$D log --oneline OLD..NEW` (the release notes on GitHub group the same subjects).
  A major release (its first number changes) needs a migration: say so first.
- `$PF` stops with "not in the devshop copy" when NEW is newer than the copy, which refreshes only
  when the environment's cache rebuilds. Tell the owner to rebuild the environment, then stop.

## 2. Show the plan

Run `$PF plan --from OLD --to NEW --project .` and show the owner its sections:

- **`devshop` files:** each diff from the project's copy to NEW. These come all or nothing: the
  owner takes them, or the upgrade waits. A copy the project needs to differ is a devshop bug (fix
  it in the devshop, or make the file a `seed` there), never a local edit.
- **`seed` files:** what the template changed and the commits that changed it. Don't apply the
  template's hunks: write the change to the project's own file that brings what it needs, show
  that diff, and ask the owner per file (apply, change, or skip with a reason).
- **Removed from the manifest:** the project keeps the file; ask whether to delete it.
- "Removals can't be listed" means OLD predates the manifest; say so, don't call it checked.

## 3. Apply what the owner confirmed

- Each `devshop` file: `$PF apply --version NEW --project . --file <path>`. It refuses seeds,
  unlisted paths and symlinks; a refusal is a stop, not a workaround.
- Each confirmed seed change: edit the project's file by hand, exactly as shown.
- Write NEW as named (a release tag, else the full SHA) to `.devshop-version`.
- Run `$PF check --version NEW --project .` (exit 0), then the project's
  `scripts/check-fast.sh origin/main`. A red check stops the upgrade: an owned script and its seed
  can change together.

## 4. Open the PR

Commit everything in one commit, then invoke `devshop:pr`, which writes the body from the PR
template (a pin from before it has no `pr` skill: follow `devshop:build`'s PR section). The title
says what moves, e.g. "chore: pin the devshop to v2.1.1, <what the project gains>". **What you
should know** lists each file with its owner and outcome (applied, changed, skipped and why), any
file removed from the manifest, and the checks you ran; no Announcement.

A project's formatter must leave `devshop` copies alone (`.prettierignore` for the `.mjs` ones), or
every session reports them as drift. What `scripts/contract-check.py` then reports goes in the same PR.
