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

### A doc/SKILL.md edit can silently drift a `grep`-based bats test

- **Score**: 12 (impact 3 × count 4)
- **Impact**: 3 (M) — grep-based bats tests are brittle against the prose they assert, in BOTH directions: an edit that changes asserted text turns the suite red silently (until the next full-suite run), and a test that _under_-asserts lets a future edit silently drop the very coverage it was meant to pin and ship green. Recurs on the common doc/prompt-editing path.
- **Count**: 4
- **Status**: open
- **First seen**: 2026-05-28 (`1d343bf`, surfaced via parallel `/ak-merge-devshop` runs)
- **Sessions**:
  - 2026-05-28 — `1d343bf` updated 9 docs but missed the asserting test; a red suite reached main.
  - 2026-05-30 — `claude-md-condense` Audit 1 (tests, low): the capture-the-prompt test (`util-adversarial-review-narrowing.bats`) pins the `CLAUDE_MD_SECTIONS` section list + forwarded reason but does NOT assert the rubric prose body reaches the assembled prompt — so a future CLAUDE.md-condense pass could silently drop the new rubric (f) "Reachability split" lines and ship green. Inverse flavor of the 2026-05-28 instance (under-assertion → silent drop, vs assertion-drift → red).
  - 2026-05-30 — `merge-devshop-worktree-hooks` build, Audit 2 (tests, low): the new Phase 3 ordering test in `util-ak-merge-devshop.bats` (~l.877–887) anchors the ff-merge gitleaks line with `grep … | head -1`, but the anchor matches TWICE in the Phase 3 range (the real code line AND a recovery-prose sentence). Correct at HEAD (code line sorts first), but if the code line were removed the prose line still matches → silent pass (under-assertion flavor again). Shipped as a noted-LOW (squash `4085ec6`); suggested tightening: anchor on a unique code-form token.
  - 2026-05-31 — `propagation-skip-noop` focused fix: inserting the new NOTE-3 tag-FAIL paragraph into `adversarial-review.sh`'s prompt wrapped the literal phrase `"If the list is EMPTY"` (grepped by test 16 in `util-adversarial-review-narrowing.bats`) across a line break → test went red. Worked around by keeping the phrase on one line; the brittle literal-grep-against-prose coupling is the recurring root. Assertion-drift flavor.
- **Symptom**: a `grep`-based bats test and the prose it asserts drift apart with no mechanism linking them — either an edit removes/rewrites asserted text (test goes red, ships silently until the next full-suite run) OR the test under-asserts so a later edit silently drops the pinned content and ships green.
- **Detail**: Layer-1 test-presence hooks catch _missing_ tests, not _stale_ or _under-scoped_ ones. Worked observations: (a) `1d343bf` (2026-05-28) updated 9 docs but missed the asserting test — test 14 in `util-build-phase58-audit-parser.bats` (a stale Phase 6 audit-comment assertion from ancestor `486a57d`) went red once `1d343bf` removed the asserted "Pre-ship audit | gates passed" text, and a red suite reached `main`. (b) `claude-md-condense` (2026-05-30) — the capture-the-prompt test asserts the section-list + reason but not the rubric prose body, leaving rubric (f) unpinned. **Cheap per-case fix (b)**: add one `grep -q "Reachability split"` assertion to the existing capture test. **Structural fix shape**: a `structural-invariants.bats` check that maps SKILL/prompt-asserting tests to their source files, OR a `conventions.md` note requiring co-update of a doc and any test asserting its content.
- **Promotion target**: `kit/TODOS.md` (structural-invariants mapping check or conventions.md co-update note; plus the one-line `grep -q "Reachability split"` assertion).

### Devshop kit scripts ship a red `main` when a new skill-invoked script isn't added to the wiring allow-list

- **Score**: 8 (impact 4 × count 2)
- **Impact**: 4 (L) — a red `structural-invariants.bats` wiring test on `main` blocks the Phase 2.5 / Gate 2d full-suite gate of _every_ in-flight merge until someone fixes it; recurs whenever a new skill-invoked (not hook-wired) kit script lands without being registered.
- **Count**: 2
- **Status**: open
- **First seen**: 2026-05-27 (`bebda21`, three `kit/scripts/preship/` scripts)
- **Sessions**:
  - 2026-05-27 — `bebda21` added three `kit/scripts/preship/` scripts without registering them in the wiring accounting; the full suite went red mid-stream and reached `main`.
  - 2026-05-29 — `ca4bc76` added `reconcile-task-commits.sh` (skill-invoked from `/ak-build` Step 0 + `/ak-implement`) without adding it to the wiring test's `infra_scripts` allow-list; red `main` surfaced during `claude-md-regrowth-prune` Phase 2.5; fixed in `bb3e13c`.
- **Symptom**: the `structural-invariants.bats` test "every non-exempt kit script is wired into a hook or pre-commit" goes red because a new `kit/scripts/**` file is neither hook-wired, exempt, nor in the hand-maintained `infra_scripts` allow-list — and it reaches `main` because the per-commit hook only runs the affected-subset, not the full suite.
- **Detail**: The wiring test enumerates every `kit/scripts/**.sh` and requires each to be hook-wired OR in the `exempts` list OR in the in-test `infra_scripts` string. Skill-invoked helpers (called from a SKILL.md prompt, not a hook) must be hand-added to `infra_scripts` or the test red-flags them. Two instances so far (`bebda21`, `ca4bc76`); the closely-related asserted-text-drift flavor is logged separately ("A doc/SKILL.md edit can silently drift a `grep`-based bats test"). **Candidate fix**: make the wiring test auto-detect skill invocation — grep `.claude/skills/**/SKILL.md` for the script's basename and treat a hit as "wired (skill-invoked)" — so a new skill-helper is covered without an allow-list edit. **Defense-in-depth already shipped**: `/ak-merge-devshop` Phase 2.5 now derives its verdict from a `grep -c '^not ok'` count (not the green tail), so a mid-stream red can't false-pass; that catches the red but doesn't prevent it landing via a direct commit.
- **Promotion target**: `kit/ROADMAP.md` (auto-detect skill-invocation in the wiring test) or `kit/TODOS.md`.

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

### `init-firewall.sh` re-run mid-session hangs the Claude session

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — a mid-session firewall refresh (to pick up a rotated CDN IP or a new domain) can hang the session, and the only known recovery is a full container rebuild; recurs whenever a domain/IP change forces a re-run.
- **Count**: 1
- **Status**: promoted → `PLAN.md § Planned (v0)` (`init-firewall-connection-preserving`, re-promoted 2026-05-31)
- **First seen**: 2026-04-20 (lalista PR 2 close-out, observed twice in one session)
- **Sessions**:
  - 2026-04-20 — `sudo /usr/local/bin/init-firewall.sh` re-run mid-session hung indefinitely (twice during lalista PR 2 close-out); container rebuild was the only recovery.
- **Symptom**: re-running `init-firewall.sh` mid-session stalls the Claude session indefinitely — subsequent commands never return.
- **Detail**: Root cause **unconfirmed** (hypothesis: the iptables/ipset rebuild drops the session's own established API connection; when Claude Code reconnects against the new network state, commands stall). **Demoted from `PLAN § Planned (v0)`** (was `init-firewall-mid-session-hang`, Lev 1.8) to the ledger because the fix is a guess — the committed entry proposed a connection-preserving atomic ipset swap / netns approach (L-cost, "investigation-heavy") against an _unconfirmed_ root cause. Root-cause it before committing build time. Detailed note: `kit/TODOS.md § sudo /usr/local/bin/init-firewall.sh hangs the session when re-run`.
- **Promotion target**: `kit/TODOS.md` / `kit/ROADMAP.md` once the connection-drop hypothesis is confirmed and a fix shape is validated.

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

### Virtiofs phantom rebase also surfaces as a "rescheduled pick" stall on a clean tree

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — the `core.checkStat=minimal` retry remedy already shipped (`8aa012c`) and the merge fallback always works, so recovery is mechanical; the residual risk is recognition time — an operator who hits this _variant_ may not connect it to the documented phantom (which only names the "local changes would be overwritten" message) and burn cycles before reaching the remedy. Recurs on the common merge path.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`merge-devshop-phase25-tree-pin` /ak-build, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` of `merge-devshop-phase25-tree-pin`; Phase 1.0 rebase + two mid-pipeline rebases each flaked this way; resolved via the `git merge` fallback (the checkStat retry remedy landed mid-session via `8aa012c`, after the loaded skill version, so it wasn't tried first).
- **Symptom**: `git rebase <anchor>` (in `/ak-merge-devshop § Phase 1.0` or a standalone worktree rebase) stalls on a verifiably **clean** tree with `git rebase --edit-todo` / `--continue` hints and a "rescheduled" pick (often the SAME pick listed as both done and next-to-do), "currently editing a commit" — NOT the documented `error: Your local changes ... would be overwritten by merge` string.
- **Detail**: Same virtiofs stat-cache root cause as the documented phantom (`CLAUDE.md § Known Footguns` + `merge-devshop/SKILL.md § Phase 1.0`), but a different surface form — so a grep/recognition match on the documented "local changes would be overwritten" message misses it. The `core.checkStat=minimal -c core.trustctime=false rebase` first-remedy almost certainly covers this variant too (same root cause); the `git merge` fallback definitely does (verified 3× this session). **Candidate fix**: add one clause to the `§ Phase 1.0` phantom note + the CLAUDE.md footgun — _"also surfaces as a rescheduled-pick / 'editing a commit' stall on a clean tree (with `git rebase --edit-todo`/`--continue` hints); same root cause, same checkStat retry → merge fallback ladder."_ References `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1.0` + `CLAUDE.md § Known Footguns`.
- **Promotion target**: `kit/TODOS.md` (one-clause symptom-variant addition to the Phase 1.0 phantom note + CLAUDE.md footgun).

### zsh doesn't word-split unquoted `$STRING` in orchestrator-authored loops (e.g. Phase 3.3 concat)

- **Score**: 2 (impact 2 × count 1)
- **Impact**: 2 (S) — silent: `for x in $STRING` iterates once over the whole string (zero file matches), so a hand-authored concat/loop no-ops without error. Caught at review-assembly time, but recurs whenever an orchestrator hand-writes a loop over a space-joined string (the GIT_CMD array convention covers one call-site, not the general pattern).
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`merge-devshop-phase25-tree-pin` /ak-build, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` Phase 3.3 (devshop mode); `for g in $ORDER` over a space-joined gate-name string matched zero sink files (treated the whole string as one filename), producing an empty gate roster in `review.md` until switched to an array.
- **Symptom**: an orchestrator-authored bash loop `for x in $STRING; do ... "$DIR/$x.md" ...` (over a space-joined string var) silently does nothing useful in zsh — the Bash tool's shell is zsh, which does NOT word-split an unquoted scalar; the loop runs once with `x` = the entire string.
- **Detail**: `devshop-mode.md § Concatenation + handoff` describes the Phase 3.3 gate-sink concatenation in prose ("concatenate all 19 gate sinks") with no array-shaped bash example, so an orchestrator naturally reaches for `for g in $ORDER` — which works in bash but no-ops in zsh. Same root cause the `GIT_CMD` array-vs-string convention already documents for ONE call-site, but the general "use an array for any multi-item iteration in orchestrator bash" rule isn't stated where the concat loop is authored. **Candidate fix**: add an array-shaped example (`ORDER=(docs-check …); for g in "${ORDER[@]}"`) to `devshop-mode.md § Concatenation + handoff`, or a one-line "zsh: iterate arrays, not space-joined strings" note; optionally a tiny `concat-gate-sinks.sh` helper. References `.claude/skills/ak-build/devshop-mode.md § Concatenation + handoff`.
- **Promotion target**: `kit/TODOS.md` (array example / one-line zsh note in `devshop-mode.md § Concatenation`).

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

### Phase 2.5 `verification.log` exit artifact is gitignored by `*.log`

- **Score**: 2 (impact 1 × count 2)
- **Impact**: 1 (XS) — latent inconsistency, no breakage: within-session resume works because the file exists in the working tree; it just never reaches git history or a fresh checkout.
- **Count**: 2
- **Status**: open
- **First seen**: 2026-05-29 (`triage-todos-to-friction-log` /ak-build, this session)
- **Sessions**:
  - 2026-05-29 — `/ak-build` of `triage-todos-to-friction-log`; `git add specs/…/verification.log` was refused ("paths are ignored by .gitignore") — matched the repo-wide `*.log` rule.
  - 2026-05-29 — `claude-md-regrowth-prune` build; Phase 2.5 `verification.log` couldn't be committed (gitignored), so the audit record stayed working-tree-only.
- **Symptom**: the Phase 2.5 exit artifact `specs/<feature>/verification.log` can't be `git add`ed — it matches the repo-wide `*.log` `.gitignore` rule, so it's never committed even though `devshop-mode.md § Phase 2.5` calls it a durable resume artifact.
- **Detail**: `devshop-mode.md § Phase 2.5 § Exit artifact` says "verification.log must exist before Phase 3 starts. The resume check uses its presence to skip Phase 2.5 on re-invocation." Within a session that holds (the file is in the working tree), but `*.log` in `.gitignore` means it never lands in the squash / `main` / a fresh clone — so a clean-checkout resume wouldn't see it. Mismatch between the "durable artifact" framing and the actual ignore rule. **Candidate fix**: rename the artifact to `verification.md` (the sibling `review.md` / `tasks.md` / `spec.md` are all `.md` and tracked) — cleaner than adding a `!specs/**/verification.log` re-include. References `.claude/skills/ak-build/devshop-mode.md § Phase 2.5` + `.gitignore`.
- **Promotion target**: `kit/TODOS.md` (rename Phase 2.5 artifact to `verification.md`, or re-include in `.gitignore`).

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
