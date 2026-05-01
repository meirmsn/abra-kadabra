<!-- This file is the project's PRODUCT-level overview — answers "what does this app do, and for whom".
     For the SYSTEM-level view (components, data flow, deployment), see ARCHITECTURE.md.
     Both are on-demand docs. The always-loaded entry-point is CLAUDE.md.
     Authoring rules: kit/docs/guide/conventions.md § Project Docs Hierarchy. -->

# OVERVIEW: <project name>

> Product-level map of what this app does, the people it serves, and the user-visible flows that make it useful. For the system view (architecture, data flow, deployment), see [ARCHITECTURE.md](./ARCHITECTURE.md).

## What this is

<One paragraph. The product in plain language — what someone using it does, why they care, and what problem it removes. No engineering jargon.>

## Who uses it

<Bullet list of user types, each with one sentence on what they need from the product.>

-

## Core flows

<The verbs the product supports, end-to-end. One bullet per flow. Each names the surfaces involved (sign-in, dashboard, etc.) — the system-level details live in ARCHITECTURE.md.>

-

## Features

<Grouped feature inventory, organized by user-visible category rather than by code structure. Cross-reference to the per-package README.md or apps/<x>/README.md when relevant.>

### <Category>

-

### <Category>

-

## Out of scope (intentionally)

<What this product is deliberately NOT — bounds the conversation when stakeholders ask "could it also...". Update as scope decisions are made.>

-

## Where to look next

- [ARCHITECTURE.md](./ARCHITECTURE.md) — how it's built, components, data flow, deployment
- [PLAN.md](./PLAN.md) — what's being built right now (Active + Planned PRs)
- [PRODUCT-ROADMAP.md](./PRODUCT-ROADMAP.md) — long-term / deferred features
- [BUILD-LOG.md](./BUILD-LOG.md) — what has shipped, in chronological order
- [CLAUDE.md](./CLAUDE.md) — the always-loaded entry point with path map + gotchas

<!-- Authoring rules:
     - Update OVERVIEW.md when a new user-visible flow lands, a feature category is added,
       or product scope changes (in vs out).
     - The pre-commit docs-freshness hook is opt-in: it triggers only once OVERVIEW.md exists
       at HEAD (which it does once you commit this scaffold). Triggers fire on changes to
       user-visible surfaces (apps/*/app/**/page.tsx, layout.tsx, route.ts) and require this
       file to be staged when those changes alter what the product does.
     - Cross-link to ARCHITECTURE.md whenever a flow has non-trivial system implications.
     - This is product-language. Engineering-language goes in ARCHITECTURE.md. -->
