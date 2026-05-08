---
name: ak-merge-devshop
version: 1.0.0
description: |
  Merge a devshop feature branch into main: audit + squash-merge with a structured
  commit message + push + branch cleanup. The squash commit body carries bullet-led
  summary sections, key/notable details, and a compressed per-commit bullet list
  under a `## Squashed commits` section (SHAs recoverable via `git reflog`) — so
  `git log` on main stays scannable without losing per-task detail.
  Use when asked to "merge the devshop branch", "land this devshop feature",
  "ff-merge devshop" (legacy phrasing — this skill squash-merges instead),
  or after a devshop feature branch is reviewed and ready to land. (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Skill
  - AskUserQuestion
---

# /ak-merge-devshop

Owns the devshop ff-equivalent merge flow. Replaces the manual
`git checkout main && git merge --ff-only feat/<branch> && git push` sequence
documented (now historical) in `/devshop/CLAUDE.md § Devshop shipping flow` step 2.

The shape: **squash-merge** (not ff-merge) with a structured commit message —
bullet-led summary sections + key details + compressed per-commit bullet list,
all in one commit on main. Trade-off: per-commit pointer chain is collapsed
(lost as ancestry, preserved as compressed bullets in the message body, with
short SHAs that `git reflog` resolves for ~90 days post-merge); `git log` on
main becomes one entry per landed branch instead of one entry per task. The
user explicitly chose this trade-off — main reads as a feature-grain narrative,
not a task-grain stream.

## When to invoke

- The operator has finished a devshop feature branch (`feat/<topic>`,
  `fix/<topic>`, `docs/<topic>`, `chore/<topic>`) and wants it landed on `main`.
- After local iteration is complete; before invoking `/ak-release-devshop`.
- Replaces ad-hoc `git merge --ff-only` from devshop CLAUDE.md prose.

Do NOT invoke when:

- Already on `main` — there's nothing to merge.
- Working tree dirty — commit or stash first.
- This is a project (lalista) repo, not `/devshop` — projects use PRs +
  `/ship` + `/ak-go-live`, not this flow.

## Inputs

- (none required) — the skill auto-detects from the current branch.
- The current branch must be the feature branch to merge.

---

## Phase 0: Pre-flight + preview

The most expensive failure is a bad squash-commit message landing on `main` —
once pushed, fixing it requires a force-push (which this devshop's
`hooks/check-not-force-push.sh` blocks) or an amending commit (which clutters
history with a "fix the previous commit message" entry). Phase 0 catches this
before anything is destructive.

### 0.1: Hard preconditions

Run from `/devshop`. Refuse early on any of these:

```bash
cd /devshop

BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "✖ on main — checkout the feature branch first"; exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "✖ working tree dirty — commit or stash first"; exit 1
fi

git fetch origin

# Refuse if branch == origin/main (nothing to merge). Divergent branches are
# OK — Phase 2's rebase reconciles them with origin/main before squashing.
if [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ]; then
  echo "✖ $BRANCH is at origin/main — nothing to merge"; exit 1
fi

# Verify branch has at least one commit ahead of merge-base (otherwise nothing
# to squash). `git rev-list --count <merge-base>..HEAD` returns the ahead count.
MERGE_BASE=$(git merge-base origin/main HEAD)
if [ "$(git rev-list --count ${MERGE_BASE}..HEAD)" = "0" ]; then
  echo "✖ $BRANCH has no commits ahead of origin/main — nothing to squash"; exit 1
fi
```

If any fails, surface the diagnostic and stop. The operator fixes and re-invokes.

### 0.2: Read state needed for the preview

```bash
FEATURE=$(echo "$BRANCH" | sed -E 's#^(feat|feature|fix|docs|chore|refactor)/##')
if [ -z "$FEATURE" ] || [ "$FEATURE" = "$BRANCH" ]; then
  echo "✖ branch name doesn't start with a known type prefix"
  echo "  (feat/, feature/, fix/, docs/, chore/, refactor/)"
  echo "  branch: $BRANCH"
  exit 1
fi
FEATURE_DIR="specs/$FEATURE"

# Range of commits being merged
COMMITS=$(git log --reverse --format='%h %s' origin/main..HEAD)
N_COMMITS=$(echo "$COMMITS" | grep -c '^' || echo 0)

# Diff shape
DIFFSTAT=$(git diff --stat origin/main...HEAD | tail -1)        # one-line summary
DIFFFILES=$(git diff --name-only origin/main...HEAD | head -50) # file list (capped)

# Audit state
if [ -f "$FEATURE_DIR/review.md" ]; then
  LATEST_AUDIT_SHA=$(grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' \
    "$FEATURE_DIR/review.md" 2>/dev/null | tail -1)
  AUDIT_COUNT=$(grep -cP '^## Audit \d+' "$FEATURE_DIR/review.md" 2>/dev/null || echo 0)
else
  LATEST_AUDIT_SHA=""
  AUDIT_COUNT=0
fi
HEAD_SHA=$(git rev-parse HEAD)
```

Audit-status display logic:

| Condition                        | Display                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------ |
| `$AUDIT_COUNT == 0`              | `no audit yet — Phase 1 will run /ak-check-docs-and-tests`                     |
| `$LATEST_AUDIT_SHA == $HEAD_SHA` | `Audit $AUDIT_COUNT at HEAD (idempotent — Phase 1 no-op)`                      |
| `$LATEST_AUDIT_SHA != $HEAD_SHA` | `$AUDIT_COUNT prior audit(s); $N commits since latest — Phase 1 will re-audit` |

### 0.3: Compose the squash commit message

This is the load-bearing step — once squashed, the per-commit pointer chain is
gone, and the message body is the only durable record of detail. The composer
(you) reads:

1. `git log --reverse --format='%H%n%s%n%n%b%n----%n' origin/main..HEAD` — full
   subject + body for each commit, separator-delimited. This is the composer's
   reference input for distilling each commit into a 1-3-bullet entry under
   the `## Squashed commits` section (the section itself is compressed, not
   verbatim — see § "Why compressed bullets, not verbatim bodies" below).
2. `git diff --stat origin/main...HEAD` — shape of the change.
3. Selected file diffs for files the diffstat flags as central (e.g. the new
   skill file, the largest changed file, files whose names suggest the
   feature's core — not the whole diff; use judgment, target ~3-5 files).
4. `$FEATURE_DIR/spec.md` if it exists — the spec is the canonical "what
   shipped, why" source; lift the summary from it rather than re-deriving.
5. `$FEATURE_DIR/review.md` if it exists — recent `## Audit N` sections may
   surface key decisions or non-obvious details worth promoting into the
   commit body.

Then compose a message in this exact shape:

```
<type>(<scope>): <subject ≤ 72 chars>

**<Lead-in topic 1, e.g. "Adds:" or "Lands:">** <one-paragraph statement
of what this branch shipped, then drops into a sub-bullet list when the
detail benefits from being scannable>:
- <sub-bullet — concrete user-meaningful unit>
- <sub-bullet>

**<Lead-in topic 2, e.g. "Why squash:" or "Trade-off:">** <prose statement
of the non-obvious decision or trade-off this branch made, when applicable>

**<Lead-in topic 3, e.g. "Doc updates:" or "Migration:">** <when there's
a list to enumerate, use sub-bullets>:
- <sub-bullet>
- <sub-bullet>

Key details:
- <bullet — surprising, load-bearing, or convention-shifting detail
  the lead-in topics didn't surface>
- <bullet — gotcha codified, breaking change, etc.>
- <only include this section when there are real bullets; skip otherwise>

---

## Squashed commits

Recoverable via `git reflog` / `git show <sha>` for ~90 days post-merge.

- `<short-SHA>` <subject>
  - <1-3 sub-bullets distilling what this commit did at the change-level —
    NOT a copy of the body, NOT meta-narrative ("Phase 1 expansion"); just
    the concrete diff this commit landed.>
- `<short-SHA>` <subject>
  - <sub-bullet>
- ...

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

#### Why bullet-led summary, not paragraphs

Earlier shape used 2-4 paragraphs of flowing prose. That reads naturally but
forces the reader to consume the whole block to track what landed — and forces
the composer to re-flow the prose every time the contents shift. Bullet-led
sections (`**Adds:**`, `**Trade-off:**`, `**Doc updates:**`, etc.) give the
reader scannable anchors and let the composer add or drop a section without
breaking the rest of the structure. The lead-in bold-text label IS the section
header — no need for `###`-style headers (which would compete with
`## Squashed commits`).

Pick the lead-in labels that fit the change. Common ones:

- **Adds:** / **Lands:** — what new capability shipped
- **Removes:** / **Deletes:** — what was retired
- **Why <X>:** — non-obvious decisions worth surfacing inline
- **Trade-off:** — what was given up
- **Doc updates:** — sibling docs that moved with the change
- **Migration:** — schema or breaking-change context
- **Smoke-test finding:** — bug found while running the change against
  itself or against a real branch (this is exactly the kind of detail
  worth foregrounding when it surfaces)

Skip the prose paragraphs entirely when the bullet structure says it all.
The sections aren't load-bearing — `Key details:` (lower) is the only
section header that's stable across all squash messages.

#### Why compressed bullets, not verbatim bodies

The earlier shape used full verbatim per-commit bodies under `### <SHA>`
headers. That preserved every detail but produced ~25 lines per commit on
average (12 commits → 290+ lines for the squash message alone). The
compressed shape keeps the SHA (so `git reflog` recovers the original message
verbatim if anyone needs to dig) and the subject (the at-a-glance "what was
this commit about") plus 1-3 sub-bullets distilling the actual change. A
12-commit squash becomes ~40 lines instead of ~290.

The trailers (`Co-Authored-By:` from each constituent commit) are dropped in
the compressed view — they're attribution noise that GitHub already
deduplicates by email, and the single trailer at the bottom of the squash
message attributes the merge commit itself.

#### Subject prefix selection

The squash subject is one commit, so it carries one conventional-commit prefix.
Pick the **highest-impact** prefix that appears in the constituent commits —
mirrors `/ak-release-devshop`'s bump-level math:

| Constituent commits include                                              | Squash subject prefix                                      |
| ------------------------------------------------------------------------ | ---------------------------------------------------------- |
| Any `feat!:` / `fix!:` / `BREAKING CHANGE:` in body                      | `feat!:` (or `fix!:`)                                      |
| Any `feat:`                                                              | `feat:`                                                    |
| Any `fix:` (and no `feat:`)                                              | `fix:`                                                     |
| All `docs:` / `chore:` / `style:` / `test:` / `ci:` / `build:` / `perf:` | use the most common prefix — typically `chore:` or `docs:` |

Scope (`(<scope>)`) — pick from the most-touched area: skill name (e.g.
`ak-merge-devshop`), guide section, or path segment. Skip the scope if
the change is genuinely cross-cutting.

#### Generating the compressed bullet list

The composer reads each constituent commit's full body to write the
sub-bullets — the agent (you) makes a judgment call per commit about what
the actual diff did vs what the message body's prose said.

For mechanical input:

```bash
# subject + body for composer reference
git log --reverse --format='%h %s%n%n%b%n----' origin/main..HEAD

# diff per commit, scoped to the commit's actual changes (helps when the
# body and the diff disagree — trust the diff)
git log --reverse --format='%h %s' origin/main..HEAD | while read sha _; do
  echo "=== $sha ==="
  git show --stat "$sha"
done
```

Sub-bullets should describe the change, not the meta-narrative. Examples:

- ✗ "Phase 1 spec expansion" (meta-narrative — what /ak-build phase ran)
- ✓ "expanded spec from 143 to 775 lines: In scope, Files, Tests, Task order" (what the diff did)
- ✗ "fix bypass example" (vague)
- ✓ "corrected docsReviewed bypass example in CLAUDE.md to use the merged flag" (concrete)

Skip sub-bullets entirely for commits whose subject is fully self-describing
(e.g. `chore(build-log): record cheap-test-gates-local` — the subject IS the
description; sub-bullets would be redundant).

Write the composed message to `/tmp/squash-message-${FEATURE}.txt` for the
preview + the eventual `git commit -F` step.

### 0.4: Print the preview

Single message, three sections:

```
## Merge preview: <BRANCH> → main

Commits: $N_COMMITS
Diffstat: $DIFFSTAT
Files: <list, capped at 10; "...and N more" if longer>

Audit: <per the table in 0.2>

## Proposed squash commit message

<full contents of /tmp/squash-message-${FEATURE}.txt>
```

### 0.5: Approval gate

Use `AskUserQuestion`:

> **Approve this squash commit message?**
>
> - **Approve** — continue to Phase 1 (audit), then squash-merge with this exact message.
> - **Edit** — describe the change you want, or open `/tmp/squash-message-${FEATURE}.txt` directly. After your edit, the skill recomposes from the file and shows the preview again.
> - **Cancel** — abort. Nothing has been merged or pushed.

On **Edit**:

- Small change requested in chat → edit `/tmp/squash-message-${FEATURE}.txt`
  via `Edit` tool, re-print the preview, re-ask. Loop until **Approve**.
- "I'll edit it myself" → instruct the user to open
  `/tmp/squash-message-${FEATURE}.txt`, save, and reply "ready". Re-read,
  re-print, re-ask.

On **Cancel**: print `✖ /ak-merge-devshop cancelled. Nothing merged.` and exit 0.

---

## Phase 1: Audit

Invoke `/ak-check-docs-and-tests` via the Skill tool:

```
Skill({
  skill: "ak-check-docs-and-tests",
  args: "--feature-dir specs/${FEATURE} --label manual"
})
```

Behavior:

- If `${FEATURE_DIR}/review.md` already has `## Audit N` at HEAD → no-op
  (idempotent), exit 0. Continue to Phase 2.
- If new audit appended with **high-severity findings** → halt. Surface the
  findings to the user. Do NOT continue to Phase 2.

  ```
  ✖ /ak-check-docs-and-tests reported high-severity findings.
  Phase 1 halts; merge will not proceed.

  Findings: see ${FEATURE_DIR}/review.md § Audit N

  Options:
    1. Fix the findings on this branch, commit, then re-invoke
       /ak-merge-devshop. Phase 1 will re-audit the new HEAD.
    2. If you believe the finding is wrong, override via the
       per-finding bypass (read /ak-tests-review or /ak-docs-review
       for the appropriate mechanism), commit the bypass trailer,
       re-invoke.
  ```

  Exit non-zero.

- If 0/0/0 or only medium/low findings → continue to Phase 2.

The skill does NOT auto-fix findings. Sub-skills don't either.

---

## Phase 2: Squash on the feature branch

The squash commit is created on the **feature branch**, not on main. Two
reasons this is the right shape:

1. **`check-branch-not-main.sh` blocks Claude from running `git commit` on
   main.** Committing on the feature branch dodges the hook structurally —
   no operator handoff, no `!`-prefix terminal incantation, fully
   autonomous. Pre-commit hooks (gitleaks, doc-coverage, lint, typecheck,
   test suite) still fire on the feature-branch commit, so coverage is
   identical.
2. **It's what GitHub's "Squash and merge" does internally.** Squash on
   the source side, fast-forward to the destination. Phase 3 then becomes
   a pointer move with no new commit.

```bash
# Already on the feature branch from Phase 0.
git rebase origin/main          # incorporate origin/main's commits; resolve conflicts inline
git reset --soft origin/main    # collapse all of $BRANCH's commits to a single staged delta
git commit -F "/tmp/squash-message-${FEATURE}.txt"
```

Why `--soft`: `git reset --soft <commit>` moves HEAD to `<commit>` while
leaving the index AND working tree untouched. So after the soft-reset, the
working tree still contains the rebased branch's full content; HEAD is at
origin/main; the index has every change from the squashed commits as a
single staged delta. The follow-up `git commit` produces one commit on top
of origin/main containing exactly that delta.

Why the rebase is required first: `git reset --soft origin/main` produces a
correct squash only if the working tree already contains origin/main's
content. Without the rebase, the soft-reset would create a commit that
appears to _revert_ any origin/main changes the branch hadn't picked up.
The rebase merges them in first; conflicts are resolved at rebase time
(operator-visible, recoverable via `git rebase --abort`).

If `git rebase origin/main` reports conflicts: resolve them (mechanical
resolutions inline, ambiguous ones via the operator), `git add`, then
`git rebase --continue`. Repeat until rebase finishes.

If `git commit` fails (pre-commit hook block — Layer 1 docs/tests-coverage,
gitleaks, lint, typecheck, test suite): halt and surface the hook output.
The fix lives in the branch content; resolve, re-stage if needed, retry
the commit. The branch is still valid for re-invocation — Phase 0's
ff-mergeability check is the only thing that needs to re-pass.

If the rename+symlink-at-old-path combo from § Known limitations fires
during the rebase or commit: switch to the documented ff-only fallback
(unaffected by lint-staged's stash bug because it doesn't go through the
squash machinery).

---

## Phase 3: Fast-forward main + push

```bash
git checkout main
git merge --ff-only origin/main         # catch local-main lag
git merge --ff-only "$BRANCH"           # ff main → squash commit (no NEW commit, no hook)
git push origin main
```

`git merge --ff-only` does not create a new commit — it just moves main's
HEAD pointer forward to the squash commit Claude created on the feature
branch. The on-main commit hook never fires. The push transports a
pointer move plus the new commit object.

If `git merge --ff-only "$BRANCH"` fails (would require a real merge
because main moved during Phase 2): rare on a single-developer devshop, but
recoverable — `git fetch origin && git rebase origin/main` on the feature
branch, then re-run Phase 3.

If push fails because someone else pushed in between (multi-machine race):

```
✖ push rejected — origin/main has moved since fetch.
  Run /ak-merge-devshop again; Phase 0's fetch + ff-mergeability check
  will re-evaluate against the new tip. The squash commit on the feature
  branch is preserved (recoverable via git reflog if rebase rewrites it),
  and /tmp/squash-message-${FEATURE}.txt survives across invocations.
```

If push fails because the commit touched `.github/workflows/**` (PAT
lacks `workflow` scope — same issue as `/ak-build` Phase 5.4 step 8):
surface the human-push command and exit. The operator pushes manually;
the skill is done.

```bash
TOUCHED_WORKFLOWS=$(git diff --name-only HEAD~1 HEAD | \
  grep -E '^\.github/workflows/' || true)
if [ -n "$TOUCHED_WORKFLOWS" ]; then
  USER=$(gh api user --jq .login 2>/dev/null || echo "<your-github-user>")
  echo "⚠ Squash commit touches workflow file(s):"
  echo "$TOUCHED_WORKFLOWS"
  echo ""
  echo "Devcontainer PAT lacks 'workflow' scope. Push manually:"
  echo ""
  echo "  git -c credential.helper= \\"
  echo "    push https://${USER}@github.com/<owner>/<repo>.git main"
  echo ""
  echo "Then run Phase 4 cleanup manually:"
  echo "  git branch -D ${BRANCH}"
  echo "  git push origin --delete ${BRANCH} 2>/dev/null || true"
  exit 0
fi
```

---

## Phase 4: Verify + cleanup

### 4.1: Tree-equality check

Under the soft-reset + ff-merge flow this check is trivially true (main
and the feature branch point at the same commit after Phase 3's
ff-merge), so it's a near-free sanity assertion. Worth keeping as
defense-in-depth in case the flow changes or the operator interrupted
between Phase 2 and Phase 3 in a way that left the branches at different
commits:

```bash
if ! git diff --quiet "main" "$BRANCH"; then
  echo "✖ post-merge tree mismatch between main and $BRANCH:"
  git diff --stat "main" "$BRANCH"
  echo ""
  echo "  Halting before cleanup so the feature branch is still"
  echo "  recoverable. Investigate the diff manually."
  exit 1
fi
```

### 4.2: Cleanup

After the squash, the feature branch's commits are NOT in main's ancestry —
git's `branch -d` (lowercase) safety check will refuse. With 4.1's tree-
equality check passing, force-delete is safe.

```bash
git branch -D "$BRANCH"

# Remote branch — best-effort. The branch may not have a remote.
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git push origin --delete "$BRANCH"
fi

# Tempfile cleanup
rm -f "/tmp/squash-message-${FEATURE}.txt"
```

If `git branch -D` fails for any reason (extremely unlikely at this point —
HEAD is on main, branch exists locally, force-delete should always work):
surface the error and continue. The merge has already shipped; a stale local
branch is a cosmetic problem the operator can clean up by hand.

---

## Phase 5: Handoff

Print a summary and surface the next-step signal:

```bash
NEW_HEAD=$(git rev-parse --short HEAD)
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

# Count meaningful commits since last tag (squash subjects, since each merge
# is now one commit on main)
if [ -n "$LAST_TAG" ]; then
  SINCE_TAG=$(git log --format='%s' "$LAST_TAG"..HEAD)
  HAS_FEAT=$(echo "$SINCE_TAG" | grep -cE '^feat(\(|!|:)' || true)
  HAS_FIX=$(echo "$SINCE_TAG" | grep -cE '^fix(\(|!|:)' || true)
  HAS_BREAKING=$(echo "$SINCE_TAG" | grep -cE '^(feat|fix)!|BREAKING CHANGE' || true)
fi
```

Output:

```
✓ /ak-merge-devshop complete.

  Branch:   $BRANCH (squashed → 1 commit on main)
  Source:   $N_COMMITS commits collapsed
  HEAD:     $NEW_HEAD
  Pushed:   ✓
  Cleaned:  local + remote feature branch deleted

Next step:
  <one of:>
  → Run /ak-release-devshop — there are feat:/fix: commits since v$LAST_TAG.
  → No release needed — all commits since v$LAST_TAG are trivial (chore/docs/...).
  → No prior tag — first release: run /ak-release-devshop --bump <level>.
```

The handoff is informational, not autonomous — `/ak-release-devshop` decides
the bump level deliberately with operator confirmation; this skill doesn't
chain into it.

---

## Known limitations

### Rename + symlink-at-old-path combo blocks `git merge --squash`

When the squashed diff contains BOTH (a) a rename `R OLD/file -> NEW/file` AND
(b) a new symlink at the `OLD` path, the pre-commit hook's `lint-staged` stash
backup chokes with `error: 'OLD/file' is beyond a symbolic link`. This is a
git-plumbing limitation surfacing through `git stash`, NOT a real conflict —
the repo content is fine, but the staging machinery refuses.

**How to detect**: after `git merge --squash <branch>` stages changes, run:

```bash
RENAME_SRCS=$(git diff --cached --name-status --diff-filter=R \
  | awk '{print $2}')
ADDED_PATHS=$(git diff --cached --name-status --diff-filter=A \
  | awk '{print $2}')
COLLISIONS=$(comm -12 <(echo "$RENAME_SRCS" | sort) <(echo "$ADDED_PATHS" | sort))
[ -n "$COLLISIONS" ] && echo "✖ rename-plus-symlink combo: $COLLISIONS"
```

**Workaround**: fall back to `git merge --ff-only <branch>` instead of squash.
This lands the constituent commits as-is on `main` (loses the squash's
1-commit shape, gains 2 separate commits — same file-system end state). Each
constituent commit was already validated by `lint-staged` when authored on
the feature branch, so the per-commit hook fires cleanly.

**Operator recovery if Phase 2 fails on this**:

```bash
# 1. Confirm not mid-merge
[ -f .git/MERGE_HEAD ] && echo "abort first: git merge --abort"
# 2. Unstage the failed squash (no working-tree change)
git reset
rm -f .git/SQUASH_MSG
# 3. Stash any tracked-file edits (DCG-friendly; the dirty bits match the
#    commits we're about to land, so dropping the stash post-merge is safe)
git stash push -m "pre-ff-merge cleanup"
# 4. ff-merge instead
git merge --ff-only <branch>
git push origin main
git stash drop
# 5. Phase 4 cleanup as usual
git branch -D <branch>
git push origin --delete <branch>
```

The detect-and-suggest behavior is tracked as a TODO (see `kit/TODOS.md`
entry "/ak-merge-devshop Phase 2: detect rename-plus-symlink-at-old-path
combo and fallback to ff-merge"). The underlying lint-staged stash bug is
also tracked separately. Until those land, the operator does the dance
manually per the recipe above.

---

## Idempotence + resume

Every phase is idempotent on re-invocation:

- **Phase 0 preconditions**: re-evaluated each run — branch state, tree
  cleanliness, ff-mergeability all derived from live git state.
- **Phase 0 message composition**: the tempfile at
  `/tmp/squash-message-${FEATURE}.txt` survives between invocations. On
  resume, if the file exists AND the branch SHA hasn't changed since the
  file's mtime, offer to reuse it (skip recompose). Otherwise recompose.
- **Phase 1 audit**: idempotent via `/ak-check-docs-and-tests`'s own no-op
  guard (latest `## Audit N` at HEAD → skip).
- **Phase 2 squash**: if the feature branch's tip is already a single
  commit on top of origin/main with the expected message subject (detected
  via `git log -1 --format='%s' "$BRANCH"` matching the composed subject
  AND `git rev-list --count origin/main..HEAD = 1`), skip the rebase +
  soft-reset + commit — already squashed.
- **Phase 3 ff-merge + push**: `git merge --ff-only` is a no-op when
  already at the target; `git push` is idempotent ("Everything up-to-date"
  on re-run).
- **Phase 4 cleanup**: re-running the deletes when the branch is already
  gone is a no-op (use the `ls-remote --exit-code` guard for the remote;
  `git branch -D` errors when local branch is absent — wrap in `|| true`).

Effect: any halt-and-resume sequence works. Operator hits a Phase 1
high-severity finding → fixes on the feature branch → re-invokes; Phase 0
recomputes everything, Phase 1 re-audits, the rest proceeds.

---

## What this skill does NOT do

- **Bump version / cut release** — that's `/ak-release-devshop`. The two
  skills compose: `/ak-merge-devshop` lands a feature; `/ak-release-devshop`
  decides when accumulated features warrant a release.
- **Coordinated devshop+project change orchestration** — the operator
  decides when a coordinated change is "validated by the project side" (per
  `/devshop/CLAUDE.md § Devshop shipping flow`). At skill-invocation time
  that decision has already been made by virtue of the operator running
  this skill.
- **Edit the message after commit** — once `git commit` lands the squash,
  amending requires force-push, which the devshop's pre-push hook blocks.
  Phase 0's approval gate is the only chance to perfect the message; that's
  why it's an explicit gate, not an inferred default.
- **Handle non-`/devshop` repos** — projects (lalista et al.) use PRs +
  `/ship` + `/ak-go-live`. Refusing on the cwd check is intentional.
- **Restore the file-permission lock on security-critical scripts** — the
  filesystem-lock erosion footgun (`kit/TODOS.md`, v1) is out of scope. If
  the operator relies on the lock, they re-run `init-devshop.sh` after merge.
