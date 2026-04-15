---
name: ak-build
version: 1.0.0
description: |
  Autonomous build pipeline: spec → implement → quality gates → ship → CI watch → notify.
  Runs unattended after autoplan is ready. User's only touchpoint: review the PR.
  Delegates heavy phases to subagents to keep main context clean.
  Resumable — detects where it left off if session is interrupted.
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
  ├─ Agent → /ak-spec        → writes specs/<name>/spec.md
  ├─ Agent → /ak-implement   → writes specs/<name>/tasks.md + code + tests
  ├─ Agent → /ak-pre-ship    → writes specs/<name>/review.md
  ├─ Agent → /ship           → pushes, creates PR
  └─ CI watch (main ctx)  → reads review.md + tasks.md for audit comment
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
3. **If no existing branch** → determine the feature name from the gstack plan
   (`.gstack/projects/*/plan.md`) or ask the user. Pick the branch prefix:
   `feature/` for new functionality, `fix/` for bug fixes. Create and switch:
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

Detect where a previous run left off:

1. **Open PR for this branch?** → skip to Phase 5 (CI watch)
   ```bash
   PR=$(gh pr list --head "$BRANCH" --json number --jq '.[0].number // empty')
   ```
2. **`$FEATURE_DIR/tasks.md` exists with all tasks `done`?** → skip to Phase 3 (pre-ship)
3. **`$FEATURE_DIR/tasks.md` exists with some tasks `done`?** → skip to Phase 2 (implement resumes internally)
4. **`$FEATURE_DIR/spec.md` exists?** → skip to Phase 2 (implement)
5. **None of the above** → start from Phase 1 (create `$FEATURE_DIR/`)

Log resume point: "Resuming from Phase N: <reason>"

## Phase 1: Spec

Launch **Agent** with prompt:
> Run /devshop:spec for feature "$FEATURE".
> Write the spec to $FEATURE_DIR/spec.md (create the directory if needed).
> Write provenance header linking to the gstack plan.
> If METRICS.md needs new events, stop and ask me before adding them.
> Return a one-line summary of what was written.

This may stop for METRICS.md confirmation on new projects (new metric definitions
require human review). This is the one acceptable interactive moment before the PR.

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
> Return: summary of gate results, number of findings fixed.

`/ak-pre-ship` does NOT ship or create a PR. If findings require fixes, the agent
handles them within its context.

## Phase 4: Ship

Launch **Agent** with prompt:
> Run /ship to push the branch and create a PR.
> /ship will run tests, code review, bump VERSION, push, create PR,
> and auto-invoke /document-release.
> Return: PR number and URL.

After `/ship` completes, a PR exists on GitHub. Verify the PR title and description
reflect all commits. Title: under 70 chars, summarizes the feature/fix. Description:
## Summary (bullets), ## Test plan (checklist), attribution line.

## Phase 5: CI watch + fix loop

Wait for CI to complete, fix failures if possible.

### 5.1: Get PR number
```bash
PR=$(gh pr list --head "$(git branch --show-current)" --json number --jq '.[0].number')
```

### 5.2: Watch CI
```bash
gh pr checks "$PR" --watch --fail-fast
```
This blocks until all checks complete or one fails. If it times out, re-run.
Cap total wait at 30 minutes.

### 5.3: On CI green → proceed to Phase 6

### 5.4: On CI failure → fix loop

```
FIX_ATTEMPTS=0
MAX_ATTEMPTS=3

while CI is failing and FIX_ATTEMPTS < MAX_ATTEMPTS:
  1. Read failure logs:
     gh run view <RUN_ID> --log-failed 2>&1 | tail -200

  2. Classify failure: lint | typecheck | unit | integration | e2e | build | timeout

  3. For timeout/flaky: just push an empty commit to trigger retry
     git commit --allow-empty -m "ci: retry after timeout"
     git push

  4. For real failures:
     a. Grep the test name from the logs
     b. Read the failing test file locally
     c. Read the source code the test exercises
     d. Understand why it fails (logs + local code context)
     e. Fix the source code

  5. For locally verifiable failures (lint, typecheck, unit, build):
     Run the relevant local command to confirm the fix works
     pnpm turbo run lint        # for lint failures
     pnpm turbo run typecheck   # for type errors
     pnpm turbo run test:unit   # for unit test failures
     pnpm turbo run build       # for build failures

  6. For CI-only failures (integration, E2E):
     Fix is informed by logs but cannot be verified locally.
     Push and let CI verify.

  7. Commit + push:
     git add -A
     git commit -m "fix: CI failure - <description>"
     git push

  8. After pushing, update PR title/description if the fix changes scope.

  9. FIX_ATTEMPTS += 1
  10. Go to 5.2 (watch CI again)
```

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

## Phase 6: Post audit trail comment

After CI is green, read `$FEATURE_DIR/review.md` and `$FEATURE_DIR/tasks.md` for the
audit data. Post the audit trail on the PR:

```bash
gh pr comment "$PR" --body "$(cat <<'COMMENT'
## Pre-ship audit trail

### Quality gates
| Gate | Result |
|------|--------|
| Docs check | <pass/skipped/findings> |
| Metrics check | <pass/skipped/findings> |
| Responsive + theme | <pass/skipped/findings> |
| /simplify | <pass/N findings fixed> |
| /ak-test-review | <pass/N findings> |
| /review | <pass/N findings fixed> |
| /cso | <pass/N findings fixed> |
| /design-review | <pass/skipped/N fixes> |
| /qa | <pass/N bugs fixed> |
| /benchmark | <pass/skipped/regression> |
| Convention check | <pass/N issues> |

### CI fix loop
<N attempts / 0 if CI passed first try / details of what was fixed>

### Implementation decisions
<From $FEATURE_DIR/tasks.md § Decisions — judgment calls made during /ak-implement>

### Findings fixed during pre-ship
<From $FEATURE_DIR/review.md — one bullet per finding: what was found, which commit fixed it>
COMMENT
)"
```

## Phase 7: Update BUILD-LOG.md

If `BUILD-LOG.md` does not exist, copy from `/devshop/template/BUILD-LOG.md`.

Append an entry to the project's `BUILD-LOG.md`:

```markdown
### <feature-name> (YYYY-MM-DD)

- **Branch**: <branch name>
- **PR**: #<PR number>
- **Spec**: specs/<feature>/spec.md
- **Summary**: <1-line from spec>
- **Commits**: <N>
- **Quality gates**: all passed
```

## Phase 8: Notify

```bash
GITHUB_USER=$(gh api user --jq .login 2>/dev/null || git config user.name)

gh pr comment "$PR" --body "## Ready for review

@${GITHUB_USER} This PR is ready for your review.

**Summary:** <feature name from spec>
**Commits:** <N>
**Quality gates:** all passed
**CI:** green <after N fix attempts if any>

Review the diff, check the preview URL, then run \`/ak-go-live\` to deploy."
```

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
