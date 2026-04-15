# Security + Quality

## Core Principle

**Claude cannot weaken its own guardrails.** Six layers of protection enforce this:

1. **Root ownership + sticky bit** — security-critical files are `root:root 644`, sticky bit on `.claude/` prevents deletion
2. **Deny rules** — `settings.json` explicitly denies Edit on itself, `.dcg.toml`, `.devcontainer/*`, guard scripts
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

All `kit/scripts/*.sh` are also root-locked — `init-devshop.sh` globs and locks every script in the directory (`root:root 644`). This breaks the circularity where the scripts that watch `settings.json` were themselves only protected by `settings.json`.

## Edge Function Auth

Edge functions always validate auth server-side — `getUser()` to verify against auth server, even with gateway JWT verification.

## Secrets in CI

Wired into `ci.yml` in the same PR as the integration — never a follow-up.

## Third-Party Binaries

Pinned to specific version + SHA256 checksum. Never "latest." Update version + checksum in same commit.

## Guard Script Editing

Guard script deny rules are easy to toggle — when the user wants Claude to edit guard scripts, uncomment the four `kit/scripts/*` deny lines in settings.json.

## `.claude/` Allow vs settings.json Deny

`Edit(.claude/**)` allows Claude to edit skills, commands, and memory through the symlink path. `settings.json` is safe: the explicit `Edit(**/.claude/settings.json)` deny takes priority.

## Known Gaps

- **Fakeowner caveat** — Docker Desktop bind mounts from macOS use `fakeowner`, where `chown`/`chmod` are cosmetic (displayed but not enforced by the kernel). Root ownership only provides real protection on native Linux or Docker named volumes. See ROADMAP.md § v+ for hardening options.
- **Bash bypasses deny rules** — Edit/Write deny rules don't prevent Bash commands from modifying protected files (e.g., `python3 -c "open('file','w')"`). On fakeowner mounts, root ownership doesn't help either. DCG custom block rules were attempted but cause false positives on git commands (git add, git commit mention the filenames). See ROADMAP.md § v+ for planned fix.
