---
name: ak-build
version: 1.3.0
description: |
  Autonomous build pipeline: spec → implement → quality gates → ship → CI watch → notify.
  Runs unattended after autoplan is ready. User's only touchpoint: review the PR.
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

### 5.6: Finalize PLAN.md + BUILD-LOG.md on the feature branch

Runs on CI green (after 5.3), before advancing to Phase 6. Closes out this feature's history **on the feature branch** so it ships as part of this PR — not as a separate post-merge cleanup PR.

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

4. Commit on the feature branch:

   ```bash
   git add PLAN.md BUILD-LOG.md
   git commit -m "chore(build-log): record <FEATURE>"
   git push
   ```

5. Re-fetch the PR body. If it carries a commit count that's now stale (e.g., `Commits: N`), update via `gh pr edit "$PR" --body-file`.

**Idempotence**: if 5.6 has already run for this feature (no Active row for `$FEATURE_BRANCH` in `PLAN.md` AND a `BUILD-LOG.md` entry referencing `$PR` exists), skip — don't duplicate.

**Fallback for CI-timeout**: if `$PR` is not yet set (5.1 hasn't run — edge case where Phase 5 was entered out-of-band), 5.6 is a no-op; it will fire next time CI is green with a known PR.

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
| Vercel/preview deploy checkbox                                      | URL in the checkbox line resolves (HTTP 2xx)                                                | `curl -sfI "$URL" >/dev/null`                                                                                |
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

# For every [x] preview-deploy line, curl the URL
grep -oE '\[x\].*(https://[^ )]+\.(vercel|netlify|fly)\.(app|dev|io)[^ ]*)' /tmp/pr-body.md \
  | grep -oE 'https://[^ )]+' \
  | while read -r url; do
      curl -sfI "$url" >/dev/null || EVIDENCE_MISSING+="  $url (preview URL not reachable)\n"
    done

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
