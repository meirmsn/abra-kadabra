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
bash kit/scripts/release.sh --bump <level> --no-push
```

`release.sh --no-push` generates all release files and stages them, then
stops **before committing**:

1. Writing new version to `kit/version` + `template/.devshop-version`
2. Generating a changelog entry from `$LAST_TAG..HEAD` commits
3. Auto-generating `PROPAGATION.md` entry from `**Existing projects:**` blocks in commit messages
4. Staging all four files

The skill owns the commit, tag, push, and GitHub release from here.

## Phase 2.5 — Review PROPAGATION.md

Before committing, review the generated `PROPAGATION.md` entry for the
new version. The generator reads the `[auto]`/`[manual]`/`[conditional]`
disposition tag on each commit's `**Existing projects:**` block: `[auto]`
blocks are deliberately dropped (they auto-propagate; the audit trail stays
in the commit), `[manual]`/`[conditional]` blocks are kept. So `(no manual
steps)` is a **valid, correct end state** when every propagation-relevant
change in the range carries an `[auto]` block — the version genuinely needs
no project-side action. Do NOT re-add entries for `[auto]`-tagged changes;
that would fight the filter and re-admit no-op noise the tags exist to drop.

The only genuine gap is a propagation-relevant change with **no
`**Existing projects:**` block at all** — the block is the generator's only
input, so a missing block drops the change from the log with no signal
(`propagation-entry.sh` warns to stderr at generate time; this review is the
backstop).

1. Read `kit/docs/PROPAGATION.md` — find the new `## v<new>` section.
2. Read the diff of all commits since the last tag:
   `git diff $LAST_TAG..HEAD -- template/ kit/scripts/ kit/docs/guide/`
   Look for changes that affect existing projects: template files, scripts,
   guide docs with new rules/conventions.
3. For each propagation-relevant change, check it carried an
   `**Existing projects:**` block in its commit body
   (`git log $LAST_TAG..HEAD --format='%H %s%n%b' -- <path>`). If a change has
   **no block at all** (the genuine omission), compose the missing entry, edit
   `PROPAGATION.md`, and re-stage it (`git add kit/docs/PROPAGATION.md`). A
   change that DID carry a block is already handled by the generator per its
   tag — leave it alone even when the result is `(no manual steps)`.
4. If every propagation-relevant change carried a block (all-`[auto]` → a
   correct `(no manual steps)`, or real `[manual]`/`[conditional]` steps
   present), or there are genuinely no propagation-relevant changes, proceed
   as-is.

## Phase 3 — Commit, tag, push, confirm

After PROPAGATION.md is finalized, commit + tag + push in one step:

```bash
cd /devshop
bash kit/scripts/release.sh --finalize
```

`release.sh --finalize` re-stages PROPAGATION.md (in case it was edited),
commits with `CLAUDECODE=` unset (bypasses the main branch guard), tags,
pushes, and creates the GitHub release. Fully autonomous — no human input
needed.

If a Layer 1 hook blocks the commit (e.g., missing test-pairing for a
new script that should have been caught earlier), surface the reason to
the user — don't bypass at release time. Coverage gaps belong in the
merge-time audit, not the bump commit.

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
