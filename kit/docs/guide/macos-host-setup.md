# macOS host setup for devshop projects

One-time, per-Mac. Outside the dev container, on the macOS host. Apply once before your **first** devshop project on this machine; every subsequent project inherits the same host config.

The devshop's Option 3 compose isolation (workspace has no docker socket; sibling `supabase-runner` holds it with a narrow `<host>/supabase` bind) reduces but does NOT eliminate the bind-mount escape vector. The load-bearing mitigation lives on macOS, not inside the container — a compromised npm dep with docker-socket access can still `docker run -v /Users:/h alpine` against whatever Docker Desktop's File Sharing list permits. Steps 1+2 close the security model. Step 3 is mechanically required for `pnpm dev` and the macOS browser to reach the local supabase stack at all.

Threat model + decision matrix: [`/devshop/kit/notes/security/local-supabase-isolation-options.md`](../../notes/security/local-supabase-isolation-options.md). Architecture detail: [`local-supabase-compose-isolation.md`](./local-supabase-compose-isolation.md).

## The four steps

### 1. Docker Desktop → Settings → Resources → File Sharing

Restrict the allowed paths to `/Users/<you>/dev` (or whichever single parent holds your code projects). Apply & Restart.

**Mandatory** per the threat model — bounds bind-mount-based file access if a container ever breaches the docker socket.

### 2. Docker Desktop → Settings → Docker Engine

Paste-merge into the JSON config:

```jsonc
{
  "no-new-privileges": true,
  "userland-proxy": false,
  "icc": false,
}
```

Apply & Restart. Belt-and-suspenders defaults — `icc: false` only restricts the default bridge, so compose stacks with explicit named networks (the Option 3 setup) keep working.

### 3. macOS `/etc/hosts`

Add the loopback entry so the macOS browser resolves the same hostname the workspace does:

```sh
sudo sh -c 'grep -q host.docker.internal /etc/hosts || echo "127.0.0.1 host.docker.internal" >> /etc/hosts'
```

Without this, XHR from the React app to local supabase fails to resolve.

### 4. Verify Docker Desktop hygiene (no commands — UI check)

- **Auto-update is on.** Kernel CVE patches in the VM are the realistic VM-escape attack surface — skipping these is the highest practical risk.
- **Kubernetes is off** (Settings → Kubernetes) unless you actively use it. Bundled K8s is a running attack surface if unused.
- **You're on the stable channel** (not beta/experimental).

## Verifying it stuck

Cheap re-check of step 2 from any terminal (host or container) once Docker Desktop is running:

```sh
docker info --format '{{.SecurityOptions}}'    # should include `name=no-new-privileges`
```

Steps 1 + 4 are not introspectable from the CLI — re-open Docker Desktop's settings UI to confirm.

## What's per-project, not per-host

The `apps/web/.env.local` file (with `NEXT_PUBLIC_SUPABASE_URL=http://host.docker.internal:54321` + the local-stack anon JWT) is **per-project**, not per-host. It folds into normal project scaffolding once `apps/web/` exists; not a launch-day item.

## When to revisit

- New macOS install / new Mac → re-run all four steps before opening the first devshop project.
- Docker Desktop major version bump → step 2's JSON config can survive the upgrade, but verify with the `docker info` snippet above. Steps 1 and 4 should also survive but are worth a 30-second recheck.
- Adding a code-projects parent outside `/Users/<you>/dev` → revisit step 1's File Sharing list. Don't widen casually — every new path is bind-mount blast-radius.
