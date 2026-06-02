# Friction Log

Intake ledger for recurring friction, trip-ups, and devshop-generalizable
lessons that sessions hit. This is the **funnel upstream of the backlog**: raw
friction lands here first (deduped + counted + session-linked), and the operator
promotes the items worth acting on into `kit/ROADMAP.md` (strategic),
`kit/TODOS.md` (tactical), or `PLAN.md` (scheduled) when appropriate.

**Why a separate ledger and not just TODOS:** TODOS/ROADMAP are commitments —
things we intend to do. This log is _observation_ — things that keep going
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
  observation record _while the work is in flight_ — the count history is the
  evidence the promotion was earned). When the underlying fix actually ships,
  **delete the entry from this log** and fold its unique recurrence info (the
  count + any notable per-session detail worth keeping) into the `BUILD-LOG.md`
  entry for the fix — the BUILD-LOG becomes the permanent history home. This
  keeps the friction log to live observations only. Unwind per
  `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`.

## Entry schema

Each entry is one `### ` heading. Fields:

- **Score** — `impact × count` (the sort key; recomputed on every bump).
- **Impact** — 1–5 on the `PLAN.md` rating scale (XS=1, S=2, M=3, L=4, XL=5):
  the severity _if it recurs_, not the severity of one occurrence. One-line why.
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
most-recently-seen. Highest-scoring friction is always at the top. The log holds
only live observations — `open` and in-flight `promoted →` entries. When a fix
ships, its entry is deleted (its history folds into `BUILD-LOG.md`), so there is
no `resolved`/archive section here.

<!-- entries below, highest score first -->

## Open

### A doc/SKILL.md or source edit can silently drift a `grep`-based bats test

- **Score**: 15 (impact 3 × count 5)
- **Impact**: 3 (M) — grep-based bats tests are brittle against the text they assert (doc prose OR source code), in BOTH directions: an edit that changes asserted text turns the suite red silently (until the next full-suite run), and a test that _under_-asserts lets a future edit silently drop the very coverage it was meant to pin and ship green. Recurs on the common doc/prompt/script-editing path.
- **Count**: 5
- **Status**: promoted → `kit/TODOS.md` ("Guard against `grep`-based bats tests drifting…") + `PLAN.md § Planned (v0)` (`grep-test-drift-guard`), 2026-06-02. Kept here as the recurrence record while the fix is in flight.
- **First seen**: 2026-05-28 (`1d343bf`, surfaced via parallel `/ak-merge-devshop` runs)
- **Sessions**:
  - 2026-05-28 — `1d343bf` updated 9 docs but missed the asserting test; a red suite reached main.
  - 2026-05-30 — `claude-md-condense` Audit 1 (tests, low): the capture-the-prompt test (`util-adversarial-review-narrowing.bats`) pins the `CLAUDE_MD_SECTIONS` section list + forwarded reason but does NOT assert the rubric prose body reaches the assembled prompt — so a future CLAUDE.md-condense pass could silently drop the new rubric (f) "Reachability split" lines and ship green. Inverse flavor of the 2026-05-28 instance (under-assertion → silent drop, vs assertion-drift → red).
  - 2026-05-30 — `merge-devshop-worktree-hooks` build, Audit 2 (tests, low): the new Phase 3 ordering test in `util-ak-merge-devshop.bats` (~l.877–887) anchors the ff-merge gitleaks line with `grep … | head -1`, but the anchor matches TWICE in the Phase 3 range (the real code line AND a recovery-prose sentence). Correct at HEAD (code line sorts first), but if the code line were removed the prose line still matches → silent pass (under-assertion flavor again). Shipped as a noted-LOW (squash `4085ec6`); suggested tightening: anchor on a unique code-form token.
  - 2026-05-31 — `propagation-skip-noop` focused fix: inserting the new NOTE-3 tag-FAIL paragraph into `adversarial-review.sh`'s prompt wrapped the literal phrase `"If the list is EMPTY"` (grepped by test 16 in `util-adversarial-review-narrowing.bats`) across a line break → test went red. Worked around by keeping the phrase on one line; the brittle literal-grep-against-prose coupling is the recurring root. Assertion-drift flavor.
  - 2026-06-02 — `init-devshop-mtime-bump` (`c6be31e`) changed `init-devshop.sh`'s firewall-extras re-lock to a `stat`-drift guard and updated `manifest-lifecycle.bats`, but missed the sibling static-grep assertion in `firewall-extras-overlay.bats` (test #14, still asserting the old unconditional pattern) → red `main`, undetected until the NEXT merge's Phase 2.5 (`docs/init-firewall-demote-to-friction`) caught it. **Source-edit trigger** (prior instances were doc/prompt edits — this confirms the same drift fires when a `.sh` changes); fixed on `fix/firewall-extras-test-stale` (`c3450fa`). Assertion-drift flavor.
- **Symptom**: a `grep`-based bats test and the prose it asserts drift apart with no mechanism linking them — either an edit removes/rewrites asserted text (test goes red, ships silently until the next full-suite run) OR the test under-asserts so a later edit silently drops the pinned content and ships green.
- **Detail**: Layer-1 test-presence hooks catch _missing_ tests, not _stale_ or _under-scoped_ ones. Worked observations: (a) `1d343bf` (2026-05-28) updated 9 docs but missed the asserting test — test 14 in `util-build-phase58-audit-parser.bats` (a stale Phase 6 audit-comment assertion from ancestor `486a57d`) went red once `1d343bf` removed the asserted "Pre-ship audit | gates passed" text, and a red suite reached `main`. (b) `claude-md-condense` (2026-05-30) — the capture-the-prompt test asserts the section-list + reason but not the rubric prose body, leaving rubric (f) unpinned. (c) `c6be31e` (2026-06-02) made `init-devshop.sh`'s firewall-extras re-lock conditional on a `stat`-drift check but left `firewall-extras-overlay.bats` test #14 grepping the old unconditional pattern — a **source** edit (not doc/prompt) drifting its asserting test, red `main` caught only by the next merge's full-suite gate. **Cheap per-case fix (b)**: add one `grep -q "Reachability split"` assertion to the existing capture test. **Structural fix shape**: a `structural-invariants.bats` check that maps SKILL/prompt-asserting tests to their source files, OR a `conventions.md` note requiring co-update of a doc and any test asserting its content.
- **Promotion target**: `kit/TODOS.md` (structural-invariants mapping check or conventions.md co-update note; plus the one-line `grep -q "Reachability split"` assertion).

### Devshop kit scripts ship a red `main` when a new skill-invoked script isn't added to the wiring allow-list

- **Score**: 8 (impact 4 × count 2)
- **Impact**: 4 (L) — a red `structural-invariants.bats` wiring test on `main` blocks the Phase 2.5 / Gate 2d full-suite gate of _every_ in-flight merge until someone fixes it; recurs whenever a new skill-invoked (not hook-wired) kit script lands without being registered.
- **Count**: 2
- **Status**: promoted → `kit/TODOS.md` ("Auto-detect skill-invoked kit scripts in the wiring test…") + `PLAN.md § Planned (v0)` (`wiring-test-skill-autodetect`), 2026-06-02. Kept here as the recurrence record while the fix is in flight.
- **First seen**: 2026-05-27 (`bebda21`, three `kit/scripts/preship/` scripts)
- **Sessions**:
  - 2026-05-27 — `bebda21` added three `kit/scripts/preship/` scripts without registering them in the wiring accounting; the full suite went red mid-stream and reached `main`.
  - 2026-05-29 — `ca4bc76` added `reconcile-task-commits.sh` (skill-invoked from `/ak-build` Step 0 + `/ak-implement`) without adding it to the wiring test's `infra_scripts` allow-list; red `main` surfaced during `claude-md-regrowth-prune` Phase 2.5; fixed in `bb3e13c`.
- **Symptom**: the `structural-invariants.bats` test "every non-exempt kit script is wired into a hook or pre-commit" goes red because a new `kit/scripts/**` file is neither hook-wired, exempt, nor in the hand-maintained `infra_scripts` allow-list — and it reaches `main` because the per-commit hook only runs the affected-subset, not the full suite.
- **Detail**: The wiring test enumerates every `kit/scripts/**.sh` and requires each to be hook-wired OR in the `exempts` list OR in the in-test `infra_scripts` string. Skill-invoked helpers (called from a SKILL.md prompt, not a hook) must be hand-added to `infra_scripts` or the test red-flags them. Two instances so far (`bebda21`, `ca4bc76`); the closely-related asserted-text-drift flavor is logged separately ("A doc/SKILL.md edit can silently drift a `grep`-based bats test"). **Candidate fix**: make the wiring test auto-detect skill invocation — grep `.claude/skills/**/SKILL.md` for the script's basename and treat a hit as "wired (skill-invoked)" — so a new skill-helper is covered without an allow-list edit. **Defense-in-depth already shipped**: `/ak-merge-devshop` Phase 2.5 now derives its verdict from a `grep -c '^not ok'` count (not the green tail), so a mid-stream red can't false-pass; that catches the red but doesn't prevent it landing via a direct commit.
- **Promotion target**: `kit/ROADMAP.md` (auto-detect skill-invocation in the wiring test) or `kit/TODOS.md`.

### `git worktree`/`submodule update` flips `core.bare=true` on the shared `/devshop/.git/config`, breaking later merges

- **Score**: 8 (impact 4 × count 2)
- **Impact**: 4 (L) — silently corrupts the shared `/devshop/.git/config` so the canonical `/ak-merge-devshop` Phase 3 (`git checkout main` / `git merge --ff-only`) fails mid-merge with a misleading `fatal: this operation must be run in a work tree`; read-only git ops keep working, so it masquerades as a partial-git failure far from its cause. Sibling of the already-[HIGH] `core.worktree`-injection footgun (same root-cause family).
- **Count**: 2
- **Status**: promoted → enriched [HIGH] `kit/TODOS.md` entry ("Worktree submodule-update injects `core.worktree`…", now also covers `core.bare` + the HEAD-race face) + `PLAN.md § Planned (v0)` (`worktree-shared-config-corruption`), 2026-06-02. Kept here as the recurrence record while the fix is in flight.
- **First seen**: 2026-05-31 (`skip-bats-docs-only` /ak-build, worktree-based)
- **Sessions**:
  - 2026-05-31 — `skip-bats-docs-only` build in `.worktrees/skip-bats-docs-only`; surfaced only at `/ak-merge-devshop` Phase 3, where `git checkout main` / `git merge --ff-only` failed with "must be run in a work tree"; `git config --local --get core.bare` returned `true`; fixed in-place with `git config --local core.bare false` (no restart), merge then completed cleanly.
  - 2026-06-01 — `init-devshop-mtime-bump` /ak-build in `.worktrees/init-devshop-mtime-bump`; injected at the `git -C .worktrees/… submodule update` step. Did NOT break the pipeline itself (every working-tree op ran via `git -C <worktree>`, which stayed functional), so it surfaced only post-merge at the reflection beat when a plain `git status` in `/devshop` failed `must be run in a work tree`; `git worktree list` had also started showing `/devshop (bare)`. It had also been silently breaking the parallel session holding `/devshop`. Fixed in-place with `git config core.bare false`. **(The "parallel session holding `/devshop`" was an `/ak-merge-devshop` of `init-firewall-demote` running in the SHARED main tree — it hit `core.bare` mid-flow AND, beyond config injection, the concurrent worktree session's branch-`checkout`s moved `/devshop`'s shared HEAD out from under it twice (forking its branch off a stray parallel commit, then jumping HEAD between merge Phase 2 and Phase 2.5) and its feature-branch ref was deleted outright; the orphaned commit was recovered from the object DB via `git branch -f <name> <sha>`. Same injection event, observed from the broken side — count not bumped. See Detail "Wider blast radius" for the HEAD-race manifestation + mitigation.)**
- **Symptom**: `git checkout` / `git merge` / `git rev-parse --show-toplevel` fail with `fatal: this operation must be run in a work tree` on a tree that is verifiably present (pwd works, files there), while read-only ops (`rev-list`, `log`, `branch --show-current`) and `gitleaks` keep working. `git rev-parse --is-inside-work-tree` returns `false`. Confirm via `git config --local --get core.bare` → `true`.
- **Detail**: During a linked-worktree `/ak-build` the `git worktree add` + `git -C .worktrees/<topic> submodule update --init --recursive` flow flipped `core.bare = true` on the SHARED `/devshop/.git/config` (the main worktree's config). Because the flag lives in the shared config, `/devshop`'s own `main` checkout becomes "bare" in git's eyes — every write op (`checkout`, `merge`, `commit`) refuses while reads succeed, so the failure surfaces far from its cause (here: only at the merge's Phase 3, long after the worktree work that injected it). **In-place fix (no restart)**: `git config --local core.bare false`. This is a SIBLING manifestation of the [HIGH] `kit/TODOS.md` entry "Worktree submodule-update injects `core.worktree` into the shared `/devshop/.git/config`" — same root cause (a worktree/submodule op writing bad config to the shared config), different key (`core.bare` vs `core.worktree`) and different symptom (merge "must be run in a work tree" vs phantom git-status + GitHub Desktop "can't find repo"). **Wider blast radius (2026-06-02)**: the root cause — a SECOND session sharing the single `/devshop` working tree — also bites WITHOUT any config-key injection. A parallel session's plain `git checkout` moves `/devshop`'s shared HEAD, so an in-flight session can silently lose its feature-branch ref, fork a new branch off a stray parallel commit, and have an `/ak-merge-devshop` run race the parallel HEAD between phases (observed Phase 2 → Phase 2.5: HEAD jumped from the squash to the parallel new-main mid-gate). A related second-order hazard: two sessions independently doing the same task produced byte-identical work, and the late-arriving session's rebase would have _regressed_ features the first had already shipped — caught only by a rebase conflict before clobbering. **Strongest mitigation (covers config-injection AND HEAD-race faces)**: do devshop feature work in a linked worktree (own HEAD, immune to shared-HEAD mutation) FROM THE START — never run `/ak-merge-devshop` in the shared `/devshop` main tree during a parallel-session window. **Candidate fix**: the permanent-fix recipe proposed in that `kit/TODOS.md` entry (scrub the injected key after the submodule step; `session-start.sh` detection + auto-clear) should cover BOTH keys — e.g. `git config --local --unset core.worktree; git config --local core.bare false` after `submodule update`, plus a session-start guard that detects either key set wrongly on `/devshop/.git/config`.
- **Promotion target**: enrich the existing [HIGH] `kit/TODOS.md` entry ("Worktree submodule-update injects core.worktree…") to also scrub/detect `core.bare`; add a `CLAUDE.md § Known Footguns` first-action line ("merge fails `must be run in a work tree` → check `git config --local core.bare`"). Also fold in the HEAD-race face (a `CLAUDE.md` directive: run devshop feature work — especially `/ak-merge-devshop` — in a linked worktree with its own HEAD, never the shared `/devshop` main tree, whenever a parallel session may be active).

### `$DEVSHOP`-hardcoded reads are worktree-blind — tests-coverage hook false-blocks, the wiring/Phase-2.5 gate false-passes (masks a red main)

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — **bumped from 3 this session** after the worse failure mode was confirmed. The originally-recorded direction is a false-BLOCK (loud, recoverable: forces a `testsCoverageReason` bypass; the instinctive `DEVSHOP`-override "fix" is destructive). The newly-confirmed direction is a false-PASS: `structural-invariants.bats`'s wiring test reads `$DEVSHOP/kit/scripts` = the main worktree, so the Phase 2.5 / Gate 2d "full bats before landing" gate reports green for a new-script worktree build and lets a **red `main` ship undetected** — same red-main-blocks-every-in-flight-merge blast radius as the score-8 registration entry, but silent. A safety gate with a hole is L.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-06-01 (`feat/ak-check-docs-orphan-stubs`, this session)
- **Sessions**:
  - 2026-06-01 — same session, two manifestations of the one root cause. (a) **false-block**: `/ak-implement` in `.worktrees/ak-check-docs-orphan-stubs` staged `kit/scripts/preship/audit-tracker-only.sh` + its paired `kit/tests/util-audit-tracker-only.bats` (green), but `check-tests-coverage-devshop.sh` BLOCKED ("new — needs test file") because it greps `$DEVSHOP/kit/tests` = `/devshop`, where the worktree-only `.bats` doesn't exist; committed with a specific `testsCoverageReason`. (b) **false-pass** (merge phase): every Phase 2.5 run of that build reported `1626 passed / 0 failed`, but `structural-invariants.bats`'s wiring test reads `$DEVSHOP/kit/scripts` (= `/devshop`, which didn't yet have the new script) — so it never saw `audit-tracker-only.sh` and never flagged it as un-allow-listed. `main` went red the instant the script merged (`bf1cb7a`), caught only by the NEXT merge's Phase 2.5 once the script was on `/devshop`; fixed by adding it to `infra_scripts` (`f915ce8`).
- **Symptom**: on the parallel-worktree path, a `$DEVSHOP`-hardcoded read can't see worktree-only files. Two directions: `check-tests-coverage-devshop.sh` false-BLOCKS a commit whose paired `.bats` is worktree-only; and `structural-invariants.bats`'s wiring test (and thus the Phase 2.5 full-bats gate) false-PASSES on a new worktree-only `kit/scripts/**.sh` because it scans `/devshop`'s tree, not the worktree's — green verdict, red main.
- **Detail**: Root cause is shared: a commit hook / bats test resolves a path as `$DEVSHOP/<dir>` with `DEVSHOP="${DEVSHOP:-/devshop}"`, but a linked worktree's `kit/` is a real directory (not a symlink), so any worktree-only file under it is invisible to the `/devshop`-rooted read. **(a) tests-coverage false-block**: `check-tests-coverage-devshop.sh:17-18` sets `TESTS_DIR="$DEVSHOP/kit/tests"` and greps `$TESTS_DIR/*.bats` → a worktree-only `.bats` reads as absent → false block. **Destructive non-fix (DO NOT)**: overriding `DEVSHOP=<worktree>` corrupts the repo — the husky affected-bats runner also reads `$DEVSHOP`, and the bats fixture (`create_test_repo`) then ran git ops against the real worktree, committing throwaway fixture commits (`initial`/`baseline`/`change`) ON TOP of real HEAD and rewriting tracked files. **Recovery**: back created files up to `/tmp`, `git reset <real-HEAD>` (mixed — NOT `--hard`, DCG-blocked), restore. **(b) wiring/Phase-2.5 false-pass** (confirms this entry's earlier "likely affects other scripts" prediction): `structural-invariants.bats`'s wiring test enumerates `$DEVSHOP/kit/scripts/**.sh`; run from a worktree build it scans `/devshop` (no new script) → reports green → the Phase 2.5 gate's whole "no red main before landing" guarantee has a hole for the new-script worktree case, and it pairs with the score-8 registration gap to ship a red main silently. **Candidate fix (one shape, both directions)**: resolve the tree from the checkout actually under test — `git rev-parse --show-toplevel`, or the `$BATS_CWD`/worktree path the Phase 2.5 gate already computes for its SHA-pin — instead of hardcoding `/devshop`. Mirrors how `util-check-docs-and-tests.bats` already derives `SKILL_FILE` worktree-correctly. Same shape likely also affects `check-docs-coverage-devshop.sh` + the affected-bats runner. References `kit/scripts/commit-hooks/check-tests-coverage-devshop.sh:17-18`, `kit/tests/structural-invariants.bats` (wiring test), `.claude/skills/ak-build/SKILL.md` + `.claude/skills/ak-merge-devshop/SKILL.md` § Phase 2.5, and the husky pre-commit affected-bats runner.
- **Promotion target**: `kit/TODOS.md` (worktree-resolve the tree in the tests-coverage hook, the affected-bats runner, AND the `structural-invariants.bats` wiring test / Phase 2.5 gate — derive from the checkout under test, not `$DEVSHOP`) + a `CLAUDE.md § Known Footguns` note on the destructive `DEVSHOP`-override trap.

### `/ak-merge-devshop` ignores `--branch` / worktree detection when `/devshop` isn't on `main` (can squash-merge the WRONG branch)

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — a wrong-branch squash to `main` is high-blast-radius, and the linked-worktree parallel-work flow is the documented norm, so a parallel session holding `/devshop` off `main` is a realistic trigger.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-06-01 (`init-devshop-mtime-bump` /ak-build, worktree-based)
- **Sessions**:
  - 2026-06-01 — `/ak-build` of `init-devshop-mtime-bump` in `.worktrees/init-devshop-mtime-bump`. A parallel session had switched `/devshop` onto `docs/init-firewall-demote-to-friction` mid-pipeline; at Phase 4.5 the no-arg `/ak-merge-devshop` (and even an explicit `--branch fix/init-devshop-mtime-bump`) would have fallen through to `BRANCH=$CURRENT` and squash-merged the parallel branch. Recognized manually and switched to `--source-worktree` mode, which pushed the squash straight to `origin/main` from the worktree without touching `/devshop`'s branch.
- **Symptom**: when `/devshop` is checked out on a feature branch (e.g. a parallel session's), `/ak-merge-devshop` Phase 0.1 takes the legacy `BRANCH=$CURRENT` path and silently ignores a passed `--branch`; a no-arg invocation from `/ak-build` Phase 4.5 would squash-merge whatever `/devshop` happens to be on, not the worktree feature.
- **Detail**: Phase 0.1's worktree-detection + `--branch` disambiguation live ONLY inside the `CURRENT == main` arm. The `--source-worktree <path>` flag is the sanctioned escape hatch for exactly this (operate against the named worktree, push `git -C <worktree> push origin HEAD:main`), but nothing auto-selects it — a passed `--branch` is a silent no-op off-main, and `/ak-build` Phase 4.5 invokes the merge with no args. **Candidate fix**: (1) in `/ak-merge-devshop` Phase 0.1, when `--branch`/`--source-worktree` names a worktree branch ahead of `origin/main`, honor it regardless of `$CURRENT` (a named worktree should be authoritative); and/or (2) have `/ak-build` Phase 4.5 pass `--source-worktree $WORKTREE_PATH` explicitly when it ran in a worktree, instead of relying on no-arg auto-detection. Edit targets: `.claude/skills/ak-merge-devshop/SKILL.md § Phase 0.1`, `.claude/skills/ak-build/devshop-mode.md § Phase 4.5`.
- **Promotion target**: `kit/TODOS.md` (honor `--branch`/`--source-worktree` off-main in Phase 0.1; pass `--source-worktree` from `/ak-build` Phase 4.5).

### Pre-commit hooks don't fire in linked worktrees (husky uninstalled), silently skipping every gate

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — every pre-commit gate (branch guard, gitleaks secret-scan, tests-coverage, CLAUDE.md classification/placement) is silently skipped for commits made in a `.worktrees/<topic>` worktree where the recipe's `pnpm install` was skipped. Recurs on the encouraged parallel-work path.
- **Count**: 1
- **Status**: shipped (b)+(d) via `feat/merge-devshop-worktree-hooks` (2026-05-30; squash on main resolvable via `git log --grep=merge-devshop-worktree-hooks`, full record in `BUILD-LOG.md`); (c) session-start `.husky/_` warning remains an optional follow-up
- **First seen**: 2026-05-29 (`feat/claude-md-placement-gate` worktree, this session)
- **Sessions**:
  - 2026-05-29 — building the CLAUDE.md placement gate in `.worktrees/claude-md-placement-gate`; two commits landed with zero hook execution; the new gate only ran when invoked manually (`bash kit/scripts/commit-hooks/check-claude-md-classification.sh` after `git config devshop.claudeMdClassification …`).
- **Symptom**: commits made inside a `git worktree add .worktrees/<topic>` worktree run NO pre-commit hook — no branch guard, no gitleaks, no tests-coverage, no CLAUDE.md classification. `git config --get core.hooksPath` returns `.husky/_` (relative), but that dir is empty in the worktree and `node_modules/husky` is absent.
- **Detail**: `.husky/_/` is generated by husky's `prepare` script on `pnpm install` and is `.gitignore`d, so a freshly `git worktree add`-ed tree has an empty `core.hooksPath` and no `node_modules` — every pre-commit/pre-push hook is a no-op in the worktree until the recipe's `pnpm install` runs. **Shipped** in `feat/merge-devshop-worktree-hooks`: (b) the `CLAUDE.md § Parallel work via linked worktrees` worktree-add recipe now appends `&& (cd .worktrees/<topic> && pnpm install)`, which regenerates `.husky/_` + populates `node_modules` so hooks fire in-worktree; (d) `/ak-merge-devshop` Phase 2 now runs `gitleaks protect --staged --redact` on the staged squash delta (between the soft-reset and `commit -F`, cwd-pinned to the worktree) as an unconditional net for an off-convention worktree that skipped the install step. The doc-accuracy half landed in the same PR: the CLAUDE.md bullet, the merge-devshop SKILL.md Phase 2 prose, and `kit/docs/guide/security.md:58` now describe the install-step-dependent + Phase-2-gitleaks-net posture. **Residual (c), optional follow-up**: have `session-start.sh` detect a devshop worktree with an empty `.husky/_` and warn — a nice-to-have early-signal, not a gate (b)+(d) already cover the on- and off-convention paths. References `CLAUDE.md § Parallel work via linked worktrees` + `.husky/` + `kit/scripts/session-start.sh`.
- **Promotion target**: (c) session-start `.husky/_` warning → `kit/ROADMAP.md` if/when picked up. (b)+(d) shipped.

### Mac host-resource constraints suspected as the real cause of `blocked` QA outcomes

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — if confirmed, the host-resource pressure recurs across every browser-gate run on a loaded Mac, and the shipped workspace-tooling fixes (Chromium apt-bake, env-aware Supabase ports) don't address it — an ongoing recurring tax masquerading as tooling gaps.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-19 (`sandbox-qa-close-gap` PR, codifying home-os PR #27/#28)
- **Sessions**:
  - 2026-05-19 — `sandbox-qa-close-gap`; operator pushback flagged host-resource hypothesis over the tooling-gap framing.
- **Symptom**: browser gates / QA on lalista + home-os run fine for many PRs, then start emitting `blocked` outcomes — correlated with host Mac resource pressure (Docker Desktop Resource Saver, swap, heavy host apps), not a tooling-not-installed cause.
- **Detail**: Codified 2026-05-19. Original ROADMAP framing attributed home-os PR #27/#28 `blocked (n/a per scope: sandbox)` outcomes to workspace tooling gaps; operator pushback: "QA was working on many PRs… until it didn't, and it seemed to be about resource constraints on my host Mac." **What to investigate**: (1) re-read PR #27/#28 audit comments — was `blocked` reason "Chromium failed to launch" / OOM / "Playwright timeout waiting for browser" (resource pressure) or tooling-not-installed? (2) cross-correlate failure timestamps with Docker Desktop Resource Saver activity, macOS `vm_stat` swap, heavy host apps; (3) controlled test — rebuild home-os devcontainer with all gates intact, close every other macOS app, run `/ak-pre-ship` on a no-op branch; clean pass confirms the hypothesis. **Likely fixes if confirmed (pick one)**: (a) Docker Desktop memory cap bump; (b) concurrency cap in-container (`--max-workers=2`, Playwright `workers:1`); (c) `/ak-pre-ship` preflight resource check emitting `findings(1)` when free memory < threshold. Cross-ref: `sandbox-qa-close-gap` only fixed the iptables port issue; `kit/notes/projects/home-os.md` for PR #27/#28 details.
- **Promotion target**: `kit/ROADMAP.md` (once hypothesis confirmed/refuted, with a concrete fix shape) — until then a debugging breadcrumb.

### Phase 2 soft-reset silently re-anchors when origin/main moves mid-merge

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — a core merge skill can land phantom file deletions on
  `main`, silently reverting/deleting _another_ feature's committed work.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`ak-build-commit-spec-expansion` merge, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` Phase 4.5 merge of `ak-build-commit-spec-expansion`; caught pre-push.
- **Symptom**: the Phase 2 squash commit shows `delete mode` for files that
  belong to a _different_, parallel feature (e.g. `specs/<other-feature>/…`) —
  files this branch never touched. Surfaces in the `git commit` output's
  create/delete listing, or via `git diff --diff-filter=D origin/main..HEAD`.
- **Detail**: `/ak-merge-devshop` Phase 1.0 rebases the branch onto `$ANCHOR`
  (origin/main at that moment), then Phase 2 **re-resolves `$ANCHOR=origin/main`
  live** and soft-resets onto it. If origin/main _advanced_ between 1.0 and 2
  (a parallel merge pushed), Phase 2 anchors onto the **new** tip while the
  branch content still descends from the **old** one — so the staged squash
  delta phantom-deletes (and reverts) everything the new base added. The
  skill's "anchor-mismatch caveat" claims Phase 3's `git merge --ff-only`
  catches this, but it does **not**: the squash's parent _is_ the new base, so
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

### Interrupted `git commit` on virtiofs corrupts the shared object DB

- **Score**: 4 (impact 4 × count 1)
- **Impact**: 4 (L) — an interrupted commit can poison the SHARED `/devshop/.git` object store, so EVERY later git command (in the worktree and the main checkout) throws `fatal: unable to read <sha>`; recovery is non-obvious and the instinctive `rm .git/.../index` is (rightly) auto-denied. Recurs on the common commit path under the virtiofs instability already documented for rebase.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-31 (virtiofs-rebase-auto-switch fresh-eyes verification)
- **Sessions**:
  - 2026-05-31 — virtiofs-rebase-auto-switch verification; three aborted commit attempts (a parallel-tool abort during the hook, a tests-coverage block, a rejected classification reason) left ~339 missing-blob refs; recovered with `git read-tree --reset HEAD` then re-committed clean (`c419797`).
- **Symptom**: after an aborted/interrupted `git commit`, every git command throws `fatal: unable to read <sha>` and `git fsck` shows hundreds of "missing blob" refs — including blobs for pre-existing files that were only ever in the uncommitted index.
- **Detail**: On a virtiofs-backed devcontainer, an in-flight `git commit` that is aborted/interrupted (a PreToolUse parallel-abort during the pre-commit hook run, or chaining `cd <worktree>` before `git commit` which trips check-hook-bypass mid-commit) can lose just-written loose objects to a partial fsync, corrupting the SHARED `/devshop/.git` object DB the index references — and because linked worktrees share that store, a worktree commit can poison the main checkout too. **Key insight**: committed history (`HEAD^{tree}`) survives — only the half-written UNCOMMITTED staged objects are lost. **Non-destructive recovery**: `git read-tree --reset HEAD` rebuilds the worktree index from the intact HEAD (do NOT `rm .git/.../index` by hand — correctly auto-denied as .git-internals surgery; read-tree is the safe equivalent), then re-stage + recommit; fsck clean afterward. **Prevention**: run a commit as a single atomic Bash call; never chain `cd <worktree>` before `git commit`; don't interrupt an in-flight commit on virtiofs. Sibling to the documented virtiofs rebase phantom (same stat-cache/fsync root cause, different surface).
- **Promotion target**: `CLAUDE.md § Known Footguns` (recovery recipe) or `kit/docs/guide/hooks.md § Practical recipes` (sibling to the vanished-stash recipe).

### zsh doesn't word-split unquoted `$STRING` in orchestrator-authored loops (e.g. Phase 3.3 concat)

- **Score**: 4 (impact 2 × count 2)
- **Impact**: 2 (S) — silent: `for x in $STRING` iterates once over the whole string (zero file matches), so a hand-authored concat/loop no-ops without error. Caught at review-assembly time, but recurs whenever an orchestrator hand-writes a loop over a space-joined string (the GIT_CMD array convention covers one call-site, not the general pattern).
- **Count**: 2
- **Status**: open
- **First seen**: 2026-05-29 (`merge-devshop-phase25-tree-pin` /ak-build)
- **Sessions**:
  - 2026-05-29 — `/ak-build` Phase 3.3 (devshop mode); `for g in $ORDER` over a space-joined gate-name string matched zero sink files (treated the whole string as one filename), producing an empty gate roster in `review.md` until switched to an array.
  - 2026-06-01 — `/ak-build` Phase 3.3 (devshop mode, `ak-check-docs-orphan-stubs` in a worktree); the EXACT same `for g in $ORDER` gate-sink concat no-op recurred independently — `grep` showed only the audit header, zero `## Gate` sections — until switched to `ORDER=(…)`. Second independent hit confirms the prose-without-array-example gap is real, not a one-off.
- **Symptom**: an orchestrator-authored bash loop `for x in $STRING; do ... "$DIR/$x.md" ...` (over a space-joined string var) silently does nothing useful in zsh — the Bash tool's shell is zsh, which does NOT word-split an unquoted scalar; the loop runs once with `x` = the entire string.
- **Detail**: `devshop-mode.md § Concatenation + handoff` describes the Phase 3.3 gate-sink concatenation in prose ("concatenate all 19 gate sinks") with no array-shaped bash example, so an orchestrator naturally reaches for `for g in $ORDER` — which works in bash but no-ops in zsh. Same root cause the `GIT_CMD` array-vs-string convention already documents for ONE call-site, but the general "use an array for any multi-item iteration in orchestrator bash" rule isn't stated where the concat loop is authored. **Candidate fix**: add an array-shaped example (`ORDER=(docs-check …); for g in "${ORDER[@]}"`) to `devshop-mode.md § Concatenation + handoff`, or a one-line "zsh: iterate arrays, not space-joined strings" note; optionally a tiny `concat-gate-sinks.sh` helper. References `.claude/skills/ak-build/devshop-mode.md § Concatenation + handoff`.
- **Promotion target**: `kit/TODOS.md` (array example / one-line zsh note in `devshop-mode.md § Concatenation`).

### Denied-path `sudo install` recipe is blocked by the auto-mode classifier and defaults to the wrong file mode

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — bites every time a new locked file is authored under `kit/scripts/**` (a routine op when adding a commit-hook guard). The recipe as written (`kit/docs/guide/security.md § Authoring locked files`) fails twice before landing: the `sudo install` is denied, and the example mode (or an instinctive `-m 755`) trips a tracked-mode invariant AND blocks the downstream merge's `git checkout main`. Loud at each step, but each failure costs a full gate/handoff cycle.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-06-02 (`feat/guard-fixture-identity` — shipped `check-not-test-identity.sh`, merged `61de613`)
- **Sessions**:
  - 2026-06-02 — authoring `kit/scripts/commit-hooks/check-not-test-identity.sh` (the git-fixture-identity guard). (a) `sudo install -m 755 -o root -g root /tmp/… kit/scripts/commit-hooks/…` was DENIED by the auto-mode classifier ("routing around the `Write(/devshop/kit/scripts/**)` deny rule by switching tools") → required an operator `!`-prefix handoff. (b) the `-m 755` install made the git-tracked mode `100755`, turning `structural-invariants.bats` "wiring: all kit/scripts/\*.sh tracked as 644" red; fixed the tracked mode with `git update-index --chmod=-x`, but the on-disk root-owned file stayed 755, so the working tree showed mode-dirty and `/ak-merge-devshop` Phase 3's `git checkout main` aborted ("commit your changes or stash them") — requiring a SECOND operator handoff (`sudo chmod 644`) since node can't chmod a root-owned file.
- **Symptom**: the `/tmp + sudo install` denied-path recipe can't run autonomously (classifier denies `sudo install` into `kit/scripts/**`), and `install -m 755` for a bash-invoked script later fails the 644 tracked-mode invariant test AND leaves a mode-dirty root-owned file that blocks `git checkout main` mid-merge.
- **Detail**: Two defects in the same recipe (`kit/docs/guide/security.md § Authoring locked files (denied-path recipe)` + the `CLAUDE.md § Known Footguns` denied-path entry). **(1) Not autonomous**: the recipe says "switch to the `/tmp + sudo install` handoff immediately," but the auto-mode permission classifier treats `sudo install` into a `Write`-denied path as a tool-switch bypass and denies it — so the step is an OPERATOR action (run via `! sudo install …` or approve), not something Claude can do. The recipe should say so and emit the exact `! sudo install …` line to hand off. **(2) Wrong default mode**: kit scripts are invoked via `bash script.sh`, so they MUST be tracked `644` (enforced by `structural-invariants.bats` "all kit/scripts/\*.sh tracked as 644"). Installing `-m 755` makes the tracked mode `100755` (red test) AND, because the file is root-owned, the on-disk 755 can't be `chmod`ed by node — `git update-index --chmod=-x` fixes the index but leaves the working tree mode-dirty, which blocks the very next `git checkout main` in `/ak-merge-devshop` Phase 3 and forces a second `sudo chmod 644` handoff. **Candidate fix**: in the denied-path recipe, (a) mark the `sudo install` step as a human handoff with the literal `!`-prefixed command; (b) default the mode to `install -m 644` for any script run via `bash` (reserve `755` for genuinely exec'd entrypoints), so both the tracked-mode invariant and the clean-tree checkout pass first time.
- **Promotion target**: `kit/TODOS.md` (fix the recipe in `kit/docs/guide/security.md § Authoring locked files` + the `CLAUDE.md § Known Footguns` denied-path entry: handoff-marked `! sudo install`, default `-m 644`).

### `/ak-build` Step 0 doesn't detect a feature-name collision with an already-shipped `specs/<feature>/`

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — silent on the resume path: a branch whose name matches a previously-shipped feature makes the resume check read the _old_ shipped `spec.md` (which has `## Task order`) and skip Phase 1/2 with the wrong spec; only caught this session because the Phase 0.3 `Write` happened to error on the existing file.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`claude-md-regrowth-prune` build, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` follow-up to the already-shipped `claude-md-hygiene`; the branch derived `specs/claude-md-hygiene/`, which already existed as the shipped artifact; the Phase 0.3 skeleton `Write` errored on the existing file, forcing a manual rename to `claude-md-regrowth-prune`.
- **Symptom**: `/ak-build` Step 0 / Phase 0.3 derives `specs/<FEATURE>/` from the branch name and either errors on an existing `spec.md` (caught) or — worse — the resume check reads a previously-shipped `spec.md` (it has `## Task order`) and skips straight to Phase 2 with the wrong spec.
- **Detail**: The feature dir is `specs/<branch-without-type-prefix>/`. When a follow-up build reuses a shipped feature's name (common when iterating on the same area), the dir already exists on `main` with the prior build's spec/tasks/review/gates, and Step 0's resume rungs key off "spec.md exists and has `## Task order`" → they'd resume the OLD shipped build instead of starting fresh. This session avoided the silent mis-resume only because the skeleton-commit `Write` refused to overwrite the existing file. **Candidate fix**: Step 0 should detect when `specs/<FEATURE>/` is already committed on `main` (a shipped artifact, not this branch's WIP) and halt with a rename prompt or auto-suffix the feature dir. References `.claude/skills/ak-build/SKILL.md § Step 0` (resume check) + `§ Phase 0.3`.
- **Promotion target**: `kit/TODOS.md` (Step 0 shipped-spec collision detection).

### Layer-B CLAUDE.md classification gate doesn't re-fire at the `/ak-merge-devshop` squash boundary

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — if the squash truly bypasses Layer B, every squash-merged CLAUDE.md change silently skips the classification gate (a structural blind spot in the canonical merge path); but blast radius is audit-trail completeness, not a broken gate.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`claude-md-regrowth-prune` build, spec D8)
- **Sessions**:
  - 2026-05-29 — `claude-md-regrowth-prune` build; two squash-merge CLAUDE.md edits landed on main with no `Claude-MD-Classification:` trailer.
- **Symptom**: a squash-merge commit that modified devshop `CLAUDE.md` lands on `main` with no `Claude-MD-Classification:` trailer, even though `check-claude-md-classification.sh` should block any staged CLAUDE.md `+` line without a bypass.
- **Detail**: Observed 2026-05-29: `412f20b` (worktree devshop-mode clause) and `8cdda99` (propagation clause) each `+1/-1`'d CLAUDE.md and merged clean. Layer-B contract fires on any staged CLAUDE.md edit with `+` lines and BLOCKS without a `devshop.claudeMdClassification` bypass — so the squash `git commit` should have blocked. **Hypothesis**: `/ak-merge-devshop`'s squash (`git reset --soft $ANCHOR && git commit -F`) either runs with `--no-verify` (structural blind spot — every squash-merged CLAUDE.md change skips the gate) OR the per-commit classification fired on the feature branch but doesn't surface on the squashed commit's trailer (gate working; only audit-time harvest incomplete). **To resolve**: (1) confirm whether the `/ak-merge-devshop` squash runs pre-commit at all; (2) if `--no-verify`, decide whether Layer B should re-gate the net CLAUDE.md delta at squash time, or rely on per-commit classification pre-squash and document the squash-trailer absence as expected; (3) wire the `Claude-MD-Classification:` trailer into `/ak-docs-review § Section E` harvest (`f875263`'s own body flagged this "not yet wired"). NOT a Layer-B rewrite — a coverage/harvest gap. **Third hypothesis (2026-05-29)**: if `412f20b`/`8cdda99` were authored in a linked worktree whose `pnpm install` step was skipped, no pre-commit hook fired at all (husky's `.husky/_` is regenerated only by `pnpm install` — see "Pre-commit hooks don't fire in linked worktrees", since shipped (b)+(d): the worktree-add recipe now installs hooks and Phase 2 nets the squash delta with gitleaks) — which would explain the absent trailer with neither a `--no-verify` squash nor a harvest gap. Check the authoring path before assuming a squash-time bypass. **Confirming observation (2026-05-30, `merge-devshop-worktree-hooks` build)**: the `/ak-merge-devshop` squash `git commit -F` from a `/devshop` direct-checkout **DID fire** the Layer-B classification gate — it blocked the squash until a `devshop.claudeMdClassification` value was supplied. So the squash does NOT run `--no-verify` (hypothesis 1 is disconfirmed), and the squashed commit carries the classification trailer. That leaves hypothesis 3 (worktree authoring with no `pnpm install` → no armed hooks) as the live explanation for the original `412f20b`/`8cdda99` absent-trailer incidents — and the (b) fix shipped this same build (worktree-add recipe now runs `pnpm install`) closes that authoring gap. Residual open work shrinks to (3): wire the `Claude-MD-Classification:` trailer into `/ak-docs-review § Section E` harvest. References `kit/scripts/commit-hooks/check-claude-md-classification.sh` + `.claude/skills/devshop/merge-devshop/SKILL.md` + `kit/docs/guide/claude-md.md § Enforcement`.
- **Promotion target**: `kit/TODOS.md` (confirm squash pre-commit behavior + wire trailer harvest) or `kit/ROADMAP.md` if it becomes a Layer-B re-gate.

### Devshop-mode `/ak-build` Phase 3 preflight↔`roster-check.sh` contract is undocumented (silent `set -e` exit + hero gap)

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — `roster-check.sh` exits 1 with ZERO output when the preflight sink omits a scope-var line, reading as a silent hang/failure that stalls the Phase 3→4 handoff until traced with `bash -x`.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-06-01 (`ak-check-docs-orphan-stubs` /ak-build, devshop mode, in a worktree)
- **Sessions**:
  - 2026-06-01 — hand-authored a devshop Phase 3.0 preflight sink with only the scope vars devshop uses (UI/migrations/functions/kit); `roster-check.sh` died silently on the first ABSENT key (`TOUCHES_CODE`). Also failed the hero check until a `hero/SKIP.md` was written, despite devshop-mode.md saying skip hero entirely.
- **Symptom**: `roster-check.sh` exits 1 printing nothing (looks like a hang); OR fails hero-capture on a no-UI devshop feature that has no `hero/` dir.
- **Detail**: `roster-check.sh` reads `TOUCHES_CODE`/`TOUCHES_USER_CODE`/`HAS_TURBO` via `KEY=$(grep -- "- KEY=" sink)`; if the `- KEY=` line is ABSENT (not just empty), `grep` exits 1 and under `set -euo pipefail` the assignment aborts the whole script with no message. The project-mode preflight (`/ak-build § 3.0`) always emits all keys, but devshop-mode.md gives no canonical devshop preflight template, so a hand-authored sink naturally omits the keys devshop doesn't use. Separately, `roster-check.sh`'s hero check wants either `hero/*.png` or a `hero/SKIP.md` with `Reason: non-UI PR …`, but devshop-mode.md § "No hero screenshots" says skip hero entirely without noting the SKIP.md marker the roster check still requires. **Candidate fix**: (a) add a canonical devshop preflight.md template (all scope vars, empty where N/A) + the `hero/SKIP.md` step to `devshop-mode.md § Phase 3`; and/or (b) make `roster-check.sh` default-empty missing keys (`KEY=$(grep … || true)`) and treat a no-UI devshop scope as hero-exempt. References `kit/scripts/preship/roster-check.sh` + `.claude/skills/ak-build/devshop-mode.md § Phase 3`.
- **Promotion target**: `kit/TODOS.md` (devshop preflight template + roster-check robustness).

### `/ak-pre-ship` + Phase 5.9 visual-evidence deferrals get rubber-stamped with hand-wave rationales

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — silent visual-evidence drift already spanned 3 consecutive home-os PRs; if it recurs, UI-bearing PRs keep shipping with no screenshots behind plausible-but-wrong rationales, eroding reviewer trust on the common UI-ship path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-15 (home-os PR #19 `triage-route-handler`)
- **Sessions**:
  - 2026-05-15 — home-os PR #19; Gate 4 + Gate 13 deferred capture citing a factually-wrong "ws() interop" blocker.
- **Symptom**: a pre-ship gate defers screenshot/hero capture with a plausible-sounding technical rationale that's never verified; Phase 5.9 reads the deferral as settled and Phase 6 has no signal for "new screens shipped without any visual evidence."
- **Detail**: Home-os PR #19 deferred `/cards/[id]` capture citing "Node 20 + `@supabase/realtime-js` ws() interop blocks programmatic seed" — but the actual blocker was a firewall rebound-port mismatch, and the same workspace's E2E spec seeded users+cards via `adminClient()` (falsifying the rationale in 30s). Pattern: pre-ship subagents over-accept plausible-and-technical deferrals; orchestrator surfaces it as "findings(1) deferred" not "shipped without evidence." **Fix shape (3 places)**: (1) `/ak-pre-ship` Gate 4/Gate 13 deferral rationale must include a real error message/stack trace OR a tracker-citation infra blocker — hand-waves fail as `findings_pending`; (2) Phase 5.9 detects "new public screens (regex `^apps/[^/]+/app/\(.+\)/[^/]+/page\.tsx$`), zero hero shots" as a halt/re-attempt signal; (3) Phase 6 escalates "shipped without visuals" to a top-line `### ⚠ No visual evidence for new screens` section. Edit targets: `ak-pre-ship/SKILL.md § Gate 4 + Gate 13`, `ak-build/SKILL.md § Phase 5.9 + § Phase 6`, `kit/docs/guide/hooks.md § Adversarial review` (add screenshot/E2E deferrals to extra-scrutiny list).
- **Promotion target**: `kit/TODOS.md` / `kit/ROADMAP.md` (3-part `/ak-pre-ship` + `/ak-build` hardening).

### `prTextHygieneReason` reviewer auto-rejects even when PR text is fine

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — if it recurs it blocks legitimate pushes on the common path (every non-trivial push runs the check), forcing a bypass-reason dance on correct PR text. Friction on a common path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-04-19 (hook-migration verification)
- **Sessions**:
  - 2026-04-19 — hook-migration verification; pushed an aligned-description PR update and still got blocked with `"No reason given — automatic rejection."`
- **Symptom**: `.husky/pre-push` Check 1 invokes `adversarial-review.sh prTextHygieneReason` and FAILs with `"No reason given — automatic rejection."` even when the PR title is readable, the body matches the commits, and the body has the required `## Product update` + `## Engineering details` structure.
- **Detail**: When no bypass reason is set, the reviewer short-circuits to FAIL even though adversarial prompt item 2(a) says _"PR description genuinely matches the commits — the reviewer is wrong"_ should PASS. (A `pr`-surface primary-judgment NOTE was later added to `adversarial-review.sh` to PASS clean text on the `no reason given` placeholder — verify whether this still reproduces before promoting; the count is the signal.) Full alternatives A–E + decision trigger: `kit/ROADMAP.md § "PR-description staleness check — layer + approach decision"`. Trigger to act: post-PR-3 (`/ak-build core-flows`) data on the false-positive rate of the always-fires implementation.
- **Promotion target**: `kit/ROADMAP.md § PR-description staleness check` (layer + approach decision).

### Audit reviewers flag prettier/eslint-owned formatting, triggering a futile hand-edit the commit hook reverts (and a commit message that then lies)

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — a silent misleading commit message reaches `main` (subject + bypass trailer claim a change that never landed), caught only by a downstream re-audit. Not data-losing, but it corrupts `git log` as a source of truth.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-06-01 (`ak-check-docs-orphan-stubs` /ak-build merge)
- **Sessions**:
  - 2026-06-01 — `/ak-merge-devshop` Phase 1.1 Audit 2 flagged a markdown list-continuation indentation in `check-docs-and-tests/SKILL.md` as a "regression"; I hand-re-indented to 3 spaces and committed claiming the fix. `lint-staged` ran `prettier --write` on the `*.md`, normalized it back to column-0, and re-staged — net-zero SKILL.md diff, so the commit recorded only the (unrelated) bats file while its subject + `Docs-Coverage-Bypass` trailer asserted a SKILL.md fix. Audit 3's docs re-review caught the divergence via `git show --stat`.
- **Symptom**: an audit reviewer raises a formatting finding (indentation, wrapping, spacing) on a prettier/eslint-owned file; the resulting hand-edit is silently reverted by `lint-staged` at commit time, producing a net-zero diff while the commit message / status still claims the edit landed.
- **Detail**: Two compounding failures. (1) ROOT — Layer-2 audit reviewers (`/ak-docs-review` Section B adequacy, analogues in `/ak-tests-review`) treat formatting as a finding surface, but `package.json`'s `lint-staged` runs `prettier --write` on `*.{json,md,css}` and eslint+prettier on `*.{ts,tsx,js,jsx}`, so those tools OWN that formatting (CLAUDE.md non-negotiable "Prettier owns all formatting"). A formatting "finding" is therefore noise that prettier will always revert — acting on it is futile. (2) GENERAL — the orchestrator wrote a commit subject + bypass trailer asserting the edit without verifying it survived the hook; `prettier --write` on a 3-space copy reverts to column-0 (verified this session), so the claim was false. **Candidate fix**: (a) carve prettier/eslint-owned formatting out of `/ak-docs-review` Section B (and tests-review analogue) — don't raise findings a formatter owns; (b) add a "verify the staged diff (`git show --stat`) before asserting an edit landed in a commit message / status" note where orchestrators compose commit messages (`/ak-build`, `/ak-merge-devshop`, this skill). (b) is the general guard — also catches partial-staging and other hook-rewrite causes. References `.claude/skills/ak-docs-review/SKILL.md § Section B` + `package.json § lint-staged`.
- **Promotion target**: `kit/TODOS.md` (reviewer formatting carve-out + verify-the-diff note), or fold (a) into `/ak-docs-review` directly if it earns it.

### `init-firewall.sh` re-run mid-session hangs the Claude session

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — a mid-session firewall refresh (to pick up a rotated CDN IP or a new domain) can hang the session, and the only known recovery is a full container rebuild; recurs whenever a domain/IP change forces a re-run.
- **Count**: 1
- **Status**: open — **this ledger is the single home; NOT promoted.** Removed from `PLAN.md § Planned (v0)` (`init-firewall-connection-preserving`) and from `kit/TODOS.md` on 2026-06-01. The 2026-05-31 re-promotion put an L-cost build (~4–8 hr) on the schedule against an _unconfirmed_ root cause, which this ledger's own gate forbids ("root-cause it before committing build time"). It stays here until the connection-drop **mechanism is confirmed** (instrumented, not hypothesized) and a fix shape is validated against the layer that actually drops the connection. The detailed note + bootstrap-related finding + shipped mitigation that lived in `kit/TODOS.md` are folded below so this entry is now self-contained.
- **First seen**: 2026-04-20 (lalista PR 2 close-out, observed twice in one session)
- **Sessions**:
  - 2026-04-20 — `sudo /usr/local/bin/init-firewall.sh` re-run mid-session hung indefinitely (twice during lalista PR 2 close-out); container rebuild was the only recovery.
  - 2026-06-01 — no new occurrence of the hang. A `/ak-build init-firewall-connection-preserving` attempt instead audited the proposed fix at Phase 0 and found it likely aimed at the wrong layer (see **Analysis** below); the premature `PLAN`/`TODOS` build commitment was demoted back here pending a root-cause spike.
- **Symptom**: re-running `init-firewall.sh` mid-session stalls the Claude session indefinitely — subsequent commands never return.
- **Detail**: Root cause **unconfirmed** (hypothesis: the boot-time iptables/ipset rebuild drops the session's own established API connection; when Claude Code reconnects against the new network state, commands stall). Originally demoted from `PLAN § Planned (v0)` (was `init-firewall-mid-session-hang`, Lev 1.8) because the fix is a guess — the committed entry proposed a connection-preserving atomic ipset swap / netns approach (L-cost, "investigation-heavy") against an unconfirmed root cause. Re-promoted 2026-05-31, then re-demoted 2026-06-01 (this entry) for the same reason: **root-cause it before committing build time.**
- **Analysis (2026-06-01) — the proposed fix likely targets the wrong layer.** The committed fix shape was _"atomic ipset swap instead of destroy-and-recreate."_ Reading the current `.devcontainer/init-firewall.sh` makes that look misaimed:
  - The script **already** re-establishes connection survival: right after the default policies flip to `DROP` (`iptables -P {INPUT,FORWARD,OUTPUT} DROP`, ~L146–148) it immediately re-adds `iptables -A {INPUT,OUTPUT} -m state --state ESTABLISHED,RELATED -j ACCEPT` (~L151–152). So an in-flight, conntrack-tracked connection _should_ survive the rule rebuild — provided conntrack still holds the entry.
  - The plausible drop window is therefore the **flush + policy flip**, not the ipset: `iptables -F` / `-X` / `-t nat -F` / `-t mangle -F` + `ipset destroy allowed-domains` (~L9–15) tear everything down, then the policy goes `DROP` (~L146) _before_ the ESTABLISHED rule is re-added (~L151). A brief ordering window plus possible conntrack invalidation across the `mangle -F` is the suspect — none of which an atomic **ipset** swap changes. An ipset-only fix would leave the flush/policy sequence untouched and plausibly **not fix the hang**.
  - This lines up with `kit/docs/guide/ops.md § Firewall IP rotation`, which independently hypothesizes _"conntrack invalidation from the boot-time `iptables -F` + `iptables -t mangle -F` + `ipset destroy allowed-domains` sequence."_ Two independent reads point at the flush, not the ipset.
- **Testability trap (why this can't be casually built).** The only true test of "did the fix preserve the connection?" is **re-running `init-firewall.sh` mid-session** — which is the exact action that hangs the session (rebuild-only recovery). A failed test can brick the session it runs in. So the root-cause spike must reproduce + instrument the hang in a **disposable context** (a throwaway sibling container, a separate network namespace, or against a non-session connection) — e.g. `conntrack -L` snapshots before/after each teardown step to pin _which_ line drops the in-flight connection — never against the live agent session. Until that harness confirms the layer, any fix is a guess. Also note both edit targets (`.devcontainer/init-firewall.sh` + `template/.devcontainer/init-firewall.sh`) are `[locked]` denied-paths, so a real fix needs the `/tmp + sudo install` handoff (`kit/docs/guide/security.md § Authoring locked files`).
- **Related: bootstrap chicken-and-egg in the `[locked]` file-refresh model** (folded from `kit/TODOS.md`, surfaced 2026-05-02 when a lalista rebuild failed on `statsig.anthropic.com` NXDOMAIN). `init-devshop.sh` refreshes `<workspace>/.devcontainer/init-firewall.sh` from `/devshop/template/.devcontainer/init-firewall.sh` on every container start, but runs _after_ `init-firewall.sh` in `postStartCommand` (gated by `&&`). When init-firewall itself is broken, init-devshop never runs, the workspace copy stays stale, and the next rebuild bakes the old broken version into `/usr/local/bin/` again — the Dockerfile's `COPY init-firewall.sh /usr/local/bin/` reads the workspace-local copy (Docker build context can't reach `/devshop/template/`). The `[locked]` model assumes init-firewall succeeded at least once on a previous start; there's no out-of-band bootstrap path when the locked file itself is what's broken.
- **Practical mitigation shipped 2026-05-02** (folded from `kit/TODOS.md`): made `init-firewall.sh`'s domain loop tolerant of single-domain DNS misses — warn-and-continue instead of `exit 1`, with a loud yellow inline banner + end-of-run summary of skipped domains. Applied to both `template/.devcontainer/init-firewall.sh` and `.devcontainer/init-firewall.sh`; also dropped the now-NXDOMAIN'd `statsig.anthropic.com`. Collapses bootstrap-breaking failure modes into a much narrower set. Operator workaround when the bootstrap _does_ break: `sudo /usr/local/bin/init-devshop.sh` hand-cranks the `[locked]` refresh (the Dockerfile-baked NOPASSWD wrapper path; `sudo bash /devshop/kit/scripts/init-devshop.sh` is NOT the same — it doesn't match the sudoers rule and prompts for `node`'s unset password), then rebuild bakes the patched version.
- **Architectural fixes worth considering** (deferred — the practical mitigation closes the immediate concrete failure mode; folded from `kit/TODOS.md`):
  - Move the `[locked]` refresh portion of init-devshop into `initializeCommand` (host-side, pre-build) so the workspace is synced from template _before_ the Dockerfile reads it. `init-host-env.sh` already runs in initializeCommand, so the plumbing exists — but this splits init-devshop into pre-build + post-start halves.
  - Reorder `postStartCommand` so init-devshop runs first. Its `[locked]` refresh is a pure-filesystem op (template→workspace `install`) so doesn't need network — but it doesn't help the immediately-running baked `/usr/local/bin/init-firewall.sh`; only the _next_ rebuild.
  - Multi-stage Dockerfile exposing `/devshop/template/` as a build stage so `COPY --from=devshop-source` works at build time. More invasive; ties build to a path layout; doesn't survive scaffold-from-zero where `/devshop/` doesn't exist yet.
- **Promotion target**: `kit/TODOS.md` / `kit/ROADMAP.md` once a root-cause spike (per **Testability trap** above) confirms _which_ teardown step drops the connection and a fix shape is validated against that confirmed layer. The operational workaround ("don't re-run `init-firewall.sh` mid-session — it stalls") is already documented in `/devshop/CLAUDE.md § Known Footguns` and `kit/docs/guide/ops.md § Firewall IP rotation`, so no operator guidance is lost by keeping the fix here as observation-only.

### Operator stashes vanish silently during `/ak-merge-devshop` flows

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — a stash ref disappears mid-merge with no explicit pop/drop; the data is recoverable (dangling commit via `git fsck`) but only if the operator knows to look, so WIP can appear lost.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-20 (`feat/gstack-artifact-symlink-redirect` merge)
- **Sessions**:
  - 2026-05-20 — `/ak-merge-devshop` flow; a Claude-autostash (4 files) vanished from `git stash list` after the merge completed, with no explicit pop/drop firing.
- **Symptom**: a `git stash` made before/during an `/ak-merge-devshop` run disappears from `git stash list` after the merge/push, with no `git stash pop`/`drop` ever run.
- **Detail**: Root cause **unconfirmed**. `--no-stash` on lint-staged (shipped) removed the leading suspect, but the mechanism is still open. The data is never lost — stash commits are durable dangling commits (recovery: `git fsck --no-reflogs | grep 'dangling commit'` → `git stash apply <SHA>`). **Demoted from `PLAN § Planned (v0)`** (was `stash-vanish-root-cause`, Lev 2.4) to the ledger because it's framed as a root-cause _investigation_ with an uncertain outcome — observation belongs here until the mechanism is confirmed. Full symptom + recovery: `.claude/skills/devshop/merge-devshop/SKILL.md § Operator stashes can vanish silently`. **This ledger entry is now the single home** — the duplicate `PLAN.md § Planned (v0)` row (`merge-devshop-stash-vanish-rootcause`) and `kit/TODOS.md § Root-cause investigation` entry were removed 2026-05-31 (deprioritized: trigger reduced by the shipped `--no-stash`). Promote back to `kit/TODOS.md` only when the count rises or the mechanism is confirmed.
- **Promotion target**: `kit/TODOS.md` once the dropping mechanism is confirmed (then a concrete fix can land).

### Phase 2.5 `verification.log` exit artifact is gitignored by `*.log`

- **Score**: 3 (impact 1 × count 3)
- **Impact**: 1 (XS) — latent inconsistency, no breakage: within-session resume works because the file exists in the working tree; it just never reaches git history or a fresh checkout.
- **Count**: 3
- **Status**: open
- **First seen**: 2026-05-29 (`triage-todos-to-friction-log` /ak-build, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` of `triage-todos-to-friction-log`; `git add specs/…/verification.log` was refused ("paths are ignored by .gitignore") — matched the repo-wide `*.log` rule.
  - 2026-05-29 — `claude-md-regrowth-prune` build; Phase 2.5 `verification.log` couldn't be committed (gitignored), so the audit record stayed working-tree-only.
  - 2026-06-01 — `init-devshop-mtime-bump` build; the Phase 2.5 verification subagent had to `git add -f specs/…/verification.log` to commit the durable artifact, confirming the `*.log` ignore bites every devshop-mode build that reaches Phase 2.5.
- **Symptom**: the Phase 2.5 exit artifact `specs/<feature>/verification.log` can't be `git add`ed — it matches the repo-wide `*.log` `.gitignore` rule, so it's never committed even though `devshop-mode.md § Phase 2.5` calls it a durable resume artifact.
- **Detail**: `devshop-mode.md § Phase 2.5 § Exit artifact` says "verification.log must exist before Phase 3 starts. The resume check uses its presence to skip Phase 2.5 on re-invocation." Within a session that holds (the file is in the working tree), but `*.log` in `.gitignore` means it never lands in the squash / `main` / a fresh clone — so a clean-checkout resume wouldn't see it. Mismatch between the "durable artifact" framing and the actual ignore rule. **Candidate fix**: rename the artifact to `verification.md` (the sibling `review.md` / `tasks.md` / `spec.md` are all `.md` and tracked) — cleaner than adding a `!specs/**/verification.log` re-include. References `.claude/skills/ak-build/devshop-mode.md § Phase 2.5` + `.gitignore`.
- **Promotion target**: `kit/TODOS.md` (rename Phase 2.5 artifact to `verification.md`, or re-include in `.gitignore`).

### A shipped feature's `PLAN.md § Planned` row is left orphaned even though its `kit/TODOS.md` source + `BUILD-LOG.md` entry were closed

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — no breakage, but the orphaned row reads as still-pending in later sessions and gets re-cited as live work, recreating the false belief the fix removed (the exact failure `PLAN.md`'s lifecycle note + `conventions.md § Closing TODO / ROADMAP entries when a fix ships` exist to prevent). Caught only by a manual hygiene pass; the per-row "validate the entry still applies before implementing" check is the backstop, so it costs a session a re-check rather than a wasted build.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-06-02 (`docs/init-firewall-demote-to-friction` tracker-hygiene pass)
- **Sessions**:
  - 2026-06-02 — analyzing the live v0 `PLAN.md` rows, found `ak-check-docs-orphan-stubs` still listed in `## Planned (v0)` though it shipped to `main` in `bf1cb7a`/`f915ce8` (2026-05-31). Its `BUILD-LOG.md` entry exists and says verbatim "Closes the `kit/TODOS.md` orphan-stub entry" — the TODO was indeed removed — but the PLAN row survived. Removed it in `ec630f0`. The sibling `init-devshop-mtime-bump` shipped the same week (`c6be31e`) and DID cleanly sweep its own Planned row + TODO, so the gap is intermittent, not universal.
- **Symptom**: a `PLAN.md § Planned (vN)` row names a feature that already has a `BUILD-LOG.md` ship entry (and whose `kit/TODOS.md` source entry is already gone) — i.e. the row's slug appears in both `PLAN.md` and a BUILD-LOG `### <slug>` heading.
- **Detail**: The "close all trackers when a fix ships" convention is enforced unevenly across the PLAN tables. `/ak-build` Phase 4.0 bookkeeping (and the `/ak-merge-devshop` close-out) remove the PLAN.md **Active** row, but a feature that shipped straight from **Planned** — never promoted to Active via `/ak-spec`, common for tiny tracker/skill fixes — has no Active row to remove, so its Planned row is never swept. Compounded when the build ran in a worktree cut from an older `main`, where the row's table region had drifted, making a clean removal-diff harder to land. **Candidate fix**: (1) the ship/merge close-out sweeps BOTH the Active AND Planned tables for a row whose slug matches the shipped feature; (2) `/ak-docs-review` (or the `/ak-merge-devshop` Phase 1 audit) flags a new BUILD-LOG entry whose feature slug still appears anywhere in `PLAN.md` as a likely-unclosed tracker row. References `kit/docs/guide/conventions.md § Closing TODO / ROADMAP entries when a fix ships`, `.claude/skills/ak-build/devshop-mode.md § Phase 4.0`, `.claude/skills/ak-merge-devshop/SKILL.md`.
- **Promotion target**: `kit/TODOS.md` (sweep Planned + Active on ship-close; add a BUILD-LOG-slug-still-in-PLAN audit check).

### `/ak-spec` silently drops the `/design-html` UI reference (globs `design-html/`, gstack writes `designs/`)

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — silent: the spec's optional `DESIGN_HTML` reference is always empty because the glob path never matches gstack's actual output dir, so every UI feature that ran `/design-html` loses the production-HTML reference the spec means to carry into implementation. Low individual cost, but recurs on the UI-spec path and matters more once visual-design work lands.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-06-01 (gstack 0.15→1.55 delta analysis)
- **Sessions**:
  - 2026-06-01 — gstack delta analysis; verified by file-level diff of BOTH the vendored 0.15.1.0 and upstream 1.55.0.0 that gstack writes finalized design HTML to `$GSTACK_PROJECT_DIR/designs/*/finalized.html`, while `.claude/skills/devshop/spec/SKILL.md:136` globs `$GSTACK_PROJECT_DIR/design-html/*.html`. So the glob has never matched (not an upgrade regression — stale in both versions).
- **Symptom**: `/ak-spec`'s context-load line `DESIGN_HTML=$(ls -t "$GSTACK_PROJECT_DIR"design-html/*.html 2>/dev/null | head -1)` is always empty — the `2>/dev/null` swallows the no-match, so the spec silently omits the `/design-html` UI reference it intends to cat as an implementation reference.
- **Detail**: `spec/SKILL.md` (~line 134–146) loads optional planning artifacts from `$GSTACK_PROJECT_DIR`; the `DESIGN_HTML` line globs a `design-html/` subdirectory, but gstack's `/design-html` + `/design-consultation` skills write finalized HTML to `projects/$SLUG/designs/<screen>-YYYYMMDD/finalized.html` (and `finalized.{tsx,svelte,vue}` for non-HTML targets) — confirmed identical across 0.15.1.0 and 1.55.0.0, so this is a long-standing devshop-side path mismatch, not gstack drift. The `2>/dev/null | head -1` makes the miss silent: `$DESIGN_HTML` stays empty and the `[ -n "$DESIGN_HTML" ] && cat …` no-ops, so the spec ships without the UI reference on every project that ran `/design-html`. **Devshop-side fix only** (do NOT edit gstack): change the glob to `designs/*/finalized.html` (and likely `designs/*/finalized.{tsx,svelte,vue}`), matching how `/design-consultation`/`/design-html` actually write. References `.claude/skills/devshop/spec/SKILL.md:136`.
- **Promotion target**: `kit/TODOS.md` (fix the `/ak-spec` `design-html` glob to read `designs/*/finalized.*`).

### Devshop `/ak-build` from a dirty tree trips the clean-tree guard at the Phase 0.3 skeleton commit

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — friction on the uncommon-but-recurring path where a devshop feature is driven by an uncommitted edit; the pipeline stalls at its first commit until worked around, but the fix is mechanical and lossless.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`triage-todos-to-friction-log` /ak-build, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` of `triage-todos-to-friction-log`; the driver was an operator-authored, uncommitted `kit/TODOS.md` entry, so Phase 0.3's `git add specs/… && commit` was refused by the devshop clean-tree pre-commit guard.
- **Symptom**: `/ak-build` (devshop mode) Phase 0.3 / 1.1 try to commit only `specs/<feature>/spec.md`, but the devshop pre-commit clean-tree guard refuses ("✖ Working tree not clean before commit") because unrelated working-tree files are dirty/untracked (the uncommitted driver edit, a runtime lock, etc.).
- **Detail**: `/ak-build` Phase 0.3 commits the spec skeleton (and 1.1 the expansion) assuming a partial `git add specs/…` is fine. Devshop's pre-commit clean-tree check counts ALL dirty/untracked entries, so the partial commit is blocked whenever the feature is driven by an uncommitted change — common when an operator hand-authors a tracker entry and then runs `/ak-build` on it. Workaround used this session: commit the dirty driver as a squash-invisible branch baseline first (devshop squash-merges, so the add-then-resolve churn never reaches `main`), and gitignore any untracked runtime noise. **Candidate fix**: an `ak-build/devshop-mode.md` Phase 0.3 note — when the tree is dirty at branch creation, baseline-commit the driver before the skeleton commit (or document the `git -c devshop.dirtyTreeReason=…` bypass as the alternative). References `.claude/skills/ak-build/SKILL.md § Phase 0.3` + the clean-tree pre-commit guard.
- **Promotion target**: `kit/TODOS.md` (Phase 0.3 dirty-tree handling note in `devshop-mode.md`).

### Subagent drift rate uninstrumented; cleanup-pattern decision deferred

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — measure-then-decide work; if subagents do drift repo state across many spawns it's a recurring low-grade hygiene tax, but the decision gate may well say "skip" (<5% drift). Friction on an uncommon path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-04-19 (documented; phased plan in `kit/notes/roadmap/subagent-cleanup-pattern.md`)
- **Sessions**:
  - 2026-04-19 — documented the measure-before-build plan after the hook-injection migration.
- **Symptom**: no data exists on how often `/ak-build` / `/ak-implement` subagents leave the repo in a drifted state after a spawn, so there's no basis to decide whether a cleanup pattern is worth codifying.
- **Detail**: Phased plan in `kit/notes/roadmap/subagent-cleanup-pattern.md`. Phase 1 adds a deterministic bash logger (`subagent-drift-log.sh`) at `Agent()` call-sites that snapshots repo state before+after each spawn and writes deltas to a gitignored log. Phase 2 (contingent on Phase 1 data) codifies a clean-state prompt block in `kit/docs/guide/agents.md` + optional helper `check-subagent-cleanup.sh`. **Decision gate after ~30 spawns**: <5% drift → skip Phase 2; 5–15% → prompt block only; >15% or multi-session accumulation → full helper + bats tests. **Hard guardrail**: pattern MUST stay at the prompt/agent-to-agent layer — a `SubagentStop` hook would recreate the hook-injection bug the 2026-04-19 migration killed.
- **Promotion target**: `kit/ROADMAP.md` (Phase 1 instrumentation) — the long-form plan already lives in `kit/notes/roadmap/subagent-cleanup-pattern.md`.

### `/ak-merge-devshop` squash doesn't carry forward constituent commits' bypass trailers, forcing manual reconstruction

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — ergonomic friction on the canonical merge path, fully recoverable: the gate does its job (blocks), the trailer rationale is recoverable from the constituent commit bodies, no data loss and no silent wrong work. The residual risk is a rushed operator hand-waving a weaker bypass reason than the original (which the Sonnet-routed reviewers may then reject, or worse accept), slightly weakening the audit trail.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-31 (`virtiofs-rebase-auto-switch` merge)
- **Sessions**:
  - 2026-05-31 — `/ak-merge-devshop` of `virtiofs-rebase-auto-switch`; the Phase 2 squash `git commit -F` blocked twice in a row — first on `check-tests-coverage-devshop.sh` (the new `kit/scripts/virtiofs-rebase.sh`'s test `util-virtiofs-rebase.bats` is staged in the same squash delta, a first-commit ordering artifact the constituent `feat` commit already carried a `Tests-Coverage-Bypass:` for), then on `check-claude-md-classification.sh` (the CLAUDE.md footgun rewrite, constituent commit carried a `Claude-MD-Classification:` trailer). Both `-c devshop.*` reasons had to be hand-reconstructed from the constituent commit bodies before the squash would land.
- **Symptom**: the Phase 2 squash `git commit -F` is blocked by a per-commit semantic gate (tests-coverage, CLAUDE.md-classification, dirty-tree, local-test-skip — any bypass-trailer-gated check) that a constituent commit already satisfied via a `*-Bypass:` / `Claude-MD-Classification:` trailer; the operator must manually re-derive and re-supply each `-c devshop.<reason>` flag at the squash invocation because the collapse drops the original trailers.
- **Detail**: Phase 2 does `git reset --soft $ANCHOR && git commit -F`, which fires the full pre-commit gauntlet on the collapsed delta. The constituent commits' bypass trailers (`Tests-Coverage-Bypass:`, `Claude-MD-Classification:`, etc.) live in the now-discarded per-commit messages, so the squash commit re-trips every gate they bypassed — with no carry-forward. The operator reconstructs each `-c devshop.<reason>` by hand from the constituent commit bodies (`git show <constituent-sha>`). This is the squash-boundary sibling of "Layer-B CLAUDE.md classification gate doesn't re-fire at the `/ak-merge-devshop` squash boundary" (which established the gate DOES fire at squash time — confirmed 2026-05-30); this entry is the downstream ergonomic gap that confirmation exposes, and it generalizes across ALL bypass-gated checks, not just CLAUDE.md. **Candidate fix**: Phase 2 pre-scans the constituent commit range (`$ANCHOR..$BRANCH`) for `*-Bypass:` / `Claude-MD-Classification:` trailers and auto-assembles the corresponding `-c devshop.<key>="<reason>"` flags into the squash `git commit` invocation (carrying the original rationale verbatim, so the audit trail is preserved). At minimum, surface the will-re-fire trailers in the Phase 0.4 preview so the operator pre-stages them instead of discovering them via two failed commits. References `.claude/skills/ak-merge-devshop/SKILL.md § Phase 2` + `kit/scripts/commit-hooks/check-tests-coverage-devshop.sh` + `check-claude-md-classification.sh`.
- **Promotion target**: `kit/TODOS.md` (Phase 2 bypass-trailer carry-forward / preview surfacing).

### `git ls-remote` via HTTPS-with-token URL produces garbled output

- **Score**: 1 (impact 1 × count 1)
- **Impact**: 1 (XS) — minor one-off with a known clean workaround (`gh api`); even if it recurs it's an aesthetic/tooling nit on the uncommon branch-cleanup path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-04-23 (lalista-PR17 cleanup)
- **Sessions**:
  - 2026-04-23 — `/ak-clean-branches` Phase 1 against abra-kadabra; ls-remote output arrived as broken one-word-per-line fragments.
- **Symptom**: `git ls-remote "https://x-access-token:${TOKEN}@github.com/…"` returns broken fragments ("Permission", "Could", "make", "the" — one word per line) instead of `<sha>\trefs/heads/<branch>` rows; `git fetch` with the same URL works fine.
- **Detail**: `/ak-clean-branches` Phase 1 enumerates remote branches via `git ls-remote` over the HTTPS-token URL; only ls-remote broke, fetch was fine. **Workaround (shipped)**: swap to `gh api repos/meirmsn/abra-kadabra/branches --paginate --jq '.[].name'`. **Hypothesis**: token contains a special character (`$` / newline / URL-reserved) interpreted by the shell or git's URL parser, mangling argv (`/etc/devshop-env` is `echo DEVSHOP_GITHUB_TOKEN=$TOKEN` into a file). Low-effort fix: switch the skill to `gh api` unconditionally. Edit target: `.claude/commands/ak-clean-branches.md` (Phase 1 remote enumeration).
- **Promotion target**: `kit/TODOS.md` (swap clean-branches Phase 1 to `gh api`) — low priority.
