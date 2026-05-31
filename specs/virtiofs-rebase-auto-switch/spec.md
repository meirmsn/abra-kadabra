<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: virtiofs-rebase-auto-switch -->
<!-- date: 2026-05-31 -->

# Spec: virtiofs-rebase-auto-switch (devshop)

**Sources:**

- `kit/TODOS.md § /ak-merge-devshop Phase 2 / Phase 1.0 — mechanize the virtiofs phantom-rebase fallback` — primary scope + enumerated approaches
- `PLAN.md` row `virtiofs-rebase-auto-switch` (Lev 8.0) — scope summary + source pointer
- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1.0` — the manual ladder being mechanized (lines ~708–784)
- `CLAUDE.md § Known Footguns` "Phantom 'local changes would be overwritten' on rebase (virtiofs)" — operator-facing footgun to rewrite
- `kit/FRICTION-LOG.md § Virtiofs phantom rebase also surfaces as a "rescheduled pick" stall` (F244) — variant auto-covered by unmerged-path discrimination
- Prior shipped helper `kit/scripts/reconcile-task-commits.sh` + `kit/tests/util-reconcile-task-commits.bats` — style/structure reference (header shape, exit-code contract, bats fixture pattern)

Mechanize the virtiofs phantom-rebase recovery ladder that `/ak-merge-devshop`
Phase 1.0 currently hand-drives: a new `kit/scripts/virtiofs-rebase.sh` helper
auto-detects the phantom false-failure and walks `rebase → checkStat-retry →
merge-fallback` autonomously, returning genuine conflicts to the caller.

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — devshop mode
routes Headline → `BUILD-LOG.md` `Headline:` + Detail → `Summary:`, and
`/ak-merge-devshop`'s squash-message composer reads this section. Pure-infra
feature → Headline uses the infra convention.

### Headline (user-facing)

Infrastructure update — no user-visible change in this PR.

### Detail (team-facing)

Devshop merges stop stalling on the virtiofs phantom-rebase flake —
`/ak-merge-devshop` Phase 1.0 now auto-detects the false-failure and walks the
recovery ladder (reduced-stat retry → merge fallback) without operator
hand-driving, while genuine conflicts still surface for manual resolution.

---

## Decisions (resolved at spec time)

Five `/ak-spec`-time decisions resolved in Phase 0 with the operator. Recorded
below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Form — reusable script, not inline SKILL bash

**Decision:** Implement as `kit/scripts/virtiofs-rebase.sh` (a bats-tested
helper) invoked from `/ak-merge-devshop § Phase 1.0`, not as inline
orchestrator bash in the SKILL.

**Rationale:** TODOS scopes "a bats test against a mocked rebase-failure
scenario" — bats tests exercise scripts/functions, not SKILL prose. DRY: the
current manual ladder is ~70 lines of prose the agent hand-runs each merge.

### D2: Recovery ladder — mirror the proven manual sequence, mechanized

**Decision:** `git rebase $ANCHOR` → on phantom, `git -c core.checkStat=minimal
-c core.trustctime=false rebase $ANCHOR` (preserves linear history) → on still-
phantom, `git merge $ANCHOR --no-edit` fallback (always works; transient merge
commit discarded by Phase 2 soft-reset).

**Rationale:** This is exactly the shipped manual ladder order
(checkStat-first-then-merge). Auto-picking it supersedes the either/or
("auto-switch" vs "auto-retry") framing in TODOS — both rungs, in the proven
order.

### D3: Phantom-vs-real-conflict discrimination — by unmerged-path presence

**Decision:** Discriminate phantom from real conflict by checking for unmerged
paths (`git diff --diff-filter=U` / `git status --porcelain` unmerged entries),
NOT by grepping the stderr error string.

**Rationale:** More robust than string-matching (≥2 known phantom string
variants: "would be overwritten" + the rescheduled-pick stall). A real conflict
leaves unmerged paths; both phantom flavors leave a clean tree. Side benefit:
auto-covers friction-log F244 (rescheduled-pick variant) with no extra code.

### D4: Real-conflict handling — return to caller, never auto-resolve

**Decision:** On a genuine conflict the helper leaves git state as-is and
returns distinct exit codes (10 = rebase-conflict, 11 = merge-fallback-conflict)
so the caller's existing inline resolution path takes over. The helper never
attempts auto-resolution.

**Rationale:** Conflict resolution needs the judgment the existing recipe
already documents; auto-resolving would be reckless. Principle of least
surprise.

### D5: Scope — rebase-only

**Decision:** Mechanize the rebase call-site only. cherry-pick / `am` keep their
manual inline recipes.

**Rationale:** Only Phase 1.0's rebase is an orchestrator call-site to
mechanize; cherry-pick/`am` have no orchestrator call-site. YAGNI.

---

<!-- /ak-spec (Phase 1) expanded the file from here. The Product update +
     Decisions sections above stay verbatim. -->

## Core user story

N/A — devshop infrastructure helper; no end-user flow added or modified. The
"user" is the `/ak-merge-devshop` orchestrator, whose behavior is covered by the
bats cases in § Tests, not by a qa-walk. (Render conditions section also omitted:
no UI surface — pure bash/git tooling.)

## In scope

- A new bats-tested helper `kit/scripts/virtiofs-rebase.sh` that mechanizes the
  phantom-rebase recovery ladder `/ak-merge-devshop § Phase 1.0` currently
  hand-drives (D1, D2).
- Phantom-vs-real-conflict discrimination by **unmerged-path presence** — not
  by stderr string-matching (D3).
- A distinct exit-code + `RESULT:` line vocabulary so the caller can route:
  clean success, checkstat-retry success, merge-fallback success, real
  rebase-conflict, real merge-fallback-conflict, usage error, internal error
  (D4).
- Worktree routing: when arg2 (`worktree-path`) is given, every git call runs
  via `git -C "$worktree-path"` (matches the `GIT_CMD` array convention in the
  caller).
- `kit/tests/util-virtiofs-rebase.bats` — a git-stub-on-PATH harness for the
  phantom paths plus real-repo fixtures for the clean/conflict/usage/worktree
  paths (~18 cases).
- Rewiring `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1.0` to call
  the helper and handle exit 10 / 11.
- Registering the new script in `kit/tests/structural-invariants.bats`
  `infra_scripts` allow-list (skill-invoked, non-hook-wired).
- Closing-convention doc work in the same PR (CLAUDE.md footgun rewrite,
  workflow.md row, kit/TODOS.md entry delete, FRICTION-LOG F244 resolve,
  cross-ref unwind).

## Out of scope

- **cherry-pick / `am` mechanization** (D5). Only Phase 1.0's rebase is an
  orchestrator call-site; cherry-pick/`am` have no orchestrator call-site, so
  they keep their manual inline `core.checkStat=minimal` + sleep/stat-refresh
  recipe (SKILL § Phase 1.0, lines ~757–784). YAGNI.
- **Auto-resolving genuine conflicts** (D4). The helper returns to the caller's
  existing inline resolution path; it never edits conflicted files.
- **Anchor selection logic** — the caller still computes `$ANCHOR`
  (origin/main vs local-main-when-ahead) and passes it in as arg1. The helper
  does not re-derive it.
- **Phase 2 soft-reset** — unchanged; it discards any transient merge commit the
  `merged-fallback` rung produces, exactly as today.
- **Deleting the `PLAN.md` row** — that is Phase 4.0's job per the pipeline, not
  this spec's implementation. Listed in § Acceptance closing-convention only for
  completeness.

## Behavior

### Invocation

```
virtiofs-rebase.sh <anchor> [worktree-path]
```

- `<anchor>` (required) — the rebase target ref (e.g. `origin/main` or `main`).
  The caller pre-selects it; the helper does not re-derive.
- `[worktree-path]` (optional) — when given, all git runs via
  `git -C "$worktree-path"`; when absent, git runs in the current repo.

The helper builds a `GIT` argv array internally — `(git)` or
`(git -C "$worktree-path")` — and routes every git call through it, mirroring
the caller's `GIT_CMD` array convention.

### Ladder (D2, in proven order)

1. `git rebase <anchor>`.
   - **Success** (exit 0) → emit `RESULT: rebased`, exit 0.
   - **Failure** (non-zero) → discriminate by unmerged-path presence (D3):
     - **Unmerged paths present** (`git diff --diff-filter=U --name-only`
       non-empty, or porcelain `U`-state entries) → real conflict. Leave git
       state as-is (rebase still in progress, conflict markers present). Emit
       `RESULT: conflict-rebase`, exit 10.
     - **No unmerged paths** (phantom — clean tree, false-failure) → continue to
       rung 2.
2. `git rebase --abort` (guarded — only if a rebase is in progress), then retry
   with reduced stat comparison, flags **inline**:
   `git -c core.checkStat=minimal -c core.trustctime=false rebase <anchor>`.
   - **Success** → emit `RESULT: rebased-checkstat`, exit 0.
   - **Failure with unmerged paths** → real conflict surfaced by the retry.
     Leave state as-is. Emit `RESULT: conflict-rebase`, exit 10.
   - **Failure, still no unmerged paths** (still phantom) → continue to rung 3.
3. `git rebase --abort` (guarded), then `git merge <anchor> --no-edit`.
   - **Success** → emit `RESULT: merged-fallback`, exit 0. (Transient merge
     commit — Phase 2's soft-reset discards it.)
   - **Failure with unmerged paths** → merge-fallback conflict. Leave state
     as-is (merge in progress, markers present). Emit `RESULT: conflict-merge`,
     exit 11.
   - **Failure, no unmerged paths** (merge failed for some other reason) → emit
     `RESULT: error: <msg>`, exit 1.

### Exit-code + RESULT vocabulary contract

| Exit | RESULT line         | Meaning                                                        | Caller action                                                  |
| ---- | ------------------- | -------------------------------------------------------------- | -------------------------------------------------------------- |
| 0    | `rebased`           | clean rebase, first try                                        | proceed to 1.1                                                 |
| 0    | `rebased-checkstat` | rebase succeeded after the reduced-stat retry (phantom dodged) | proceed to 1.1                                                 |
| 0    | `merged-fallback`   | both rebase attempts phantom-failed; merge fallback succeeded  | proceed to 1.1 (Phase 2 soft-reset discards the merge commit)  |
| 10   | `conflict-rebase`   | genuine rebase conflict (unmerged paths); rebase in progress   | resolve inline → `add` → `rebase --continue`                   |
| 11   | `conflict-merge`    | genuine conflict in the merge fallback; merge in progress      | resolve inline → `add` → `commit -F /tmp/merge-commit-msg.txt` |
| 1    | `error: <msg>`      | unexpected failure (merge failed, not a conflict)              | surface to operator, halt                                      |
| 64   | `usage: ...`        | no `<anchor>` arg, or too many args                            | fix invocation                                                 |

The full table is duplicated in the script header (style ref:
`reconcile-task-commits.sh` § Exit codes).

### `set -euo pipefail` interaction

The script runs `set -euo pipefail`, but rungs 1–3 each invoke git calls that
are **expected to fail**. Each such call captures its exit code without letting
`set -e` kill the script before discrimination runs — e.g.

```bash
rc=0
"${GIT[@]}" rebase "$anchor" || rc=$?
```

The `|| rc=$?` idiom neutralizes `set -e` for the expected-nonzero call while
preserving the code for the discrimination branch. Unmerged-path probes
(`git diff --diff-filter=U`) likewise capture rather than asserting.

### Guarding `git rebase --abort`

Before each `rebase --abort` (rungs 2 and 3), confirm a rebase is actually in
progress — `git rev-parse --git-path rebase-merge` / `rebase-apply` dir exists,
or fall back to `rebase --abort 2>/dev/null || true`. A bare `rebase --abort`
when no rebase is in progress exits non-zero and (under `set -e`) would abort the
script; the guard / `|| true` prevents that.

### Inline-flag invariant (D2)

The `-c core.checkStat=minimal -c core.trustctime=false` flags are passed
**inline per-command** (after any `-C "$worktree-path"`, which git parses first),
never `git config`-ed repo-global. This keeps the reduced stat comparison scoped
to the single retry and unable to leak into unrelated git operations.

## Files to create / modify

### Create

- `kit/scripts/virtiofs-rebase.sh` — the helper. `#!/usr/bin/env bash`,
  `set -euo pipefail`, `# What:/# Why:/# Does NOT:` header, full exit-code +
  RESULT vocabulary documented in the header (style ref:
  `reconcile-task-commits.sh`). `chmod +x`.
- `kit/tests/util-virtiofs-rebase.bats` — the test surface (~18 cases, below).

### Modify

- `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1.0` — replace the
  hand-run "First remedy / Second remedy" ladder blocks (lines ~708–755) with a
  single call to `virtiofs-rebase.sh "$ANCHOR" "$WORKTREE_PATH"` (GIT_CMD-array
  aware: pass `$WORKTREE_PATH` as arg2 only when set) plus caller-side handling
  of exit 10 (resolve inline → `add` → `rebase --continue`) and exit 11 (resolve
  → `add` → `commit -F /tmp/merge-commit-msg.txt`). **Keep** the cherry-pick/`am`
  manual recipe (lines ~757–784, out of scope per D5).
- `kit/tests/structural-invariants.bats` — append `virtiofs-rebase.sh` to the
  `infra_scripts` allow-list (~line 237) with a one-line rationale comment
  (skill-invoked from `/ak-merge-devshop § Phase 1.0`, not hook-wired).
- `CLAUDE.md § Known Footguns` — rewrite the "Phantom 'local changes would be
  overwritten' on rebase (virtiofs)" entry from "First action: retry inline
  with…" to imperative-present pointing at the helper (`/ak-merge-devshop`
  Phase 1.0 now auto-runs `virtiofs-rebase.sh`; the manual `-c` form remains the
  recipe only for the still-manual cherry-pick/`am` call-sites).
- `kit/docs/guide/workflow.md` — update the merge-devshop row that describes the
  phantom-rebase handling to reference the mechanized helper.
- `kit/TODOS.md` — delete the `§ /ak-merge-devshop Phase 2 / Phase 1.0 —
mechanize the virtiofs phantom-rebase fallback` entry (closing convention).
- `kit/FRICTION-LOG.md` — resolve F244 (rescheduled-pick variant): mark it
  resolved, noting the unmerged-path discrimination (D3) auto-covers it (it is a
  clean-tree, no-unmerged phantom → routes through the same ladder).

## Tests

Surface: **bats** (`kit/tests/util-virtiofs-rebase.bats`). Devshop-self-mode —
no vitest/Playwright. Pattern ref: `util-reconcile-task-commits.bats`
(`load helpers/setup`, `$SCRIPTS_DIR`, temp git repo in `$BATS_TEST_TMPDIR`,
per-case `run` + status/output capture).

Two harnesses in one file:

**A. git-stub-on-PATH harness** (deterministic phantom simulation). A fake `git`
shim is prepended to `$PATH`; it is table-driven via env vars so each case can
script the rung-by-rung responses, and it **records its argv** to a log file so a
test can assert which flags a given call carried. The shim:

- `rebase <anchor>` (no `-c` flags) → configurable: emit the phantom stderr +
  exit 1 with a clean tree / no unmerged (default), OR exit 0 (clean success),
  OR exit 1 with unmerged paths (real conflict).
- `rebase` **with** `-c core.checkStat=minimal -c core.trustctime=false` →
  configurable: success, still-phantom (exit 1 no unmerged), or exit-1-with-
  unmerged. Detected by scanning recorded argv for both flags.
- `merge <anchor> --no-edit` → configurable: success, conflict (unmerged), or
  other-error.
- `rebase --abort` → exit 0 (and clears the "rebase in progress" sentinel).
- `diff --diff-filter=U --name-only` / `status --porcelain` → emit the
  controllable unmerged set.
- `rev-parse --git-path …` (rebase-in-progress probe) → controllable sentinel.
- Records every argv line so a test can grep it.

**B. real-repo fixtures** (genuine git for the non-phantom paths) — a real temp
repo with `main` + a feature branch, mirroring the reconcile bats setup.

Enumerated cases:

1. **clean rebase, first try** (real repo) — anchor is a clean fast-forward base
   → exit 0, `RESULT: rebased`.
2. **checkstat retry success** (stub) — first `rebase` phantom-fails (clean, no
   unmerged); checkstat `rebase` succeeds → exit 0, `RESULT: rebased-checkstat`.
3. **checkstat retry carries BOTH flags** (stub) — assert the recorded argv for
   the retry contains `core.checkStat=minimal` AND `core.trustctime=false`
   (regression sentinel for a dropped flag).
4. **merge fallback success** (stub) — both `rebase` attempts phantom-fail
   (clean, no unmerged); `merge --no-edit` succeeds → exit 0,
   `RESULT: merged-fallback`.
5. **genuine rebase conflict, first try** (real repo) — feature + anchor edit the
   same line → first `rebase` fails WITH unmerged paths → exit 10,
   `RESULT: conflict-rebase`; rebase left in progress (no abort).
6. **genuine conflict surfaced by the checkstat retry** (stub) — first `rebase`
   phantom (clean); checkstat `rebase` fails WITH unmerged → exit 10,
   `RESULT: conflict-rebase`.
7. **genuine conflict in the merge fallback** (stub) — both rebases phantom;
   `merge` fails WITH unmerged → exit 11, `RESULT: conflict-merge`; merge left
   in progress.
8. **merge fallback non-conflict error** (stub) — both rebases phantom; `merge`
   fails with NO unmerged paths (other error) → exit 1, `RESULT: error: …`.
9. **discrimination is by unmerged-path, not stderr string** (stub) — first
   `rebase` exits 1 emitting the phantom "would be overwritten" string BUT with
   unmerged paths present → must classify as conflict (exit 10), proving the
   helper ignores the stderr string (D3).
10. **F244 rescheduled-pick variant** (stub) — first `rebase` exits non-zero with
    a rebase IN PROGRESS, clean tree, NO unmerged paths (the "currently editing a
    commit / rescheduled pick" shape) → must route into the recovery ladder
    (checkstat retry), NOT misclassify as conflict. Asserts the abort-guard fires
    and the retry runs.
11. **usage: no anchor arg** (real repo) → exit 64, output names `usage`.
12. **usage: too many args** (real repo) — three positional args → exit 64.
13. **worktree-path routing** (real repo) — invoke with arg2 = the repo path from
    a _different_ cwd; assert the rebase happens in the worktree repo (verify by
    branch tip moving there) → exit 0, `RESULT: rebased`.
14. **abort-guard: no rebase in progress** (stub) — drive a path that reaches a
    `rebase --abort` call site while the in-progress sentinel is unset; assert the
    script does not die (guard / `|| true` holds) and continues correctly.
15. **clean success emits exactly `RESULT: rebased`** (real repo) — assert the
    RESULT line is present and is the success variant, not a fallback variant
    (pins that a clean run does NOT spuriously fall through to a lower rung).
16. **checkstat path leaves no repo-global config** (real-repo or stub) — after a
    `rebased-checkstat` run, assert `git config --local core.checkStat` is unset
    (inline-flag invariant; flags must not leak repo-global).
17. **merge-fallback leaves anchor as ancestor** (real repo) — after a
    `merged-fallback` run, assert `git merge-base --is-ancestor <anchor> HEAD`
    holds (the end-state contract Phase 1.1's audit range depends on).
18. **conflict exit leaves state for the caller** (real repo, case 5 companion) —
    after exit 10, assert unmerged paths are still present and the rebase is still
    in progress (helper did NOT abort/clean up — caller resolves).

## Dependencies

- **Prior art / style ref**: `kit/scripts/reconcile-task-commits.sh` (header
  shape, exit-code contract block, `set -euo pipefail`, mawk-portability note
  pattern) and `kit/tests/util-reconcile-task-commits.bats` (bats fixture
  pattern). No behavioral dependency — independent helper.
- **Ordering**: the helper script must exist before the SKILL rewrite references
  it, and before the `structural-invariants.bats` wiring test will pass (an
  unregistered new script reds the suite). Create script + register in
  infra_scripts + write bats together, then rewire the SKILL, then docs.
- **No new runtime deps** — pure git + bash, already present in the devcontainer.

## Task order

1. **T1 — helper script.** Create `kit/scripts/virtiofs-rebase.sh` via bash
   heredoc (kit/scripts is Write/Edit-TOOL-denied; see Gotchas), `chmod +x`.
   Implement the full ladder, exit codes, RESULT vocabulary, header contract.
2. **T2 — bats tests.** Write `kit/tests/util-virtiofs-rebase.bats` (git-stub
   harness + real-repo fixtures, ~18 cases). Run the file green.
3. **T3 — wiring registration.** Add `virtiofs-rebase.sh` to the
   `infra_scripts` allow-list in `structural-invariants.bats` (~line 237) with a
   rationale comment. Run that suite green.
4. **T4 — SKILL rewrite.** Replace the Phase 1.0 manual remedy ladder with the
   helper call + exit-10/11 handling. Keep cherry-pick/`am` recipe.
5. **T5 — closing-convention docs.** Rewrite CLAUDE.md footgun, update
   workflow.md row, delete kit/TODOS.md entry, resolve FRICTION-LOG F244, unwind
   cross-refs. (PLAN.md row deletion is Phase 4.0, not here.)

(T1+T2+T3 land together as the "helper + tests + wiring" logical unit per the
ordering dependency; T4 and T5 follow as their own commits.)

## Gotchas

Carry-forward implementation traps for Phase 2:

- **`kit/scripts/**`is Write/Edit-TOOL-denied** (settings.json deny rules) but
the directory is **node-owned in the worktree** → create`virtiofs-rebase.sh`via a bash heredoc:`cat > /devshop/.worktrees/virtiofs-rebase-auto-switch/kit/scripts/virtiofs-rebase.sh <<'EOF' … EOF`then`chmod +x`. The `/tmp`+`sudo install -m 755 -o root -g root`handoff is
the documented fallback **only if a container re-lock bites** (don't reach for
it first).`kit/tests/**`, `.claude/skills/**`, `CLAUDE.md`, `kit/docs/**`,
`kit/TODOS.md`, `kit/FRICTION-LOG.md` are **NOT\*\* tool-denied → use Write/Edit.
- **Quote the heredoc delimiter** (`<<'EOF'`) so the script body's `$ANCHOR`,
  `"${GIT[@]}"`, `$#`, etc. land literally and are not expanded at authoring
  time.
- **`set -euo pipefail` + expected-nonzero git calls** — every git call that may
  legitimately fail (each rung's rebase/merge, the unmerged-path probe) MUST
  capture its code (`rc=0; "${GIT[@]}" … || rc=$?`) so `set -e` doesn't kill the
  script before discrimination. This is the single most likely impl bug.
- **Guard `git rebase --abort`** — a bare abort with no rebase in progress exits
  non-zero → `set -e` death. Probe the rebase-in-progress dir first, or
  `|| true`.
- **`-c` flags stay inline per-command**, after any `-C "$worktree-path"` — never
  `git config` them repo-global (test 16 pins this).
- **DCG blocks `git reset --hard`** (no bypass). Irrelevant to this feature's
  impl (the helper never resets), but noted as a git-op constraint — don't reach
  for it in any fixture teardown.
- **Editing devshop `CLAUDE.md` triggers the Layer-B classification gate** at
  commit → the CLAUDE.md-footgun-rewrite commit needs
  `git config devshop.claudeMdClassification "<value>"` (or the inline
  `-c devshop.claudeMdClassification=…` form). This is a docs-prose rewrite of an
  existing footgun entry, not a new directive.
- **Every devshop tooling change includes doc updates in the same commit** — the
  helper + tests commit should carry the script's own header docs; the SKILL +
  CLAUDE.md + workflow.md edits satisfy the docs-coverage guard for the
  behavior change. Don't split code from its docs across commits in a way that
  reds the docs-coverage gate.
- **structural-invariants wiring test reds the suite the moment the script
  exists unregistered** — land T3 (infra_scripts registration) in the same
  logical unit as T1 so a mid-implementation test run isn't red for a spurious
  reason.

## Acceptance

- [ ] `kit/scripts/virtiofs-rebase.sh` exists, is executable, has the
      `# What:/# Why:/# Does NOT:` header and the full exit-code + RESULT vocabulary
      documented in-header.
- [ ] Ladder behaves per § Behavior: clean→`rebased`/0;
      phantom→checkstat→`rebased-checkstat`/0; double-phantom→merge→
      `merged-fallback`/0; rebase-conflict→`conflict-rebase`/10;
      merge-conflict→`conflict-merge`/11; merge-other-error→`error:`/1;
      usage→64.
- [ ] Discrimination is by unmerged-path presence, never stderr string (test 9).
- [ ] checkstat retry carries BOTH `core.checkStat=minimal` and
      `core.trustctime=false`, inline (tests 3, 16).
- [ ] F244 rescheduled-pick variant routes into the recovery ladder, not
      misclassified as conflict (test 10).
- [ ] Worktree-path arg2 routes git via `-C` (test 13).
- [ ] `kit/tests/util-virtiofs-rebase.bats` is green (~18 cases).
- [ ] `virtiofs-rebase.sh` registered in `structural-invariants.bats`
      `infra_scripts`; that suite is green.
- [ ] `/ak-merge-devshop § Phase 1.0` calls the helper (GIT_CMD-array aware) and
      handles exit 10 / 11; cherry-pick/`am` manual recipe retained.
- [ ] Closing convention satisfied: CLAUDE.md footgun rewritten to
      imperative-present; workflow.md row updated; kit/TODOS.md mechanize entry
      deleted; FRICTION-LOG F244 resolved; cross-refs unwound. (PLAN.md row deletion
      deferred to Phase 4.0 per § Out of scope.)
- [ ] Full bats suite (`pnpm turbo run test`) green.
