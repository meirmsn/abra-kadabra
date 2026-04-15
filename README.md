# Abra-Kadabra

A one-person dev shop. Goes from rough notes to deployed, tested, observable web app.

## Getting Started

### New project

1. Create a new repo on GitHub
2. Clone abra-kadabra as a sibling: `git clone <devshop-url> ../abra-kadabra`
3. Add a `.devcontainer/` that mounts `../abra-kadabra` at `/devshop` (copy from abra-kadabra's `.devcontainer/`)
4. Open in VS Code, reopen in the dev container
5. Run `claude` in the terminal and say `/ak-init`

`/ak-init` walks through a 27-step guided setup: accounts, scaffolding, integrations, security, and verification. See `.devshop/GUIDE.md § Starting a New Project` for the full checklist.

### Existing project

Adopting the devshop on an existing codebase is planned but not yet automated. See `.devshop/ROADMAP.md § /ak-migrate` for the design.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [VS Code](https://code.visualstudio.com) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- **Claude access** — either:
  - An [Anthropic API key](https://console.anthropic.com/) (`ANTHROPIC_API_KEY`), or
  - A [Claude Pro/Team subscription](https://claude.ai/) (sign in via `claude` in the terminal)

## How it works

See `.devshop/OVERVIEW.md` for the full picture: workflow, file map, conventions, and glossary.

Short version: you write rough notes, `/office-hours` turns them into a product design, `/autoplan` locks in architecture, `/ak-build` implements autonomously (spec → code → quality gates → PR), you review, `/ak-go-live` deploys.

## Improving the devshop

- `.devshop/TODOS.md` — tactical: friction, bugs, small fixes
- `.devshop/ROADMAP.md` — strategic: new capabilities, major improvements
- `.devshop/notes/` — research, design notes, build blueprints
- `.devshop/GUIDE.md` — full operational reference (update when changing conventions)
- `.devshop/FAQ.md` — design rationale and architecture decisions
