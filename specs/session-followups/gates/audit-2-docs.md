# Audit 2 — Docs Review

**Range**: `073b048..HEAD` (2 commits: `f71f0a6`, `ce549ad`)
**Feature dir**: `specs/session-followups`
**Mode**: devshop self-mode (`$GIT_ROOT == /devshop`)

---

## Scope of diff

```
 kit/tests/structural-invariants.bats           |  32 +++--
 kit/tests/util-ak-merge-devshop.bats           |  48 ++++++-
 specs/session-followups/gates/audit-1-docs.md  |  82 ++++++++++++
 specs/session-followups/gates/audit-1-tests.md | 170 ++++++++++++++++++++
 specs/session-followups/review.md              |  22 ++++
 5 files changed, 335 insertions(+), 19 deletions(-)
```

Two commits in range:

- `f71f0a6 fix(tests): close 3 Audit-1 findings` — repairs the broken E5 test (now if-then-fail shape, scoped to `vitest.config.ts` only); splits the Phase 3 source-worktree OR-grep into 3 independent `grep -q` calls (mirrors Phase 4.2 shape); adds 3 Phase 0.1 guard-predicate coverage tests (path-not-exists, on-main-or-detached, no-commits-ahead). Net `-19 +29` lines in two `.bats` files.
- `ce549ad docs(session-followups): Audit 1 trail` — scaffolds `review.md` + 2 audit sinks under `specs/session-followups/gates/`. Audit-trail commit; no source surface.

No source code under `kit/scripts/**`, `kit/hooks/**`, `template/**`, `.devcontainer/**`, or `.claude/skills/**/SKILL.md` was touched in this range. The `.claude/skills/devshop/merge-devshop/SKILL.md` referenced by the new tests is *grepped against*, not edited.

---

## Section A — Coverage

Per the devshop surface→doc rubric, the surfaces touched in this diff are:

| Surface path                                              | Required doc?                                              | Status                                                                                   |
| --------------------------------------------------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `kit/tests/**` (structural-invariants + util-ak-merge-devshop) | **Carve-out** — `kit/tests/**` does not fire docs coverage | n/a                                                                                      |
| `specs/session-followups/**`                              | **Carve-out** — `specs/**` audit-artifact, not source       | n/a                                                                                      |

No `kit/scripts/**.sh`, `kit/scripts/commit-hooks/**`, `kit/scripts/preship/**`, `kit/hooks/**`, `.claude/skills/**/SKILL.md`, `template/**`, `.devcontainer/**`, or `kit/manifest.txt` was touched. The rubric returns zero required doc surfaces — this is a test-only + audit-trail-only range.

No `Docs-Coverage-Bypass:` trailers expected for a carve-out range; none harvested. (Section D below confirms.)

**Section A findings**: none.

---

## Section B — Adequacy

No reference docs were touched in this range (CLAUDE.md, `kit/docs/OVERVIEW.md`, `kit/docs/guide/*.md`, `kit/docs/FAQ.md`, `README.md` are all unchanged). Adequacy of *touched* reference docs cannot be evaluated — there are none.

The two new `.bats` tests carry inline `#`-comment rationale (Phase 0.1 guards explain "First of three guard predicates — the path must exist as a directory…" etc.; Phase 3 split explains "Three independent `grep -q` calls (NOT a single OR) so any missing dimension fails the test…"). These are test-file comments, not reference-doc claims, so the "named-section claims verified by grep" rubric doesn't apply. The comments are accurate to the source they describe — confirmed against `.claude/skills/devshop/merge-devshop/SKILL.md § 0.1` (`! -d "$SOURCE_WORKTREE_ARG"`, `[ -z "$BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]`, `AHEAD -eq 0` predicates all present).

The `audit-1-{docs,tests}.md` and `review.md` artifacts are audit-trail records — they describe *findings*, not project state. They correctly attribute the closing commit (`f71f0a6`) to each finding and describe the fix shape applied. Audit-trail accuracy is verifiable: `review.md` says "split into 3 independent grep-q calls" — the diff at `kit/tests/util-ak-merge-devshop.bats:131-150` does exactly that. `review.md` says "added 3 new tests pinning path-does-not-exist refusal + on-main-or-detached refusal + no-commits-ahead refusal" — bats output `ok 12 / 13 / 14` confirms the three named tests run and pass.

**Section B findings**: none.

---

## Section C — Cross-doc coherence

No renamed or deleted files in the range (`git diff --name-status --diff-filter=DR 073b048..HEAD` returns empty — all five entries are `M` or `A`). No reference doc was touched, so cross-doc-contradiction checks (touched doc vs untouched doc) have nothing to compare.

The audit-trail artifacts under `specs/session-followups/gates/` describe behavior in `.claude/skills/devshop/merge-devshop/SKILL.md` (Phase 0.1 + Phase 3) and `template/packages/core/{vitest.config.ts,src/index.ts}` (placeholder leak shape). Spot-checks:

- `audit-1-tests.md` line 19: "Barrel export for @PROJECT_NAME_PLACEHOLDER/core" — confirmed against `template/packages/core/src/index.ts:1` (the legitimate placeholder substituted at scaffold time by `/ak-new-project § Step 10`'s sed).
- `audit-1-tests.md` line 124: "`[ "$BRANCH" = "main" \| "master" ]` — wrong-branch refusal" — confirmed against `.claude/skills/devshop/merge-devshop/SKILL.md § 0.1` line 32 (`[ -z "$BRANCH" ] || [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]`).
- `review.md` line 16 names commit `c810c39` as the prior commit that fixed `vitest.config.ts`'s header. This is a historical reference — not verified at the audit-trail level, but the trail consistently attributes it the same way.

**Section C findings**: none.

---

## Section D — Bypass trailer audit

```bash
$ git log --format='%H%n%B%n---' 073b048..HEAD | grep -E 'Docs-Coverage-Bypass:'
# (zero matches)
```

No `Docs-Coverage-Bypass:` trailers in range. Section D is empty.

---

## Section E — CLAUDE.md hygiene

**Skipped** — devshop self-mode (Section E applies to project mode only, per the skill: "Mode: project (skip in devshop mode). Reads ALL of current CLAUDE.md…"). Devshop's CLAUDE.md hygiene is governed by the per-commit `docsReviewed` reviewer + the `kit/docs/guide/claude-md.md § What CLAUDE.md typically contains` taxonomy, exercised at every commit, not at audit time.

For the record: `/devshop/CLAUDE.md` was NOT touched in this range.

---

## Verification of Audit 1 closures

Audit 1 (`specs/session-followups/review.md § Audit 1`) carried zero docs findings (`### Docs findings — (none)`). There is no docs work to verify closed at Audit 2.

---

## Summary

- Section A (coverage): 0 findings — test-only + audit-trail range, no surface→doc rubric fires.
- Section B (adequacy): 0 findings — no reference docs touched.
- Section C (coherence): 0 findings — no renames/deletes; audit-trail prose verified against source.
- Section D (bypass): 0 trailers in range.
- Section E (CLAUDE.md hygiene): skipped per devshop self-mode.

Clean — no docs findings.

---

## Tally

`high=0 medium=0 low=0`
