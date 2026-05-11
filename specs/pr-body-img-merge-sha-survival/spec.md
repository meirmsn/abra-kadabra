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

**Decision:** Per ROADMAP § Track B: `--dry-run` (default), `--accept-history-rewrite` (required to mutate), `--owner` / `--repo`, `--limit N`, `--since <date>`. JSONL audit log per-run. Skip PRs where `headRefName` is empty. Skip PRs whose body was edited post-merge (heuristic: `updatedAt > mergedAt + 5min`).

**Rationale:** ROADMAP § Track B § Safety notes; explicit `--accept-history-rewrite` forces operator acknowledgement; post-merge-edit heuristic avoids clobbering manual fixes the operator already applied.

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
