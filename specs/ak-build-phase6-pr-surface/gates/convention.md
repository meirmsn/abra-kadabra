## Gate 11: convention

**Outcome:** pass (1 minor informational note — see Dismissals)

Devshop-self-mode convention check over `git diff origin/main..HEAD`. The change is
`/ak-build` Phase 6 prose (drop the gate-table audit comment per D1 + autonomous
Gate A per D2) + a cross-reference sweep (D3) + bats coverage.

### Structural conventions (devshop-mode.md § Gate 11)

- **SKILL.md frontmatter** — n/a. No skill frontmatter touched; all SKILL.md edits
  are body prose (Phase 6 region of `build/SKILL.md` + sibling cross-reference fixes
  in `docs-review`, `go-live`, `pre-ship`, `spec`, `tests-review`). Verified the diff
  touches no `---`-delimited frontmatter block.
- **Shell-script structure** — n/a. No `kit/scripts/**` files changed (diff confirms;
  the only `.sh` mentions in the diff are prose references to existing helpers).
- **Guide-doc routing index** — n/a. No NEW guide doc added. `claude-md.md`,
  `conventions.md`, `workflow.md` were edited in place; all three are already linked
  in `kit/docs/guide/README.md`. The only added files are `specs/<feature>/{spec,tasks}.md`
  (per-feature artifacts, not guide docs).
- **Bats coverage for new scripts** — n/a (no new scripts). Separately confirmed the
  test surface is covered: `kit/tests/util-product-update-blurb.bats` rewrites the
  Gate-A assertion to the autonomous 3-way contract and adds two new assertions
  (escalation-is-only-prompt; Phase 6 posts no `gh pr comment`). Ran
  `kit/tests/lib/bats-core/bin/bats kit/tests/util-product-update-blurb.bats` — **39/39 pass**.

### Cleanup-completeness (CLAUDE.md § Closing TODO/ROADMAP entries — unwind cross-refs)

The core risk for this feature (per its own § Gotchas) is a partial sweep that leaves
a dangling "Phase 6 posts a comment" reference re-seeding the contradiction. Verified:

- `awk '/^## Phase 6/,/^## Phase 7/' build/SKILL.md | grep 'gh pr comment'` → **no match**.
  Phase 6 posts nothing; Parts A/B retain only `gh pr edit --body-file` body-fix calls
  (legitimate, distinct verb).
- Repo-wide `grep -nE 'audit comment|audit-trail comment|Post audit trail comment'`
  over SKILL.md + guide docs: the surviving hits are all in `workflow.md § Step 2.5`
  backfill prose, correctly reframed to reference **legacy / historical** comments on
  PRs that pre-date the removal ("on PRs that pre-date the comment's removal" /
  "current /ak-build no longer posts them"). These are accurate, not dangling — they
  describe the backfill script's coverage of old PRs, not current Phase 6 behavior.
- Sibling docs reframed consistently: `conventions.md` (PR body structure + Product-update
  style) now says Gate A verifies autonomously, operator only on a genuine product-judgment
  mismatch; `claude-md.md` medium-severity now "recorded in review.md at Phase 6";
  `FAQ.md` + `OVERVIEW.md` hero/path embeds at Phase 4.1, Phase 6 verifies; `workflow.md`
  diagram label + HUMAN REVIEW line + devshop-mode summary all reframed. Matches the
  D3 cross-reference list in the spec.

### Commit + PR text style (CLAUDE.md § Commit + PR text style)

8 commits on the branch. Subjects are conventional-commit-typed and describe the
observable change (`refactor: drop Phase 6 audit-trail PR comment`,
`feat: autonomous Phase 6 Gate A PR-description review`, etc.). Bodies open with a
one-sentence TL;DR + bullets at user-meaningful grain — correct raw material for the
eventual `/ak-merge-devshop` squash (bold-led-bullet shape). Seven of eight subjects
are ≤72 chars; one is 73 (1 over). See Dismissals.

The squash shape will be appropriate: the per-commit bodies already carry the
bullet-led detail the squash body aggregates; the squash subject (composed at
merge time) is what reaches `main`, so the 73-char per-commit subject does not
survive to the durable `git log`.

### Tracker-closure timing

The `kit/ROADMAP.md` + `PLAN.md` entries for this feature are still present (added by
the planning commit `293746e`). This is **not** a convention violation at Gate 11:
ROADMAP/PLAN closure is owned by Phase 4.0 (BUILD-LOG + PLAN closure), which is a
later, still-pending pipeline phase. Flagging here only so Phase 4.0 remembers to
delete both rows in the closing commit.

## Dismissals

- **Commit subject 1 char over ≤72** — `docs: align Gate A operator-verification
  framing with autonomous behavior` is 73 chars. Dismissed as a non-blocking minor
  note: (a) it's already committed history, so fixing it requires a non-interactive
  rebase to amend a single doc commit; (b) `/ak-merge-devshop` squashes this branch,
  so the per-commit subject never reaches `main`'s `git log` — the squash subject
  (composed fresh at merge time, where the ≤72 rule actually binds) is the durable
  artifact. Rewriting history for a 1-char overage on a soon-squashed commit is not
  worth the churn. Noted for awareness; no fix applied.
- **ROADMAP/PLAN entries still present** — n/a per phase ownership. Closure is Phase
  4.0's job (still pending), not Gate 11's. See § Tracker-closure timing.
- **`audit comment` strings still in workflow.md** — n/a. All surviving hits correctly
  describe legacy/historical comments on pre-removal PRs (backfill-script scope), not
  current Phase 6 behavior. Verified each in context.
