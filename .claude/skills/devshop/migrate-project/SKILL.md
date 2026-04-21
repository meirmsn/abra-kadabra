---
name: ak-migrate-project
version: 1.0.0
description: |
  Adopt the devshop on an existing project. Two tiers: lightweight (same stack,
  just needs tooling) and full (different stack, port everything).
  Skeleton — full implementation deferred to when a second project needs the devshop.
  Use when asked to "migrate project", "adopt devshop", "add devshop to existing project". (devshop)
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Migrate Project

Adopt the devshop on an existing project. Not yet fully implemented — this is a
skeleton that documents the approach. See `kit/ROADMAP.md § /ak-migrate skill`
for the full design.

## Two Tiers

### Lightweight (same stack — existing Node/Next.js project)

The project already uses the same stack. Just needs devshop tooling wired in.

- Merge configs (`.prettierrc`, `eslint.config.mjs`, `tsconfig.base.json`, etc.)
  instead of replacing — the project's versions may have intentional differences
- Create/adapt `.devcontainer/` from the devshop template
- Skip N/A steps (no Supabase, no PostHog, etc.)
- Don't delete existing `apps/` / `packages/` — they have real code
- Run `/cso` baseline audit once tooling is wired in

### Full (different stack — migration from another framework)

Migration from another framework (e.g., Swift → React, Django → Next.js).

- Archive old code for reference
- Port design system (tokens, colors, typography)
- Set up backend integration
- Rebuild screens
- Full test pass
- Run `/cso` baseline audit before going live

## Trigger

When a second project needs to adopt the devshop. The lalista Phase 1 execution
(`kit/notes/bootstrap/v0-web.md`) is the first data point for parametrization.

## For now

Tell the user this skill is a skeleton. Point them to:

- `kit/ROADMAP.md § /ak-migrate skill` for the full design
- `/ak-new-project` if they want to start from scratch instead

---

## Known migration: PLAN.md adoption (v1.13.0+)

Devshop v1.13.0 moved feature tracking out of `BUILD-LOG.md § In Flight` + `## Log` into a new root-level `PLAN.md`. Existing projects on v1.12.0 or earlier need a one-time migration. This is the first real tier-1 ("lightweight, same stack") migration with concrete steps — documented here so the full `/ak-migrate` implementation can parametrize from it.

### Steps for an existing project adopting PLAN.md

Run these in the project repo (`/workspace`) on a feature branch (e.g. `feat/plan-md-adoption`):

1. **Create `PLAN.md` at repo root** from `/devshop/template/PLAN.md`. If the old `BUILD-LOG.md § In Flight` had entries, convert each into a `## Active` row in PLAN.md:
   - `Branch` = the branch cell
   - `Spec` = `specs/<feature>/spec.md`
   - `Notes` = free-form pointer to scope (from the original In Flight status line or a PRODUCT-ROADMAP section)

2. **Restructure `BUILD-LOG.md`**:
   - Remove the `## In Flight` heading + placeholder (`_No work in progress._`)
   - Remove the `## Log` heading
   - Keep the intro paragraph; keep all shipped entries as-is, newest-first.
   - Update the intro to say "One entry per merged PR, most-recent first. Written by `/ak-build` Phase 5.6 on the feature branch before merge."

3. **Update project `CLAUDE.md § "Where Things Happen"`** to reference `PLAN.md` alongside `BUILD-LOG.md` (e.g. add a "Forward plan" row).

4. **Delete `.gstack/projects/<slug>/IMPLEMENT.md`** if present. `/ak-spec` v2.1.0+ discovers design + test plan files generically by pattern (`*-design-*.md`, `*-test-plan-*.md`) — no pointer file needed. Keeping IMPLEMENT.md doesn't break anything, but it's dead weight and often contains hardcoded project-specific filenames that mislead.

5. **Grep the project for stale references** to `In Flight`, `## Log`, or `IMPLEMENT.md`. Common hit sites:
   - Code comments in E2E / QA test files (e.g., comments in `*.spec.ts` or `*.test.ts`)
   - Project-local notes under `docs/` or `notes/`
   - README.md
   - Replace with PLAN.md-aware references or remove.

6. **Verify the devshop version** consumed by the project is v1.13.0+:

   ```bash
   cat /devshop/kit/version
   ```

   Older versions still expect `## In Flight` — a project can't straddle the migration.

7. **Commit everything in one reviewable PR**. Typical shape: one commit for the structural changes (PLAN.md + BUILD-LOG restructure + CLAUDE.md addition + IMPLEMENT.md delete), one commit for grep-fixed stale references. The PR title is something like `chore: adopt PLAN.md feature tracking (devshop v1.13.0)`.

### What to expect if you skip this migration

On a project still carrying `## In Flight`, the new skills will:

- `/ak-spec` tries to write an Active row into a non-existent `PLAN.md` (it will create PLAN.md from the template at that point, automatically).
- `/ak-implement` fails to resolve the spec because it looks in `PLAN.md § Active` and finds nothing — falls back to branch-name derivation (still works, but less informative).
- `/ak-build` Phase 5.6 cleans the PLAN.md Active row and appends to BUILD-LOG; the old `## In Flight` stub sits untouched and the old `## Log` section accumulates a new peer (the Phase 5.6 entry appears above `## In Flight`).

In short: the migration is safe to defer but surfaces as messy history in BUILD-LOG until done. Run the steps above at a lull between features.

### For the full `/ak-migrate` implementation (future)

The lightweight tier is essentially the PLAN.md migration steps above, generalized:

- Read the devshop `manifest.txt` and offer to sync missing build tooling files (`turbo.json`, `eslint.config.mjs`, etc.) via `sync-from-devshop.sh`.
- Snapshot the current `.devcontainer/` and offer to merge devshop additions rather than replace (existing projects have real customizations).
- Run the structural-migration steps for whatever devshop-version delta the project spans (v1.12 → v1.13 is one such delta; future deltas accumulate as versioned migration scripts under `kit/migrations/<from>-to-<to>.sh`).
- Run `/cso` baseline audit at the end.

Parametrize from the lalista v1.12 → v1.13 migration when implementing — that flow is the proof that the steps are correct and complete.
