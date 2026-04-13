# Abra-Kadabra

A one-person dev shop. Goes from rough notes to deployed, tested, observable web app.

## Getting Started

1. Clone this repo as a sibling to your project repo
2. Open your project in VS Code and reopen in the dev container
3. The devcontainer mounts this repo at `/devshop` and runs `init-devshop.sh` on start
4. Place your Claude credentials in `.devcontainer/.env` (see below)
5. Run `claude` in the terminal and say `/ak-init`

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [VS Code](https://code.visualstudio.com) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- **Claude access** — either:
  - An [Anthropic API key](https://console.anthropic.com/) (`ANTHROPIC_API_KEY`), or
  - A [Claude Pro/Team subscription](https://claude.ai/) (sign in via `claude` in the terminal)
