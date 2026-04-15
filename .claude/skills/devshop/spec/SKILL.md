---
name: ak-spec
version: 2.0.0
description: |
  Convert the latest gstack plan into an implementation-ready spec.
  Run after /autoplan (and optionally /design-shotgun + /design-html) has locked
  in architecture, edge cases, and design direction.
  Use when asked to "write the spec", "create a spec", or "prepare for implementation". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Spec

Convert the latest gstack plan into an implementation-ready spec.

Run after `/autoplan` (and optionally `/design-shotgun` + `/design-html`) has locked
in architecture, edge cases, and design direction.

## Step 1: Check METRICS.md

- If `METRICS.md` does not exist AND this is the first feature (no `apps/`, `packages/` with code):
  - Read the gstack plan output
  - Draft an initial event taxonomy following the metrics principles in `kit/docs/guide/ § Metrics Lifecycle`
  - Present to user: "Here's the initial metrics taxonomy I derived from the plan — confirm, adjust, or add events before I continue"
  - **Stop and wait for confirmation** (new metric event definitions require review)
  - Write `METRICS.md` with confirmed events using the structure in `kit/docs/guide/ § Metrics Lifecycle`
- If `METRICS.md` does not exist AND this is NOT the first feature:
  - Error: "METRICS.md not found — create it before running /ak-spec. See kit/docs/guide/ new-project checklist."
  - Stop.
- If `METRICS.md` exists: continue.

## Step 2: Read the gstack plan

```bash
cat .gstack/projects/*/IMPLEMENT.md
```

Read the design doc and test plan referenced in IMPLEMENT.md fully before proceeding.

## Step 3: Judge completeness

The plan is ready to implement directly if it specifies **all** of:

- Every user-facing behavior including error states
- Exact data model changes (schema diffs, not prose)
- API contracts (endpoints, inputs, outputs, auth requirements)
- Service dependencies
- Explicit out-of-scope items

**If complete**: write `specs/<feature-name>/spec.md` noting the plan is the spec:

```
# Spec: <feature-name>
The gstack plan is the spec. See .gstack/projects/<slug>/<plan-file>.md
```

**If gaps exist**: continue to Step 4.

## Step 4: Write the spec

Derive the feature name from the current branch:

```bash
git branch --show-current | sed 's|^feat/||;s|^fix/||;s|^chore/||'
```

Create the feature directory and write `specs/<feature-name>/spec.md`. The first 3 lines
must be machine-parseable provenance so that `/devshop:implement` can trace the full
context chain:

```
<!-- gstack-plan: .gstack/projects/<slug>/<plan-file>.md -->
<!-- generated-by: /devshop:spec -->
<!-- date: YYYY-MM-DD -->
```

Then fill only the gaps the gstack plan left — the missing detail only, not a rewrite:

- User-facing behaviors not yet specified (happy path + all error states)
- Data model changes (exact schema diffs)
- API contracts (endpoints, inputs, outputs, auth)
- Service dependencies
- Explicit out-of-scope items
- **Offline behavior**: every feature with remote data must declare: (a) online-only with error state, (b) read-only cache, (c) full offline with sync. Default to (a) unless explicitly upgraded.
- **Metrics** section — reference specific events from `METRICS.md` that this feature touches (existing events to instrument + new events to define)

Do not rewrite what the plan already said. If something is genuinely ambiguous after
reading the full plan, ask. Otherwise fill the gap from what the plan implies.
No decision Q&A — architecture decisions were made by `/autoplan`'s eng review.

## Step 5: Handle new metrics

If the feature introduces new user actions not yet in `METRICS.md`:

- Propose new events following the metrics principles in `kit/docs/guide/ § Metrics Lifecycle`
- **Stop and ask for confirmation** before adding to `METRICS.md`
- Never auto-add events without review

## Step 6: Verify feature directory

Confirm `specs/<feature-name>/spec.md` was written. No pointer file needed —
`/ak-build` and `/ak-implement` find the spec via the feature directory path.

## Quality checklist

Every spec must have:

- [ ] All user-facing behaviors described (happy path + error states)
- [ ] Data model changes explicit (exact schema diffs or "no changes")
- [ ] API contracts specified (endpoints, inputs, outputs, auth requirements)
- [ ] Out-of-scope items explicitly listed
- [ ] Offline behavior declared for any feature with remote data: (a) online-only with error state, (b) read-only cache, (c) full offline with sync. Default to (a) unless explicitly upgraded.
- [ ] Metrics section referencing events from `METRICS.md`
- [ ] Provenance header linking to gstack plan
