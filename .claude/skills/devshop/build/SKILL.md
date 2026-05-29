---
name: ak-build
version: 2.0.0
description: |
  Autonomous build pipeline: preview → spec → implement → quality gates → ship → CI watch → notify.
  Two modes: **project** (default — PR-based, CI watch, PR-surface verification, /ak-go-live) and
  **devshop** (auto-detected for the /devshop repo + its linked worktrees — reduced gate set, /ak-merge-devshop
  transport, no PR/CI/deploy). See `devshop-mode.md` in this directory for devshop-specific
  phases (Phase 3 gate matrix, Phase 4.5, terminal handoff).
  Phase 0 produces a 3-section pre-flight preview (decisions / scope / tracker) and
  persists user-approved decisions as a `specs/<feature>/spec.md` skeleton (provenance
  + Sources + Decisions) — one file, no parallel artifact. Phase 1's spec agent
  preserves the Decisions section verbatim and expands the rest. On crash-restart,
  a committed spec.md lacking `## Task order` signals Phase 0 finished but Phase 1
  didn't (Step 0 reads the discriminator from committed state — Phase 1.1 commits
  the expansion).
  The live TaskCreate tracker mirrors the preview's hierarchy as phases run.
  Delegates heavy phases to subagents to keep main context clean.
  Resumable — detects where it left off if session is interrupted.
  If /ak-pre-ship reports any `blocked` gate (tooling missing), fires AskUserQuestion
  with three options (resolve / override / abort) before advance — captures any override
  in specs/<feature>/review.md § Phase 3 → 4 advance log, adversarially reviews it via
  the blockedGateOverride check-type — the committed review.md is the durable audit trail.
  PR body conventions codified: private-repo-safe image URLs, checkbox timing per
  phase, hero-screenshot embeds rendered correctly at Phase 6.
  Use when asked to "build it", "build this", "go", or "implement and ship". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - Agent
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# Build

Autonomous pipeline: spec → implement → quality gates → ship → CI watch → notify.

**Two modes** — auto-detected at Step 0:

- **Project mode** (default): PR-based. After this completes, the user has a PR
  ready for review with all quality gates passed, CI green, and an audit trail
  comment. The user's only action: review and say `/ak-go-live`.
- **Devshop mode** (the `/devshop` repo, including its linked worktrees —
  detected via `--git-common-dir`, see § Mode detection): no PRs, no CI watch, no deploy.
  Runs Phases 0–2 identically, Phase 3 with a reduced gate set, Phase 4.0
  bookkeeping, then Phase 4.5 invokes `/ak-merge-devshop` (squash + ff-merge
  + push). After this completes, the feature is on main. Read
  `devshop-mode.md` in this directory for devshop-specific phases.

## Non-negotiable: run the full pipeline

**Default, unconditionally: run the WHOLE pipeline — every phase, every task —
no matter how small the change seems.** Spec → implement → quality gates →
bookkeeping → ship/merge all run, top to bottom. There is no size threshold
below which the pipeline shrinks. Subagent delegation (below) makes running it
all cheap, so completeness costs almost nothing — that is the whole point of the
architecture.

**You have no discretion to hand-roll a lighter flow.** You do NOT decide a task
is "too small" for the pipeline, skip a phase to save time, or quietly drop a
step you judge unnecessary. There is **no** routine applicability check, no
per-run "is this big enough to deserve the full pipeline?" gate, and no
preliminary work-sizing beat — introducing any such routine pre-run assessment
would be the exact bias this rule exists to kill. The default is unconditional;
you run it all without asking.

**What silently disappears when you improvise a reduced flow:** the
`specs/<feature>/` artifacts (spec.md, tasks.md, and especially `review.md`'s
audit log), the `BUILD-LOG.md` ship entry, `PLAN.md` tracker movement, and the
Phase 6 PR-surface verification (project mode) / squash-message detail (devshop mode).
These are not ceremony — they are the audit trail. Dropping a phase to "save
time" deletes them with no warning to the operator.

**The single exception — ask, never act.** If you ever feel a genuine impulse to
deviate (the change truly seems to not warrant some phase), you do NOT act on it.
You STOP and fire `AskUserQuestion`, with the full pipeline as the recommended
default. The reduced-flow option is selectable only by the operator, never by
you, and only after you have enumerated exactly what it drops:

```
header: "Pipeline shape"
question: "Run the full /ak-build pipeline, or deviate? The default is the full pipeline."
options:
  1. Run the full pipeline (Recommended)
     — Every phase, every artifact, the complete audit trail. This is the
       default; pick it unless the operator has a specific reason not to.
  2. Run a reduced flow
     — REQUIRES you to first enumerate, in the question text, EXACTLY which
       phases and which specs/<feature>/ + BUILD-LOG + PLAN + PR-surface
       verification would be dropped and WHY each is safe to skip for THIS change.
       Not selectable without that enumeration.
  3. Abort
     — Stop /ak-build entirely; make no changes.
```

This is the ONLY path to anything but the full pipeline. Absent an explicit
operator pick of option 2, you run every phase.

## Architecture: subagent delegation

Heavy phases run as **subagents** via the Agent tool. Each writes results to
`specs/<feature>/` so the next subagent has full context. The main context stays
clean for orchestration and user communication.

```
/ak-build (main context — thin orchestrator)
  ├─ Phase 0 (main ctx)      → 3-section preview + user approval +
  │                             writes specs/<name>/spec.md (skeleton:
  │                             provenance + Sources + Decisions) +
  │                             starts live TaskCreate tracker
  ├─ Agent → /ak-spec        → expands specs/<name>/spec.md (Decisions
  │                             preserved verbatim; fills In scope, Task
  │                             order, Tests, etc.)
  ├─ Agent → /ak-implement   → writes specs/<name>/tasks.md + code + tests
  ├─ Agent → /ak-pre-ship    → writes specs/<name>/review.md (Gate 5
  │                             appends `## Audit 1` via /ak-check-docs-and-tests)
  ├─ Agent → /ship           → pushes, creates PR
  ├─ CI watch (main ctx)     → fix-loop, post-CI-green PR-body edits (Phase 5.1–5.6)
  ├─ Agent → /ak-check-docs-and-tests → re-audit over post-pre-ship range
  │                             (Phase 5.8 — appends `## Audit 2` to
  │                             specs/<name>/review.md; halts on high-severity
  │                             findings)
  ├─ Agent → visual refresh  → re-runs /ak-pre-ship Gates 4 + 13 over HEAD
  │                             (Phase 5.9 — overwrites stale screenshots/
  │                             hero shots; freshness-only, no halt path)
  └─ Phase 6 (main ctx)      → reads review.md (Gate N + Audit N sections) +
                                tasks.md to verify the PR surface
```

## Phase exit artifact registry

**Every phase must produce its listed artifacts before advancing.** Mechanical
checks at each boundary verify the artifacts exist; missing artifacts halt the
pipeline with the same shape as the Phase 3 → 4 `blocked > 0` halt. The checks
reference this table by row — it is the single source of truth.

| Phase | Required artifact | Producer | Checked at | Check shape |
|-------|-------------------|----------|------------|-------------|
| 0 | `$FEATURE_DIR/spec.md` (skeleton with provenance + Decisions) | Phase 0.3 | Step 0 resume check | file exists |
| 1 | `$FEATURE_DIR/spec.md` committed with `## Task order` | Phase 1.1 (commit step) | Step 0 resume check | `git show HEAD:$FEATURE_DIR/spec.md \| grep -q '## Task order'` |
| 2 | `$FEATURE_DIR/tasks.md` with all tasks `done` | Phase 2 (implement agent) | Step 0 resume check | awk parse + `reconcile-task-commits.sh` (clean tree + impl-commit-count ≥ done-count) |
| 2.5 | `$FEATURE_DIR/verification.log` (devshop mode only) | Phase 2.5 (verification agent) | Step 0 resume check | file exists (devshop only) |
| 3-preflight | `$FEATURE_DIR/gates/preflight.md` with scope vars + tooling status | Phase 3.0 | before 3.1 gate loop | file exists + result not `blocked` |
| 3-gates | `$FEATURE_DIR/gates/<name>.md` for every scope-expected gate | Phase 3.1 + 3.2 | § 3.3.1 roster check | expected-set minus found-set is empty |
| 3-hero | `$FEATURE_DIR/hero/*.png` OR `$FEATURE_DIR/hero/SKIP.md` | Phase 3.1b | § 3.3.1 roster check | one of the two exists |
| 3 | `$FEATURE_DIR/review.md` with `blocked==0`, `findings_pending==0`, no forbidden n/a | Phase 3.3 | § Phase 3 → 4 handoff | awk + grep (existing) |
| 4.1 | `/tmp/ship-body.md` (full PR body with all required sections) | Phase 4.1 | § 4.1 exit check | grep for required `##`/`###` headings |
| 5.3.5 | `$FEATURE_DIR/body-consistency.log` | Phase 5.3.5 | § 5.10 exit checklist | file exists |
| 5.8 | `$FEATURE_DIR/review.md` latest `## Audit N` stamp at HEAD (or empty-range / skip logged) | Phase 5.8 | § 5.10 exit checklist | `tail -1` stamp == HEAD |
| 5.9 | `$FEATURE_DIR/visual-refresh.log` | Phase 5.9 | § 5.10 exit checklist | file exists |
| 6-A | `/tmp/phase6-partA.done` | Phase 6 Part A | § Phase 6 exit checklist | file exists |
| 6-B | `/tmp/phase6-partB.done` | Phase 6 Part B | § Phase 6 exit checklist | file exists |
| 6-C | `/tmp/phase6-partC.done` | Phase 6 Part C | § Phase 6 exit checklist | file exists |
| 6-D | `/tmp/phase6-partD.done` | Phase 6 Part D | § Phase 6 exit checklist | file exists |

Phase 6 markers use `/tmp/` (ephemeral — Parts re-run from scratch on
resume). All other artifacts use `$FEATURE_DIR/` (durable — survive
session crashes and inform Step 0's resume check).

## Step 0: Determine feature and resume state

### Mode detection

```bash
GIT_ROOT=$(git rev-parse --show-toplevel)
# A linked worktree of /devshop (`.worktrees/<topic>/`) has its OWN
# --show-toplevel (the worktree path, NOT /devshop), so a bare GIT_ROOT check
# would mis-detect devshop work done in a worktree as project mode. The
# worktree's --git-common-dir still points at /devshop/.git, which is the
# reliable signal. Resolve it to an absolute path (it's the relative `.git`
# from the main worktree, already absolute from a linked worktree) and treat
# the session as devshop mode when EITHER GIT_ROOT is /devshop OR the
# common-dir belongs to /devshop.
GIT_COMMON=$(git rev-parse --git-common-dir)
case "$GIT_COMMON" in
  /*) ;;                                    # already absolute (linked worktree)
  *) GIT_COMMON="$GIT_ROOT/$GIT_COMMON" ;;  # relative ".git" → absolutize
esac
if [ "$GIT_ROOT" = "/devshop" ] || [ "$GIT_COMMON" = "/devshop/.git" ]; then
  MODE="devshop"
else
  MODE="project"
fi
```

Surface the mode in terminal output: `"Mode: $MODE"`.

The `--git-common-dir` check is load-bearing for worktree-based devshop work:
`git worktree add .worktrees/<topic>` is the documented parallel-work flow
(`/devshop/CLAUDE.md § Parallel work via linked worktrees`), and inside such a
worktree `git rev-parse --show-toplevel` returns the worktree path, not
`/devshop`. Without the common-dir fallback the orchestrator would run a
project-mode pipeline (PRs, CI watch, deploy) against the devshop repo. The
`session-start.sh` hook already routes worktree sessions to devshop context;
this keeps `/ak-build`'s own mode detection consistent with it.

When `MODE=devshop`, read `devshop-mode.md` in this skill's directory for
devshop-specific phase behavior. The sections below note `(devshop: ...)` at
decision points where the modes diverge.

### Derive feature name and ensure branch
```bash
BRANCH=$(git branch --show-current)
```

If on `main`, find or create the right branch:

1. **Check for in-progress work** — look for open PRs or local feature/fix branches:
   ```bash
   # Open PRs from feat/feature/fix branches (project mode only)
   [ "$MODE" = "project" ] && gh pr list --state open --json headRefName --jq '.[].headRefName' 2>/dev/null
   # Local feat/feature/fix branches (both modes)
   git branch --list 'feat/*' 'feature/*' 'fix/*'
   ```
2. **If existing branch found** → ask the user which one to resume, switch to it:
   ```bash
   git checkout <prefix>/<name>
   ```
3. **If no existing branch** → determine the feature name from `PLAN.md § Planned`
   (top-ranked row) or (project mode only) from the gstack plan artifacts
   under `.gstack/projects/<slug>/`.
   Pick the feat-vs-feature prefix by detecting the project's prevailing
   convention from existing branches (count `feat/*` vs `feature/*` across
   local + remote refs); default to `feat/` on greenfield projects (both
   counts zero) — it's the shorter form and matches the conventional-commit
   type prefix (`feat:` / `fix:` / `chore:` already use the short form
   everywhere). Use `fix/` instead when the work is a bug fix.

   ```bash
   FEAT_COUNT=$(git branch --list --all 'feat/*' '*/feat/*' 2>/dev/null | wc -l)
   FEATURE_COUNT=$(git branch --list --all 'feature/*' '*/feature/*' 2>/dev/null | wc -l)
   if [ "$FEATURE_COUNT" -gt "$FEAT_COUNT" ]; then
     PREFIX="feature/"   # project history favors the long form
   else
     PREFIX="feat/"      # greenfield default OR project favors the short form
   fi
   # Override to fix/ if the work is a bug fix:
   # PREFIX="fix/"
   git checkout -b "${PREFIX}<name>"
   ```

Re-read the branch after switching:
```bash
BRANCH=$(git branch --show-current)
FEATURE=$(echo "$BRANCH" | sed 's|^feat/||;s|^feature/||;s|^fix/||')
FEATURE_DIR="specs/$FEATURE"
```

If already on a `feat/*`, `feature/*`, or `fix/*` branch, skip straight to the resume check.

### Resume check

Detect where a previous run left off. Evaluate top-to-bottom; the first match wins:

**(Devshop mode — rungs 1d, 2d replace rung 1)**

1d. **(devshop only) Already merged to main?** — `$FEATURE` appears in a
   commit on `main` AND no local feature branch exists → "Feature already
   shipped. Nothing to do." Exit cleanly.

2d. **(devshop only) Phase 3 + 4.0 ran, merge pending?** —
   `$FEATURE_DIR/review.md` exists AND `$FEATURE_DIR/tasks.md` has all
   tasks `done` AND `BUILD-LOG.md` contains an entry for `$FEATURE` →
   skip to Phase 4.5 (`/ak-merge-devshop`). See `devshop-mode.md §
   Resume check adaptations`.

**(Project mode — rung 1)**

1. **(project only) Open PR for this branch?** → skip to Phase 5 (CI watch)
   ```bash
   PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty')
   ```
   Two sub-rungs land closer to Phase 6 if their artifacts already match HEAD —
   the per-phase idempotence checks (5.8 § Idempotence, 5.9 § Idempotence) do
   the same work, but pinning them in the resume tree saves a session-restart
   from re-spawning a subagent that would no-op anyway:
   - **1a.** Open PR + `$FEATURE_DIR/review.md` has a latest `## Audit N`
     section whose `<!-- audited-at: <SHA> -->` SHA equals current `HEAD` →
     skip Phase 5.8 specifically (jump straight to 5.9, then Phase 6). Use
     the same parser one-liners as `/ak-check-docs-and-tests § Step 2`:
     ```bash
     LATEST_AUDIT_SHA=$(grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' \
       "$FEATURE_DIR/review.md" 2>/dev/null | tail -1)
     ```
     Note: `tail -1` (not `head -1`) because Audit N sections append over
     time — the latest section is the bottommost stamp in the file.
   - **1b.** Open PR + `git status --porcelain -- "$FEATURE_DIR/screenshots" "$FEATURE_DIR/hero" 2>/dev/null` is empty AND the latest commit touching either dir is at HEAD → skip Phase 5.9 specifically (jump to Phase 6).
   - Both sub-rungs satisfied → skip 5.8 + 5.9 entirely → Phase 6.

**(Both modes — rungs 2–6)**

2. **`$FEATURE_DIR/tasks.md` exists with all tasks `done`?** → **reconcile before trusting it.** A dropped `/ak-implement` subagent can mark tasks `done` before committing (or leave work uncommitted), so an "all done" file is not sufficient on its own. Run:
   ```bash
   bash kit/scripts/reconcile-task-commits.sh "$FEATURE_DIR" "origin/${BASE:-main}"
   ```
   (`$BASE` is the PR base, set later in Phase 5/6; at Step 0 it is usually unset, so default to `main` — the base every devshop feature branch targets.)
   - **Exit 0** (trustworthy — clean tree AND impl-commit-count ≥ done-count) → skip to Phase 3 (pre-ship). **(Devshop mode)**: if `$FEATURE_DIR/verification.log` does NOT exist → run Phase 2.5 first (see `devshop-mode.md § Phase 2.5`), then Phase 3.
   - **Non-zero** (dirty tree, or fewer implementation commits than `done` tasks — a `done` marker with no matching commit) → **do NOT skip to Phase 3.** Fall through to rung 3's destination (**re-enter Phase 2**, which resumes internally and re-verifies per-task), and print the helper's diagnostic loudly to the terminal: `Resume reconcile FAILED: <diag> — re-entering Phase 2`. The count heuristic is rebase-/amend-robust and a false-fail is cheap (Phase 2 re-verifies and no-ops if work is genuinely complete), so the safe action on any non-zero exit is always re-enter Phase 2, never skip ahead. See `kit/scripts/reconcile-task-commits.sh` for the contract; the helper is bats-covered in `kit/tests/util-reconcile-task-commits.bats`.
3. **`$FEATURE_DIR/tasks.md` exists with some tasks `done`?** → skip to Phase 2 (implement resumes internally). This is also where rung 2 lands when its reconcile fails — same destination (re-enter Phase 2), and the rung-2 reconcile diagnostic is surfaced so the operator sees *why* an "all done" file did not skip.
4. **`$FEATURE_DIR/spec.md` committed at HEAD with `## Task order`?** (`git show HEAD:$FEATURE_DIR/spec.md | grep -q '## Task order'`) → full spec written AND committed by Phase 1 → skip to Phase 2 (implement)
5. **`$FEATURE_DIR/spec.md` committed at HEAD but lacks `## Task order`?** → Phase 0.3 committed the skeleton (provenance + Decisions only); Phase 1 hasn't completed (or crashed before its 1.1 commit) → re-run Phase 1. Spec agent reads the existing file, preserves its Decisions section verbatim, and expands into the full spec; Phase 1.1 commits it. Do NOT re-prompt the user.
6. **None of the above** → start from Phase 0 (preview + spec skeleton)

Log resume point: "Resuming from Phase N: <reason>"

**Remote-control nudge on resume paths**: when the resume check lands at
rungs 1–5 (i.e. N > 0 — skipping Phase 0's interactive beat entirely),
emit the Phase 0.5 nudge once before advancing to the target phase. This
mirrors the fresh-run timing: nudge = last beat before autonomous work
starts. On rung 6 (N = 0, fresh run), Phase 0.5 handles the nudge itself
after the decisions preview.

**What "skip to Phase N" means**: start executing at Phase N. Some phases have
recoverable state (Phase 2 resumes per-task from `tasks.md`; Phase 5 resumes
polling the latest CI run), some are atomic re-runs (Phase 1 spawns a fresh
spec subagent; same inputs → same output). The resume check just identifies
which artifacts already exist so earlier phases can be skipped.

The `## Task order` header is the discriminator between a Phase 0 skeleton and
a Phase 1 completed spec, because every spec produced by `/ak-spec` contains
that section (it's the dependency-ordered task list `/ak-implement` consumes).
Phase 0 never writes it; Phase 1 always does, and Phase 1.1 commits it, so Step 0
reads the discriminator from the committed `spec.md` (`git show HEAD:…`), not the
working tree.

## Phase 0: Preview + decisions checkpoint

This pre-flight previews the build; it never decides whether to run it — the full
pipeline runs by default per `§ Non-negotiable: run the full pipeline`, and any
deviation goes through that section's `AskUserQuestion`, never a silent scope-down.

Before spawning any subagent, produce a pre-flight preview so the user can flag
scope or decision issues before token-heavy work begins. Catching a mis-shaped
build here is orders of magnitude cheaper than discovering it mid-Phase 2 (which
has already burned context writing code around the wrong decision).

Skip Phase 0 entirely when the resume check lands at step 5 — the `spec.md`
skeleton already exists from a prior run, meaning the user already approved
the decisions it contains.

### 0.1: Read sources

Read enough context to produce the preview accurately.

**Project mode** inputs:

- `PRODUCT-ROADMAP.md` section for this feature (e.g., `§ v0 § 1e`) — primary
  scope and the enumerated `/ak-spec`-time decisions.
- `PLAN.md` row Notes for this feature — scope summary and source pointer.
- `DESIGN.md` at repo root, if the feature touches UI.
- `.gstack/projects/<slug>/*-design-*.md` (newest by mtime), if present.
- `.gstack/projects/<slug>/*-test-plan-*.md` (newest by mtime), if present.
- Prior PR's spec (`specs/<prior-feature>/spec.md`) as a style/structure reference.

**Devshop mode** inputs (see `devshop-mode.md § Phase 0 source routing`):

- `kit/ROADMAP.md` section for this feature (matched via Source column in
  `PLAN.md`) — primary scope and decisions.
- `kit/TODOS.md` entries the feature closes, if any.
- `PLAN.md` row for this feature — scope summary and source pointer.
- Prior shipped spec (`specs/<prior-feature>/spec.md`) as a
  style/structure reference.
- Do NOT read: `PRODUCT-ROADMAP.md`, `DESIGN.md`, `.gstack/projects/`.

### 0.2: Produce the 3-section preview

Output a single message with these three sections, in order:

**1. Decisions** — table with columns `# / Question / Proposed answer / One-line
rationale`. Include every `/ak-spec`-time decision called out in the scope
source (or discovered by reading test-plan / design docs). If a decision is
genuinely a judgment call the user must make (e.g., adding new metric events),
mark it `[USER MUST DECIDE]` in the "Proposed answer" column — don't fake a
default.

**2. Scope** — bullets at the *what* level: screens added, migrations, new
events, files in broad strokes. Stay at one-screen-scannable granularity. Do
NOT include: full per-decision rationale (§1), file-level diffs (spec owns),
test coverage matrices (spec owns), rollout/rollback plans (spec owns). The
preview is "what would you object to?", not "here's the spec."

The **first two named bullets of Scope** are the canonical product blurbs
the spec's `## Product update` section will carry — both audiences,
authored here at Phase 0 so the operator approves them inline alongside
the rest of Scope rather than as a fourth preview section. Same shape both
times, drawn from the roadmap row's Hook + sources read at §0.1:

- **Headline (user-facing, 1–2 sentences, zero eng terms)**: <one-line
  marketing-grade copy for end-user / changelog audience>. No enum names,
  no RPC names, no migration numbers, no component PascalCase, no route
  paths, no cross-PR references. Phase 0.2.6 lints for these patterns
  before the operator sees the preview — if the lint fires, rewrite the
  bullet to plain English and re-run before printing.
- **Detail (team-facing, 1–4 sentences, light eng OK)**: <expanded copy
  for the future-me reader / cold reviewer / BUILD-LOG scanner>. Explain
  the eng vocabulary the Headline elided.

After those two named bullets, list the remaining scope items normally
(screens, migrations, events, files-in-broad-strokes). Operator approves
both blurbs as part of approving Scope. If a PR is small enough that the
two blurbs would be word-for-word identical, collapse them under a single
`Headline + Detail (combined)` bullet — downstream surfaces route correctly.
For pure infra PRs the Headline literally reads
`Infrastructure update — no user-visible change in this PR.`; same shape,
infra-flavored — don't fabricate marketing copy for an infra change.

**3. Tracker (the live view you'll see come alive)** — hierarchical, mirroring
exactly what Phase 0.4 will instantiate via `TaskCreate`. The harness's task
list is flat (no real parent field), so sub-tasks **prefix their parent phase
in the subject** — that prefix is what makes the parent-child relationship
visible:

**Project mode:**

```
Phase 1: Spec
Phase 2: Implement
Phase 2 / Task 1: <first implementation task>
Phase 2 / Task 2: <second>
…
Phase 2 / Task N: <last>
Phase 3: Pre-ship
Phase 4: Ship
Phase 5: CI watch + BUILD-LOG
Phase 6: Verify PR surface
Phase 7: Notify
```

**Devshop mode** (see `devshop-mode.md § Tracker hierarchy`):

```
Phase 1: Spec
Phase 2: Implement
Phase 2 / Task 1: <first implementation task>
…
Phase 2 / Task N: <last>
Phase 3: Pre-ship (devshop gate set)
Phase 4.0: BUILD-LOG + PLAN closure
Phase 4.5: /ak-merge-devshop
```

Derive the Phase 2 sub-tasks from the roadmap's numbered subsections + any
obvious dependency-order tasks (e.g., migrations first, E2E last). This is a
rough cut; Phase 1's spec will refine it. Usually the spec adds 1–2 sub-steps
but doesn't change the overall shape.

End the preview with: **"Proceed? or flip any decision / trim scope / add task?"**

Wait for the user's response. Do NOT proceed to 0.3 without explicit approval.

### 0.2.6: Headline forbidden-vocabulary lint (auto-flip eng leaks before preview)

Before printing §0.2's preview, scan the drafted Headline bullet for
eng-vocabulary patterns the marketing-grade copy must not contain. The
spec agent's first draft tends to leak eng terms ("the `monitor` state",
"the new RPC", "DecideCard component"); catching them here means the
operator sees a clean Headline at preview time rather than re-litigating
the lint at Phase 6.

Forbidden patterns (each is a soft signal — the lint warns + suggests a
rewrite, not a hard fail):

- **Backtick-fenced identifiers** (`` `card_state` ``, `` `confirm_triage` ``)
  — anything in inline code is by definition eng vocabulary. Rewrite to
  plain English (`the card's path`, `the confirm step`).
- **snake_case tokens** outside backticks (`card_state`, `confirm_triage`)
  — same shape, no backticks. Same rewrite.
- **PascalCase component names** (`DecideCard`, `PathCard`, `AwaitingConfirmationCard`)
  — TSX component identifiers. Rewrite to the UI element ("the decide
  card", "the path card", "the confirmation card") or omit.
- **RPC / function suffix patterns** (`*_rpc`, `*Rpc`, `*RPC`,
  `.invoke(`, names ending in `()`) — backend call references. Rewrite
  to user-action verb ("save", "submit").
- **Migration numbers** (`migration 011`, `0042_<name>`, `supabase/migrations/...`) —
  internal schema references. Omit entirely (the user doesn't read these).
- **Route paths** (`/app/...`, `/api/...`, route segments with brackets) —
  routing internals. Rewrite to the screen name in plain English.
- **Cross-PR references** (`PR #N`, `PR N`, `#42`) — drift surface; Headline
  is per-PR, not a release-aggregate.

Implementation:

```bash
HEADLINE="$1"  # the drafted Headline string from §0.2

LINT_FINDINGS=""
echo "$HEADLINE" | grep -oE '`[^`]+`' | while read -r m; do
  LINT_FINDINGS+="  • backticked identifier: $m\n"
done
echo "$HEADLINE" | grep -oE '\b[a-z]+_[a-z_]+\b' | while read -r m; do
  LINT_FINDINGS+="  • snake_case token: $m\n"
done
echo "$HEADLINE" | grep -oE '\b[A-Z][a-z]+([A-Z][a-z]+)+\b' | while read -r m; do
  LINT_FINDINGS+="  • PascalCase component: $m\n"
done
echo "$HEADLINE" | grep -oE '\b\S+_rpc\b|\b\S+Rpc\b|\b\S+RPC\b|\.invoke\(' | while read -r m; do
  LINT_FINDINGS+="  • RPC/function pattern: $m\n"
done
echo "$HEADLINE" | grep -oE 'migration [0-9]+|\b[0-9]{4}_[a-z_]+\b|supabase/migrations/' | while read -r m; do
  LINT_FINDINGS+="  • migration reference: $m\n"
done
echo "$HEADLINE" | grep -oE '/[a-z]+(/[a-z\[\]\-]+)+' | while read -r m; do
  LINT_FINDINGS+="  • route path: $m\n"
done
echo "$HEADLINE" | grep -oE '\bPR ?#?[0-9]+\b|#[0-9]+\b' | while read -r m; do
  LINT_FINDINGS+="  • cross-PR reference: $m\n"
done
```

If `$LINT_FINDINGS` is empty → continue to §0.2 / §0.2.5. The Headline is
already audience-shaped.

If non-empty → rewrite the Headline bullet to plain English (drop the
flagged tokens, replace with user-facing equivalents) BEFORE printing the
§0.2 preview. Print a one-line note in the preview noting the rewrite
happened so the operator sees the spec agent's first-pass voice was
corrected ("Headline auto-rewrote to strip eng vocabulary — operator can
revert at preview time if a flagged term was intentional"). Detail is
NOT linted — light eng context is allowed there by contract.

The lint is **advisory at Phase 0** (rewrite + note, don't halt) because
audience-shape is a judgment call the operator owns. The same patterns
are checked at Phase 5.3.5 drift-signal #5 and Phase 6 Gate B as
audience-mismatch warnings — three rungs, increasing the cost of leaking
eng vocabulary at each step.

### 0.2.5: Empirical-verify load-bearing decisions before locking

For any decision where the proposed answer's correctness turns on **"does X
work in version Y of Z"** — a framework's resolution order, a library's
default behavior, an API's edge-case semantics, a runtime's contract — run
the empirical test BEFORE the user approves. Cost is typically 30 seconds;
the alternative is committing implementation code against an unverified
hypothesis and discovering the hypothesis was wrong mid-Phase 2 (which
burns the implementation commit + the revert + a re-spec round-trip + the
operator's attention).

**Triggering signals** in a Decision row:

- "vN of Z does/should X" without a citation that proves it
- "framework documentation says..." paired with an inferred extrapolation
- "this is the standard behavior" applied to an edge-case combination
- Any decision whose proposed answer reads as a hypothesis the spec author
  is fairly confident in but hasn't actually run

**How to verify** depends on the layer:

- Build-system / token resolution → run the compiler directly against a
  fixture (e.g. `node -e "import('@tailwindcss/node').then(m =>
  m.compile(...).build([...]))"`) and grep the output.
- API / SDK behavior → minimal repro script that exercises the specific
  call shape against the actual library version pinned in
  `package.json`.
- Database / driver behavior → spin a transaction in `psql` against the
  local stack and check the side effects.
- Browser / runtime behavior → 5-line Playwright spec or `node:test` that
  asserts the load-bearing assumption.

**Codified from**: lalista PR 53 (2026-05-08). D1 was "define Tailwind v4
`--container-*` tokens to override the `--spacing-*` fall-through for
`max-w-*` named keys." Hypothesized the override would work; shipped the
implementation commit; discovered via direct `@tailwindcss/node@4.2.4`
compile that v4 4.2.x DOES resolve every named-key max-w through
`--spacing-*` regardless of what's defined under `--container-*`. Reverted
in the same PR and shipped the surgical fallback (D2). The 30-second compile
test would have flipped D1 from "global with surgical fallback" to just
"surgical" before any code was written, saving the failed-attempt commit +
revert + the operator's review of the empirical disconfirmation. Apply
this rule when a decision's proposed answer reads "X should work because Y"
and the verification cost is under a minute.

If the empirical test contradicts the hypothesis, **rewrite the decision
row** with the verified answer (not the hypothesis) before showing the
preview to the user. Don't mark the row "verified" without showing the
verification — say which test ran, what command produced what output, where
the test artifact lives. Loud verification beats silent extrapolation.

### 0.3: Persist approved decisions as a spec.md skeleton

Once the user approves (or after any flips they request), write
`$FEATURE_DIR/spec.md` as a **skeleton** — provenance header + Sources list +
feature one-liner + the canonical `## Product update` section (both blurbs
verbatim from the §0.2 preview) + fully-populated Decisions section. Phase
1's spec agent reads this same file, preserves the Product update and
Decisions sections verbatim, and expands everything below into the full
spec. One file, one source of truth, no second artifact to keep in sync.

```markdown
<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: <name> -->
<!-- date: YYYY-MM-DD -->

# Spec: <feature> (PR N)

**Sources:**

- `PRODUCT-ROADMAP.md § ...` — primary scope
- `.gstack/projects/<slug>/*-design-*.md` — design reference (if present)
- `.gstack/projects/<slug>/*-test-plan-*.md` — test plan (if present)
- `DESIGN.md` — token map, motion, aesthetic (if UI-touching)
- Prior spec `specs/<prior>/spec.md` — style + structure reference

(Feature one-liner — what PR N turns into at the user level.)

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — `/ak-build`
Phase 4.1 copies them verbatim into the PR body's `## Product update`
section, Phase 5.6 copies Headline into BUILD-LOG `Headline:` and Detail
into `Summary:`, and `/ak-go-live` Step 6 uses Headline as the
deployed-to-prod lede. Verified
against the diff at Phase 6 Gate A (autonomous claim-vs-diff review) + Gate B
(automated claim-vs-diff cross-check). Collapse to
`### Headline + Detail (combined)` if the two would be word-for-word
identical.

### Headline (user-facing)

<1–2 sentences, zero eng terms — see /ak-spec § Product update for the
forbidden-vocabulary list>

### Detail (team-facing)

<1–4 sentences, light eng context OK — see /ak-spec § Product update for
the contract>

---

## Decisions (resolved at spec time)

N `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: <decision topic>

**Decision:** <user-approved answer>

**Rationale:** <1–2 lines>

### D2: …

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Screens, Data
     model changes, API contracts, Offline behavior, Metrics, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. The Product update + Decisions sections above
     stay verbatim. -->
```

Commit this file immediately on the feature branch so it survives a crash:

```bash
mkdir -p "$FEATURE_DIR"
# write $FEATURE_DIR/spec.md per template above
git add "$FEATURE_DIR/spec.md"
git commit -m "chore($FEATURE): Phase 0 spec skeleton (decisions)"
```

No push yet — the feature-branch push happens in Phase 4 along with the rest
of the implementation. The Phase 0 commit just needs to exist locally so a
session crash + restart finds the skeleton via Step 0's resume check.

### 0.4: Start the live tracker

Call `TaskCreate` to instantiate the hierarchical tracker from §0.2 item 3 —
one task per row. Mark Phase 1 `in_progress` the moment you spawn its
subagent; mark `completed` when it returns. Expand / correct Phase 2
sub-rows against `spec.md § Task order` once Phase 1 finishes — if the
spec's tasks shifted from the preview, update the tracker rows to match.
Add new rows dynamically for:

- Phase 3 findings as they're surfaced — prefixed with their parent phase
  (e.g., `Phase 3 / Finding: CSP fix on PathCard.tsx`).
- Phase 5 CI fix-loop attempts when the loop fires — one row per attempt
  (e.g., `Phase 5 / Fix attempt 2: lint failure on PathCard.tsx`).
- Ad-hoc user corrections mid-flight — also prefixed (e.g., `Phase 1 / D7
  flip: revisit decision after operator objects`).

**Subject-prefix convention** (load-bearing for the live view): when a
phase decomposes into sub-units, every sub-task's `TaskCreate` subject
**must** prefix its parent phase as `<Phase X> / <sub-unit>`. The harness's
task list is flat — no real parent field — so the prefix is the only
signal that makes the parent-child relationship visible. Without it,
sub-tasks render as flat peers of the phase rows and an operator watching
from `/remote-control` can't tell whether `Phase 3: in_progress` means
the gauntlet is at Gate 1 or Gate 12.

The convention applies to every sub-task this skill (or its subagents)
creates:

- Phase 2 implementation tasks: `Phase 2 / Task N: <subject from spec>`
  (`/ak-implement` calls `TaskUpdate` on these rows as it progresses).
- Phase 3 gate findings and ad-hoc fixes during pre-ship.
- Phase 5 CI fix-loop attempts (the bookkeeping commit now lands at
  Phase 4.0, before `/ship` pushes — no separate Phase 5 tracker row).
- Phase 5.8 / 5.9 sub-jobs when those fire (`Phase 5.8 / Audit N`,
  `Phase 5.9 / Visual refresh`).

If `TaskCreate` is not available in the current harness, narrate progress in
text instead — the tracker is a visibility aid, not a correctness requirement.

### 0.5: Remote-control nudge (last beat before autonomous work)

Emit a short reminder in user-facing text, placed immediately before spawning
the Phase 1 subagent:

> 💡 Pipeline is about to run autonomously. If you want to monitor progress
> from phone / watch / another device, type `/remote-control` now to connect
> this session. The rest of /ak-build is unattended until the PR is ready.

Timing matters: the nudge must appear AFTER the decisions preview + skeleton
commit + tracker start, so it's the last thing the user sees before stepping
away — not buried above the interactive decisions list (which they'll scroll
past and forget).

Resume paths that skip Phase 0 (because `specs/<feature>/spec.md` already
exists from a prior run, or the resume check lands at a later phase) should
still emit this nudge once — right before the first subagent spawn on the
resume path. See Step 0's resume-check section for the resume-path hook.

The nudge fires once per `/ak-build` invocation regardless of path. It's a
visibility aid — do NOT gate the pipeline on whether `/remote-control` is
active (we can't detect that from inside the skill, and the user may
legitimately not want it enabled).

### 0.6: Staleness check (both modes)

Before spending tokens on spec expansion and implementation, verify the
PLAN row's Source entry still applies. See `devshop-mode.md § Phase 0.5:
Staleness check` for the full procedure.

1. Read the Source column from the PLAN row for `$FEATURE`.
2. Follow the pointer to the source file (project: `PRODUCT-ROADMAP.md`;
   devshop: `kit/ROADMAP.md` or `kit/TODOS.md`).
3. Compare key assertions against recent git history and current codebase.
4. Surface concerns via `AskUserQuestion` if high-confidence. Advisory, not
   blocking — "Proceed anyway" is the recommended default.

Skip when the resume check landed at rung 5+ (spec skeleton exists from a
prior run — user already approved the decisions it contains and the staleness
context hasn't changed since then).

---

## Phase 1: Spec

Launch **Agent** with prompt:
> Run /devshop:spec for feature "$FEATURE".
> Read $FEATURE_DIR/spec.md — this is the Phase 0 skeleton containing the
> provenance header, Sources list, feature one-liner, and user-approved
> Decisions section. Preserve those sections verbatim. Expand the file below
> the Phase-1-expand marker comment with the full spec body (In scope,
> Screens, Data model changes, API contracts, Offline behavior, Metrics,
> Files to create/modify, Tests, Dependencies, Task order, Gotchas,
> Acceptance / rollout / rollback). Your output is the same file, now
> complete. Do NOT re-resolve decisions.
> If METRICS.md needs new events AND the skeleton's Decisions section did
> not already cover them, stop and ask me before adding them.
> Return a one-line summary of what was written.

When Phase 0 ran, the spec skeleton exists with every `/ak-spec`-time
decision (including new METRICS events) already user-approved. The
METRICS-confirmation fallback above only fires when the skeleton is missing
those decisions — rare, and only happens if the user manually seeded the
feature branch without going through `/ak-build` Phase 0.

**(Devshop mode)**: add to the spec subagent prompt: `"This is
devshop-self-mode. There is no METRICS.md; skip the metrics-confirmation
step. The test surface is bats (kit/tests/), not vitest/Playwright."`

### 1.1: Commit the expanded spec

When the spec subagent returns, the expanded `spec.md` is sitting uncommitted
in the working tree — only the Phase 0.3 skeleton commit and (later)
`tasks.md` have landed. Commit the expansion now so a crash between here and
the next sweeping commit can't silently lose it (and so Step 0's resume
check, which reads committed state, sees a complete spec rather than
re-running Phase 1):

```bash
git add "$FEATURE_DIR/spec.md"
# Idempotence guard: skip the commit if spec.md is already committed at HEAD
# (Phase 1 is an atomic re-run on resume — same inputs, same output, so a
# re-entry where the spec is already committed must no-op, not error with
# "nothing to commit").
if ! git diff --cached --quiet -- "$FEATURE_DIR/spec.md"; then
  git commit -m "docs($FEATURE): expand spec (Phase 1)"
fi
```

No push yet — the feature-branch push happens in Phase 4 / 4.5 along with the
rest of the implementation. This commit just needs to exist locally so a
session crash + restart finds the full spec via Step 0's resume check
(rung 4). This step applies to **both modes** — Phase 1 is the shared
section; the `(Devshop mode)` note above is only a prompt addendum, not a
separate Phase 1. Mirrors the Phase 0.3 skeleton commit
(`chore($FEATURE): Phase 0 spec skeleton`).

## Phase 2: Implement

Launch **Agent** with prompt:
> Run /devshop:implement for feature "$FEATURE".
> Read the spec from $FEATURE_DIR/spec.md.
> Write tasks and decisions to $FEATURE_DIR/tasks.md.
> Follow the implementation loop: write code + tests, stuck protocol if needed,
> commit per task. Return: number of tasks completed, number of commits, test status.

`/ak-implement` has its own stuck protocol:
- Try fix × 2 → `/investigate` → ask user if still stuck
- Writes `$FEATURE_DIR/tasks.md` with `## Decisions` section (judgment calls made)
- Commits atomically per task

Wait for agent to report completion (all tasks `done`).
If agent reports any task `blocked`, stop and escalate (see Escalation below).

**On a non-clean subagent return (socket drop / context exhaustion — no
all-tasks-`done` signal):** the *current* invocation already halts here — it
never receives the clean completion signal, so it cannot advance. The silent-skip
risk is on the **next** `/ak-build` invocation's Step 0 resume check, where an
"all done" `tasks.md` written just before the drop (or with uncommitted task
work) could otherwise skip Phase 2. That is exactly why the reconcile gate lives
at **Step 0 rung 2** (`kit/scripts/reconcile-task-commits.sh`), not at this live
Phase 2 return: it re-checks the `done` markers against actual git state — clean
tree + enough implementation commits — before the next resume trusts them. See
Step 0 rung 2 for the gate; `/ak-implement` Step 3/4 reaffirms that a task is
`done` only once its work is committed and the tree is clean.

## Phase 3: Pre-ship (per-gate sub-agent gauntlet)

**(Devshop mode)**: read `devshop-mode.md § Phase 3: Pre-ship — devshop gate
set` for the reduced gate set (7 dispatched, 12 pre-composed carve-outs)
and the structural carve-out advance-log handling. The two-pass structure
(Stabilize-HEAD + Analysis) is the same; only the gate roster differs.

**Project mode** (below):

Phase 3 runs the `/ak-pre-ship` gauntlet as a series of **per-gate sub-agent
dispatches** in two ordered passes. Each gate is one `Agent` tool invocation
with a fresh context bounded to its own scope. Each sub-agent writes its
findings to a **per-gate file sink** under `specs/<feature>/gates/<gate-name>.md`
using the canonical name from `pre-ship/SKILL.md § Gates (canonical order + named
IDs)`. The orchestrator concatenates the per-gate sinks into
`$FEATURE_DIR/review.md` after each pass.

**Why decomposed.** A single sub-agent running the full 18-gate gauntlet (the
canonical count from `pre-ship/SKILL.md § Gates`) is one point of failure for
the whole pass. When that agent's socket / context / runtime fails partway
through (as happened on home-os feature/decide-state 2026-05-17 at Gate 6 of
its run after ~2h / 207 tool uses), all completed-gate work became hard to
resume. Per-gate dispatch isolates failure: one dropped agent loses one gate's
work. Per-gate file sinks survive the agent boundary, so re-running picks up
at the gate that dropped.

**Phase 0 (preflight) runs first, before either pass.** `pre-ship/SKILL.md §
Phase 0: Preflight` is a tooling verification step (Chromium available, browse
daemon healthy, etc.), not a gate. It runs in-line in the orchestrator before
3.1 fires its first sub-agent dispatch. On a `blocked` outcome, the orchestrator
halts Phase 3 entirely without writing any per-gate sink.

**Why two passes.** Gates split into two classes:

- **Stabilize-HEAD gates** (sequential — each may commit fixes that mutate
  HEAD; later gates audit the new HEAD), in canonical order from
  `pre-ship/SKILL.md § Gates`:
  - `1 docs-check` → `2 metrics-check` → `2b rls-coverage` → `2c slow-job-lifecycle`
    → `2d fast-job-local` → `2e migration-rollback-roundtrip` → `2f changed-tests-local`
    → `2g advisor-clean` → `3 responsive-theme` → `4 /simplify` →
    `8 /design-review` (UI PRs only) → `9 /qa` → `11 convention`.
  - Hero-screenshot capture runs as an orchestrator-side step after the
    Stabilize-HEAD pass completes — see § 3.1b below. It is NOT dispatched as
    a per-gate sub-agent and has no `gates/<name>.md` sink (hero shots commit
    directly to `specs/<feature>/hero/`).
- **Analysis-pass gates** (parallel — read-only against the stabilized HEAD),
  in canonical order:
  - `5 docs-and-tests-review` (Audit 1) ‖ `6 /review` ‖ `7 /cso` ‖
    `8b design-conformance` ‖ `10 /benchmark` (UI PRs only) ‖ `10b preflight-final`.

The Stabilize-HEAD pass runs gates sequentially (one Agent call at a time)
because iterative-fix gates may commit on HEAD. The Analysis pass dispatches
all its gates in a single tool-use turn (multiple `Agent` calls in one turn),
because every gate is read-only against the same SHA.

**Per-gate file sinks.** Each gate sub-agent writes its `## Gate <#>: <name>`
section to its own file at `specs/<feature>/gates/<canonical-gate-name>.md`
(names from `pre-ship/SKILL.md § Gates`, e.g. `docs-check.md`, `cso.md`, `qa.md`).
The orchestrator concatenates these into `review.md` after each pass — first
the Stabilize-HEAD sections in canonical order, then the Analysis sections in
canonical order. The shards are committed alongside `review.md` for durability
(a crashed-mid-concatenate resume re-reads them; a re-run of a single gate
overwrites just that one shard).

**Halt-on-find vs iterative-fix dispatch.** Two categories of gate determine
who fixes findings:

- **Iterative-fix gates** (`/simplify`, `/design-review`, `/qa`,
  `design-conformance`, `convention`, `/benchmark` when surfaceable): the
  sub-agent finds AND fixes AND commits atomically per fix. Same posture as
  the pre-decomposition gauntlet. Status on return: `pass` /
  `findings (N) fixed` / `blocked`.
- **Halt-on-find gates** (`/review`, `/cso`, `docs-and-tests-review`/Audit 1,
  `rls-coverage`): the sub-agent surfaces findings, returns. The orchestrator
  routes by severity: high → escalate to operator (Rung 1); medium → record in
  `review.md`; low → note + proceed; **mechanical/obvious** →
  orchestrator dispatches a focused fix sub-agent (template at § 3.1c).
  Preserves the existing trust boundary on security/SQL-critical findings
  (don't auto-fix without operator read).

  **What counts as "mechanical/obvious"** (the line between auto-fix and
  escalate):
  - Single-file diff with **no public-API change** (function signatures,
    exported types, edge-function URLs all unchanged).
  - No auth / RLS / migrations / `supabase/functions/**` surface touched.
  - Fix shape names a specific line + replacement (e.g. "remove unused
    `console.log` at `foo.ts:42`" — yes; "rethink the cache invalidation
    strategy" — no).
  - Re-running the affected gate after the fix would be deterministic (the
    fix doesn't open a new can of worms the next gate would catch).

  Everything else escalates to operator (Rung 1). When in doubt, escalate.

- **Deterministic gates** (`docs-check`, `metrics-check`, `slow-job-lifecycle`,
  `fast-job-local`, `migration-rollback-roundtrip`, `changed-tests-local`,
  `responsive-theme`, `preflight-final`): sub-agent runs the deterministic
  check; pass / findings / blocked per the check's exit status.

**Test:unit checkpoints between code-changing gates.** Between every pair of
adjacent code-changing gates in the Stabilize-HEAD pass (every iterative-fix
gate AND every halt-on-find gate whose fixes the orchestrator dispatched), the
orchestrator runs `pnpm turbo run test:unit` (turbo cache; typically ~1s when
nothing changed). On failure, the orchestrator invokes `pre-ship/SKILL.md §
Stuck protocol` at the orchestrator boundary, NOT inside the next gate
sub-agent. Keeps the per-gate context bounded to its own scope.

### 3.0: Preflight (explicit orchestrator step — runs BEFORE any gate dispatch)

Run `pre-ship/SKILL.md § Phase 0: Preflight` inline in the orchestrator.
Write the outcome to `$FEATURE_DIR/gates/preflight.md` so the roster
completeness check (§ 3.3.1) can verify preflight ran, and downstream
steps can read scope variables without re-running `git diff`.

```bash
mkdir -p "$FEATURE_DIR/gates"

git diff --name-only origin/main...HEAD > /tmp/preship-changed.txt
TOUCHES_UI=$(grep -E '^(apps/|packages/ui/|components/)' /tmp/preship-changed.txt | head -1)
TOUCHES_MIGRATIONS=$(grep -E '^supabase/migrations/' /tmp/preship-changed.txt | head -1)
TOUCHES_FUNCTIONS=$(grep -E '^supabase/functions/' /tmp/preship-changed.txt | head -1)
TOUCHES_KIT=$(grep -E '^kit/' /tmp/preship-changed.txt | head -1)
TOUCHES_CODE=$(grep -E '^(apps/|packages/(core|ui)/|.*\.(integration\.)?test\.(ts|tsx)$|apps/.*/e2e/.*\.spec\.(ts|tsx)$|supabase/(migrations|functions)/)' /tmp/preship-changed.txt | head -1)
TOUCHES_USER_CODE=$(grep -E '^(apps/|packages/)' /tmp/preship-changed.txt | head -1)
HAS_TURBO=$([ -f turbo.json ] && echo "yes" || echo "")

# Chromium check (blocking only when TOUCHES_UI is non-empty).
CHROMIUM_AVAILABLE=""
if [ -n "$TOUCHES_UI" ]; then
  CHROMIUM=$(ls /home/node/.cache/ms-playwright/chromium-*/chrome-linux/chrome 2>/dev/null | head -1)
  CHROMIUM=${CHROMIUM:-$(which chromium 2>/dev/null)}
  CHROMIUM=${CHROMIUM:-$(which chrome 2>/dev/null)}
  if "$CHROMIUM" --version >/dev/null 2>&1; then
    CHROMIUM_AVAILABLE="yes"
  fi
fi

# Supabase check (blocking for Gate 9 /qa). Pre-writes qa.md as blocked
# when degraded so the roster check catches it even if the orchestrator
# skips dispatch.
SUPABASE_STATUS=$(bash /devshop/kit/scripts/preship/supabase-bootstrap.sh up 2>&1 | tail -1)

# Local environment health check — verify dev server, memory, zombies.
# On failure, attempt recovery once and retry.
ENV_HEALTH_RC=0
bash /devshop/kit/scripts/preship/local-env-health.sh check || ENV_HEALTH_RC=$?
if [ "$ENV_HEALTH_RC" != "0" ]; then
  echo "  Attempting auto-recovery..."
  bash /devshop/kit/scripts/preship/local-env-health.sh recover || true
  # Retry check after recovery.
  ENV_HEALTH_RC=0
  bash /devshop/kit/scripts/preship/local-env-health.sh check || ENV_HEALTH_RC=$?
  if [ "$ENV_HEALTH_RC" != "0" ]; then
    PREFLIGHT_RESULT="blocked"
    BLOCK_REASON="Local environment unhealthy after recovery attempt — run local-env-health.sh check for diagnostics"
  fi
fi

# When Supabase is not fully healthy, pre-write a blocked gate sink for
# Gate 9 so the § 3.3.1 roster check catches it. If the gate dispatch
# later runs Gate 9 successfully, the sub-agent overwrites this file.
SUPABASE_HEALTHY=""
if echo "$SUPABASE_STATUS" | grep -qE "^(ok:|reused:)"; then
  SUPABASE_HEALTHY="yes"
else
  cat > "$FEATURE_DIR/gates/qa.md" <<QEOF
## Gate 9: /qa

- Result: blocked (Supabase not available — $SUPABASE_STATUS)

Gate 9 requires a healthy local Supabase with seed fixtures.
Pre-written by preflight; will be overwritten if Gate 9 runs successfully.

## Dismissals

None
QEOF
fi

# Determine overall preflight result.
PREFLIGHT_RESULT="pass"
BLOCK_REASON=""
if [ -n "$TOUCHES_UI" ] && [ -z "$CHROMIUM_AVAILABLE" ]; then
  PREFLIGHT_RESULT="blocked"
  BLOCK_REASON="Chromium not available (UI PR requires browser for Gates 3, 8, 9, 10)"
elif echo "$SUPABASE_STATUS" | grep -q "^blocked:"; then
  PREFLIGHT_RESULT="blocked"
  BLOCK_REASON="$SUPABASE_STATUS"
fi

cat > "$FEATURE_DIR/gates/preflight.md" <<EOF
## Preflight

- TOUCHES_UI=$TOUCHES_UI
- TOUCHES_MIGRATIONS=$TOUCHES_MIGRATIONS
- TOUCHES_FUNCTIONS=$TOUCHES_FUNCTIONS
- TOUCHES_KIT=$TOUCHES_KIT
- TOUCHES_CODE=$TOUCHES_CODE
- TOUCHES_USER_CODE=$TOUCHES_USER_CODE
- HAS_TURBO=$HAS_TURBO
- Chromium: ${CHROMIUM_AVAILABLE:-not available}
- Supabase: $SUPABASE_STATUS
- Supabase healthy: ${SUPABASE_HEALTHY:-no}
- Result: $PREFLIGHT_RESULT ${BLOCK_REASON:+(reason: $BLOCK_REASON)}
EOF

if [ "$PREFLIGHT_RESULT" = "blocked" ]; then
  echo "✖ Phase 3 preflight blocked: $BLOCK_REASON"
  echo "  Phase 3 will NOT proceed. Fix the tooling gap and re-invoke"
  echo "  /ak-build (Step 0's resume check re-enters Phase 3)."
  # Route to the Phase 3 → 4 Rung 2 halt (AskUserQuestion with
  # resolve / override / abort options).
  exit 1
fi
```

When Supabase is unavailable but the preflight as a whole passes (e.g.,
docs-only diff with `pass-with-note:` from `emit_degraded_outcome`), a
pre-written `blocked` sink for `qa.md` ensures the roster check at § 3.3.1
still catches the unavailability. The Phase 3 → 4 handoff then sees
`blocked > 0` and halts properly rather than silently shipping without QA.
If the gate dispatch later runs Gate 9 successfully (e.g., after the
operator fixes the Supabase issue and re-invokes), the sub-agent overwrites
the pre-written sink with the real outcome.

On `pass`, the scope variables are available in the preflight sink for
§ 3.3.1's roster derivation (read them back via `grep`). On `blocked`,
the halt fires before any gate dispatch — per the existing prose at
lines 710-714, now enforced as a file-based gate per § Phase exit
artifact registry.

### 3.1: Stabilize-HEAD pass (sequential)

```
for each gate in stabilize-head-order:
  Agent {
    description: "Gate <#>: <name>",
    subagent_type: "general-purpose",
    prompt: """
      You are running ONE gate of /ak-pre-ship: <gate-name>.

      Follow /devshop:pre-ship § <Gate section> for this gate's specific
      contract (scope predicate, evidence requirements, outcome semantics).
      Read $FEATURE_DIR/spec.md + $FEATURE_DIR/tasks.md for feature context.

      Iterative-fix gates: find AND fix AND commit atomically per fix.
      Halt-on-find gates: surface findings, do NOT auto-fix.
      Deterministic gates: run the check; report pass / findings / blocked
      per the check's exit status.

      Write your section to $FEATURE_DIR/gates/<canonical-gate-name>.md
      as your FINAL action before returning. The heading MUST use the
      shape `## Gate <#>: <name>` (NOT `## Gate <name>` — the numbered
      form is the parse contract Phase 3 → Phase 4's forbidden-n/a awk
      depends on; canonical numbers from /ak-pre-ship § Gates, e.g. `8b`
      for design-conformance, `10b` for preflight-final). Include the
      mandatory `## Dismissals` sub-section per /ak-pre-ship § Dismissal
      Log — body is either `None` (zero findings dismissed) or a
      bulleted list with per-bullet `rationale:` fields.

      Do NOT pre-classify the gate as `n/a`. If the gate's scope doesn't
      apply, emit `blocked (n/a per scope: <reason>)` per the LLM-mediated-
      gates contract (gates 6/7/8/9) or `n/a (<reason>)` for the non-LLM-
      mediated gates that legitimately support it.

      Return one line: `pass` | `findings (N) fixed` | `findings (N) pending`
                       | `blocked: <reason>`.
    """
  }

  Read the gate's sink and route:
    - findings (N) pending + halt-on-find gate: classify findings by severity.
      Mechanical/obvious → dispatch a focused fix sub-agent on this gate's
      shard. High → halt and surface to operator (Rung 1). Medium/low →
      note for Phase 6, advance.
    - blocked → halt (Rung 2 below).
    - pass | findings (N) fixed → advance.

  If the gate was code-changing (iterative-fix OR halt-on-find-with-fix
  dispatched): run `pnpm turbo run test:unit` at the orchestrator
  boundary. On failure, invoke /ak-pre-ship § Stuck protocol; do not
  proceed to the next gate until the unit suite is green.
```

### 3.1b: Hero-screenshot capture (post-pass orchestrator step)

After the Stabilize-HEAD pass returns clean, capture hero screenshots per
`pre-ship/SKILL.md § Capture hero screenshots`. This is NOT a gate — no
per-file sink under `gates/`, no Agent dispatch. The orchestrator runs the
capture inline (via the browse skill), commits the resulting PNGs under
`specs/<feature>/hero/`, and proceeds to § 3.2.

**Artifact contract** (enforced by § 3.3.1 roster completeness check —
see § Phase exit artifact registry row `3-hero`): one of two outcomes
MUST be produced. No third option (silently doing nothing) is valid.

```bash
mkdir -p "$FEATURE_DIR/hero"

# Read scope from preflight sink (§ 3.0 wrote it).
TOUCHES_UI=$(grep 'TOUCHES_UI=' "$FEATURE_DIR/gates/preflight.md" | sed 's/.*=//')

if [ -n "$TOUCHES_UI" ]; then
  # UI PR → capture heroes via browse skill. The browse skill writes
  # PNGs under $FEATURE_DIR/hero/. After capture, verify at least one
  # file was produced.
  # <capture logic per pre-ship/SKILL.md § Capture hero screenshots>

  if [ -z "$(ls "$FEATURE_DIR/hero/"*.png 2>/dev/null)" ]; then
    echo "✖ 3.1b: hero capture ran for UI PR but produced no PNGs."
    echo "  Browse skill may have failed silently. Check Chromium"
    echo "  availability (§ 3.0 preflight) and retry."
    exit 1
  fi
  git add "$FEATURE_DIR/hero/"
  git commit -m "chore($FEATURE): hero screenshots (Phase 3.1b)"
else
  # Non-UI PR → write skip marker with reason.
  cat > "$FEATURE_DIR/hero/SKIP.md" <<EOF
# Hero capture skipped

- Reason: non-UI PR (TOUCHES_UI empty — diff does not touch apps/, packages/ui/, or components/)
- Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- SHA: $(git rev-parse HEAD)
EOF
  git add "$FEATURE_DIR/hero/SKIP.md"
  git commit -m "chore($FEATURE): skip hero capture (non-UI)"
fi
```

The roster completeness check at § 3.3.1 verifies that
`$FEATURE_DIR/hero/` contains either `*.png` files or `SKIP.md`. If
neither exists, the check halts — preventing the silent-skip failure
mode where hero capture was never attempted.

### 3.1c: Focused-fix sub-agent (for mechanical/obvious findings)

When a halt-on-find gate returns `findings (N) pending` AND every finding
matches the "mechanical/obvious" criteria above, the orchestrator dispatches
one focused fix sub-agent per gate (NOT per finding — batch by gate so the
agent has the gate-shard findings context):

```
Agent {
  description: "Mechanical fix for Gate <#>: <name>",
  subagent_type: "general-purpose",
  prompt: """
    The /ak-pre-ship gate <gate-name> surfaced N mechanical/obvious findings
    in $FEATURE_DIR/gates/<canonical-gate-name>.md (read it now).

    For each finding:
    1. Apply the fix exactly as the finding's "Fix:" line specifies.
    2. Commit atomically with subject: `fix(<scope>): <one-line>` where
       <scope> derives from the touched file.
    3. Run `pnpm turbo run test:unit` after each commit; abort + return
       `unresolved (test:unit failed on commit <SHA>)` if it fails.

    Do NOT broaden scope beyond what each finding specifies. If a finding
    looks larger than its "Fix:" line suggests, return
    `escalate (finding <N>: <reason>)` for that finding without fixing.

    After applying every fix, append a `## Focused fix log` sub-section
    to $FEATURE_DIR/gates/<canonical-gate-name>.md listing each finding +
    its commit SHA + the local test:unit result. This survives the agent
    boundary so re-running the gate sees what was already fixed.

    Return one line: `pass (N findings fixed)` | `partial (N fixed, M
    escalated)` | `unresolved (<reason>)`.
  """
}
```

Orchestrator behavior on return:
- `pass` → re-run the affected gate sub-agent to confirm `pass`. If the
  re-run also passes, advance.
- `partial` → halt and surface the escalated subset to the operator (Rung 1).
- `unresolved` → halt and surface verbatim (Rung 1).

### 3.2: Analysis pass (parallel, read-only)

After the Stabilize-HEAD pass returns clean, dispatch every analysis gate in a
single tool-use turn — N parallel `Agent` calls, one per gate. Each writes to
its own sink under `$FEATURE_DIR/gates/<canonical-gate-name>.md`.

```
# Single tool-use turn — all Agent calls fire in parallel.
Agent { description: "Gate 5: docs-and-tests-review (Audit 1)", ... }
Agent { description: "Gate 6: /review", ... }
Agent { description: "Gate 7: /cso", ... }
Agent { description: "Gate 8b: design-conformance", ... }
Agent { description: "Gate 10: /benchmark", ... }
Agent { description: "Gate 10b: preflight-final", ... }
Agent { description: "Gate 11: convention", ... }
```

Each agent prompt mirrors the Stabilize-HEAD-pass template (run ONE gate per
its `/ak-pre-ship § Gate <name>` section + write to per-file sink + return one
line). Because the pass is read-only against the stabilized HEAD, race-free
parallel writes are guaranteed by the per-file-sink scheme: each agent's write
target is unique.

After all parallel agents return, the orchestrator routes per-gate findings
identically to the Stabilize-HEAD pass (halt-on-find severity classification +
focused fix dispatch for mechanical mediums).

### 3.3: Concatenate sinks → review.md

After both passes return, the orchestrator concatenates every
`$FEATURE_DIR/gates/<canonical-gate-name>.md` file written this run into
`$FEATURE_DIR/review.md` in **canonical-gate order from `pre-ship/SKILL.md §
Gates`** — i.e. the order of rows in the gates table, which is the same as
the Stabilize-HEAD pass's gate order followed by the Analysis pass's gate
order (the table is already laid out for this concatenation).

Concrete order (omitting gates whose sink doesn't exist — UI gates on non-UI
PRs, etc.):

```
1 docs-check
2 metrics-check
2b rls-coverage
2c slow-job-lifecycle
2d fast-job-local
2e migration-rollback-roundtrip
2f changed-tests-local
3 responsive-theme         # UI PRs only
4 simplify
5 docs-and-tests-review
6 review
7 cso
8 design-review            # UI PRs only
8b design-conformance
9 qa
10 benchmark               # UI PRs only
10b preflight-final
11 convention
```

The concatenation is **idempotent** — a re-run of Phase 3 reads each shard
fresh and rewrites `review.md` from scratch, overwriting the prior
`## Gate <#>: <name>` sections rather than duplicating them.

Aggregate the per-gate `## Dismissals` blocks into the single
`## Router Summary` block at the top of `review.md` per
`/ak-pre-ship § Router Summary aggregation`. Stamp the file's first line
with `<!-- audited-at: $(git rev-parse HEAD) -->` so Phase 5.8's range-
computation has its parse contract.

Return to the orchestrator: `passed`, `findings_pending`, `n_a`, `blocked`
counts (sum across all gate sinks). If `blocked > 0`, include the preflight
fix recipe verbatim in the return.

`/ak-pre-ship` does NOT ship or create a PR. The per-gate sub-agents handle
fixes for iterative-fix gates within their own context; the orchestrator
handles routing for halt-on-find findings.

### 3.3.1: Gate roster completeness check

Before computing the aggregate counts for the Phase 3 → 4 handoff, verify
that every expected gate produced a sink file. A missing sink means the
gate was never dispatched — the orchestrator silently skipped it, which is
the exact failure mode the per-gate decomposition exists to prevent.

See § Phase exit artifact registry rows `3-gates` and `3-hero`.

**Steps 1-3 — Roster completeness check via `roster-check.sh`.**

The scope-variable parsing, expected-roster derivation, gate-sink existence
check, and hero capture validation are all handled by the standalone script.
It reads the preflight sink (§ 3.0 wrote the scope vars), diffs expected vs
produced gate sinks, and validates hero capture (PNGs or SKIP.md with a
known-valid `Reason:` line).

```bash
if ! bash /devshop/kit/scripts/preship/roster-check.sh \
     "$FEATURE_DIR/gates/preflight.md" \
     "$FEATURE_DIR/gates" \
     "$FEATURE_DIR/hero"; then
  echo "✖ Phase 3 gate roster incomplete — see output above."
  echo "  Re-invoke /ak-build to re-enter Phase 3; the resume check picks"
  echo "  up at Phase 3 and re-dispatches all gates."
  exit 1
fi
```

### Phase 3 → Phase 4 handoff: refuse to advance on blocked, findings, or LLM-mediated n/a

After the agent returns, parse the counts AND grep `review.md` for the
LLM-mediated-gate `n/a` violation. The only acceptable state to advance to
`/ship` is: `findings_pending == 0` AND `blocked == 0` AND no LLM-mediated
gate marked `n/a`.

**Rung 1 — `findings_pending > 0`**: pause and escalate to the user (findings
need fixes).

**Rung 2 — `blocked > 0`**: **mechanical halt via `AskUserQuestion`. Do
NOT advance to Phase 4.** The PR is not shippable until either the tooling
gap is closed or the operator provides an explicit, adversarially-reviewed
override. The halt is orchestrator state, not advisory prose — the
orchestrator MUST fire `AskUserQuestion` and branch on its return.

1. Emit the per-gate halt summary to the user — for each `blocked` gate,
   render its canonical name, the blocking reason verbatim from the gate's
   `## Dismissals` section, and the preflight fix recipe the gate runner
   returned in its `blocked` payload.

2. Post a PR comment (if a PR exists for this branch already — unusual in
   Phase 3, but possible on resume) describing which gates are blocked and why.

3. **Required: fire `AskUserQuestion`** with the halt reason inline. Three
   options, in this order:

   ```
   header: "Phase 3 halt"
   question: "<N> gate(s) reported `blocked` — pipeline is paused. How do you want to proceed?"
   options:
     1. Resolve the tooling gap and re-invoke /ak-build (Recommended)
        — Step 0's resume check re-runs Phase 3 cleanly. Pick this when the
          gate runner's fix recipe is doable from the operator's environment.
     2. Override — name the gate, reason, and follow-up tracker entry
        — Captured in specs/<feature>/review.md § Phase 3 → 4 advance log,
          adversarially reviewed via the `blockedGateOverride` check-type
          (Sonnet) — the committed review.md is the durable audit record.
     3. Abort the /ak-build run
   ```

   The orchestrator MUST NOT autonomously advance to Phase 4 — even when
   the same gate-blocked shape was previously accepted on a prior PR. Each
   PR re-acks. The mechanical halt exists precisely so "matches the
   decide-state precedent" is not a path the orchestrator can invent.

4. **Option 1 (resolve)**: emit the gate runner's fix recipe verbatim and
   exit cleanly. The operator re-invokes /ak-build after the tooling gap is
   closed; Step 0's resume check picks up at Phase 3 and reruns the gauntlet.

5. **Option 2 (override)**: collect three fields from the operator via a
   follow-up `AskUserQuestion` round (re-prompt if any field is empty):

   - **Gate** — the canonical gate ID being waived (e.g. `Gate 8:
     /design-review`). When `blocked > 1`, one override entry per gate.
   - **Reason** — why shipping past this `blocked` outcome is acceptable
     for THIS PR specifically. Not as a precedent, not as a category claim.
   - **Follow-up tracker** — path + section to an existing entry in
     `TODOS.md` / `PRODUCT-ROADMAP.md` / `kit/TODOS.md` / `kit/ROADMAP.md`
     (or a GitHub issue URL) that names the work to close the tooling gap.

   Append the override to `$FEATURE_DIR/review.md` under a new section,
   then invoke the adversarial reviewer:

   ```bash
   STAMP_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   cat >> "$FEATURE_DIR/review.md" <<EOF

   ## Phase 3 → 4 advance log

   ### $STAMP_TS — $GATE

   **Gate:** $GATE
   **Reason:** $REASON
   **Follow-up tracker:** $TRACKER
   <!-- adversarial-review-stamp: blockedGateOverride pending @ $STAMP_TS -->
   EOF

   if bash kit/scripts/adversarial-review.sh blockedGateOverride \
        "$REASON" "$GATE" "$TRACKER" "$FEATURE_DIR/review.md"; then
     sed -i "s|blockedGateOverride pending @ $STAMP_TS|blockedGateOverride PASS @ $STAMP_TS|" \
       "$FEATURE_DIR/review.md"
     git add "$FEATURE_DIR/review.md"
     git commit -m "chore($FEATURE): Phase 3 → 4 override on $GATE"
     # Advance to Phase 4 with the override captured.
   else
     # Reviewer rejected. DO NOT advance. The `pending` stamp stays in
     # review.md as the audit trail; the operator must either fix the
     # reason (re-invoke /ak-build to re-prompt — Step 0's resume check
     # re-runs the halt) or re-pick option 1 or 3.
     echo "✖ Override rejected by adversarial review:"
     echo "$REVIEWER_OUTPUT"
     exit 1
   fi
   ```

   The `<!-- adversarial-review-stamp -->` is the audit signal: a `pending`
   stamp on a merged PR is a contract violation (the orchestrator MUST NOT
   advance with a `pending` stamp). The advance log section in the
   committed `review.md` records the gate + reason + tracker + stamp
   disposition verbatim so reviewers can audit it.

6. **Option 3 (abort)**: exit /ak-build cleanly. Phase 4 is not entered. No
   commits made; no PR push. Operator can re-invoke later.

The override flow exists for genuine ship-now cases where the tooling gap
can't be closed in the current session (CI-only browser available, sandbox
env without Docker, etc.) AND the follow-up work is genuinely tracked. The
`blockedGateOverride` adversarial reviewer rejects: generic reasons
("seems fine", "we've done this before"); precedent-based reasons
("matches PR #27's override"); reasons without a verifiable tracker entry;
reasons that contradict the spec's § In scope or § Core user story.

Worked incidents — three repeats in the same project's lifetime is why
this halt is now mechanical rather than prose:

- **Home-os PR #15** (2026-05-14) — shipped past `blocked: 1` because the
  halt happened but the override was silent; reviewers received
  placeholder hero shots from the sign-in flow instead of the actual
  feature.
- **Home-os PR #27** (decide-state, 2026-05-17) — Gates 3/8/9/10 emitted
  `blocked (n/a per scope: sandbox)`; orchestrator self-advanced.
- **Home-os PR #28** (planned-state, 2026-05-18) — `blocked: 4` (same
  sandbox-blocked LLM-mediated gates); orchestrator self-advanced with
  prose like "advance to Phase 4 — matches the decide-state precedent."

Do NOT treat `blocked` as `n/a`. A cheerful advance past blocked gates is
the exact failure mode this workflow exists to prevent.

**Rung 3 — LLM-mediated gate marked `n/a`** (codified from lalista PR #65,
2026-05-12): even when the agent returns `findings_pending == 0` and
`blocked == 0`, grep `review.md` for the four LLM-mediated gates emitting
the forbidden `n/a` outcome:

```bash
if ! bash /devshop/kit/scripts/preship/check-llm-mediated-na.sh "$FEATURE_DIR/review.md"; then
  echo "✖ Phase 3 → 4 halt: see check-llm-mediated-na.sh output above."
  exit 1
fi
```

The script is mawk-portable (no `\b` — uses `[^a-z-]` anchors) and anchored
on the LLM-mediated gate names (`review|cso|design-review|qa`) so legitimate
`n/a` outcomes from non-LLM-mediated gates (Gate 3 responsive, Gate 10
benchmark, Gate 1 docs-check) don't false-positive. Tested with mawk
explicitly in `kit/tests/util-check-llm-mediated-na.bats`.

Once the user has resolved the violation, re-run `/ak-build` — Step 0's resume
check will pick up at Phase 3 and rerun pre-ship from the start.

## Phase 4: Ship

### 4.0: Compose + commit BUILD-LOG entry + PLAN row removal

**Why this runs before `/ship`.** The historical shape ran BUILD-LOG +
PLAN bookkeeping at Phase 5.6 — after the first CI green — and triggered
a fresh ~5-minute CI cycle for a docs-only push (Phase 5.7 watched it).
That cycle is fixed-cost per PR regardless of diff size: a 15-LOC PR
paid the same 5 min as a 1500-LOC PR. Folding the bookkeeping commit
into the original `/ship` push eliminates the extra cycle entirely;
`/ship`'s push at 4.2 now carries the bookkeeping atomically.

**Risk acknowledged.** A BUILD-LOG entry composed here lands on the
feature branch BEFORE any CI run. If the operator abandons the PR
post-`/ak-build` (CI never goes green; no merge), the entry sits on a
dead branch and is deleted with it. Net effect on shipped history is
unchanged from the prior order (5.6's entries also lived only on the
feature branch until merge; abandoned branches always carried their
unmerged BUILD-LOG entries down with them).

**Inputs**:

- `$FEATURE` — feature name (from Phase 0 / Phase 1)
- `$FEATURE_BRANCH` — branch name (from Phase 0's branch creation)
- `$FEATURE_DIR` — `specs/$FEATURE/`
- `PLAN.md` at repo root (Phase 1's `/ak-spec` flipped the Planned row into `## Active`)
- `BUILD-LOG.md` at repo root (append-only ship log)

**Steps**:

1. If `BUILD-LOG.md` doesn't exist, copy from `/devshop/template/BUILD-LOG.md`. If `PLAN.md` doesn't exist, copy from `/devshop/template/PLAN.md`.

2. **Remove the Active row from `PLAN.md`**: find the row in `## Active` whose Branch column matches `$FEATURE_BRANCH`, delete it. If `## Active` is now empty (no remaining rows), restore the placeholder `_No work in progress._` under the `## Active` heading.

3. **Append the ship entry to `BUILD-LOG.md`**, most-recent-first (top of the entry list, after the intro paragraph and the `_No builds yet._` placeholder if present — remove the placeholder on first real entry):

   ```markdown
   ### <FEATURE> (YYYY-MM-DD)

   - **Branch**: `<FEATURE_BRANCH>`
   - **Spec**: `specs/<FEATURE>/spec.md`
   - **Headline**: <verbatim copy of $FEATURE_DIR/spec.md § Product update § Headline>
   - **Summary**: <verbatim copy of $FEATURE_DIR/spec.md § Product update § Detail>
   - **Commits**: <N> (<brief list if ≤ 5, else "N atomic commits per /ak-implement">)
   - **Quality gates**: <one-line summary — "all passed" / "N findings fixed" / etc>
   ```

   **Headline + Summary routing**: both fields draw from spec.md §
   Product update verbatim — `Headline:` carries the Headline blurb
   (user-facing, marketing-grade), `Summary:` carries the Detail blurb
   (team-facing, future-me grain). Two reasons for two fields rather
   than one rich Summary:
   1. Future CHANGELOG / release-notes aggregation reads `Headline:` —
      a clean single-line string per shipped PR.
   2. BUILD-LOG scanners are typically future-me asking "what shipped?"
      — Detail (the team-facing blurb) is the right grain for that
      audience. Headline is the changelog primitive; Summary is the
      operational record.

   When the spec used the collapsed shape (`### Headline + Detail
   (combined)`), copy the same body verbatim into both fields. Schema /
   routes / UI / tests / CI minutiae stay in additional sub-bullets if
   needed; do not mix them into `Summary:` (that's the post-fix shape —
   pre-fix BUILD-LOG entries shipped as 400-word eng paragraphs that
   buried the product story).

   **No PR row in new entries.** Phase 4.0 runs before `/ship` creates
   the PR, so the number isn't known yet. The squash-merge subject on
   `main` carries the PR number automatically (`feat(<topic>): … (#42)`
   from GitHub's default squash format), so `git log --grep=<FEATURE>`
   on main resolves the PR pointer without the explicit row. Older
   entries retain their `**PR**:` row — no migration; they're history.

   **Commits count caveat.** `<N>` is the count BEFORE `/ship`'s
   potential VERSION/CHANGELOG bump (`git log origin/$BASE..HEAD |
   wc -l`). `/ship` typically adds 1 commit. The Audit 2 pass at
   Phase 5.8 catches the discrepancy as a low-severity finding and the
   polish loop fixes it; this is the same path PR #18 followed when it
   was the post-CI-green design.

4. **Retire any tracker entry the PR closes.** If the PR shipped a fix that resolves a tracker entry living in any of:

   - `TODOS.md` (project)
   - `PRODUCT-ROADMAP.md` (project, e.g. a v0 chapter)
   - `/devshop/kit/TODOS.md`
   - `/devshop/kit/ROADMAP.md`

   …the same commit that runs step 4 also (a) **deletes** the entry — no "shipped 2026-04-26" footnote, no strikethrough, just delete; git log + the PR description are the audit trail; (b) **rewrites any docs that described the prior constraint** from conditional preflight prose ("Without this, X fails", "verify X before assuming blocked") to imperative present tense ("Do X." / "X works."), since "Without this" framing reads identically whether the prereq is met or not and trips future sessions into false beliefs; and (c) **unwinds every cross-reference to the deleted entry** in the same commit — orphan citations elsewhere respawn the false belief.

   How to enumerate the cross-refs cheaply: `grep -rE "<dropped-entry-name>|<dropped-entry-section-id>" /workspace/ /devshop/kit/docs/ /devshop/CLAUDE.md` — every hit needs to be either rewritten or removed. Don't trust that "the entry is just in v0" — a sibling entry (or a SKILL.md, or another guide doc) may cite it as a prereq.

   Worked example: this convention was codified after a session read `/ak-build` SKILL.md Phase 5.4's "Without this, `gh run download` fails" line as "still blocked" and skipped artifact-pull on a CI failure that had artifacts waiting. The firewall fix had shipped weeks earlier; the v0 entry tracking it never moved out of `kit/ROADMAP.md` v0; the SKILL.md prereq prose never moved to imperative present. See devshop commits `7e03f6a` (cleanup of the specific incident) + `f3ec42b` (the convention itself). Full statement: `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`.

5. Commit on the feature branch:

   ```bash
   git add PLAN.md BUILD-LOG.md  # plus any deleted/rewritten files from step 4
   git commit -m "chore(build-log): record <FEATURE>"
   ```

   No `git push` — Phase 4.2's `/ship` invocation pushes this commit
   together with `/ship`'s own VERSION/CHANGELOG bump (if any) in a
   single cycle. That's the elision.

   If step 4 retired a tracker entry, prefer a separate commit on the feature branch with message `chore(roadmap): close <entry-name> (shipped via PR #<PR>)` — keeps the bookkeeping atomic. The PR# in this message can also be `(shipped from this feature branch — PR pending)` since 4.0 predates PR creation.

**Idempotence**: if Phase 4.0 has already run for this feature (no Active row for `$FEATURE_BRANCH` in `PLAN.md` AND a `BUILD-LOG.md` entry referencing `$FEATURE` exists, AND no PR-closed tracker entry remains in any roadmap), skip — don't duplicate. Phase 5.6 (verification-only, project mode) catches the un-run case as a fallback.

### Mode fork after Phase 4.0

- **Devshop mode** → skip to Phase 4.5 (`/ak-merge-devshop`). Read
  `devshop-mode.md § Phase 4.5` for the full procedure. After Phase 4.5
  completes, print the terminal handoff (`devshop-mode.md § Terminal
  handoff`) and exit. **Do NOT continue to Phase 4.1 or any later phase.**
- **Project mode** → continue to Phase 4.1 below.

### 4.1: Pre-compose PR title + Product update + Engineering details body

Before invoking `/ship`, compose the PR title and the two leading body
sections (`## Product update` + `## Engineering details`) in this skill —
`/ak-build` owns the convention and has `kit/docs/guide/conventions.md §
Commit + PR Text Style` reliably available; `/ship` is upstream-owned
(gstack) and would re-compose to its own taste otherwise. The split:

- **PR title** — one line, ≤ 72 chars, verb-led where natural,
  describes the **observable change** (no internal jargon like "polish",
  "soak findings", "Phase N"). Noun-lists are fine for multi-unit
  features (`feat: invite link + member mgmt + audit feed`).
- **`## Product update` section** — copied verbatim from
  `$FEATURE_DIR/spec.md § Product update`. Both `### Headline
  (user-facing)` and `### Detail (team-facing)` sub-sections, Headline
  first. Placed as the **first content after the H1 title** so a
  reviewer (or anyone reading the PR cold) sees the product story
  before the eng narrative. When the spec uses the collapsed shape
  (`### Headline + Detail (combined)`), copy that heading verbatim too
  — the PR body inherits the collapse.
- **`## Engineering details` section** — the historical `## Summary`
  contents, renamed. One-sentence TL;DR followed by 3-7 bullets.
  Bullets first; prose only when a non-obvious decision needs framing
  (1-2 sentences max). Enumerate from `git log <base>..HEAD --oneline`,
  exclude the VERSION/CHANGELOG bookkeeping commit, then every remaining
  substantive commit must appear in at least one bullet. Group into
  themed sub-sections (`**Performance**`, `**Infrastructure**`, etc.)
  when there are 2+ themes. The Product update section above already
  carries the product story — Engineering details is for schema /
  routes / components / tests / CI / migration details that reviewers
  need but end-users don't read.

Compose all artifacts, then assemble the **FULL** PR body as a single
file (see § Phase exit artifact registry row `4.1`):

- `/tmp/ship-title.txt` (one line)
- `/tmp/ship-body.md` (the complete PR body — all sections below)

The body template, assembled in this order:

```markdown
## Product update

<verbatim from $FEATURE_DIR/spec.md § Product update — both sub-sections>

## Engineering details

<composed per the rules above>

## Test plan

- [ ] CI green
- [ ] Vercel / Netlify / Fly preview deployed

### Manual review
- [ ] Spec / intent match — does the PR do what was specified?
- [ ] Visual / design audit — hierarchy, spacing, dark-mode parity
- [ ] Live QA walkthrough — does the user flow work end-to-end?
- [ ] Post-deploy metrics — p95 latency, error rate, event volume
<Add out-of-band deploy items per § Out-of-band deploy items if diff
 touches supabase/functions/, supabase/migrations/, terraform/, k8s/.>

### Hero shots
<If $FEATURE_DIR/hero/*.png exists: one image embed per file using
 https://github.com/<owner>/<repo>/raw/<branch>/<rel-path> URL form.
 If $FEATURE_DIR/hero/SKIP.md exists: "Hero shots skipped — non-UI PR."
 If neither: "⚠ No hero shots — capture was not attempted.">
```

The PR body is intentionally clean of devshop process artifacts (gate
tables, attestation language, `specs/` cross-references). Gate results
persist in `specs/<feature>/review.md` (committed to the repo); the PR
body is for the reviewer, not the audit trail.

**Mechanical check** — verify the body before proceeding to § 4.2 (see
§ Phase exit artifact registry row `4.1`):

```bash
BODY_MISSING=""
for section in "## Product update" "## Engineering details" "## Test plan" \
               "### Manual review" "### Hero shots"; do
  if ! grep -qF "$section" /tmp/ship-body.md; then
    BODY_MISSING+="  $section\n"
  fi
done
if [ -n "$BODY_MISSING" ]; then
  echo "✖ Phase 4.1: /tmp/ship-body.md missing required sections:"
  echo -e "$BODY_MISSING"
  exit 1
fi
```

The next step (§4.2) hands `/ship` the title via `/tmp/ship-title.txt`
and the **entire body** via `--body-file /tmp/ship-body.md`. `/ship`
does NOT compose its own body sections — it receives the complete
artifact and uses it verbatim. Phase 4.3's verify step confirms the PR
body on GitHub matches the file.

**Why Product update goes first, not Summary**: a reviewer landing on a
PR cold reads top-down; the product story is what they're orienting on
("what does this change for the user?") before they scan the eng
details ("how was it built?"). Inverting that order makes reviewers
re-derive the product story from eng nouns. Codified from the
home-os PR #27 case where the eng-shaped Summary worked for reviewers
but the product story had to be re-derived post-deploy when the
operator asked "what went live, product-wise?"

### 4.2: Invoke `/ship` with the pre-composed directives

Launch **Agent** with prompt:
> Run /ship to push the branch and create a PR.
> /ship will run tests, code review, bump VERSION, push, create PR,
> and auto-invoke /document-release.
>
> Use the pre-composed title and FULL body from /ak-build — do NOT
> compose your own body sections. The title is at /tmp/ship-title.txt
> (one line). The ENTIRE PR body is at /tmp/ship-body.md — use it
> verbatim via `--body-file /tmp/ship-body.md` when creating the PR.
>
> If /ship's PR creation uses a different body, overwrite immediately:
>
>   gh pr edit "$PR" --title "$(cat /tmp/ship-title.txt)"
>   gh pr edit "$PR" --body-file /tmp/ship-body.md
>
> Return: PR number and URL.

This shape moves ALL composition into the devshop-owned skill; `/ship`
becomes a pure executor (push + bump + PR creation). The full body is
pre-composed at § 4.1 with structured checkboxes, gates summary, hero
shots, and manual-review items — `/ship` has no latitude to produce a
different shape. Codified after a `gstack` sync clobbered local edits
to `gstack/ship/SKILL.md` (2026-05-13), and after close-flow PR #34
(2026-05-26) where delegating body composition to `/ship` produced a
flat Test plan without the structured checkbox categories.

### 4.3: Verify

After `/ship` completes, a PR exists on GitHub. Verify the PR title and
description match what 4.1 composed and what `kit/docs/guide/conventions.md
§ Commit + PR Text Style` requires.

**Required body shape** (top-down, first H1 onward):

1. `# <title>` (H1 — `/ship` writes this from the title file)
2. `## Product update` (H2) + `### Headline (user-facing)` + `### Detail
   (team-facing)` — both verbatim from `/tmp/ship-product-update.md`. Or
   the collapsed `### Headline + Detail (combined)` when the spec
   collapsed them.
3. `## Engineering details` (H2) — verbatim from
   `/tmp/ship-engineering-details.md`.
4. `## Test plan` / `## Evidence` / `## Manual review` / etc. — per
   `/ship`'s template.

If `/ship` produced a body with a `## Summary` heading (the historical
shape), rename it to `## Engineering details` and splice
`## Product update` above it. If the body's `## Product update` or
`## Engineering details` sections don't match the pre-composed
artifacts, rewrite:

```bash
gh pr view "$PR" --json body --jq .body > /tmp/pr-body.md
# Ensure the body leads with `## Product update` (from
# /tmp/ship-product-update.md) immediately after the H1, followed by
# `## Engineering details` (from /tmp/ship-engineering-details.md).
# If a `## Summary` section exists, rename to `## Engineering details`
# and splice `## Product update` above it.
gh pr edit "$PR" --body-file /tmp/pr-body.md
```

Apply the **PR body conventions** (see § "PR body conventions" near the end of this
skill) — in particular:

- **Image embeds**: every `![alt](path)` must use
  `https://github.com/<owner>/<repo>/raw/<branch>/<path>`. Repo-relative paths
  (`specs/auth/hero/signin.png`) do not resolve in PR descriptions, and
  `raw.githubusercontent.com` URLs require an auth token on private repos
  (they silently 404 for viewers). Convert every embed when you see one.
- **Checkbox state at PR creation time**: the pre-push automated gates
  (`pnpm turbo run lint typecheck test:unit build`) are already green by the
  time `/ship` runs them — those checkboxes should be `[x]` in the body
  `/ship` writes. Manual-review items (visual audits, QA walkthrough,
  post-deploy metrics) stay `[ ]` for the reviewer. CI-job checkboxes
  (fast job / slow job / Vercel preview) start `[ ]` — they get marked as
  the signals land during Phase 5.

If `/ship` produced a body with violations of the above (wrong image URLs,
missing pre-push checkmarks), fix with:

```bash
gh pr view "$PR" --json body --jq .body > /tmp/pr-body.md
# edit /tmp/pr-body.md
gh pr edit "$PR" --body-file /tmp/pr-body.md
```

## Phase 5: CI watch + fix loop

Wait for CI to complete, fix failures if possible.

### 5.1: Get PR number
```bash
PR=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')
```

### 5.2: Watch CI

The canonical `gh pr checks "$PR" --watch --fail-fast` requires Check Runs
API access, which is **not available to fine-grained PATs** — the Checks
permission was removed after initial release and has not been reintroduced
(see https://github.com/orgs/community/discussions/129512). Fine-grained
PATs with Actions: Read can still watch GitHub Actions runs via the Actions
API, which is what this devshop uses.

```bash
BRANCH=$(git branch --show-current)
RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --exit-status

# Cross-check: gh run watch --exit-status reports exit 0 even when the run's
# actual conclusion is `failure`. Verify conclusion before trusting the exit
# code. Codified from lalista PR #65 (2026-05-12) where two consecutive watch
# calls reported exit 0 but the runs had conclusion=failure; the regression
# was caught only because the operator looked at the GitHub Actions UI.
CONCLUSION=$(gh run view "$RUN_ID" --json conclusion --jq .conclusion)
if [ "$CONCLUSION" != "success" ]; then
  echo "✖ Run $RUN_ID conclusion=$CONCLUSION (watch reported success but the API disagrees)"
  # Route to Phase 5.4 fix loop with this run's failed step.
  exit 1
fi
```

This blocks until the most-recent workflow run on the branch completes.
Non-zero exit on failure. If it times out, re-run. Cap total wait at 30
minutes. **The `gh run view --json conclusion` cross-check is load-bearing**
— without it, a run that ended in `failure` can silently pass this gate
because `gh run watch --exit-status`'s exit code disagrees with the actual
conclusion in some scenarios (root cause unconfirmed; reproducibly seen
2026-05-12 across two consecutive runs on different SHAs).

If a project uses third-party CIs that only publish commit statuses (not
Actions workflow runs), `gh pr checks` works if the PAT has
**Commit statuses: Read** granted — those contexts come back, just not
the GitHub Actions check runs. For the typical devshop project that uses
GitHub Actions + Vercel preview, `gh run list` covers it.

When GitHub re-enables the fine-grained Checks permission, swap back to
`gh pr checks "$PR" --watch --fail-fast` — tracked in `kit/TODOS.md`.

### 5.3: On CI green → update PR body checkboxes, then continue to 5.6

**Watch-every-push guarantee (folded in from defunct Phase 5.7).** After
this CI-green attestation, treat every subsequent push on the branch as
its own watch-then-advance unit before Phase 6 marks the `CI green`
checkbox `[x]` in the PR body. Polish-loop fixes, post-`/ak-build` operator
edits, and audit-fix commits all trigger their own CI runs; each must be
re-watched and confirmed `success` at the SHA being audited. The Phase 5.6
elision removed one structural source of post-CI-green pushes (the
BUILD-LOG bookkeeping cycle) but did not remove the general requirement.
Codified from lalista PR 18 (2026-04-25) — audit + ready-for-review
comments posted while a bookkeeping push's CI was still `in_progress`;
that run failed on a WebKit system-libs flake, forcing a public
retraction comment. Phase 6's `Part B` evidence sweep enforces this
check before it attests the PR body's `[x]` claims.

Once the CI run completes successfully, mark the `CI green` and
`preview deployed` checkboxes as `[x]` in `## Test plan`. Check for
Vercel / Netlify / Fly bot comments on the PR — if a preview is deployed,
mark the preview checkbox with the URL.

```bash
gh pr view "$PR" --json body --jq .body > /tmp/pr-body.md
# Mark CI + preview checkboxes per actual status; leave manual-review items [ ].
# See § "PR body conventions" for the checkbox-timing table.
gh pr edit "$PR" --body-file /tmp/pr-body.md
```

Do NOT mark manual-review callouts (visual audits, live QA walkthrough,
post-deploy metrics) — those stay `[ ]` for the reviewer.

### 5.3.5: Body-consistency check (catches post-/ship scope drift)

Phase 5.3 marks checkboxes; it doesn't notice when a commit between /ship
and Phase 6 materially **changed what shipped** in a way that invalidates
the body's Summary, Evidence, or Test plan narrative. Without this check,
the body authored at /ship time silently drifts: a new test file lands,
hero shots get replaced with a different methodology, a CI fix gets
bundled — none of those flag "did you change what shipped?" until Phase 6's
final sweep, which can be many commits later.

Fires once per CI-green tick (alongside 5.3, after the checkbox update).
Compares the post-/ship commit range against four scope-drift signals:

```bash
SHIP_SHA=$(git log --grep="^chore.*ship" --pretty=%H -1 origin/${BASE}...HEAD 2>/dev/null \
  || git log --reverse --pretty=%H "origin/${BASE}..HEAD" | head -1)
DRIFT_RANGE="${SHIP_SHA}..HEAD"
DRIFT_FILES=$(git diff --name-only "$DRIFT_RANGE")

DRIFT_SIGNALS=""

# Signal 1: new test files (the body's "Test plan" probably doesn't mention them)
NEW_TESTS=$(git diff --diff-filter=A --name-only "$DRIFT_RANGE" | \
  grep -E '^(apps/[^/]+/e2e/.+\.spec\.(ts|tsx)|.+\.test\.(ts|tsx)|.+\.integration\.test\.(ts|tsx))$' || true)
[ -n "$NEW_TESTS" ] && DRIFT_SIGNALS+="  new test files added since /ship:\n$(echo "$NEW_TESTS" | sed 's/^/    /')\n"

# Signal 2: hero / qa-walk evidence replaced (different methodology than what the body cites)
EVIDENCE_REPLACED=$(echo "$DRIFT_FILES" | grep -E "^specs/[^/]+/(hero|qa-walk|screenshots)/" || true)
[ -n "$EVIDENCE_REPLACED" ] && DRIFT_SIGNALS+="  visual / qa-walk evidence touched:\n$(echo "$EVIDENCE_REPLACED" | sed 's/^/    /')\n"

# Signal 3: workflow / CI changes bundled (changes the merge / deploy contract)
WORKFLOW_BUNDLED=$(echo "$DRIFT_FILES" | grep -E "^\.github/workflows/" || true)
[ -n "$WORKFLOW_BUNDLED" ] && DRIFT_SIGNALS+="  CI workflow changes bundled:\n$(echo "$WORKFLOW_BUNDLED" | sed 's/^/    /')\n"

# Signal 4: new runtime files (component, page, route, API wrapper) — scope expansion
NEW_RUNTIME=$(git diff --diff-filter=A --name-only "$DRIFT_RANGE" | \
  grep -E '^(apps/[^/]+/(app|components|lib)/.+\.(ts|tsx)|packages/[^/]+/src/.+\.(ts|tsx))$' | \
  grep -vE '\.(test|spec)\.' || true)
[ -n "$NEW_RUNTIME" ] && DRIFT_SIGNALS+="  new runtime files added since /ship:\n$(echo "$NEW_RUNTIME" | sed 's/^/    /')\n"

# Signal 5: product-blurb stale check — does the spec.md § Product update
# (Headline + Detail) still describe what shipped? Two sub-checks:
#   (a) noun-coverage: new runtime / test files added since /ship may
#       have introduced user-visible affordances the blurbs don't name
#       (a polish-loop fix added a disclosure; Headline elides it).
#       Extract distinctive nouns from $NEW_RUNTIME + $NEW_TESTS and
#       check whether either blurb mentions them.
#   (b) audience-shape: does Headline cover the same claim set as Detail
#       at a lower fidelity? Claims present in Detail but absent from
#       Headline (or vice versa) warn — operator decides at Phase 6
#       whether the asymmetry is intentional.
# Both sub-checks read $FEATURE_DIR/spec.md § Product update. Inlined
# here (rather than a separate script) so the convention stays
# self-contained — kit/tests/util-product-update-blurb.bats validates
# this block.
HEADLINE_BODY=$(awk '/^### Headline \(user-facing\)/{flag=1; next} /^###|^## /{flag=0} flag' \
  "$FEATURE_DIR/spec.md" 2>/dev/null)
DETAIL_BODY=$(awk '/^### Detail \(team-facing\)/{flag=1; next} /^###|^## /{flag=0} flag' \
  "$FEATURE_DIR/spec.md" 2>/dev/null)
# Collapsed case: pull from `### Headline + Detail (combined)`.
if [ -z "$HEADLINE_BODY" ] && [ -z "$DETAIL_BODY" ]; then
  COMBINED_BODY=$(awk '/^### Headline \+ Detail \(combined\)/{flag=1; next} /^###|^## /{flag=0} flag' \
    "$FEATURE_DIR/spec.md" 2>/dev/null)
  HEADLINE_BODY="$COMBINED_BODY"
  DETAIL_BODY="$COMBINED_BODY"
fi

PRODUCT_BLURB_FINDINGS=""
if [ -n "$HEADLINE_BODY" ] || [ -n "$DETAIL_BODY" ]; then
  # Distinctive nouns from each blurb (PascalCase + 4+char lowercase, minus stopwords).
  STOPWORDS='with|this|that|than|from|when|will|have|here|each|just|only|some|then|they|been|were|into|over|same|more|like|much|where|after|other|user|users|page|view|flow|able|make|made|need|want|allow|shows|adds|added|fixes|fixed|onto|down|both|along|your|saved|sets|see|set|via|now|out|but|and|the|for|its|any|all|new|can'
  nouns() {
    { echo "$1" | grep -oE '\b[A-Z][a-zA-Z]+\b' || true
      echo "$1" | grep -oE '\b[a-z]{4,}\b' | grep -vwE "$STOPWORDS" || true
    } | tr '[:upper:]' '[:lower:]' | sort -u
  }
  HEADLINE_NOUNS=$(nouns "$HEADLINE_BODY")
  DETAIL_NOUNS=$(nouns "$DETAIL_BODY")
  # (a) Noun-coverage: did any new file's path introduce a noun neither
  # blurb names? Scan $NEW_RUNTIME + $NEW_TESTS file paths for
  # distinctive tokens.
  NEW_FILE_NOUNS=$(echo "${NEW_RUNTIME:-}"$'\n'"${NEW_TESTS:-}" \
    | grep -oE '[A-Za-z][A-Za-z0-9-]+' | tr '[:upper:]' '[:lower:]' | sort -u || true)
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    if ! echo "$HEADLINE_NOUNS"$'\n'"$DETAIL_NOUNS" | grep -qiwF "$tok"; then
      PRODUCT_BLURB_FINDINGS+="  noun-coverage: '$tok' appears in a new file but in neither blurb"$'\n'
    fi
  done <<< "$NEW_FILE_NOUNS"
  # (b) Audience-shape: claims in Detail not in Headline, and vice versa.
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    PRODUCT_BLURB_FINDINGS+="  headline-missing: '$tok' (Detail mentions; Headline does not)"$'\n'
  done < <(comm -23 <(echo "$DETAIL_NOUNS") <(echo "$HEADLINE_NOUNS") | head -5)
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    PRODUCT_BLURB_FINDINGS+="  detail-overclaim: '$tok' (Headline mentions; Detail does not)"$'\n'
  done < <(comm -23 <(echo "$HEADLINE_NOUNS") <(echo "$DETAIL_NOUNS") | head -5)
fi
[ -n "$PRODUCT_BLURB_FINDINGS" ] && DRIFT_SIGNALS+="  product-blurb drift since /ship:\n${PRODUCT_BLURB_FINDINGS}"
```

If `$DRIFT_SIGNALS` is empty → continue. The body's narrative still matches
what's in the diff.

If `$DRIFT_SIGNALS` is non-empty → **read the current PR body** and judge
whether the signals invalidate any specific claim:

- **Product update section** (`## Product update` — first body section
  after H1, both Headline + Detail) is the canonical product story.
  Signal 5 fires when the spec.md blurbs don't mention nouns/verbs the
  diff added since /ship, OR Headline lags Detail in coverage. Both
  signals warrant a body edit: rewrite the Headline / Detail to reflect
  what actually shipped, then re-stamp spec.md so the source-of-truth
  stays in sync (the next surface — BUILD-LOG at 5.6, Phase 7 notify,
  /ak-go-live Step 6 — all copy from spec.md, not from the PR body).
- Engineering details section names the bug + fix at the eng grain. New
  runtime / test files often mean there's a "scope expansion" angle
  Engineering details should mention.
- Evidence section embeds hero shots. If hero shots were replaced with a
  different methodology (synthetic → live, single-viewport → multi-viewport,
  injected DOM → real flow), the Evidence caption must reflect that —
  reviewers reading the new shots through the old caption assume the wrong
  methodology shipped.
- Test plan lists pre-push gates + manual-review items. New test files
  warrant a row attesting they ran green; bundled CI / workflow changes
  warrant a row flagging the scope-creep with a "happy to split" offer
  per `§ PR body conventions § What belongs in "Manual review"`.

When any claim is invalidated, edit `/tmp/pr-body.md` and `gh pr edit`
inline (same flow as 5.3). Do NOT post a comment — comments accumulate;
the body is the authoritative summary at merge time.

When no claim is invalidated (the signals are present but the existing
body already covers them, or they're trivially additive), record the
no-op decision in `review.md § Body-consistency log` so Phase 6's sweep
sees the receipts:

```markdown
- 5.3.5 at `<SHA>`: signals fired (new test file `<path>`); body already
  attests via "<existing claim>"; no edit needed.
```

**Codified from**: lalista PR 53 (2026-05-08). Between /ship at 3ef24da
and Phase 6 the branch landed: a new e2e spec
(`apps/web/e2e/confirmation-toast-width-qa-walk.spec.ts`), hero shot
replacement (synthetic DOM-injection captures swapped for live /list
captures via `b52d22f`), and a bundled CI workflow fix
(`.github/workflows/ci.yml` at 3d1546c). All three would have fired the
signals above. The body went stale across all three; the user caught it
at Phase 6 PR-surface review time and asked "isn't the PR description stale?" —
which is exactly the question this check exists to answer pre-emptively.

**Exit artifact** (§ Phase exit artifact registry row `5.3.5`): as the
final action of 5.3.5, write the outcome to `$FEATURE_DIR/body-consistency.log`
so § 5.10's exit checklist can verify 5.3.5 ran:

```bash
if [ -n "$DRIFT_SIGNALS" ]; then
  echo "drift-signals-found: edited PR body at $(git rev-parse HEAD)" \
    > "$FEATURE_DIR/body-consistency.log"
else
  echo "clean: no drift signals at $(git rev-parse HEAD)" \
    > "$FEATURE_DIR/body-consistency.log"
fi
```

### 5.4: On CI failure → fix loop (fresh-agent-per-attempt)

The loop is a 3-attempt decision tree that escalates observability as blind
inference becomes less likely to work. Attempt 1 guesses from the log (cheap —
often enough for straightforward failures); attempt 2+ pulls run artifacts
BEFORE guessing (evidence-based); attempt 3 escalates to the user (structural).
This bounds the blind-loop cost to one round and forces evidence on the second
— the "never more than ~2 blind iterations" rail codified from the 2026-04-24
lalista slow-job stabilization incident, where 4 blind retries against a
Playwright failure burned ~30 minutes because the trace artifact was
unreachable from the devcontainer.

**Fresh-agent-per-attempt with persistent already-tried log.** Each attempt
runs as a separate `Agent` tool invocation — a fresh inference context, not a
continuation of the prior attempt's. Without the isolation, a failed attempt's
reasoning (wrong diagnosis, wrong fix-shape, wrong assumption about the failure
class) carries over and biases the next attempt. Without the log, the fresh
agent has no memory of what was tried — it can repeat the same failed approach.
The pattern: each attempt reads `specs/<feature>/fix-attempts.md` first, writes
its own `## Attempt N` section as its final action. Same shape as the
`/ak-implement § Step 3` per-task stuck protocol (`task-attempts/T<N>.md`).

**Artifact lifecycle**: `specs/<feature>/fix-attempts.md` is created on first
failed attempt for this Phase 5 run; cleared (truncated to the header line) at
the start of each new Phase 5 invocation. A new push triggers a new CI run; the
prior attempts on prior CI failures aren't applicable diagnostics for the new
failure.

```
FIX_ATTEMPTS=0
MAX_ATTEMPTS=3

# Clear / initialize the already-tried log for this Phase 5 run.
mkdir -p "$FEATURE_DIR"
printf '# Fix attempts — %s\n\n' "$FEATURE" > "$FEATURE_DIR/fix-attempts.md"

while CI is failing and FIX_ATTEMPTS < MAX_ATTEMPTS:
  Dispatch a fresh sub-agent for this attempt. The agent prompt includes:

  - the CI failure log (attempt #1) OR every artifact + unzipped trace.zip
    (attempt #2+), per the artifact tier-escalation rules below.
  - The contents of $FEATURE_DIR/fix-attempts.md (empty on attempt #1).
  - The 11-step instructions below, with attempt-specific context.
  - The instruction to append its `## Attempt N — <classification>` section
    to fix-attempts.md as its FINAL action before returning, and to NEVER
    repeat a ruled-out approach without explicitly justifying why the prior
    ruling-out was wrong.

  Agent {
    description: "CI fix attempt $((FIX_ATTEMPTS+1)) — $FEATURE",
    subagent_type: "general-purpose",
    prompt: """
      CI is failing on PR #$PR / run $RUN_ID. This is fix attempt $((FIX_ATTEMPTS+1)) of 3.

      READ FIRST: $FEATURE_DIR/fix-attempts.md (your prior-attempts log).
      Do not repeat any approach class listed under 'Ruled out for next
      attempt' without explicitly justifying (in writing) why the prior
      ruling-out was wrong.

      Follow Phase 5.4 steps 1–11 (failure context tier-escalation, classify,
      fix, locally verify or push, workflow-scope detection). Append your
      `## Attempt $((FIX_ATTEMPTS+1)) — <classification>` section to
      fix-attempts.md as your FINAL action before returning.

      Return: pass (pushed; awaiting CI) | timeout-retry (empty-commit pushed)
              | workflow-blocked (human push required; do NOT increment) |
              | unresolved.
    """
  }

  After the agent returns:
    - workflow-blocked → exit the loop (do NOT increment FIX_ATTEMPTS);
      surface the human-push command per step 8 below. /ak-build resumes
      via Step 0's resume check after manual push.
    - timeout-retry → do NOT increment FIX_ATTEMPTS (the empty commit is
      not a fix; it's a retry). Go to 5.2 (watch CI again).
    - pass | unresolved → FIX_ATTEMPTS += 1. Go to 5.2.

  Inside-the-sub-agent steps:

  1. Read failure context (tier escalates with attempt count):

     a. Attempt #1 — log-based inference:
        gh run view <RUN_ID> --log-failed 2>&1 | tail -200
        Proceed with log-only diagnosis. Often enough for lint errors,
        missing deps, env-var format, straightforward test assertions.

     b. Attempt #2+ — artifact-based investigation:
        The log-only guess already failed once. Before attempting another
        fix, pull every artifact from the failed run AND extract each
        failed test's trace.zip — error-context.md alone is not enough
        (it shows the assertion's page snapshot but NOT the console
        messages, network calls, or upgrade-failure events that contain
        the actual root cause for many bugs):

           mkdir -p /tmp/ci-artifacts/<RUN_ID>
           OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
           for art in $(gh api \
               "/repos/$OWNER_REPO/actions/runs/<RUN_ID>/artifacts" \
               --jq '.artifacts[].name'); do
             gh run download "<RUN_ID>" --name "$art" \
                 --dir "/tmp/ci-artifacts/<RUN_ID>/"
           done

           # MUST extract trace.zip per failed test — the .trace and
           # .network files carry the load-bearing evidence. Use a unique
           # extract dir name per zip (avoid `rm -rf` shortcuts):
           for zip in $(find /tmp/ci-artifacts/<RUN_ID> -name 'trace.zip'); do
             dest="/tmp/trace-${zip##*/}-$(basename $(dirname "$zip"))-$$"
             mkdir -p "$dest" && (cd "$dest" && unzip -q "$zip")
           done

        For each failed test, run BOTH inspections:

        - Read `error-context.md` for the assertion's page snapshot and
          the immediate failure signature.
        - Inspect the extracted `0-trace.trace` and `0-trace.network`
          (and `1-trace.*` for two-context tests) for:
            * `'"messageType":"error"'` — console errors (CSP violations,
              uncaught throws, network errors that didn't surface in the
              assertion). CSP violations in particular do NOT appear in
              error-context.md — they only surface as console events.
            * `'"url":"http[^"]*"'` — actual network requests; absence
              of an expected call (e.g. no `auth/v1/token` POST when
              the test should have signed in) is often the smoking gun
              that the click did not actually fire the API call.
            * `'fill\\(|click\\(|getByLabel|getByRole'` — Playwright
              actions and what they resolved to.

        These two inspections answer different questions: error-context
        says "what did the page look like at the assertion?"; trace says
        "what did the page do over the test's lifetime?" Many root causes
        are visible only in the trace (silent network failures, CSP
        blocks, missing API calls, console errors that don't bubble to
        assertions).

        Optional: open interactively if a local GUI is available:

           pnpm exec playwright show-trace \
               /tmp/ci-artifacts/<RUN_ID>/<test-dir>/trace.zip

        The page state at the assertion is definitive — diagnose from
        evidence, not inference. Reading only error-context.md and
        skipping the trace turns attempt #2 back into guessing; that
        defeats the artifact-pull rung's purpose.

  2. Classify failure: lint | typecheck | unit | integration | e2e | build | timeout

  3. For timeout/flaky: just push an empty commit to trigger retry
     git commit --allow-empty -m "ci: retry after timeout"
     git push

  4. For real failures:
     a. Grep the test name from the logs
     b. Read the failing test file locally
     c. Read the source code the test exercises
     d. Understand why it fails:
        - Attempt #1: logs + local code context
        - Attempt #2+: artifacts (trace, error-context.md, screenshots) + logs + local code
     e. Fix the source code

  5. For locally verifiable failures (lint, typecheck, unit, build):
     Run the relevant local command to confirm the fix works
     pnpm turbo run lint        # for lint failures
     pnpm turbo run typecheck   # for type errors
     pnpm turbo run test:unit   # for unit test failures
     pnpm turbo run build       # for build failures

  6. For CI-only failures (integration, E2E):
     Fix is informed by logs (and artifacts on attempt 2+) but cannot be
     verified locally. Push and let CI verify.

  7. Commit:
     git add -A
     git commit -m "fix: CI failure - <description>"

  8. **Workflow-scope detection** — before pushing, check whether the
     commit touches `.github/workflows/**`. The devcontainer PAT lacks
     `workflow` scope intentionally (security posture: Claude can't
     silently amend CI). If the diff matches:

        TOUCHED_WORKFLOWS=$(git diff --name-only HEAD~1 HEAD | \
          grep -E '^\.github/workflows/' || true)

     If `TOUCHED_WORKFLOWS` is non-empty, do NOT attempt `git push`
     (it will fail with `refusing to allow a Personal Access Token
     to create or update workflow ... without 'workflow' scope`).
     Surface the human-push command directly:

        SHA=$(git rev-parse HEAD)
        REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
        USER=$(gh api user --jq .login)
        echo "⚠ Commit $SHA touches workflow file(s):"
        echo "$TOUCHED_WORKFLOWS"
        echo ""
        echo "The devcontainer PAT lacks 'workflow' scope. Push needs a"
        echo "user PAT with that scope:"
        echo ""
        echo "  git -C \$PWD -c credential.helper= \\"
        echo "    push https://${USER}@github.com/${REPO}.git ${BRANCH}"

     Then **exit the fix loop** (do NOT increment FIX_ATTEMPTS or
     re-enter 5.2). After the user pushes manually, /ak-build will
     resume on next invocation via Step 0's resume check (which lands
     at Phase 5).

     Otherwise (no workflow files touched):
        git push

  9. After pushing, update PR title/description if the fix changes scope.

  10. Append the structured already-tried section to fix-attempts.md as the
      LAST action before returning:

         ## Attempt N — <one-line failure classification>

         - Hypothesis: <what we thought was broken>
         - Tried: <what we changed; commit SHA>
         - Why ruled out: <what evidence shows it didn't fix it>
         - Ruled out for next attempt: <approach class to skip>

      Return one of: pass | timeout-retry | workflow-blocked | unresolved
      (semantics in the orchestrator block above).

  11. (Orchestrator side, outside the sub-agent) Go to 5.2 (watch CI again)
      OR exit on workflow-blocked.
```

**Notes on the artifact-pull path:**

- Inspect `error-context.md` + PNG screenshots + unzipped `trace.zip` (DOM snapshots + network logs) directly. `playwright show-trace` is optional (needs a local display); the inline files are sufficient for evidence.
- Whatever the test framework, attempt #2 pulls every artifact the failed run produced — `gh api .../artifacts` enumerates them. If the artifact you need isn't there, that's a CI-config bug worth fixing in this same PR (e.g., the workflow forgot `actions/upload-artifact@v4` with `if: failure()`).

### 5.5: Escalation after max attempts

If CI still fails after 3 fix attempts:

```bash
gh pr comment "$PR" --body "## CI failing — help needed

@$(gh api user --jq .login) CI is still failing after $FIX_ATTEMPTS fix attempts.

**Last failure:** <check name>
**Error:** <1-line summary from logs>
**Attempts:**
1. <what was tried and why>
2. <what was tried and why>
3. <what was tried and why>

**Failing run:** <link to run>"
```

Stop and wait. The user gets a GitHub notification.

### 5.6: Verify Phase 4.0's BUILD-LOG commit shipped (fallback if not)

Phase 4.0 composes + commits BUILD-LOG.md + PLAN.md row removal on the
feature branch before `/ship` runs, so `/ship`'s push at Phase 4.2
carries the bookkeeping atomically — no second CI cycle. 5.6 is the
verification rung that catches resume paths or out-of-order invocations
where 4.0 didn't run.

**Steps**:

1. Look for the bookkeeping commit on this branch:

   ```bash
   BUILD_LOG_COMMIT=$(git log "origin/${BASE}..HEAD" \
     --grep="^chore(build-log): record" --format=%H -1)
   ```

2. **If present** (the common path — 4.0 ran): no-op. Print
   `✓ 5.6: build-log already recorded at $BUILD_LOG_COMMIT`. Advance to
   Phase 5.8 (Phase 5.7 was deleted; no re-watch cycle).

3. **If absent** (resume rung where 4.0 was skipped, or 4.0 itself was
   skipped via Phase 0 resume): run the full Phase 4.0 procedure here
   (steps 1–4 of § 4.0), then commit + push:

   ```bash
   git add PLAN.md BUILD-LOG.md  # plus any deleted/rewritten files from § 4.0 step 4
   git commit -m "chore(build-log): record <FEATURE>"
   git push
   ```

   This push triggers a new CI run. Watch it via the same loop as 5.2
   (set `RUN_ID = gh run list --branch "$BRANCH" --limit 1 …`, then
   `gh run watch "$RUN_ID" --exit-status`, cross-check conclusion). On
   green, re-run 5.3 to update PR body checkboxes for the new SHA, then
   advance to Phase 5.8. On red, route to 5.4's fix loop. This is the
   pre-elision behavior; it's the right shape for the fallback even
   though it incurs the CI cycle the elision exists to avoid.

**Idempotence**: 5.6 either no-ops (commit present) or runs once (commit
absent and 4.0 didn't fire). The check is a single `git log --grep` —
no race window with 4.0.

**Why 5.7 was deleted**: the historic 5.7 re-watched CI after 5.6's
unconditional bookkeeping push. With 4.0 making the bookkeeping commit
part of `/ship`'s push, the common path has no 5.6 push to re-watch and
Phase 6 can verify the PR surface against the original `/ship` CI run. The "watch every
push" guarantee (the load-bearing piece 5.7 enforced) is folded into
5.3's preamble: every subsequent push on the branch — polish-loop fixes,
audit-fix commits, out-of-band operator edits, OR a 5.6-fallback push —
must be re-watched before Phase 6 attests the PR body. Phase 5.8.1's polish-loop CI
sanity check is the enforcement point on entry to 5.8 (it enumerates
every run since PR open and halts if the latest isn't green).

## Phase 5.8: Post-pre-ship docs + tests re-audit

`/ak-pre-ship` runs `/ak-check-docs-and-tests` as Gate 5 once, against the
spec snapshot — that audit appends `## Audit 1` to `review.md`. Every commit
landed AFTER that audit — Phase 4.0's `chore(build-log)` commit, `/ship`'s
`Suspense`-fix commit, the entire CI fix-loop, a 5.6-fallback bookkeeping
commit if one fired, and any post-Phase-3 polish iterations the user asks
for during local dogfood — bypasses docs +
test-coverage review entirely. The pre-push reviewer covers PR-description
coverage, the Layer-1 test-presence hook covers "did you touch a test file
at all," and the freshness hook covers docs — but none check **whether the
new behavior is actually pinned by an assertion** or **whether the polish
diff invalidated existing docs**. That's `/ak-check-docs-and-tests`'s job;
5.8 re-runs it once over the polish range — appending `## Audit 2` to the
same `review.md` — before Phase 6 verifies the PR surface.

**Devshop-side equivalent**: this phase is project-specific (assumes
Phase 5's CI watch + post-CI-green polish window precedes it). Devshop
branches that ride `/ak-build` go straight from Phase 3 to `/ak-merge-
devshop` — there's no project-style polish window, so 5.8 doesn't fire
for them. The analogous catch-rung on the devshop side lives in
`.claude/skills/devshop/merge-devshop/SKILL.md § Phase 1 (medium
findings)` — Phase 1's audit interactively pauses on medium-severity
findings via `AskUserQuestion`, giving the operator the same
"spec-vs-delivery gap" polish opportunity 5.8 provides on the project
side. Different mechanism (interactive halt at merge time vs. dedicated
audit phase post-CI), same intent (catch the gap before it ships).

**Why a test-presence hook isn't enough**: the Layer-1 hook
(`check-tests-coverage-project.sh`) catches "added a `.tsx` file with no
`.test.tsx` next to it" — a file-level math check. It cannot judge:

- A new prop on an existing component lacks a test for the prop's
  behavior (`AwaitingConfirmationCard` gained an `onEdit` callback in
  lalista PR #43; the file-level paired test exists but does nothing
  for the new prop).
- A new code branch is unreached by any existing test (sign-up's
  no-enumeration parity changed which UI path renders for `identities=[]`
  — same file, same test file, but the existing tests pinned the OLD
  behavior).
- A modification crossing a security boundary (password policy) where
  the existing tests still pass but no longer assert the right thing.

These are the cases `/ak-check-docs-and-tests` (sub-skill `/ak-tests-review`)
catches via fresh-eyes read; the docs sub-skill `/ak-docs-review` covers
the symmetric "the polish diff invalidated CLAUDE.md / Gotchas / a
README" case.

### 5.8.1: Polish-loop CI sanity check (enumerate-on-invocation)

Every push between Phase 4 (PR open) and 5.8 fires a CI run. That data
is free; ignoring it lets reds accumulate silently across polish
iterations until something forces a check (the lalista PR #43 failure
mode — 4 silent reds before the user manually flagged one). 5.8's first
job is to surface every CI result since the PR opened, then halt if the
latest is non-success.

This replaces the prior "watch every push as discipline" framing. There's
no orchestrator state to maintain, no background watches to keep alive
across user-driven dogfood sessions, and no load-bearing-discipline
ask. The data is queried from GitHub at the moment we actually need it.

```bash
PR_OPENED_AT=$(gh pr view "$PR" --json createdAt --jq .createdAt)
RUNS=$(gh run list --branch "$BRANCH" --limit 50 \
  --json conclusion,createdAt,headSha,displayTitle,databaseId,status \
  --jq "[.[] | select(.createdAt >= \"$PR_OPENED_AT\")]")

# Surface every red run since PR open — informational, even when latest is green.
echo "$RUNS" | jq -r '
  .[] | select(.conclusion == "failure") |
  "  \(.createdAt | sub("T"; " ") | sub("Z"; "")) \(.headSha[0:7]) \(.displayTitle)"' \
  > /tmp/polish-loop-reds.txt

if [ -s /tmp/polish-loop-reds.txt ]; then
  echo "Polish-loop CI failures since PR open:"
  cat /tmp/polish-loop-reds.txt
fi

# Halt only if LATEST is non-success — that's the actionable state.
LATEST=$(echo "$RUNS" | jq -r '.[0] | .conclusion // .status // "unknown"')
if [ "$LATEST" != "success" ]; then
  echo "✖ 5.8 prereq: latest CI run is $LATEST (not success)."
  echo "  Routing to Phase 5.4's fix loop. 5.8 will re-run on the"
  echo "  next /ak-build invocation after CI is green."
  goto_phase=5.4
  return
fi
```

**Reading the output**: a transient red→green sequence (push broke
something, next push fixed it) is informational. The `review.md` audit
section records the count for reviewer due-diligence — it's evidence
the polish loop hit and resolved real failures, not a problem. A
sustained-red latest run is the halt path.

### 5.8.2: Determine the audit range

The audit runs over `<latest-audit-SHA>..HEAD`, where `<latest-audit-SHA>`
is read from the **latest `## Audit N` section** in `review.md` —
typically Audit 1, written by `/ak-pre-ship` Gate 5 against the spec
snapshot. The orchestrator (`/ak-check-docs-and-tests § Step 2`) does this
computation itself; 5.8 doesn't need to pre-compute the range. But the
following pre-flight signal still applies — surface it loudly if the
stamp is missing so the producer (Gate 5) gets fixed, not the consumer:

```bash
PRE_SHIP_SHA=$(grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' \
  "$FEATURE_DIR/review.md" 2>/dev/null | tail -1)

if [ -z "$PRE_SHIP_SHA" ]; then
  echo "✖ 5.8: review.md has no '## Audit N' section with"
  echo "  '<!-- audited-at: <SHA> -->'."
  echo "  Phase 3 (/ak-pre-ship Gate 5) is supposed to invoke"
  echo "  /ak-check-docs-and-tests, which appends '## Audit 1' with"
  echo "  the stamp. Either the file was rebased and the section"
  echo "  was lost, or Gate 5 ran against an older skill version."
  echo "  Re-run /ak-pre-ship to regenerate review.md with the"
  echo "  current stamp."
  SKIP_5_8=1
fi

# Empty range = no commits between Phase 3 and HEAD = 5.8 is a no-op.
if [ -z "$SKIP_5_8" ] && [ -z "$(git log --oneline "$PRE_SHIP_SHA"..HEAD)" ]; then
  echo "✓ 5.8: empty range ($PRE_SHIP_SHA..HEAD) — no polish commits"
  echo "  to audit. Recording 'clean — no polish range' in the audit"
  echo "  comment."
  SKIP_5_8=1
fi
```

The `tail -1` (vs `head -1`) is intentional: `## Audit N` sections append
over time, so the latest stamp is the bottommost one. The orchestrator
uses the same parser; 5.8 mirrors it for the pre-flight skip check.

### 5.8.3: Spawn the audit subagent

5.8 delegates to `/ak-check-docs-and-tests` (the audit-time orchestrator)
rather than calling `/ak-tests-review` directly. The orchestrator runs
both Layer 2 reviews (docs + tests) over the same range and appends a
single `## Audit 2` section to `review.md`.

```bash
Agent({
  description: "Phase 5.8: post-pre-ship docs + tests re-audit",
  subagent_type: "general-purpose",
  prompt: "Run /ak-check-docs-and-tests via the Skill tool with
  --feature-dir ${FEATURE_DIR} --label post-polish on branch ${BRANCH}
  of repo ${REPO_ROOT}. The orchestrator computes the range from the
  latest '## Audit N' section in ${FEATURE_DIR}/review.md, dispatches
  /ak-docs-review and /ak-tests-review as parallel Agent calls with
  per-file sinks under specs/<feature>/gates/audit-N-{docs,tests}.md,
  concatenates into a new '## Audit N' section with structured findings
  (docs + tests) and bypass-trailer review. Do NOT write any docs or
  tests yourself — your job is to audit and recommend, not implement.

  **COMMIT-OR-SURFACE RULE** (codified from home-os PR #26 — the
  Audit-2 section was written to ${FEATURE_DIR}/review.md but never
  committed; it was lost when the squash-merge happened mid-flight):
  After appending the section, either (a) commit it on the current
  branch with message 'docs(${FEATURE}): Phase 5.8 review.md Audit N
  section' using the dirtyTreeReason bypass if needed, OR (b) leave
  the file dirty in the working tree AND return the line 'UNCOMMITTED:
  ${FEATURE_DIR}/review.md' in your response so the orchestrator can
  decide what to do. Default to (a) — committing is the right call
  unless something specific blocks it. Never return success without
  one of these two outcomes; a clean working tree with no commit
  means the audit was silently lost.

  Return: the findings summary line ('findings: high=N medium=N
  low=N') from the appended section, plus 'committed: <SHA>' or
  'UNCOMMITTED: <path>'."
})
```

### 5.8.4: Severity branching

Mirrors `/ak-pre-ship`'s `findings_pending > 0` halt and the Phase 3 → 4
`blocked > 0` refusal. Severity totals come from the appended `## Audit
N` section's `findings: high=H medium=M low=L` summary line:

| Severity     | Action                                                                                                                                                                                      |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `high>0`     | **Halt** at 5.8. Surface the findings to the user in the same shape as `findings_pending`. Phase 6 does NOT run. User options: (a) close findings with new commits (docs and/or tests) and re-invoke `/ak-build` (resumes via Step 0 — 5.8 re-runs over the new HEAD; the orchestrator's idempotence guard skips if HEAD didn't move); (b) override via `git config devshop.testReviewSkipReason "<specific reason>"` (then re-invoke). The Layer-2 adversarial reviewer judges the override. |
| `medium>0`   | **Proceed**. The `review.md` audit section lists them under `### Post-pre-ship docs + tests findings` so a reviewer reading the committed audit trail sees them. Mediums are recommendations, not blockers.                                          |
| `low>0`      | `review.md` notes `(N low-severity items in § Audit N)` without listing.                                                                                                        |
| `0/0/0`      | `review.md` notes `Post-pre-ship audit: clean.`                                                                                                                                           |

**Halt-path output**:

```
✖ Phase 5.8: post-pre-ship docs + tests audit found N high-severity
findings over range ${PRE_SHIP_SHA}..${HEAD}.

Findings (full report at ${FEATURE_DIR}/review.md § Audit N):
  - <finding 1: file:line + one-line summary>
  - <finding 2: ...>

Phase 6 will not run until findings are closed.

Options:
  1. Close findings with new commits (docs and/or tests), then re-run
     /ak-build. Step 0 resumes at Phase 5.8; the audit re-runs over
     the new HEAD.
  2. Override with a specific bypass reason:
     git config devshop.testReviewSkipReason "<why these are OK to ship>"
     then re-run /ak-build. The reason is judged by the adversarial
     reviewer (testReviewSkipReason check-type, Sonnet 4.6); generic
     reasons fail.
```

### 5.8.5: Idempotence

Skip 5.8 when the latest `## Audit N` section in `review.md` is already
stamped at HEAD:

```bash
if [ -f "$FEATURE_DIR/review.md" ]; then
  LATEST_AUDIT_SHA=$(grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' \
    "$FEATURE_DIR/review.md" 2>/dev/null | tail -1)
  HEAD_SHA=$(git rev-parse HEAD)
  if [ -n "$LATEST_AUDIT_SHA" ] && [ "$LATEST_AUDIT_SHA" = "$HEAD_SHA" ]; then
    echo "✓ 5.8: already audited at $HEAD_SHA — skipping"
    SKIP_5_8=1
  fi
fi
```

This is the same idempotence pattern that lets Step 0's resume-rung
1a fast-forward past 5.8 — both paths read the latest `## Audit N`
section's `audited-at` stamp via `tail -1`. It also matches the
orchestrator's own Step 6 idempotence guard (so even if 5.8 invokes
the orchestrator unconditionally, the orchestrator no-ops at the same
boundary — defensive double-check).

## Phase 5.9: Post-pre-ship visual evidence refresh

The hero screenshots embedded in the PR body are captured during
`/ak-pre-ship` Gate 4 (responsive + theme) and Gate 13 (hero shots) at
Phase 3 — against the spec snapshot. Every commit that lands AFTER
Phase 3 can change what each screen looks like, but the PR-body
screenshots stay frozen at the Phase-3 SHA. The reviewer reads the body,
sees the wrong UI, and either re-runs the screenshots manually or
reviews the wrong artifact.

5.9 is the visual-evidence sibling to 5.8 — once-per-PR, late in the
pipeline. The previous version of this section routed captures through
a bytewise diff (changed / unchanged / new / deleted). That was
over-engineering: headless Chromium captures vary on font hinting and
GPU rasterization, so bytewise comparison false-positives on every run;
and the reviewer doesn't actually care which files changed, only that
the embeds match HEAD. **Always regenerate, always commit on changes;
no diff routing**.

### 5.9.1: What gets regenerated

| Path                                                 | Refresh? | Why                                                                                                                                                                                                                        |
| ---------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `$FEATURE_DIR/hero/*.png`                            | yes      | The curated hero set referenced by the PR body's `https://github.com/.../raw/.../hero/<file>.png` embeds — overwriting the file at the same path makes the embeds resolve to the new image automatically; no PR body edit. |
| `$FEATURE_DIR/screenshots/<screen>-<vw>-<theme>.png` | yes      | The 4-combo evidence matrix from Gate 3 (typically not embedded in the PR body, but kept fresh for the audit doc).                                                                                                         |
| `$FEATURE_DIR/qa-walk/*.png`                         | **no**   | Walk-through-specific; re-running the walk requires a full Gate 9 happy-path re-run, too expensive for routine 5.9. Defer to a separate roadmap entry if the need surfaces.                                                |

### 5.9.2: Spawn the refresh subagent

```bash
Agent({
  description: "Phase 5.9: post-pre-ship visual evidence refresh",
  subagent_type: "general-purpose",
  prompt: "Re-run /ak-pre-ship Gate 4 (responsive + theme — 4 combos
  per screen) and Gate 13 (hero shots) over branch ${BRANCH} at HEAD.
  Read the existing screenshot manifest at ${FEATURE_DIR}/review.md
  to know which screens were captured originally; capture the same
  set against the latest UI, overwriting every file under
  ${FEATURE_DIR}/{screenshots,hero}/. Do not diff against the previous
  captures — always regenerate. Capture at fixed viewport sizes with
  prefers-reduced-motion: reduce (per /ak-pre-ship convention).

  Edge cases:
  - New screen (rare; only if a polish commit added a new route) →
    write a new file using the manifest's filename convention.
  - Removed screen (rare; only if a polish commit deleted one) →
    delete the stale file AND update the PR body via
    'gh pr edit \$PR --body-file <new-body>' to drop the embed.

  Stage everything under ${FEATURE_DIR}/{screenshots,hero}/, then:
  - if 'git diff --cached --quiet' (no actual changes), do not commit
    (the captures were bytewise-identical or only differ by deterministic
    noise that git's content hashing happens to absorb — either way,
    nothing to ship);
  - otherwise commit with message
    'chore(${FEATURE}): refresh visual evidence at HEAD (Phase 5.9)'.

  Return: 'committed' or 'no-op'."
})
```

The "regenerate, then commit only if `git diff --cached` shows changes"
shape replaces the bytewise-routing prose. Git already does
content-addressed hashing — let it decide whether the regenerated
captures are actually different from what's tracked. False positives
from rasterization variance still reach the working tree but don't
reach a commit.

### 5.9.3: No halt path

5.9 is freshness-only. There is no "high-severity finding" concept and
no escalation. The subagent either produces a commit (UI did change
during polish) or a no-op (UI is unchanged). The `review.md` audit
section records which.

### 5.9.4: Idempotence

Skip 5.9 when both `$FEATURE_DIR/screenshots/` and `$FEATURE_DIR/hero/`
have a clean working tree AND the latest commit touching either dir is
at HEAD:

```bash
if [ -z "$(git status --porcelain -- \
  "$FEATURE_DIR/screenshots" "$FEATURE_DIR/hero" 2>/dev/null)" ]; then
  LAST_VISUAL_COMMIT=$(git log -1 --format=%H -- \
    "$FEATURE_DIR/screenshots" "$FEATURE_DIR/hero" 2>/dev/null)
  if [ "$LAST_VISUAL_COMMIT" = "$(git rev-parse HEAD)" ]; then
    echo "✓ 5.9: visual evidence already at HEAD — skipping"
    SKIP_5_9=1
  fi
fi
```

This is the same shape that lets Step 0's resume-rung 1b fast-forward
past 5.9 — both paths read the same git state.

After 5.9 commits its refresh (when the UI did change), the resulting
push triggers a fresh CI run. 5.8's polish-loop CI sanity check (§5.8.1)
catches any failure on the next /ak-build invocation; do not advance to
Phase 6 until that run is green.

**Exit artifact** (§ Phase exit artifact registry row `5.9`): as the
final action of 5.9 (after the subagent returns or after the idempotence
skip at § 5.9.4), write the outcome:

```bash
if [ -n "$SKIP_5_9" ]; then
  echo "skipped: idempotence — visual evidence already at HEAD" \
    > "$FEATURE_DIR/visual-refresh.log"
else
  echo "$SUBAGENT_RESULT at $(git rev-parse HEAD)" \
    > "$FEATURE_DIR/visual-refresh.log"
fi
```

### 5.10: Phase 5 exit checklist

Before advancing to Phase 6, verify that every Phase 5 sub-step produced
its required artifact. See § Phase exit artifact registry for the
canonical list. A missing artifact means the sub-step was silently
skipped — halt and surface, same shape as § Phase 3 → 4 handoff.

```bash
EXIT_MISSING=""

# 1. Body-consistency log (5.3.5)
if [ ! -f "$FEATURE_DIR/body-consistency.log" ]; then
  EXIT_MISSING+="  body-consistency.log (Phase 5.3.5 never ran)\n"
fi

# 2. Post-pre-ship audit (5.8): review.md Audit N at HEAD or skip logged
if [ -z "$SKIP_5_8" ]; then
  LATEST_AUDIT_SHA=$(grep -oP '(?<=<!-- audited-at: )[a-f0-9]+' \
    "$FEATURE_DIR/review.md" 2>/dev/null | tail -1)
  HEAD_SHA=$(git rev-parse HEAD)
  if [ "$LATEST_AUDIT_SHA" != "$HEAD_SHA" ]; then
    EXIT_MISSING+="  review.md Audit N stamp not at HEAD (5.8 did not audit; latest=$LATEST_AUDIT_SHA, HEAD=$HEAD_SHA)\n"
  fi
fi

# 3. Visual refresh log (5.9)
if [ ! -f "$FEATURE_DIR/visual-refresh.log" ]; then
  EXIT_MISSING+="  visual-refresh.log (Phase 5.9 never ran)\n"
fi

if [ -n "$EXIT_MISSING" ]; then
  echo "✖ Phase 5 exit checklist: required artifact(s) missing."
  echo -e "$EXIT_MISSING"
  echo ""
  echo "  Phase 6 will NOT run. Re-invoke /ak-build to re-enter Phase 5;"
  echo "  the resume check picks up at the PR's current state and"
  echo "  re-runs the missing sub-steps."
  exit 1
fi

echo "✓ Phase 5 exit checklist: all artifacts present."
```

## Phase 6: Verify the PR surface

After CI is green, read `$FEATURE_DIR/review.md` and `$FEATURE_DIR/tasks.md` for the
audit data. Phase 6 validates that the PR body tells the truth (Parts A–D below); it
posts nothing. The gate-by-gate audit trail already lives in the committed
`specs/<feature>/review.md` — a PR comment would only duplicate it onto the timeline,
contradicting the no-clutter convention (Phase 4.1 "body … clean of devshop process
artifacts"; Phase 7 "the PR being open IS the notification").

Use the outcome vocabulary from `/ak-pre-ship`: **`pass`**, **`findings (N) [fixed | pending]`**,
**`n/a`** (gate didn't apply), **`blocked`** (tooling missing — should never reach
Phase 6 because Phase 3 refuses to advance, but surface it if it somehow does).

### Phase 6 checkbox verification (final sweep)

Before leaving Phase 6, re-read the PR body one more time and reconcile the `## Test plan` checkboxes against reality.

**Part A — State-based reconciliation** (does the box's state match its trigger signal?):

| Box                                                                     | Should be `[x]` when                                                                                                                                                                                                                          |
| ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CI green                                                                | CI run completed with `conclusion == "success"` — mark when Phase 5.3 fires.                                                                                                                                                                  |
| Vercel/Netlify/Fly preview deployed                                     | Platform bot comment reports `Ready` / equivalent — mark with the preview URL + timestamp.                                                                                                                                                    |
| Manual-review callouts (visual audits, QA walkthrough, post-deploy p95) | **Never** — these are for the reviewer, not the automation.                                                                                                                                                                                   |

If any box is in the wrong state when Phase 6 runs, fix it with `gh pr edit "$PR" --body-file`.

**Part A exit marker**: `echo "reconciled at $(git rev-parse HEAD)" > /tmp/phase6-partA.done`

**Part B — Evidence-on-disk sweep** (does every `[x]` that maps to an artifact actually have that artifact?):

A `[x]` claim is only credible when the artifact exists. Phase 6 verifies this for every checkbox that maps to a file or URL-resolvable resource:

| Checkbox type                                                       | Expected artifact                                                                           | Verification                                                                                                 |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Hero screenshot(s) (`![...](https://github.com/.../raw/.../specs/.../hero/*.png)`) | File exists at `specs/<feature>/hero/<screen>.png`                                          | `[ -f "specs/$FEATURE/hero/<screen>.png" ]`                                                                  |
| 4-combo evidence matrix (Gate 3)                                    | Files exist at `specs/<feature>/screenshots/<screen>-{375,1440}-{light,dark}.png`           | Stat each of the 4 per primary screen (same list Gate 3 used)                                                |
| Gate 9 happy-path walk                                              | `specs/<feature>/qa-walk.log` OR Playwright trace in `specs/<feature>/traces/`              | `[ -f qa-walk.log -o -d traces ]`                                                                            |
| Vercel/Netlify/Fly preview deploy checkbox                          | Platform bot's status comment reports `Ready` / `Deployed` / `Healthy`                      | Parse `gh pr view "$PR" --json comments` for the platform-bot comment; match its status badge / status line |
| CI-green checkboxes                                                 | Referenced run-id is `success` in `gh run view`                                             | Already covered by Part A's state-based reconciliation                                                       |

**Implementation sketch**:

```bash
# Re-fetch current PR body
gh pr view "$PR" --json body --jq .body > /tmp/pr-body.md

EVIDENCE_MISSING=""

# For every [x] image embed, check the referenced file exists in specs/
grep -oE '!\[.*\]\(https://github.com/[^)]+\)' /tmp/pr-body.md | while read -r embed; do
  # Extract the path after /raw/<branch>/
  rel_path=$(echo "$embed" | sed -E 's|.*/raw/[^/]+/(.+)\).*|\1|')
  if [ ! -f "$rel_path" ]; then
    EVIDENCE_MISSING+="  $rel_path (referenced in PR body but not in repo)\n"
  fi
done

# For every [x] preview-deploy line, verify the PLATFORM BOT's status —
# not the URL. curl-from-devcontainer is brittle: branch-preview subdomains
# aren't in the firewall allowlist (resolved IPs vary per branch), CDN IPs
# rotate, geo-routing can give different answers than what reviewers see.
# The platform bot's comment is the canonical signal — that's what GitHub
# shows reviewers regardless of where the curl runs from. Codified from
# lalista PR 18 (2026-04-25): firewall blocked the preview-host curl, but
# Vercel's `Ready` badge in the bot comment was authoritative.
if grep -qE '\[x\].*(vercel|netlify|fly)\.(app|dev|io)' /tmp/pr-body.md; then
  # Find the platform bot's most recent comment + check its status line.
  # Each platform's bot user/format:
  #   Vercel  → login "vercel", body contains `![Ready](...ready.svg)`
  #   Netlify → login "netlify", body contains "Deploy preview ready!"
  #   Fly     → login "fly-pr-review-apps", body contains "Successful deploy"
  STATUS=$(gh pr view "$PR" --json comments --jq '
    [.comments[] | select(.author.login | IN("vercel","netlify","fly-pr-review-apps"))] | last |
    if . == null then "no-bot-comment"
    elif (.body | test("Ready|Deploy preview ready|Successful deploy")) then "ready"
    elif (.body | test("Building|Queued|Deploying|in_progress")) then "in-progress"
    else "failed-or-unknown"
    end')
  case "$STATUS" in
    ready) ;;  # matches the [x] claim — pass
    in-progress)
      EVIDENCE_MISSING+="  Platform deploy still in progress (bot not yet showing 'Ready') — checkbox is premature\n";;
    failed-or-unknown)
      EVIDENCE_MISSING+="  Platform bot comment does not show Ready/Deployed/Healthy — checkbox claim is wrong\n";;
    no-bot-comment)
      EVIDENCE_MISSING+="  No platform bot comment found, but PR body claims preview deployed — verify out-of-band\n";;
  esac
fi

# For Gate 3 / Gate 9 evidence (inferred from $FEATURE_DIR):
[ -n "$(ls specs/$FEATURE/hero/ 2>/dev/null)" ] || EVIDENCE_MISSING+="  specs/$FEATURE/hero/ (no hero shots captured)\n"
```

If `$EVIDENCE_MISSING` is non-empty → **halt Phase 6**. The PR body carries an `[x]` claim with no backing artifact — surface the discrepancy to the operator:

```
✖ Phase 6 evidence-on-disk sweep: N [x] checkbox(es) reference missing evidence.

Missing:
$EVIDENCE_MISSING

Options:
  1. Produce the evidence (re-run the gate, commit the artifact)
  2. Downgrade the checkbox to [ ] — only appropriate if the claim was aspirational
  3. Remove the checkbox row entirely — if it was never in scope

Do NOT ship a PR with [x] claims that don't match reality. The reviewer trusts those marks.
```

This extension pairs with Gate 3's evidence-matrix enforcement (Fix B) and Gate 9's happy-path evidence requirement (Fix C) — both gates produce the artifacts; Phase 6 verifies the PR body tells the truth about them.

**Part B exit marker**: `echo "swept at $(git rev-parse HEAD)" > /tmp/phase6-partB.done`

**Part C — Manual-review classification sweep** (does each `[ ]` under "Manual review" actually need a human?):

For every `[ ]` line under a `### Manual review` (or "Live QA" / "Reviewer-only") heading in the PR body, classify as `factual` (resolvable by file/symbol/value lookup) or `judgmental` (spec/design/UX/intent). See `## PR body conventions § What belongs in "Manual review"` for the canonical set the body should have followed.

| Classification | Verification result | Action |
|---|---|---|
| `factual` | Verifies ✓ (file exists / symbol present / claim true) | Rewrite line as `[x] <text> (verified at <file>:<line>)`. No halt; no operator prompt — autonomous closure is Phase 6's job. |
| `factual` | Verifies ✗ (artifact contradicts the claim) | Halt — same shape as Part B's "evidence missing" branch. The body claims something the file disproves; that's a real problem. |
| `judgmental` | n/a | Leave `[ ]` for the human reviewer. |

Classification heuristic — words that fire `factual`: "is correct", "matches", "cites", "references", "reads correctly", "follows convention X", "matches schema Y", "guards against pattern Z", "file exists", "symbol exists". Words that fire `judgmental`: "reflects intent", "looks right", "feels good", "is intuitive", "tests pass on prod", "design hierarchy correct", "user flow works end-to-end". When ambiguous, default to **factual** — the verification is cheap (one Read or one grep), halting on a false positive is recoverable, and keeping a factual item under Manual review just to dodge the verification round-trip wastes the operator's attention.

**Implementation sketch**:

```bash
# Reuse /tmp/pr-body.md from Part B if present
[ -f /tmp/pr-body.md ] || gh pr view "$PR" --json body --jq .body > /tmp/pr-body.md

# Extract the Manual review block (from "### Manual review" to the next ###/## or EOF)
awk '/^### Manual review/,/^(### |## )/' /tmp/pr-body.md \
  | grep -E '^- \[ \]' > /tmp/manual-review-items.txt

FACTUAL_RE='is correct|matches|cites|references|reads correctly|follows convention|file exists|symbol exists'
JUDGMENT_RE='reflects intent|looks right|feels good|is intuitive|tests pass on prod|design hierarchy|user flow|end-to-end'

while IFS= read -r line; do
  if echo "$line" | grep -qiE "$JUDGMENT_RE"; then
    CLASS=judgmental
  elif echo "$line" | grep -qiE "$FACTUAL_RE"; then
    CLASS=factual
  else
    CLASS=factual  # default when ambiguous; verify is cheap
  fi
  case "$CLASS" in
    judgmental) ;;  # leave [ ] for human
    factual)
      # Run the operator-drafted verification (Read the file / grep the symbol).
      # On verifies ✓: edit /tmp/pr-body.md to rewrite this line as [x] with attestation.
      # On verifies ✗: append to $EVIDENCE_MISSING per Part B's halt path.
      ;;
  esac
done < /tmp/manual-review-items.txt
```

**Why Phase 6 auto-attests rather than surfacing**: Phase 6's existing Parts A and B already do autonomous closure (state-based reconciliation marks CI/preview `[x]`; evidence sweep halts only on missing artifacts). The factual-checkbox case is symmetric to Part A — auto-attest when verifiable, halt only when something is genuinely wrong. Surfacing a factual item to the operator just to do the verification I could have done myself wastes their attention; surfacing only on real failure preserves it.

Codified from lalista PR 27 (2026-04-27) — the PR shipped with 4 Manual-review items; 3 of 4 were factually verifiable by reading specific files. Phase 6 should have auto-attested those rather than leaving them as `[ ]` for the operator's eyes.

**Part C exit marker**: `echo "classified at $(git rev-parse HEAD)" > /tmp/phase6-partC.done`

**Part D — Product update verification (Gate A + Gate B):**

The `## Product update` section was authored at Phase 0 from intent — the polish loop may have subtly changed what shipped (a fix added a user-visible disclosure, a feature was trimmed for scope). Without a verification rung, both blurbs decay to stale claims that propagate verbatim into BUILD-LOG / Phase 7 / `/ak-go-live` Step 6 / future CHANGELOG aggregation. Part D pairs an automated cross-check (Gate B) with an autonomous review (Gate A) at the final-sweep moment — Gate A reads both blurbs against the diff and self-resolves, escalating to the operator only on a genuine claim-vs-diff product-judgment mismatch the diff can't settle.

**Gate B — automated claim-vs-diff cross-check (runs first, informs Gate A):**

```bash
BASE=$(gh pr view "$PR" --json baseRefName --jq .baseRefName)
DIFF_RANGE="origin/${BASE}...HEAD"

# Pull both blurbs from spec.md verbatim.
HEADLINE_BODY=$(awk '/^### Headline \(user-facing\)/{flag=1; next} /^###|^## /{flag=0} flag' \
  "$FEATURE_DIR/spec.md")
DETAIL_BODY=$(awk '/^### Detail \(team-facing\)/{flag=1; next} /^###|^## /{flag=0} flag' \
  "$FEATURE_DIR/spec.md")
if [ -z "$HEADLINE_BODY" ] && [ -z "$DETAIL_BODY" ]; then
  COMBINED_BODY=$(awk '/^### Headline \+ Detail \(combined\)/{flag=1; next} /^###|^## /{flag=0} flag' \
    "$FEATURE_DIR/spec.md")
  HEADLINE_BODY="$COMBINED_BODY"
  DETAIL_BODY="$COMBINED_BODY"
fi

# Extract distinctive nouns from each blurb (same heuristic as Phase 5.3.5).
STOPWORDS='with|this|that|than|from|when|will|have|here|each|just|only|some|then|they|been|were|into|over|same|more|like|much|where|after|other|user|users|page|view|flow|able|make|made|need|want|allow|shows|adds|added|fixes|fixed|onto|down|both|along|your|saved|sets|see|set|via|now|out|but|and|the|for|its|any|all|new|can'
nouns() {
  { echo "$1" | grep -oE '\b[A-Z][a-zA-Z]+\b' || true
    echo "$1" | grep -oE '\b[a-z]{4,}\b' | grep -vwE "$STOPWORDS" || true
  } | tr '[:upper:]' '[:lower:]' | sort -u
}
HEADLINE_NOUNS=$(nouns "$HEADLINE_BODY")
DETAIL_NOUNS=$(nouns "$DETAIL_BODY")

GATE_B_FINDINGS=""
# (a) Unevidenced claims — Detail nouns absent from the diff.
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  if ! git diff --name-only "$DIFF_RANGE" 2>/dev/null | grep -qiF "$tok" \
     && ! git diff "$DIFF_RANGE" -- 2>/dev/null | grep -qiF "$tok"; then
    GATE_B_FINDINGS+="unevidenced-claim: $tok"$'\n'
    GATE_B_FINDINGS+="  reason: no diff evidence (Detail mentions; diff does not)"$'\n'
  fi
done <<< "$DETAIL_NOUNS"
# (b) Audience-shape mismatch — Detail vs Headline noun-set delta.
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  GATE_B_FINDINGS+="headline-missing: $tok"$'\n'
  GATE_B_FINDINGS+="  reason: audience-shape mismatch — Headline may be missing this affordance"$'\n'
done < <(comm -23 <(echo "$DETAIL_NOUNS") <(echo "$HEADLINE_NOUNS") | head -5)
while IFS= read -r tok; do
  [ -z "$tok" ] && continue
  GATE_B_FINDINGS+="detail-overclaim: $tok"$'\n'
  GATE_B_FINDINGS+="  reason: audience-shape mismatch — Detail may be missing the eng context"$'\n'
done < <(comm -23 <(echo "$HEADLINE_NOUNS") <(echo "$DETAIL_NOUNS") | head -5)
```

Gate B is **warn-not-block** — the noun-phrase grep is fuzzy, and the Headline/Detail audience-shape rule has a legitimate asymmetry (Headline is intentionally lower-fidelity than Detail). False positives are likely; the operator at Gate A decides whether each finding is real. The heuristic is intentionally simple (sort-uniq noun comparison + grep against the diff); the LLM running Gate A can read both blurbs against the actual diff with full context, so Gate B's job is to *surface candidate concerns*, not adjudicate them.

**Gate A — autonomous claim-vs-diff review (mirrors Part C's factual-checkbox closure):**

After Gate B produces findings, read both blurbs against the diff +
`$GATE_B_FINDINGS` and classify the result into one of three outcomes —
no operator prompt unless a genuine claim-vs-diff mismatch's correct
wording is a product-judgment call the diff can't settle. The
orchestrator already has every input it needs: the spec blurbs, the full
diff, and Gate B's automated cross-check.

```bash
# Pull spec.md's Product update section verbatim.
SPEC_HEADLINE=$(awk '/^### Headline \(user-facing\)/,/^###|^## /' "$FEATURE_DIR/spec.md" | sed '1d;$d')
SPEC_DETAIL=$(awk '/^### Detail \(team-facing\)/,/^###|^## /' "$FEATURE_DIR/spec.md" | sed '1d;$d')
# Collapsed case:
if [ -z "$SPEC_HEADLINE" ] && [ -z "$SPEC_DETAIL" ]; then
  SPEC_COMBINED=$(awk '/^### Headline \+ Detail \(combined\)/,/^###|^## /' "$FEATURE_DIR/spec.md" | sed '1d;$d')
  SPEC_HEADLINE="$SPEC_COMBINED"
  SPEC_DETAIL="$SPEC_COMBINED"
fi

# Build the diff summary — one line per substantive file changed since
# /ship's first commit, with a 3-line context window of the new code per
# file (so the review can answer "did the blurb name this?" without
# clicking into the PR).
git diff --name-only "$DIFF_RANGE" | grep -vE '^(specs/|BUILD-LOG\.md$|PLAN\.md$|kit/version|.*CHANGELOG\.md$)' > /tmp/product-update-diff-files.txt
```

Read both blurbs against the diff summary (`/tmp/product-update-diff-files.txt`
+ the actual `git diff "$DIFF_RANGE"`) and `$GATE_B_FINDINGS`, then classify:

| Outcome | Trigger | Action |
|---------|---------|--------|
| **Accurate** | Both blurbs match the diff; Gate B findings (if any) are false positives the diff disproves. | Log a one-line attestation in `review.md § Product update verification`: `Gate A reviewed at <SHA>: both blurbs match the diff.` Continue. No operator prompt. |
| **Edit-and-self-resolve** | A fixable drift — stale wording, a missing claim the diff supports, or an audience-shape leak Gate B flagged that the diff confirms. | Rewrite the named blurb in `$FEATURE_DIR/spec.md § Product update`, re-splice the PR body's `## Product update` section with the new text, commit on the feature branch (`chore(<feature>): refine product blurb post-Gate-A`), then re-run Gate B once over the edited blurbs. Log the edit in `review.md § Product update verification`. After two loops, accept and continue — Gate A is for accuracy, not infinite polish. |
| **Escalate** | A genuine claim-vs-diff mismatch whose correct wording is a product-judgment call the diff can't settle (e.g. the diff supports two equally-defensible framings and which is "right" depends on product intent the diff doesn't encode). | `AskUserQuestion` with both blurbs, the diff summary, and the specific mismatch. Apply the operator's wording via the Edit-and-self-resolve path, then log. This is the ONLY operator prompt in Gate A. |

Both blurbs are the single source-of-truth for BUILD-LOG + Phase 7 +
`/ak-go-live` Step 6; any Edit-and-self-resolve or Escalate rewrite MUST
be saved back to `spec.md § Product update` so downstream surfaces stay
in sync.

Why autonomous: Phase 6's other Parts (A/B/C) auto-attest factual gates
and halt only on a real problem; Part C's factual-checkbox closure is the
direct precedent — the orchestrator verifies what it can verify and
surfaces only the genuine judgment call. Gate A has the same shape: the
spec blurbs + full diff + Gate B cross-check are enough to confirm an
accurate blurb or self-resolve a fixable drift. Surfacing an accurate
blurb to the operator just to rubber-stamp it wastes their attention;
the Escalate rung preserves the operator's eyes for the one case the diff
can't settle.

If `$EVIDENCE_MISSING` is empty (Parts A-C clean) **and** Gate A resolved
(Accurate, or self-resolved/escalated-and-applied) → Phase 6's verification
sweeps are complete. If any halt fires, Phase 6 does not exit clean.

**Part D exit marker**: `echo "verified at $(git rev-parse HEAD)" > /tmp/phase6-partD.done`

### Phase 6 exit checklist

Before leaving Phase 6, verify that all four verification sweeps (Parts
A-D) completed. Each Part wrote its marker file as its final action (see
§ Phase exit artifact registry rows `6-A` through `6-D`). Phase 6 markers
use `/tmp/` — they're ephemeral because Parts re-run from scratch on
resume; the PR body is re-fetched, evidence is re-checked. Stale `/tmp/`
markers from a prior session are gone.

```bash
P6_MISSING=""
for part in A B C D; do
  if [ ! -f "/tmp/phase6-part${part}.done" ]; then
    P6_MISSING+="  Part $part\n"
  fi
done

if [ -n "$P6_MISSING" ]; then
  echo "✖ Phase 6 exit checklist: verification sweep(s) did not complete."
  echo -e "$P6_MISSING"
  echo ""
  echo "  Re-run the missing Part(s) — the PR body may contain stale claims."
  exit 1
fi

echo "✓ Phase 6 exit checklist: all Parts (A-D) verified. The PR body is trustworthy."
```

## Phase 7: Notify

### 7.1: Detect diff type (runtime vs docs-only)

The "next step" handoff depends on whether this PR has runtime changes that need a deploy. Runtime paths trigger `/ak-go-live`; docs-only diffs don't — and leaving the hint as "run `/ak-go-live`" on a docs-only PR leads to unnecessary canary runs and user confusion about what's shipping.

```bash
BASE=$(gh pr view "$PR" --json baseRefName --jq .baseRefName)
DIFF_FILES=$(git diff --name-only "origin/${BASE}...HEAD")

# Runtime paths — touching any of these means the deploy pipeline needs to run:
#   apps/**        — Next.js / web app code
#   packages/**    — workspace packages (core, ui)
#   supabase/migrations/**  — DB schema
#   supabase/functions/**   — edge functions
RUNTIME_REGEX='^(apps/|packages/|supabase/migrations/|supabase/functions/)'

if echo "$DIFF_FILES" | grep -qE "$RUNTIME_REGEX"; then
  NEXT_STEP_LINE="Review the diff, check the preview URL, then run \`/ak-go-live\` to deploy + canary-check."
  TERMINAL_HINT="Next step after you merge: run /ak-go-live to deploy + canary-check."
else
  # Docs-only diff (docs/, README.md, BUILD-LOG.md, kit/, .github/, specs/**/*.md, CHANGELOG.md, etc.)
  NEXT_STEP_LINE="Review the diff and merge. No runtime changes in this PR — \`/ak-go-live\` not needed."
  TERMINAL_HINT="/ak-go-live not needed — no runtime changes."
fi
```

The branch is explicit rather than silent: on docs-only PRs, the user should SEE "no deploy needed" rather than wonder whether the pipeline forgot to suggest one.

### 7.2: Print the handoff to the terminal

No "Ready for review" comment — the PR being open IS the notification.
Adding a comment just clutters the PR timeline with devshop process
noise. The reviewer sees the PR in their GitHub notifications and reads
the body (Product update + Engineering details + Test plan).

Phase 7 prints the handoff to the terminal only:

After the comment posts, echo the handoff to the session's stdout so the user sees the next step in Claude Code without having to read the PR on GitHub first:

```bash
echo ""
echo "→ $TERMINAL_HINT"
```

## PR body conventions

These rules are referenced from Phase 4 (creation), Phase 5.3 (CI-green update), and Phase 6 (final sweep). Apply them every time `gh pr edit` is called on a PR body in this pipeline.

### Image embeds — private-repo safe

Most devshop projects are private. Markdown image-embed URLs must render for an authenticated viewer without leaking tokens or 404'ing:

| URL form | Use? | Why |
|-----|-----|-----|
| `specs/auth/hero/signin.png` (repo-relative) | ❌ | PR bodies don't resolve repo-relative paths like README.md does. |
| `https://raw.githubusercontent.com/owner/repo/branch/path` | ❌ for private repos | Requires an auth token the body can't embed; silently 404s for viewers. |
| `https://github.com/owner/repo/raw/branch/path` | ✅ | GitHub resolves with the viewer's own auth; works in both public and private repos. Branch names with slashes (`feature/auth`) are handled correctly. |
| Drag-drop upload in the PR UI → `https://github.com/user-attachments/assets/<uuid>` | ✅ | Manual-only; fine when the image isn't in the repo. |

Generate the safe URL programmatically:

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BRANCH=$(git branch --show-current)
REL="specs/${FEATURE}/hero/signin.png"   # relative to repo root
echo "![signin](https://github.com/${OWNER_REPO}/raw/${BRANCH}/${REL})"
```

When reviewing an existing PR body, `grep -E '!\[.*\]\(' /tmp/pr-body.md` catches every embed to check.

### Checkbox semantics + timing

Every `- [ ]` / `- [x]` in the Test plan has a specific moment at which it flips:

| Checkbox (typical wording) | Flips to `[x]` when | Where in /ak-build |
|---|---|---|
| CI green | `gh run watch` returned `success` + conclusion cross-check | Phase 5.3 |
| Vercel / Netlify / Fly preview deployed | Platform bot comment reports `Ready` / equivalent | Phase 5.3 — include preview URL |
| Manual-review callouts (visual, QA, post-deploy) | — | **Never** — human reviewer only |

Two kinds of mistakes to avoid:

1. Leaving a verified gate as `[ ]` — reviewer sees "not green" on something that actually is; reads as partial failure.
2. Marking a reviewer-only item `[x]` — pre-commits to a human verification you didn't do; misleading.

Phase 6's final sweep reconciles both sides.

### What belongs in "Manual review"

PR-body items under a `### Manual review` (or "Live QA" / "Reviewer-only") heading must be **genuinely judgmental** — items the automation cannot answer. Canonical set:

- Spec / intent match — does the PR actually do what was specified?
- Visual / design audit — hierarchy, spacing, typography, dark-mode parity
- Live QA walkthrough — does the user flow feel right end-to-end?
- Post-deploy metrics — p95 latency, error rate, conversion deltas (only measurable after merge)

Anything resolvable by `cat <file>` / `grep <symbol>` / fixed-shape comparison is **NOT** a manual-review item — it's factual and pre-ship gates already attested it. If you draft a body with a factual item under Manual review:

1. **Drop it** — the pre-ship gate already covered it; the gate's entry in `review.md` carries the attestation.
2. **Or self-attest** with `[x]` + the file:line that grounds the claim inline in the Test plan. Example: `[x] Migration idempotent guard correct (supabase/migrations/013_realtime_publication.sql:12-20)`.

Phase 6's Part C sweep auto-attests factual items the body author missed, so the rule has a structural backstop — but draft them right at Phase 4 to save the round-trip.

Codified from lalista PR 27 (2026-04-27): the PR shipped with 4 Manual-review items, three of which were factually verifiable (idempotent guard correct, JSDoc cites coverage, CLAUDE.md gotcha reads correctly). Reviewers feel obligated to re-verify each `[ ]`; restating factually-attested items dilutes the one item that genuinely needed a human (spec/intent match).

### Out-of-band deploy items

Some surfaces don't ship with the PR merge. The front-end gets auto-deployed (Vercel/Netlify on merge to main); other artifacts need a separate command after merge or they silently lag behind. The most common offender for Supabase-backed projects is `supabase/functions/**` — the front-end calls the new contract, the back-end is still the old one, the user hits stale behavior with no clear error.

Phase 4 must inspect the diff and, if it touches a known out-of-band-deploy path, add the deploy step to the test plan checklist explicitly so `/ak-go-live` doesn't skip it. Detection patterns to handle:

| Diff path matches | Add to test plan |
|---|---|
| `supabase/functions/**` | `- [ ] After merge: \`supabase functions deploy <name>\` for each touched function — front-end ships to prod calling unchanged back-end otherwise (stale behavior + analytics misattribution).` |
| `supabase/migrations/**` | `- [ ] After merge: \`supabase db push\` (or hosted dashboard apply) — schema needed by the new code.` |
| `terraform/**` / `*.tf` | `- [ ] After merge: \`terraform apply\` — infra change required for the new code.` |
| `k8s/**` / `*.yaml` under deploy paths | `- [ ] After merge: \`kubectl apply -f <path>\` — k8s manifest update required.` |

Implementation sketch for Phase 4:

```bash
DIFF_FILES=$(git diff --name-only "origin/${BASE}...HEAD")
DEPLOY_ITEMS=""
if echo "$DIFF_FILES" | grep -qE '^supabase/functions/'; then
  FNS=$(echo "$DIFF_FILES" | grep -oE '^supabase/functions/[^/]+' | sort -u | sed 's|supabase/functions/||')
  for fn in $FNS; do
    DEPLOY_ITEMS+="- [ ] After merge: \`supabase functions deploy ${fn}\` — function code changed, no auto-deploy.\n"
  done
fi
# ... add other patterns ...
# Splice $DEPLOY_ITEMS into the PR body's ## Test plan section.
```

Add the items inside the existing `## Test plan` block, ideally above the manual-review callouts (visual audit, live QA walkthrough), so reviewers see them adjacent to the CI checkboxes rather than at the bottom.

The handoff in Phase 7 should surface these in the terminal hint. `/ak-go-live` does not run these for you; the user (or the slow-job CI from a future PR) does.

If the project's spec template doesn't already mention this convention, the next PR that touches an out-of-band-deploy path is a good time to add it to `CLAUDE.md § Gotchas` — but Phase 4 should not block on whether the convention is documented; it should add the test-plan items unconditionally based on diff detection.

### Edit flow

```bash
gh pr view "$PR" --json body --jq .body > /tmp/pr-body.md
# edit /tmp/pr-body.md per the rules above
gh pr edit "$PR" --body-file /tmp/pr-body.md
```

Prefer `--body-file` over `--body "<string>"`. The file path keeps long bodies readable in the edit round-trip and avoids shell-escape gotchas on multi-line markdown.

## Escalation chain

1. **Self-fix**: stuck protocol (/ak-implement), test checkpoints (/ak-pre-ship), CI fix loop (/ak-build)
2. **AskUserQuestion**: if user is present in the session (blocking — waits for answer)
3. **PR comment @mention**: if user may have walked away (async — GitHub notification)

Rule: always try self-fix first. Escalate through AskUserQuestion if the session is interactive.
Fall back to PR comment if unsure whether user is watching.

## Context pressure

The full pipeline consumes significant context. Mitigation:
- Heavy work runs in subagents — main context stays clean
- Critical state survives in files: `specs/<name>/spec.md`, `specs/<name>/tasks.md`,
  `specs/<name>/review.md`, git commits, PR on GitHub
- On resume, Step 0 reads file state rather than relying on conversation history
- If context is exhausted mid-pipeline, the session ends — user starts a new session,
  says `/ak-build`, and Step 0 resumes from where it left off
