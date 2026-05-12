<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: pr-body-img-merge-sha-survival -->
<!-- date: 2026-05-11 -->

# Spec: pr-body-img-merge-sha-survival

**Sources:**

- `kit/ROADMAP.md § PR-body image URLs survive branch deletion (forward fix at merge + one-time backfill)` (lines 1423–1473) — primary scope; this PR retires the entry entirely.
- `PLAN.md § Planned` row #2 — feature one-liner.
- `.claude/skills/ak-go-live/SKILL.md` — Step 2 / Step 2b context for placement of the new Step 2.5.
- `.claude/skills/ak-build/SKILL.md § PR body conventions § Image embeds — private-repo safe` — the URL form being preserved.
- `kit/docs/guide/workflow.md § Step 6` — paragraph addition target.
- `kit/tests/util-build-phase58-audit-parser.bats` — BATS style reference for content-tests-of-SKILL-prose.
- `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` — retire-and-rewrite-prereq-prose convention applied at task 5/6/7.

PR body image embeds use the form `https://github.com/<owner>/<repo>/raw/<feature-branch>/<path>` (per the convention). They render fine at PR-review time, then 404 the moment `gh pr merge --delete-branch` removes the feature branch — every closed lalista PR with hero shots currently shows broken-image squares. Two-track fix lands in this PR: **Track A** inserts a body-rewrite step (`/ak-go-live § Step 2.5`) between merge and branch cleanup that repoints `/raw/${BRANCH}/` slices to `/raw/${mergeCommit.oid}/`, so future PRs survive `--delete-branch`. **Track B** ships a one-time backfill script (`/devshop/kit/scripts/backfill-pr-image-urls.sh`) and runs it once against lalista's ~50 closed PRs to repoint the existing surface. The ROADMAP entry retires entirely after this PR.

---

## Decisions (resolved at spec time)

11 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Where does the new step live in `/ak-go-live`?

**Decision:** New `### Step 2.5: Rewrite PR-body image URLs to merge SHA`, between Step 2 (`/land-and-deploy` returns merged) and Step 2b (branch cleanup).

**Rationale:** ROADMAP § Track A line 1437; placement is load-bearing — must run **after** merge produces a SHA but **before** `git branch -D` removes the branch ref the URLs currently point at.

### D2: How to determine the feature branch name in Step 2.5?

**Decision:** `gh pr view "$PR" --json headRefName --jq .headRefName` (PR-derived, not `git branch --show-current`).

**Rationale:** Robust against working-tree state; survives if any prior step accidentally checked out main. The shell-derived `BRANCH` is fine in practice but the GH-derived name is the canonical source of truth and matches what the URLs in the body actually contain.

### D3: How to determine the merge SHA?

**Decision:** `gh pr view "$PR" --json mergeCommit --jq .mergeCommit.oid`.

**Rationale:** ROADMAP line 1447: squash merge produces a single new commit on main; `mergeCommit.oid` is the canonical permanent reference. Branch-tip SHAs may be GC'd after `--delete-branch`.

### D4: URL match pattern — what gets rewritten?

**Decision:** Exact match on `https://github.com/<owner>/<repo>/raw/${HEAD_REF}/`. Branch name regex-escaped so slashes-in-branch (`feat/foo`) work. Other `/raw/<x>/` URLs (other branches, tags, main, third-party repos) preserved verbatim.

**Rationale:** ROADMAP line 1445: don't accidentally rewrite cross-PR refs or tag-based refs. Branches with `/` are conventional shape (`feat/x`, `fix/y`) — branch-name regex-escape (`${HEAD_REF//\//\\/}` style) applies.

### D5: Behavior when `mergeCommit.oid` is null

**Decision:** Print `⚠ Step 2.5: no mergeCommit.oid — skipping body rewrite`, continue to Step 2b. Non-fatal.

**Rationale:** Squash-merge is the default and the only path `/ak-go-live` invokes — null oid means the operator did something out-of-band (rebase merge, manual). Don't halt their flow; just don't rewrite URLs we can't anchor.

### D6: Behavior when body has zero `/raw/${HEAD_REF}/` matches

**Decision:** Silent no-op: print `✓ Step 2.5: no /raw/${HEAD_REF}/ URLs in body — nothing to rewrite`. No `gh pr edit` call.

**Rationale:** Most non-UI PRs have no image embeds; this is the common case. Silent-but-attesting pass leaves a log line for the operator without noise.

### D7: Track B (one-time backfill) — bundle in this PR or split?

**Decision:** **Bundle.** Both tracks ship in this PR. Track A protects new PRs; Track B catches up the existing surface (~15+ closed lalista PRs with hero shots).

**Rationale:** Splitting would leave the existing broken surface un-repaired until a follow-up landed, with no good reason to defer. ROADMAP marks them as independent, but "independent" means "no implementation coupling," not "must ship in separate PRs."

### D7a: Where does the backfill script live?

**Decision:** `/devshop/kit/scripts/backfill-pr-image-urls.sh` (root of `kit/scripts/`, alongside `populate-playwright-cache.sh` etc.).

**Rationale:** There's no `/devshop/kit/scripts/devshop/` subdir today; the ROADMAP's path was speculative. Match the existing layout.

### D7b: Does the bundled PR also **run** the backfill against lalista, or just ship the script?

**Decision:** **Ship + run** against lalista in this same session, after the PR is created. The audit log JSONL goes under `/workspace/.gstack/backfill-pr-image-urls/<timestamp>.jsonl` (which is git-tracked per lalista's gstack wiring).

**Rationale:** Operator-visible artifact + audit trail. The devshop repo's own PRs get a separate run after this PR merges, since rewriting devshop's own merged PRs while the script is mid-merge would be confusing.

### D7c: Safety flags on the script

**Decision:** Per ROADMAP § Track B: `--dry-run` (default), `--accept-history-rewrite` (required to mutate), `--owner` / `--repo`, `--limit N`, `--since <date>`. JSONL audit log per-run. Skip PRs where `headRefName` is empty. **Post-merge-edit conservatism is opt-in via `--skip-edited`, NOT default.** When enabled, skips PRs where `updatedAt > mergedAt + 5min`.

**Rationale:** ROADMAP § Track B § Safety notes; explicit `--accept-history-rewrite` forces operator acknowledgement.

**Polish update (Phase 5.5 lalista backfill, 2026-05-11)**: D7c originally had post-merge-edit conservatism on by default. The lalista backfill surfaced the actual failure mode — `/ak-build` Phase 5.3 routinely edits PR bodies post-merge to mark CI checkboxes (and Phase 6 posts audit comments, etc.), which the 5min heuristic mis-reads as "operator manually fixed something." Result: PRs #60 / #61 (with 3 and 7 hero shot URLs respectively) were silently skipped on the conservative run, and only got rewritten when the heuristic was flipped to opt-in. The asymmetry is severe: false skips are concretely happening on every UI-touching PR that passes through the pipeline; false rewrites are essentially hypothetical (the script's idempotence + the fact that any prior URL-fix would itself eliminate `/raw/<branch>/` matches means a re-rewrite is at worst a no-op). New default: rewrite when `/raw/<branch>/` matches exist, period. Operators who want the conservatism (e.g., for repos where they routinely hand-edit post-merge URL fixes to non-merge-SHA refs) can opt in with `--skip-edited`. Post-polish run on lalista: 9 PRs / 45 URLs total rewritten across both runs (3 PRs / 11 URLs from the conservative pass + 6 PRs / 34 URLs from the aggressive default that the original D7c would have skipped).

### D7d: BATS coverage for Track B

**Decision:** Behavior tests for the script's filter logic — fixture inputs (PR JSON shapes) → expected dry-run output. Same `util-go-live-step-25-body-rewrite.bats` file, additional `@test` blocks. The actual `gh` call surface mocked via `_FAKE_GH=1` env var that switches to fixture stdin.

**Rationale:** One test file per related feature keeps the BATS suite navigable. Mocking `gh` lets the tests run in CI without GitHub credentials and without depending on real PR state.

### D8: Workflow.md prose addition placement

**Decision:** Inside `## Step 6: /ak-go-live` numbered list, between current bullet 2 (`/land-and-deploy`) and bullet 3 (Branch cleanup). New bullet 2.5: one-paragraph summary of the rewrite.

**Rationale:** Mirrors the SKILL.md placement so the guide stays a faithful narrative of the skill steps. Cross-references Step 2.5 by name.

### D9: BATS test scope

**Decision:** `kit/tests/util-go-live-step-25-body-rewrite.bats`. **Content tests** against `/devshop/.claude/skills/ak-go-live/SKILL.md` (Step 2.5 exists, names `mergeCommit.oid`, exact-branch-match phrasing, runs before Step 2b). **Behavior tests** of the rewrite logic via a small extracted shell function `rewrite_pr_body_urls()` exercised with fixture bodies (rewrites the right URLs, leaves cross-branch / tag / `main` URLs alone, no-op on empty match, escapes slashed branch names). Plus the Track B script behavior tests per D7d.

**Rationale:** Mirrors `util-build-phase58-audit-parser.bats` shape (content tests for skill prose) plus behavior tests for the logic. The skill itself doesn't ship a separate `.sh` file; the function lives inline in the SKILL block but is small + extractable for test by `source`-ing a tiny helper script that the SKILL prose also references.

### D10: What backlog entries get retired when this ships?

**Decision:** Delete `/devshop/kit/ROADMAP.md § PR-body image URLs survive branch deletion` (lines 1423–1473) **entirely** (both tracks shipped). Delete `/devshop/PLAN.md` row #2 (`pr-body-img-merge-sha-survival`); renumber row #3 → #2. Convert any "Without this, image URLs 404 on close" preflight prose elsewhere to imperative present per the closing-tracker convention.

**Rationale:** `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` — both `delete` (no strikethrough) and `rewrite-prereq-prose-to-imperative-present` apply. Bundling Track B means no scoped Track-B-only entry survives.

### D11: Carry-over commit for the `/devshop` dirty diff

**Decision:** Land as one separate commit `chore(roadmap): scope gstack-artifact-path-resolution` at the head of the new branch BEFORE the feature work begins. The diff is purely PLAN.md row #3 + kit/TODOS.md scoping entry for a _sibling_ future feature — orthogonal but worth preserving.

**Rationale:** User explicitly authorized this in `/ak-build` args. Separate commit keeps history clean — feature audit comment doesn't need to mention this carry-over. **Status: already shipped as commit `ca6131f`** before Phase 1.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Screens (n/a),
     Data model changes (n/a), API contracts (script + SKILL prose), Files
     to create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance
     / rollout / rollback. The Decisions section above stays verbatim. -->

## Core user story

N/A — pure tooling change. Affects `/ak-go-live`'s deploy pipeline and a one-time
backfill script; no end-user-observable surface in the lalista web app. Gate 9
(qa-walk) recognizes `N/A` and skips the per-verb artifact assertion for this PR.

## Render conditions

N/A — no UI surface added or modified. The diff is entirely SKILL.md prose, a
new bash script under `kit/scripts/`, BATS tests, and tracker hygiene.

## Data model changes

None. No migrations, no schema diffs, no edge-function changes.

## Metrics

No new METRICS.md events. The Decisions section did not surface any (D1–D11
all touch tooling / docs / tests, not user-observable behavior in lalista). If
a reviewer disagrees, surface the gap as a stop-and-ask Decision row before
`/ak-implement` writes code — per `kit/docs/guide/conventions.md § Confidence
Calibration`, new metric events are a stop-and-ask category.

## In scope

**Track A — forward fix at merge time** (per D1, D2, D3, D4, D5, D6):

- New `### Step 2.5: Rewrite PR-body image URLs to merge SHA` in
  `/devshop/.claude/skills/ak-go-live/SKILL.md`, placed between Step 2
  (`/land-and-deploy` returns merged) and Step 2b (branch cleanup).
- Step 2.5 derives `HEAD_REF` via `gh pr view "$PR" --json headRefName`,
  derives `MERGE_SHA` via `gh pr view "$PR" --json mergeCommit`, fetches the
  current PR body, calls a small extractable shell helper
  `rewrite_pr_body_urls()` to repoint `https://github.com/<owner>/<repo>/raw/<HEAD_REF>/<path>`
  to `https://github.com/<owner>/<repo>/raw/<MERGE_SHA>/<path>` (exact
  branch match, regex-escaped), and writes the rewritten body back via
  `gh pr edit "$PR" --body-file -`.
- Skip semantics codified per D5 (null `mergeCommit.oid` → warn-and-continue)
  and D6 (zero matches → silent attesting pass).
- One-paragraph reference paragraph in `kit/docs/guide/workflow.md` Step 6
  (per D8), inserted as a new bullet 2.5 between current bullet 2
  (`/land-and-deploy`) and current bullet 3 (branch cleanup), so the guide
  narrative stays a faithful mirror of the skill steps.

**Track B — one-time per-project backfill** (per D7, D7a, D7b, D7c):

- New shell script at `/devshop/kit/scripts/backfill-pr-image-urls.sh`.
- Lists merged PRs via `gh pr list --state merged --json number,headRefName,mergeCommit,body,mergedAt,updatedAt`,
  filters per the safety rules (per D7c), rewrites bodies, writes a per-run
  JSONL audit log under `${GSTACK_HOME:-$HOME/.gstack}/backfill-pr-image-urls/<UTC-ts>.jsonl`.
- Default mode is `--dry-run`; mutation requires explicit `--accept-history-rewrite`.
- Reuses the same `rewrite_pr_body_urls()` helper as Track A (single source
  of truth for the rewrite shape; no behavior drift between forward fix and
  backfill).
- Bundled run against lalista's ~50 closed PRs in this same session, after
  the PR is created (Phase 5.5 of `/ak-build`, per D7b). Devshop's own merged
  PRs get a separate run after this PR merges.

**Tracker hygiene** (per D10):

- Delete `kit/ROADMAP.md § PR-body image URLs survive branch deletion`
  (lines 1423–1473) entirely — both tracks shipped, no scoped follow-up.
- Delete `PLAN.md` row #2 (`pr-body-img-merge-sha-survival`); renumber row
  #3 (`gstack-artifact-path-resolution`) → #2.
- `grep -rE 'image URLs?.*404|broken image.*PR body' kit/ apps/` (or equivalent)
  to find any preflight prose elsewhere that mentions the bug as a hypothetical;
  rewrite to imperative present (the fix exists, narrate it as such) per
  `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`.

**BATS coverage** (per D9, D7d):

- New file `kit/tests/util-go-live-step-25-body-rewrite.bats` covering both
  the SKILL.md prose contract (content tests) and the rewrite-helper +
  backfill-script behavior (behavior tests).

**Out of scope**:

- Any change to `/ak-build § PR body conventions § Image embeds — private-repo
safe`. The URL form stays `https://github.com/<owner>/<repo>/raw/<branch>/<path>`
  at PR-creation time; Track A repoints it at merge time. The convention is
  preserved exactly because Track A's load-bearing precondition is that the
  pre-merge form contains `<branch>` (so it's identifiable at merge time).
- Comment rewriting. Only PR bodies are touched; comments are immutable
  history (per ROADMAP § Track B safety notes; preserved as a Track B
  invariant in the script preamble).
- Any new metric events (see § Metrics above).
- Re-architecting the URL form to use the merge SHA at PR-creation time
  (would require knowing the merge SHA before the merge happens — chicken-and-egg).

## Files to create / modify

**Modify:**

| Path                                                                              | Change                                                                                                                                                                                                                                                                                                          |
| --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/devshop/.claude/skills/ak-go-live/SKILL.md`                                     | Insert `### Step 2.5: Rewrite PR-body image URLs to merge SHA` between current Step 2 and Step 2b. Include the inline `rewrite_pr_body_urls()` helper definition (or `source` of an extracted helper script — see API contracts § "Helper extraction strategy"). Bump `version:` field from `1.3.0` to `1.4.0`. |
| `/devshop/kit/docs/guide/workflow.md`                                             | Add new bullet 2.5 inside `## Step 6: /ak-go-live` numbered list, between current bullet 2 (`/land-and-deploy`) and current bullet 3 (Branch cleanup). One paragraph; cross-references `Step 2.5` by name; describes the rewrite + the skip semantics (D5, D6).                                                 |
| `/devshop/kit/ROADMAP.md`                                                         | Delete the entry `### PR-body image URLs survive branch deletion (forward fix at merge + one-time backfill)` (lines 1423–1473) entirely (both tracks shipped).                                                                                                                                                  |
| `/devshop/PLAN.md`                                                                | Delete row #2 (`pr-body-img-merge-sha-survival`) from `## Planned`; renumber row #3 (`gstack-artifact-path-resolution`) → #2.                                                                                                                                                                                   |
| `/devshop/BUILD-LOG.md`                                                           | Append the ship entry for `pr-body-img-merge-sha-survival` per `/ak-build` Phase 5.6 conventions (handled by Phase 5.6, not by `/ak-implement` directly — listed here for completeness of the surface this PR touches).                                                                                         |
| Any file matching `grep -rE 'image URLs?.*404\|broken image.*PR body' kit/ apps/` | Rewrite preflight prose ("Without this, image URLs 404 on close") to imperative present — the fix exists, narrate it as such (per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`). Likely zero hits; if any, edit in the same commit as the ROADMAP entry retirement (Task 5).          |

**Create:**

| Path                                                                                                    | Purpose                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `/devshop/kit/scripts/backfill-pr-image-urls.sh`                                                        | The Track B one-time backfill script. Bash, `set -euo pipefail`, executable. CLI per § API contracts. Sources or inlines the `rewrite_pr_body_urls()` helper for behavior parity with Track A.                                                                                        |
| `/devshop/kit/tests/util-go-live-step-25-body-rewrite.bats`                                             | BATS suite covering SKILL.md prose contracts + rewrite-helper behavior + backfill-script behavior. Per § Tests.                                                                                                                                                                       |
| `/devshop/kit/scripts/lib/rewrite-pr-body-urls.sh` _(optional, see "Helper extraction strategy" below)_ | Tiny extracted helper script defining `rewrite_pr_body_urls()`. Sourced by both `/ak-go-live` Step 2.5 (inline `source` line) and `backfill-pr-image-urls.sh`, AND by the BATS behavior tests. Single source of truth — no drift between Track A's inline use and Track B's loop use. |

**Helper extraction strategy** (informs whether `lib/rewrite-pr-body-urls.sh` is created):

D9's "small extracted shell function `rewrite_pr_body_urls()` exercised with
fixture bodies" implies a sourceable file the BATS suite can `source`. Two
implementation shapes both satisfy D9; the implementer picks one in Task 1:

- **Shape A (inline + duplicate)**: define `rewrite_pr_body_urls()` inline in
  `SKILL.md`'s Step 2.5 code block AND duplicate it in `backfill-pr-image-urls.sh`.
  BATS tests `eval` the function definition out of the script. Pro: no new
  file. Con: two definitions to keep in sync; future drift risk.
- **Shape B (extracted)**: ship `kit/scripts/lib/rewrite-pr-body-urls.sh` defining
  the function; `SKILL.md` Step 2.5 has `source /devshop/kit/scripts/lib/rewrite-pr-body-urls.sh`
  inline; backfill script `source`s the same; BATS suite `source`s the same.
  Pro: single definition, no drift. Con: one extra file.

**Recommend Shape B** for the no-drift property — D9's rationale ("the SKILL
itself doesn't ship a separate `.sh` file; the function lives inline in the
SKILL block but is small + extractable for test by `source`-ing a tiny helper
script that the SKILL prose also references") explicitly contemplates the
extracted helper. The tiny-helper file is the cleanest read of D9.

## API contracts

### `rewrite_pr_body_urls()` (extracted helper for Track A)

Bash function, sourced from `kit/scripts/lib/rewrite-pr-body-urls.sh` (per
"Helper extraction strategy" Shape B above).

**Signature**:

```bash
rewrite_pr_body_urls <body-file-in> <body-file-out> <owner-repo> <head-ref> <merge-sha>
```

| Arg               | Type   | Meaning                                                                                                                                         |
| ----------------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `<body-file-in>`  | path   | File containing the current PR body (typically a tmpfile written by `gh pr view --json body --jq .body`).                                       |
| `<body-file-out>` | path   | File to write the rewritten body to. May equal `<body-file-in>` (in-place rewrite supported via tmpfile shuffle inside the function).           |
| `<owner-repo>`    | string | `<owner>/<repo>` slug (e.g., `meirmsn/lalista`). Used to scope the URL match to this repo (preserves third-party-repo `/raw/` URLs).            |
| `<head-ref>`      | string | The PR's `headRefName` — the feature branch name. May contain `/` (`feat/foo`); the function regex-escapes it before pattern construction (D4). |
| `<merge-sha>`     | string | The squash-merge commit SHA from `mergeCommit.oid` (D3). 40-char hex.                                                                           |

**Behavior**:

- Reads `<body-file-in>`.
- Substitutes every literal occurrence of
  `https://github.com/<owner-repo>/raw/<head-ref>/` with
  `https://github.com/<owner-repo>/raw/<merge-sha>/`.
- The `<head-ref>` is regex-escaped (`/` → `\/`, `.` → `\.`, etc.) before the
  pattern is assembled so branches like `feat/foo.bar` substitute correctly
  (D4). Implementation may use `perl -pe` or `sed` with the escaping done in
  Bash; either is acceptable.
- Writes the result to `<body-file-out>`.
- Prints to stderr a one-line summary: `rewrote <N> URL(s) (head=<head-ref> sha=<short-sha>)`. If `N == 0`, prints
  `no /raw/<head-ref>/ URLs in body — nothing to rewrite`.

**Exit code**: 0 always (no-op-on-empty is a valid outcome, not an error).

**Idempotence**: a second call with the same args on the just-rewritten body
finds zero matches (the body now has `<merge-sha>` not `<head-ref>` in URL
slots) and is a no-op. This is what makes Track B safe to re-run.

### `backfill-pr-image-urls.sh` flags (Track B)

Per D7c. CLI signature:

```
backfill-pr-image-urls.sh
  --owner <owner>                  GitHub org/user that owns the repo (required)
  --repo <repo>                    Repo name (required)
  [--dry-run]                      Default. Print planned rewrites; do not call gh pr edit.
  [--accept-history-rewrite]       Required to actually mutate. Mutually exclusive with --dry-run
                                   in semantics — passing both is an error (operator must pick).
  [--limit <N>]                    Cap PR scan to most-recent N merged PRs. Default: 100.
  [--since <YYYY-MM-DD>]           Only consider PRs merged on or after this date. Default: unset.
  [--audit-dir <path>]             Override audit-log dir. Default:
                                   ${GSTACK_HOME:-$HOME/.gstack}/backfill-pr-image-urls/
  [--help | -h]                    Print usage + exit 0.
```

**Required**: `--owner`, `--repo`, AND exactly one of `{--dry-run,
--accept-history-rewrite}`. If `--accept-history-rewrite` is omitted, the
script defaults to `--dry-run` and prints a banner explaining how to actually
mutate.

**Skip rules** (per D7c, applied per-PR; each skip emits one JSONL audit row
with `outcome: "skip"` and a `reason` field):

| Reason code              | Predicate                                                                                                   |
| ------------------------ | ----------------------------------------------------------------------------------------------------------- |
| `no-head-ref`            | `headRefName` is empty/null.                                                                                |
| `no-merge-sha`           | `mergeCommit.oid` is null (manual / non-squash close).                                                      |
| `body-edited-post-merge` | `updatedAt > mergedAt + 5min` (5min grace; the operator may have manually fixed evidence URLs).             |
| `no-matching-urls`       | The body contains zero `/raw/<headRefName>/` patterns scoped to `<owner>/<repo>`. Common — most non-UI PRs. |

**Audit log JSONL row schema** (one row per PR processed, including skips):

```json
{
  "ts": "2026-05-11T22:14:03Z",
  "pr": 53,
  "head_ref": "feat/foo",
  "merge_sha": "abc1234567890...",
  "merged_at": "2026-05-08T14:22:00Z",
  "updated_at": "2026-05-08T14:22:01Z",
  "url_count_before": 7,
  "url_count_after": 7,
  "outcome": "rewrote",
  "reason": null,
  "dry_run": false
}
```

`outcome` ∈ `{rewrote, dry-run-would-rewrite, skip, error}`. `reason` is non-null
only for `skip` and `error`. For `rewrote` and `dry-run-would-rewrite`,
`url_count_before` is the number of `/raw/<head-ref>/` matches found and
`url_count_after` is the same value (every match becomes a `<merge-sha>` URL —
counts don't drop, just shift slot).

**Exit codes**:

- `0` — completed (zero or more PRs processed; including all-skips).
- `1` — invalid CLI args (missing `--owner`/`--repo`, conflicting flags, unknown flag).
- `2` — `gh` unavailable or unauthenticated.
- `3` — repo not found / no merged PRs returned at all.

**Rate limit**: ~5000 authenticated `gh api` requests per hour; ~50 PRs × 2
calls each (`gh pr view` for body + `gh pr edit` to write back) = ~100 calls.
Well under the limit. No throttling shim needed in v0.

## Tests

`kit/tests/util-go-live-step-25-body-rewrite.bats` — single file per D9 / D7d.
Mirrors the `util-build-phase58-audit-parser.bats` content-tests-of-SKILL-prose
shape, layered with behavior tests of the rewrite helper and the backfill
script. Behavior tests mock `gh` via `_FAKE_GH=1` env var that switches
fixture-stdin (per D7d).

### Content tests — SKILL.md prose (per D9)

| `@test` name                                                                      | Asserts                                                                                                                                                                                                                                                                                                                                                                                            |
| --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Step 2.5 exists between Step 2 and Step 2b`                                      | Section header `### Step 2.5: Rewrite PR-body image URLs to merge SHA` exists; line number is between `## Step 2:` and `## Step 2b:` headers. Order is load-bearing per D1.                                                                                                                                                                                                                        |
| `Step 2.5 names mergeCommit.oid as the SHA source`                                | `gh pr view ... --json mergeCommit` and `.mergeCommit.oid` appear in Step 2.5's code block. Per D3.                                                                                                                                                                                                                                                                                                |
| `Step 2.5 names headRefName as the branch source (not git branch --show-current)` | `gh pr view ... --json headRefName` appears in Step 2.5; `git branch --show-current` does NOT appear inside Step 2.5's section slice. Per D2.                                                                                                                                                                                                                                                      |
| `Step 2.5 documents the exact-branch-match phrasing`                              | Step 2.5 prose mentions "exact" / "exact-match" / "exact branch" + names that other branches / tags / `main` / cross-PR refs are preserved. Per D4.                                                                                                                                                                                                                                                |
| `Step 2.5 documents the null-mergeCommit.oid skip`                                | Step 2.5 includes the warn-and-continue path with a recognizable phrase (e.g. `no mergeCommit.oid`, `skipping body rewrite`). Per D5.                                                                                                                                                                                                                                                              |
| `Step 2.5 documents the zero-match silent pass`                                   | Step 2.5 includes the no-op path with a recognizable phrase (`nothing to rewrite` / `no /raw/...URLs in body`). Per D6.                                                                                                                                                                                                                                                                            |
| `Step 2.5 runs BEFORE Step 2b's git branch -D`                                    | Step 2b's `git branch -D` line exists at a higher line number than Step 2.5's section. Load-bearing per D1 — branch must still be alive when the rewrite reads `headRefName` (well, headRefName comes from `gh pr view` so branch ref isn't strictly required, but the ordering invariant is what's being asserted; the rewrite's URL re-anchoring must conceptually precede the branch deletion). |
| `ak-go-live SKILL.md version bumped to 1.4.0+`                                    | `version:` field in frontmatter is `1.4.0` or higher (mirrors `util-build-phase58-audit-parser.bats`'s version-bump assertion shape).                                                                                                                                                                                                                                                              |
| `workflow.md Step 6 has bullet 2.5 paragraph`                                     | `kit/docs/guide/workflow.md`'s `## Step 6: /ak-go-live` section contains a bullet 2.5 (or numbered item between bullet 2 and bullet 3) referencing Step 2.5 by name. Per D8.                                                                                                                                                                                                                       |

### Behavior tests — `rewrite_pr_body_urls()` helper (per D9)

Source the helper file (`kit/scripts/lib/rewrite-pr-body-urls.sh` per Shape B,
or `eval` the inline definition per Shape A). Each test writes a fixture body
to a tmpfile, calls the helper, and asserts the rewritten body:

| `@test` name                                                        | Fixture body                                                                                       | Args                                            | Expected                                                                                                 |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `rewrites a single feature-branch URL to merge-SHA URL`             | One `https://github.com/o/r/raw/feat-x/specs/foo/hero.png` line.                                   | owner-repo=`o/r` head-ref=`feat-x` sha=`abc...` | URL slug becomes `/raw/abc.../`. Single substitution.                                                    |
| `rewrites multiple feature-branch URLs in one body`                 | 5 image-embed lines, all on the same feature branch.                                               | same                                            | All 5 lines rewritten.                                                                                   |
| `preserves a /raw/<other-branch>/ URL elsewhere in body`            | Mixes `/raw/feat-x/` (target) with `/raw/feat-other/` (must preserve).                             | head-ref=`feat-x`                               | Only `/raw/feat-x/` is rewritten; `/raw/feat-other/` survives verbatim.                                  |
| `preserves a /raw/main/ URL`                                        | Mixes target with `/raw/main/some.png`.                                                            |                                                 | `/raw/main/` survives.                                                                                   |
| `preserves a /raw/<tag>/ URL`                                       | Mixes target with `/raw/v1.2.3/some.png`.                                                          |                                                 | Tag URL survives (head-ref doesn't match a tag name).                                                    |
| `preserves a third-party-repo /raw/<head-ref>/ URL`                 | `https://github.com/other-owner/other-repo/raw/feat-x/foo.png` (same branch name, different repo). | owner-repo=`o/r` head-ref=`feat-x`              | Third-party URL survives (owner/repo scope guard).                                                       |
| `escapes slashes in slashed branch names (feat/foo)`                | URL with `/raw/feat/foo/path.png`.                                                                 | head-ref=`feat/foo`                             | Rewrites correctly; `/foo` is part of the matched branch, not the path. Per D4 regex-escape requirement. |
| `escapes regex metacharacters in branch names (feat.foo, feat+foo)` | URLs with `/raw/feat.foo/` and `/raw/feat+foo/`.                                                   | head-ref=`feat.foo` then `feat+foo`             | Each branch matches its own URL; the `.` and `+` are regex-escaped, not interpreted.                     |
| `is a no-op when body has zero matching URLs`                       | Body with no `/raw/` URLs at all.                                                                  |                                                 | `url_count_before == 0`; output body byte-identical to input.                                            |
| `is idempotent — second call on rewritten body is a no-op`          | Run helper, capture output, run helper again with same args.                                       |                                                 | Second invocation: zero matches, body unchanged from first invocation's output.                          |

### Behavior tests — `backfill-pr-image-urls.sh` (per D7d)

`gh` mocked via `_FAKE_GH=1` env — the tests stub `gh` with a shell function
that reads from a fixture JSON file in the test's tmpdir, so no GitHub
credentials or network are needed in CI:

| `@test` name                                                              | Fixture                                                     | Asserts                                                                                                            |
| ------------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `--help prints usage and exits 0`                                         | n/a                                                         | Exit code 0; stdout contains `--owner`, `--repo`, `--dry-run`, `--accept-history-rewrite`.                         |
| `missing --owner exits 1`                                                 | n/a                                                         | Exit 1; stderr names `--owner`.                                                                                    |
| `missing --repo exits 1`                                                  | n/a                                                         | Exit 1; stderr names `--repo`.                                                                                     |
| `--dry-run + --accept-history-rewrite together exit 1`                    | n/a                                                         | Exit 1; stderr explains the conflict.                                                                              |
| `default mode is dry-run`                                                 | One PR with matching URLs.                                  | Audit JSONL row's `dry_run: true` and `outcome: "dry-run-would-rewrite"`. No `gh pr edit` mock invocation.         |
| `--accept-history-rewrite mutates the body`                               | Same fixture as above.                                      | Audit row's `dry_run: false` and `outcome: "rewrote"`. Mock `gh pr edit` was invoked once with the rewritten body. |
| `skips PR with empty headRefName, audit reason=no-head-ref`               | One PR with `headRefName: ""`.                              | Audit row's `outcome: "skip"`, `reason: "no-head-ref"`.                                                            |
| `skips PR with null mergeCommit.oid, audit reason=no-merge-sha`           | One PR with `mergeCommit: null`.                            | Audit row's `reason: "no-merge-sha"`.                                                                              |
| `skips PR edited >5min after merge, audit reason=body-edited-post-merge`  | One PR with `updatedAt = mergedAt + 6min`.                  | Audit row's `reason: "body-edited-post-merge"`.                                                                    |
| `does NOT skip PR edited within 5min grace`                               | One PR with `updatedAt = mergedAt + 4min`.                  | Processed normally (rewrite path runs).                                                                            |
| `silent skip for PR with no matching URLs, audit reason=no-matching-urls` | One PR whose body has no `/raw/<headRefName>/` matches.     | Audit row's `reason: "no-matching-urls"`.                                                                          |
| `--limit caps PR scan`                                                    | 5 PRs in fixture.                                           | Run with `--limit 2`; only 2 audit rows produced.                                                                  |
| `--since filters to merged-on-or-after`                                   | 3 PRs with varying mergedAt.                                | Run with `--since 2026-05-01`; only PRs ≥ that date appear in audit.                                               |
| `idempotent re-run on already-rewritten body is all-skip`                 | Run mutate once; capture mock-mutated state; re-run mutate. | Second run's audit rows all have `reason: "no-matching-urls"`.                                                     |
| `audit log JSONL is well-formed`                                          | Any successful run.                                         | Each line in the audit log parses as JSON; required keys present per the schema in § API contracts.                |

## Dependencies

None beyond what `/devshop` already has:

- `gh` (GitHub CLI) — used by every existing `/ak-build` and `/ak-go-live`
  step that touches PRs. Already installed in the devcontainer.
- `jq` — used everywhere in the existing skills; available in devcontainer.
- `bash` (4.x or later) — devcontainer ships current bash; the regex-escape
  - `${var//pat/repl}` parameter expansions used in `rewrite_pr_body_urls()`
    are all bash 4-safe.
- `perl` or `sed` — for the actual substitution. Both ship in the devcontainer.
  Implementation picks one in Task 1; recommend `perl -pe` for safer regex
  handling (`sed`'s BRE/ERE differences across platforms have bitten us
  elsewhere — see `kit/scripts/populate-playwright-cache.sh` which standardized
  on perl for the same reason).
- `bats` — already in devcontainer; runs the existing
  `kit/tests/util-build-phase58-audit-parser.bats`.

No new packages, no new platform requirements, no new credentials. The
backfill script's `--accept-history-rewrite` runs against any repo the
operator's `gh auth` already has push access to — no separate GitHub App or
service-account setup.

## Task order

Dependency-ordered list of the 7 implementation tasks. Task 0 (the carry-over
scoping commit) already shipped as `ca6131f` before Phase 1.

| #   | Task                                                                                                                                                                                                                                                                                                                                                                                                                      | Why this position                                                                                                                                                                                                                                                                                                                                                                           | Touches                                                                                |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 0   | _(already shipped — `ca6131f`)_ chore(roadmap): scope `gstack-artifact-path-resolution`                                                                                                                                                                                                                                                                                                                                   | Carry-over from a prior session; orthogonal to the feature; landed at the head of the new branch BEFORE Phase 1 per D11.                                                                                                                                                                                                                                                                    | `PLAN.md`, `kit/TODOS.md`.                                                             |
| 1   | Add Step 2.5 to `/ak-go-live` SKILL.md (bump v1.4.0). Define and inline-source the `rewrite_pr_body_urls()` helper (Shape B → ship the extracted helper file in this task).                                                                                                                                                                                                                                               | Foundation. The helper file (`kit/scripts/lib/rewrite-pr-body-urls.sh`) it references must exist before Task 3 (backfill script sources the same helper).                                                                                                                                                                                                                                   | `.claude/skills/ak-go-live/SKILL.md`, `kit/scripts/lib/rewrite-pr-body-urls.sh` (new). |
| 2   | Add bullet 2.5 to `kit/docs/guide/workflow.md` Step 6.                                                                                                                                                                                                                                                                                                                                                                    | Docs paragraph mirrors Task 1's skill change; lands together so the docs-coverage hook contract is satisfied in a single commit.                                                                                                                                                                                                                                                            | `kit/docs/guide/workflow.md`.                                                          |
| 3   | Create `/devshop/kit/scripts/backfill-pr-image-urls.sh`. Sources the same `kit/scripts/lib/rewrite-pr-body-urls.sh` from Task 1 — single source of truth, no behavior drift.                                                                                                                                                                                                                                              | Depends on Task 1's helper file existing.                                                                                                                                                                                                                                                                                                                                                   | `kit/scripts/backfill-pr-image-urls.sh` (new).                                         |
| 4   | Write `kit/tests/util-go-live-step-25-body-rewrite.bats` covering content tests (Tasks 1, 2) + behavior tests (helper from Task 1, script from Task 3).                                                                                                                                                                                                                                                                   | Tests come after the surfaces they cover exist. Per the `kit/docs/guide/conventions.md § Test Presence` non-negotiable, the test file lands in the same PR.                                                                                                                                                                                                                                 | `kit/tests/util-go-live-step-25-body-rewrite.bats` (new).                              |
| 5   | Retire `kit/ROADMAP.md § PR-body image URLs survive branch deletion` (delete lines 1423–1473 entirely, both tracks shipped). Also `grep -rE 'image URLs?.*404\|broken image.*PR body' kit/ apps/` and rewrite any preflight prose to imperative present.                                                                                                                                                                  | Per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`. Lands AFTER Tasks 1–4 ship the actual fix; doing it earlier would leave a window where the ROADMAP says "todo" while the fix already exists in the diff.                                                                                                                                                        | `kit/ROADMAP.md` + any greps.                                                          |
| 6   | Retire `PLAN.md` row #2 (`pr-body-img-merge-sha-survival`); renumber row #3 (`gstack-artifact-path-resolution`) → #2.                                                                                                                                                                                                                                                                                                     | Per `/ak-build` Phase 5.6's "remove the Active row" convention. (The Active row removal happens at Phase 5.6, but row #2 is in `## Planned` not `## Active` because Task 0 didn't move it; either way the renumbering happens in the same edit.) Lands as part of Phase 5.6's tracker close-out, not as a separate `/ak-implement` task — listed here for visibility into the full surface. | `PLAN.md`.                                                                             |
| 7   | Phase 5.5: run the backfill against lalista's ~50 closed PRs (per D7b). NOT a code task — operator action via `bash /devshop/kit/scripts/backfill-pr-image-urls.sh --owner meirmsn --repo lalista --accept-history-rewrite`. Captures audit log JSONL under `/workspace/.gstack/backfill-pr-image-urls/<ts>.jsonl` (git-tracked per lalista's gstack wiring). Spot-check 3 random rewritten PRs to confirm images render. | Bundled run per D7b. Happens in Phase 5.5 of `/ak-build` — after PR creation, before Phase 6 audit comment. Devshop's own merged PRs get a separate run after this PR merges (would be confusing to rewrite devshop's own PRs while this PR is mid-merge).                                                                                                                                  | No repo files; produces an audit log artifact + lalista PR-body mutations on GitHub.   |

## Gotchas

- **Regex-escaping the head-ref is load-bearing.** Conventional branch shapes
  (`feat/foo`, `fix/bar`, `chore/x.y`) contain `/` and `.` — both are regex
  metacharacters in `perl -pe` / `sed -E`. Without escaping, `/raw/feat/foo/`
  pattern-matches `feat<any-char>foo` (so a sibling URL `/raw/featAfoo/` would
  spuriously match). Implementation MUST regex-escape the head-ref before
  pattern construction. Bash idiom (one of several valid):
  `HEAD_REF_ESC=$(printf '%s' "$HEAD_REF" | perl -pe 's/([\/.+*?\[\]{}()^\$|\\])/\\$1/g')`.
  The BATS test `escapes slashes in slashed branch names (feat/foo)` and
  `escapes regex metacharacters in branch names (feat.foo, feat+foo)` are the
  regression assertion for this.

- **Track B's post-merge-edit heuristic (D7c) is conservative — false skips
  surface in the audit log, not silently.** `updatedAt > mergedAt + 5min`
  catches the legitimate case where an operator manually fixed evidence URLs
  post-merge (don't clobber their fix); but it ALSO catches harmless edits
  (`/ak-go-live` Step 6's notify comment doesn't bump `updatedAt` because
  comments are separate from body, but a `gh pr edit --add-label` does, and
  any post-merge body edit by `/ak-build` Phase 6 itself would). The audit
  log row's `outcome: "skip"`, `reason: "body-edited-post-merge"` makes false
  skips investigable — operator can manually re-run with `--limit 1` after
  inspecting the PR. Don't add automatic 3-way-merge-of-body-content logic;
  it's overkill for evidence URLs and would be its own correctness liability.

- **Track A's rewrite happens BEFORE Step 2b's `git branch -D`, but the URLs
  being rewritten are derived from the PR's `headRefName` (via `gh pr view`),
  not from the local branch.** This is a deliberate D2 decision (PR-derived
  branch name is the canonical source of truth). The practical implication:
  a working-tree state mishap (someone checked out main between Step 2 and
  Step 2.5; a hook somewhere did `git checkout`) doesn't break the rewrite —
  Step 2.5 doesn't read `git branch --show-current`. Step 2b's `git branch -D
"$FEATURE_BRANCH"` (which DOES depend on the variable from Step 2b's own
  `git branch --show-current`) is unaffected because Step 2b runs after Step
  2.5 and re-derives `FEATURE_BRANCH` from its own context.

- **Squash-merge SHA vs merge-commit SHA vs branch-tip SHA.** Per D3 / ROADMAP
  line 1447: `gh pr merge --squash` produces a single new commit on main;
  that commit's SHA is the canonical permanent reference. The branch-tip SHA
  from before the merge lands in reflog but is NOT reachable from main and
  may be GC'd. **Always use `mergeCommit.oid`**, never `headRefOid` /
  `commits[-1].oid` / `git rev-parse @{1}`. The BATS test asserts the SKILL
  prose names `mergeCommit.oid` specifically.

- **`gh pr view --json body` returns the body verbatim — including any
  trailing newline / whitespace.** The rewritten body, written back via `gh
pr edit --body-file -`, should preserve byte-identical whitespace EXCEPT
  for the URL substitutions. Use `--body-file` (file on disk) not `--body`
  (shell-arg, which adds a trailing newline). The helper writes to
  `<body-file-out>` exactly to support this contract.

- **Audit-log path uses `${GSTACK_HOME:-$HOME/.gstack}` — NOT hardcoded
  `~/.gstack`.** This is the same gotcha that `gstack-artifact-path-resolution`
  (PLAN.md row #3, scoped by Task 0) tracks for the wider SKILL.md surface.
  The backfill script ships its audit-write path correctly from the start
  (`/devshop/kit/scripts/backfill-pr-image-urls.sh` uses `${GSTACK_HOME:-$HOME/.gstack}`)
  so it doesn't add to the surface that future PR will fix.

- **Bundled-PR's run-against-lalista happens in Phase 5.5, before Phase 6
  audit comment, AFTER Phase 4 PR creation.** Per D7b. Doing it before PR
  creation would mean the backfill run isn't visible in the PR audit trail;
  doing it after Phase 6 would race with `/ak-go-live` Step 6's notify
  comment. Phase 5.5 is the correct slot. The backfill produces an
  operator-visible JSONL audit log artifact under `/workspace/.gstack/...`
  that the operator can inspect during Phase 5.5 review.

- **The `version: 1.4.0` bump on `ak-go-live/SKILL.md` is meaningful behavior
  change** — Step 2.5 is a new pipeline step that mutates PR bodies post-merge.
  Per the convention used elsewhere in `kit/tests/util-build-phase58-audit-parser.bats`
  (`build/SKILL.md's version was bumped to 1.7+ for the PR-B wiring`), the
  BATS suite asserts the version bumped. If a future PR adds another Step
  2.x sub-step, the version bumps again.

## Acceptance / rollout / rollback

### Track A acceptance (per ROADMAP § Track A acceptance, lines 1485–1488)

- `/ak-go-live` runs Step 2.5 between merge and cleanup; new PRs land with
  merge-SHA URLs in the body. Verified via the BATS content tests (Step 2.5
  exists between Step 2 and Step 2b, names `mergeCommit.oid`, etc.) and via
  the next post-this-PR `/ak-go-live` invocation showing the rewrite in its
  output.
- BATS test asserts the rewrite shape on a fixture PR body (branch URL → SHA
  URL). Covered by `rewrites a single feature-branch URL to merge-SHA URL`
  - the multi-URL + slashed-branch variants.
- Post-merge body diff shows the URL transformation; the dry-run preview is
  logged in `/ak-go-live`'s output for operator visibility (Step 2.5's stderr
  one-line summary `rewrote <N> URL(s)` is the audit trail).
- A non-image `/raw/<other-branch>/` URL elsewhere in the body is preserved
  verbatim. Covered by `preserves a /raw/<other-branch>/ URL` + `/raw/main/`
  - `/raw/<tag>/` BATS cases.

### Track B acceptance (per ROADMAP § Track B acceptance, lines 1490–1494)

- `--dry-run` exits 0 and shows the planned rewrites per PR. Covered by
  `default mode is dry-run` BATS case.
- Run against lalista's PR history (~50 closed PRs as of 2026-05-08): every
  closed PR with `/raw/<feature-branch>/` patterns gets repointed; spot-check
  3 random PRs to confirm images render. **This is Phase 5.5's deliverable**
  — the operator runs the script with `--accept-history-rewrite`, inspects
  the audit log, opens 3 random rewritten PRs in a browser, confirms hero
  shots load. Result captured in the PR's `## Pre-ship audit trail` comment.
- Run against devshop's own PR history (the devshop repo also accumulates
  PRs). **Deferred to a separate session AFTER this PR merges** — running
  the script against devshop's own merged PRs while this PR is itself
  mid-merge would be confusing (Phase 5.5 against devshop would rewrite
  devshop PR bodies, then this PR's merge would cause Step 2.5 to re-run on
  this PR — net result fine but the audit trail would interleave confusingly).
- Idempotent re-run on a project with no remaining branch-URL bodies is
  exit-0 no-op. Covered by `idempotent re-run on already-rewritten body is
all-skip` BATS case + asserted by Phase 5.5 spot-check (re-run with
  `--dry-run` after the mutating run; expect zero `dry-run-would-rewrite`
  outcomes).
- The audit log JSONL contains one row per PR with the before/after URL
  counts + outcome. Covered by `audit log JSONL is well-formed` BATS case +
  schema in § API contracts.

### Rollout

- Both tracks ship in this PR (per D7).
- Phase 5.5 runs the Track B backfill against lalista in this same session,
  after Phase 4 PR creation, with audit log captured under
  `/workspace/.gstack/backfill-pr-image-urls/<ts>.jsonl`.
- Track A activates on the NEXT `/ak-go-live` invocation (i.e., this PR's
  own merge — meta-validation: this PR's hero shots, if any, get rewritten
  by the very Step 2.5 it ships).
- Devshop's own merged-PR backfill is a separate operator-initiated run
  after this PR merges.

### Rollback

Revert this PR (`git revert <merge-sha>`).

- **Track A**: `/ak-go-live` Step 2.5 disappears; future PRs revert to
  shipping branch-URL bodies that 404 on `--delete-branch`. No corruption,
  no migration to undo — Step 2.5 is purely additive in the pipeline.
- **Track B**: the `backfill-pr-image-urls.sh` script disappears from
  `kit/scripts/`. The lalista PR-body mutations performed in Phase 5.5
  remain in place — they're correct rewrites pointing at permanent merge
  SHAs, not "data loss" to undo. If for some reason the operator wants to
  restore the original branch-URL bodies, the per-run JSONL audit log
  records the before-state at row level (PR number + url_count_before); the
  operator could write a small one-off script to walk that log and `gh pr
edit` each PR back to its original body. **Very low likelihood** — the
  rewrite is provably safe (SHA is permanent, URL paths preserved verbatim,
  spot-check confirms images render), so rollback of Track B's effect is
  not contemplated as a normal-operations path.
- The `--accept-history-rewrite` flag's gating + the script's idempotence
  together make accidental re-mutation low-risk: a re-run on a
  rewritten-PR-body is all-skips (no matching `/raw/<head-ref>/` URLs
  remain), so even a second invocation post-revert is a no-op.
