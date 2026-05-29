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
  observation record; don't delete it — the count history is the evidence the
  promotion was earned). When the underlying fix actually ships, set Status to
  `resolved (<commit/PR>)` and unwind it per
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
most-recently-seen. Highest-scoring friction is always at the top. `resolved`
entries sink to a `## Resolved` section at the bottom (kept for the history).

<!-- entries below, highest score first -->

## Open

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

### Layer-B CLAUDE.md classification gate doesn't re-fire at the `/ak-merge-devshop` squash boundary

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — if the squash truly bypasses Layer B, every squash-merged CLAUDE.md change silently skips the classification gate (a structural blind spot in the canonical merge path); but blast radius is audit-trail completeness, not a broken gate.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-29 (`claude-md-regrowth-prune` build, spec D8)
- **Sessions**:
  - 2026-05-29 — `claude-md-regrowth-prune` build; two squash-merge CLAUDE.md edits landed on main with no `Claude-MD-Classification:` trailer.
- **Symptom**: a squash-merge commit that modified devshop `CLAUDE.md` lands on `main` with no `Claude-MD-Classification:` trailer, even though `check-claude-md-classification.sh` should block any staged CLAUDE.md `+` line without a bypass.
- **Detail**: Observed 2026-05-29: `412f20b` (worktree devshop-mode clause) and `8cdda99` (propagation clause) each `+1/-1`'d CLAUDE.md and merged clean. Layer-B contract fires on any staged CLAUDE.md edit with `+` lines and BLOCKS without a `devshop.claudeMdClassification` bypass — so the squash `git commit` should have blocked. **Hypothesis**: `/ak-merge-devshop`'s squash (`git reset --soft $ANCHOR && git commit -F`) either runs with `--no-verify` (structural blind spot — every squash-merged CLAUDE.md change skips the gate) OR the per-commit classification fired on the feature branch but doesn't surface on the squashed commit's trailer (gate working; only audit-time harvest incomplete). **To resolve**: (1) confirm whether the `/ak-merge-devshop` squash runs pre-commit at all; (2) if `--no-verify`, decide whether Layer B should re-gate the net CLAUDE.md delta at squash time, or rely on per-commit classification pre-squash and document the squash-trailer absence as expected; (3) wire the `Claude-MD-Classification:` trailer into `/ak-docs-review § Section E` harvest (`f875263`'s own body flagged this "not yet wired"). NOT a Layer-B rewrite — a coverage/harvest gap. References `kit/scripts/commit-hooks/check-claude-md-classification.sh` + `.claude/skills/devshop/merge-devshop/SKILL.md` + `kit/docs/guide/claude-md.md § Enforcement`.
- **Promotion target**: `kit/TODOS.md` (confirm squash pre-commit behavior + wire trailer harvest) or `kit/ROADMAP.md` if it becomes a Layer-B re-gate.

### A doc/SKILL.md edit can silently drift a `grep`-based bats test

- **Score**: 3 (impact 3 × count 1)
- **Impact**: 3 (M) — a red suite can reach `main` when a doc edit changes text a content-validation test asserts and nothing forces them to co-update; recurs on the common doc-editing path and the failure is silent until the next full-suite run.
- **Count**: 1
- **Status**: open
- **First seen**: 2026-05-28 (`1d343bf`, surfaced via parallel `/ak-merge-devshop` runs)
- **Sessions**:
  - 2026-05-28 — `1d343bf` updated 9 docs but missed the asserting test; a red suite reached main.
- **Symptom**: a SKILL.md/doc edit removes or rewrites text that a `grep`-based bats test asserts; the test goes red but nothing in the Layer-1 test-presence hooks links the edit to the test, so the drift ships silently.
- **Detail**: Layer-1 test-presence hooks catch _missing_ tests, not _stale_ ones. Worked observation: `1d343bf` (2026-05-28) updated 9 docs but missed the asserting test — test 14 in `util-build-phase58-audit-parser.bats` (a stale Phase 6 audit-comment assertion from ancestor `486a57d`) went red once `1d343bf` removed the asserted "Pre-ship audit | gates passed" text, and a red suite reached `main`. **Fix shape**: a `structural-invariants.bats` check that maps SKILL-asserting tests to their source files, OR a `conventions.md` note requiring co-update of a doc and any test asserting its content.
- **Promotion target**: `kit/TODOS.md` (structural-invariants mapping check or conventions.md co-update note).

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

## Resolved

_None yet._
