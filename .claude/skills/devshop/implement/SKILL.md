---
name: ak-implement
version: 3.0.0
description: |
  Run the implementation loop for the active spec. Reads spec from specs/<name>/ →
  traces the gstack plan → checks tasks (new vs resume) → implements each task with tests → runs stuck
  protocol on failure → commits atomically per task → prints completion summary and
  handoff to /ak-pre-ship. Follows conventions in kit/docs/guide/ and CLAUDE.md.
  Use when asked to "implement", "start coding", or "build this". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# Implement

Run the implementation loop for the active spec.

**Before starting** — read two layers, both:

1. **Baseline (always-read)** — `kit/docs/guide/conventions.md` for the
   cross-cutting non-negotiables that fire on every PR regardless of topic:
   Test Presence, Non-Negotiables (Testing / Test Assertion Depth /
   Responsive + Theme / PWA / Code Structure), Bypass trailers, Project
   Docs Coverage, Backlog Routing, Confidence Calibration. Conventions.md
   is the substrate; topical guidance layers on top.

2. **Topical (additive)** — parse the spec's `## Files` + `## Decisions`
   sections, look up matching routing rows in `kit/docs/guide/README.md`,
   read the matched `(file, anchor)` targets, and follow `**See also:**`
   footers where scope-relevant. The routing index points at the guide
   sections that govern the specific patterns this change touches — see
   the SKILL.md for `/ak-spec` Step 1.5 for the parsing shape (file-globs
   - keyword tokens).

The two layers are complementary, not alternatives: conventions.md's
non-negotiables apply universally; the routing matches sharpen the read to
exactly the topics this PR touches. **Pre-adoption projects** (whose
`kit/docs/guide/README.md` isn't yet a routing index) get the baseline
only — equivalent to the pre-routing behavior, with zero regression.

## Step 1: Gather context

Find the active feature spec. When invoked by `/ak-build`, the feature directory is provided.
When invoked standalone, resolve from `PLAN.md § Active`:

```bash
# Source of truth: PLAN.md § Active lists active branches + their specs.
# Find the row whose Branch column matches the current branch.
BRANCH=$(git branch --show-current)
ACTIVE_ROW=$(awk '/^## Active/,/^## Planned/' PLAN.md 2>/dev/null | grep -F "$BRANCH" || true)

if [ -z "$ACTIVE_ROW" ]; then
  # Fall back to branch-name derivation (legacy specs with no PLAN.md row)
  FEATURE=$(echo "$BRANCH" | sed 's|^feature/||;s|^feat/||;s|^fix/||;s|^docs/||;s|^chore/||')
else
  # Parse `specs/<FEATURE>/spec.md` out of the Active row's Spec cell
  FEATURE=$(echo "$ACTIVE_ROW" | grep -oE 'specs/[^/]+/spec\.md' | head -1 | sed 's|^specs/||;s|/spec\.md$||')
fi

FEATURE_DIR="specs/$FEATURE"
```

If `PLAN.md § Active` does not list the current branch and there is no fallback spec
at `$FEATURE_DIR/spec.md`, stop and tell the user to run `/ak-spec` first — it creates
the branch and flips the PLAN.md row into `## Active`.

Read the spec:

```bash
cat "$FEATURE_DIR/spec.md"
```

If spec is absent: stop and tell the user to run `/ak-spec` first.

Read the gstack-plan reference from the provenance header.
Read the gstack plan. Read `DESIGN.md` if the spec touches UI. Read `METRICS.md`.

Check tasks state:

```bash
[ -f "$FEATURE_DIR/tasks.md" ] && echo "RESUME" && cat "$FEATURE_DIR/tasks.md" || echo "NEW"
```

Check git state:

```bash
git branch --show-current && git log --oneline -10 && git status --short
```

## Step 2: New vs resume

**New** (no `$FEATURE_DIR/tasks.md`): decompose the spec into tasks, pre-scan all tasks against
the STOP AND ASK list in `CLAUDE.md` before writing any code, then write `$FEATURE_DIR/tasks.md`.
Include a `## Decisions` section at the bottom (starts empty).

**Resume** (`$FEATURE_DIR/tasks.md` exists): use a sub-agent to read it + `git log --oneline -20`
and return one paragraph: which tasks are done, which is next, any blockers.
Then continue from the next `todo` task.

tasks.md format:

```markdown
## Task: [name]

**Hat**: FE | BE | Data | PM
**Depends on**: [task names or "none"]
**Blocks**: [task names or "none"]
**Done when**: [concrete, testable criterion — tests pass, endpoint returns X, etc.]
**Risk**: low | medium | high
**Status**: todo | in_progress | done | blocked
```

#### Resume pattern

When a session is interrupted, start a new session with:

```
claude "use a sub-agent to read specs/<name>/tasks.md and recent git log,
then tell me in one paragraph: which tasks are done, which is next,
what context I need to continue"
```

Sub-agent reads the file; main session gets a short summary — no context pollution.

## Hats

Each task has a primary hat that sets the quality bar:

- **Frontend** (components, pages, styles): "Does this feel right?" Visual fidelity to DESIGN.md. Loading/empty/error states for every screen. Route-level `error.tsx` boundary per route segment; async components get their own error boundary with retry. Accessible (keyboard nav, labels, contrast). Mobile-first: build 375px, scale up. Theme tokens from `tokens.ts`, never hardcoded colors. Verify both light and dark themes. **Token changes**: design tokens live in two places — `packages/ui/src/tokens.ts` (JS consumers) and `apps/web/app/globals.css` (Tailwind v4 `@theme`). When changing token values, update both. `DESIGN.md` is the source of truth; both files are mechanical derivations.
- **Backend/Data** (migrations, RLS, edge functions, API wrappers): "Can this corrupt data or leak it?" Correctness first, then performance. Never trust client input. RLS boundary tests for every table with policies. Auth validation at every edge function entry. Idempotent where possible. **Migration workflow**: create migration file in `supabase/migrations/`, apply locally with `supabase db reset`, apply to remote with `supabase db push`. Regenerate types after schema changes: `supabase gen types typescript --project-id <ref> > packages/core/src/supabase.types.ts`.
- **Product/PM** (scope decisions, edge cases, UX tradeoffs): "Would a real user hit this?" If >5 min on an edge case not in the spec, add to TODOS.md as `[discovered]` and move on.

A task can involve multiple hats; the primary hat sets the quality bar.

## Conventions to honor (every task)

Pre-write checks restated here so they fire before code lands, not after. Full text + rationale: `kit/docs/guide/conventions.md`.

- **Confidence calibration** — before implementing, re-verify the spec's stop-and-ask items (new DB columns/tables, auth flow changes, new third-party APIs, performance-sensitive paths, security logic, deletion of existing tests, new METRICS.md events) have user approval. Adding a new metric event mid-implementation triggers a pause. See `conventions.md § Confidence Calibration`.
- **Testing** — tests alongside code, never after. Three layers: unit (`*.test.ts`, no DB), integration (`*.integration.test.ts`, real local DB — bring up via `pnpm db:start` on the template-default compose-isolation shape, or `supabase start` from macOS host on the Host Supabase shape; see `kit/docs/guide/local-supabase-compose-isolation.md` for the architecture), E2E (Playwright at 375px + 1440px — both must pass). Auth-boundary RLS test required for every RLS-policied table (User A creates → User B can't see). See `conventions.md § Non-Negotiables — Testing`.
- **Metrics** — `posthog.capture()` calls for every event referenced in the spec's Metrics section, instrumented alongside code, never after. New event definitions are stop-and-ask, never auto-added. See `conventions.md § Metrics Lifecycle`.
- **Code structure** — every non-trivial `.ts`/`.tsx` file under `src/` or `app/` starts with a 3-line header (`// What:` / `// Why:` / `// Does NOT:`); every exported function has a 1-2 sentence JSDoc. Shared packages export TypeScript source directly (`"main": "src/index.ts"`); each package has a `src/index.ts` barrel; no deep path imports across package boundaries. Default to the boring solution. See `conventions.md § Non-Negotiables — Code Structure`.
- **Migrations referencing `auth.users(id)`** — every FK MUST specify `ON DELETE` explicitly (`CASCADE` for tight-ownership columns / `SET NULL` for nullable audit columns / `RESTRICT` for must-keep-row). Implicit `NO ACTION` silently blocks user deletion. See `conventions.md § ON DELETE on auth.users FK references`.
- **Realtime helpers** — when adding a `subscribeTo<X>` wrapper or `postgres_changes` listener, add the matching `alter publication supabase_realtime add table <name>;` migration in the same PR with a `-- ROLLBACK:` block. Without it, cross-session delivery silently no-ops. See `conventions.md § Realtime publication setup`.
- **LLM / edge-function response boundaries** — parse with Zod at the wrapper boundary in `packages/core/src/api/<feature>.ts` for any LLM-backed edge function call or third-party HTTP fetch with a hand-written response shape. Use `.safeParse()` (never `.parse()`); throw a feature-named `{Feature}ValidationError`; capture to Sentry with a scrubbed payload excerpt before throwing. Do NOT add Zod to PostgREST results, form input, or app-internal function args (TypeScript already proves those). See `wrapper-boundaries.md § Runtime Validation at LLM / Edge-Function Boundaries`.

## Step 3: Implementation loop

For each `todo` task in dependency order:

1. Mark `in_progress` in tasks.md
2. If task hits STOP AND ASK in `CLAUDE.md`: stop and ask before writing any code
3. Read relevant existing code (Grep + Glob — do not assume file paths)
4. Implement with tests written alongside (never after)
5. Instrument metrics for events referenced in the spec's Metrics section (`posthog.capture()` calls)
6. Run lint: `pnpm turbo run lint` — fix errors before testing
7. Run typecheck: `pnpm turbo run typecheck` — catches type errors that VS Code would flag instantly for a human developer
8. Run tests: `pnpm turbo run test:unit` (fast inner loop — integration tests are CI's responsibility)
9. **Tests fail**: enter stuck protocol
10. **Tests pass**: commit with format `<type>(<scope>): <imperative summary>` — one task = one commit.
    Note: prettier runs automatically via lint-staged on commit.
11. Mark task `done` in tasks.md
12. **If a judgment call was made** (resolved from context rather than stopping to ask):
    append a one-liner to the `## Decisions` section of tasks.md with the task name and what was decided.

**TypeScript note**: `noUncheckedIndexedAccess: true` is enabled in `tsconfig.base.json`.
Array/object index access returns `T | undefined` — handle explicitly. No `!` assertions
unless the check is genuinely impossible.

**Clarification escalation** — when ambiguity blocks progress:

- Can answer from spec/plan/context → make the call, note in commit message AND in tasks.md `## Decisions`
- Falls under STOP AND ASK (schema, auth, security, new integrations, new metrics) → stop and ask user
- User escalation format: which task, what the ambiguity is, options considered, your lean

### Stuck protocol

Today's prose underspecified the "step back" moment between attempts. The refined
shape uses fresh-agent isolation + a persistent already-tried log to break out of
the failure mode where a stuck agent's failed-reasoning bias carries into the
next attempt. Per-task log path: `$FEATURE_DIR/task-attempts/T<N>.md` where `<N>`
is the task index from `tasks.md`.

- **Attempt 1** — natural. Read the error, hypothesize root cause, fix, rerun.
  On failure, before re-running tests, append a structured section to the
  per-task log:

  ```markdown
  ## Attempt 1 — <one-line failure classification>

  - Hypothesis: <what we thought was broken>
  - Tried: <what we changed>
  - Why ruled out: <what evidence shows it didn't fix it>
  - Ruled out for next attempt: <approach class to skip>
  ```

  Create `$FEATURE_DIR/task-attempts/` and the `T<N>.md` file on first failure
  (`mkdir -p` + `>` to create empty). Subsequent attempts append.

- **Attempt 2** — fresh `Agent` sub-agent invocation with the already-tried log
  fed in. Dispatch:

  ```
  Agent {
    description: "Stuck-task attempt 2 — T<N>",
    subagent_type: "general-purpose",
    prompt: """
      Task T<N> from $FEATURE_DIR/tasks.md is stuck after one failed attempt.
      The prior attempt's hypothesis, what was tried, and why-ruled-out are in
      $FEATURE_DIR/task-attempts/T<N>.md — READ IT FIRST. Do not repeat any
      approach class listed under 'Ruled out for next attempt' without
      explicitly justifying (in writing) why the prior ruling-out was wrong.

      Read the spec, the failing test, and the source code under test. Try a
      different approach class than attempt 1. Run tests. Append your
      `## Attempt 2 — <classification>` section to T<N>.md as your FINAL
      action before returning.

      Return: pass | findings (test name + first-line error) | unresolved.
    """
  }
  ```

  Why fresh-agent: an agent that has just spent its inference budget convincing
  itself approach X is right carries that bias forward. A fresh inference
  context reads the log as evidence ("X was tried and ruled out") rather than
  as a defeat to overturn.

- **Attempt 3** — fresh `Agent` + already-tried log + TWO meta-checks layered on:

  - **Spec re-read** (structural): the agent re-reads `$FEATURE_DIR/spec.md`
    and asks: is task T<N> right-sized? Does it actually contain 2–3 latent
    sub-tasks pretending to be one? If yes, propose a split and surface to
    the operator before continuing.
  - **Devil's-advocate critic** (tactical): a separate sub-sub-`Agent`
    invocation whose only job is to enumerate "what's structurally wrong with
    the approach class we've been trying?". Output appends to T<N>.md as
    `## Devil's advocate (attempt 3)` — concrete listing of 2–3 fundamentally
    different tactics, not variations of what already failed. The attempt-3
    agent reads this section before formulating its fix.

  Dispatch:

  ```
  # First: devil's-advocate critic (writes to T<N>.md, returns synopsis)
  Agent {
    description: "Devil's advocate — T<N>",
    subagent_type: "general-purpose",
    prompt: """
      Read $FEATURE_DIR/task-attempts/T<N>.md. Enumerate what's structurally
      wrong with the approach class attempts 1 + 2 have been trying. Propose
      2–3 fundamentally different tactics — not variations of what already
      failed. Append your enumeration to T<N>.md as a
      `## Devil's advocate (attempt 3)` section before returning.
    """
  }

  # Then: attempt-3 agent (consumes devil's-advocate output)
  Agent {
    description: "Stuck-task attempt 3 — T<N>",
    subagent_type: "general-purpose",
    prompt: """
      Task T<N> is on attempt 3. Read $FEATURE_DIR/spec.md AND
      $FEATURE_DIR/task-attempts/T<N>.md (including the new
      `## Devil's advocate (attempt 3)` section). First answer: is T<N>
      right-sized, or does it bundle 2–3 latent sub-tasks? If yes, return
      'PROPOSE SPLIT' with the proposed sub-tasks; do NOT attempt the fix.
      Otherwise, pick one of the devil's-advocate tactics and try it.

      Append your `## Attempt 3 — <classification>` section to T<N>.md as
      your FINAL action before returning. Return: pass | findings | unresolved
      | PROPOSE SPLIT.
    """
  }
  ```

  The meta-checks only fire at attempt 3 — bounded cost. Attempts 1 + 2 stay
  cheap.

- **Attempt 3 fail** (returns `unresolved`): existing escalation behavior —
  mark task `blocked` in tasks.md, stop, ping user.

- **Attempt 3 returns `PROPOSE SPLIT`**: surface the proposed sub-tasks to
  the operator via `AskUserQuestion`. Operator decides: split into N tasks
  (re-running `/ak-implement` will pick them up) or override-and-continue
  with the original task definition (operator-supplied hypothesis appended to
  T<N>.md, attempt-3 agent re-runs against the updated log).

- The pre-`/ak-build`-phase-decomposition prose ran `/investigate` at attempt
  3 inside the same agent context. The refined shape replaces that with the
  spec-re-read + devil's-advocate combination — both run as fresh sub-agents
  and write to the durable log, so the next attempt (or the user, post-block)
  reads the structured analysis instead of having to reconstruct it from the
  main agent's working memory.

## Step 4: Completion

Run the full unit suite:

```bash
pnpm turbo run test:unit
```

Print completion summary:

```
## Implementation complete
Feature: <name from spec>
Spec: specs/<feature-name>.md
Commits: <N> — <list of task names>
Tests: all green (unit)
Metrics: <list of events instrumented>
Decisions: <count> judgment calls (see tasks.md § Decisions)

Ready for /ak-pre-ship
```

## During implementation

Follow the TODO protocol in `CLAUDE.md` and backlog routing guide in
`kit/docs/guide/conventions.md` for blockers, out-of-scope discoveries,
and minor issues encountered along the way.
