<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: worktree-shared-config-corruption -->
<!-- date: 2026-06-01 -->

# Spec: worktree-shared-config-corruption (de-submodule bats libs)

**Sources:**

- `kit/TODOS.md § [HIGH] Worktree submodule-update injects core.worktree…` — primary scope (the recurring corruption class)
- `kit/FRICTION-LOG.md § git worktree/submodule update flips core.bare=true…` — recurrence record (both config-injection + HEAD-race faces)
- `PLAN.md` row `worktree-shared-config-corruption` (score 6.4) — scope summary + source pointer
- Blast-radius map (Phase 0 Explore agent, 2026-06-01) — every reference to the bats submodules + the submodule-update recipe across docs/scripts/skills
- `kit/docs/FAQ.md:46` ("No git submodules. Git-native.") — the philosophy this change aligns the codebase back to
- Prior shipped spec `specs/init-devshop-mtime-bump/spec.md` — style/structure reference

Root-fix the recurring shared-`/devshop/.git/config` corruption by removing its
cause: the `git submodule update --init --recursive` step in the linked-worktree
recipe. The three vendored bats libraries (`kit/tests/lib/bats-{core,support,assert}`)
become plain checked-in files instead of git submodules, so the submodule op —
the thing that intermittently wrote `core.worktree`/`core.bare=true` onto the
shared config — no longer exists. The HEAD-race face of the same tracker entry is
split out and re-filed (it has a different root cause: a shared working tree).

---

## Product update

Single source-of-truth — `/ak-build` Phase 4.0 copies these into the
`BUILD-LOG.md` entry (`Headline:` ← Headline, `Summary:` ← Detail), and
`/ak-merge-devshop` reads this section when composing the squash commit body.

### Headline (user-facing)

Infrastructure update — no user-visible change in this PR.

### Detail (team-facing)

The three vendored bats test libraries (`bats-core`, `bats-support`, `bats-assert`)
are now plain checked-in files instead of git submodules. This eliminates the
`git submodule update --init --recursive` step from the linked-worktree setup
recipe — the operation that intermittently corrupted the shared
`/devshop/.git/config` (writing `core.worktree`/`core.bare=true`) and silently
broke unrelated parallel sessions' `git status`/`checkout`/`merge` with errors
that surfaced far from their cause. With the submodule machinery gone, the
corruption class is structurally impossible rather than detected-and-repaired.
Bats runs are unchanged (the libs sit at the same paths, loaded by-path), worktree
creation is simpler (`git worktree add … && pnpm install`, no submodule step), and
the codebase now matches its own stated "no git submodules, git-native" philosophy.
A `vendor-bats-libs.sh` script replaces `git submodule update --remote` for future
upstream bumps.

---

## Decisions (resolved at spec time)

7 decisions resolved in Phase 0 with the operator (D-depth probe: chose root-fix
over the original a+b+d bandaid; then dropped (b) and split out (d)).

### D1: De-submodule — vendor bats libs as plain files at the same paths

**Decision:** Convert `kit/tests/lib/bats-{core,support,assert}` from git submodules
to plain checked-in files **at the same paths**, preserving executable bits.
Delete `.gitmodules`, remove the `submodule.*` keys, and drop the
`git submodule update --init --recursive` step from the worktree-add recipe
everywhere it appears. The bats runner (`kit/tests/lib/bats-core/bin/bats`) and
every `load "…/bats-support/load"` line are by-path, so the test harness is
unchanged.

**Rationale:** The submodule op is the sole trigger of the shared-config corruption.
Removing it makes face-1 corruption structurally impossible, not merely repaired
after the fact. Aligns the tree with the FAQ's stated "no git submodules" philosophy
(currently inaccurate). Verified empirically at Phase 0 that the libs load by-path.

### D2: vendor-bats-libs.sh replaces `git submodule update --remote`

**Decision:** Add `kit/scripts/vendor-bats-libs.sh` — clones each lib at a SHA
pinned in a manifest, copies the runtime subset into place, strips any `.git`, and
self-verifies the full bats suite passes. Pin the currently-vendored SHAs:

- `bats-core`: `d9faff0d7bc32e7adebc6552446f978118d3ab3b`
- `bats-support`: `0954abb9925cad550424cebca2b99255d4eabe96`
- `bats-assert`: `697471b7a89d3ab38571f38c6c7c4b460d1f5e35`
  Register the new script in `structural-invariants.bats` `infra_scripts` and pair it
  with a bats test.

**Rationale:** Keeps upstream bumps reproducible and documented without submodule
machinery. The pinned-SHA manifest is the audit trail for what version we vendored.

### D3: Trim vendored files to the runtime subset

**Decision:** Vendor only the runtime files, not the full upstream trees
(`bats-core` is 1.9M, mostly `test/`/`docs/`/`man/`/`contrib/`/`docker/`).
Candidate runtime set (the vendor script + the bats suite confirm the exact set):

- `bats-core`: `bin/`, `libexec/`, `lib/`, `LICENSE.md`
- `bats-support`: `load.bash`, `src/`, license file
- `bats-assert`: `load.bash`, `src/`, license file
  The vendor script self-verifies by running the full suite after copying.

**Rationale:** Full trees add hundreds of third-party noise files, bloat the diff,
and carry a gitleaks-false-positive risk from bats-core's own test fixtures. Trim's
only risk — missing a needed file — is caught loudly by the full bats suite in this
same PR. Keep each lib's LICENSE for attribution compliance.

### D4: Exclude kit/tests/lib/\*\* from devshop's own gates

**Decision:** Exclude `kit/tests/lib/**` from every devshop gate/hook that walks the
tree applying our conventions — file-header check, convention check, tests-coverage
check, and `/ak-merge-devshop` Phase 2's gitleaks scan. Audit each and wire the
exclusion in this same PR.

**Rationale:** As gitlinks the libs were outside our tree; as plain files they enter
it, and our conventions (3-line headers, paired bats tests, etc.) must not lint
third-party vendored code. Missing an exclusion would block the merge or false-flag
vendored fixtures.

### D5: Drop the (b) session-start auto-clear guard entirely

**Decision:** Do NOT build the session-start `core.worktree`/`core.bare` detection +
auto-clear guard. Do NOT add new `CLAUDE.md § Known Footgun` lines for the
config-injection symptom.

**Rationale:** (b) was only a net under the submodule trigger. With the trigger gone
(D1), nothing writes those keys to the shared config — an automated guard would watch
for an impossible event, and stale footgun prose about a fixed cause misleads future
sessions (per the closing-TODO convention). The FRICTION-LOG/TODOS closure records
"fixed by de-submoduling." If config corruption ever recurs without submodules, that
is new information earning a fresh targeted fix.

### D6: Shared-.git safety during conversion

**Decision:** Perform the conversion inside the linked worktree; avoid mutating
`/devshop` main's shared `.git` state beyond what de-submoduling requires; verify
BOTH trees are healthy (`git status`/`rev-parse` succeed) and the full bats suite is
green before and after the conversion. Do not use `rm -rf` (sandbox-blocked); detach
gitlinks by removing the single `.git` pointer file per lib.

**Rationale:** The feature exists to stop shared-`.git` corruption — the fix must not
itself corrupt shared state. There is no parallel session now, but the conversion
touches shared config/`.git/modules`, so verify-before-and-after is the safety check.

### D7: Split out the HEAD-race face (d) — re-file as its own entry

**Decision:** This PR ships ONLY the face-1 (config-injection) root-fix. The HEAD-race
face (a parallel `git checkout` moving `/devshop`'s shared HEAD) is NOT addressed
here. Re-file it as its own `kit/TODOS.md`/`PLAN.md` entry during Phase 4.0
bookkeeping, preserving the FRICTION-LOG observations about it.

**Rationale:** The HEAD-race has a different root cause (a shared working tree, not
submodules). A soft "use a worktree" directive would be a bandaid — the exact thing
this root-fix PR rejected. It deserves its own deliberate design pass (likely a
workflow convention or mechanical guard), not a bolt-on.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Data model (n/a),
     Files to create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance.
     The Product update + Decisions sections above stay verbatim. This is
     devshop-self-mode: no METRICS.md, test surface is bats (kit/tests/). -->

## Core user story

N/A — devshop infrastructure change (de-submodule the vendored bats libs). No
user-facing UI flow added or modified; no browser surface. Gate 9 (qa-walk)
skips artifact assertion for this PR.

## In scope

- **De-submodule the three bats libs** (`kit/tests/lib/bats-{core,support,assert}`)
  from git submodules to plain checked-in files at the same paths, preserving
  executable bits (D1). Delete `.gitmodules`, drop the `submodule.*` keys from the
  shared `/devshop/.git/config`, detach each gitlink by removing its single `.git`
  pointer file (NOT `rm -rf` — D6), `git rm --cached` the gitlink, keep the trimmed
  runtime subset, `git add` the files as plain content.
- **Trim to the runtime subset** (D3): `bats-core` → `bin/ libexec/ lib/ LICENSE.md`;
  `bats-support` → `load.bash src/` + license; `bats-assert` → `load.bash src/` +
  license. Remove non-runtime dirs (`test/ docs/ man/ contrib/ docker/`, root
  `*.yaml`/`*.dist`/`install.sh`/`uninstall.sh`/`Dockerfile`/`package.json` etc.).
  Keep each lib's LICENSE for attribution.
- **`kit/scripts/vendor-bats-libs.sh`** (NEW, D2) — clones each lib at a pinned SHA,
  copies the runtime subset into place, strips `.git`, self-verifies the full bats
  suite passes. SHAs recorded in a manifest (decision below: inline in the script as
  a `pin` table + emitted to `kit/tests/lib/VENDORED-VERSIONS` so the vendored state
  is auditable without reading the script). Paired bats test
  `kit/tests/util-vendor-bats-libs.bats`. Registered in `structural-invariants.bats`
  `infra_scripts`.
- **Gate exclusions** (D4) — exclude `kit/tests/lib/**` from every devshop gate that
  walks the tree applying our conventions, where it scans paths the vendored files
  now occupy: tests-coverage check, file-header check, bats-coverage check, the
  Gate-11 convention check, and `/ak-merge-devshop` Phase 2's gitleaks scan. Audit
  each first (most are already scoped narrower than `kit/tests/lib/**` — only add an
  exclusion where the gate would otherwise reach the vendored files).
- **Rewrite the `structural-invariants.bats` "BATS submodules are initialized" test**
  to assert the plain runtime files are present (`bats-core/bin/bats` executable +
  each lib's `load.bash`/`src` reachable) instead of submodule init.
- **Strip the `submodule update --init --recursive` step** from the worktree-add
  recipe everywhere it appears: `CLAUDE.md`, `kit/docs/guide/architecture.md`,
  `kit/ROADMAP.md`. Rewrite the "submodule populates bats libs" trap prose to reflect
  that the libs are now plain checked-in files (present after `git worktree add`, no
  init step needed).
- **Remove the now-dead submodule-deinit teardown** from
  `.claude/skills/devshop/merge-devshop/SKILL.md` (Step 1 of the teardown) — a plain
  `git worktree remove --force` suffices once there are no submodules.
- **Confirm `kit/docs/FAQ.md:46`** ("No git submodules. Git-native.") now reads as
  accurate present tense (it becomes true with this PR — no edit needed unless prose
  has drifted).
- **Tracker closure** (D7) — split the [HIGH] `kit/TODOS.md` entry: remove the
  config-injection (face-1) portion (fixed by this PR), re-file the HEAD-race face as
  its own new `kit/TODOS.md` entry preserving the observations. Fold the
  `kit/FRICTION-LOG.md` `core.bare=true` entry's recurrence history into the
  `BUILD-LOG.md` entry at Phase 4.0; preserve its HEAD-race observations into the
  re-filed TODOS entry. Remove the `PLAN.md` Active row at Phase 4.0. Unwind any
  cross-refs to the config-injection footgun.

## Out of scope

- **The HEAD-race face** (a parallel `git checkout` moving `/devshop`'s shared HEAD).
  Different root cause (a shared working tree, not submodules). Split out and re-filed
  as its own deliberate tracker entry (D7); NOT fixed here. A bandaid "use a worktree"
  directive is explicitly rejected.
- **The (b) session-start `core.worktree`/`core.bare` auto-clear guard** — dropped
  entirely (D5). It was only a net under the submodule trigger; with the trigger gone
  it would watch for an impossible event. No new `CLAUDE.md § Known Footgun` line for
  the config-injection symptom.
- **Upstream bumps of the bats libs.** This PR pins the currently-vendored SHAs (D2);
  bumping to newer upstream is a separate future task run through
  `vendor-bats-libs.sh`.
- **Frozen historical `specs/*/spec.md` references** to the submodules — left alone
  (they document prior state).
- **De-submoduling gstack** (`.claude/skills/gstack/`) or any other vendored tree —
  out of scope; this PR is bats-only.

## Data model

N/A — no database, no schema. This is a build-tooling / VCS-structure change.

## Files to create / modify

### Create

- `kit/scripts/vendor-bats-libs.sh` — vendor script (D2/D3). Clones each lib at its
  pinned SHA into a temp dir, copies the runtime subset to `kit/tests/lib/<lib>/`,
  strips `.git`, writes `kit/tests/lib/VENDORED-VERSIONS`, runs the full bats suite to
  self-verify. 3-line `# What/Why/Does NOT` header (it's a `.sh`, not exempt as a
  config file — header convention applies).
- `kit/tests/util-vendor-bats-libs.bats` — paired test for the vendor script. Asserts
  the script exists + is executable, that `VENDORED-VERSIONS` lists all three libs
  with 40-char SHAs, and (cheap structural assertions, not a network re-clone) that
  the runtime subset the script targets matches what's checked in.
- `kit/tests/lib/VENDORED-VERSIONS` — manifest of pinned SHAs (one `<lib> <sha>` per
  line). Plain data file; excluded from header/convention gates as part of
  `kit/tests/lib/**`.

### Modify

- `.gitmodules` — **delete** (3 submodule blocks; the only content).
- `kit/tests/lib/bats-core/` — detach gitlink (remove `.git` pointer), `git rm
--cached` gitlink, trim to `bin/ libexec/ lib/ LICENSE.md`, `git add` as plain files.
- `kit/tests/lib/bats-support/` — same; trim to `load.bash src/` + `LICENSE`.
- `kit/tests/lib/bats-assert/` — same; trim to `load.bash src/` + `LICENSE`.
- `kit/tests/structural-invariants.bats` — (a) add `vendor-bats-libs.sh` to the
  `infra_scripts` list (~line 239); (b) rewrite the "wiring: BATS submodules are
  initialized" test (~line 664) to assert plain runtime files present.
- `kit/scripts/commit-hooks/check-tests-coverage-devshop.sh` — audit; it scopes to
  `kit/scripts/*.sh` only (line 51-52), so vendored libs under `kit/tests/lib/` are
  already out of its scan. Confirm no change needed, or add `kit/tests/lib/**`
  exclusion if the audit shows a reach.
- `kit/scripts/commit-hooks/check-file-headers.sh` — audit; it matches `.ts/.tsx`
  under `src/|app/` only — bats libs are `.bash`/`.sh`/no-ext, so already excluded.
  Add a defensive `kit/tests/lib/**` filter only if the audit shows a future reach.
- `kit/scripts/commit-hooks/check-bats-devshop.sh` — audit; it scans changed
  `kit/scripts/*.sh` (line 47) for paired tests, so vendored `.sh` under
  `kit/tests/lib/` won't be treated as needing a paired test. Confirm; add exclusion
  if needed.
- `.claude/skills/devshop/pre-ship/SKILL.md` Gate 11 (~line 1021-1026) — the
  convention check runs `check-file-headers.sh main`; covered by that script's audit.
  Confirm Gate 11 prose doesn't separately scan `kit/tests/lib/**`.
- `.claude/skills/devshop/merge-devshop/SKILL.md` — (a) Phase 2 gitleaks scan
  (~line 1025-1064): add `kit/tests/lib/**` to the scan exclusion if the staged-delta
  / range scan would reach the newly-plain vendored files (verify against
  `.gitleaksignore`/`.gitleaks.toml` — prefer excluding via the gitleaks config so
  both the husky and merge paths inherit it); (b) remove the submodule-deinit teardown
  (Step 1, ~line 1397-1459) — plain `git worktree remove --force` suffices.
- `CLAUDE.md` (~line 63) — strip `git -C .worktrees/<topic> submodule update --init
--recursive &&` from the recipe; rewrite the "submodule step populates bats libs"
  trap bullet.
- `kit/docs/guide/architecture.md` (~line 129-135) — strip the submodule step from the
  recipe + remove the submodule explanation paragraph.
- `kit/ROADMAP.md` (~line 463-464) — strip the submodule step from the documented
  recipe + the "submodule update populates vendored tooling" bullet.
- `kit/docs/FAQ.md:46` — confirm "No git submodules. Git-native." reads accurate (no
  edit expected).
- `.gitleaks.toml` / `.gitleaksignore` (if present) — add `kit/tests/lib/**` allowlist
  if the gitleaks audit (above) shows the vendored files trip the scan.

## Tests (bats — `kit/tests/lib/bats-core/bin/bats kit/tests/`)

- **NEW `kit/tests/util-vendor-bats-libs.bats`** (D2 paired test):
  - script exists and is executable
  - `kit/tests/lib/VENDORED-VERSIONS` exists and lists all three libs, each with a
    40-hex-char SHA
  - the runtime subset present on disk matches the script's declared target set (e.g.
    `bats-core/bin/bats`, `bats-core/libexec`, `bats-support/load.bash`,
    `bats-assert/load.bash` all present)
  - non-runtime dirs are absent (`bats-core/test`, `bats-core/docs` not present) — the
    trim is asserted, not just the keep
- **Rewritten `structural-invariants.bats` "BATS runtime files present"** test —
  asserts `kit/tests/lib/bats-core/bin/bats` is executable + each lib's load entry
  reachable, replacing the submodule-init assertion. Failure message points at
  `kit/scripts/vendor-bats-libs.sh`, not `git submodule update`.
- **`structural-invariants.bats` infra_scripts wiring** test (existing, ~line 239) —
  now passes for `vendor-bats-libs.sh` because it's registered (see Gotcha 1).
- **Full suite green before AND after the conversion** (D6) — run
  `kit/tests/lib/bats-core/bin/bats kit/tests/` at the start (baseline), after the
  de-submodule, and after each subsequent task. The full suite passing is the loud
  catch that the runtime trim (D3) didn't drop a needed file.

## Dependencies

- None new. `git` (submodule/worktree mechanics), `bats` (the vendored runner itself —
  bootstraps from the same tree it's converting). No package installs.
- Conversion happens inside this linked worktree; `/devshop` main's shared `.git`
  state is touched only as de-submoduling requires (D6).

## Task order

1. **De-submodule the bats libs (Task 1, D1/D3/D6).** Baseline: run the full bats
   suite (must be green) + `git status` + `git rev-parse --is-inside-work-tree` in
   BOTH this worktree and `/devshop` main — record healthy. For each lib: remove its
   single `.git` pointer file (detach gitlink — NOT `rm -rf`), `git rm --cached
<path>` (drops the gitlink from the index), trim to the runtime subset (D3),
   `git add <path>` the plain files (preserving exec bits). Delete `.gitmodules`.
   Remove the `submodule.*` keys (`submodule.active`, the three
   `submodule.kit/tests/lib/*.url`) from the shared config carefully. Re-verify BOTH
   trees healthy + full suite green. Commit.
2. **Vendor script + manifest + paired test (Task 2, D2).** Write
   `kit/scripts/vendor-bats-libs.sh` (pinned SHAs from D2, runtime subset from D3,
   `.git` strip, `VENDORED-VERSIONS` emit, self-verify via full suite). Write
   `kit/tests/lib/VENDORED-VERSIONS`. Write `kit/tests/util-vendor-bats-libs.bats`.
   Register `vendor-bats-libs.sh` in `structural-invariants.bats` `infra_scripts`
   (~line 239) **in this same PR** (Gotcha 1). Run full suite green. Commit.
3. **Gate exclusions + rewrite the submodule-init invariant (Task 3, D4).** Audit each
   gate (tests-coverage, file-headers, bats-coverage, Gate-11 convention,
   merge-devshop Phase 2 gitleaks) — add `kit/tests/lib/**` exclusion only where the
   audit shows a reach (prefer the gitleaks config for the gitleaks path). Rewrite the
   "BATS submodules are initialized" structural-invariants test to assert plain
   runtime files. Run full suite green. Commit.
4. **Recipe + doc edits (Task 4).** Strip the submodule step from `CLAUDE.md`,
   `architecture.md`, `ROADMAP.md`; rewrite trap prose. Remove the merge-devshop
   submodule-deinit teardown. Confirm FAQ:46 accurate. Run full suite green. Commit.
   (Per the Non-Negotiable: tooling change + doc updates in the same commits as their
   code — Tasks 1-3 each carry their own doc deltas; Task 4 is the remaining
   recipe/skill prose.)
5. **Tracker closure (Task 5, D7).** Split the [HIGH] `kit/TODOS.md` entry: remove the
   config-injection portion; re-file the HEAD-race face as a new `kit/TODOS.md` entry
   preserving its observations + the FRICTION-LOG HEAD-race detail. Unwind cross-refs
   to the config-injection footgun across `kit/docs/` + `CLAUDE.md`. (The
   `PLAN.md` Active-row removal + the FRICTION-LOG `core.bare` recurrence fold into
   `BUILD-LOG.md` happen at `/ak-build` Phase 4.0, not as a spec task — noted here so
   Phase 4.0 carries them.) Commit.

## Gotchas

1. **Worktree-blind structural-invariants wiring test (MUST register in THIS PR).** The
   `infra_scripts` wiring test in `structural-invariants.bats` is `$DEVSHOP`-rooted —
   it scans `/devshop/kit/scripts`, not the worktree's copy. A new script added in the
   worktree is invisible to that test until it lands on `/devshop` main, so it
   **false-passes** Phase 2.5 / Gate 2d in the worktree but **reddens main on merge**.
   Mitigation: register `vendor-bats-libs.sh` in `infra_scripts` in this PR (Task 2),
   and don't trust a green wiring test in-worktree as proof — the merge is where it's
   real. (This is itself a score-8 friction worth a friction-log entry at session end.)
2. **D6 shared-`.git` safety.** `git status` AND `git rev-parse --is-inside-work-tree`
   must succeed in BOTH `/devshop` and this worktree after the conversion (and the full
   bats suite must be green before + after). The whole point of this feature is to stop
   shared-`.git` corruption — the conversion must not itself corrupt it. Verify at
   Task 1 start and end.
3. **No `rm -rf` (sandbox-blocked).** Detach gitlinks by removing the single `.git`
   pointer file per lib, then `git rm --cached`. For trimming non-runtime dirs, use
   plain `rm`/`rm -r` on the specific subtrees (sandbox permits non-`-rf` removals);
   if a removal is blocked, fall back to the `/tmp + sudo install` handoff rather than
   looping on alternative tools (per `CLAUDE.md § Known Footguns` denied-path recipe).
4. **`kit/scripts/**`is a denied-path in the canonical tree but EDITABLE in worktree
copies** (per CLAUDE.md).`vendor-bats-libs.sh`is created in the worktree, so
Write works here. (It only becomes locked once on`/devshop` main.)
5. **The bats runner bootstraps from the tree it converts.** `vendor-bats-libs.sh`
   self-verifies by running `kit/tests/lib/bats-core/bin/bats` — which is the very file
   being vendored. Run the verify step AFTER the copy completes, against the
   freshly-placed runtime files, so the self-check exercises the vendored state.
6. **gitleaks false-positive risk from bats-core fixtures (D3 rationale).** The trim
   removes `bats-core/test/` — its fixtures are the most likely gitleaks trip. Confirm
   `gitleaks protect --staged` (the husky path) passes on the staged conversion delta;
   if anything in the kept runtime subset trips it, allowlist `kit/tests/lib/**` via
   the gitleaks config (Task 3).
7. **Don't drop the HEAD-race observations.** D7 splits face-2 out — the re-filed
   `kit/TODOS.md` entry must preserve the HEAD-race incident detail (Phase 2→2.5 HEAD
   jump, branch-ref deletion + recovery via `git branch -f <name> <dangling-sha>`,
   byte-identical-parallel-work regression hazard) currently living in the [HIGH]
   entry + FRICTION-LOG. Closing the config-injection part must not erase them.

## Acceptance

- `.gitmodules` is gone; `git config --get-regexp '^submodule\.'` on the shared config
  returns nothing.
- `kit/tests/lib/bats-{core,support,assert}` are plain tracked files (no gitlink, no
  `.git` pointer); `git ls-files kit/tests/lib/` lists real files, not gitlink entries.
- The runtime subset is present (each lib's `load`/`bin` entry) and non-runtime dirs
  (`test/`, `docs/`, `man/`, etc.) are gone.
- `kit/tests/lib/bats-core/bin/bats kit/tests/` passes the FULL suite (green), including
  the rewritten runtime-files invariant and the new `util-vendor-bats-libs.bats`.
- `vendor-bats-libs.sh` exists, is executable, is registered in `infra_scripts`, and
  `VENDORED-VERSIONS` lists all three pinned SHAs.
- The worktree-add recipe in `CLAUDE.md`, `architecture.md`, `ROADMAP.md` no longer
  contains `submodule update --init --recursive`; trap prose updated.
- `merge-devshop` SKILL no longer has the submodule-deinit teardown.
- BOTH `/devshop` and the worktree pass `git status` + `git rev-parse
--is-inside-work-tree` after conversion (D6).
- No devshop gate (pre-commit, pre-ship, merge gitleaks) flags the vendored files.
- The [HIGH] `kit/TODOS.md` config-injection entry is closed; a new HEAD-race entry
  exists preserving the observations; FRICTION-LOG `core.bare` entry is removed (folded
  into BUILD-LOG at Phase 4.0); no dangling cross-refs to the config-injection footgun.

## Rollback

- This is a VCS-structure change with no runtime/prod surface, so rollback is `git
revert` of the squash commit (or `git reset` of the feature branch before merge).
  Reverting restores `.gitmodules` + the gitlinks; a follow-up `git submodule update
--init --recursive` re-hydrates the submodule working dirs. Because the pinned SHAs
  (D2) match the previously-vendored commits, the restored submodule state is identical
  to pre-PR.
- Mid-conversion abort (Task 1 fails the BOTH-trees-healthy check): restore the `.git`
  pointer files + `.gitmodules` from `git`, `git submodule update --init`, re-verify
  both trees, and re-plan — do NOT leave the shared config half-converted across a
  session boundary (D6).
- No data migration, no deploy, no canary — nothing to roll back beyond the commit.
