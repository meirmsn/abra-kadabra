---
name: ak-build
version: 1.7.0
description: |
  Autonomous build pipeline: preview → spec → implement → quality gates → ship → CI watch → notify.
  Phase 0 produces a 3-section pre-flight preview (decisions / scope / tracker) and
  persists user-approved decisions as a `specs/<feature>/spec.md` skeleton (provenance
  + Sources + Decisions) — one file, no parallel artifact. Phase 1's spec agent
  preserves the Decisions section verbatim and expands the rest. On crash-restart,
  a spec.md lacking `## Task order` signals Phase 0 finished but Phase 1 didn't.
  The live TaskCreate tracker mirrors the preview's hierarchy as phases run.
  Delegates heavy phases to subagents to keep main context clean.
  Resumable — detects where it left off if session is interrupted.
  If /ak-pre-ship reports any `blocked` gate (tooling missing), refuses to advance to
  /ship and surfaces the preflight fix recipe to the user.
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

After this completes, the user has a PR ready for review with all quality gates passed,
CI green, and an audit trail comment. The user's only action: review and say `/ak-go-live`.

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
  ├─ CI watch (main ctx)     → fix-loop, bookkeeping, re-watch (Phase 5.1–5.7)
  ├─ Agent → /ak-check-docs-and-tests → re-audit over post-pre-ship range
  │                             (Phase 5.8 — appends `## Audit 2` to
  │                             specs/<name>/review.md; halts on high-severity
  │                             findings)
  ├─ Agent → visual refresh  → re-runs /ak-pre-ship Gates 4 + 13 over HEAD
  │                             (Phase 5.9 — overwrites stale screenshots/
  │                             hero shots; freshness-only, no halt path)
  └─ Phase 6 (main ctx)      → reads review.md (Gate N + Audit N sections) +
                                tasks.md for audit comment
```

## Step 0: Determine feature and resume state

### Derive feature name and ensure branch
```bash
BRANCH=$(git branch --show-current)
```

If on `main`, find or create the right branch:

1. **Check for in-progress work** — look for open PRs or local feature/fix branches:
   ```bash
   # Open PRs from feature/fix branches
   gh pr list --state open --json headRefName --jq '.[].headRefName' 2>/dev/null
   # Local feature/fix branches
   git branch --list 'feature/*' 'fix/*'
   ```
2. **If existing branch found** → ask the user which one to resume, switch to it:
   ```bash
   git checkout feature/<name>
   ```
3. **If no existing branch** → determine the feature name from `PLAN.md § Planned`
   (top-ranked row) or from the gstack plan artifacts under `.gstack/projects/<slug>/`.
   Pick the branch prefix: `feature/` for new functionality, `fix/` for bug fixes.
   Create and switch:
   ```bash
   git checkout -b feature/<name>   # or fix/<name>
   ```

Re-read the branch after switching:
```bash
BRANCH=$(git branch --show-current)
FEATURE=$(echo "$BRANCH" | sed 's|^feature/||;s|^feat/||;s|^fix/||')
FEATURE_DIR="specs/$FEATURE"
```

If already on a `feature/*` or `fix/*` branch, skip straight to the resume check.

### Resume check

Detect where a previous run left off. Evaluate top-to-bottom; the first match wins:

1. **Open PR for this branch?** → skip to Phase 5 (CI watch)
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
2. **`$FEATURE_DIR/tasks.md` exists with all tasks `done`?** → skip to Phase 3 (pre-ship)
3. **`$FEATURE_DIR/tasks.md` exists with some tasks `done`?** → skip to Phase 2 (implement resumes internally)
4. **`$FEATURE_DIR/spec.md` exists and contains `## Task order`?** → full spec written by Phase 1 → skip to Phase 2 (implement)
5. **`$FEATURE_DIR/spec.md` exists but lacks `## Task order`?** → Phase 0 wrote the skeleton (provenance + Decisions only); Phase 1 hasn't completed → re-run Phase 1. Spec agent reads the existing file, preserves its Decisions section verbatim, and expands into the full spec. Do NOT re-prompt the user.
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
Phase 0 never writes it; Phase 1 always does.

## Phase 0: Preview + decisions checkpoint

Before spawning any subagent, produce a pre-flight preview so the user can flag
scope or decision issues before token-heavy work begins. Catching a mis-shaped
build here is orders of magnitude cheaper than discovering it mid-Phase 2 (which
has already burned context writing code around the wrong decision).

Skip Phase 0 entirely when the resume check lands at step 5 — the `spec.md`
skeleton already exists from a prior run, meaning the user already approved
the decisions it contains.

### 0.1: Read sources

Read enough context to produce the preview accurately. Typical inputs:

- `PRODUCT-ROADMAP.md` section for this feature (e.g., `§ v0 § 1e`) — primary
  scope and the enumerated `/ak-spec`-time decisions.
- `PLAN.md` row Notes for this feature — scope summary and source pointer.
- `DESIGN.md` at repo root, if the feature touches UI.
- `.gstack/projects/<slug>/*-design-*.md` (newest by mtime), if present.
- `.gstack/projects/<slug>/*-test-plan-*.md` (newest by mtime), if present.
- Prior PR's spec (`specs/<prior-feature>/spec.md`) as a style/structure reference.

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

**3. Tracker (the live view you'll see come alive)** — hierarchical, mirroring
exactly what Phase 0.4 will instantiate via `TaskCreate`:

```
Phase 1: Spec
Phase 2: Implement
  - Task 1: <first implementation task>
  - Task 2: <second>
  - …
  - Task N: <last>
Phase 3: Pre-ship
Phase 4: Ship
Phase 5: CI watch + BUILD-LOG
Phase 6: Audit comment
Phase 7: Notify
```

Derive the Phase 2 sub-tasks from the roadmap's numbered subsections + any
obvious dependency-order tasks (e.g., migrations first, E2E last). This is a
rough cut; Phase 1's spec will refine it. Usually the spec adds 1–2 sub-steps
but doesn't change the overall shape.

End the preview with: **"Proceed? or flip any decision / trim scope / add task?"**

Wait for the user's response. Do NOT proceed to 0.3 without explicit approval.

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
feature one-liner + fully-populated Decisions section. Phase 1's spec agent
reads this same file, preserves the Decisions section verbatim, and expands
everything below into the full spec. One file, one source of truth, no
second artifact to keep in sync.

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
     rollout / rollback. The Decisions section above stays verbatim. -->
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
one task per row, with Phase 2's sub-rows indented (or prefixed "Phase 2 /
Task N:" if the harness's task list is flat). Mark Phase 1 `in_progress` the
moment you spawn its subagent; mark `completed` when it returns. Expand /
correct Phase 2 sub-rows against `spec.md § Task order` once Phase 1 finishes
— if the spec's tasks shifted from the preview, update the tracker rows to
match. Add new rows dynamically for:

- Phase 3 findings as they're surfaced (e.g., "CSP fix", "dead ternary fix").
- Ad-hoc user corrections mid-flight (e.g., "D7 flip" added after the user
  objects to a Phase 1 decision).

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

## Phase 3: Pre-ship (quality gates)

Launch **Agent** with prompt:
> Run /devshop:pre-ship for feature "$FEATURE".
> Read tasks and decisions from $FEATURE_DIR/tasks.md.
> Run all quality gates (1-11) with test:unit checkpoints after code-changing gates.
> Write gate results to $FEATURE_DIR/review.md.
> Return these counts explicitly (not buried in prose):
> `passed`, `findings_pending`, `n_a`, `blocked`.
> If `blocked > 0`, include the preflight fix recipe verbatim in the return.
>
> **Do NOT pre-classify gates as `n/a` in your prompt or reasoning.** Gate
> disposition belongs to the gate runner per its SKILL.md, not to this
> orchestrator. If you find yourself thinking "this gate doesn't apply
> because <reason>," let the gate runner make that call and emit the
> correct outcome shape — `blocked (n/a per scope: <reason>)` for the
> LLM-mediated gates (6 `/review`, 7 `/cso`, 8 `/design-review`, 9 `/qa`),
> or `n/a (<reason>)` for non-LLM-mediated gates that legitimately
> support it. The orchestrator's job is to run the gauntlet; the gate
> runner's job is to decide what each gate's outcome should be.
> Pre-classifying in this prompt is what shipped lalista PR #65 without
> `/qa` evidence — don't repeat it.

`/ak-pre-ship` does NOT ship or create a PR. If findings require fixes, the agent
handles them within its context.

### Phase 3 → Phase 4 handoff: refuse to advance on blocked, findings, or LLM-mediated n/a

After the agent returns, parse the counts AND grep `review.md` for the
LLM-mediated-gate `n/a` violation. The only acceptable state to advance to
`/ship` is: `findings_pending == 0` AND `blocked == 0` AND no LLM-mediated
gate marked `n/a`.

**Rung 1 — `findings_pending > 0`**: pause and escalate to the user (findings
need fixes).

**Rung 2 — `blocked > 0`**: **do NOT advance to Phase 4**. The PR is not
shippable until the tooling gap is closed. Take these actions:

  1. Emit a clear message to the user with the preflight fix recipe from the agent's return.
  2. Post a PR comment (if a PR exists for this branch already — unusual in Phase 3,
     but possible on resume) describing which gates are blocked and why.
  3. **Require explicit operator acknowledgement before continuing past blocked.**
     Do not advance autonomously. Pause the pipeline and surface the halt
     reason verbatim. Continuing past `blocked > 0` requires the operator to
     re-invoke `/ak-build` with either (a) the tooling gap resolved (Step 0's
     resume check re-runs Phase 3 cleanly), or (b) an explicit override that
     names the gate, the reason, and a follow-up tracker entry — never a
     silent autonomous continue. Home-os PR #15 (2026-05-14) shipped past
     `blocked: 1` because the halt happened but the override was silent;
     reviewers received placeholder hero shots from the sign-in flow
     instead of the actual feature.
  4. Do NOT treat `blocked` as `n/a`. A cheerful advance past blocked gates
     is the exact failure mode this workflow exists to prevent.

**Rung 3 — LLM-mediated gate marked `n/a`** (codified from lalista PR #65,
2026-05-12): even when the agent returns `findings_pending == 0` and
`blocked == 0`, grep `review.md` for the four LLM-mediated gates emitting
the forbidden `n/a` outcome:

```bash
FORBIDDEN_NA=$(awk '
  /^## Gate [0-9]+: \/(review|cso|design-review|qa)($|[^a-z-])/ { in_section=1; gate=$0; next }
  in_section && /^## Gate / { in_section=0 }
  in_section && /^- Result: *n\/a/ { print gate }
  in_section && /^\*?\*?Result:\*?\*? *n\/a/ { print gate }
' "$FEATURE_DIR/review.md")

if [ -n "$FORBIDDEN_NA" ]; then
  echo "✖ Phase 3 → 4 halt: LLM-mediated gate(s) emitted n/a (forbidden per"
  echo "  ak-pre-ship § Outcome semantics § n/a is not legal for LLM-mediated gates):"
  echo "$FORBIDDEN_NA" | sed 's/^/    /'
  echo ""
  echo "  Scope exemptions must use 'blocked (n/a per scope: <reason>)' so the"
  echo "  dismissalLog adversarial reviewer judges the rationale. Re-run"
  echo "  /ak-pre-ship after the gate runner emits the correct outcome shape,"
  echo "  or — if the gate runner pre-classified per orchestrator instruction"
  echo "  — re-examine the Phase 3 prompt for pre-classification (which is"
  echo "  forbidden — see § Phase 3: Pre-ship)."
  exit 1
fi
```

The grep is anchored on the LLM-mediated gate names (`review|cso|design-review|qa`)
so legitimate `n/a` outcomes from non-LLM-mediated gates (Gate 3 responsive,
Gate 10 benchmark, Gate 1 docs-check) don't false-positive.

Once the user has resolved the violation, re-run `/ak-build` — Step 0's resume
check will pick up at Phase 3 and rerun pre-ship from the start.

## Phase 4: Ship

### 4.1: Pre-compose PR title + Summary body

Before invoking `/ship`, compose the PR title and the `## Summary` section
of the PR body in this skill — `/ak-build` owns the convention and has
`kit/docs/guide/conventions.md § Commit + PR Text Style` reliably
available; `/ship` is upstream-owned (gstack) and would re-compose to
its own taste otherwise. The split:

- **PR title** — one line, ≤ 72 chars, verb-led where natural,
  describes the **observable change** (no internal jargon like "polish",
  "soak findings", "Phase N"). Noun-lists are fine for multi-unit
  features (`feat: invite link + member mgmt + audit feed`).
- **`## Summary` body** — one-sentence TL;DR followed by 3-7 bullets.
  Bullets first; prose only when a non-obvious decision needs framing
  (1-2 sentences max). Enumerate from `git log <base>..HEAD --oneline`,
  exclude the VERSION/CHANGELOG bookkeeping commit, then every remaining
  substantive commit must appear in at least one bullet. Group into
  themed sub-sections (`**Performance**`, `**Infrastructure**`, etc.)
  when there are 2+ themes.

Compose both, then stash them at `/tmp/ship-title.txt` and
`/tmp/ship-summary.md` so the next step can pass them in by path.

### 4.2: Invoke `/ship` with the pre-composed directives

Launch **Agent** with prompt:
> Run /ship to push the branch and create a PR.
> /ship will run tests, code review, bump VERSION, push, create PR,
> and auto-invoke /document-release.
>
> Use the pre-composed title + Summary from /ak-build — do NOT
> re-compose. The title is at /tmp/ship-title.txt (one line). The
> Summary body is at /tmp/ship-summary.md (use it verbatim as the
> `## Summary` section of the PR body; /ship still fills in
> `## Test plan` and the other sections per its template). If /ship
> composes its own title/Summary first, overwrite via
> `gh pr edit "$PR" --title "$(cat /tmp/ship-title.txt)"` and replace
> the `## Summary` section of the PR body with /tmp/ship-summary.md
> before returning.
>
> Return: PR number and URL.

This shape moves composition into the devshop-owned skill so the
convention fires reliably regardless of `gstack/ship/SKILL.md` state;
`/ship` becomes a pure executor (push + bump + PR creation) for this
step. Codified after a `gstack` sync clobbered local edits to
`gstack/ship/SKILL.md` (2026-05-13) and exposed the wrong-side-of-the-
boundary placement.

### 4.3: Verify

After `/ship` completes, a PR exists on GitHub. Verify the PR title and
description match what 4.1 composed and what `kit/docs/guide/conventions.md
§ Commit + PR Text Style` requires. If the body's `## Summary` section
doesn't match `/tmp/ship-summary.md`, rewrite:

```bash
gh pr view "$PR" --json body --jq .body > /tmp/pr-body.md
# splice /tmp/ship-summary.md into the ## Summary section of /tmp/pr-body.md
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

Once the CI run completes successfully, mark the relevant `## Test plan` /
`### CI gates` checkboxes as `[x]` with the short attestation inline
(`green on <commit-sha>`, deploy URL + timestamp, etc.). Also check for
Vercel / Netlify / Fly bot comments on the PR — if a preview is deployed,
mark the "preview deploys successfully" checkbox with the URL.

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
```

If `$DRIFT_SIGNALS` is empty → continue. The body's narrative still matches
what's in the diff.

If `$DRIFT_SIGNALS` is non-empty → **read the current PR body** and judge
whether the signals invalidate any specific claim:

- Summary section names the bug + fix. New runtime / test files often mean
  there's a "scope expansion" angle the Summary should mention.
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
at audit-comment time and asked "isn't the PR description stale?" —
which is exactly the question this check exists to answer pre-emptively.

### 5.4: On CI failure → fix loop

The loop is a 3-attempt decision tree that escalates observability as blind
inference becomes less likely to work. Attempt 1 guesses from the log (cheap —
often enough for straightforward failures); attempt 2+ pulls run artifacts
BEFORE guessing (evidence-based); attempt 3 escalates to the user (structural).
This bounds the blind-loop cost to one round and forces evidence on the second
— the "never more than ~2 blind iterations" rail codified from the 2026-04-24
lalista slow-job stabilization incident, where 4 blind retries against a
Playwright failure burned ~30 minutes because the trace artifact was
unreachable from the devcontainer.

```
FIX_ATTEMPTS=0
MAX_ATTEMPTS=3

while CI is failing and FIX_ATTEMPTS < MAX_ATTEMPTS:
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

  10. FIX_ATTEMPTS += 1
  11. Go to 5.2 (watch CI again)
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

### 5.6: Finalize PLAN.md + BUILD-LOG.md on the feature branch

Runs on CI green (after 5.3), before advancing to Phase 5.7. Closes out this feature's history **on the feature branch** so it ships as part of this PR — not as a separate post-merge cleanup PR.

**Why here, not post-merge**: the prior design landed a second `chore: close <feature> in BUILD-LOG` PR on main after merge. That's an extra PR for pure history, and fails on projects with a main-is-PR-only guard that blocks Claude from committing to main directly. Writing on the feature branch eliminates both problems — the PR carries its own history entry, and merge-to-main brings it along.

**Inputs**:

- `$FEATURE` — feature name (from Phase 0 / Phase 1)
- `$PR` — PR number (from 5.1)
- `$FEATURE_DIR` — `specs/$FEATURE/`
- `PLAN.md` at repo root (Phase 1's `/ak-spec` flipped the Planned row into `## Active`)
- `BUILD-LOG.md` at repo root (append-only ship log)

**Steps**:

1. If `BUILD-LOG.md` doesn't exist, copy from `/devshop/template/BUILD-LOG.md`. If `PLAN.md` doesn't exist, copy from `/devshop/template/PLAN.md`.

2. **Remove the Active row from `PLAN.md`**: find the row in `## Active` whose Branch column matches `$FEATURE_BRANCH`, delete it. If `## Active` is now empty (no remaining rows), restore the placeholder `_No work in progress._` under the `## Active` heading.

3. **Append the ship entry to `BUILD-LOG.md`**, most-recent-first (top of the entry list, after the intro paragraph and the `_No builds yet._` placeholder if present — remove the placeholder on first real entry):

   ```markdown
   ### <FEATURE> (YYYY-MM-DD)

   - **Branch**: `<FEATURE_BRANCH>` (merging via #<PR>)
   - **PR**: [#<PR>](https://github.com/<owner>/<repo>/pull/<PR>)
   - **Spec**: `specs/<FEATURE>/spec.md`
   - **Summary**: <1-line summary from $FEATURE_DIR/spec.md>
   - **Commits**: <N> (<brief list if ≤ 5, else "N atomic commits per /ak-implement">)
   - **Quality gates**: <summary from audit — "all passed" / "N findings fixed during pre-ship" / etc>
   ```

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
   git push
   ```

   If step 4 retired a tracker entry, prefer a separate commit on the feature branch with message `chore(roadmap): close <entry-name> (shipped via PR #<PR>)` — keeps the bookkeeping atomic.

6. Re-fetch the PR body. If it carries a commit count that's now stale (e.g., `Commits: N`), update via `gh pr edit "$PR" --body-file`.

**Idempotence**: if 5.6 has already run for this feature (no Active row for `$FEATURE_BRANCH` in `PLAN.md` AND a `BUILD-LOG.md` entry referencing `$PR` exists, AND no PR-closed tracker entry remains in any roadmap), skip — don't duplicate.

**Fallback for CI-timeout**: if `$PR` is not yet set (5.1 hasn't run — edge case where Phase 5 was entered out-of-band), 5.6 is a no-op; it will fire next time CI is green with a known PR.

### 5.7: Re-watch CI after the 5.6 bookkeeping push

The 5.6 commit triggers a fresh CI run on the latest SHA. Even though
the diff is docs-only (PLAN.md + BUILD-LOG.md), the new run can fail on
environmental flakes (runner-image variance, browser-cache hits that
skip system-deps install, CDN IP rotation, etc.) that the prior run got
lucky on. Phase 6's audit comment claims "CI is green" — that claim
must be true for the SHA the comment is being posted against, not for
an earlier SHA whose CI passed.

**Codified from**: lalista PR 18 audit-trail correction (2026-04-25) —
audit + ready-for-review comments were posted while the bookkeeping
commit's CI was still `in_progress`; that run failed on a WebKit
system-libs flake (`libwoff2dec.so.1.0.2` not on this runner image),
forcing a public retraction comment. Phase 5.6's push has the same
shape as any other push and deserves the same watch-then-advance
discipline; collapsing the watch was a load-bearing oversight, not a
shortcut.

**Steps**:

1. Re-read the latest run on the feature branch. The 5.6 push triggers
   a new run; that run is now the canonical CI signal:

   ```bash
   RUN_ID=$(gh run list --branch "$BRANCH" --limit 1 \
     --json databaseId --jq '.[0].databaseId')
   gh run watch "$RUN_ID" --exit-status

   # Same conclusion cross-check as 5.2 — see that section for the
   # codification + rationale.
   CONCLUSION=$(gh run view "$RUN_ID" --json conclusion --jq .conclusion)
   if [ "$CONCLUSION" != "success" ]; then
     echo "✖ Re-watched run $RUN_ID conclusion=$CONCLUSION; route to 5.4"
     exit 1
   fi
   ```

   This blocks until the bookkeeping run completes. Same 30-minute cap
   as 5.2.

2. **If green**: re-run 5.3 to repoint the PR body's CI checkboxes at
   this latest run (the prior CI attestation now references a stale
   SHA — leaving it points reviewers at an older run that doesn't
   reflect the latest commit). Then advance to Phase 6.

3. **If red**: re-enter Phase 5.4's fix loop. The bookkeeping commit's
   failure is a CI failure like any other; the same observability-tiered
   cadence applies (attempt #1 from logs; attempt #2+ pulls artifacts).
   Do NOT advance to Phase 6 with a red latest run — the audit and
   ready-for-review comments are public artifacts, and overclaiming
   ("CI is green") in them costs trust.

**Idempotence**: 5.7 fires once per 5.6 push. If 5.6 was a no-op (e.g.,
PLAN.md was already empty and BUILD-LOG entry already existed), there
is no new run to watch and 5.7 is a no-op too.

## Phase 5.8: Post-pre-ship docs + tests re-audit

`/ak-pre-ship` runs `/ak-check-docs-and-tests` as Gate 5 once, against the
spec snapshot — that audit appends `## Audit 1` to `review.md`. Every commit
landed AFTER that audit — `/ship`'s `Suspense`-fix commit, the entire CI
fix-loop, the 5.6 bookkeeping commit, and any post-Phase-3 polish
iterations the user asks for during local dogfood — bypasses docs +
test-coverage review entirely. The pre-push reviewer covers PR-description
coverage, the Layer-1 test-presence hook covers "did you touch a test file
at all," and the freshness hook covers docs — but none check **whether the
new behavior is actually pinned by an assertion** or **whether the polish
diff invalidated existing docs**. That's `/ak-check-docs-and-tests`'s job;
5.8 re-runs it once over the polish range — appending `## Audit 2` to the
same `review.md` — before Phase 6 posts the audit comment.

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
something, next push fixed it) is informational. The audit comment in
Phase 6 records the count for reviewer due-diligence — it's evidence
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
  latest '## Audit N' section in ${FEATURE_DIR}/review.md, invokes
  /ak-docs-review and /ak-tests-review in sequence, and appends a new
  '## Audit N' section with structured findings (docs + tests) and
  bypass-trailer review. Do NOT write any docs or tests yourself —
  your job is to audit and recommend, not implement.

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
| `medium>0`   | **Proceed**. Phase 6's audit comment includes a `### Post-pre-ship docs + tests findings` section listing them so the human reviewer sees them inline. Mediums are recommendations, not blockers.                                          |
| `low>0`      | Audit comment notes `(N low-severity items in review.md § Audit N)` without listing.                                                                                                        |
| `0/0/0`      | Audit comment notes `Post-pre-ship audit: clean.`                                                                                                                                           |

**Halt-path output**:

```
✖ Phase 5.8: post-pre-ship docs + tests audit found N high-severity
findings over range ${PRE_SHIP_SHA}..${HEAD}.

Findings (full report at ${FEATURE_DIR}/review.md § Audit N):
  - <finding 1: file:line + one-line summary>
  - <finding 2: ...>

Phase 6 will not post the audit comment until findings are closed.

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
during polish) or a no-op (UI is unchanged). Phase 6's audit comment
records which.

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

## Phase 6: Post audit trail comment

After CI is green, read `$FEATURE_DIR/review.md` and `$FEATURE_DIR/tasks.md` for the
audit data. Post the audit trail on the PR.

Use the outcome vocabulary from `/ak-pre-ship`: **`pass`**, **`findings (N) [fixed | pending]`**,
**`n/a`** (gate didn't apply), **`blocked`** (tooling missing — should never reach
Phase 6 because Phase 3 refuses to advance, but surface it if it somehow does).

```bash
gh pr comment "$PR" --body "$(cat <<'COMMENT'
## Pre-ship audit trail

### Quality gates
| Gate | Result |
|------|--------|
| Docs check | <pass / findings (N) fixed / n/a / blocked> |
| Metrics check | <pass / findings (N) fixed / n/a / blocked> |
| Responsive + theme | <pass / findings (N) fixed / n/a / blocked> |
| /simplify | <pass / findings (N) fixed / blocked> |
| /ak-check-docs-and-tests (Audit 1, pre-polish) | <pass / findings (N) / blocked> |
| /review | <pass / findings (N) fixed / blocked> |
| /cso | <pass / findings (N) fixed / blocked> |
| /design-review | <pass / findings (N) fixed / n/a / blocked> |
| /qa | <pass / findings (N) fixed / blocked> |
| /benchmark | <pass / findings (N) / n/a / blocked> |
| Convention check | <pass / findings (N) / blocked> |
| /ak-check-docs-and-tests (Audit 2, post-polish) | <pass / findings (N) [pending or medium-only] / n/a — empty range / skipped — testReviewSkipReason / blocked> |

### CI fix loop
<N attempts / 0 if CI passed first try / details of what was fixed>

### Polish-loop CI history
<From 5.8.1's enumerate-on-invocation. If zero reds since PR open: "Clean —
 no transient failures during polish."
 If N reds with latest = green: "N transient failure(s) resolved during
 polish (most-recent-first, SHA + run title):" + bulleted list.
 If latest is non-success: should not reach Phase 6 — halted at 5.8.1.
 The reviewer reads this as evidence of polish-loop due diligence — red
 runs that the next push fixed are signal, not noise.>

### Implementation decisions
<From $FEATURE_DIR/tasks.md § Decisions — judgment calls made during /ak-implement>

### Findings fixed during pre-ship
<From $FEATURE_DIR/review.md § Gate N sections — one bullet per finding:
 what was found, which commit fixed it>

### Post-pre-ship docs + tests audit (range: ${PRE_SHIP_SHA}..${HEAD})
<From $FEATURE_DIR/review.md § Audit 2 (the latest `## Audit N` section
 appended by /ak-check-docs-and-tests at Phase 5.8). Surface docs + tests
 findings together — they share one severity budget.

 If 0/0/0: "Clean — no new gaps."
 If medium>0: list each medium verbatim from the section's
              `### Docs findings` and `### Tests findings` subsections
              (file:line + one-line summary).
 If low>0 (and medium=0): "(N low-severity items in review.md § Audit 2)"
 If high>0: should not reach Phase 6 — halt at 5.8.
 If skipped (testReviewSkipReason): "Skipped per <reason>; reviewer judged the
              override (testReviewSkipReason adversarial review PASS)."
 If empty range: "Empty post-pre-ship range — no polish commits to audit.">

### Evidence
<If specs/$FEATURE/hero/*.png exists, include one markdown image-embed per
file. Use the github.com/.../raw/... URL form per § "PR body conventions"
(private-repo safe; raw.githubusercontent.com 404s for viewers without a
token). Skip this section entirely when no hero shots were captured —
do not leave placeholder text.

Append a one-line freshness note based on 5.9's outcome:
  "(Hero shots refreshed at 5.9.)"             — subagent committed new captures
  "(Hero shots unchanged; already at HEAD.)"    — subagent ran, no diff to commit
  "(5.9 skipped — visual evidence already at HEAD via idempotence.)"
This gives the reviewer ground-truth on whether the embeds reflect
the merge-target SHA.>
COMMENT
)"
```

Hero screenshot embeds — generate one image-tag per file found in
`$FEATURE_DIR/hero/`, to splice into the `### Evidence` section above.
Use the private-repo-safe URL form:

```bash
OWNER_REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
BRANCH=$(git branch --show-current)
for shot in "$FEATURE_DIR"/hero/*.png; do
  [ -f "$shot" ] || continue
  REL=${shot#/workspace/}
  echo "![${shot##*/}](https://github.com/${OWNER_REPO}/raw/${BRANCH}/${REL})"
done
```

### Phase 6 checkbox verification (final sweep)

Before leaving Phase 6, re-read the PR body one more time and reconcile the `## Test plan` checkboxes against reality.

**Part A — State-based reconciliation** (does the box's state match its trigger signal?):

| Box                                                                       | Should be `[x]` when                                                                                                                                                                                                                          |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pre-push automated gates (`pnpm turbo run lint typecheck test:unit build`) | `/ship` ran them green before pushing — mark at PR creation time (Phase 4).                                                                                                                                                                   |
| Fast-job CI green                                                         | CI run completed with `conclusion == "success"` — mark when Phase 5.3 fires.                                                                                                                                                                  |
| Slow-job CI green                                                         | CI run's slow job completed green. **If the repo doesn't run a slow job yet**, do NOT mark `[x]` — instead strike the row through (`~~...~~`) with a short "out of scope for this PR" note, so the box reads as a known deferred gate rather than a failing one. |
| Vercel/Netlify/Fly preview deploys successfully                           | Platform bot comment reports `Ready` / equivalent — mark with the preview URL + timestamp.                                                                                                                                                    |
| Manual-review callouts (visual audits, QA walkthrough, post-deploy p95)   | **Never** — these are for the reviewer, not the automation.                                                                                                                                                                                   |

If any box is in the wrong state when Phase 6 runs, fix it with `gh pr edit "$PR" --body-file` before posting the audit comment.

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

If `$EVIDENCE_MISSING` is non-empty → **halt Phase 6**. Do NOT post the audit-trail comment. Surface the discrepancy to the operator:

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

### 7.2: Post ready-for-review comment

```bash
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || git config user.name)

gh pr comment "$PR" --body "## Ready for review

@${GITHUB_USER} This PR is ready for your review.

**Summary:** <feature name from spec>
**Commits:** <N>
**Quality gates:** all passed
**CI:** green <after N fix attempts if any>

${NEXT_STEP_LINE}"
```

### 7.3: Print the handoff to the terminal

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
| `pnpm turbo run lint typecheck test:unit build` — green | `/ship` ran them clean before push | Phase 4 — mark at PR creation |
| `Playwright spec parses via playwright test --list` | `/ak-implement` wrote the spec; `/ak-pre-ship` verified parse | Phase 4 — mark at PR creation |
| Fast-job CI green | `gh run watch` returned `success` | Phase 5.3 |
| Slow-job CI green | Slow-job workflow finished green | Phase 5.3 — or strike through with "out of scope" if the slow job isn't enabled yet |
| Vercel / Netlify / Fly preview deployed | Platform bot comment reports `Ready` / equivalent | Phase 5.3 — include preview URL + timestamp |
| Visual audit (375 / 1440 × light / dark) | — | **Never** — human reviewer only |
| Live QA walkthrough | — | **Never** — human reviewer only |
| Post-deploy middleware p95 / metrics | — | **Never** — runs after merge |
| Onboarding / screen-specific hero screenshot | — | **Never** if blocked on rate-limit / env; note why in `review.md` |

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

1. **Drop it** — the pre-ship gate already covered it; the gate's audit comment carries the attestation.
2. **Or self-attest under "Pre-push automated gates"** with `[x]` + the file:line that grounds the claim. Example: `[x] Migration idempotent guard correct (supabase/migrations/013_realtime_publication.sql:12-20)`.

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

The handoff comment in Phase 7 should also surface these — print them in the terminal hint AND as part of the "Ready for review" comment on the PR. `/ak-go-live` does not run these for you; the user (or the slow-job CI from a future PR) does.

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
