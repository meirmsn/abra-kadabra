# Devshop Separation Architecture

The devshop (abra-kadabra) and the project repo are separate git repositories. The project repo is clean and publishable — it contains only project code, build config, and CI. All devshop infrastructure gets **injected at container start** via symlinks.

For the conceptual model (layers, pipeline, file lifecycle): see [`../MODEL.md`](../MODEL.md)

## Two repos, one workspace

```
Host filesystem:
├── abra-kadabra/          ← devshop repo
│   ├── template/          ← project skeleton (copied by /ak-new-project)
│   ├── kit/               ← scripts, docs, hooks
│   ├── .claude/           ← skills, commands, settings
│   ├── .devcontainer/     ← devshop's own container config (thin forwarder)
│   ├── CLAUDE.md          ← devshop conventions for Claude
│   └── (shared configs)   ← .editorconfig, eslint.config.mjs, etc.
│
└── my-project/            ← project repo (mounted at /workspace)
    ├── .devcontainer/     ← Dockerfile, firewall, thin forwarder
    ├── CLAUDE.md          ← project-specific Claude context (tracked)
    ├── .claude/memory/    ← Claude memory (tracked)
    ├── apps/, packages/   ← project code
    └── (build configs)    ← turbo.json, eslint, etc. (tracked)

Inside container:
/workspace/                ← project repo (bind mount)
├── .devshopkit/           ← symlink → /devshop/kit/
├── .claude/               ← created by init-devshop.sh (skills, settings)
├── CLAUDE.md              ← project-specific Claude context (tracked)
├── BUILD-LOG.md           ← created if missing
├── .dcg.toml              ← copy of /devshop/.dcg.toml (root-owned)
└── (everything else)      ← project files, tracked normally

/devshop/                  ← abra-kadabra (bind mount, CLAUDE.md auto-loaded via additionalDirectories)
```

**Scope expansion:** `additionalDirectories: ["/devshop"]` in `.claude/settings.json` tells Claude Code to treat `/devshop/` as part of the project. This lets `acceptEdits` mode auto-approve Read/Edit on devshop files without per-path allow rules. The Bash allow list also includes common read-only utilities (`cat`, `find`, `head`, `tail`, `wc`, `echo`, `git show`) so skills and hook scripts can use them without prompts — Claude itself should still prefer dedicated tools (Read, Grep, Glob) per its system instructions.

## What lives where

| Content                                   | Repo         | Tracked? | How it gets to /workspace                                               |
| ----------------------------------------- | ------------ | -------- | ----------------------------------------------------------------------- |
| `kit/` (scripts, docs, hooks)             | abra-kadabra | yes      | symlink by init-devshop.sh                                              |
| `.claude/skills/`, `.claude/commands/`    | abra-kadabra | yes      | symlink by init-devshop.sh                                              |
| `.claude/settings.json`, `.dcg.toml`      | abra-kadabra | yes      | copied by init-devshop.sh (root-owned, freshness-checked in pre-commit) |
| `CLAUDE.md` (devshop conventions)         | abra-kadabra | yes      | auto-loaded via `additionalDirectories` in settings.json                |
| `CLAUDE.md` (project context)             | project      | yes      | already there                                                           |
| `.claude/memory/`                         | project      | yes      | already there                                                           |
| `BUILD-LOG.md`                            | project      | yes      | created by init-devshop.sh if missing                                   |
| `.devcontainer/`                          | project      | yes      | already there                                                           |
| `.husky/`, `.github/`, `turbo.json`, etc. | project      | yes      | already there                                                           |
| `apps/`, `packages/`, `supabase/`         | project      | yes      | already there                                                           |
| Sessions, API keys, credentials           | neither      | no       | `~/.claude/` volume (persists across rebuilds)                          |

## How init-devshop.sh works

Runs as root via sudo on every container start (`postStartCommand`). The project's `.devcontainer/init-devshop.sh` is a thin forwarder that delegates to `/devshop/kit/scripts/init-devshop.sh` (the real script). Includes a devshop-self guard that skips injection when the workspace IS the devshop (prevents destructive symlink-over-directory). Symlink creation is in `create-devshop-symlinks.sh` (called by init-devshop.sh, and also by session-start.sh and .husky/pre-commit for reactive recovery when symlinks are lost by git ops).

## File lifecycle

Every file in `/workspace/` falls into one of five categories based on where it comes from and how it stays current:

**1. Symlinked (always match devshop)**

Node-owned symlinks created by `init-devshop.sh` on container start. If lost by git operations (checkout, stash, clean), auto-recovered by the pre-commit hook via `create-devshop-symlinks.sh`.

Files: `.devshopkit/`, `.claude/skills/`, `.claude/commands/`, `.claude/README.md`, `.hooks/pre-commit`

**2. Root-owned copies (always match devshop)**

Copied from devshop on every container start. Root-owned (`chown root:root`) so node (Claude) can't modify them. Freshness is verified by `check-security-files-freshness.sh` in the pre-commit hook — warns if stale, recommends `sudo bash /devshop/kit/scripts/init-devshop.sh` to fix.

Files: `.claude/settings.json`, `.dcg.toml`

Why copies instead of symlinks: symlinks are fragile — git ops can delete them, and node can replace symlink targets. Root-owned copies survive git ops and can't be tampered with.

**3. Manifest files (can diverge per project)**

Present from the initial clone of the devshop repo (abra-kadabra). After that, project-owned — they can and do diverge (e.g., `.gitignore` adds project-specific exclusions). Manually synced in either direction via `sync-from-devshop.sh` / `sync-to-devshop.sh`, which read the file list from `kit/manifest.txt`.

Files: `.prettierrc`, `turbo.json`, `eslint.config.mjs`, `.husky/`, `.github/workflows/`, `.devcontainer/`, and other build tooling (see `manifest.txt` for the full list)

**4. Generated (created at runtime if missing)**

Created by `init-devshop.sh` on container start if not present. Once created, project-owned and tracked.

- `BUILD-LOG.md` — copied from `/devshop/template/BUILD-LOG.md` if missing, then project-owned

**5. Project-only (never in devshop)**

Files that exist only in the project repo. No devshop source, no sync.

Files: `.devcontainer/.env` (secrets), `.claude/settings.local.json` (project-specific permission grants), `CLAUDE.md`, `.claude/memory/`, `apps/`, `packages/`, `supabase/`, `METRICS.md`, `TODOS.md`

## Doing project work

All project work happens in the project repo. Branches, PRs, commits — all on the project's GitHub.

- `git status` only shows project files (devshop files are gitignored)
- Commits use conventional commits (`feat:`, `fix:`, `chore:`, etc.)
- PRs go to the project repo — clean diffs, no devshop noise
- Edit `CLAUDE.md` for project-specific Claude guidance (tracked)
- Edit `BUILD-LOG.md`, `TODOS.md`, `METRICS.md` as normal project docs

## Doing devshop work

Devshop changes go to the abra-kadabra repo. Since `.devshopkit/` is a symlink to `/devshop/kit/`, edits to devshop files are automatically in the abra-kadabra working tree.

```bash
cd /devshop                    # abra-kadabra repo
git status                     # see devshop changes
git add -A && git commit -m "chore: ..."
# Push works if GH_TOKEN is in /devshop/.devcontainer/.env, otherwise push from host
```

- Devshop commits use conventional commits (`feat:`, `fix:`, `chore:`, etc.)
- Most injected files are symlinks — edits in `/devshop/` take effect immediately. The exceptions are `settings.json` and `.dcg.toml`, which are copies (see File Lifecycle above). The lock step (`chown root:root`) applies to both copies in `/workspace/` and the source files in `/devshop/`.

## When devshop changes take effect

| What you changed                                                       | When it takes effect               | Why                                                       |
| ---------------------------------------------------------------------- | ---------------------------------- | --------------------------------------------------------- |
| Skills, scripts, docs (`kit/`, `.claude/skills/`, `.claude/commands/`) | Immediately                        | Symlinks resolve live                                     |
| Devshop `CLAUDE.md` or project `CLAUDE.md`                             | Immediately                        | Claude Code watches CLAUDE.md files and reloads on change |
| Shared build tooling (`.husky/`, `turbo.json`, CI, etc.)               | Manual: run `sync-from-devshop.sh` | Project owns its copy — can diverge from devshop          |

## Propagating build tooling updates

Build tooling files (`turbo.json`, `eslint.config.mjs`, `.husky/`, etc.) are tracked in both repos — abra-kadabra has the base version, the project has its copy. They can diverge.

To pull devshop updates into a project:

```bash
.devshopkit/scripts/sync-from-devshop.sh    # diffs + applies; you review
```

To push project improvements back to the devshop:

```bash
.devshopkit/scripts/sync-to-devshop.sh      # copies to abra-kadabra; you review + push
```

`manifest.txt` defines which files the sync scripts operate on. See `kit/manifest.txt`.

## Public contributors (without devshop)

Contributors who clone the project without abra-kadabra get a working repo:

- `pnpm install && pnpm turbo run dev` works
- `.devcontainer/` works (init-devshop.sh forwarder is a no-op without `/devshop`)
- `CLAUDE.md` is already the standard name — works out of the box with Claude Code
- No devshop skills, hooks, or quality gates — just standard development

## Devshop Repo Layout

When working in the devshop repo (`/devshop/`):

- **Root** = devshop infrastructure only (minimal package.json, .devcontainer/, shared configs).
- **`template/`** = project skeleton. Copied by `/ak-new-project` Phase A. Deny-ruled — do not modify directly via Claude (use sync scripts after project changes).
- **`kit/`** = the devshop kit — docs (`kit/docs/`), scripts (`kit/scripts/`), hooks (`kit/hooks/`), notes, backlogs. Symlinked as `.devshopkit` into project repos.
- **`.claude/`** = Claude Code runtime config (skills, commands, settings). Also symlinked.

Root keeps eslint + friends because `lint-staged` invokes `eslint --fix` on every commit. Practically a no-op (no .ts/.js at root) but removing it would break the pre-commit hook.

Never create CHANGELOG, NOTES, ROADMAP, or other content files at the repo root.

Root `.devcontainer/` and `template/.devcontainer/` are identical — both contain thin forwarders. When updating (e.g., new tool version in Dockerfile), update both.

## Known gotchas

- **macOS bind mount no-execute**: Scripts on the `/devshop/` mount can't execute via shebang (`/usr/bin/env: bad interpreter: Permission denied`). The thin forwarder must use `exec bash /devshop/...` not `exec /devshop/...`.
- **Thin forwarder mechanism**: The Dockerfile COPYs `init-devshop.sh` at build time → baked at `/usr/local/bin/init-devshop.sh`. A NOPASSWD sudoers rule only covers this exact path. The project's `.devcontainer/init-devshop.sh` is a thin forwarder (`[ -f /devshop/... ] && exec bash /devshop/...`) that delegates to abra-kadabra. This way the Dockerfile and sudoers rule don't change — only the forwarder content matters, and it gets re-baked on container rebuild.
- **Container PAT scope**: The project's GitHub token (`.devcontainer/.env`) is scoped to the project repo. To push devshop changes from the container, add `GH_TOKEN=<pat>` to `/devshop/.devcontainer/.env` — `init-devshop.sh` configures git credentials and `release.sh` uses it for push + GitHub release. Without it, push devshop changes from the host.
- **`.devcontainer/` files are root-owned**: Cannot edit inside the container without sudo. Edit from the host filesystem or use `sudo nano <file>`.
- **`[ -e ]` not `[ -f ]` for symlinks**: `[ -f ]` tests for regular files and may return false for symlinks. Use `[ -e ]` (exists) for symlinked paths.
- **gitignore patterns for symlinks**: Use `.devshopkit` and `.claude` (no trailing `/`). A trailing slash only matches directories, but symlinks to directories may not match.
- **Migration commits (one-time)**: `git rm --cached` combined with lint-staged's stash/restore can delete files from disk if they're gitignored. Use `--no-verify` for one-time migration commits that bulk-remove tracked files.
- **Heredoc terminal indentation**: Pasting heredocs in the terminal may add leading whitespace. Use `sed -i 's/^  //' file` to strip, or write from a script.

---

## Documentation Structure

All devshop docs live in `kit/docs/`. Three types: reference docs (living), backlogs (growing), and build blueprints (historical).

### Reference docs (living — update together in the same commit)

- `kit/docs/OVERVIEW.md` — bird's eye view (~60-80 lines). Read for orientation.
- `kit/docs/guide/` — operational reference (this directory). Read when implementing or shipping.

Commit guard enforces: check 3 (doc consistency) blocks if one is staged without the others unless a reason is provided via `git -c devshop.docSyncReason="<reason>"`. `/ak-pre-ship` also enforces.

### Backlogs (living — grow independently)

- `kit/TODOS.md` — tactical (friction, bugs, small fixes). Items can have version tags (e.g., `[v0.2]`).
- `kit/ROADMAP.md` — strategic (capabilities, major improvements). Defines version milestones.

See "Backlog Routing Guide" in [`conventions.md`](conventions.md) for routing rules. Project backlogs (`TODOS.md`, `PRODUCT-ROADMAP.md`) are separate.

### Build blueprints (one-time — historical after execution)

- `kit/notes/bootstrap/v0-web.md` — web devshop construction.
- `kit/notes/bootstrap/v+-native.md` — native/mobile capability (deferred).

Blueprints are not synced to projects — they live in the devshop repo as construction history for the devshop maintainer.
