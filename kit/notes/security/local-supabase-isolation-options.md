# Local Supabase + Devcontainer Isolation — Options Comparison

Captured 2026-04-28 during lalista's devcontainer-host-docker-socket migration session.
Goal: enable `supabase start` for local-dev integration testing without exposing the
host machine to compromise via dev-container tooling.

## TL;DR

For a single-developer macOS workflow:

1. **Apply Docker Desktop File Sharing restriction** (limit to `~/dev/` or your code-projects parent). Mandatory step regardless of which option below you choose. Bounds bind-mount-based file access to your code folder.
2. **Pick the architecture** — see decision matrix below. Default recommendation: **Option 1 (supabase on macOS host)** if you have any other projects under `~/dev/` you'd care about being read by a compromised dev-container tool.

## Threat model

The realistic compromise vectors for a developer's devcontainer:

| Vector                                                        | Probability                                               | Path                                                                                     |
| ------------------------------------------------------------- | --------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Malicious npm transitive dep on `pnpm install`                | Meaningful — supply-chain attacks against npm are routine | Compromised package code runs as `node` user inside dev container during install/runtime |
| Claude approving an unsafe command                            | Moderate — operator-mediated but mistakes happen          | Command runs in dev container's shell                                                    |
| Compromised dev tool (gh, gitleaks, etc.) via package upgrade | Low                                                       | Tool runs in dev container                                                               |
| Compromised Supabase CLI itself                               | Very low — single binary, supabase team, brew tap         | CLI process — wherever it runs                                                           |
| Compromised edge function dependency                          | Low — small dep tree per function                         | Function code runs in supabase edge function runtime container                           |

**Compromise blast radius depends on what the compromised process can reach.** The architectural choice determines what each compromised process can reach.

## macOS-specific reality (Docker Desktop)

On macOS, Docker Desktop runs a Linux VM. All "containers" actually run in that VM, not on macOS. A "host root" escape from a container reaches **VM root**, not macOS root.

**However**, Docker Desktop maintains a File Sharing list of macOS paths that containers can bind-mount. Default: `/Users`, `/Volumes`, `/private`, `/tmp`, `/var/folders`. With docker socket access, a compromised container can `docker run -v /Users:/h alpine` and read your home directory — bypassing the VM boundary via the file-sharing mechanism.

**File Sharing restriction is the load-bearing macOS-side mitigation.** Set it to just your code-projects parent (e.g., `/Users/<you>/dev`) and the bind-mount escape is bounded to that folder.

What File Sharing restriction does NOT address:

- VM kernel exploits (theoretical, not realistic for typical threats)
- Network access to host services (`host.docker.internal` reachable)
- Environment variables in already-running containers
- macOS Keychain — already inaccessible to containers (not file-mounted)

On native Linux, there's no VM layer — docker socket exposure is direct host root. Same options apply but the absolute risk level is higher.

## Other Docker Desktop hardening worth applying alongside File Sharing

| Setting                                            | What it does                                          | Recommendation                                                                       |
| -------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------------ |
| **File Sharing**                                   | Restricts which macOS paths containers can bind-mount | Restrict to `/Users/<you>/dev/` (load-bearing)                                       |
| **Software updates** (auto-update)                 | Ships VM kernel patches that close kernel-escape CVEs | Keep auto-update on. Outdated VM kernels are the realistic VM-escape attack surface. |
| **Disable Kubernetes** (Settings → Kubernetes)     | Bundled K8s is a running attack surface if unused     | Off by default, verify it stays off                                                  |
| **Disable beta/experimental features** unless used | Settings → Features in development                    | Stay on stable channel for security-sensitive workflows                              |
| **Resources → Memory / CPU limits**                | Bounds DoS impact, not security per se                | Set sane caps to prevent runaway containers from impacting macOS responsiveness      |
| **Docker Engine config (advanced JSON)**           | Daemon-level defaults                                 | Add the safety defaults below                                                        |

### Docker Engine JSON additions (Settings → Docker Engine)

```jsonc
{
  // ... existing config ...
  "no-new-privileges": true, // containers can't gain privileges via setuid
  "userland-proxy": false, // smaller network attack surface, slight perf win
  "icc": false, // CAUTION: blocks default-bridge container-to-container; use only if all your stacks define explicit named networks (compose does this automatically)
}
```

`"icc": false` is the riskiest — it disables inter-container communication on the **default** bridge network. Compose stacks with explicit `networks:` blocks (like the Option 3 setup) create dedicated networks where this restriction doesn't apply, so they keep working. But ad-hoc `docker run` containers that relied on the default bridge will lose container-to-container reach. Test before committing.

### Network access to host services — not a Docker Desktop setting

Docker Desktop has no setting that restricts container access to `host.docker.internal:<port>`. Mitigation is on the macOS side:

- Don't run unauthenticated services on macOS localhost during dev sessions (most dev servers default to binding `127.0.0.1` which is NOT directly reachable from containers — Docker Desktop intermediates `host.docker.internal`, but localhost-bound macOS services aren't exposed by default)
- For lalista's typical workflow, `pnpm dev` runs INSIDE the devcontainer, so there's nothing on macOS localhost for a compromised container to reach
- Belt-and-suspenders: macOS `pf` (packet filter) rules can block container subnet from specific ports, but this is fiddly and rarely worth it

### What's NOT helpful

- **macOS firewall** (System Settings → Network → Firewall) — applies to incoming connections to macOS, not container egress. Doesn't help here.
- **Privacy / Telemetry** Docker Desktop settings — orthogonal to threat model
- **VPN / proxy settings** — connectivity-related, not isolation

## The five options

| #     | Approach                              | `supabase start` runs from          | Dev container has docker socket?      | Setup cost                                    | Workflow friction                                         |
| ----- | ------------------------------------- | ----------------------------------- | ------------------------------------- | --------------------------------------------- | --------------------------------------------------------- |
| **1** | **Supabase on macOS host**            | macOS terminal                      | No                                    | ~5 min (`brew install supabase/tap/supabase`) | One extra terminal tab for stack lifecycle                |
| **2** | **Docker socket bind-mount**          | Inside dev container                | Yes                                   | Already done                                  | Zero (single container, all commands work)                |
| **3** | **Two-container compose**             | `supabase-runner` sibling container | No (workspace), yes (supabase-runner) | ~2-4 hrs (compose authoring + env wiring)     | Wrappers needed for stack lifecycle                       |
| **4** | **Docker-in-Docker** (`--privileged`) | Inside dev container, nested daemon | N/A — runs embedded dockerd inside    | Equivalent to #2 setup                        | Same as #2 but with nested-storage performance overhead   |
| **5** | **CI-only** (no local supabase)       | Nowhere locally — slow-job CI only  | No                                    | Zero (revert to pre-fix state)                | Loses local integration test feedback; debug-via-CI-rerun |

## Comparison: blast radius after File Sharing restriction is in place

**Assumption: File Sharing restricted to `/Users/<you>/dev/` (the code-projects parent).**

| Option | Dev-container compromise can reach                                                                                                              | Edge function runtime compromise can reach                              |
| ------ | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **1**  | `/workspace` (current project) + `/devshop` only — no docker socket → no escape primitive                                                       | `supabase/functions/` source dir + network to `host.docker.internal`    |
| **2**  | Everything under `/Users/<you>/dev/` — docker socket lets it spawn `docker run -v /Users/<you>/dev:/h` and reach all projects, not just lalista | Same as Option 1 (edge function runtime is identical container in both) |
| **3**  | `/workspace` + `/devshop` only (workspace has no socket)                                                                                        | Same as Option 1                                                        |
| **4**  | Equivalent to #2; the dev container is privileged, so direct kernel attack surface is more accessible but ultimate reach is the same            | Same as Option 1                                                        |
| **5**  | `/workspace` + `/devshop` only                                                                                                                  | N/A — no edge function runtime running locally                          |

**Key insight:** the load-bearing decision criterion is **whether you have other projects under `/Users/<you>/dev/`** that matter. Options 1, 3, and 5 protect them; Options 2 and 4 don't.

## Edge function exposure (orthogonal caveat)

Edge functions run inside a Deno-based supabase container regardless of which option you pick. Their security profile is **identical** in Options 1, 2, 3, 4 (Option 5 doesn't run them locally).

What edge functions can reach:

- Their own bind-mount (the `supabase/functions/` source dir — under `/Users/<you>/dev/<project>/` either way)
- Network to `host.docker.internal` (any localhost service)
- VM kernel exploits (theoretical)
- NOT the docker socket (supabase CLI doesn't mount it into the function runtime)

Realistic edge function compromise probability is low (small dep tree, narrow execution surface) but blast radius is the same code under `/dev/` that everything else can reach. **Choose between Options 1, 2, 3, 4 based on dev-container exposure, not edge-function exposure** — they're equivalent on the function side.

To reduce edge function exposure specifically, the only structural option is Option 5 (don't run them locally).

## Why Option 4 (DiD with `--privileged`) is not separately recommendable

Earlier framing in the session called this "strictly worse" than the docker socket — that was overstated. They're security-equivalent:

|                              | DiD with `--privileged` (Option 4)                                                                                 | Docker socket bind-mount (Option 2)                                              |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| Bind-mount-based file access | Embedded dockerd can only see paths the outer container has → can't reach `/Users` directly without first escaping | Spawn sibling via host engine → File Sharing allows `/Users/<you>/dev/` directly |
| Kernel exploit attempt       | Direct from dev container (privileged outer, one step)                                                             | Via spawning a privileged sibling (two steps)                                    |
| Operational                  | Nested storage overhead, networking quirks                                                                         | Standard, simple                                                                 |

Net: Option 4 makes kernel exploits more direct; Option 2 makes bind-mount escapes more direct. Equivalent ultimate reach. Option 2 wins on operational simplicity, which is why Option 4 isn't a meaningful distinct choice.

## Operational details for the recommended option (Option 1)

### Setup (one-time)

```bash
# On macOS:
brew install supabase/tap/supabase
cd ~/dev/<project>
supabase start          # spins up the local stack; leave running
```

### Devcontainer.json adjustments (vs the current Option 2 shape)

- Remove `/var/run/docker.sock` bind-mount from `mounts`
- Add `host.docker.internal:host-gateway` to `runArgs` (only matters on Linux native; harmless on macOS)
- Remove docker CLI install block from Dockerfile
- Remove `init-docker-socket.sh` (no socket to align)
- Keep the `init-firewall.sh` Supabase-host removals (still correct under Option 1)

### Project env config

Point local-dev Supabase URL at `host.docker.internal:54321` instead of `127.0.0.1:54321`. On Docker Desktop this resolves to the macOS host's localhost; on Linux native it resolves via the `host-gateway` runArg.

### Daily workflow

| Action                                                                                                      | Where it runs                                                          |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| Write/edit migration SQL                                                                                    | Inside devcontainer (file is bind-mounted, appears on macOS instantly) |
| `supabase db reset` (apply migrations + reseed)                                                             | macOS terminal (`cd ~/dev/<project> && supabase db reset`)             |
| `supabase gen types typescript --db-url postgresql://postgres:postgres@host.docker.internal:54322/postgres` | Inside devcontainer (TCP to host stack)                                |
| `supabase functions serve`                                                                                  | Inside devcontainer (Deno runs natively, talks to Postgres via TCP)    |
| `pnpm test:integration`                                                                                     | Inside devcontainer (TCP to host stack)                                |
| `pnpm dev`                                                                                                  | Inside devcontainer (frontend dev server)                              |
| `supabase status`                                                                                           | macOS terminal (talks to local docker daemon)                          |

The only command that **must** run from the macOS side is `supabase db reset` (and other stack-lifecycle commands like `start`, `stop`, `status`). Everything code-side stays in the devcontainer.

## Operational details for Option 3 (compose isolation)

If you specifically don't want supabase tooling on macOS:

### `.devcontainer/compose.yml` shape

```yaml
services:
  workspace:
    build: ./.devcontainer
    volumes:
      - ../:/workspace
    networks: [supabase-net]
    # NO /var/run/docker.sock mount, NO --privileged

  supabase-runner:
    build: ./.devcontainer/supabase-runner
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # exposure isolated here
      - ../supabase:/supabase # narrow bind: just the supabase subdir
      - supabase-data:/var/lib/supabase
    networks: [supabase-net]
    ports:
      - '54321:54321'
      - '54322:54322'
    command:
      [
        'sh',
        '-c',
        'cd /supabase && supabase start && /usr/local/bin/cmd-relay.mjs',
      ]

networks:
  supabase-net:

volumes:
  supabase-data:
```

**Why bind just `<project>/supabase/` and not `<project>/`**: principle of least privilege within the compose. The runner only needs `supabase/migrations/`, `supabase/functions/`, `supabase/seed.sql`, `supabase/config.toml` — not `apps/web/`, `node_modules/`, or other code. A runner compromise then can't read frontend code that has nothing to do with Supabase. The bind-mount is otherwise identical in mechanics to macOS host-side: write a migration in the workspace at `/workspace/supabase/migrations/0XX_name.sql` and it appears in the runner at `/supabase/migrations/0XX_name.sql` instantly.

### Devcontainer.json change

```jsonc
{
  "dockerComposeFile": "compose.yml",
  "service": "workspace",
  "workspaceFolder": "/workspace",
  // ... other config
}
```

### How Claude invokes supabase orchestration commands without docker socket access

The workspace has no docker socket, so `docker compose exec supabase-runner ...` doesn't work. Four mechanisms for letting Claude (or scripts) invoke supabase commands in the runner, ordered by recommendation:

**Recommended: tiny RPC server inside the runner with command whitelist** (~30 lines):

```javascript
// /usr/local/bin/cmd-relay.mjs — runs after `supabase start`, listens on docker network
import { createServer } from 'node:http';
import { spawn } from 'node:child_process';
const ALLOWED = {
  'db-reset': ['supabase', 'db', 'reset'],
  status: ['supabase', 'status'],
  start: ['supabase', 'start'],
  stop: ['supabase', 'stop'],
  'gen-types': ['supabase', 'gen', 'types', 'typescript', '--local'],
};
createServer((req, res) => {
  const cmd = ALLOWED[req.url.replace(/^\//, '')];
  if (!cmd) {
    res.writeHead(403);
    res.end('blocked\n');
    return;
  }
  const p = spawn(cmd[0], cmd.slice(1), { cwd: '/supabase' });
  p.stdout.pipe(res);
  p.stderr.pipe(res);
  p.on('close', (code) => res.end(`\n[exit ${code}]\n`));
}).listen(9000, '0.0.0.0');
```

Workspace `pnpm db:reset` becomes `curl -X POST http://supabase-runner:9000/db-reset`. Whitelist is explicit and auditable; arbitrary commands are blocked at the relay layer. Same pattern for any other supabase orchestration.

**Alternative: restricted SSH via `command=` forced key**. Workspace SSHes to runner with a key restricted to a single dispatch script that whitelists commands. More setup (SSH server in image, key management) for similar effect. Use if you want to reuse SSH tooling.

**Alternative: filtered docker socket via `tecnativa/docker-socket-proxy`**. Add a third compose service that proxies the socket with API filtering. Workspace gets `DOCKER_HOST=tcp://docker-proxy:2375` and uses standard `docker compose exec`. Most idiomatic but biggest dependency; configuration tuning has historically had subtle bugs allowing more API surface than intended.

**Fallback: user runs from macOS host**. `docker compose exec supabase-runner supabase db reset` from a host terminal. Simplest if you don't need Claude autonomy for stack lifecycle commands.

### Daily workflow

| Action                          | Where                 | How                                                                                                                                                |
| ------------------------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Write/edit migration SQL        | Workspace             | Direct file edit; appears in runner instantly via bind-mount                                                                                       |
| `supabase db reset`             | Workspace (via relay) | `curl -X POST http://supabase-runner:9000/db-reset` (or `pnpm db:reset` wrapper)                                                                   |
| `supabase status`               | Workspace (via relay) | `curl http://supabase-runner:9000/status`                                                                                                          |
| `supabase gen types typescript` | Workspace             | Direct: `supabase gen types typescript --db-url postgresql://postgres:postgres@supabase-runner:54322/postgres` (no docker access needed; TCP only) |
| `supabase functions serve`      | Workspace             | Deno runs natively; talks to runner's Postgres via TCP                                                                                             |
| `pnpm test:integration`         | Workspace             | Tests connect to `http://supabase-runner:54321`                                                                                                    |
| `pnpm dev`                      | Workspace             | Frontend dev server                                                                                                                                |

## Decision matrix

| If...                                                                                                  | Pick                                                                                          |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| You have other projects under `~/dev/` whose code you'd not want a compromised lalista npm dep to read | **Option 1** (default recommendation)                                                         |
| Same as above, but you actively don't want supabase CLI on macOS                                       | **Option 3**                                                                                  |
| `~/dev/` will only ever contain this one project family (lalista + abra-kadabra)                       | **Option 2** is acceptable — File Sharing restriction bounds the blast                        |
| You only need integration tests in CI, never locally                                                   | **Option 5**                                                                                  |
| You're on native Linux (not Docker Desktop) and want comprehensive isolation                           | **Option 1 with rootless docker on the host** — separate hardening, orthogonal to this matrix |

## What's not addressed by any of these options

- **Already-running container's environment variables** — the dev container reads `--env-file .devcontainer/.env` at create time. A compromised process inside can read `/proc/<pid>/environ` and exfiltrate any tokens that were passed in. Mitigation: keep `.devcontainer/.env` minimal (no prod tokens).
- **Network access to host services** — any container can reach `host.docker.internal:<port>` for services bound to localhost on macOS. If you run sensitive dev servers on macOS that don't authenticate, a compromised container can hit them. Mitigation: don't run unauthenticated services on host localhost during dev sessions.
- **macOS Keychain** — already inaccessible to containers regardless of File Sharing. Out of scope.
- **macOS-level system compromise** — none of these options enable it; macOS kernel is unreachable from containers.
- **Supabase CLI supply-chain compromise** — affects Options 1, 2, 3, 4 equally (the CLI is somewhere in all of them).

## Cross-references

- `kit/docs/guide/security.md § CI Credential Isolation` — separate concern (credentials in CI), but related principle (concentrate exposure at narrowest necessary surface)
- `kit/notes/roadmap/qa-options.md` — original QA-backend isolation discussion
- `template/.devcontainer/devcontainer.json` § mounts — the comment block explains why the host-socket approach was picked over DiD when interlude (d) shipped on 2026-04-27
- `kit/ROADMAP.md § Migration sequencing safety nets for the Vercel-preview window § Out of scope` — preview-side backend isolation (Vercel previews dial prod) is a separate concern from local-dev isolation; documented there

## When to revisit

- A second project adopts the devshop and the operator picks a different default — codify whichever default emerges as a `/ak-new-project` option choice
- Sysbox or rootless docker matures enough on macOS to be worth the dependency — would change Option 4's viability
- Docker Desktop's Enhanced Container Isolation (paid Docker Business) becomes default-available — would change the default's threat model
