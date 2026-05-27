<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: merge-devshop-rename-detect -->
<!-- date: 2026-05-26 -->

# Spec: merge-devshop-rename-detect

**Sources:**

- `kit/TODOS.md` § `/ak-merge-devshop` Phase 2: detect rename-plus-symlink-at-old-path combo and fallback to ff-merge — primary scope
- `kit/TODOS.md` § lint-staged stash backup chokes on rename + new-symlink-at-old-path — companion entry (root cause)
- `.claude/skills/devshop/merge-devshop/SKILL.md` § Phase 2 + § Known limitations — edit targets
- `kit/tests/util-ak-merge-devshop.bats` — existing test coverage reference
- Prior spec `specs/sync-show-first-confirm/spec.md` — style + structure reference

Auto-detect rename-plus-symlink combos in `/ak-merge-devshop` Phase 2 that would crash lint-staged's stash backup, and offer a clean ff-merge fallback instead of failing mid-squash.

---

## Product update

### Headline (user-facing)

The devshop merge skill now auto-detects rename-plus-symlink combos that would crash lint-staged, and offers a clean ff-merge fallback instead of failing mid-squash.

### Detail (team-facing)

`/ak-merge-devshop` Phase 2 gains a pre-commit detection step: after `git reset --soft` stages the squash delta, scan `git diff --cached --name-status` for `R<sim> OLD → NEW` + `A OLD` collisions. On hit, unstage (`git reset`), surface the issue, and offer `git merge --ff-only` as the fallback — same file-system end state, N separate commits instead of 1 squash. Known limitations section updated from "manual recovery" to "auto-detected".

---

## Decisions (resolved at spec time)

4 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Detection location

**Decision:** Phase 2 prose (inline in SKILL.md), not a standalone script under `kit/scripts/`.

**Rationale:** The TODOS entry names `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2` as the edit target. The skill prompt is where the LLM reads the procedure; a standalone script would need the LLM to know about it, doubling the surface for no gain.

### D2: Operator interaction on detection

**Decision:** Prompt the operator with an explanation + ff-merge offer, not auto-fallback.

**Rationale:** TODOS entry says "on the operator's confirmation, run `git merge --ff-only`." The ff-merge produces a different history shape (N commits instead of 1 squash) — the operator should know and confirm.

### D3: Detection timing within Phase 2

**Decision:** After `$GIT_CMD reset --soft "$ANCHOR"` stages the delta, before `$GIT_CMD commit`. Scan `git diff --cached --name-status`.

**Rationale:** Phase 2 currently does rebase → soft-reset → commit. The rename+symlink combo surfaces when the staged delta includes both `R OLD → NEW` and `A OLD`. Scanning after soft-reset but before commit catches it at the right moment — the delta is staged and inspectable, but no commit has been attempted yet.

### D4: Known limitations section update

**Decision:** Rewrite from "tracked as a TODO" to "detected automatically — skill falls back to ff-merge on operator confirmation."

**Rationale:** The section already documents the combo and the manual recovery recipe. Keep the recipe for context but note the skill now handles it inline.

---

<!-- Phase 1 expansion follows. Provenance header, Sources, feature one-liner,
     Product update, and Decisions sections above are verbatim from Phase 0. -->

## In scope

- **Detection block in SKILL.md Phase 2**: after `$GIT_CMD reset --soft "$ANCHOR"` stages the squash delta but before `$GIT_CMD commit -F`, scan `git diff --cached --name-status` for `R<sim>` (rename) entries whose source path also appears as an `A` (added) entry. A collision means the staged delta contains a rename-plus-symlink-at-old-path combo.
- **On detection — unstage + surface + offer ff-merge fallback**: run `$GIT_CMD reset` to unstage, print a one-screen explanation of the lint-staged stash bug and why the squash cannot proceed, and offer `git merge --ff-only $BRANCH` as the alternative (same file-system end state, N separate commits instead of 1 squash). Proceed only on operator confirmation (D2).
- **Update `## Known limitations § Rename + symlink-at-old-path combo`**: rewrite from "tracked as a TODO / operator does the dance manually" to "detected automatically — skill falls back to ff-merge on operator confirmation." Keep the recovery recipe as historical context.
- **Bats content-validation tests**: new section (L) in `kit/tests/util-ak-merge-devshop.bats` verifying the SKILL.md prose contains the detection block's required elements.

## Out of scope

- Fixing the underlying lint-staged stash bug (separate TODOS entry, root-cause in git plumbing).
- Behavior tests (running the LLM end-to-end) — bats tests are content-validation only, consistent with sections A-K.
- Changes to the squash commit message format or any other Phase 0/1/3/4/5 behavior.

## Files to create/modify

| File | Change type | What changes |
|------|------------|--------------|
| `.claude/skills/devshop/merge-devshop/SKILL.md` | edit | Phase 2: insert detection block between `$GIT_CMD reset --soft "$ANCHOR"` and `$GIT_CMD commit -F`. Update `## Known limitations § Rename + symlink-at-old-path combo` prose. |
| `kit/tests/util-ak-merge-devshop.bats` | edit | Add section L with content-validation tests for the rename-detect prose. |
| `kit/TODOS.md` | edit | Close the `/ak-merge-devshop Phase 2: detect rename-plus-symlink` entry (mark done or delete per convention). |

## Tests

All tests are **content-validation** (grep SKILL.md for required prose/commands), matching the existing A-K section style in `kit/tests/util-ak-merge-devshop.bats`.

### Section L — Phase 2 rename-plus-symlink detection

| Test name | What it greps for |
|-----------|-------------------|
| `Phase 2 has a rename-plus-symlink detection block between soft-reset and commit` | The detection block exists in the Phase 2 section (between `reset --soft` and `commit -F`); verify ordering by line number. |
| `Phase 2 detection scans git diff --cached --name-status for R (rename) entries` | `git diff --cached --name-status` with `--diff-filter=R` or equivalent rename-filtering logic appears in Phase 2. |
| `Phase 2 detection compares rename source paths against A (added) entries` | Both `--diff-filter=R` and `--diff-filter=A` (or equivalent) appear; `comm -12` or similar set-intersection logic present. |
| `Phase 2 detection unstages on hit via git reset (not git reset --hard)` | On detection, the block runs `$GIT_CMD reset` (soft unstage), NOT `$GIT_CMD reset --hard` (which would destroy working tree). |
| `Phase 2 detection surfaces the lint-staged stash bug explanation` | The detection output references `lint-staged` and `beyond a symbolic link` (the actual git error message). |
| `Phase 2 detection offers git merge --ff-only as fallback` | `git merge --ff-only` appears in the detection block's operator-facing output. |
| `Phase 2 detection requires operator confirmation before ff-merge (not auto-fallback)` | `AskUserQuestion` or equivalent interactive prompt appears in the detection flow (per D2). |
| `Known limitations section notes rename-plus-symlink is now auto-detected` | The `## Known limitations` section contains language indicating automatic detection (e.g. "detected automatically", "auto-detect"). |
| `Known limitations section preserves the recovery recipe` | The `## Known limitations` section still contains the `git reset` + `git merge --ff-only` recovery recipe (historical context). |

## Task order

1. **Edit SKILL.md Phase 2 — insert detection block.** Between the `$GIT_CMD reset --soft "$ANCHOR"` line and the `$GIT_CMD commit -F` line, add a detection block that:
   - Runs `git diff --cached --name-status --diff-filter=R` via `$GIT_CMD` to extract rename source paths.
   - Runs `git diff --cached --name-status --diff-filter=A` via `$GIT_CMD` to extract added paths.
   - Computes the intersection (rename source paths that also appear as added paths).
   - On empty intersection: proceed to `$GIT_CMD commit -F` as before.
   - On non-empty intersection: run `$GIT_CMD reset` to unstage, print explanation (lint-staged stash bug, the actual error message `beyond a symbolic link`, why squash cannot proceed), and use `AskUserQuestion` to offer the ff-merge fallback (`git merge --ff-only $BRANCH`). On operator confirmation, execute the ff-merge path and skip the rest of Phase 2's commit. On cancel, abort.

2. **Edit SKILL.md Known limitations — update rename+symlink section.** Rewrite the opening paragraph from "tracked as a TODO" / "operator does the dance manually" to "detected automatically by Phase 2 — the skill unstages and offers ff-merge on operator confirmation." Keep the detection recipe and recovery recipe as reference context. Remove the forward-pointer to `kit/TODOS.md` since the entry will be closed.

3. **Edit bats tests — add section L.** Add section L to `kit/tests/util-ak-merge-devshop.bats` with the 9 content-validation tests from the Tests section above. Follow the existing section style: section comment header, `@test` blocks that `awk` a section range from `$SKILL_FILE` and `grep -q` for required patterns.

4. **Close TODOS entry.** Delete or mark done the `/ak-merge-devshop Phase 2: detect rename-plus-symlink` entry in `kit/TODOS.md`. The companion `lint-staged stash backup chokes on rename` entry stays open (root-cause fix is out of scope).

## Gotchas

- **`$GIT_CMD` routing is load-bearing.** Every `git diff --cached` and `git reset` in the detection block MUST go through `$GIT_CMD` (which expands to `git -C "$WORKTREE_PATH"` when the feature branch lives in a linked worktree). Hardcoding `git` would scan `/devshop`'s index (which is on `main`) instead of the worktree's staged delta.
- **`--diff-filter=R` returns similarity-scored renames (`R100`, `R095`, etc.).** The `awk` extraction must handle the variable-width `R<sim>` prefix — don't assume a fixed column count. The TODOS entry's recipe uses `awk '{print $2}'` which works because `--name-status` output for renames is `R<sim>\tOLD\tNEW` (tab-separated, three fields).
- **Detection fires after soft-reset, not after rebase.** The rebase incorporates upstream commits; the soft-reset is what stages the full squash delta. Scanning after rebase but before soft-reset would miss renames that only appear in the collapsed delta.
- **The ff-merge fallback skips Phase 2's commit entirely.** When the operator confirms ff-merge, the skill should jump to Phase 3 (which already handles `git merge --ff-only`). The squash message at `/tmp/squash-message-${FEATURE}.txt` becomes unused — note this in the operator-facing explanation.
- **Phase 2's existing rename+symlink paragraph at the bottom** ("If the rename+symlink-at-old-path combo from § Known limitations fires...") should be updated or removed since the detection now happens inline rather than as a post-hoc recovery.
- **Bats tests grep Phase 2 via `awk '/^## Phase 2:/,/^## Phase 3:/'`** — the detection block must land inside this range to be testable with the existing section-extraction pattern.

## Acceptance

1. **Bats tests pass**: `bats kit/tests/util-ak-merge-devshop.bats` exits 0 with all section L tests green.
2. **Existing tests unbroken**: sections A-K still pass (the Phase 2 edits don't remove any prose they depend on).
3. **SKILL.md Phase 2 prose review**: the detection block is positioned between `$GIT_CMD reset --soft "$ANCHOR"` and `$GIT_CMD commit -F`; uses `$GIT_CMD` throughout; offers ff-merge with operator confirmation.
4. **Known limitations section reads as "auto-detected"**: no "tracked as a TODO" language; recovery recipe preserved for context.
5. **TODOS entry closed**: the `/ak-merge-devshop Phase 2: detect rename-plus-symlink` checkbox is gone from `kit/TODOS.md`.
