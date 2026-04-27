# Security + Quality

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

Root-owned copies (not symlinks), verified fresh on every commit:

- `.claude/settings.json` — permissions, hooks, deny rules
- `.dcg.toml` — destructive command patterns
- `.devcontainer/*` — container config, firewall, secrets
- `.husky/pre-commit` — gates commit-time guards (gitleaks, docs-drift, mixed-commit, release-coverage); tampering silently disables them

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

## Known Gaps

- **Fakeowner caveat** — Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic (displayed but not enforced by the kernel). Root ownership only provides real protection on native Linux or Docker named volumes. See ROADMAP.md § v+ for hardening options.
- **Bash bypasses deny rules** — Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either. DCG custom block rules were attempted but cause false positives on git commands (git add, git commit mention the filenames). See ROADMAP.md § v+ for planned fix.
