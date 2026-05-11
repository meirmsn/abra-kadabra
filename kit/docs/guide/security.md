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
- [Known Gaps](#known-gaps)

## Core Principle

**Claude cannot weaken its own guardrails.** Six layers of protection enforce this:

1. **Root ownership + sticky bit** — security-critical files are `root:root 644`; sticky bit on `.claude/` and `.devcontainer/` in both repos (plus `template/.devcontainer/`) prevents node from deleting root-owned files
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
- `.devcontainer/*` — container config (Dockerfile, init-devshop.sh, init-firewall.sh, devcontainer.json, checksums.sha256), firewall, secrets
- `.husky/pre-commit` — gates commit-time guards (gitleaks, mixed-commit, Layer 1 docs/tests-coverage hooks); tampering silently disables them
- `.husky/prepare-commit-msg` — appends `Tests-Coverage-Bypass:` / `Docs-Coverage-Bypass:` trailers when bypass flags are set; tampering hides bypass evidence from audit-time review
- `.husky/pre-push` — gates push-time guards (no-direct-push-to-main, dirty-tree adversarial review); tampering silently disables them

All scripts under `kit/scripts/` (recursive — covers `commit-hooks/`, `preship/`, `notify/`, `sync/`, etc.) are also root-locked — `init-devshop.sh` runs `find $DEVSHOP/kit/scripts/ -type f -name '*.sh'` at container start and chowns each to `root:root 644`. This breaks the circularity where the scripts that watch `settings.json` were themselves only protected by `settings.json`. The two-layer model (Layer 1 = settings.json deny rules, Layer 2 = filesystem ownership) is documented inline in `.claude/settings.json` permission rules:

```json
"Edit(kit/scripts/**)",          // matches subdirectories too
"Write(kit/scripts/**)",
"Edit(/devshop/kit/scripts/**)", // absolute-path variant
"Write(/devshop/kit/scripts/**)",
```

The `**` recursive glob is load-bearing — single-segment `*` would not match `kit/scripts/commit-hooks/commit-guard.sh` and would let Claude bypass Layer 1 by editing subdirectory scripts. (Layer 1 widening from `*` → `**` shipped in v1.20.0 after the gap was exploited unintentionally during the cross-repo check removal session — the file was Layer-2-eroded by prior git activity AND Layer-1-uncovered by the single-segment glob.)

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

Pinned to specific version + SHA256 checksum. Never "latest." Update version + checksum in same commit.

## Guard Script Editing

Guard script deny rules are easy to toggle — when the user wants Claude to edit guard scripts, uncomment the four `kit/scripts/**` deny lines in settings.json (relative + absolute path variants for both `Edit` and `Write`). The `**` recursive glob covers subdirectory scripts too (`commit-hooks/`, `preship/`, etc.); a previous single-segment `*` glob shipped briefly through v1.19.x and was tightened in v1.20.0.

## `.claude/` Allow vs settings.json Deny

`Edit(.claude/**)` allows Claude to edit skills, commands, and memory through the symlink path. `settings.json` is safe: the explicit `Edit(**/.claude/settings.json)` deny takes priority.

## Memory Write Protection

Memory files (`.claude/memory/`, `.claude/projects/*/memory/`) are protected at two levels:

1. **Write/Edit hook** (`check-memory-created.sh`) — blocks the Write and Edit tools, forces Claude to classify the memory (project vs. devshop) and get user confirmation before writing.
2. **Bash deny rules** — blocks Bash commands that redirect output to memory paths (`cat >`, `>>`, `tee`). Prevents bypassing the classification hook via shell redirects.

`MEMORY.md` (the index file) is exempt from the Write/Edit hook — it's updated alongside memory files to maintain the index.

## Runtime Validation at Trust Boundaries

LLM-backed edge functions and third-party HTTP APIs are trust boundaries: their response shapes are not provable at compile time and can drift silently. Every Supabase / third-party edge-fn response with a hand-written shape must be parsed with Zod at the wrapper boundary (in `packages/core/src/api/<feature>.ts`) — never inside a React component or server action. Schemas live in `packages/core/src/schemas/<feature>.ts` (the template ships this directory with a placeholder README). The full pattern + worked examples are at [`wrapper-boundaries.md § Runtime Validation`](./wrapper-boundaries.md#runtime-validation-at-llm--edge-function-boundaries). This section names runtime validation as a security control to keep the cross-skill view ("auth + boundary + validation") cohesive — substance lives in `wrapper-boundaries.md`.

## Known Gaps

- **Fakeowner caveat** — Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic (displayed but not enforced by the kernel). Root ownership only provides real protection on native Linux or Docker named volumes. See ROADMAP.md § v+ for hardening options.
- **Bash bypasses deny rules** — Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either. DCG custom block rules were attempted but cause false positives on git commands (git add, git commit mention the filenames). See ROADMAP.md § v+ for planned fix.
