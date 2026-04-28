# Local Supabase via two-container compose isolation (Option 3)

How a project's dev container runs `supabase start` for local-dev integration tests **without** giving the workspace docker socket access. This is the recommended setup for projects with other code under `~/dev/` whose contents a compromised npm dep (transitive or otherwise) should not be able to read.

For the threat-model + decision matrix that picked this architecture over four alternatives, see [`/devshop/kit/notes/security/local-supabase-isolation-options.md`](../../notes/security/local-supabase-isolation-options.md). Adopted in lalista PR 34 (`devcontainer-compose-isolated`, 2026-04-28); pattern reference for `/ak-new-project` template work captured in `kit/TODOS.md § lalista-option3-template-variant`.

## TL;DR architecture

```
macOS host
├── Docker Desktop VM (Linux)
│   ├── lalista_devcontainer (compose project)
│   │   ├── workspace          ← dev container, NO docker socket, NO docker CLI
│   │   └── supabase-runner    ← holds /var/run/docker.sock + narrow `<host>/supabase` bind
│   │       │                    runs `supabase start` and a ~30-line HTTP relay on :9000
│   │       └─ socat tunnels   ← 127.0.0.1:54321/54322 → host.docker.internal:54321/54322
│   │                            (works around supabase CLI's hardcoded localhost)
│   │
│   └── supabase_*_workspace   ← spawned siblings on the host engine (not part of the
│       ├── supabase_db_workspace      compose project). Bind ports 54321/54322 to the
│       ├── supabase_kong_workspace    HOST engine. supabase CLI manages their lifecycle
│       ├── supabase_auth_workspace    via the docker socket.
│       └── ... (10+ containers)       Have `restart: always` set by supabase CLI.
│
└── /etc/hosts: 127.0.0.1 host.docker.internal   ← so the macOS browser also resolves
                                                   the same hostname the workspace does
```

**Two hostnames, two purposes:**

- `supabase-runner:9000` — compose-internal DNS, only reachable from the workspace. Used by `pnpm db:reset` / `db:status` / `db:start` / `db:stop` / `db:gen-types` to drive the supabase stack lifecycle through a whitelisted RPC relay.
- `host.docker.internal:54321` (REST/GraphQL/Functions), `host.docker.internal:54322` (Postgres) — the supabase data plane. Reachable from both the workspace (Docker Desktop auto-resolves it inside containers) and the macOS browser (after the operator adds the `/etc/hosts` entry). Same hostname both contexts → `NEXT_PUBLIC_SUPABASE_URL` stays single-valued.

## Host-side touchpoints

These exist on the macOS host (or Linux native) and are not visible inside any container. Future operators looking for "what's the manual setup" — it's exactly this list.

| Surface                                              | What                                                                 | Why                                                                                                                                                                                                                                                                                                                                                                                | How it gets set                                                                                                                                                                  |
| ---------------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.devcontainer/.env` (gitignored)                    | `LOCAL_WORKSPACE_FOLDER=<absolute host path>`                        | docker compose has no built-in interpolation for "host pwd"; VS Code Dev Containers does not auto-export `${localWorkspaceFolder}` as a compose-readable env var. The runner needs the host path string at compose-up time so its bind mount mirrors the host's view (supabase CLI's `docker run -v ...` calls go to the host engine, which resolves paths on its OWN filesystem). | Auto-written by `.devcontainer/init-host-env.sh`, invoked via `initializeCommand` in devcontainer.json before every container start. Idempotent; refreshes on Rebuild Container. |
| macOS `/etc/hosts`                                   | `127.0.0.1 host.docker.internal`                                     | macOS browser must resolve the same hostname the workspace does, so XHR calls from the React app reach the supabase REST API. Docker Desktop only injects `host.docker.internal` into containers, not into macOS itself.                                                                                                                                                           | One-time manual step, run from a macOS terminal: `sudo sh -c 'grep -q host.docker.internal /etc/hosts \|\| echo "127.0.0.1 host.docker.internal" >> /etc/hosts'`                 |
| `apps/web/.env.local` (gitignored)                   | `NEXT_PUBLIC_SUPABASE_URL=http://host.docker.internal:54321`         | Next.js client + server both read this var; both contexts resolve the hostname to the supabase data plane via Docker Desktop / `/etc/hosts`.                                                                                                                                                                                                                                       | Per-developer manual once; documented in project CLAUDE.md § Env Var Naming.                                                                                                     |
| Docker Desktop → Settings → Resources → File Sharing | Restrict to `/Users/<you>/dev` (your code-projects parent)           | Bounds bind-mount-based file access if a container ever does break out via the docker socket (which only the runner has, and only with a narrow `supabase/` bind anyway). Load-bearing macOS-side mitigation.                                                                                                                                                                      | Manual once, in Docker Desktop UI. Apply & Restart.                                                                                                                              |
| Docker Desktop → Settings → Docker Engine (JSON)     | `{"no-new-privileges": true, "userland-proxy": false, "icc": false}` | Belt-and-suspenders defaults. `icc: false` only restricts the default bridge — compose stacks with explicit named networks (like ours) keep working.                                                                                                                                                                                                                               | Manual once, in Docker Desktop UI. Apply & Restart. Verify nothing broke after.                                                                                                  |

`compose.yml`'s `extra_hosts: ["host.docker.internal:host-gateway"]` on both services is technically redundant on Docker Desktop (which auto-resolves) but is required for Linux native compatibility and is harmless either way.

## URL routing — workspace POV

What the workspace sees, what each request actually traverses, and which firewall rule allows it (init-firewall.sh defaults to DROP):

| URL                                            | Traversal                                                                                              | Firewall rule                                                                  |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ |
| `http://supabase-runner:9000/*`                | compose DNS → runner container's bridge IP → cmd-relay.mjs                                             | `OUTPUT -d HOST_NETWORK -j ACCEPT` (runner is on the same supabase-net /24)    |
| `http://host.docker.internal:54321/*`          | Docker Desktop magic → host gateway IP → host's port 54321 (bound by `supabase_kong_workspace`) → kong | `OUTPUT -d <getent ahostsv4 host.docker.internal> -p tcp --dport 54321 ACCEPT` |
| `http://host.docker.internal:54322` (Postgres) | same path as above, port 54322 → `supabase_db_workspace`                                               | `OUTPUT -d <ip> -p tcp --dport 54322 ACCEPT`                                   |

`init-firewall.sh` MUST use `getent ahostsv4` (not `getent hosts`) because Docker Desktop's `host.docker.internal` resolution can flip between IPv4 and IPv6 across restarts; iptables is IPv4-only, ip6tables would be a separate rule set we don't maintain.

## The socat workaround in supabase-runner

`supabase start` (running inside the runner) hardcodes `127.0.0.1` for healthchecks against its own spawned db / kong containers. But "127.0.0.1" inside the runner is the runner's own loopback — and the spawned siblings bind their host ports to the HOST docker engine, NOT to the runner. Healthcheck connection refused, supabase tears the stack down.

`supabase-runner`'s `command:` runs two `socat` tunnels before `supabase start`:

```sh
socat -d TCP-LISTEN:54321,fork,reuseaddr,bind=127.0.0.1 TCP:host.docker.internal:54321 &
socat -d TCP-LISTEN:54322,fork,reuseaddr,bind=127.0.0.1 TCP:host.docker.internal:54322 &
sleep 0.5
supabase start
exec /usr/local/bin/cmd-relay.mjs
```

socat's lazy-connect behavior + supabase CLI's healthcheck retry loop handle the brief window where the spawned db isn't yet listening — by the time supabase's second healthcheck runs, db is up, the forward succeeds, and healthcheck passes. socat keeps running for the lifetime of the runner so later relay-driven `pnpm db:reset` etc. hit healthy forwards too.

GitHub Actions slow-job doesn't need socat because the supabase CLI runs **natively on the GH runner's host**, where 127.0.0.1 IS the host. Container-based nesting flips that assumption — that's the entire reason the workaround exists.

## Container lifecycle

| Action                                                           | workspace | supabase-runner | spawned `supabase_*_workspace` siblings     | Data                                            |
| ---------------------------------------------------------------- | --------- | --------------- | ------------------------------------------- | ----------------------------------------------- |
| `Reopen Folder Locally`                                          | running   | running         | running                                     | preserved                                       |
| `Stop Container` (VS Code)                                       | stopped   | stopped         | running (independent restart: always)       | preserved                                       |
| `Rebuild Container` (VS Code)                                    | recreated | recreated       | preserved (reused by next `supabase start`) | preserved                                       |
| `pnpm db:stop` (relay → `supabase stop`)                         | running   | running         | stopped                                     | preserved                                       |
| `pnpm db:stop` then `Stop Container`                             | stopped   | stopped         | stopped                                     | preserved                                       |
| `pnpm db:reset` (relay → `supabase db reset`)                    | running   | running         | running                                     | **wiped + reseeded from migrations + seed.sql** |
| Docker Desktop restart                                           | stopped   | stopped         | restarted (`restart: always`)               | preserved                                       |
| `docker compose --project-name lalista_devcontainer ... down -v` | stopped   | stopped         | running (different compose project)         | preserved                                       |

To **fully stop everything** (e.g., closing the lid, freeing battery / RAM):

```bash
# Inside workspace, before stopping the dev container:
pnpm db:stop                     # relay → supabase stop, tears down all supabase_* siblings

# Then from VS Code Command Palette:
#   Dev Containers: Stop Container
# OR from a macOS terminal:
docker compose --project-name lalista_devcontainer -f .devcontainer/compose.yml stop
```

Supabase data still persists across this (only `supabase stop --no-backup` wipes it). Resuming later via `Reopen in Container` brings everything back; the next `supabase start` from-scratch takes ~30-60s on first restart (image instantiation, schema reapply via migrations + seed.sql).

## Smoke-test commands

The first thing to run in a fresh `docker exec -it lalista_devcontainer-workspace-1 zsh` shell when something's off (or just to confirm the architecture is intact). In recommended order:

```sh
# 1. Identity check — confirm you're inside the workspace, not somewhere else.
hostname    # should match the lalista_devcontainer-workspace-1 container

# 2. Security checkpoint — workspace MUST NOT have docker access.
which docker                         # → "docker not found"
ls /var/run/docker.sock 2>&1 | head  # → "No such file or directory"

# 3. Relay reachable + supabase stack alive.
curl -fsS http://supabase-runner:9000/status | head -3   # → 🔧 Development Tools box

# 4. Data plane reachable from workspace.
curl -sS -o /dev/null -w "kong=%{http_code}\n" http://host.docker.internal:54321/    # → kong=404
curl -sS http://host.docker.internal:54321/rest/v1/ | head -3                        # → PostgREST OpenAPI swagger

# 5. Auto-set env vars present (compose.yml workspace.environment).
echo "SUPABASE_URL=$SUPABASE_URL"
echo "SUPABASE_ANON_KEY (first 30)=${SUPABASE_ANON_KEY:0:30}..."

# 6. Integration tests are the strongest forcing-function for end-to-end correctness.
cd /workspace && pnpm test:integration 2>&1 | tail -3   # → "Tests N passed (N)"

# 7. host.docker.internal resolves to a v4 address (the firewall rule depends on this).
getent ahostsv4 host.docker.internal    # → some "192.168.x.x  STREAM ..." line
```

If 1-7 all pass, Option 3 isolation is intact and the local-dev path is healthy.

## Running integration tests locally

Integration tests (`*.integration.test.ts`) hit a real Supabase stack — they're the highest-confidence local verification a project has, but they're opt-in via `VITEST_INTEGRATION=1` so the default `pnpm turbo run test:unit` loop stays fast.

### When in the dev cycle

Recommended order, smallest-feedback-loop first:

1. **While iterating on a feature**: `pnpm turbo run test:unit` — runs in seconds, no live stack needed. Use as the default save-trigger gate.
2. **Before pushing a commit that touches `packages/core/src/api/*`, `supabase/migrations/*`, or `supabase/functions/*`**: `pnpm test:integration` — confirms the wire-shape contract still holds against a real Postgres + GoTrue + PostgREST + edge runtime.
3. **Before opening a PR**: re-run `pnpm test:integration` once after the final rebase. Catches any drift against the latest local schema.
4. **CI slow-job runs them automatically on PRs to main** — but the local feedback loop is faster than CI's ~10-15 min.

You don't need to run them on every save (use `test:unit` for that), and you don't need to run them when only touching `apps/web/components/*` (UI-only changes) — but any change at the API or schema seam should get one local pass before push.

### How to manually run them

The compose stack auto-sets `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` on workspace startup, so no env-prefix is needed. From `/workspace`:

```bash
# Run all integration tests
pnpm test:integration

# Just the core package's
pnpm --filter @lalista/core test:integration

# A single test file
pnpm --filter @lalista/core exec vitest run --include 'src/api/items.integration.test.ts'

# A single test by name
pnpm --filter @lalista/core exec vitest run -t 'addedByName hydration'
```

If the stack isn't up, start it via the relay before running tests:

```bash
pnpm db:start    # POST http://supabase-runner:9000/start — supabase start in the runner
pnpm db:status   # GET http://supabase-runner:9000/status — confirm services table renders
```

After a schema change (new migration), reseed before re-running:

```bash
pnpm db:reset           # POST http://supabase-runner:9000/db-reset — drops + reapplies all migrations + seed.sql
pnpm db:gen-types       # GET http://supabase-runner:9000/gen-types -o packages/core/src/supabase.types.ts
git diff --stat packages/core/src/supabase.types.ts   # confirm types refreshed cleanly
pnpm test:integration   # re-run against the new schema
```

### How to debug a failing integration test

Failures come in three shapes — diagnose by what's true.

**Shape 1: `tests skipped (N skipped)` instead of running.** The test files have a runtime gate that requires `SUPABASE_URL` to start with one of `http://127.0.0.1:`, `http://localhost:`, `http://host.docker.internal:` AND `SUPABASE_ANON_KEY` + `SUPABASE_SERVICE_ROLE_KEY` to be set. If they skip:

```bash
echo "SUPABASE_URL=$SUPABASE_URL"
echo "SUPABASE_ANON_KEY (first 30)=${SUPABASE_ANON_KEY:0:30}..."
echo "SUPABASE_SERVICE_ROLE_KEY (first 30)=${SUPABASE_SERVICE_ROLE_KEY:0:30}..."
```

If any are empty, the workspace's compose-set env block didn't apply — likely the workspace container hasn't been recreated since the env block was added. Recreate via `docker compose --project-name <project>_devcontainer -f .devcontainer/compose.yml up -d` from a macOS terminal, or "Dev Containers: Rebuild Container" in VS Code.

**Shape 2: `connect ECONNREFUSED` / `getaddrinfo ENOTFOUND` against `host.docker.internal:54321` or `:54322`.** The supabase stack isn't actually up:

```bash
# Check stack via the relay
curl -fsS http://supabase-runner:9000/status

# If status is empty or returns 500, look at the runner's logs from a macOS terminal
docker logs lalista_devcontainer-supabase-runner-1 | tail -50

# Common: supabase start failed during runner boot. Restart the stack:
pnpm db:start
```

If the runner logs show `dial tcp 127.0.0.1:54322: connect: connection refused` during `supabase start`, the socat tunnels aren't in place — see § The socat workaround in supabase-runner.

**Shape 3: tests run but fail with assertion errors / RLS errors / `null` rows.** This is the actual test failure path — a real bug in the code under test, or schema drift from a migration that didn't seed correctly.

```bash
# Confirm the schema is what tests expect
pnpm db:reset      # reapply migrations + seed.sql
pnpm db:gen-types  # regenerate types — if diff is non-cosmetic, types are stale

# Re-run the failing test with vitest verbose mode
pnpm --filter @lalista/core exec vitest run -t '<test name>' --reporter verbose

# Inspect the actual db state via the supabase Studio UI (forwarded to host)
open http://host.docker.internal:54323
```

The Studio UI lets you browse rows, run SQL, and check that RLS policies are actually rejecting the calls you expect them to reject — the most common source of "the test is right, the production code is wrong" mismatches.

### Common test-file patterns to know

Lalista's integration tests follow a few conventions worth recognizing when extending or debugging them:

- **`signInAs(email, password, displayName)` helper** (in `profiles.integration.test.ts`) — uses the anon client to `signUp` a fresh user per test, returns an authenticated client that carries the user's JWT. Local seed sets `mailer_autoconfirm = true` so the session is issued immediately; in CI's local stack the same convention holds.
- **`adminClient()` helper** (in `items.integration.test.ts` and similar) — returns a Supabase client built with the SERVICE_ROLE_KEY, bypasses RLS. Use ONLY in test setup/teardown (creating users, deleting users, seeding rows). Never in production code.
- **`describe.skipIf(!shouldRun)(...)`** — the URL-prefix + key-presence gate. If the gate doesn't fire, the test never runs (Shape 1 above).

## Debugging tree

The failure modes hit during lalista PR 34's verification, in order surfaced. Future operators recognizing the symptom can jump straight to the fix.

1. **`Error response from daemon: mounts denied: The path /supabase is not shared from the host`** during compose-up.
   → `LOCAL_WORKSPACE_FOLDER` was unset, so the `${LOCAL_WORKSPACE_FOLDER}/supabase:${LOCAL_WORKSPACE_FOLDER}/supabase` bind interpolated to `/supabase:/supabase`. Fix: confirm `.devcontainer/init-host-env.sh` ran on the host before compose-up (look for the "init-host-env.sh: LOCAL_WORKSPACE_FOLDER=..." log line in VS Code's rebuild output). For manual `docker compose up`, export it: `LOCAL_WORKSPACE_FOLDER=$(pwd) docker compose ...`.

2. **`Bind for 0.0.0.0:54322 failed: port is already allocated`** during supabase start.
   → Another container (probably a leftover `supabase_db_workspace` from a previous run) holds the host port. Fix from a macOS terminal: `docker ps -a --filter "name=supabase_" --format "{{.Names}}" | xargs -r docker rm -f`, then re-up the compose stack.

3. **`failed to connect to postgres: dial tcp 127.0.0.1:54322: connect: connection refused`** during supabase start, followed by "Stopping containers...".
   → socat tunnels aren't running inside the runner (or they failed). Check `docker logs lalista_devcontainer-supabase-runner-1` for socat startup lines. Confirm `socat` is installed in the runner image (Dockerfile installs it via apt). Confirm the `command:` in compose.yml runs the socat lines before `supabase start`.

4. **Relay returns empty body, integration tests skip silently, kong unreachable**.
   → `supabase start` may have failed in the runner. Read `docker logs lalista_devcontainer-supabase-runner-1` from the top — first error is the actionable one. Common: missing `supabase/config.toml` (working_dir wrong), or migrations bug.

5. **Integration tests print "skipped" instead of running**.
   → The test files have a runtime gate that requires `SUPABASE_URL` to start with one of `http://127.0.0.1:`, `http://localhost:`, `http://host.docker.internal:` AND `SUPABASE_ANON_KEY` + `SUPABASE_SERVICE_ROLE_KEY` to be set. Confirm `compose.yml`'s `workspace.environment` block has all three. The well-known supabase-local JWTs work; same values CI uses.

6. **`iptables: host/network 'fdc4:f303:9324::254' not found` during postStartCommand**.
   → `host.docker.internal` resolved to IPv6, iptables is IPv4-only. The init-firewall.sh fix uses `getent ahostsv4` to force IPv4 resolution. If `ahostsv4` returns empty, Docker Desktop's network is in an unusual mode — toggle Settings → Resources → Network options and restart.

7. **macOS browser can't reach Supabase even though workspace can**.
   → `/etc/hosts` on macOS doesn't have the `host.docker.internal` entry. Add it: `sudo sh -c 'echo "127.0.0.1 host.docker.internal" >> /etc/hosts'`. Idempotent.

## CI / prod isolation

This entire architecture is local-dev-only. CI and prod surfaces are unaffected:

- **CI fast-job** uses GitHub Secret `SUPABASE_URL=http://127.0.0.1:54321` (fast-job's runner doesn't bring up supabase locally; the stub URL guards against accidental prod calls — see project CLAUDE.md § Gotchas for the URL guard pattern).
- **CI slow-job** runs `supabase start` natively on the GH runner host (no compose, no docker-in-container). 127.0.0.1 IS the host there, so no socat needed.
- **Prod** uses Vercel env vars (`NEXT_PUBLIC_SUPABASE_URL` set on the Vercel project pointing at the project's `<ref>.supabase.co`). Independent of any of this.

Changing local-dev compose / firewall / env-block does not touch CI or prod surfaces.

## Cross-references

- Threat-model + alternatives matrix: [`/devshop/kit/notes/security/local-supabase-isolation-options.md`](../../notes/security/local-supabase-isolation-options.md)
- Pattern reference (real diff, real failure modes, real fixes): lalista PR 34 (`devcontainer-compose-isolated`, 2026-04-28), commits `75a02f6` → `7231cb9` → `3d4ef2d` → `cf71aad` → `a76b5f8`.
- Future template work: `kit/TODOS.md § lalista-option3-template-variant` — convert this into an `/ak-new-project` choice once a second project picks the same architecture.
