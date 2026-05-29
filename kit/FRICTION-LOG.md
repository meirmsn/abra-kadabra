# Friction Log

Intake ledger for recurring friction, trip-ups, and devshop-generalizable
lessons that sessions hit. This is the **funnel upstream of the backlog**: raw
friction lands here first (deduped + counted + session-linked), and the operator
promotes the items worth acting on into `kit/ROADMAP.md` (strategic),
`kit/TODOS.md` (tactical), or `PLAN.md` (scheduled) when appropriate.

**Why a separate ledger and not just TODOS:** TODOS/ROADMAP are commitments —
things we intend to do. This log is *observation* — things that keep going
wrong, whether or not we've decided to fix them. The count is the signal: an
item that recurs across many sessions earns promotion; a one-off may never need
it. Keeping observation separate from commitment stops the backlog from
filling with noise and stops real recurring pain from being forgotten.

## How to use it

- **File via `/ak-record-friction-log`** — the skill scans for an existing
  match BEFORE adding (so the same issue isn't filed twice), bumps the count +
  links the session when it matches, adds a new entry when it doesn't, re-sorts
  by score, and prints a notice if any entry now looks big/urgent/impactful.
  Don't hand-edit for routine filing — the scan-before-add step is the whole
  point and is easy to skip by hand.
- **Promotion is the operator's call.** When you decide an item is worth acting
  on, move it into `kit/ROADMAP.md` / `kit/TODOS.md` / `PLAN.md`, then set this
  entry's **Status** to `promoted → <tracker>` (keep the entry as the
  observation record; don't delete it — the count history is the evidence the
  promotion was earned). When the underlying fix actually ships, set Status to
  `resolved (<commit/PR>)` and unwind it per
  `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`.

## Entry schema

Each entry is one `### ` heading. Fields:

- **Score** — `impact × count` (the sort key; recomputed on every bump).
- **Impact** — 1–5 on the `PLAN.md` rating scale (XS=1, S=2, M=3, L=4, XL=5):
  the severity *if it recurs*, not the severity of one occurrence. One-line why.
- **Count** — number of distinct sessions that hit this. Bumped once per
  session (the Sessions list is the same-session dedup guard).
- **Status** — `open` | `promoted → <tracker §>` | `resolved (<ref>)`.
- **First seen** — date + session/commit ref.
- **Sessions** — append-only `YYYY-MM-DD <ref/one-line>` list; its length is
  the Count.
- **Symptom** — the one-line "how you notice it" (what a future session greps
  for to find a match).
- **Detail** — accumulated knowledge: mechanism, blast radius, candidate fix.
  Grows as sessions add what they learn; keep it the single best description,
  not a changelog.
- **Promotion target** — where it would go if promoted (so triage is a quick
  read, not a re-think).

## Ordering

Sorted by **Score descending** (impact × count), tie-broken by Impact desc, then
most-recently-seen. Highest-scoring friction is always at the top. `resolved`
entries sink to a `## Resolved` section at the bottom (kept for the history).

<!-- entries below, highest score first -->

## Open

### Phase 2 soft-reset silently re-anchors when origin/main moves mid-merge

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — a core merge skill can land phantom file deletions on
  `main`, silently reverting/deleting *another* feature's committed work.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`ak-build-commit-spec-expansion` merge, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` Phase 4.5 merge of `ak-build-commit-spec-expansion`; caught pre-push.
- **Symptom**: the Phase 2 squash commit shows `delete mode` for files that
  belong to a *different*, parallel feature (e.g. `specs/<other-feature>/…`) —
  files this branch never touched. Surfaces in the `git commit` output's
  create/delete listing, or via `git diff --diff-filter=D origin/main..HEAD`.
- **Detail**: `/ak-merge-devshop` Phase 1.0 rebases the branch onto `$ANCHOR`
  (origin/main at that moment), then Phase 2 **re-resolves `$ANCHOR=origin/main`
  live** and soft-resets onto it. If origin/main *advanced* between 1.0 and 2
  (a parallel merge pushed), Phase 2 anchors onto the **new** tip while the
  branch content still descends from the **old** one — so the staged squash
  delta phantom-deletes (and reverts) everything the new base added. The
  skill's "anchor-mismatch caveat" claims Phase 3's `git merge --ff-only`
  catches this, but it does **not**: the squash's parent *is* the new base, so
  the FF succeeds and lands the phantom deletions on main. Caught this session
  only by manual `--diff-filter=D` inspection before the push. **Recovery**:
  reset the branch to its pre-squash tip, re-merge/rebase onto the new
  origin/main (rebase hits the documented virtiofs phantom flake → `git merge`
  fallback), drop any now-stale tracker entries the parallel merge made
  obsolete, re-verify the full bats suite, re-squash. **Candidate fix**: in
  Phase 2, assert the soft-reset anchor's SHA equals the SHA Phase 1.0 rebased
  onto (capture it in 1.0, re-check in 2 and halt on mismatch), AND scan the
  staged delta for unexpected file-level deletions (`--diff-filter=D` outside
  the branch's own paths) before the squash commit.
- **Promotion target**: `kit/ROADMAP.md` (harden `/ak-merge-devshop` Phase 2
  anchor-drift guard) or `kit/TODOS.md`.

## Resolved

_None yet._
