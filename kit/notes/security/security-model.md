# Security & Permissions Model

How the devshop protects security-critical files from modification by Claude (running as `node`).

## The 6 Layers

### Layer 1: Container startup (`init-devshop.sh`, runs as root)

On every `postStartCommand`, the devcontainer runs `sudo /usr/local/bin/init-devshop.sh`,
which forwards to `/devshop/.devshop/scripts/init-devshop.sh`. This script:

1. **Removes passwordless sudo** — reads `DEVCONTAINER_ROOT_PASSWORD` from `.devcontainer/.env`,
   sets it on root + node, writes `node ALL=(ALL:ALL) ALL` to sudoers (password required).
2. **Creates all symlinks** via `create-devshop-symlinks.sh`.
3. **Copies security files as real files** (not symlinks) — `settings.json`, `.dcg.toml`.
4. **Locks files** — `chown root:root` + `chmod 644` on every security-critical file
   in both `/workspace` and `/devshop`.
5. **Sets sticky bit** — `chmod 1755 /workspace/.claude/`.

### Layer 2: File ownership + sticky bit (OS level)

**Root-owned copies** (can't be written or deleted by node):

| File                          | Why not a symlink?                                                        |
| ----------------------------- | ------------------------------------------------------------------------- |
| `.claude/settings.json`       | Symlinks are fragile — git ops delete them, node could replace the target |
| `.claude/settings.local.json` | Grants additional permissions — same protection needed                    |
| `.dcg.toml`                   | DCG config — controls which Bash commands are blocked                     |
| `.devcontainer/*`             | Dockerfile, init scripts, .env, firewall                                  |
| `CLAUDE.md`                   | Generated file — devshop conventions + project context                    |

**The sticky bit** (`t` in `drwxr-xr-t` on `.claude/`) is the key mechanism: node owns the
directory (can create files like `memory/`), but the sticky bit means node can only delete
files **it owns**. Root-owned `settings.json` inside the directory survives even though node
has write permission on the directory.

**Symlinks** (node-owned, recreatable if lost):

| Symlink             | Target                                  |
| ------------------- | --------------------------------------- |
| `.devshop`          | `/devshop/.devshop`                     |
| `.claude/commands`  | `/devshop/.claude/commands`             |
| `.claude/README.md` | `/devshop/.claude/README.md`            |
| `.claude/skills/*`  | `/devshop/.claude/skills/*`             |
| `.hooks/pre-commit` | `/devshop/.devshop/hooks/pre-commit.sh` |

If symlinks are lost by git operations, the pre-commit hook in `.husky/pre-commit`
re-creates them by calling `create-devshop-symlinks.sh`.

### Layer 3: `settings.json` deny rules (Claude Code level)

Even if Claude tried to use `Edit` or `Write` tools, deny rules block modifications to:

- `.devcontainer/*`, `.claude/settings.json`, `.dcg.toml`
- `.husky/pre-commit`, `.devshop/scripts/*`
- Secrets (`.env*`, `*.pem`, `*.key`, credentials)

This is the Claude Code tool-level block — Claude never even gets to try the filesystem.

### Layer 4: DCG — Destructive Command Guard (Bash hook)

A `PreToolUse` hook runs `dcg` on every Bash command. Blocks dangerous patterns like
`rm -rf` on sensitive paths. Catches Bash-based workarounds that bypass Edit/Write deny rules.

### Layer 5: Git hook chain

Two pre-commit chains run in sequence:

**Husky** (`.husky/pre-commit`):

1. Re-create devshop symlinks if missing
2. `lint-staged` (ESLint + Prettier)
3. `turbo typecheck`
4. `gitleaks protect --staged`
5. Call `.hooks/pre-commit` (the devshop hook)

**Devshop** (`.hooks/pre-commit` → symlink → `.devshop/hooks/pre-commit.sh`):

1. `check-security-files-freshness.sh` — settings.json/dcg.toml match devshop source, are copies not symlinks
2. `check-clean-tree.sh` — no unstaged changes
3. `devshop-commit-guard.sh` — prevents mixed project/devshop commits

### Layer 6: Claude Code PreToolUse hooks (commit-specific)

- **`check-hook-bypass.sh`** — runs on any `git commit` command. Blocks `--no-verify`,
  `HUSKY=0`, `core.hooksPath` bypasses. If `--no-verify` is used with a
  `devshop.hookBypassReason`, an adversarial Claude Sonnet review validates the reason.
  Fail-closed on API error.
- **`check-memory-created.sh`** — runs on Write/Edit to prompt memory saving.

## Copies vs Symlinks

Security-critical files are **copies**, not symlinks. This is deliberate:

- Symlinks are fragile — `git checkout`, `git stash`, `git clean` can delete them.
- Node can replace a symlink target (the symlink itself is node-owned).
- Root-owned copies survive git operations and can't be modified by node.
- `init-devshop.sh` explicitly checks for and removes symlinks before copying:
  `[ -L "$WS/.claude/settings.json" ] && rm` then `cp`.
- Freshness is verified at pre-commit by `check-security-files-freshness.sh` — warns
  if copies differ from devshop source (can't auto-fix since node can't write root-owned files).

## What reaches the public repo?

None of the security files are pushed. All are gitignored:

| File                          | Gitignore rule | Lives where instead            |
| ----------------------------- | -------------- | ------------------------------ |
| `.claude/settings.json`       | `.claude/*`    | Devshop repo (source of truth) |
| `.claude/settings.local.json` | `.claude/*`    | Local only                     |
| `.dcg.toml`                   | `.dcg.toml`    | Devshop repo (source of truth) |
| `CLAUDE.md`                   | `CLAUDE.md`    | Generated at container start   |
| `.devshop`                    | `.devshop`     | Symlink to devshop repo        |
| `.devcontainer/.env`          | `.env`         | Local only (secrets)           |

The project repo only carries `.devcontainer/devcontainer.json` (tells Docker to mount
`/devshop` and run `init-devshop.sh`) and `.husky/pre-commit`. Everything else is injected
at runtime.

## Known gaps

- **Fakeowner caveat** — Docker Desktop bind mounts from macOS use `fakeowner`, where
  `chown`/`chmod` are cosmetic. Layer 2 only provides real protection on native Linux
  or Docker named volumes.
- **Bash bypasses deny rules** — Edit/Write deny rules don't prevent Bash commands from
  modifying files (e.g., `python3 -c "open('file','w')"`). DCG catches common patterns
  but can't cover everything.
- **Sudo scoping** — see `sudo-hardening.md` for analysis. Current model relies on
  password requirement + user approval prompt for `sudo` commands.
