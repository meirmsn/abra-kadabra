# Claude Code Dev Container

A sandboxed VS Code Dev Container for running Claude Code with restricted network access. Claude can only reach a specific allowlist of domains - it cannot make arbitrary outbound connections to the internet.

Source: https://github.com/anthropics/claude-code/tree/main/.devcontainer

---

## What's included

- Node.js 20
- Claude Code CLI
- ESLint (code quality) + Prettier (formatting) + EditorConfig
- `git-delta` for syntax-highlighted diffs
- Zsh + Oh My Zsh (provided by the Microsoft base image)
- Outbound firewall (allowlist-only)

---

## Getting started

1. Create `.devcontainer/.env` (copy from `.env.example` if your project ships one). The file holds **project-runtime** secrets (Supabase tokens, Vercel token, etc.) — see your project's `/ak-new-project` Step 4 for the full list.
2. Open the project in VS Code and select **Reopen in Container**
3. Run `claude` in the terminal — onboarding is auto-skipped, so Claude Code is ready immediately

> **Anthropic API key** — if your project's edge functions call Claude at runtime, add `QA_ANTHROPIC_API_KEY=...` to `.devcontainer/.env`. The `QA_` prefix is deliberate: Claude Code in the devcontainer auto-detects a bare `ANTHROPIC_API_KEY` as its own auth credential and prompts the operator at every start, even when the key is meant for the project's runtime, not Claude Code itself. The prefix dodges that detection. The corresponding prod key (`PROD_ANTHROPIC_API_KEY`) MUST NEVER live in this file — it lives only in GitHub Secrets and the Supabase project secrets pushed by `deploy-functions.yml`. See your project's `/ak-new-project` § Security Posture for the QA/PROD split rationale.

> **Claude Code auth** — Claude Code uses your VS Code extension login or your subscription session by default; you don't need to put your Claude Code API key in this `.env` unless you're explicitly opting into pay-as-you-go API billing for the CLI itself.

---

## Key decisions

- **ESLint for code quality only** — formatting is handled entirely by Prettier; no overlap between the two
- **EditorConfig as source of truth** — universal formatting rules (indent, line endings, charset) that apply in any editor or CI environment
- **`.devcontainer/.env` holds project-runtime secrets only** — Claude Code auth runs through the VS Code extension or your subscription session, not via env-var. Project-runtime keys (Supabase, Vercel, optional `QA_ANTHROPIC_API_KEY` for projects whose edge functions call Claude) go in `.env`. Prod keys never live here.
- **`waitFor: postStartCommand`** — VS Code won't connect until the firewall script succeeds, so you're never silently in an unprotected environment

---

## Python projects

Swap the base image in `devcontainer.json`:

```json
"image": "mcr.microsoft.com/devcontainers/python:3.12"
```

Then replace ESLint/Prettier with Python equivalents (e.g. `ruff` for both linting and formatting).

---

## Files

| File                | Purpose                                                     |
| ------------------- | ----------------------------------------------------------- |
| `devcontainer.json` | Tells VS Code how to build and configure the container      |
| `Dockerfile`        | Builds the container image                                  |
| `init-firewall.sh`  | Locks down outbound network access on every container start |

---

## devcontainer.json - Key Settings Explained

### Build Args

```json
"args": {
  "TZ": "${localEnv:TZ:America/Los_Angeles}",
  "CLAUDE_CODE_VERSION": "latest",
  "GIT_DELTA_VERSION": "0.18.2",
  "SUPABASE_CLI_VERSION": "2.78.1"
}
```

- `devcontainer.json` is the **single source of truth** for tool versions — the Dockerfile ARGs have no defaults, so the build fails loudly if a version is missing here
- Pinned versions are a tradeoff: you get reproducible builds, but you have to manually bump them to get updates (tools like Dependabot can automate this)
- `CLAUDE_CODE_VERSION` is intentionally left as `latest` since Claude Code is the primary tool and staying current is preferred over strict pinning

### Network Capabilities

```json
"runArgs": ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW"]
```

Docker containers run with restricted Linux capabilities by default. These two grant the container permission to manipulate firewall rules:

- `NET_ADMIN` - required to run `iptables` and `ipset` commands
- `NET_RAW` - required for raw network sockets used internally by iptables

These capabilities persist for the container's lifetime. There is no clean built-in way to drop them after the firewall script finishes - Docker's `runArgs` apply at startup and cannot be changed mid-lifecycle.

### VS Code Extensions

```json
"extensions": [
  "anthropic.claude-code",
  "EditorConfig.EditorConfig",
  "dbaeumer.vscode-eslint",
  "esbenp.prettier-vscode"
]
```

Installed automatically into the VS Code instance running inside the container.

### Terminal Settings

```json
"terminal.integrated.defaultProfile.linux": "zsh",
"terminal.integrated.profiles.linux": {
  "bash": { "path": "bash", "icon": "terminal-bash" },
  "zsh": { "path": "zsh" }
}
```

- Registers `bash` and `zsh` as available terminal options in the dropdown
- Sets `zsh` as the default for new terminals
- Does **not** affect the built-in "JavaScript Debug Terminal" - that's added by VS Code's debugger extension and is unrelated to shell profiles. It lets you run Node.js processes with the debugger automatically attached, no launch config needed

### Non-root User

```json
"remoteUser": "node"
```

VS Code connects as the `node` user (built into the Microsoft devcontainer base image) rather than `root`. This limits what can go wrong if something misbehaves. The only exception is `init-firewall.sh`, which needs root - the Dockerfile grants `node` passwordless sudo access for that one script specifically.

### Volumes (Persistent Storage)

```json
"mounts": [
  "source=claude-code-bashhistory-${devcontainerId},target=/commandhistory,type=volume",
  "source=claude-code-config-${devcontainerId},target=/home/node/.claude,type=volume"
]
```

These are **Docker named volumes** - storage managed internally by Docker that survives container rebuilds. Two things are persisted:

- `/commandhistory` - your shell history (bash/zsh)
- `/home/node/.claude` - Claude Code config and session history

Important caveats:

- These are **not** stored on your Mac's filesystem - they live inside Docker's Linux VM, invisible to Finder and not backed up by Time Machine
- They are **lost if you move to a new machine** - your session history won't carry over (the API key comes from `.devcontainer/.env`, so that's fine)
- The `${devcontainerId}` suffix ensures each project gets its own isolated volumes
- The suffix is at the end (not the start) so volume names are readable left-to-right: what it is, then which project

This is different from your workspace folder, which is a **bind mount** - a direct portal to your Mac's filesystem:

|                            | Named Volume (`type=volume`) | Bind Mount (`type=bind`) |
| -------------------------- | ---------------------------- | ------------------------ |
| Visible in Finder          | ❌                           | ✅                       |
| Backed up by Time Machine  | ❌                           | ✅                       |
| Survives container rebuild | ✅                           | ✅                       |
| Lost on new machine        | ✅                           | ❌                       |

### Workspace Mount

```json
"workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=delegated",
"workspaceFolder": "/workspace"
```

Maps your local project folder into `/workspace` inside the container. `consistency=delegated` is a macOS performance hint - it lets Docker sync file changes back to the Mac lazily, which meaningfully improves I/O speed (Mac↔Linux VM file syncing is a known Docker bottleneck).

If you omit these settings entirely (as in a simpler `devcontainer.json`), VS Code defaults to mounting your project at `/workspaces/<folder-name>` automatically.

### Environment Variables

```json
"containerEnv": {
  "NODE_OPTIONS": "--max-old-space-size=4096"
}
```

- `NODE_OPTIONS` - raises Node.js heap memory limit to 4GB. Claude Code is a Node.js process and can be memory-hungry on large codebases; the default limit (~512MB–1GB) can cause crashes

### Startup

```json
"postCreateCommand": "echo '{\"hasCompletedOnboarding\": true}' > ~/.claude.json",
"postStartCommand": "sudo /usr/local/bin/init-firewall.sh",
"waitFor": "postStartCommand"
```

- `postCreateCommand` runs once on first container creation and writes a flag file that tells Claude Code to skip the interactive onboarding wizard — without this, `claude` hangs waiting for input on first launch
- `postStartCommand` runs the firewall script on every start (not just first build). `waitFor` tells VS Code to wait for this to complete before connecting — ensuring the firewall is always in place before any work begins

---

## init-firewall.sh - Network Allowlist

Runs on every container start. Locks down outbound traffic to a specific allowlist using `iptables` and `ipset`.

### How it works

The script uses two tools together:

- `ipset` — creates named sets of IP addresses that can be referenced by firewall rules. Much more efficient than writing one iptables rule per IP address
- `iptables` — the actual Linux firewall. Rules are evaluated top-to-bottom; the first match wins

The general pattern is: explicitly allow the things you trust, then block everything else at the end.

### What it allows

- DNS lookups and SSH (always)
  - Without this, nothing works: domain names can't resolve, git operations over SSH fail
- Localhost traffic
  - Processes on the container talking to each other
- Host machine's local network
  - The script detects the host machine's local network range (e.g. `192.168.x.x`) and allows traffic to it. This lets the container reach your local machine and LAN resources without opening the broader internet
- GitHub IP ranges (fetched dynamically from `api.github.com/meta`)
- Specific domains: `registry.npmjs.org`, `api.anthropic.com`, `sentry.io`, `statsig.anthropic.com`, `statsig.com`, VS Code marketplace and update servers

Domain-based rules have a caveat: IPs are resolved once at startup. If a service's IPs change while the container is running, the rules won't update until the next restart.

### What it blocks

Everything else. All other outbound connections are explicitly rejected with `icmp-admin-prohibited`.

After all the allow rules, a final rule explicitly rejects all other outbound connections with `icmp-admin-prohibited`. This sends a rejection signal back to the requesting process (rather than silently dropping packets), so you get a fast, clear error instead of a timeout when hitting a blocked destination.

### Self-verification

After setting up rules, the script verifies:

- `example.com` is **unreachable** (firewall is working)
- `api.github.com` is **reachable** (allowlist is working)

The script exits with an error if either check fails.

Because `waitFor: postStartCommand` is set in `devcontainer.json`, VS Code won't connect to the container if the firewall script fails — so you'll never silently end up in an unprotected environment.

---

## Dockerfile - Notable Details

- Based on `mcr.microsoft.com/devcontainers/javascript-node:20` (includes Node.js, git, zsh, Oh My Zsh, and the non-root `node` user)
- Installs network tools (`iptables`, `ipset`, `iproute2`) needed by the firewall script
- Installs `git-delta` for syntax-highlighted git diffs
- Shell history is configured to write immediately on every command (`PROMPT_COMMAND='history -a'`) rather than only when the session ends
- The `/commandhistory` directory is created at **build time** so Docker has a valid path to attach the volume at runtime
- Claude Code is installed globally via `npm install -g @anthropic-ai/claude-code`
- The `node` user is granted passwordless sudo for `init-firewall.sh` only - not general sudo access

### Base image

Built on `mcr.microsoft.com/devcontainers/javascript-node:20`, Microsoft's official Node.js devcontainer image. It comes with Node.js, npm, git, zsh, Oh My Zsh, and a non-root `node` user pre-configured — no need to install or configure any of these manually.

### Network tooling

Installs `iptables`, `ipset`, and `iproute2` — the Linux networking tools required by `init-firewall.sh`. These aren't present in the base image. Without them, the firewall script can't run, and the container startup would fail.

### git-delta

Installs `git-delta` at the pinned version from `devcontainer.json`'s build args. Delta is a syntax highlighter for git diffs — it replaces the default red/green line output with language-aware highlighting, side-by-side views, and line numbers. It integrates via git's `core.pager` config.

### zsh + Oh My Zsh

Zsh and Oh My Zsh come pre-installed from the Microsoft base image. The Dockerfile sets `SHELL=/bin/zsh` and `devcontainer.json` sets it as the default terminal profile. Oh My Zsh provides the plugin/theme framework; no additional prompt theme is installed.

### Shell history behavior

Configures `PROMPT_COMMAND='history -a'` in the shell environment, which flushes the history file after every command rather than only when the session ends. Without this, if the container crashes or you close the terminal abruptly, you lose everything typed since you opened it. Combined with the named volume mounted at `/commandhistory`, this means history is both immediately saved and persists across rebuilds.

The `/commandhistory` directory is created at **build time** inside the Dockerfile. This matters because Docker attaches named volumes at runtime — if the target directory doesn't already exist in the image, Docker creates it as root, which can cause permission errors when the `node` user tries to write to it.

### Claude Code

Installed globally via `npm install -g @anthropic-ai/claude-code` using the `CLAUDE_CODE_VERSION` build arg (default: `latest`). Global installation means the `claude` binary is on the PATH for all users and processes in the container, not just within a specific project's `node_modules`.

### Sudo access

The `node` user is granted passwordless sudo for `/usr/local/bin/init-firewall.sh` specifically — not general sudo. This is done by adding a targeted entry to `/etc/sudoers.d/` rather than adding `node` to the `sudo` group. The distinction matters: general sudo would let Claude Code (or anything else running as `node`) escalate to root arbitrarily. This way, the only privileged operation available is running the firewall script — which is the only thing that actually needs it.
