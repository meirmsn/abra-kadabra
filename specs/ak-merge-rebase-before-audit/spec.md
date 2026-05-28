<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: ak-merge-rebase-before-audit -->
<!-- date: 2026-05-28 -->

# Spec: ak-merge-rebase-before-audit (devshop)

**Sources:**

- `kit/TODOS.md § /ak-merge-devshop audits before rebasing` — primary scope + fix options + worked incident
- `PLAN.md` Active row `ak-merge-rebase-before-audit` — scope summary + source pointer
- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1` + `§ Phase 2` — the code being restructured
- `.claude/skills/ak-check-docs-and-tests/SKILL.md § Step 2` — the audit's range-computation (the consumer that produces phantom findings)
- Prior shipped spec `specs/ak-merge-devshop-hardening/spec.md` — style + structure reference

`/ak-merge-devshop` rebases the feature branch onto its merge target **before**
running the Phase 1 docs+tests audit, so a stale-base worktree is no longer
audited against a diverged two-dot range that manufactures phantom revert
findings.

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — `/ak-merge-devshop`'s
squash-commit composer (Phase 0.3) reads this section; `/ak-build` Phase 4.0 copies
Headline → BUILD-LOG `Headline:` and Detail → `Summary:`.

### Headline (user-facing)

Merging a devshop branch whose base has fallen behind `main` no longer
produces bogus "this reverts X" findings in the pre-merge audit — the merge
runs clean instead of stalling on a phantom blocker.

### Detail (team-facing)

`/ak-merge-devshop` now rebases the feature branch onto its merge target (the
same `$ANCHOR` the squash lands on) **before** the Phase 1 `/ak-check-docs-and-tests`
audit, and audits the precise `$ANCHOR..HEAD` delta. Previously the audit ran
on the un-rebased branch against the default `origin/main..HEAD` two-dot range;
when the branch was created off an older `main` (common for a worktree that has
sat through a few merges), `origin/main` was not an ancestor of the branch tip,
so everything that had landed on `main` since the branch point surfaced as
phantom deletions/reverts. That wasted an audit cycle (two agent dispatches) and
risked the operator aborting a valid merge on a finding that read like a serious
blocker.

---

## Decisions (resolved at spec time)

5 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Where does the rebase go?

**Decision:** Introduce a new sub-step **Phase 1.0: Rebase onto the merge
target**, run before the audit (which becomes Phase 1.1). The `## Phase 1`
heading is renamed "Rebase + audit". Phase numbers 2 / 2.5 / 3 / 4 / 5 stay
fixed. The rebase is placed **after** the Phase 0.5 approval gate so nothing
mutates the branch before the operator approves the merge.

**Rationale:** Implements the recommended fix (a) — rebase ahead of audit.
Keeping "Phase 1 = rebase + audit" preserves the many cross-references to
"Phase 1 (audit)" in `workflow.md`, `devshop-mode.md`, `hooks.md`,
`conventions.md`, and `architecture.md`. Doing the rebase post-approval keeps
Phase 0's "non-destructive preview" design principle intact.

### D2: What range does the audit use after the rebase?

**Decision:** Phase 1.1 passes an explicit `--range "$ANCHOR..HEAD"` to
`/ak-check-docs-and-tests` (where `$ANCHOR` is the anchor Phase 1.0 rebased
onto — `origin/main` normally, or local `main` when an unpushed release sits
on local main).

**Rationale:** Audits exactly the delta the squash will introduce to main —
literally "the base the squash lands on," which is the PLAN row's stated intent.
Correct in both the common case (`$ANCHOR` = origin/main → range = origin/main..HEAD)
and the in-flight-release case (`$ANCHOR` = local main → range excludes the
unpushed release commit). The audit skill already supports `--range <SHA>..HEAD`
and its idempotence stamp (`audited-at: HEAD`) is unaffected.

### D3: How does Phase 2 obtain `$ANCHOR` once the rebase moved out?

**Decision:** Phase 2 re-runs the same deterministic anchor-detection block
(the `git rev-list --count origin/main..main` check) to set `$ANCHOR` for its
`reset --soft "$ANCHOR"`. Phase 2 no longer rebases.

**Rationale:** Orchestrator bash blocks don't share variables across tool calls;
the detection is idempotent given live git state, so recomputation yields the
same anchor Phase 1.0 used (barring a `main` move between phases — a single-dev
devshop edge that Phase 3's ff-merge already catches).

### D4: Where does the virtiofs phantom-error → merge fallback live?

**Decision:** The phantom "local changes would be overwritten" fallback (merge
instead of rebase to incorporate the base) moves to Phase 1.0 alongside the
rebase. Phase 2 keeps only soft-reset + rename-detection + commit.

**Rationale:** The phantom error is a rebase/merge phenomenon; `git reset --soft`
never touches the working tree, so Phase 2 can't trigger it. The transient merge
commit created by the fallback survives the read-only audit harmlessly and is
discarded by Phase 2's soft-reset — same end state as today.

### D5: Divergence guard (TODOS option c)?

**Decision:** Light, non-blocking. Phase 0.2's audit-status preview gains a row
that fires when `merge-base origin/main HEAD != origin/main` (diverged base):
"base diverged — Phase 1.0 will rebase, then re-audit the rebased HEAD." No hard
refusal.

**Rationale:** Always-rebase already resolves the divergence, so a blocking
guard is redundant. Surfacing the divergence in the preview gives the operator
option (c)'s visibility benefit for free, without an extra interactive halt.

---

## In scope

- Restructure `.claude/skills/devshop/merge-devshop/SKILL.md`:
  - Rename `## Phase 1: Audit` → `## Phase 1: Rebase + audit`.
  - Add `### 1.0: Rebase onto the merge target (before auditing)` — moves the
    `GIT_CMD` setup, the anchor-detection block, the `$GIT_CMD rebase "$ANCHOR"`,
    and the virtiofs phantom-error → merge fallback out of Phase 2.
  - Add a "Why rebase before the audit" rationale codifying the 2026-05-28
    `go-live-prod-url-extraction` worked incident.
  - Convert the existing audit prose into `### 1.1: Audit` and make its
    `/ak-check-docs-and-tests` invocation pass `--range "$ANCHOR..HEAD"`.
  - Phase 2: remove the rebase line; recompute `$ANCHOR` via the same detection
    block; keep `reset --soft` + rename-detection + `commit`. Update Phase 2's
    prose ("Why the rebase is required first" → "the rebase already ran in
    Phase 1.0; this phase only collapses to a staged delta").
  - Update the `## Idempotence + resume` section: add a Phase 1.0 rebase
    idempotence bullet; reword the Phase 2 bullet to drop the rebase.
  - Update the Phase 0.2 audit-status table with a diverged-base row.
- Update `kit/tests/util-ak-merge-devshop.bats`:
  - New assertion: the rebase line precedes the audit invocation (line-order).
  - New assertion: Phase 1 region contains the anchor-detection + rebase.
  - New assertion: the audit invocation passes `--range "$ANCHOR..HEAD"`.
  - Update Section G: move the rebase assertion to Phase 1; Phase 2 keeps
    `reset --soft` + `commit -F` (no rebase).
- Update `kit/docs/guide/workflow.md` Devshop Skill Map row for
  `/ak-merge-devshop` (~line 488): reflect rebase-before-audit ordering.
- Bookkeeping (Phase 4.0): remove the PLAN Active row + delete the closed
  `kit/TODOS.md § /ak-merge-devshop audits before rebasing` entry.

## Out of scope

- `/ak-build` devshop-mode Gate 5 (the docs+tests audit inside the pipeline,
  before the merge). It runs on a fresh-base feature branch in practice, and
  even if it ever saw a stale base, `/ak-merge-devshop`'s new Phase 1.0
  rebase + re-audit corrects it before the squash — the system self-heals on
  that path. No change needed; noted in Gotchas.
- A blocking divergence guard (TODOS option c). Superseded by always-rebase
  (D5); only the light preview note ships.
- Merge-base range (TODOS option b). Not chosen — `--range "$ANCHOR..HEAD"`
  (D2) is strictly better (audits against the post-rebase base, not the old one).

## Files to create / modify

| File                                                        | Change                                                                                                            |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `.claude/skills/devshop/merge-devshop/SKILL.md`             | Phase 1 rename + new 1.0/1.1; Phase 2 rebase removed; idempotence + 0.2 table updates; worked-incident rationale. |
| `kit/tests/util-ak-merge-devshop.bats`                      | Rebase-before-audit ordering test; `--range` test; Section G updates.                                             |
| `kit/docs/guide/workflow.md`                                | `/ak-merge-devshop` skill-map row: rebase-before-audit ordering.                                                  |
| `PLAN.md`                                                   | Phase 4.0: delete the Active row.                                                                                 |
| `kit/TODOS.md`                                              | Phase 4.0: delete the closed entry.                                                                               |
| `specs/ak-merge-rebase-before-audit/{spec,tasks,review}.md` | Pipeline artifacts.                                                                                               |

## Tests

The skill is a Markdown prompt; tests are content-validation greps in
`kit/tests/util-ak-merge-devshop.bats` (existing convention). New / changed:

1. **`Phase 1 rebases onto the merge target BEFORE invoking the audit`** —
   line number of `$GIT_CMD rebase "$ANCHOR"` < line number of
   `skill: "ak-check-docs-and-tests"` (or the `Skill(` invocation). This is the
   core invariant the feature exists to guarantee.
2. **`Phase 1.0 anchor-selects between origin/main and local main`** — the
   `git rev-list --count origin/main..main` detection + `ANCHOR=` assignment
   appear in the Phase 1 region.
3. **`Phase 1.1 audit passes --range "$ANCHOR..HEAD"`** — the audit invocation
   carries the explicit range arg.
4. **Section G update** — `Phase 2 uses $GIT_CMD on reset --soft + commit`
   (drop the rebase clause); Phase 2 region still anchor-selects (recompute);
   Phase 2 no longer needs to contain `$GIT_CMD rebase`.
5. **Regression guards** — existing Phase 1 audit tests (high-halt,
   medium-pause, orchestrator invocation) still pass against the renamed
   `## Phase 1: Rebase + audit` heading (awk `/^## Phase 1:/,/^## Phase 2:/`
   still matches).
6. **Cross-doc coherence (Section K)** — `workflow.md` reflects rebase-before-audit.

Run: `kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-merge-devshop.bats`
(targeted) and `bats kit/tests/` (full suite, Phase 2.5 + Gate 2d).

## Dependencies

None. Pure devshop skill/doc/test change. No new packages, no migrations, no
external APIs.

## Task order

1. **Restructure Phase 1.0 + 1.1** in `merge-devshop/SKILL.md` (the rebase +
   audit reorder, anchor block move, `--range`, worked-incident rationale).
2. **Update Phase 2 + idempotence + Phase 0.2 table** (rebase removed,
   `$ANCHOR` recompute, prose, diverged-base preview row).
3. **bats coverage** (ordering test, `--range` test, Section G updates) — run
   the targeted suite green.
4. **workflow.md cross-ref** + verify full bats suite green.

(PLAN/TODOS closure is Phase 4.0, not a Phase 2 task.)

## Gotchas

- **Awk ranges in the bats file** key off `## Phase 1:` / `## Phase 2:`
  headers. Renaming `## Phase 1: Audit` → `## Phase 1: Rebase + audit` keeps
  the `/^## Phase 1:/` anchor valid — verify the existing Section F tests
  still pass.
- **Anchor recompute race (D3)**: if `main` moves between Phase 1.0 and
  Phase 2, the recomputed `$ANCHOR` could differ from the one Phase 1.0
  rebased onto. Single-dev devshop edge; Phase 3's ff-merge catches it. Note
  it in the Phase 2 prose, don't engineer around it.
- **Squash-message SHAs (Phase 0.3) are pre-rebase**: composed before
  Phase 1.0 rewrites them. They stay reflog-recoverable for ~90 days, same as
  today (squash detaches them regardless). Add a one-line note; don't reorder
  the approval gate to recompose post-rebase.
- **`/ak-build` Gate 5 unchanged** (Out of scope) — the self-heal via
  Phase 1.0 re-audit is the reason it's safe to leave.
- **Pre-commit on `merge-devshop/SKILL.md`**: a SKILL.md change with no paired
  test change can trip `check-tests-coverage-devshop.sh`. The bats update
  ships in the same commit (Task 3) or a tightly-following commit; keep the
  test change with the skill change to satisfy the coverage hook.

## Acceptance

- `/ak-merge-devshop` SKILL.md: the rebase (with anchor detection + phantom
  fallback) appears in Phase 1.0, before the Phase 1.1 audit; the audit passes
  `--range "$ANCHOR..HEAD"`; Phase 2 contains no rebase, only soft-reset +
  commit.
- `bats kit/tests/util-ak-merge-devshop.bats` green, including the new
  ordering + `--range` assertions.
- Full `bats kit/tests/` green (Phase 2.5 gate).
- `workflow.md` skill-map row describes the rebase-before-audit ordering.
- PLAN Active row + `kit/TODOS.md` entry deleted at Phase 4.0; squash delta to
  `PLAN.md` / `kit/TODOS.md` is net-zero against origin/main.
