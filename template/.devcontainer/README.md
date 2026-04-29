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
- Sibling `supabase-runner` container for local Supabase stack (Option 3 compose isolation — workspace itself has NO docker access)

---

## Getting started

1. Create `.devcontainer/.env` (copy from `.env.example` if your project ships one). The file holds **project-runtime** secrets (Supabase tokens, Vercel token, etc.) — see your project's `/ak-new-project` Step 4 for the full list.
2. (macOS one-time) Add `127.0.0.1 host.docker.internal` to `/etc/hosts` so the macOS browser resolves the same hostname containers use to reach the local Supabase stack:
   ```sh
   echo '127.0.0.1 host.docker.internal' | sudo tee -a /etc/hosts
   ```
   Idempotent — skip if the line is already there.
3. Open the project in VS Code and select **Reopen in Container**
4. Run `claude` in the terminal — onboarding is auto-skipped, so Claude Code is ready immediately

> **Anthropic API key** — if your project's edge functions call Claude at runtime, add `ANTHROPIC_API_KEY_QA=...` to `.devcontainer/.env`. The `QA_` prefix is deliberate: Claude Code in the devcontainer auto-detects a bare `ANTHROPIC_API_KEY` as its own auth credential and prompts the operator at every start, even when the key is meant for the project's runtime, not Claude Code itself. The prefix dodges that detection. The corresponding prod key (`ANTHROPIC_API_KEY_PROD`) MUST NEVER live in this file — it lives only in GitHub Secrets and the Supabase project secrets pushed by `deploy-functions.yml`. See your project's `/ak-new-project` § Security Posture for the QA/PROD split rationale.

> **Claude Code auth** — Claude Code uses your VS Code extension login or your subscription session by default; you don't need to put your Claude Code API key in this `.env` unless you're explicitly opting into pay-as-you-go API billing for the CLI itself.

---

## Key decisions

- **ESLint for code quality only** — formatting is handled entirely by Prettier; no overlap between the two
- **EditorConfig as source of truth** — universal formatting rules (indent, line endings, charset) that apply in any editor or CI environment
- **`.devcontainer/.env` holds project-runtime secrets only** — Claude Code auth runs through the VS Code extension or your subscription session, not via env-var. Project-runtime keys (Supabase, Vercel, optional `ANTHROPIC_API_KEY_QA` for projects whose edge functions call Claude) go in `.env`. Prod keys never live here.
- **`waitFor: postStartCommand`** — VS Code won't connect until the firewall script succeeds, so you're never silently in an unprotected environment
- **Two-container compose isolation (Option 3)** — workspace dev container has no docker socket; the sibling `supabase-runner` holds the socket and runs `supabase start` against the host engine. A compromised devtool / npm dep in the workspace cannot spawn `docker run -v /Users:/h alpine` to escape into the host's File Sharing. Architecture rationale + lifecycle table: [`/devshop/kit/docs/guide/local-supabase-compose-isolation.md`](../../devshop/kit/docs/guide/local-supabase-compose-isolation.md). Threat-model + decision matrix: [`/devshop/kit/notes/security/local-supabase-isolation-options.md`](../../devshop/kit/notes/security/local-supabase-isolation-options.md).

---

## Python projects

Swap the base image in the workspace `Dockerfile` (or in `compose.yml`'s build args if you templatize the base):

```Dockerfile
FROM mcr.microsoft.com/devcontainers/python:3.12
```

Then replace ESLint/Prettier with Python equivalents (e.g. `ruff` for both linting and formatting).

---

## Files

| File                | Purpose                                                                                                                                                                                                                                                                     |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `devcontainer.json` | Tells VS Code which compose file + service to attach to; runtime env, mounts (named volumes + devshop bind), postCreate / postStart commands, `initializeCommand`                                                                                                           |
| `compose.yml`       | Two-service compose project (workspace + supabase-runner). Build args, networks, volumes, env, runner's socat tunnels + `supabase start` + cmd-relay command. Source of truth for tool versions.                                                                            |
| `Dockerfile`        | Builds the workspace image                                                                                                                                                                                                                                                  |
| `supabase-runner/`  | Sibling-container `Dockerfile` + `cmd-relay.mjs` — holds `/var/run/docker.sock`, runs `supabase start`, exposes a whitelisted RPC relay on `:9000` so the workspace can drive `pnpm db:reset` / `db:status` / `db:start` / `db:stop` / `db:gen-types` without docker access |
| `init-firewall.sh`  | Locks down outbound network access on every container start (workspace only)                                                                                                                                                                                                |
| `init-host-env.sh`  | Runs on the macOS host BEFORE compose-up via `initializeCommand`; auto-writes `LOCAL_WORKSPACE_FOLDER=<host-path>` into `.devcontainer/.env` so compose can interpolate the supabase-runner's host-path-mirrored bind                                                       |
| `init-devshop.sh`   | Sets up the devshop bind-mount + symlinks at container start (creates `.devshopkit`, copies locked configs)                                                                                                                                                                 |

---

## Container settings — compose.yml + devcontainer.json

Settings that affect the container at build / run time live in `compose.yml` (per Option 3 — VS Code attaches via `dockerComposeFile`). Settings that are VS-Code-specific or need devcontainer interpolation (`${devcontainerId}`, `${localWorkspaceFolder}`) stay in `devcontainer.json` and are additive on top of the compose service config.

### Build Args

```yaml
# compose.yml, under services.workspace.build.args:
TZ: ${TZ:-America/Los_Angeles}
CLAUDE_CODE_VERSION: latest
GIT_DELTA_VERSION: 0.19.2
SUPABASE_CLI_VERSION: 2.84.2
DCG_VERSION: 0.4.0
GITLEAKS_VERSION: 8.30.1
```

- `compose.yml` is the **single source of truth** for tool versions (moved here from `devcontainer.json` when Option 3 compose isolation shipped — the workspace's `build:` block moved with it). The Dockerfile ARGs have no defaults, so the build fails loudly if a version is missing here.
- The same `GITLEAKS_VERSION:` line is read by `.github/workflows/ci.yml` to fetch a matching binary on the GH runner — keep the YAML key shape stable so the workflow's `grep | sed` extraction keeps working.
- Pinned versions are a tradeoff: you get reproducible builds, but you have to manually bump them to get updates (tools like Dependabot can automate this).
- `CLAUDE_CODE_VERSION` is intentionally left as `latest` since Claude Code is the primary tool and staying current is preferred over strict pinning.

### Network Capabilities

```yaml
# compose.yml, under services.workspace.cap_add:
- NET_ADMIN
- NET_RAW
```

Docker containers run with restricted Linux capabilities by default. These two grant the workspace container permission to manipulate firewall rules:

- `NET_ADMIN` - required to run `iptables` and `ipset` commands
- `NET_RAW` - required for raw network sockets used internally by iptables

These capabilities persist for the container's lifetime. There is no clean built-in way to drop them after the firewall script finishes — `cap_add` applies at start and cannot be revoked mid-lifecycle. The `supabase-runner` sibling does NOT get these caps (it doesn't run init-firewall.sh).

### VS Code Extensions

```jsonc
// devcontainer.json, under customizations.vscode:
"extensions": [
  "anthropic.claude-code",
  "EditorConfig.EditorConfig",
  "dbaeumer.vscode-eslint",
  "esbenp.prettier-vscode"
]
```

Installed automatically into the VS Code instance running inside the workspace container.

### Terminal Settings

```jsonc
// devcontainer.json, under customizations.vscode.settings:
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

```jsonc
// devcontainer.json:
"remoteUser": "node"
```

VS Code connects as the `node` user (built into the Microsoft devcontainer base image) rather than `root`. This limits what can go wrong if something misbehaves. The only exception is `init-firewall.sh` and `init-devshop.sh`, which need root — the Dockerfile grants `node` passwordless sudo for those scripts specifically.

### Volumes (Persistent Storage)

```jsonc
// devcontainer.json mounts (additive on top of compose volumes):
"mounts": [
  "source=claude-code-bashhistory-${devcontainerId},target=/commandhistory,type=volume",
  "source=claude-code-config-${devcontainerId},target=/home/node/.claude,type=volume",
  "source=${localWorkspaceFolder}/../abra-kadabra,target=/devshop,type=bind,consistency=delegated"
]
```

These are applied IN ADDITION to the volumes declared on the workspace service in `compose.yml` (which has the `..:/workspace:cached` workspace bind). Why split: entries that need devcontainer-style interpolation (`${devcontainerId}`, `${localWorkspaceFolder}`) stay here; everything else lives in compose.yml.

Two named volumes survive container rebuilds:

- `/commandhistory` - your shell history (bash/zsh)
- `/home/node/.claude` - Claude Code config and session history

Important caveats:

- These are **not** stored on your Mac's filesystem - they live inside Docker's Linux VM, invisible to Finder and not backed up by Time Machine
- They are **lost if you move to a new machine** - your session history won't carry over (the API key comes from `.devcontainer/.env`, so that's fine)
- The `${devcontainerId}` suffix ensures each project gets its own isolated volumes
- `${devcontainerId}` is a hash of the project's local-folder path **and** the dev container schema (single-container vs compose). Switching between schemas — e.g. an older single-container setup → Option 3 compose — yields a different `devcontainerId`, so the named volumes are NOT shared across schema changes. (This is why a fresh `claude` in a newly-attached compose-stack workspace asks you to log in again rather than picking up your prior session.)

This is different from your workspace folder, which is a **bind mount** - a direct portal to your Mac's filesystem:

|                            | Named Volume (`type=volume`) | Bind Mount (`type=bind`) |
| -------------------------- | ---------------------------- | ------------------------ |
| Visible in Finder          | ❌                           | ✅                       |
| Backed up by Time Machine  | ❌                           | ✅                       |
| Survives container rebuild | ✅                           | ✅                       |
| Lost on new machine        | ✅                           | ❌                       |

### Workspace Mount

```yaml
# compose.yml, under services.workspace.volumes:
- ..:/workspace:cached
```

The `..` is relative to compose.yml's directory (`.devcontainer/`), so it resolves to the project root on the host. The `:cached` consistency flag is a macOS performance hint - it lets Docker sync file changes back to the Mac lazily, which meaningfully improves I/O speed (Mac↔Linux VM file syncing is a known Docker bottleneck).

`devcontainer.json` sets `workspaceFolder: /workspace` so VS Code knows where to open the project inside the container.

### Environment Variables

```jsonc
// devcontainer.json, under containerEnv:
"NODE_OPTIONS": "--max-old-space-size=4096"
// ...plus a few more (turbo telemetry, gstack state dir, Playwright Chromium path)

// AND, in compose.yml under services.workspace.environment:
SUPABASE_URL: http://host.docker.internal:54321
SUPABASE_ANON_KEY: <well-known supabase-local default JWT>
SUPABASE_SERVICE_ROLE_KEY: <well-known supabase-local default JWT>
```

- `NODE_OPTIONS` raises Node.js heap to 4GB. Claude Code is a Node.js process and can be memory-hungry on large codebases; the default limit (~512MB-1GB) can cause crashes.
- `SUPABASE_URL` + the two key vars are auto-set on every workspace start so vitest, integration tests, ad-hoc supabase-js scripts work without any manual env-prefix. The keys are the published well-known supabase-local defaults (deterministic from the default `JWT_SECRET` in `supabase/config.toml` — same values CI uses; not real secrets). Vercel/prod env is on a separate surface and untouched.

### Startup

```jsonc
// devcontainer.json:
"initializeCommand": ["bash", "${localWorkspaceFolder}/.devcontainer/init-host-env.sh", "${localWorkspaceFolder}"],
"postCreateCommand": "echo '{\"hasCompletedOnboarding\": true}' > ~/.claude.json && pnpm install",
"postStartCommand": "sudo /usr/local/bin/init-firewall.sh && sudo /usr/local/bin/init-devshop.sh && ([ -n \"$GITHUB_TOKEN\" ] && gh auth setup-git || true)",
"waitFor": "postStartCommand"
```

- `initializeCommand` runs **on the host** (macOS) before compose-up. Writes `LOCAL_WORKSPACE_FOLDER=<absolute host path>` into `.devcontainer/.env` so compose can interpolate the supabase-runner's host-path-mirrored bind. Idempotent; refreshes on every Rebuild Container.
- `postCreateCommand` runs once on first container creation: writes the Claude Code onboarding-skip flag and runs `pnpm install`.
- `postStartCommand` runs the firewall + devshop setup on every start (not just first build) and configures `gh` auth if a token is present. `waitFor` tells VS Code to wait for this to complete before connecting — ensuring the firewall is always in place before any work begins.

### supabase-runner sibling

```yaml
# compose.yml, under services.supabase-runner:
build:
  context: ./supabase-runner
  args:
    SUPABASE_CLI_VERSION: 2.84.2
volumes:
  - ${LOCAL_WORKSPACE_FOLDER}/supabase:${LOCAL_WORKSPACE_FOLDER}/supabase
  - /var/run/docker.sock:/var/run/docker.sock
networks: [supabase-net]
working_dir: ${LOCAL_WORKSPACE_FOLDER}/supabase
command:
  - sh
  - -c
  - |
    socat -d TCP-LISTEN:54321,fork,reuseaddr,bind=127.0.0.1 TCP:host.docker.internal:54321 &
    socat -d TCP-LISTEN:54322,fork,reuseaddr,bind=127.0.0.1 TCP:host.docker.internal:54322 &
    sleep 0.5
    supabase start
    exec /usr/local/bin/cmd-relay.mjs
```

The runner holds the docker socket and a NARROW bind (only `<host>/supabase`, not the whole repo). `supabase start` spawns sibling containers (`supabase_db_<project>`, `supabase_kong_<project>`, etc.) on the HOST docker engine — those siblings bind ports 54321/54322 directly to the host. The socat tunnels work around supabase CLI's hardcoded-localhost healthcheck (the runner's loopback isn't where the spawned siblings are listening; host.docker.internal is). Workspace reaches the relay (port 9000) via compose-internal DNS as `supabase-runner:9000`; reaches the data plane (54321/54322) via `host.docker.internal:54321/54322` (Docker Desktop auto-resolves the hostname inside containers; macOS browser resolves it via the `127.0.0.1 host.docker.internal` `/etc/hosts` entry from "Getting started" Step 2).

Full architecture + lifecycle table + smoke tests + debugging tree: see [`/devshop/kit/docs/guide/local-supabase-compose-isolation.md`](../../devshop/kit/docs/guide/local-supabase-compose-isolation.md).

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
- `host.docker.internal:54321/54322` (Option 3 — supabase data plane bound on the host by spawned siblings; resolved via `getent ahostsv4` to force IPv4 since iptables is IPv4-only and Docker Desktop's resolution can flip to IPv6 between restarts)
- GitHub IP ranges (fetched dynamically from `api.github.com/meta`) + GitHub Actions artifact-storage Azure Blob shards
- Specific domains: `registry.npmjs.org`, `api.anthropic.com`, `sentry.io`, `statsig.anthropic.com`, `statsig.com`, VS Code marketplace and update servers, Playwright CDNs, Vercel API + project domain (filled in by `/ak-new-project`), Sentry ingest endpoint (filled in by `/ak-new-project`), PostHog ingest, the project's `<ref>.supabase.co` data-plane host (anon-key data plane only — added by `/ak-new-project` Step 6)

`api.supabase.com` (control plane) and `aws-0-us-west-2.pooler.supabase.com` (connection pooler) are deliberately NOT in the allowlist under Option 3 — migrations + functions deploy from CI on push-to-main; the local stack runs in the sibling `supabase-runner` and is reached through host-port forwarding, not through Supabase's public APIs.

`download.docker.com` / `registry-1.docker.io` / `auth.docker.io` / `production.cloudflare.docker.com` are also deliberately NOT in the workspace allowlist — Option 3's workspace has no docker CLI install, so it never fetches Docker tooling at build or runtime. The supabase-runner sibling does fetch Docker tooling at build time, but it doesn't run this firewall script.

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
- Installs `gh` (GitHub CLI), `chromium` + Playwright shared libs, `supabase` CLI (for migration filesystem operations + TCP-only type-gen), `dcg` (PreToolUse safety hook), `gitleaks` (secret scanning)
- Shell history is configured to write immediately on every command (`PROMPT_COMMAND='history -a'`) rather than only when the session ends
- The `/commandhistory` directory is created at **build time** so Docker has a valid path to attach the volume at runtime
- Claude Code is installed globally via `npm install -g @anthropic-ai/claude-code`
- The `node` user is granted passwordless sudo for `init-firewall.sh` and `init-devshop.sh` only - not general sudo access
- The workspace Dockerfile does NOT install the docker CLI (Option 3 — workspace has no docker access). The runner's separate `supabase-runner/Dockerfile` is the only image with the docker CLI.

### Base image

Built on `mcr.microsoft.com/devcontainers/javascript-node:20`, Microsoft's official Node.js devcontainer image. It comes with Node.js, npm, git, zsh, Oh My Zsh, and a non-root `node` user pre-configured — no need to install or configure any of these manually.

### Network tooling

Installs `iptables`, `ipset`, and `iproute2` — the Linux networking tools required by `init-firewall.sh`. These aren't present in the base image. Without them, the firewall script can't run, and the container startup would fail.

### git-delta

Installs `git-delta` at the pinned version from `compose.yml`'s build args. Delta is a syntax highlighter for git diffs — it replaces the default red/green line output with language-aware highlighting, side-by-side views, and line numbers. It integrates via git's `core.pager` config.

### zsh + Oh My Zsh

Zsh and Oh My Zsh come pre-installed from the Microsoft base image. The Dockerfile sets `SHELL=/bin/zsh` and `devcontainer.json` sets it as the default terminal profile. Oh My Zsh provides the plugin/theme framework; no additional prompt theme is installed.

### Shell history behavior

Configures `PROMPT_COMMAND='history -a'` in the shell environment, which flushes the history file after every command rather than only when the session ends. Without this, if the container crashes or you close the terminal abruptly, you lose everything typed since you opened it. Combined with the named volume mounted at `/commandhistory`, this means history is both immediately saved and persists across rebuilds.

The `/commandhistory` directory is created at **build time** inside the Dockerfile. This matters because Docker attaches named volumes at runtime — if the target directory doesn't already exist in the image, Docker creates it as root, which can cause permission errors when the `node` user tries to write to it.

### Claude Code

Installed globally via `npm install -g @anthropic-ai/claude-code` using the `CLAUDE_CODE_VERSION` build arg (default: `latest`, set in `compose.yml`). Global installation means the `claude` binary is on the PATH for all users and processes in the container, not just within a specific project's `node_modules`.

### Sudo access

The `node` user is granted passwordless sudo for `/usr/local/bin/init-firewall.sh` and `/usr/local/bin/init-devshop.sh` specifically — not general sudo. This is done by adding targeted entries to `/etc/sudoers.d/` rather than adding `node` to the `sudo` group. The distinction matters: general sudo would let Claude Code (or anything else running as `node`) escalate to root arbitrarily. This way, the only privileged operations available are running those two scripts — which are the only things that actually need it.
