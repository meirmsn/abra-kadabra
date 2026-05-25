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

- Working tree dirty (on `/devshop` OR in the target worktree) — commit or stash first.
- This is a project (lalista) repo, not `/devshop` — projects use PRs +
  `/ship` + `/ak-go-live`, not this flow.

The skill auto-detects feature work in three shapes:

- **`/devshop` is on the feature branch directly** (operator checked it out
  in the main worktree). Skill runs the squash + ff-merge in place.
- **`/devshop` is on `main`, a linked worktree is on the feature branch**
  (`.worktrees/<topic>/`). Skill detects the worktree, routes Phase 2's
  squash there via `git -C $WORKTREE_PATH`, and tears the worktree down
  in Phase 4.2 after the ff-merge succeeds.
- **Multiple linked worktrees ahead of `origin/main`** — skill refuses with
  the candidate list and requires `--branch <name>` to disambiguate.

`/devshop` on `main` with NO feature worktree ahead of `origin/main` is the
only legitimate refusal — there is genuinely nothing to merge.

## Inputs

- **(none, common case)** — the skill auto-detects from `git branch
--show-current` on `/devshop` plus a `git worktree list --porcelain` scan
  for linked feature worktrees.
- **`--branch <name>`** — disambiguates when multiple linked worktrees are
  ahead of `origin/main`. The name matches a branch ref (e.g.
  `feat/foo` or `fix/bar`), not the worktree directory name.
- **`--source-worktree <path>`** — bypass the "`/devshop` must be on main"
  precondition. Use when a parallel session has `/devshop` checked out on
  an unrelated feature branch with WIP that can't be cleanly switched.
  The skill operates entirely against the named worktree (rebase + soft-
  reset + commit), then pushes the squash directly to `origin/main` via
  `git -C <worktree> push origin HEAD:main` (no `git checkout main` in
  `/devshop`). Phase 4.2 still cleans up the named worktree. Local `main`
  ref in `/devshop` may lag origin/main after this flow — re-fetch +
  resync when convenient. Codified from the 2026-05-20 session where
  `/ak-merge-devshop` had to be executed manually because parallel
  `fix/init-firewall-pipefail` WIP blocked the branch-switch.

---

## Phase 0: Pre-flight + preview

The most expensive failure is a bad squash-commit message landing on `main` —
once pushed, fixing it requires a force-push (which this devshop's
`hooks/check-not-force-push.sh` blocks) or an amending commit (which clutters
history with a "fix the previous commit message" entry). Phase 0 catches this
before anything is destructive.

### 0.1: Hard preconditions + worktree detection

Run from `/devshop`. Two paths converge on the same downstream variables
(`BRANCH`, `WORKTREE_PATH`): direct-checkout (legacy) and worktree-detected
(default). `WORKTREE_PATH` is empty when the feature branch is checked out
in `/devshop` itself; non-empty when detection located a linked worktree.

```bash
cd /devshop

git fetch origin

CURRENT=$(git branch --show-current)
WORKTREE_PATH=""

# --source-worktree short-circuit: when the operator names a worktree
# explicitly, skip the "/devshop must be on main" precondition entirely.
# Derive BRANCH from the named worktree's HEAD instead of /devshop's, and
# downstream Phase 3 pushes via `git -C "$WORKTREE_PATH" push origin
# HEAD:main` so /devshop's branch state stays untouched. Use case:
# parallel-session WIP on /devshop's main worktree blocks the otherwise-
# required branch-switch.
if [ -n "$SOURCE_WORKTREE_ARG" ]; then
  if [ ! -d "$SOURCE_WORKTREE_ARG" ]; then
    echo "✖ --source-worktree path does not exist: $SOURCE_WORKTREE_ARG"
    exit 1
  fi
  # Verify the path IS a registered worktree (not an arbitrary dir).
  if ! git worktree list --porcelain | grep -qxF "worktree $SOURCE_WORKTREE_ARG"; then
    echo "✖ --source-worktree path is not a registered git worktree: $SOURCE_WORKTREE_ARG"
    echo "  Registered worktrees:"
    git worktree list --porcelain | awk '/^worktree / {print "    "$2}'
    exit 1
  fi
  WORKTREE_PATH="$SOURCE_WORKTREE_ARG"
  BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current)
  if [ -z "$BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
    echo "✖ --source-worktree must be on a feature branch (currently: ${BRANCH:-detached HEAD})"
    exit 1
  fi
  AHEAD=$(git rev-list --count "origin/main..$BRANCH" 2>/dev/null || echo 0)
  if [ "$AHEAD" -eq 0 ]; then
    echo "✖ --source-worktree branch $BRANCH has no commits ahead of origin/main"
    exit 1
  fi
  echo "ℹ --source-worktree mode: $WORKTREE_PATH (branch: $BRANCH, $AHEAD commits ahead)"
  echo "  /devshop's branch state ($CURRENT) will not be touched."
  # Skip the rest of Phase 0.1's path-selection logic.
elif [ "$CURRENT" = "main" ] || [ "$CURRENT" = "master" ]; then
  # /devshop is on main — scan for a linked worktree on a feature-typed
  # branch ahead of origin/main. `git worktree list --porcelain` is the
  # canonical inventory (matches both linked worktrees and the main worktree
  # itself; filter the main worktree out by skipping the entry whose
  # `worktree` path equals /devshop).
  CANDIDATES=$(git worktree list --porcelain | awk '
    /^worktree / { wt=$2 }
    /^branch refs\/heads\// {
      ref=$2
      sub(/^refs\/heads\//, "", ref)
      if (wt != "/devshop" && ref ~ /^(feat|feature|fix|docs|chore|refactor)\//) {
        print wt "\t" ref
      }
    }
  ')

  # Filter to branches actually ahead of origin/main (a worktree at origin/main
  # has nothing to merge — same exclusion as the legacy at-origin-main check).
  FILTERED=""
  while IFS=$'\t' read -r wt ref; do
    [ -z "$wt" ] && continue
    AHEAD=$(git rev-list --count "origin/main..$ref" 2>/dev/null || echo 0)
    if [ "$AHEAD" -gt 0 ]; then
      FILTERED="${FILTERED}${wt}\t${ref}\n"
    fi
  done <<< "$CANDIDATES"

  N=$(printf "$FILTERED" | grep -c '^.' || echo 0)

  if [ "$N" -eq 0 ]; then
    echo "✖ /devshop is on main with no feature worktree ahead of origin/main"
    echo "  Either checkout the feature branch first, or develop it in a"
    echo "  linked worktree (.worktrees/<topic>/) and re-invoke."
    exit 1
  fi

  if [ -n "$BRANCH_ARG" ]; then
    # Operator disambiguated via --branch
    WORKTREE_PATH=$(printf "$FILTERED" | awk -F'\t' -v b="$BRANCH_ARG" '$2==b {print $1; exit}')
    if [ -z "$WORKTREE_PATH" ]; then
      echo "✖ --branch $BRANCH_ARG not found among feature worktrees ahead of origin/main"
      echo "  Available:"
      printf "$FILTERED" | awk -F'\t' 'NF{print "    " $2 " (" $1 ")"}'
      exit 1
    fi
    BRANCH="$BRANCH_ARG"
  elif [ "$N" -eq 1 ]; then
    WORKTREE_PATH=$(printf "$FILTERED" | awk -F'\t' 'NF{print $1; exit}')
    BRANCH=$(printf "$FILTERED" | awk -F'\t' 'NF{print $2; exit}')
  else
    echo "✖ multiple feature worktrees ahead of origin/main; pass --branch <name>:"
    printf "$FILTERED" | awk -F'\t' 'NF{print "    " $2 " (" $1 ")"}'
    exit 1
  fi

  echo "ℹ detected worktree: $WORKTREE_PATH (branch: $BRANCH)"
else
  # /devshop is already on the feature branch (legacy path — operator did the
  # manual dance or never used worktrees).
  BRANCH="$CURRENT"
fi

# Dirty-tree check: applies to whichever working tree owns the feature branch.
TARGET=${WORKTREE_PATH:-/devshop}
if [ -n "$(git -C "$TARGET" status --porcelain)" ]; then
  echo "✖ working tree dirty at $TARGET — commit or stash first"
  exit 1
fi

# Verify branch has at least one commit ahead of merge-base (defense in depth
# even though detection already filtered for this; the legacy direct-checkout
# path hasn't been through that filter).
MERGE_BASE=$(git merge-base origin/main "$BRANCH")
if [ "$(git rev-list --count ${MERGE_BASE}..${BRANCH})" = "0" ]; then
  echo "✖ $BRANCH has no commits ahead of origin/main — nothing to squash"
  exit 1
fi
```

If any check fails, surface the diagnostic and stop. The operator fixes
and re-invokes. After 0.1, two variables are set: `BRANCH` (the feature
branch ref, no `refs/heads/` prefix) and `WORKTREE_PATH` (the linked
worktree dir if detected, empty otherwise). All subsequent phases consult
`WORKTREE_PATH` to decide whether to route git commands via `-C
"$WORKTREE_PATH"`.

### 0.2: Read state needed for the preview

All git commands in this phase MUST address the branch by name (`$BRANCH`)
rather than implicitly using `HEAD`, because when `WORKTREE_PATH` is set,
`/devshop`'s HEAD is on `main` — not the feature branch we're reading
state for. `git log origin/main..$BRANCH` works from any worktree.

`$FEATURE_DIR` resolution is a parallel concern: `specs/<name>/` lives in
whichever working tree owns the branch's checkout. Use
`${WORKTREE_PATH:-/devshop}/specs/$FEATURE` when reading the audit file,
since that's where Phase 1 will write the new `## Audit N` section.

```bash
FEATURE=$(echo "$BRANCH" | sed -E 's#^(feat|feature|fix|docs|chore|refactor)/##')
if [ -z "$FEATURE" ] || [ "$FEATURE" = "$BRANCH" ]; then
  echo "✖ branch name doesn't start with a known type prefix"
  echo "  (feat/, feature/, fix/, docs/, chore/, refactor/)"
  echo "  branch: $BRANCH"
  exit 1
fi
TARGET=${WORKTREE_PATH:-/devshop}
FEATURE_DIR="${TARGET}/specs/$FEATURE"

# Range of commits being merged (use $BRANCH explicitly — works regardless
# of which worktree we're standing in).
COMMITS=$(git log --reverse --format='%h %s' "origin/main..$BRANCH")
N_COMMITS=$(echo "$COMMITS" | grep -c '^' || echo 0)

# Diff shape
DIFFSTAT=$(git diff --stat "origin/main...$BRANCH" | tail -1)
DIFFFILES=$(git diff --name-only "origin/main...$BRANCH" | head -50)

# Audit state — read review.md from whichever worktree owns the branch.
if [ -f "$FEATURE_DIR/review.md" ]; then
  LATEST_AUDIT_SHA=$(grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' \
    "$FEATURE_DIR/review.md" 2>/dev/null | tail -1)
  AUDIT_COUNT=$(grep -cP '^## Audit \d+' "$FEATURE_DIR/review.md" 2>/dev/null || echo 0)
else
  LATEST_AUDIT_SHA=""
  AUDIT_COUNT=0
fi
HEAD_SHA=$(git rev-parse "$BRANCH")
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

1. `git log --reverse --format='%H%n%s%n%n%b%n----%n' "origin/main..$BRANCH"` —
   full subject + body for each commit, separator-delimited. Use `$BRANCH`
   rather than `HEAD` so this works when `WORKTREE_PATH` is set
   (`/devshop`'s HEAD is on `main` in that case). This is the composer's
   reference input for distilling each commit into a 1-3-bullet entry under
   the `## Squashed commits` section (the section itself is compressed, not
   verbatim — see § "Why compressed bullets, not verbatim bodies" below).
2. `git diff --stat "origin/main...$BRANCH"` — shape of the change.
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

**<Lead-in topic 1, e.g. "Adds:" or "Lands:">** 3-7 bullets — each one a
concrete user-meaningful unit that shipped on this branch. A reader who
opens this commit message should be able to scan these bullets in 10
seconds and know what landed. Bullets first; if a non-obvious decision
needs framing, lead with one sentence of prose, then drop into bullets.
Don't write a paragraph and then re-summarize it as bullets — pick one.
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
- **Existing projects:** — per-project migration recipe, or explicit
  "no migration needed" when auto-sync handles it. Required when the
  diff touches propagation-relevant surfaces (`template/**`,
  `kit/scripts/**`, `[locked]`/`[sync]`/`[scaffold-once]` files).
  Convention: `kit/docs/guide/conventions.md § Existing-Project
  Migration Block`.

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

#### Subject style

Canonical rules: `kit/docs/guide/conventions.md § Commit + PR Text Style`
(devshop-owned, single source of truth — applies identically to
per-commit messages, `/ship`-authored commits, and these squash subjects).
The rules below restate the convention in the squash-message context;
keep them in sync with `conventions.md` if either side moves.

The subject is the line a reader sees in `git log --oneline`, in the
GitHub PR list, and in release notes. Write it so a teammate who hasn't
seen the diff can decode what behavior changed in the codebase — not
which file or variable was edited.

Rules:

1. **Describe the observable change**, not the implementation detail.
   "skip CI when only root markdown changes" beats "docs-only skip filter
   matches root-level markdown" — the reader cares about the new CI
   behavior, not which filter variable holds the change.
2. **Lead with a verb** when there's one verb-y change (`skip`, `add`,
   `fix`, `tighten`, `extract`, `rename`, `move`, `replace`). Noun-lists
   are fine when the commit ships multiple independent units that don't
   share a verb (e.g. `feat: invite link + member mgmt + audit feed`).
3. **No internal jargon**. Words that only make sense if you've read the
   spec ("polish", "soak findings", "Phase 2 expansion", "Tier B") are
   meta-narrative, not change description — drop them or replace with
   the underlying user- or code-facing fact.
4. **≤ 72 chars**, but err shorter — a tight subject is read faster.

Examples (drawn from real commits):

| Bad — terse but opaque                                                                             | Good — verb-led, behavior-described                                                 |
| -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| `fix(ci): docs-only skip filter matches root-level markdown`                                       | `fix(ci): skip CI when only root markdown changes`                                  |
| `fix(settings): household-collaborators polish — typography, skeleton, disclosure (soak findings)` | `fix(settings): tighten household-collaborators typography + skeleton + disclosure` |
| `feat(household-collaborators): invite link + member mgmt + audit feed`                            | (keep — noun-list is the natural shape for a multi-unit feature PR)                 |
| `chore(build-log): record cheap-test-gates-local`                                                  | (keep — subject is self-describing for a build-log chore)                           |

When in doubt: would a teammate scrolling `git log` two months from now
know what behavior shipped without opening the diff? If not, rewrite.

#### Generating the compressed bullet list

The composer reads each constituent commit's full body to write the
sub-bullets — the agent (you) makes a judgment call per commit about what
the actual diff did vs what the message body's prose said.

For mechanical input:

```bash
# subject + body for composer reference
git log --reverse --format='%h %s%n%n%b%n----' "origin/main..$BRANCH"

# diff per commit, scoped to the commit's actual changes (helps when the
# body and the diff disagree — trust the diff)
git log --reverse --format='%h %s' "origin/main..$BRANCH" | while read sha _; do
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

### 0.4.5: Adversarial readability check

The composer (you) wrote the squash subject + body following the § 0.3 style
rules — but a self-graded composer is a noisy signal. Phase 0.4.5 invokes the
shared `adversarial-review.sh prTextHygieneReason` engine — the same Sonnet-
routed reviewer that judges project PR titles at pre-push time — on the
composed message. This catches title/body that drift from the
`kit/docs/guide/conventions.md § Commit + PR Text Style` rules (mechanism-led
subjects, internal jargon like "polish" / "Tier B" / "Phase N", >72-char
subjects, body that doesn't describe what shipped) BEFORE the operator's
approval gate, so the verdict informs the operator's choice.

The engine is shared via the `DEVSHOP_HYGIENE_SURFACE=squash` env switch — no
duplicated logic. The PR-surface judges rules (a) accuracy + (b) readability +
(c) `## Product update` / `## Engineering details` body shape; the squash-
surface judges (a) + (b) and skips (c) because devshop squashes use the bold-
led-bullet + `## Squashed commits` shape from § 0.3 instead. Rule wording lives
in one place (`adversarial-review.sh`'s prompt block), so when the convention
moves, both surfaces move in lockstep.

```bash
HYGIENE_VERDICT="PASS"
HYGIENE_OUTPUT=""
if ! HYGIENE_OUTPUT=$(DEVSHOP_HYGIENE_SURFACE=squash \
       DEVSHOP_HYGIENE_MESSAGE_FILE="/tmp/squash-message-${FEATURE}.txt" \
       DEVSHOP_HYGIENE_BRANCH="$BRANCH" \
       bash /devshop/kit/scripts/adversarial-review.sh \
         prTextHygieneReason \
         "auto-check at compose time" 2>&1); then
  HYGIENE_VERDICT="FAIL"
fi
```

The literal `"auto-check at compose time"` string passed as the engine's
second positional arg is a **procedural telemetry marker, not an operator
bypass-defense rationale**. The engine's `prTextHygieneReason` squash-surface
`NOTE 1` (in `kit/scripts/adversarial-review.sh`) instructs the reviewer to
treat this field as procedural — to ignore its content when judging — and
focus its verdict on the proposed subject + body. Don't "tighten" this
string to something more specific in a behavior-preserving refactor; the
NOTE 1 contract on the script side is the canonical anchor, and the literal
value here is what the reviewer's prompt explicitly names as "e.g.
`'auto-check at compose time'`". A refactor that strips this value or makes
it operator-supplied would silently flip the surface back into bypass-review
mode and start FAILing clean titles again.

`HYGIENE_OUTPUT` carries the reviewer's `FAIL: <what's wrong>` line on FAIL
and is empty on PASS. Both feed Phase 0.5's approval-gate framing.

If `adversarial-review.sh` itself errors (API timeout after backoff, missing
tempfile from a previous-session crash that never composed), surface the
underlying message and treat the check as PASS — the operator's approval gate
is still the final human authority, and a missing-API check should not block
a working composer. The check is advisory in spirit (operator's the gate);
its job is to surface signal, not to short-circuit.

### 0.5: Approval gate

Use `AskUserQuestion`. Frame the question based on the hygiene verdict:

**On `HYGIENE_VERDICT=PASS`** — the message reads cleanly per the convention:

> **Approve this squash commit message?**
>
> - **Approve** — continue to Phase 1 (audit), then squash-merge with this exact message.
> - **Edit** — describe the change you want, or open `/tmp/squash-message-${FEATURE}.txt` directly. After your edit, the skill recomposes from the file and shows the preview again.
> - **Cancel** — abort. Nothing has been merged or pushed.

**On `HYGIENE_VERDICT=FAIL`** — surface the reviewer's verdict prominently so
the operator's choice is informed. "Approve anyway" is the explicit override;
"Edit" (recommended) is the normal path:

> **The readability reviewer flagged the composed message:**
>
> ```
> <HYGIENE_OUTPUT verbatim — the reviewer's FAIL: <reason> line>
> ```
>
> **Approve this squash commit message?**
>
> - **Edit (recommended)** — fix the flagged issue. Describe the change you want, or open `/tmp/squash-message-${FEATURE}.txt` directly. After your edit, the skill recomposes from the file, re-runs the hygiene check, and shows the preview again.
> - **Approve anyway** — ship the message despite the verdict. Use only when the reviewer is genuinely wrong (the title IS observable, the body IS accurate, etc.) — the bypass is logged in the commit's body as `Hygiene-Override: <one-line reason you give here>`.
> - **Cancel** — abort. Nothing has been merged or pushed.

On **Approve anyway**: append the override reason as a `Hygiene-Override:`
trailer to `/tmp/squash-message-${FEATURE}.txt` before continuing to Phase 1.
This makes the explicit-override visible in `git log` on main alongside the
`Co-Authored-By:` trailer, so future-you scanning history sees that the
message shipped past a flagged readability concern AND why.

On **Edit**:

- Small change requested in chat → edit `/tmp/squash-message-${FEATURE}.txt`
  via `Edit` tool, re-run Phase 0.4.5's hygiene check (the verdict may flip
  to PASS, FAIL with a different reason, or stay FAIL), re-print the preview,
  re-ask. Loop until **Approve** / **Approve anyway** / **Cancel**.
- "I'll edit it myself" → instruct the user to open
  `/tmp/squash-message-${FEATURE}.txt`, save, and reply "ready". Re-read,
  re-run Phase 0.4.5, re-print, re-ask.

On **Cancel**: print `✖ /ak-merge-devshop cancelled. Nothing merged.` and exit 0.

---

## Phase 1: Audit

**Cwd routing — required when `WORKTREE_PATH` is set.** The sub-skill
(`/ak-check-docs-and-tests`) reads the current branch via
`git branch --show-current` for its Step 1 #5 main-refusal guard. From
`/devshop` (on `main` whenever the feature lives in a worktree) the
sub-skill refuses with "audit is feature-level; check out the feature
branch first." Switch cwd into the worktree before the Skill call so
the sub-skill sees the feature branch:

```bash
[ -n "$WORKTREE_PATH" ] && cd "$WORKTREE_PATH"
```

The `--feature-dir` arg is a path resolved against the sub-skill's cwd —
once cwd is the worktree, `specs/${FEATURE}` correctly anchors at
`${WORKTREE_PATH}/specs/${FEATURE}` (where the sub-skill's scaffold
step, idempotence stamp, and commit step all need to land — and where
the resulting `## Audit N` content rides into Phase 2's squash range
without needing a separate path-rewrite). After Phase 1 returns, the
orchestrator may `cd /devshop` again or continue from the worktree;
Phase 2's squash machinery routes via `$GIT_CMD` / `git -C` so it
doesn't depend on cwd. Phase 4.2's worktree teardown also works from
either cwd (it operates on `$WORKTREE_PATH` explicitly).

Legacy direct-checkout path (`WORKTREE_PATH` empty, feature branch
checked out in `/devshop`): the cd is a no-op; the Skill call runs from
`/devshop`, which IS on the feature branch, and Step 1 #5 passes.

Worked trip-up this rule prevents: feat/home-os-onboarding-template-patches
merge (2026-05-19) — the orchestrator initially invoked the Skill without
the cd, then read `/ak-check-docs-and-tests § Step 1 #5` and concluded the
audit couldn't run. Recovery required an explicit cd to the worktree and
re-invoking. The rule above eliminates that path entirely.

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

- If new audit appended with **medium-severity findings** (no high) →
  **interactive pause** — the audit recorded the gap but didn't block.
  This is the devshop equivalent of project `/ak-build § Phase 5.8`
  (post-polish re-audit): on the project side, a second audit moment
  catches "spec promised X, X wasn't actually delivered" gaps after CI
  green; on the devshop side, the single audit moment IS this Phase 1
  pause. The operator picks whether to polish in-branch (the recommended
  default — re-invoking after polish is cheap) or proceed (recording
  the gap in `review.md` for follow-up). Fire `AskUserQuestion`:

  ```
  ⚠ /ak-check-docs-and-tests reported N medium-severity finding(s).
    No halt-on-medium path on the project side post-polish — but on the
    devshop side this is the only audit moment, so the operator decides:

      1. Fix in-branch, then re-invoke /ak-merge-devshop (Recommended)
         — Phase 1 re-audits the new HEAD; idempotent re-runs are safe.
      2. Proceed — record the gap in review.md, ship the squash with the
         medium finding(s) intact. Future follow-up sessions read them
         from review.md § Audit N.
      3. Cancel — abort /ak-merge-devshop. Nothing merged.
  ```

  Default: option 1 (Recommended). The interactive halt is the devshop's
  Phase 5.8 equivalent — fires only on medium findings; lows surface
  silently and proceed. Auto-mode sessions that want to skip the prompt
  can set `DEVSHOP_AUDIT_MEDIUM_POLICY=proceed` to take option 2
  unconditionally (records the override in `review.md` as a bypass
  trailer).

- If 0/0/0 or only low findings → continue to Phase 2.

The skill does NOT auto-fix findings. Sub-skills don't either.

**Codified from** `home-os-skill-polish-batch` merge (2026-05-20). Audit 1
reported `high=0 medium=2 low=6`. Pre-fix Phase 1 advanced silently —
the 2 medium findings (hooks.md missing B3 short-circuit doc entry; a
spec-promised bats grep guard for E5 not added) shipped into the squash
unfixed and surfaced only when an operator manually re-read `review.md`
post-merge. The interactive pause above gives the operator the polish
window without forcing fixes on every medium (option 2 keeps the
historical "proceed-but-record" behavior available).

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

Route every git invocation in this phase via `$GIT_CMD`, which expands to
`git` when the feature branch is checked out on `/devshop` (legacy direct-
checkout) or `git -C "$WORKTREE_PATH"` when detection in Phase 0.1 found a
linked worktree.

**Anchor selection** (load-bearing when an in-flight release sits on local main).
The soft-reset anchor MUST be reachable from the eventual main HEAD that
Phase 3's FF-merge lands on. When `/ak-release-devshop` has run but the
release commit (`Bump devshop version to vN.N.N`) hasn't been pushed yet,
local `main` is one commit ahead of `origin/main`. Using `origin/main`
as the anchor in that case strands the release commit (Phase 3's
`git merge --ff-only "$BRANCH"` then fails because branch and local main
have diverged). Detect and pick the right anchor:

```bash
GIT_CMD="git"
[ -n "$WORKTREE_PATH" ] && GIT_CMD="git -C $WORKTREE_PATH"

# Pick the soft-reset anchor: local main when ahead of origin/main (typical
# of an unpushed release), otherwise origin/main. The anchor MUST be
# reachable from main's HEAD so Phase 3's FF lands cleanly.
ANCHOR=origin/main
LOCAL_AHEAD=$(git rev-list --count origin/main..main 2>/dev/null || echo 0)
if [ "$LOCAL_AHEAD" -gt 0 ]; then
  ANCHOR=main
  echo "ℹ local main is $LOCAL_AHEAD commit(s) ahead of origin/main —"
  echo "  anchoring squash on local main (typical of an in-flight release"
  echo "  that hasn't been pushed). Those commits will ride along with the"
  echo "  squash on Phase 3's \`git push origin main\`."
fi

$GIT_CMD rebase "$ANCHOR"          # incorporate $ANCHOR's commits; resolve conflicts inline
$GIT_CMD reset --soft "$ANCHOR"    # collapse all of $BRANCH's commits to a single staged delta
$GIT_CMD commit -F "/tmp/squash-message-${FEATURE}.txt"
```

Why `--soft`: `git reset --soft <commit>` moves HEAD to `<commit>` while
leaving the index AND working tree untouched. So after the soft-reset, the
working tree still contains the rebased branch's full content; HEAD is at
`$ANCHOR`; the index has every change from the squashed commits as a
single staged delta. The follow-up `git commit` produces one commit on top
of `$ANCHOR` containing exactly that delta.

Why the rebase is required first: `git reset --soft "$ANCHOR"` produces a
correct squash only if the working tree already contains `$ANCHOR`'s
content. Without the rebase, the soft-reset would create a commit that
appears to _revert_ any `$ANCHOR` changes the branch hadn't picked up.
The rebase merges them in first; conflicts are resolved at rebase time
(operator-visible, recoverable via `$GIT_CMD rebase --abort`).

**Worked incident — anchor selection matters**: `home-os-skill-polish-batch`
merge (2026-05-20). Local main carried `3f122d4 Bump devshop version to
1.32.0` (release.sh commit; tag v1.32.0 set) but origin/main hadn't been
pushed yet. Using `origin/main` as the anchor (the pre-fix default) put
the squash on top of `60f64e3` (origin/main tip), diverging from local
main which carried v1.32.0 — Phase 3's `git merge --ff-only "$BRANCH"`
then refused because feature and main had no common path. Recovery
required re-doing Phase 2 with `main` as the anchor, after which
Phase 3's FF + push carried both the release commit and the squash to
origin in one push. The anchor-detection block above eliminates the
re-do.

If `$GIT_CMD rebase origin/main` reports conflicts: resolve them
(mechanical resolutions inline, ambiguous ones via the operator),
`$GIT_CMD add`, then `$GIT_CMD rebase --continue`. Repeat until rebase
finishes. When `$GIT_CMD` includes `-C "$WORKTREE_PATH"`, the conflict
files live under `"$WORKTREE_PATH"`, not `/devshop` — use the Edit tool
with the worktree-prefixed absolute path.

**Phantom "local changes would be overwritten" — fall back to merge.**
On virtiofs (devcontainer on macOS), `git rebase origin/main` sometimes
aborts immediately with `error: Your local changes to the following
files would be overwritten by merge: <N files>` even though
`git status` reports a clean tree and `git ls-files -m` returns nothing.
This is a stat-cache / virtiofs interaction (also surfaces during
direct `git merge --ff-only`); `git update-index --really-refresh` may
expose a real diff or may not. When this fires, fall back to the
merge-then-soft-reset path — same end state, different mechanics:

```bash
$GIT_CMD rebase --abort 2>/dev/null || true
$GIT_CMD merge "$ANCHOR" --no-edit     # resolve any real content conflicts
$GIT_CMD commit -F /tmp/merge-commit-msg.txt   # transient merge commit (discarded by soft-reset)
$GIT_CMD reset --soft "$ANCHOR"        # collapse everything to a staged delta
$GIT_CMD commit -F "/tmp/squash-message-${FEATURE}.txt"
```

Use the same `$ANCHOR` as the rebase path (either `origin/main` or local
`main` per the detection block above). The merge fallback is anchor-agnostic
about the mechanics; the soft-reset still has to land on the same target
the rebase path would have.

`git merge` does NOT trip the phantom error (different code path inside
git). The transient merge commit's docsReviewed trailer can describe
itself as "transient merge of origin/main into <branch>, discarded by
the immediately-following soft-reset" — the reviewer accepts that shape.
After the soft-reset the merge commit is no longer reachable from
the branch; the index contains exactly origin/main..feature-branch's
delta, identical to the rebase path's output. Verified end-to-end on
the `ci-rollback-explain-marker-loud` merge (2026-05-19): rebase
phantom-failed on `PLAN.md`; merge fallback resolved 2 real content
conflicts (PLAN.md row + kit/ROADMAP.md entry both deleted on origin/main
AND on the branch — `git checkout --theirs` + re-applying the branch's
deletions resolved cleanly), then soft-reset + commit produced the same
9-file squash the rebase path would have.

**Same flake fires in `git cherry-pick` and `git am`** when applying
multiple patches that touch the same file in quick succession. The
merge-then-soft-reset workaround above only covers the squash path; for
surgical operations adjacent to the merge skill (e.g. stripping an
accidentally-inherited commit by cherry-picking onto a clean branch from
`origin/main`), use the **sleep + stat-refresh** unsticker between
operations:

```bash
git cherry-pick <sha-1>
sleep 3
git update-index --really-refresh
git cherry-pick <sha-2>
sleep 3
git update-index --really-refresh
git cherry-pick <sha-3>
```

The first cherry-pick after a clean checkout always succeeds; subsequent
ones touching the same file trip the phantom because virtiofs's stat
cache hasn't settled. A 3-second sleep + explicit
`git update-index --really-refresh` reliably unsticks it. Verified on
the `calibration-and-task-phases` strip-and-merge (2026-05-20): without
the unsticker, every cherry-pick after the first failed with the
phantom "would be overwritten by merge"; with the unsticker, all three
cherry-picks succeeded in sequence. `git apply` and `git am --3way`
also trigger the flake on the same trigger; the sleep+refresh recipe
covers them as well.

If `$GIT_CMD commit` fails (pre-commit hook block — Layer 1 docs/tests-
coverage, gitleaks, lint, typecheck, test suite): halt and surface the
hook output. The fix lives in the branch content; resolve, re-stage if
needed, retry the commit. The branch is still valid for re-invocation —
Phase 0's ff-mergeability check is the only thing that needs to re-pass.

If the rename+symlink-at-old-path combo from § Known limitations fires
during the rebase or commit: switch to the documented ff-only fallback
(unaffected by lint-staged's stash bug because it doesn't go through the
squash machinery).

---

## Phase 3: Fast-forward main + push

**Two paths** depending on whether `--source-worktree` was passed:

- **Default path** (`SOURCE_WORKTREE_ARG` empty): checkout main in
  `/devshop`, ff-merge, push. Sequence below.
- **`--source-worktree` path** (`SOURCE_WORKTREE_ARG` set): never touch
  `/devshop`'s branch state; push the squash directly from the named
  worktree via `git -C "$WORKTREE_PATH" push origin HEAD:main`. Skip
  the checkout + ff-merge entirely. `/devshop`'s local `main` ref will
  lag origin/main after; the operator re-syncs on next session.

```bash
if [ -n "$SOURCE_WORKTREE_ARG" ]; then
  # --source-worktree path: direct push from the worktree, no /devshop
  # branch switching. The squash commit on $BRANCH IS what gets pushed
  # to origin/main; the FF-merge that the default path does is unnecessary
  # because we're pushing the worktree's HEAD as if it were main.
  git -C "$WORKTREE_PATH" -c devshop.pushToMainApproved="/ak-merge-devshop Phase 3 — audit passed, squash approved by operator at Phase 0.5" push origin HEAD:main
else
  # Default path: checkout main + ff-merge in /devshop.
  git checkout main

  # Verify checkout succeeded — parallel work in another session can change
  # /devshop's HEAD between phases, and a silent checkout failure here
  # would land the squash on the wrong branch. Worked incident:
  # calibration-and-task-phases merge (2026-05-20) — /devshop's HEAD
  # silently switched to a parallel WIP branch (fix/init-firewall-pipefail)
  # between Phase 2 and Phase 3; the ff-merge landed on the WIP branch
  # instead of main. Recovery: re-checkout main and re-run Phase 3.
  CURRENT=$(git branch --show-current)
  if [ "$CURRENT" != "main" ]; then
    echo "✖ Expected to be on main after checkout, got: $CURRENT"
    echo "  Aborting Phase 3 to avoid landing the squash on the wrong branch."
    echo "  Likely cause: parallel work changed /devshop's HEAD between phases."
    echo "  Recovery: cd /devshop && git checkout main && re-invoke /ak-merge-devshop."
    echo "  Alternative: re-invoke with --source-worktree $WORKTREE_PATH"
    echo "    to skip the /devshop branch-switch entirely (won't touch your WIP)."
    exit 1
  fi

  git merge --ff-only origin/main         # catch local-main lag
  git merge --ff-only "$BRANCH"           # ff main → squash commit (no NEW commit, no hook)
  git push origin main
fi
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

Cleanup ordering matters when `WORKTREE_PATH` is set: the linked worktree
must be torn down BEFORE `git branch -D` (git refuses to delete a branch
that's still checked out in any worktree, and `-D` doesn't override that).
Submodules in the worktree need a two-command teardown (`submodule deinit
-f --all` clears working dirs but leaves git's per-worktree submodule registry,
which then trips `git worktree remove`; the `--force` flag is required to
override that registry check). Skip the worktree-teardown block entirely on
the legacy direct-checkout path.

**DCG `push-force-short` false-positive on chained `-f` flags.** The
teardown uses `-f` (`submodule deinit -f`) and `--force` (`worktree
remove --force`) — both are documented git-API requirements (per-
worktree submodule registry + branch-checked-out safety), not
destructive flags on shared state. The devshop's `core.git:push-force-
short` rule SHOULD fire only on `git push -f` / `git push --force`,
but empirically (dcg 0.4.0, verified via `dcg test`) it false-positives
on any compound command containing BOTH a `git push` (any variant —
including `git push origin --delete` and a benign `git push origin
main`) AND a separate `-f` flag elsewhere in the chain (`rm -f`,
`submodule deinit -f`, etc.). The rule's regex isn't anchored tightly
enough — it matches `git push … -f` across the full compound. Worked
trip-up (2026-05-20, `home-os-skill-polish-batch` teardown): the
chained teardown ending with `rm -f /tmp/squash-message-*.txt`
triggered `BLOCKED` even though no `git push -f` existed in the
command. **Always run each teardown step as a SEPARATE `Bash` tool
call** — do not chain with `&&` / `;` / pipes / heredocs. The
step-by-step layout below is the runnable contract; do not condense
into one block. (The underlying DCG bug is tracked separately;
splitting the teardown is the durable workaround AND has independent
operability benefits — Step 2 worktree-remove can fail independently
of Step 1's submodule-deinit, and per-step Bash calls preserve the
partial-success state for operator recovery rather than burying the
failing step inside an opaque compound exit code.)

**Worktree-vs-direct-checkout decision rule** — Steps 1 and 2 only fire when
the feature lived in a linked worktree. Steps 3+ fire always. Evaluate
once at the top, then run only the relevant per-step Bash calls:

```bash
# Decision rule (read-only — DO NOT chain the actual teardown after this):
if [ -n "$WORKTREE_PATH" ]; then
  # → run Step 1 + Step 2 below as separate Bash calls
  :
else
  # → skip to Step 3
  :
fi
```

```bash
# === Step 1 (only when WORKTREE_PATH is set): deinit submodules ===
#
# Per-worktree-checkout-dir; /devshop's submodules are untouched (separate
# working trees of the same submodule registry). The `-f` is required to
# clear submodule working dirs even when they're untouched in this worktree.
git -C "$WORKTREE_PATH" submodule deinit -f --all 2>&1 | tail -5
```

```bash
# === Step 2 (only when WORKTREE_PATH is set): remove the worktree ===
#
# `--force` is REQUIRED even after deinit: git's per-worktree submodule
# registry still trips the safety check ("working trees containing
# submodules cannot be moved or removed") independently of working-dir
# content. This is a git-API constraint, not destructive-on-shared-state.
git worktree remove --force "$WORKTREE_PATH"
```

```bash
# === Step 3: delete the local feature branch ===
#
# Fires after the worktree (if any) is gone — git refuses to delete a
# branch still checked out in any worktree. `-D` (capital) is required
# because the squash detached the constituent commits from main's
# ancestry; lowercase `-d` would refuse.
git branch -D "$BRANCH"
```

```bash
# === Step 4: delete the remote feature branch (best-effort) ===
#
# The branch may have never been pushed (local-only feature work). When
# `ls-remote` returns no match, skip the delete — printing "no remote
# branch to delete" is cleaner than letting `git push --delete` error.
if git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git push origin --delete "$BRANCH"
else
  echo "✓ no remote branch to delete (was local-only)"
fi
```

```bash
# === Step 5: tempfile cleanup ===
rm -f "/tmp/squash-message-${FEATURE}.txt"
```

If `git branch -D` fails for any reason (extremely unlikely at this point —
HEAD is on main, branch exists locally, force-delete should always work,
worktree has been torn down if it existed): surface the error and continue.
The merge has already shipped; a stale local branch is a cosmetic problem
the operator can clean up by hand.

If `git worktree remove --force` fails (filesystem permission, in-flight
submodule update racing the deinit): surface the error, leave the worktree
in place, and continue to `git branch -D` (which will then fail with
"branch is checked out at <worktree>"). The operator inspects, repairs
manually (`rm -rf .worktrees/<topic>` is the nuclear option; `git worktree
prune` reconciles registry), and re-runs Phase 4.2's commands. The merge
is durable on main at this point — failure here is cosmetic, not
data-losing.

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

### Operator stashes can vanish silently mid-merge

`git stash push` calls made by the operator (or by a well-meaning Claude
autostash) before/during this skill's run can disappear from `git stash
list` without an explicit `git stash pop` or `git stash drop` ever firing.

**Hypothesis** — lint-staged (`package.json:"lint-staged": "^15.0.0"`,
invoked from `.husky/pre-commit:5` via `pnpm exec lint-staged`) creates
a backup stash via `git stash create` on every commit where its
ESLint/Prettier tasks touch files. The mechanism is genuinely suspicious
— lint-staged is the only routine `git stash` caller on the pre-commit
path — but the simple "lint-staged drops operator stash by index
confusion" theory doesn't fit: lint-staged v15 stores its backup under
a separate `refs/lint-staged/*` namespace, not `refs/stash`, so the
two ref namespaces don't collide directly. Some interaction (perhaps
during pop-on-failure, or via a hook that runs `git stash drop` against
the wrong ref) is the working assumption; root cause is genuinely open
and waits on `GIT_TRACE=1` + `lint-staged --debug` reproduction (filed
as a `kit/TODOS.md` entry — "Operator stashes vanish silently"). Full
lint-staged config block + interaction notes:
`kit/docs/guide/hooks.md § 2 — Husky pre-commit`.

**Worked incident**: `feat/gstack-artifact-symlink-redirect` merge
(2026-05-20) — Claude autostashed 4 dirty files on `chore/devshop-
friction-todos` before the merge; the stash was gone by the time the
merge completed; a second autostash on `main` also vanished after the
ff-merge + push.

**The data is NEVER lost** — only the named ref. `git stash` writes
real commits to the object database; `git stash drop` removes the ref
but not the commit objects. They become "dangling" commits, recoverable
via `git fsck`.

**Recovery recipe**:

```bash
# 1. Find dangling commits with stash-shaped subjects.
git fsck --no-reflogs 2>/dev/null \
  | grep '^dangling commit' | awk '{print $3}' \
  | while read c; do
      msg=$(git log -1 --format='%s' "$c" 2>/dev/null)
      # Filter to stash-shaped subjects (operator stashes typically use a
      # named -m message; lint-staged transient stashes start with
      # "lint-staged automatic backup")
      case "$msg" in
        "On "*|"WIP on "*|"index on "*|"untracked files on "*)
          echo "$c: $msg"
          ;;
      esac
    done

# 2. Identify yours by the -m label (or by branch context if you used
#    git stash push without -m).

# 3. Apply with git stash apply <full-SHA>. The tree, index, and
#    untracked-files components reconstruct identically to a fresh
#    stash pop.
git stash apply <full-SHA>
```

**Prevention**: respect this skill's pre-flight refusal at Phase 0.1:
"working tree dirty at $TARGET — commit or stash first". Do NOT
autostash from inside this skill's orchestrator path. Operator stashes
made BEFORE invoking the skill are still at risk if lint-staged fires
during the merge — operators with critical WIP should commit (even to
a throwaway branch) rather than stash.

This is filed in `kit/TODOS.md` for root-cause investigation: which
hook drops which stash, and whether the bug lives in `lint-staged`'s
stash machinery (upstream) or in our `.husky/pre-commit` wrapper (fixable
here). Until that lands, the dangling-commit recovery is the durable
backstop.

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
