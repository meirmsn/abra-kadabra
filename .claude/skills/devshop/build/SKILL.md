---
name: ak-build
version: 1.4.0
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
  ├─ Agent → /ak-pre-ship    → writes specs/<name>/review.md
  ├─ Agent → /ship           → pushes, creates PR
  └─ CI watch (main ctx)     → reads review.md + tasks.md for audit comment
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

`/ak-pre-ship` does NOT ship or create a PR. If findings require fixes, the agent
handles them within its context.

### Phase 3 → Phase 4 handoff: refuse to advance on blocked

After the agent returns, parse the counts. The only acceptable state to advance to
`/ship` is: `findings_pending == 0` **and** `blocked == 0`.

- If `findings_pending > 0` → pause and escalate to the user (findings need fixes).
- If `blocked > 0` → **do NOT advance to Phase 4**. The PR is not shippable until the
  tooling gap is closed. Take these actions:

  1. Emit a clear message to the user with the preflight fix recipe from the agent's return.
  2. Post a PR comment (if a PR exists for this branch already — unusual in Phase 3,
     but possible on resume) describing which gates are blocked and why.
  3. Stop the pipeline. The user decides how to proceed (rebuild devcontainer, install
     tooling, or re-scope the PR so the blocked gates no longer apply).
  4. Do NOT treat `blocked` as `n/a`. A cheerful advance past blocked gates is the
     exact failure mode this workflow exists to prevent.

Once the user has resolved the tooling issue, re-run `/ak-build` — Step 0's resume
check will pick up at Phase 3 and rerun pre-ship from the start.

## Phase 4: Ship

Launch **Agent** with prompt:
> Run /ship to push the branch and create a PR.
> /ship will run tests, code review, bump VERSION, push, create PR,
> and auto-invoke /document-release.
> Return: PR number and URL.

After `/ship` completes, a PR exists on GitHub. Verify the PR title and description
reflect all commits. Title: under 70 chars, summarizes the feature/fix. Description:
`## Summary` (bullets), `## Test plan` (checklist), attribution line.

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
```

This blocks until the most-recent workflow run on the branch completes.
Non-zero exit on failure. If it times out, re-run. Cap total wait at 30
minutes.

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
| /ak-test-review | <pass / findings (N) / blocked> |
| /review | <pass / findings (N) fixed / blocked> |
| /cso | <pass / findings (N) fixed / blocked> |
| /design-review | <pass / findings (N) fixed / n/a / blocked> |
| /qa | <pass / findings (N) fixed / blocked> |
| /benchmark | <pass / findings (N) / n/a / blocked> |
| Convention check | <pass / findings (N) / blocked> |

### CI fix loop
<N attempts / 0 if CI passed first try / details of what was fixed>

### Implementation decisions
<From $FEATURE_DIR/tasks.md § Decisions — judgment calls made during /ak-implement>

### Findings fixed during pre-ship
<From $FEATURE_DIR/review.md — one bullet per finding: what was found, which commit fixed it>

### Evidence
<If specs/$FEATURE/hero/*.png exists, include one markdown image-embed per
file. Use the github.com/.../raw/... URL form per § "PR body conventions"
(private-repo safe; raw.githubusercontent.com 404s for viewers without a
token). Skip this section entirely when no hero shots were captured —
do not leave placeholder text.>
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
