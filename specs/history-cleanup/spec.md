<!-- generated-by: /ak-build Phase 0 (skeleton) -->
<!-- feature: history-cleanup -->
<!-- date: 2026-05-11 -->

# Spec: history-cleanup (convention-drift backfill)

**Sources:**

- `BUILD-LOG.md` — current state: 7 entries, oldest is `cheap-test-gates-local (2026-05-06)` corresponding to v1.25.0; everything between v1.22.0 and v1.25.0 is unrecorded.
- `kit/ROADMAP.md` — v0 section has 6 entries explicitly tagged `[SHIPPED]` or `_shipped DATE_` that pre-date the closure protocol.
- `kit/TODOS.md` — 18 `[x]` entries with verbose "Original entry preserved below for context" trailing blocks; pre-dates the no-strikethrough closure rule in `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`.
- `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` — defines the post-cleanup convention.
- Operator framing: one-shot history-fix, ~3-4 h; forward-going discipline is healthy (every ship from v1.26.0 onward hits BUILD-LOG cleanly via `/ak-build` Phase 5.6).

One-shot housekeeping: backfill the missing BUILD-LOG history, sweep the shipped v0 ROADMAP entries, purge the `[x]` TODOS that should have been deleted on closure. No code, no tests.

---

## Decisions (resolved at spec time)

7 `/ak-spec`-time decisions resolved in Phase 0 with the operator.

### D1: Backfill entry format

**Decision:** Minimal shape — `PR`, `Summary`, `Commits`, `Note: Historical backfill`. Skip `Spec`, `Branch`, and `Quality gates` rows when the PR predates `/ak-build` adoption (most pre-v1.25.0 PRs).

**Rationale:** The full `/ak-build` shape requires `specs/<feature>/review.md` audit data — fabricating that would be worse than no row at all. The minimal shape preserves traceability (PR# + SHA) without inventing audit history.

### D2: Grouping policy

**Decision:** One entry per coherent feature, combining PRs where the diffs were one logical ship (e.g., `ak-check-docs-and-tests` = PR-A + PR-B + PR-C + post-polish; manifest-driven hooks = PRs #12 + #14 + #15).

**Rationale:** Mirrors how `/ak-build` entries already work — one feature = one BUILD-LOG entry, even when it lands over many commits.

### D3: ROADMAP delete set

**Decision:** Delete the 6 entries explicitly tagged `[SHIPPED]` or `_shipped DATE_` at lines 1088, 1207, 1256, 1306, 1329, 1579 of `kit/ROADMAP.md`.

**Rationale:** Closure protocol in `/devshop/CLAUDE.md` is unambiguous: shipped entries get deleted, not strikethrough. These 6 are the unambiguous closure-eligible set. Other v0 entries (e.g. `### Move adversarial Layer 2 reviews from per-commit to audit-time` at line 16) describe completed work but are followed by long audit-log sections that still serve as reference — those are left alone for this pass.

### D4: TODOS delete set

**Decision:** Delete all 18 `[x]` entries + their "Original entry preserved below" trailing blocks.

**Rationale:** Same closure protocol — git log + PR description are the audit trail. The "preserved below for context" pattern is the retired legacy.

### D5: PR shape

**Decision:** Single PR, three atomic commits (BUILD-LOG / ROADMAP / TODOS).

**Rationale:** Pure history cleanup, no inter-file dependencies; reviewer can scrub each commit independently. Also keeps the PR diff scannable.

### D6: Branch name

**Decision:** `chore/history-cleanup`.

**Rationale:** Matches "convention drift cleanup" framing; `chore:` prefix correctly classifies the docs-only work.

### D7: Skip full /ak-pre-ship subagent

**Decision:** Yes. Run BATS suite + convention check directly in the main context; skip the full 13-gate `/ak-pre-ship` invocation.

**Rationale:** ~9/13 gates (typecheck, build, /qa, /design-review, /benchmark, /cso, /simplify, hero shots, responsive+theme) are structural N/As for docs-only PRs. The subagent overhead doesn't pay back when the gate matrix collapses to 4 relevant gates.

---

## In scope

- Append 12 retroactive entries to `BUILD-LOG.md` below the current oldest (`cheap-test-gates-local`).
- Delete 6 v0 entries from `kit/ROADMAP.md`.
- Delete 18 `[x]` entries from `kit/TODOS.md`.

## Out of scope

- Forward-going BUILD-LOG discipline (already healthy).
- v1 ROADMAP entries (different cadence; no closure protocol audit for v1 yet).
- Active `[ ]` TODOS entries.

## Files to modify

- `BUILD-LOG.md`
- `kit/ROADMAP.md`
- `kit/TODOS.md`

## Task order

1. BUILD-LOG backfill (12 entries)
2. ROADMAP v0 shipped-entry sweep (6 deletes)
3. TODOS `[x]` purge (18 deletes)

## Tests

- BATS suite (`kit/tests/`) must stay green — none of the files touched are test fixtures, so this is a no-op safety check.
- No new tests added (history cleanup; nothing to assert).

## Dependencies

- None.

## Acceptance / rollout / rollback

- Acceptance: PR diff renders cleanly; CI green; reviewer can scan each of the three commits independently.
- Rollout: standard squash-merge to main via `/ak-merge-devshop`.
- Rollback: `git revert` on the squash commit; no state outside git is affected.
