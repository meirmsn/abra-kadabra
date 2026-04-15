---
name: ak-implement
version: 2.1.0
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

**Before starting**: read `kit/docs/guide/ § Shared Conventions` for testing philosophy,
backlog routing, and metrics lifecycle. These are referenced throughout, not duplicated here.

## Step 1: Gather context

Find the active feature spec. When invoked by `/ak-build`, the feature directory is provided.
When invoked standalone, derive from branch:

```bash
BRANCH=$(git branch --show-current)
FEATURE=$(echo "$BRANCH" | sed 's|^feature/||;s|^feat/||;s|^fix/||')
FEATURE_DIR="specs/$FEATURE"
```

Read the spec:

```bash
cat "$FEATURE_DIR/spec.md"
```

If spec is absent: stop and tell the user to run `/devshop:spec` first.

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

**Stuck protocol:**

- Attempts 1–2: read the error, hypothesize root cause, fix, rerun
- Attempt 3 (same error): invoke `/investigate` via Skill tool — wait for root-cause analysis
- Still stuck after `/investigate`: mark task `blocked` in tasks.md, stop, ping user

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
`kit/docs/guide/ § Shared Conventions` for blockers, out-of-scope discoveries,
and minor issues encountered along the way.
