## Gate 1: docs-check

**Verdict: pass.**

The diff is a SKILL.md-internal mechanics change (new Phase 1.1 commit step +
resume-check reads tightened to committed state), plus bats assertions and a
`kit/TODOS.md` routing entry. Verified that no reference doc beyond SKILL.md
itself describes Phase 1's artifacts/commits at a grain that the change makes
stale.

### What was checked

Grepped `kit/docs/guide/*.md`, `kit/docs/OVERVIEW.md`, and `CLAUDE.md` for
references to Phase 1 / "expand spec" / spec.md commits / "Task order" /
"skeleton commit" / Phase 0.3. Inspected every hit that touches the /ak-build
spec pipeline:

- **`kit/docs/guide/workflow.md`** — the canonical pipeline description.
  - ASCII diagram Phase 0 box (lines 58-59) and Phase 1 box (lines 64-68)
    describe Phase 1 as "expands in place → full spec … flips PLAN.md row
    Planned → Active." It does NOT enumerate per-phase commits. The new Phase
    1.1 commit step is below this grain; the box stays accurate.
  - Prose (lines 210-221): "reads the Phase 0 skeleton and expands it in place
    into a full spec … The `## Task order` section is the discriminator the
    resume check uses to tell 'skeleton' from 'complete spec.'" Still accurate
    — `## Task order` remains the discriminator. The change only moves *where*
    the resume check reads it from (committed `spec.md` via `git show HEAD:`
    rather than the working tree); workflow.md never specified the read source,
    so no sentence is falsified. No edit required.
  - Other Phase-1 hits (lines 487-488, the `/ak-merge-devshop` /
    `/ak-sync-from-devshop` rows) refer to those skills' own internal "Phase 1"
    numbering, unrelated to /ak-build's spec phase.

- **`kit/docs/OVERVIEW.md`** line 278 — describes `spec.md` as "seeded by
  /ak-build Phase 0 as a Decisions skeleton, expanded by /ak-spec into the full
  spec." High-grain artifact description with no commit-granularity claim. Not
  made inaccurate by adding a Phase 1.1 commit. No edit required.

- **`CLAUDE.md`** — no pointer to Phase 1's commit behavior or the resume
  discriminator's read source. The closest reference ("Pipeline path (Phase 4.1
  → Phase 6 Part D verification)") is unrelated. No edit required.

- **`kit/docs/guide/hooks.md`, `conventions.md`, `architecture.md`,
  `ops.md`** — Phase-1 hits all refer to other skills' phase numbering or to
  CI slow-job phases, none to /ak-build's spec-commit behavior. Untouched by
  this change.

### Self-documentation within the diff

The SKILL.md change is self-consistent: the new `### 1.1: Commit the expanded
spec` subsection, the Phase-exit artifact registry row 1 (Producer flipped to
"Phase 1.1 (commit step)", check shape `git show HEAD:… | grep`), resume rungs
4/5, and the discriminator paragraph (lines 325-328) were all updated together,
so the SKILL.md cross-references stay coherent.

### Tracker entry

`kit/TODOS.md` gained one routing entry (pre-existing `structural-invariants.bats`
wiring failure surfaced during the full-sweep) — correct TODO-protocol routing,
not a doc-coverage gap. The TODOS entry this PR closes ("/ak-build Phase 1
doesn't commit the expanded spec.md") is slated for removal in Phase 4.0
bookkeeping, per gate instructions — not flagged here.

## Dismissals

None.
