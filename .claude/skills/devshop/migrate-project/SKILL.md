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

### Full (different stack — migration from another framework)

Migration from another framework (e.g., Swift → React, Django → Next.js).

- Archive old code for reference
- Port design system (tokens, colors, typography)
- Set up backend integration
- Rebuild screens
- Full test pass

## Trigger

When a second project needs to adopt the devshop. The lalista Phase 1 execution
(`kit/notes/bootstrap/v0-web.md`) is the first data point for parametrization.

## For now

Tell the user this skill is a skeleton. Point them to:

- `kit/ROADMAP.md § /ak-migrate skill` for the full design
- `/ak-new-project` if they want to start from scratch instead
