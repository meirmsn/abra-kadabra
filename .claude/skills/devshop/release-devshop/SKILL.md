---
name: ak-release-devshop
version: 1.0.0
description: |
  Run the devshop (abra-kadabra) release flow — categorize commits since last tag,
  propose version bump, run release.sh, verify tag + GitHub release.
  Use when asked to "release the devshop", "release abra-kadabra", "bump version",
  "cut a release", or after merging changes to abra-kadabra main.
  Proactively suggest after a PR merges to abra-kadabra `main` with `feat:`/`fix:`/
  `BREAKING CHANGE:` commits since the last tag. (devshop)
allowed-tools:
  - Bash
  - Read
---

# /ak-release-devshop

Owns the devshop (abra-kadabra) release flow. Replaces the old PostToolUse commit-time reminder (deleted in the 2026-04-18 hook architecture migration) with an explicit, invokable skill — so the release decision is made deliberately, not as a noisy post-commit nudge.

## When to invoke

- After a PR merges to abra-kadabra `main` that contains `feat:`, `fix:`, or `BREAKING CHANGE:` commits since the last tag.
- When the user asks to release / bump version / cut a release on the devshop.
- When you've finished a logical chunk of devshop work on `main` and there are user-facing changes that project repos should be able to pin to.

Skip if commits since the last tag are all trivial (`chore:` / `docs:` / `style:` / `test:` / `ci:` / `build:` / `perf:`) unless the user explicitly wants to bump anyway.

## Phase 1 — Assess

Run from `/devshop`:

```bash
cd /devshop

# Must be on main (release.sh enforces this, but fail early if not)
git branch --show-current

# Commits since last tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
[ -n "$LAST_TAG" ] && git log --oneline "$LAST_TAG"..HEAD || git log --oneline -20

# Current version
cat kit/version
```

Categorize each commit:

| Prefix                                                               | Impact         |
| -------------------------------------------------------------------- | -------------- |
| `feat!:` / `fix!:` / `BREAKING CHANGE:` in body                      | **major** bump |
| `feat:`                                                              | **minor** bump |
| `fix:`                                                               | **patch** bump |
| `chore:` / `docs:` / `style:` / `test:` / `ci:` / `build:` / `perf:` | no bump (skip) |

Take the **highest-impact** category that appears. Example: if there's one `feat:` and ten `docs:`, it's a minor bump — the feat wins.

Then tell the user:

> Current: `X.Y.Z` → Proposed: `X.Y.Z+bump` (**<level>** — because <specific commit or reason>)
>
> Commits since `v<X.Y.Z>`:
> <short list>
>
> Proceed?

Wait for confirmation. If the user overrides the level, use theirs.

If all commits are trivial, say:

> No release needed — all commits since `v<X.Y.Z>` are trivial (<list of prefixes>).
> To force a bump anyway, say so explicitly.

And exit.

## Phase 2 — Execute

Only after explicit confirmation:

```bash
cd /devshop
bash kit/scripts/release.sh --bump <level>
```

`release.sh` handles:

1. Writing new version to `kit/version`
2. Generating a changelog entry from `$LAST_TAG..HEAD` commits
3. Creating a bump commit — this triggers the `release-coverage` pre-commit adversarial review. If the review blocks, surface the reason to the user and stop. Do not bypass without explicit user direction.
4. Tagging `v<new>`
5. Pushing to origin + creating a GitHub release (if `DEVSHOP_GITHUB_TOKEN` is set in `/etc/devshop-env`)

If `release-coverage` blocks (e.g., missing test for a new script), the user can:

- Add the missing test, then re-run `/ak-release-devshop`
- Provide `git -c devshop.releaseReviewed="<reason>"` override (adversarially reviewed — be specific)

## Phase 3 — Confirm

Verify the release landed:

```bash
cd /devshop
git tag --sort=-v:refname | head -3           # new tag at top
git log --oneline -3                          # bump commit visible
gh release view "v$(cat kit/version)"          # GitHub release exists
```

Tell the user:

> Released `v<new>`. Tag and GitHub release visible on origin.
>
> Downstream projects pinning to a specific devshop version may need their pin bumped — flag to user if known.

## Out of scope

- **Auto-trigger on PR merge**: this skill is manually invoked (or invoked by a future `/ak-go-live-devshop` chain). Automatic post-merge release is a separate consideration — requires detecting "merged to main" context and deciding autonomously whether to release.
- **Cross-repo coordination**: if a devshop release breaks a project (e.g., a script interface change), the project's consuming code is not touched by this skill. The user is responsible for propagating the upgrade.
