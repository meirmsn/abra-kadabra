<!-- This file is the project's SYSTEM-level overview — answers "how is this app built".
     For the PRODUCT-level view (what the app does, for whom, which flows), see OVERVIEW.md.
     Both are on-demand docs. The always-loaded entry-point is CLAUDE.md.
     Authoring rules: kit/docs/guide/conventions.md § Project Docs Hierarchy. -->

# ARCHITECTURE: <project name>

> System-level map of how this app is built. Components, data flow, deployment topology, package responsibilities. For the product view (what the app does), see [OVERVIEW.md](./OVERVIEW.md).

## High-level shape

<One paragraph + a small diagram (text or mermaid). Names the major moving parts and how they connect. The reader should understand the system's silhouette in 30 seconds.>

```text
<diagram or topology sketch>
```

## Components

<Per-component, one section. Each section: purpose, where in the repo, dependencies up/down, link to the package's README.md when it exists.>

### <component>

- **Purpose**: <one sentence>
- **Lives at**: `<path>` — see [`<path>/README.md`](./<path>/README.md)
- **Depends on**: <upstream components / external services>
- **Consumed by**: <downstream components>

## Data flow

<How a request / action travels through the system end-to-end. One numbered list per primary flow. Cross-reference OVERVIEW.md for the user-facing description of the same flow.>

1.

## External dependencies

<External services + the role each plays. Include credential surface, blast radius, and where each is configured.>

| Service | Role | Credentials | Configured in |
| ------- | ---- | ----------- | ------------- |
|         |      |             |               |

## Deployment topology

<Where each component runs in production. Include CI/CD entry points and the auto-deploy trigger map.>

-

## Module map

<Quick index of what's in each top-level directory. Each entry links to the per-package README.md if it exists.>

| Directory       | Purpose | README                             |
| --------------- | ------- | ---------------------------------- |
| `apps/<x>/`     |         | [README](./apps/<x>/README.md)     |
| `packages/<x>/` |         | [README](./packages/<x>/README.md) |

## Where to look next

- [OVERVIEW.md](./OVERVIEW.md) — what the product does, who uses it, which flows
- [CLAUDE.md](./CLAUDE.md) — always-loaded entry point with `§ Where Things Happen` path map
- Per-package READMEs (when present) — finer-grained module docs
- [BUILD-LOG.md](./BUILD-LOG.md) — what has shipped, in chronological order

<!-- Authoring rules:
     - Update ARCHITECTURE.md when a new package/app lands, a deployment-topology change ships,
       or an external-service dependency is added/removed.
     - The pre-commit docs-freshness hook is opt-in: it triggers only once ARCHITECTURE.md
       exists at HEAD (which it does once you commit this scaffold). Triggers fire on changes
       under apps/*, packages/*, supabase/functions/* that materially shift what's in the
       module map.
     - Diagrams: prefer plain-text or mermaid. PNG-only diagrams rot — they can't be diffed.
     - This is engineering-language. Product-language goes in OVERVIEW.md. -->
