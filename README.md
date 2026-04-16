# Abra-Kadabra

A one-person dev shop. Goes from rough notes to deployed, tested, observable web app.

## Getting Started

### New project

1. Open the devshop (or any existing project) in its devcontainer
2. Run `claude` in the terminal and say `/ak-new-project`
3. Phase A creates a GitHub repo from the `template/` skeleton
4. Clone the new repo on your host next to abra-kadabra, open in VS Code, reopen in container
5. Run `/ak-new-project` again — Phase B walks through guided setup (accounts, scaffolding, integrations, security)

### Existing project

Run `/ak-migrate-project` (skeleton — two tiers: lightweight and full). See `kit/ROADMAP.md § /ak-migrate`.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [VS Code](https://code.visualstudio.com) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- **Claude access** — either:
  - An [Anthropic API key](https://console.anthropic.com/) (`ANTHROPIC_API_KEY`), or
  - A [Claude Pro/Team subscription](https://claude.ai/) (sign in via `claude` in the terminal)

## Goals of Abra-Kadabra Devshop

| Goal                                         | Description                                                                                                                                         | Details                                                                 |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **Devcontainer → plan → build → go live**    | One workflow from idea to production. You handle product decisions, the devshop handles everything technical.                                       | [Pipeline](kit/docs/guide/workflow.md)                                  |
| **Improve devshop separately from projects** | Devshop changes benefit all projects without touching project code. Two repos, one workspace.                                                       | [Two-repo model](kit/docs/guide/architecture.md)                        |
| **Keep devshop out of the project**          | Public contributors see clean code, normal PRs, standard CI. No devshop artifacts in the project repo.                                              | [File lifecycle](kit/docs/guide/architecture.md#file-lifecycle)         |
| **Regular project record on git/GitHub**     | Conventional commits, feature branch PRs, CI gates — the project history reads like any well-run project.                                           | [Branch strategy](kit/docs/OVERVIEW.md#branch-strategy)                 |
| **Easy to start a new project**              | One command creates a repo from the template, guided setup walks through the rest.                                                                  | [New project](kit/docs/guide/workflow.md#starting-a-new-project)        |
| **Easy to migrate an existing project**      | Two tiers: lightweight (same stack) and full (different stack). _(Skeleton — built when a second project needs it.)_                                | [Roadmap](kit/ROADMAP.md)                                               |
| **Simple system, easy to debug**             | Boring solutions over clever ones. Three layers, five file categories, one pipeline. When something breaks, the model tells you where to look.      | [Conceptual model](kit/docs/MODEL.md)                                   |
| **Clear, hierarchical documentation**        | Docs mirror the conceptual model: MODEL for the mental model, OVERVIEW for orientation, guide/ for operational reference, FAQ for design rationale. | [Doc structure](kit/docs/guide/architecture.md#documentation-structure) |

## How it works

See `kit/docs/MODEL.md` for how the system works. See `kit/docs/OVERVIEW.md` for the full picture: workflow, file map, conventions, and glossary.

Short version: you write rough notes, `/office-hours` turns them into a product design, `/autoplan` locks in architecture, `/ak-build` implements autonomously (spec → code → quality gates → PR), you review, `/ak-go-live` deploys.

## Improving the devshop

- `kit/TODOS.md` — tactical: friction, bugs, small fixes
- `kit/ROADMAP.md` — strategic: new capabilities, major improvements
- `kit/notes/` — research, design notes, build blueprints
- `kit/docs/guide/` — full operational reference (update when changing conventions)
- `kit/docs/FAQ.md` — design rationale and architecture decisions
