# Lalista Option 3 → /devshop/template/.devcontainer/ port

Self-contained briefing for the focused session that ports lalista's Option 3 compose-isolation setup into the devshop template, plus a `/ak-new-project` interactive choice for it. Designed to be copy-pasted into a fresh `claude` session and executed without re-deriving any context.

**Status as of 2026-04-28:** lalista PR 34 (`devcontainer-compose-isolated`) verified working; merging soon. Devshop architecture guide + threat-model note already landed (devshop main commits `967508b` + `d1adce4`). This roadmap note captures the followup work that template-izes the pattern for future projects.

**Tracked in:** `/devshop/kit/TODOS.md § lalista-option3-template-variant`.

## Why this matters

Option 3 compose isolation is the default-recommended setup for any project where the operator has other code under `~/dev/` whose contents shouldn't be readable by a compromised npm transitive dep. That's most operators.

**Current template state (verified 2026-04-28 against `/devshop/template/.devcontainer/`):** the template ships **Option 2 — host docker socket bind-mount** (single-container with `/var/run/docker.sock` bind, `init-docker-socket.sh` for GID alignment, docker-ce-cli installed in Dockerfile). Interlude (d) on 2026-04-27 already shipped the firewall cleanup (drops `api.supabase.com` + `aws-0-us-west-2.pooler.supabase.com` from the allowlist; the comment block in `template/.devcontainer/init-firewall.sh` documents this).

So the migration this note captures is **Option 2 → Option 3** for the template, not "older shape → Option 3." Lalista's PR 34 made the same Option 2 → Option 3 jump on its own copy. The shipping move:

- Update the template's `.devcontainer/` to the Option 3 shape.
- Add a `/ak-new-project` choice for Option 3 so new projects start with it (default = Option 3).
- Keep Option 2 as an explicit choice for projects that pin to it (single-container is easier to reason about for some operators); document the trade-offs.
- Provide a migration recipe for stranded projects already on Option 2.

## Source materials

- **Lalista PR 34** (the canonical reference implementation): https://github.com/meirmsn/lalista/pull/34
  - All commits in scope: `75a02f6` → `7231cb9` → `3d4ef2d` → `cf71aad` → `a76b5f8` → (`01492f8` reverted by `2d6666f`) → `9cdad4e` → `97eec6b` → `add5925` → `aa79395`
  - Most relevant for the port: `75a02f6` (initial architecture), `7231cb9` (LOCAL_WORKSPACE_FOLDER), `3d4ef2d` (socat + port-conflict fix), `cf71aad` (env-block), `a76b5f8` (IPv4 firewall), `9cdad4e` (CI workflow grep), `97eec6b` (README sync)
- **Devshop architecture guide** (operator-facing): `/devshop/kit/docs/guide/local-supabase-compose-isolation.md`
- **Threat model + decision matrix** (rationale source): `/devshop/kit/notes/security/local-supabase-isolation-options.md`
- **Lalista's spec for post-merge verification**: `/workspace/specs/devcontainer-option3-followups/spec.md` (in the lalista repo, after PR 34 merges)

## Files to copy from lalista to template

All paths below are in lalista (source) → template (destination). The template path is `/devshop/template/.devcontainer/`. **Do not** copy any project-specific values; treat lalista as the canonical Option 3 shape and adapt only the project-name placeholders. Rule of thumb: if a value contains `lalista` or a JWT, scrub it.

### New files (5)

| Source                                                  | Destination                                                                        | Project-specific scrub                                                                                                                                                            |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<lalista>/.devcontainer/compose.yml`                   | `template/.devcontainer/compose.yml`                                               | None — values are architecturally fixed (URLs are `host.docker.internal`, well-known JWTs are CI-safe defaults). Verify the comment block doesn't leak any project-specific path. |
| `<lalista>/.devcontainer/init-host-env.sh`              | `template/.devcontainer/init-host-env.sh`                                          | None                                                                                                                                                                              |
| `<lalista>/.devcontainer/supabase-runner/Dockerfile`    | `template/.devcontainer/supabase-runner/Dockerfile`                                | None                                                                                                                                                                              |
| `<lalista>/.devcontainer/supabase-runner/cmd-relay.mjs` | `template/.devcontainer/supabase-runner/cmd-relay.mjs`                             | None                                                                                                                                                                              |
| (none)                                                  | `template/.devcontainer/supabase-runner/.gitkeep` (or rely on the two files above) | The directory itself needs to exist; the two files inside are sufficient.                                                                                                         |

### Modified files (3) + 1 deleted

| Template file                                  | What to change                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `template/.devcontainer/devcontainer.json`     | Switch to `dockerComposeFile: "compose.yml"` + `service: "workspace"`. Drop the `build:` block (moves to compose.yml). Drop the `runArgs` (cap_add + env_file move to compose.yml). Add `initializeCommand: ["bash", "${localWorkspaceFolder}/.devcontainer/init-host-env.sh", "${localWorkspaceFolder}"]`. Drop `workspaceMount` (moves to compose.yml). Keep named-volume `mounts` (need `${devcontainerId}` interpolation). Keep the devshop bind in `mounts` (needs `${localWorkspaceFolder}`). Keep `containerEnv`, `customizations`, `remoteUser`, `postCreateCommand`, `postStartCommand`, `waitFor`. |
| `template/.devcontainer/init-firewall.sh`      | Add the host.docker.internal allow rule (per lalista commit `a76b5f8`): use `getent ahostsv4` to force IPv4 resolution; fall back to a warn if unresolved. **Already done by interlude (d):** drop of `api.supabase.com` + `aws-0-us-west-2.pooler.supabase.com` from the allowlist for-loop and the corresponding comment block. The interlude-(d) comment text references "host docker socket bind-mount"; update wording to reflect Option 3 (workspace has no socket; supabase-runner sibling holds it; data plane reached via `host.docker.internal:54321/54322`).                                      |
| `template/.devcontainer/Dockerfile`            | Drop the docker-ce-cli + docker-compose-plugin install block (Option 2 needs it; Option 3 workspace has no docker access). Drop the `init-docker-socket.sh` COPY + sudoers entry. Drop the `RUN groupadd -f docker` line. Everything else stays.                                                                                                                                                                                                                                                                                                                                                             |
| `template/.devcontainer/init-docker-socket.sh` | **DELETE this file** — Option 3 workspace has no docker socket to align with the host's docker group GID.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |

### Optional template doc files (1-2)

| Template file                      | What to change                                                                                                                                      |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `template/.devcontainer/README.md` | If the template has a README, sync to Option 3 reality (use lalista's `97eec6b` commit's README as the source). If no template README exists, skip. |
| `template/package.json`            | Add the `db:*` script entries. Per lalista PR 34's commit `75a02f6`.                                                                                |

### Host-side "which container am I in?" debugging snippet

Drop into the template README's Option 3 section (or merge into `kit/docs/guide/local-supabase-compose-isolation.md` alongside its existing Smoke-test commands). Under Option 3 the compose stack runs `workspace` + `supabase-runner` as siblings; operators occasionally need to confirm they `docker exec`d into the right one (e.g. when a `~/.zshrc` `devcontainer` helper picks the wrong container, or when debugging a "why doesn't my project show up" issue). These three commands resolve it from the macOS host:

````md
### "Did I connect to the wrong container?"

Run on the macOS host:

```sh
# 1. Which compose stacks are up, and which services in each:
docker compose ls          # lists compose projects
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Labels}}'

# 2. What VS Code thinks the dev container is (it labels the service named in
#    devcontainer.json's "service" field — workspace — and only that one):
docker ps --filter label=devcontainer.local_folder \
  --format 'table {{.Names}}\t{{.Label "devcontainer.local_folder"}}\t{{.Label "com.docker.compose.service"}}'

# 3. Inside a container, "where am I really?":
hostname              # container ID prefix
cat /etc/hostname
ls /workspace 2>/dev/null && echo "this is the dev container" || echo "this is a sibling"
```

The `devcontainer.local_folder` label is added by the VS Code Dev Containers extension via a temporary override compose file at attach time, and is stamped only on the service container (`workspace`) — not on `supabase-runner`. Compose also stamps `com.docker.compose.project` and `com.docker.compose.service` on every container it manages, so labels are the durable identity (image + container names can drift across compose v1/v2's `_` vs `-` conventions).
````

## Files to NOT copy / NOT modify

- `<lalista>/apps/web/.env.local` — gitignored, project-specific.
- `<lalista>/.devcontainer/.env` — gitignored, holds operator-specific keys (ANTHROPIC_API_KEY_QA + LOCAL_WORKSPACE_FOLDER).
- Any `apps/web/.env.local.bak.*` files — operator local backups, irrelevant to template.
- `<lalista>/CLAUDE.md` — project-specific. The template ships its own CLAUDE.md skeleton.
- `<lalista>/specs/devcontainer-option3-followups/spec.md` — project-specific to lalista's PR 34. Don't propagate.
- `<lalista>/.gitleaks.toml` — project-specific allowlist (lalista PR 34's `01492f8` was reverted as unnecessary; don't carry forward).
- `<lalista>/.github/workflows/ci.yml` — the workflow lives in the project, not the template, but the template ships its own scaffold via `/ak-new-project`. The grep-from-compose.yml fix (lalista commit `9cdad4e`) probably needs to land in the template's CI scaffold too — see `/ak-new-project § Step` for where the workflow content is generated.

## /ak-new-project changes

`/ak-new-project` runs in two phases (Phase A creates the GH repo from template; Phase B does interactive setup inside the new project's container). The Option 3 choice goes in **Phase B** (early), so the operator picks before any rebuild.

### New choice prompt

Recommended placement: after the project name + before the supabase-related setup steps.

```
Local supabase reachability:
  (a) Option 1 — supabase CLI on macOS host (`brew install supabase/tap/supabase`).
      Workspace dev container has no docker access. supabase runs natively
      on macOS; you spawn / stop the stack from a host terminal. No compose
      runner needed.
  (b) Option 2 — host docker socket bind-mount.
      Single-container devcontainer with /var/run/docker.sock bind-mount.
      `supabase start` runs from inside the dev container. Smaller footprint
      than Option 3 but workspace has docker socket access (a compromised
      npm transitive dep can spawn `docker run -v /Users:/h alpine`).
      Acceptable only if ~/dev/ contains a single project family.
  (c) Option 3 — compose isolation [RECOMMENDED].
      Two-container compose: workspace (no docker) + supabase-runner (holds
      socket, runs supabase start). RPC relay on :9000 for orchestration.
      Workspace + browser reach data plane via host.docker.internal:54321.
  (d) Skip — CI-only integration tests.
      No local supabase. pnpm test:integration runs only in CI slow-job.
      Lowest setup; loses local integration test feedback loop.
```

Default = (c). Decision matrix is at `kit/notes/security/local-supabase-isolation-options.md`.

### Per-choice setup behavior

- **(a)** Option 1: skip copying `compose.yml`, `init-host-env.sh`, `supabase-runner/`. Strip the `/var/run/docker.sock` mount + `init-docker-socket.sh` references from `devcontainer.json`. Strip the docker-CLI install + `init-docker-socket.sh` COPY from `Dockerfile`. Workspace ends up with no docker access at all. Print the `brew install supabase/tap/supabase` instruction at end of Phase B.
- **(b)** Option 2 (the current template default): keep the existing template files unchanged. The project starts with `/var/run/docker.sock` bound to the workspace + `init-docker-socket.sh` for GID alignment. No compose runner.
- **(c)** Option 3: copy the 5 new files + apply the 3 modifications above (devcontainer.json, init-firewall.sh, Dockerfile) + delete `init-docker-socket.sh`. Print the `127.0.0.1 host.docker.internal` /etc/hosts step at end of Phase B (idempotent — only print if grep doesn't find an existing entry).
- **(d)** Skip: Option 1's strip of docker-related references + skip everything supabase-runtime related. Note in the new project's CLAUDE.md that integration tests are CI-only.

### Test plan for /ak-new-project changes

- Spin up a throwaway project with each choice. Verify the file set matches the choice.
- For (b): run `pnpm test:integration` after Phase B completes — should pass (or skip cleanly with no test files if the new project has no `*.integration.test.ts` files yet).

## Adversarial docs review

The devshop pre-commit hook fires `docsReviewed` on any staged file. For this port, the staged files will include:

- `template/.devcontainer/compose.yml` (new)
- `template/.devcontainer/init-host-env.sh` (new)
- `template/.devcontainer/supabase-runner/Dockerfile` (new)
- `template/.devcontainer/supabase-runner/cmd-relay.mjs` (new)
- `template/.devcontainer/devcontainer.json` (modified — switch to dockerComposeFile)
- `template/.devcontainer/Dockerfile` (modified — drop docker-ce-cli + init-docker-socket COPY/sudoers)
- `template/.devcontainer/init-firewall.sh` (modified — add host.docker.internal allow rule + Option 3 comment text)
- `template/.devcontainer/init-docker-socket.sh` (DELETED — workspace has no socket under Option 3)
- `template/package.json` (modified — db:\* scripts)
- `.claude/skills/devshop/new-project/SKILL.md` (modified — new 4-choice prompt + per-choice setup branches)
- `kit/tests/wiring.bats` and/or `kit/tests/template.bats` (modified — flip docker-socket assertions to dockerComposeFile, add Option-3 assertions)
- Possibly `template/.devcontainer/README.md` (modified — sync to lalista's `97eec6b` content scrubbed of project-specific values)
- Possibly `template/.github/workflows/ci.yml` (modified — gitleaks grep fix per lalista commit `9cdad4e`)

The bypass reason needs to enumerate each of the 7 reference docs (MODEL.md, OVERVIEW.md, guide/{workflow,conventions,hooks,security,ops,architecture}.md, FAQ.md). Likely affected:

- `guide/security.md` — should reference the new architecture as a security-relevant capability; might warrant a small "Local Supabase isolation" subsection or cross-link to `local-supabase-compose-isolation.md`.
- `guide/architecture.md` — devshop architecture; not directly affected (project-side architecture is separate).
- `guide/ops.md` — possibly a brief mention in the operations overview.
- The rest are likely "not affected".

Cross-file coherence: ensure the new template files don't contradict the existing `kit/docs/guide/local-supabase-compose-isolation.md` content. They shouldn't (the guide describes lalista's setup; the template is the same setup minus project-specific values).

## Tests

The devshop has BATS tests (`kit/tests/`) that validate template wiring. Add tests for:

**New tests (Option 3 shape):**

- New template files exist and are valid (compose.yml is valid YAML, init-host-env.sh is bash-syntax-clean, cmd-relay.mjs is parseable JS, supabase-runner Dockerfile builds at least to FROM line).
- `template/.devcontainer/devcontainer.json` has `dockerComposeFile: "compose.yml"` + `service: "workspace"` (verify the schema flip).
- `template/.devcontainer/devcontainer.json` has `initializeCommand` invoking `init-host-env.sh`.
- `template/.devcontainer/init-firewall.sh` contains the host.docker.internal allow rule (`getent ahostsv4`).
- `template/.devcontainer/init-firewall.sh` does NOT contain `api.supabase.com` or `aws-0-us-west-2.pooler.supabase.com` (already true post-interlude-(d); regression-guard).
- `template/.devcontainer/init-docker-socket.sh` does NOT exist (Option 3 deletes it).
- `template/.devcontainer/Dockerfile` does NOT contain `docker-ce-cli` or `init-docker-socket.sh` references (verify the Option 2 docker tooling was stripped).
- `template/package.json` has the `db:*` scripts.
- `/ak-new-project` SKILL.md has the new "Local supabase reachability" choice prompt.
- `/ak-new-project` SKILL.md per-choice setup branches reference the correct file copies / strips for each of (a) / (b) / (c) / (d).

**Existing tests to UPDATE (current Option 2 assertions will break):**

- `kit/tests/wiring.bats` § "wiring: template devcontainer.json is valid JSON" — still applies; just confirm Option 3 JSON parses.
- Any test asserting `/var/run/docker.sock` mount in template/.devcontainer/devcontainer.json — needs to flip to asserting `dockerComposeFile` for the default-Option-3 case (or split into per-choice tests if `/ak-new-project` keeps Option 2 as a choice).
- Any test asserting `docker-ce-cli` install line in template/Dockerfile — same flip.
- Run `grep -rn 'docker.sock\|docker-ce-cli\|init-docker-socket' kit/tests/` in the focused session to enumerate the assertions to update.

Look at existing `kit/tests/wiring.bats` and `kit/tests/template.bats` for the pattern.

## Open decisions (to surface during the focused session)

1. **Should the template ship the `.gitleaks.toml` allowlist additions?** Lalista's PR 34 originally added a regex for the supabase-demo JWTs but reverted it as unnecessary (existing `SUPABASE_ANON_KEY` regex covers the line context). Decision: probably DON'T propagate the regex — let projects add it only if they hit a real failure.

2. **Should the template's CI workflow grep use compose.yml?** Yes, per lalista commit `9cdad4e`. The gitleaks step in `template/.github/workflows/ci.yml` (or wherever the template's CI workflow lives) needs the same `grep .devcontainer/compose.yml | sed 's/.*: //;s/[" ]//g'` pattern.

3. **Default choice in /ak-new-project:** (b) Option 3 [recommended] OR (a) Option 1? The threat-model note recommends Option 1 as the default; this roadmap entry assumes Option 3 because it's the no-brew-install path. Surface to the operator at session start.

4. **Should Option 2 stay as a choice in the prompt?** The current template IS Option 2, so existing developers familiar with it (and migration users not yet ready to flip) may want to keep it. Recommendation: **YES, keep Option 2 as choice (b)** with a clearly-marked "Recommended: Option 3" annotation on the (c) entry. Only adds one prompt option and acknowledges what was just shipped in interlude (d). Drop only if `kit/notes/security/local-supabase-isolation-options.md`'s decision-matrix conclusion explicitly recommends against Option 2 in any new project.

5. **Backward-compat for stranded Option 2 projects:** Add a `/ak-new-project § Migration: Option 2 → Option 3` section covering the file diff (5 new files + 2 modified + 2 deleted, including `init-docker-socket.sh`). Most projects scaffolded between interlude (d) on 2026-04-27 and this template port will be on Option 2 — that's the migration target audience. Lalista PR 34 (commits `75a02f6` → `a76b5f8`) is the canonical reference diff.

## Workflow — execute the focused session

Standard devshop shipping flow (no PRs):

```bash
cd /devshop
git checkout -b feat/template-option3
# ... do the work above ...
git add <all the new and modified files>
git -c devshop.docsReviewed="<thorough enumeration of the 7 reference docs + per-doc affected/not-affected + cross-file coherence>" commit -m "..."
git checkout main
git merge --ff-only feat/template-option3
git push origin main
git branch -d feat/template-option3
```

Plus a release if the change warrants one (probably yes — minor bump, new capability):

```bash
bash kit/scripts/release.sh --bump minor
```

## Quick reorientation for the focused-session operator

Open a fresh `claude` session, then either paste this whole file or reference it via:

```
Read /devshop/kit/notes/roadmap/lalista-option3-template-port.md and execute it.
Source materials are at the paths listed in § Source materials. Use lalista PR 34's commits as the canonical reference. The operator decisions to surface are in § Open decisions.
```

That should give the new session enough context to execute without re-deriving anything from the original PR 34 diagnostic arc.
