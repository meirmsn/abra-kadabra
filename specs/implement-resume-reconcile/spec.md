<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: implement-resume-reconcile -->
<!-- date: 2026-05-28 -->

# Spec: implement-resume-reconcile (devshop)

**Sources:**

- `kit/TODOS.md § /ak-build Phase 2 resume trusts tasks.md done markers` — primary scope (the bug report)
- `PLAN.md` Planned row `implement-resume-reconcile` — scope summary + source pointer
- `.claude/skills/ak-build/SKILL.md § Step 0` (resume rungs 2–3) + `§ Phase 2` — wiring sites
- `.claude/skills/ak-implement/SKILL.md § Step 3` (per-task loop) — contract reaffirmation site
- Prior shipped spec `specs/slow-job-skip-on-docs-only/spec.md` — style/structure reference

On any `/ak-build` Phase 2 subagent drop, the orchestrator's resume check keys off
`tasks.md` `done` markers to decide where to restart — so a subagent that marked
tasks `done` before committing (or left work uncommitted) can make the next
`/ak-build` invocation silently skip to pre-ship with unfinished work. This feature
reconciles `done` markers against actual git state before the resume check trusts
them.

---

## Product update

### Headline (user-facing)

A build interrupted mid-implementation now re-checks its own progress against git
on resume instead of trusting a checklist — so an unfinished step can't silently
slip through as "done".

### Detail (team-facing)

`/ak-build` Phase 2 resume reconciles the `done` markers in `tasks.md` against
actual git state (a clean working tree plus at least as many implementation
commits as `done` tasks) before skipping the implement phase. A dropped
`/ak-implement` subagent that marked tasks done-before-commit no longer causes the
orchestrator to advance to pre-ship with uncommitted or never-started work. A new
bats-covered `kit/scripts/reconcile-task-commits.sh` does the check (rebase- and
amend-robust — it counts commits and inspects the tree rather than pinning SHAs);
the `done`-means-`committed` contract is reaffirmed in `/ak-implement`.

---

## Decisions (resolved at spec time)

Four `/ak-spec`-time decisions resolved in Phase 0 with the operator. Recorded
below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Where the reconcile logic lives

**Decision:** A new standalone helper `kit/scripts/reconcile-task-commits.sh` plus
`kit/tests/util-reconcile-task-commits.bats`, wired into the SKILL.md prose. Not
inline orchestrator prose.

**Rationale:** Matches the existing `roster-check.sh` / `check-llm-mediated-na.sh`
helper pattern; devshop convention requires bats coverage for new `kit/scripts/`;
a script is testable where inline prose is not.

### D2: Where in the pipeline reconciliation fires

**Decision:** Primarily at `/ak-build` **Step 0 resume rungs 2–3** — before
trusting an "all done" `tasks.md` to skip Phase 2. Plus a note at **Phase 2**
subagent non-clean-return handling.

**Rationale:** The silent-skip happens on the *next* `/ak-build` invocation's
resume check after a dropped subagent — Step 0 is the load-bearing surface, not the
live return (a dropped subagent never returns cleanly in the first place).

### D3: How a `done` task is verified as actually done

**Decision:** Clean-tree + commit-count heuristic. The "all done" claim is trusted
only when (a) the working tree is clean **and** (b) the count of implementation
commits in `origin/main..HEAD` (excluding bookkeeping commits — spec skeleton,
roadmap/planning, build-log) is ≥ the count of `done` tasks. No `tasks.md` format
change; no per-task SHA stamping.

**Rationale:** Sized to the TODO's "~20 lines of grep / S". Catches both documented
failure modes — uncommitted task work shows as a dirty tree, and a never-started or
uncommitted task shows as commit-count < done-count. **Decisively, it is
rebase-/amend-robust**: a plain rebase preserves commit count and subjects and
leaves a clean tree, whereas per-task SHA stamping (the rejected alternative) would
false-fail after `/ak-merge-devshop`'s Phase 1.0 rebase or any operator amend —
exactly the interrupted-then-rebased resume path this feature exists to protect.
A false-fail in the count heuristic is cheap (re-enter Phase 2, which re-verifies
and no-ops if work is genuinely complete); a false-fail in the SHA approach would
fire on the common rebase path.

### D4: Behavior on a reconcile mismatch

**Decision:** Do **not** skip to Phase 3. Re-enter Phase 2 (which resumes
internally and re-verifies per-task state), and surface the mismatch loudly to the
terminal. No silent auto-advance.

**Rationale:** Mirrors the TODO's "a task marked `done` with no matching commit
(and/or a dirty working tree) is NOT done; surface it and re-run." Phase 2's
existing resume logic absorbs the heuristic's lack of per-task precision.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, behavior, Files to
     create/modify, Tests (bats), Dependencies, Task order, Gotchas, Acceptance.
     The Product update + Decisions sections above stay verbatim. There is no
     METRICS.md (devshop-self-mode); the test surface is bats (kit/tests/). -->

## Core user story

N/A — devshop tooling change. No user-facing web flow added or modified. The
"flow" is a `/ak-build` orchestrator resume path exercised by bats, not a browser
surface; Gate 9 (qa-walk) has no artifact to capture.

## In scope

1. A new `kit/scripts/reconcile-task-commits.sh` helper: given a feature dir and a
   base ref, decide whether an "all done" `tasks.md` is **trustworthy** — clean
   working tree AND implementation-commit count ≥ `done`-task count (D1, D3).
2. `kit/tests/util-reconcile-task-commits.bats`: full behavioral coverage of the
   helper against fixture git repos (D1).
3. `/ak-build` SKILL.md Step 0 resume rungs 2–3: call the helper before trusting
   an "all done" `tasks.md` to skip Phase 2; on mismatch re-enter Phase 2 and
   surface loudly — do NOT skip to Phase 3 (D2, D4). Plus a Phase 2
   subagent-non-clean-return note (D2).
4. `/ak-implement` SKILL.md Step 3/4: reaffirm that marking a task `done` means its
   work is committed (atomic per-task commit) and the tree is clean (D3).
5. Doc sweep: update every place the resume behavior is documented to match the new
   reconcile gate, plus assertions in `kit/tests/util-ak-build-skill.bats` that the
   wiring prose is present (devshop non-negotiable: tooling change ships doc updates
   in the same commit).

## Out of scope

- **No `tasks.md` format change.** No per-task SHA stamping — explicitly rejected in
  D3 because it false-fails on the common rebase/amend path.
- **No new orchestrator inline reconcile logic.** The check lives in a standalone,
  bats-testable helper, not inline SKILL.md prose (D1).
- **No project-mode change.** The bug is a devshop-self-mode `/ak-build` resume
  path; the helper is generic but the wiring sites are the rungs both modes share
  (Step 0 rungs 2–3) and so apply identically — but no project-only resume surface
  (rung 1 open-PR path) is touched.
- **No auto-fix of a detected mismatch.** On mismatch the orchestrator re-enters
  Phase 2 (which re-verifies per-task) and surfaces — it does not attempt to guess
  which task is missing or commit anything itself (D4).
- **No change to the dirty-tree pre-commit guard** or any husky hook.

## Behavior — the reconcile contract

### `reconcile-task-commits.sh <feature-dir> [base-ref]`

**Inputs:**

- `<feature-dir>` — path to `specs/<feature>/` (the dir containing `tasks.md`).
  Required. Usage error (exit 64) if missing or if `<feature-dir>/tasks.md` does
  not exist.
- `[base-ref]` — git ref the implementation commits are counted against. Optional;
  defaults to `origin/main`. The caller (Step 0) passes the same base the resume
  check uses.

**Algorithm:**

1. **Clean-tree check.** `git status --porcelain` must be empty. A non-empty
   working tree (uncommitted task work) → **not trustworthy**, exit non-zero with a
   diagnostic naming the dirty state.
2. **Count `done` tasks.** Parse `tasks.md` for `**Status**: done` lines (the
   marker `/ak-implement` writes — see implement/SKILL.md Step 2 task template).
   Call this `DONE_COUNT`.
3. **Count implementation commits in `<base>..HEAD`.** `git log <base>..HEAD` subject
   lines, EXCLUDING bookkeeping commits:
   - `chore(<feature>): Phase 0 spec skeleton ...` (the Phase 0 skeleton commit)
   - `chore(roadmap): ...` / `chore(todos): ...` (tracker-close commits)
   - `chore(build-log): ...` (the Phase 4.0 BUILD-LOG commit)

   Everything else counts as an implementation commit. Call this `IMPL_COUNT`.
4. **Verdict.** Trustworthy (exit 0) iff tree clean AND `IMPL_COUNT >= DONE_COUNT`.
   Otherwise exit non-zero with a one-line diagnostic stating the counts and the
   failing condition (e.g. `done=3 impl-commits=1 — 2 done task(s) have no matching
   commit; not trustworthy`).

**Exit codes:**

- `0` — trustworthy: the "all done" claim is backed by a clean tree and enough
  implementation commits. Caller may skip Phase 2.
- `1` — not trustworthy: dirty tree, or `IMPL_COUNT < DONE_COUNT`. Caller must NOT
  skip Phase 2.
- `64` — usage error (missing arg, `tasks.md` not found, not in a git repo).

**Why count-based, not per-SHA (D3, decisive):** a plain rebase
(`/ak-merge-devshop` Phase 1.0) or an operator `git commit --amend` preserves the
commit count, subjects, and a clean tree — so the count heuristic still passes after
history rewrite. Per-task SHA stamping would false-fail on exactly the
interrupted-then-rebased resume path this feature exists to protect. A count
false-fail is cheap: re-entering Phase 2 re-verifies per-task and no-ops if work is
genuinely complete.

**Portability:** mawk/dash-portable. No bash-isms (no `[[ ]]`, no arrays for the
core path), no `\b` word boundaries in awk (use `($|[^…])` anchoring per the
`check-llm-mediated-na.sh` precedent). `set -euo pipefail` is acceptable (the script
runs under `#!/usr/bin/env bash`, like every other `kit/scripts/*.sh` helper) — the
"dash-portable" requirement is about awk syntax + avoiding bash-only string ops, not
about running the wrapper under dash. The awk binary is selected at runtime
(prefer `mawk`, fall back to `awk`) exactly as `check-llm-mediated-na.sh` does, so
the bats suite can pin `AWK_BIN=mawk`.

### Wiring at `/ak-build` Step 0 (D2, D4)

- **Rung 2** (`tasks.md` all `done` → skip to Phase 3): before skipping, call
  `bash kit/scripts/reconcile-task-commits.sh "$FEATURE_DIR" "origin/$BASE"`. Exit 0
  → proceed to skip (devshop mode still runs Phase 2.5 first if `verification.log`
  absent, unchanged). Non-zero → do NOT skip to Phase 3; fall through to **re-enter
  Phase 2** (which resumes internally and re-verifies per-task), and print the
  helper's diagnostic loudly to the terminal (`Resume reconcile FAILED: <diag> —
  re-entering Phase 2`).
- **Rung 3** (`tasks.md` some `done` → Phase 2) is unchanged in destination (already
  re-enters Phase 2), but the reconcile diagnostic is still surfaced when rung 2
  falls through to it, so the operator sees *why* an "all done" file did not skip.

### Phase 2 subagent-non-clean-return note (D2)

A short note at Phase 2: when the implement subagent drops (socket / non-clean
return) rather than reporting all-tasks-`done`, the *current* invocation already
halts (it never gets the clean completion signal). The silent-skip risk is on the
**next** `/ak-build` invocation's Step 0 resume check — which is exactly why the
reconcile gate lives at Step 0 rung 2, not at the live Phase 2 return. The note
cross-references the helper so a reader at Phase 2 knows the next-resume safety net
exists.

### `/ak-implement` done-means-committed reaffirmation (D3)

Step 3 per-task loop step 11 (mark `done`) and Step 4 (completion) get an explicit
restatement: **a task is `done` only when its work is committed (atomic per-task
commit, step 10) and the working tree is clean.** Marking `done` before committing
is the failure mode the Step 0 reconcile gate now catches — and `/ak-implement`
should never produce that state in the first place. This is a prose reaffirmation of
the existing step-10-then-step-11 ordering, not a new mechanic.

## Files to create / modify

**Create:**

- `kit/scripts/reconcile-task-commits.sh` — the helper (D1). ~70–90 lines, shaped
  after `kit/scripts/preship/check-llm-mediated-na.sh` (3-line `What/Why/Does NOT`
  header, usage block, exit-code legend, runtime awk-binary selection).
- `kit/tests/util-reconcile-task-commits.bats` — behavioral coverage (D1).

**Modify:**

- `.claude/skills/ak-build/SKILL.md` AND `.claude/skills/devshop/build/SKILL.md`
  — the two are kept byte-identical (same size/content today); apply the Step 0
  rung-2 reconcile wiring + Phase 2 note to BOTH so they stay in sync.
- `.claude/skills/ak-implement/SKILL.md` AND
  `.claude/skills/devshop/implement/SKILL.md` — done-means-committed reaffirmation
  in Step 3 step 11 + Step 4, to BOTH.
- `kit/docs/guide/workflow.md` — the resume-behavior prose. Two specific edits:
  (a) the `specs/<name>/tasks.md` bullet (~line 340) says tasks.md carries "commit
  SHAs" — reconcile is count-based and stamps no SHAs, so reword to "per-task status
  (reconciled against actual commits on resume)"; (b) add a one-line mention that
  the resume check reconciles `done` markers against commits before trusting an
  "all done" file.
- `kit/tests/util-ak-build-skill.bats` — add a Section (F) asserting the Step 0
  reconcile wiring prose + the Phase 2 note are present in `SKILL.md` (the test's
  `$SKILL_FILE` already points at `devshop/build/SKILL.md`).
- `kit/TODOS.md` — DELETE the closed entry (`/ak-build Phase 2 resume trusts
  tasks.md done markers`) per the close-on-ship convention.
- `PLAN.md` — Active-row flip (done at spec time).

## Tests — `util-reconcile-task-commits.bats`

Run via the repo's bats: `kit/tests/lib/bats-core/bin/bats
kit/tests/util-reconcile-task-commits.bats`. Each test builds a fixture git repo
under `$BATS_TEST_TMPDIR` (init, configure user, base commit on `main`, then a
feature branch with N commits + a `tasks.md`). Pin `AWK_BIN=mawk` in at least one
case to prove mawk-portability (per the `check-llm-mediated-na.sh` § T3 gotcha).

Cases:

1. **all-done-all-committed → pass (exit 0).** 3 `done` tasks, 3 implementation
   commits, clean tree. Asserts exit 0.
2. **done-count > impl-commit-count → fail (exit 1).** 3 `done` tasks, 1
   implementation commit (the dropped-subagent bug), clean tree. Asserts exit 1 +
   diagnostic mentions the counts.
3. **dirty tree → fail (exit 1).** 3 `done` tasks, 3 commits, but an uncommitted
   change in the working tree. Asserts exit 1 + diagnostic names the dirty tree.
   This is the "uncommitted Task 2" half of the original bug.
4. **partial-done → reported, not trusted.** 1 `done` + 2 `todo`, 1 commit. The
   helper still reports a verdict (it doesn't special-case partial files); the
   caller re-enters Phase 2 regardless. Asserts the helper returns a deterministic
   verdict for the partial file (exit 0 here since 1 impl-commit ≥ 1 done) — proving
   the helper is a pure clean-tree+count check and the *caller* owns the
   partial-vs-full routing.
5. **rebase-style: same commit count after history rewrite → still pass.** Build the
   all-done-all-committed fixture, then `git rebase` (or replay the 3 commits onto a
   fresh base) so SHAs change but count + subjects + clean tree are preserved.
   Asserts exit 0 — the decisive proof that the count heuristic survives the rebase
   path a SHA-stamping approach would false-fail (D3).
6. **bookkeeping commits excluded.** 3 `done` tasks, 3 implementation commits PLUS a
   `chore(<feat>): Phase 0 spec skeleton`, a `chore(roadmap): ...`, and a
   `chore(build-log): ...`. Asserts exit 0 AND that the bookkeeping commits did not
   inflate `IMPL_COUNT` (i.e. the same fixture with only 2 impl commits + 3
   bookkeeping commits still fails — proving the exclusion is load-bearing, not
   incidentally-passing).
7. **usage errors (exit 64).** Missing feature-dir arg (7a); `tasks.md` absent
   (7b); unresolvable base-ref (7c).
8. **mawk parity.** Re-run case 6 with `AWK_BIN=mawk` exported; assert identical
   verdict.
9. **CRLF tasks.md counted correctly.** A CRLF-encoded `tasks.md` with 3 `done`
   tasks but only 2 implementation commits → exit 1. The helper strips CR before
   counting, so `done` resolves to 3 and the mismatch is caught; without the strip
   the `done\r` lines miss the anchor, undercount to 0, and falsely pass — so this
   case is a regression sentinel for the CR-stripping fix.

## Tests — `util-ak-build-skill.bats` additions (Section F)

Content-validation assertions that the wiring prose landed (the skill is a pure LLM
prompt; grep distinctive phrases the fix introduced):

- Step 0 rung 2 references `reconcile-task-commits.sh` before skipping to Phase 3.
- The "do NOT skip to Phase 3; re-enter Phase 2" / surface-loudly prose is present
  in the rung-2 region.
- A Phase 2 region note references the next-resume reconcile gate.
- (Optionally) `kit/docs/guide/workflow.md` no longer claims tasks.md carries
  "commit SHAs" and mentions the reconcile-on-resume behavior.

## Dependencies

- **bats** — repo-vendored at `kit/tests/lib/bats-core/bin/bats` (submodule; already
  populated in this worktree via the `submodule update --init --recursive` step).
- **mawk + awk** — both ship in the devcontainer (per `check-llm-mediated-na.sh`).
- **git** — fixture repos use plain `git init` / `git commit` / `git rebase`.
- No new packages, no schema, no network. No third-party integrations.

## Task order

1. **`reconcile-task-commits.sh` + its bats.** Write the helper and
   `util-reconcile-task-commits.bats` together (test-alongside non-negotiable).
   Cover all 8 cases; run `kit/tests/lib/bats-core/bin/bats
   kit/tests/util-reconcile-task-commits.bats` green. One commit.
2. **Wire reconcile into `/ak-build` Step 0 + Phase 2 note.** Edit BOTH
   `.claude/skills/ak-build/SKILL.md` and `.claude/skills/devshop/build/SKILL.md`
   (keep byte-identical): rung-2 reconcile call + mismatch re-enter-Phase-2 +
   loud-surface, and the Phase 2 subagent-non-clean-return note. One commit.
3. **`/ak-implement` done-means-committed contract.** Edit BOTH
   `.claude/skills/ak-implement/SKILL.md` and
   `.claude/skills/devshop/implement/SKILL.md` (Step 3 step 11 + Step 4). One commit.
4. **Doc sweep + skill-prose assertions + TODO close.** Update
   `kit/docs/guide/workflow.md`, add Section F to `kit/tests/util-ak-build-skill.bats`,
   delete the closed `kit/TODOS.md` entry. Run the full `kit/tests/` bats suite
   green. One commit.

## Gotchas

1. **Two byte-identical SKILL.md copies.** `.claude/skills/ak-build/SKILL.md` and
   `.claude/skills/devshop/build/SKILL.md` are separate files kept in sync (same
   size today). Every prose edit must land in BOTH or `util-ak-build-skill.bats`
   (which reads `devshop/build/SKILL.md`) and the live `/ak-build` (which the
   `ak-build` skill dir serves) drift apart. Same for the two `implement/SKILL.md`
   copies.
2. **No `\b` in awk.** mawk lacks `\b` word boundaries. Anchor gate-name /
   commit-prefix matches with `($|[^…])` per `check-llm-mediated-na.sh`. The bats
   suite pins `AWK_BIN=mawk` to catch a `\b` regression.
3. **Bookkeeping-exclusion correctness is the subtle bit.** The `chore(...)` prefixes
   excluded are exactly the four the pipeline emits on a feature branch: Phase 0
   skeleton (`chore(<feature>): Phase 0 spec skeleton`), tracker closes
   (`chore(roadmap)`, `chore(todos)`), and BUILD-LOG (`chore(build-log)`). A future
   pipeline change that adds a new bookkeeping commit type would inflate `IMPL_COUNT`
   and could mask a missing task — but it errs SAFE (a false *pass*, not a false
   fail, only when extra real-looking commits exist). Test case 6 pins the current
   exclusion set so a prefix typo is caught.
4. **`origin/main` may be absent in a fixture repo.** Tests build fresh repos whose
   base is local `main` (or a tag), not `origin/main`. The helper takes `base-ref`
   as a parameter precisely so tests can pass a local ref; Step 0 passes
   `origin/$BASE`. Don't hardcode `origin/main` inside the helper's count logic.
5. **Devshop-self-mode: no METRICS.md, no Gate 9 artifact, no Render conditions.**
   This is a backend/tooling PR — no UI, no conditional render, no metrics. The
   Core user story is `N/A`; Render conditions omitted (no JSX). Offline behavior
   N/A (no remote data).

## Acceptance

- [ ] `kit/scripts/reconcile-task-commits.sh` exists, is executable, mawk-portable,
      and exits 0 / 1 / 64 per the contract.
- [ ] `kit/tests/util-reconcile-task-commits.bats` covers all 8 cases and passes via
      `kit/tests/lib/bats-core/bin/bats`.
- [ ] The rebase-style case (case 5) passes — count heuristic survives history
      rewrite (D3 proof).
- [ ] The bookkeeping-exclusion case (case 6) proves the exclusion is load-bearing.
- [ ] Both `/ak-build` SKILL.md copies call the helper at Step 0 rung 2 before
      trusting all-done, and on mismatch re-enter Phase 2 + surface loudly (do NOT
      skip to Phase 3).
- [ ] Both `/ak-build` SKILL.md copies carry the Phase 2 subagent-non-clean-return
      note.
- [ ] Both `/ak-implement` SKILL.md copies reaffirm done-means-committed in
      Step 3 step 11 + Step 4.
- [ ] `kit/docs/guide/workflow.md` reworded (no false "commit SHAs" claim; mentions
      reconcile-on-resume).
- [ ] `kit/tests/util-ak-build-skill.bats` Section F asserts the wiring prose.
- [ ] `kit/TODOS.md` entry deleted (close-on-ship).
- [ ] `PLAN.md` row in `## Active` (done at spec time).
- [ ] Full `kit/tests/` bats suite green.

## Decision rows (Confidence Calibration)

No stop-and-ask categories apply: no DB schema, no auth flow, no third-party
integration, no perf-sensitive path, no security logic, no test *deletion* (only
additions + the documented TODO close), no METRICS events, no new input-handling
path beyond the helper's own argv parsing (covered by usage-error tests), no UI
(a11y/i18n N/A), and the only new observability surface is the helper's stderr
diagnostic (a `kit/scripts/` diagnostic line, not a user/observability surface
needing review). D1–D4 were resolved with the operator at Phase 0 and are recorded
verbatim above; this spec adds no new decisions.
