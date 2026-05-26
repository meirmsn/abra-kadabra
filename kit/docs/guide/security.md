# Security + Quality

Layered defenses that prevent Claude from weakening its own guardrails: root-owned guard scripts, the DCG manifest, structural memory protection, edge-function auth, secrets isolation, and the supply-chain controls around third-party binaries.

## Contents

- [Core Principle](#core-principle)
- [Security-Critical Files](#security-critical-files)
- [Edge Function Auth](#edge-function-auth)
- [Local Supabase Isolation (devcontainer)](#local-supabase-isolation-devcontainer)
- [Secrets in CI](#secrets-in-ci)
- [CI Credential Isolation](#ci-credential-isolation)
- [Third-Party Binaries](#third-party-binaries)
- [Guard Script Editing](#guard-script-editing)
- [`.claude/` Allow vs settings.json Deny](#claude-allow-vs-settingsjson-deny)
- [Memory Write Protection](#memory-write-protection)
- [Runtime Validation at Trust Boundaries](#runtime-validation-at-trust-boundaries)
- [RLS-bypass write fallback ladder](#rls-bypass-write-fallback-ladder)
- [DB hardening — SQL conventions for Supabase projects](#db-hardening--sql-conventions-for-supabase-projects)
- [Per-environment secret split with canonical inner name](#per-environment-secret-split-with-canonical-inner-name)
- [Authoring locked files (denied-path recipe)](#authoring-locked-files-denied-path-recipe)
- [Known Gaps](#known-gaps)

## Core Principle

**Claude cannot weaken its own guardrails.** Six layers of protection enforce this:

1. **Root ownership + sticky bit** — security-critical files are `root:root`; mode is 644 for config and 755 for executables (the `[locked]` lock loop derives mode per-file from the template source — e.g., `init-host-env.sh` + `supabase-runner/cmd-relay.mjs` stay 755 because `pnpm db:start` execs them); sticky bit on `.claude/` and `.devcontainer/` in both repos (plus `template/.devcontainer/`) prevents node from deleting root-owned files
2. **Deny rules** — `settings.json` denies Edit/Write on itself, `.dcg.toml`, `.devcontainer/*`, guard scripts, and Bash writes to memory paths
3. **DCG** — compiled binary blocks 49+ destructive Bash patterns (rm -rf, git reset --hard, DROP TABLE, etc.)
4. **Git hooks** — pre-commit guards enforce clean tree, doc consistency, secret scanning
5. **PreToolUse hooks** — Claude Code hooks block hook bypass attempts before git even runs
6. **Freshness checks** — pre-commit verifies security files are present, real files (not symlinks), and up-to-date

Full security model: [`../../../notes/security-model.md`](../../notes/security-model.md)

## Security-Critical Files

Root-owned copies (not symlinks), verified fresh on every commit. Project-workspace files in this list are declared `[locked]` in `kit/manifest.txt` (the single source of truth — see `architecture.md § File lifecycle`) and refreshed from `template/` by `init-devshop.sh` on every container start; project-special and devshop-self files (settings.json, .dcg.toml, settings.local.json, .devcontainer/.env, plus the `$DEVSHOP/...` mirror) stay carved out as a hardcoded list in init-devshop.sh with comments explaining why.

- `.claude/settings.json` — permissions, hooks, deny rules
- `.dcg.toml` — destructive command patterns
- `.devcontainer/*` — container config (Dockerfile, init-devshop.sh, init-firewall.sh, devcontainer.json, checksums.sha256, refresh-allowed-ips.sh, init-prod-url.sh, firewall-extra-domains [scaffold-once project overlay; root:root 644]), firewall, secrets
- `.devcontainer/compose.yml` + `.devcontainer/init-host-env.sh` + `.devcontainer/supabase-runner/{Dockerfile,cmd-relay.mjs}` — compose-isolation siblings (only present when `/ak-new-project § Step 2b` chose compose isolation; lock loop skips entries whose template source is absent). Modes: `compose.yml` + `supabase-runner/Dockerfile` = 644; `init-host-env.sh` + `supabase-runner/cmd-relay.mjs` = 755 (executed by `pnpm db:start` via the cmd-relay socat path).
- `.husky/pre-commit` — gates commit-time guards (gitleaks, mixed-commit, Layer 1 docs/tests-coverage hooks); tampering silently disables them
- `.husky/prepare-commit-msg` — appends `Tests-Coverage-Bypass:` / `Docs-Coverage-Bypass:` trailers when bypass flags are set; tampering hides bypass evidence from audit-time review
- `.husky/pre-push` — gates push-time guards (no-direct-push-to-main, dirty-tree adversarial review); tampering silently disables them

All scripts under `kit/scripts/` (recursive — covers `commit-hooks/`, `preship/`, `notify/`, `sync/`, etc.) are also root-locked — `init-devshop.sh` runs `find $DEVSHOP/kit/scripts/ -type f -name '*.sh'` at container start and chowns each to `root:root 644`. This breaks the circularity where the scripts that watch `settings.json` were themselves only protected by `settings.json`. The two-layer model (Layer 1 = settings.json deny rules, Layer 2 = filesystem ownership) uses absolute-path deny patterns in `.claude/settings.json`:

```json
"Edit(/devshop/kit/scripts/**)",  // absolute — protects canonical copy
"Write(/devshop/kit/scripts/**)",
```

The `**` recursive glob is load-bearing — single-segment `*` would not match `kit/scripts/commit-hooks/commit-guard.sh` and would let Claude bypass Layer 1 by editing subdirectory scripts. (Layer 1 widening from `*` → `**` shipped in v1.20.0 after the gap was exploited unintentionally during the cross-repo check removal session — the file was Layer-2-eroded by prior git activity AND Layer-1-uncovered by the single-segment glob.)

**Worktree copies are intentionally editable.** The deny patterns use absolute paths (`/devshop/kit/scripts/**`) which protect only the canonical tree. Git worktree copies at `.worktrees/<topic>/kit/scripts/` are not denied — feature work regularly modifies scripts like `adversarial-review.sh` and `commit-guard.sh`. Pre-commit hooks fire identically in worktrees, so the guard gauntlet is not weakened. Previously, relative `kit/scripts/**` patterns caused inconsistent mid-session behavior: early Edit calls using full worktree absolute paths bypassed the deny, while later calls using relative paths triggered it — the flip trained the agent to attempt workarounds instead of the `/tmp + sudo install` recipe. Removing the relative patterns and keeping only absolute ones makes enforcement deterministic. Investigation: `specs/kit-scripts-deny-rule-investigation/spec.md`.

**Layer 2 erosion via git operations** is a known defense-in-depth gap tracked in `kit/TODOS.md` (v1): when git modifies a locked file (`checkout`, `merge`, `pull`, `rebase`), the rewritten file inherits node ownership from the running user, breaking the root lock until the next container restart. Layer 1 (the settings.json deny rules) is the load-bearing protection now that its glob is correct; Layer 2 erosion makes the model degrade defense-in-depth-wise but doesn't expose any one file unless Layer 1 also has a hole.

## Edge Function Auth

Edge functions always validate auth server-side — `getUser()` to verify against auth server, even with gateway JWT verification.

**See also:** [`supabase-ssr-boilerplate.md § Pattern 3`](./supabase-ssr-boilerplate.md#pattern-3-e2e-helpers--helpersadmin-clientts-with-the-5-canonical-exports) — the E2E side of the same defense (admin-client structural URL guard); auth-validation at the edge fn and test-time admin-client URL guard are complementary structural defenses.

## Local Supabase Isolation (devcontainer)

Projects that run a local Supabase stack pick a reachability shape at scaffold time via `/ak-new-project § Step 2b`. The **template default is compose isolation** — workspace dev container has no docker socket or docker CLI; a sibling `supabase-runner` compose service holds the socket and runs `supabase start` against the host engine. A compromised devtool / npm transitive dep in the workspace cannot spawn `docker run -v /Users:/h alpine` to read the macOS home via Docker Desktop's File Sharing, even though the host has File Sharing enabled.

Two other shapes are available per-project:

- **Host Supabase** (supabase CLI on macOS host, `brew install`) — equivalent isolation; threat-model's preferred default for operators with multiple `~/dev/` project families.
- **Skip** — no local Supabase stack; integration tests run CI-only.

The host-docker-socket-bind-mount shape (the threat model's Option 2) was an earlier shape — not offered to new projects because workspace docker access defeats the macOS-home blast-radius isolation that motivated compose isolation.

**Template default vs threat-model recommendation — two axes, not a contradiction**: the template ships compose isolation by default for ergonomics (no `brew install supabase/tap/supabase` step; `pnpm db:start` works out of the box). The [threat-model decision matrix](../../notes/security/local-supabase-isolation-options.md) recommends **Host Supabase** as the marginal-safer default for operators with multiple project families under `~/dev/` — the workspace has ZERO docker surface there (vs. compose isolation's runner-with-narrow-bind, which is also macOS-home-safe but slightly broader attack surface). Both options block the macOS-home read; the differentiation is brew-install-friction vs marginal-extra-isolation. `/ak-new-project § Step 2b` exposes both at scaffold time; pick per the operator profile.

Threat-model + decision matrix: [`/devshop/kit/notes/security/local-supabase-isolation-options.md`](../../notes/security/local-supabase-isolation-options.md). Operational guide for compose isolation: [`local-supabase-compose-isolation.md`](./local-supabase-compose-isolation.md).

## Secrets in CI

Wired into `ci.yml` in the same PR as the integration — never a follow-up.

## CI Credential Isolation

Two structural defenses keep prod credentials out of CI test paths:

1. **Local-stack defaults in CI.** The `SUPABASE_URL` GH Variable resolves to `http://127.0.0.1:54321` and the `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` Variables resolve to the published local-stack JWTs. CI's fast-job + slow-job spin up `supabase start` in the runner and dial the local stack — never prod. The deploy workflows are separate and consume `SUPABASE_PROD_URL` (Variable) + `SUPABASE_DB_PASSWORD` + `SUPABASE_ACCESS_TOKEN` (Secrets) only.
2. **URL guard in `packages/core/src/supabase.ts`.** Every `createClient` call passes through `assertNotProdUrlInTestEnv`, which throws if `NODE_ENV=test` and the URL points at the configured prod project ref. Catches a future drift where someone re-introduces a prod Supabase URL into CI's env or a unit test imports the wrong client factory. Tests in `packages/core/src/supabase.test.ts` lock the contract.

The combination matters. Without the local-stack defaults, the URL guard is the only defense — easy to disable accidentally. Without the URL guard, the local-stack defaults are convention — easy to forget when adding a new env var. With both, breaking either layer fails CI loudly.

The full credential blast-radius table + rotation cadence + Variables-vs-Secrets classification rules live in `/ak-new-project § Security Posture`. The cleanup recipe for older projects whose CI surface still mixes prod and local-stack credentials: `/ak-new-project § Migration: existing project to current credential layout`.

## Third-Party Binaries

Pinned to specific version + SHA256 checksum. Never "latest."

- **git-delta, dcg, gitleaks**: checksums hardcoded in `.devcontainer/checksums.sha256`. Update version + checksum in the same commit.
- **Supabase CLI**: checksum is self-verifying — fetched from the same GitHub release as the binary (`supabase_${VERSION}_checksums.txt`). This lets projects pin any version via `SUPABASE_CLI_VERSION` in `.devcontainer/.env` without a devshop-side checksum update. The trust model is equivalent to HTTPS-fetched package installs (npm, pip).

## Guard Script Editing

Guard script deny rules protect the canonical `/devshop/kit/scripts/` tree via two absolute-path deny patterns (`Edit(/devshop/kit/scripts/**)` + `Write(/devshop/kit/scripts/**)`). Worktree copies (`.worktrees/<topic>/kit/scripts/`) are intentionally not denied — feature work edits these directly. To toggle deny on the canonical tree, comment/uncomment the two absolute-path lines in settings.json. The `**` recursive glob covers subdirectory scripts too (`commit-hooks/`, `preship/`, etc.); a previous single-segment `*` glob shipped briefly through v1.19.x and was tightened in v1.20.0.

## `.claude/` Allow vs settings.json Deny

`Edit(.claude/**)` allows Claude to edit skills, commands, and memory through the symlink path. `settings.json` is safe: the explicit `Edit(**/.claude/settings.json)` deny takes priority.

## Memory Write Protection

Memory files (`.claude/memory/`, `.claude/projects/*/memory/`) are protected at two levels:

1. **Write/Edit hook** (`check-memory-created.sh`) — blocks the Write and Edit tools, forces Claude to classify the memory (project vs. devshop) and get user confirmation before writing.
2. **Bash deny rules** — blocks Bash commands that redirect output to memory paths (`cat >`, `>>`, `tee`). Prevents bypassing the classification hook via shell redirects.

`MEMORY.md` (the index file) is exempt from the Write/Edit hook — it's updated alongside memory files to maintain the index.

## Runtime Validation at Trust Boundaries

LLM-backed edge functions and third-party HTTP APIs are trust boundaries: their response shapes are not provable at compile time and can drift silently. Every Supabase / third-party edge-fn response with a hand-written shape must be parsed with Zod at the wrapper boundary (in `packages/core/src/api/<feature>.ts`) — never inside a React component or server action. Schemas live in `packages/core/src/schemas/<feature>.ts` (the template ships this directory with a placeholder README). The full pattern + worked examples are at [`wrapper-boundaries.md § Runtime Validation`](./wrapper-boundaries.md#runtime-validation-at-llm--edge-function-boundaries). This section names runtime validation as a security control to keep the cross-skill view ("auth + boundary + validation") cohesive — substance lives in `wrapper-boundaries.md`.

## RLS-bypass write fallback ladder

When a code path needs to write a table its caller's role can't, prefer the narrower fix in this order:

1. **Table-level RLS policy** scoped to `authenticated` (or stricter) with the specific predicate the write needs — narrowest possible widening of the trust boundary.
2. **`SECURITY DEFINER` RPC** with an explicit `auth.uid()` check inside the function body — bypasses RLS for the duration of the function only; the auth check is the gate.
3. **Service-role escalation in an edge function** — the admin client can write ANY table; only acceptable when (1) and (2) are infeasible (e.g., the write must touch tables across multiple users and the auth check is multi-actor).

Service-role is the last resort because the admin client's blast radius is "any row in any table," not "this specific operation." It also moves the security boundary from auditable SQL (RLS policy + RPC body) into application code, where review discipline and observability are weaker. Default to (1); reach for (2) when the operation needs cross-row state the policy can't express; reserve (3) for the genuinely-cross-user cases.

## DB hardening — SQL conventions for Supabase projects

Three day-1 SQL rules for every Supabase-backed project. The pre-ship gate `advisor-clean` (Gate 2g) enforces them mechanically by replicating Supabase's published Advisor lints against `pg_catalog`; this section is the authoring contract those lints encode.

### 1. `SECURITY DEFINER` functions must pin `search_path`

Every `create function ... language plpgsql security definer` (or `language sql security definer`) MUST include `set search_path = public, pg_temp` in its declaration. A `SECURITY DEFINER` function runs with the OWNER's privileges, not the caller's — so if a hostile schema lands earlier in the function's resolved `search_path`, an unqualified `select foo()` inside the body resolves to attacker-controlled code with owner authority. Pinning to `public, pg_temp` (and ONLY those, no leading `,` or `"$user"`) closes that hole.

```sql
-- Bad:
create function public.mark_item_bought(item uuid)
returns void language plpgsql security definer as $$
begin
  update items set bought = true where id = item;
end;
$$;

-- Good:
create function public.mark_item_bought(item uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  update items set bought = true where id = item;
end;
$$;
```

When the function genuinely needs a different schema (e.g., `extensions` for `gen_random_uuid()`), name it explicitly: `set search_path = public, extensions, pg_temp`. Never leave it inherited.

### 2. RLS policies use `(select auth.uid())`, not bare `auth.uid()`

Inside a `create policy` `USING` / `WITH CHECK` predicate, wrap `auth.uid()` (and `auth.jwt()`, `auth.role()`) in a subquery so Postgres can initplan it once per statement instead of re-evaluating per row. For a 10k-row scan, the unwrapped form runs `auth.uid()` 10k times; the wrapped form runs it once. The advisor lint `auth_rls_initplan` catches this; the gate is `findings`-loud until every policy is rewrapped.

```sql
-- Bad: re-evaluates auth.uid() per row.
create policy items_select_own on public.items
  for select using (owner_id = auth.uid());

-- Good: initplans auth.uid() once per statement.
create policy items_select_own on public.items
  for select using (owner_id = (select auth.uid()));
```

The rule extends to any `auth.*` SECURITY DEFINER helper Postgres can't otherwise hoist (`(select auth.jwt() ->> 'role')`, etc.). It does NOT apply to constants, plain column refs, or arithmetic — only function calls whose result is constant across the statement.

### 3. Every foreign key has a backing index (or a justification comment)

`foreign key (parent_id) references public.parent(id)` does NOT auto-create an index on `child.parent_id`. Deletes / updates on the parent then scan the child table linearly for every row touched. Either add an explicit index:

```sql
create index items_owner_id_idx on public.items (owner_id);
```

or inline-comment the migration to record the deliberate exception:

```sql
-- ADVISOR-EXEMPT(unindexed_foreign_key): items.owner_id —
-- table is row-bounded (<= 50 rows per owner) and reads dominate writes;
-- backing index would double write amplification for no measurable gain.
alter table public.items add constraint items_owner_id_fkey
  foreign key (owner_id) references auth.users(id) on delete cascade;
```

The gate scans for `ADVISOR-EXEMPT(<lint_name>)` markers on the same migration file and ignores findings the marker names. If the comment doesn't match the lint name, the gate treats the FK as unjustified and fails.

### How this gets enforced

- **Authoring time**: this section + `template/CLAUDE.md § Migration Workflow` callout. Authors are expected to write each new `create function` / `create policy` / `foreign key` with the rule in mind.
- **Pre-ship time**: `pnpm db:advisor` runs `template/scripts/advisor-probe.mjs` against the local Supabase stack, surfacing every gap. `/ak-pre-ship § Gate advisor-clean (2g)` runs it automatically on every migration-touching PR.
- **Bypass**: `git config devshop.advisorBypassReason "<per-finding rationale>"` short-circuits the gate after adversarial review (check-type `advisorBypassReason`, Sonnet-routed). Reserved for legitimate deferrals like "extension-in-public per project D4 — moving `pgcrypto` out of `public` would break existing call sites; tracked at TODOS.md L<n>."

## Per-environment secret split with canonical inner name

For third-party paid APIs with per-environment billing scopes (e.g. an LLM API), split the secret on the outer surface — CI/local-dev gets one secret-store name, production gets another — and translate to a single canonical name at the consumption boundary. Two reasons:

1. **Blast-radius separation.** A leaked QA key can't drain prod billing; prod rate-limit pressure from real users can't break CI.
2. **SDK alignment without per-environment branching.** The consumer (edge function, server-side runtime) reads `process.env.<CANONICAL_NAME>` — the name the SDK expects — and the surfaces around it (workflow steps, devcontainer env, deploy workflow) translate. The function body never sees the per-environment names; no `if (env === 'prod')` branch.

Concrete shape:

- GH Secret `<NAME>_QA` is re-exported as `<NAME>` inside `ci.yml`'s test steps.
- `.devcontainer/.env` carries the QA value under the `_QA` suffix (deliberately suffixed so any Claude Code instance running in the devcontainer doesn't mis-detect it as its own credential and prompt). A gitignored bridge file (e.g. `supabase/functions/.env`) re-names it to the canonical inside the local function-serve process.
- GH Secret `<NAME>_PROD` is pushed to the production runtime's secret store as `<NAME>` automatically by the deploy workflow — never lands on a local disk.

Operator setup is a checklist: create both GH Secrets; mint a separate prod-only key from the vendor's console; set the QA value in `.devcontainer/.env`; create the gitignored bridge file. First deploy after the prod secret exists auto-pushes it to the runtime.

## Authoring locked files (denied-path recipe)

Some paths are intentionally write-denied for Claude's Write/Edit/Bash tools — `.devcontainer/`, `/devshop/template/**`, `/devshop/kit/scripts/**` (canonical tree only — worktree copies are editable), root-owned `.claude/settings.json` + `.dcg.toml` (locked by `init-devshop.sh`), anything under `/etc/` or `/usr/local/bin/`. The denials are deliberate — these surfaces shouldn't be silently rewritten by a session.

When Claude needs to author or update a denied path, the recipe is:

1. **Write the new content to `/tmp/<flat-filename>`.** Flat — no `.devcontainer/` segments in the staging tree. The harness has intent-aware enforcement that recognizes path-staging like `/tmp/.devcontainer/...` as an attempt to bypass the deny. Use flat names: `/tmp/devcontainer.json`, NOT `/tmp/.devcontainer/devcontainer.json`. `Write` is always allowed on bare `/tmp/<file>`.

2. **Hand the operator a single sudo block to paste once.** Use `install -m <mode> -o <owner> -g <group>` for root-owned destinations (mode + owner + group set atomically in one call; safer than `cp` + `chmod` + `chown`):

   ```bash
   sudo install -m 0644 -o root -g root /tmp/devcontainer.json /workspace/.devcontainer/devcontainer.json
   sudo install -m 0644 -o root -g root /tmp/devshop-port-flat/compose.yml /devshop/template/.devcontainer/compose.yml
   sudo install -m 0755 -o root -g root /tmp/devshop-port-flat/init-host-env.sh /devshop/template/.devcontainer/init-host-env.sh
   ```

3. **For multi-file changes, group every `install` call into ONE fenced block** so the operator pastes once. The operator can `diff /tmp/X /workspace/X` first to audit before installing.

### Why `-o root -g root` is required

`install` does NOT change ownership unless told to; without those flags the destination inherits the staging file's owner (which is `node`, since `/tmp/<file>` was created by Claude's Write tool), silently breaking root-ownership invariants on `.claude/settings.json`, `.dcg.toml`, and every commit-hook under `kit/scripts/commit-hooks/`.

The drift is invisible at install time (the file is in place, the diff is correct) and only surfaces later when the freshness check reads `chown root:root` on a now-node-owned file. Codified 2026-05-12 after a freshness-check install silently dropped to node:node.

### Trigger phrases the harness emits

- `"Permission for this action has been denied"`
- `"Permission to use Bash with command ... has been denied"`
- `"File is in a directory that is denied by your permission settings"`

Even `mkdir` / `cat > file` / `tee` via Bash is denied when the target sits under one of these path patterns. **Do NOT loop trying alternative tools** when Write returns "directory denied" or Bash returns "Permission to use Bash with command" — switch to the `/tmp + sudo install` handoff immediately.

Codified 2026-04-27 after the lalista devcontainer migration repeatedly hit `.devcontainer/` denials; expanded 2026-04-28 to call out `/devshop/template/**` + Bash-also-denied + intent-aware path-staging detection.

## Known Gaps

- **Fakeowner caveat** — Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic (displayed but not enforced by the kernel). Root ownership only provides real protection on native Linux or Docker named volumes. See ROADMAP.md § v+ for hardening options.
- **Bash bypasses deny rules** — Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either. DCG custom block rules were attempted but cause false positives on git commands (git add, git commit mention the filenames). See ROADMAP.md § v+ for planned fix.
