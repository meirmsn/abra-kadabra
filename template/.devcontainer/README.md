# Dev Container

Sandboxed two-container (workspace + supabase-runner) dev environment with allowlist-only firewall. Workspace has no docker access; the runner sibling holds the socket.

Adapted from: https://github.com/anthropics/claude-code/tree/main/.devcontainer

## Getting started

1. Create `.devcontainer/.env` (copy from `.env.example` if your project ships one). Holds **project-runtime** secrets only — see `/ak-new-project` Step 4 for the full list.
2. (macOS one-time) Add `127.0.0.1 host.docker.internal` to `/etc/hosts` so the browser resolves the same hostname containers use:
   ```sh
   echo '127.0.0.1 host.docker.internal' | sudo tee -a /etc/hosts
   ```
3. Open the project in VS Code → **Reopen in Container**
4. Run `claude` in the terminal

> **Anthropic API key** — if your edge functions call Claude at runtime, use `ANTHROPIC_API_KEY_QA=...` in `.env`. The `QA_` prefix dodges Claude Code's auto-detection of a bare `ANTHROPIC_API_KEY` as its own auth credential. Prod key (`ANTHROPIC_API_KEY_PROD`) lives only in GitHub Secrets + Supabase project secrets.

> **Claude Code auth** — uses your VS Code extension login or subscription session by default; no API key in `.env` unless you're opting into pay-as-you-go CLI billing.

## Non-obvious details

### Compose isolation rationale

Workspace has no docker socket — a compromised devtool or npm dep cannot `docker run -v /Users:/h alpine` to escape into the host. The runner sibling holds the socket with a narrow bind (only `<host>/supabase`, not the whole repo). Full architecture: `kit/docs/guide/local-supabase-compose-isolation.md`. Threat model: `kit/notes/security/local-supabase-isolation-options.md`.

### Firewall guarantee

`waitFor: postStartCommand` blocks VS Code from connecting until `init-firewall.sh` succeeds + self-verifies (`example.com` unreachable, `api.github.com` reachable). You're never silently in an unprotected environment.

Domain IPs are resolved once at startup — if a service rotates IPs mid-session, rules go stale until restart. See `kit/docs/guide/ops.md § Firewall IP rotation`.

### Firewall deliberate exclusions

- `api.supabase.com` (control plane) and `aws-0-us-west-2.pooler.supabase.com` (pooler) — migrations + functions deploy from CI; local stack runs in the runner via host-port forwarding.
- `download.docker.com` / `registry-1.docker.io` — workspace has no docker CLI; runner fetches at build time only.

### Named volumes are invisible to macOS

Shell history and Claude Code config use Docker named volumes — they survive rebuilds but live inside Docker's Linux VM. **Not** backed up by Time Machine. **Lost on machine migration.** `${devcontainerId}` is derived from the project path AND the devcontainer schema — switching from single-container to compose yields a different ID, so volumes don't carry over.

### macOS file sync performance

`consistency=cached` (compose) / `consistency=delegated` (devcontainer mounts) lets Docker sync lazily, improving I/O on the known Docker-for-Mac bottleneck.

### Build-time directory creation

`/commandhistory` is created at build time because Docker attaches named volumes at runtime — if the target doesn't exist in the image, Docker creates it as root, causing permission errors for the `node` user.

### Sudo scoping

`node` has passwordless sudo only for `init-firewall.sh`, `init-devshop.sh`, and `refresh-allowed-ips.sh` — not general sudo. General sudo would let anything running as `node` escalate to root.

### Supabase CLI version pinning

Projects inherit the devshop default version. To pin a different version, add `SUPABASE_CLI_VERSION=X.Y.Z` to `.devcontainer/.env`. The Dockerfile verifies against the release's published checksum file, so any version works without devshop-side changes. See `kit/docs/guide/ops.md § Supabase CLI version pinning`.

### supabase-runner socat tunnels

`supabase start` spawns sibling containers on the HOST docker engine — their ports bind to the host, not to the runner's loopback. The socat tunnels forward `127.0.0.1:<port>` inside the runner to `host.docker.internal:<port>` so supabase CLI's hardcoded-localhost healthcheck works. Without them, `supabase start` fails with "connection refused."

### Gitleaks version sync with CI

`.github/workflows/ci.yml` extracts `GITLEAKS_VERSION` from `compose.yml` via `grep | sed` — keep the YAML key shape stable.
