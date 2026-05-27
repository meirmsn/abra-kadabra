# Devshop Separation Architecture

> **Out of routing index** — read on first project setup or when first navigating the codebase, not per-feature work.

The devshop (abra-kadabra) and the project repo are separate git repositories. The project repo is clean and publishable — it contains only project code, build config, and CI. All devshop infrastructure gets **injected at container start** via symlinks.

For the conceptual model (layers, pipeline, file lifecycle): see [`../OVERVIEW.md § Concept`](../OVERVIEW.md#concept)

## Contents

- [Two repos, one workspace](#two-repos-one-workspace)
- [What lives where](#what-lives-where)
- [How init-devshop.sh works](#how-init-devshopsh-works)
- [File lifecycle](#file-lifecycle)
- [Doing project work](#doing-project-work)
- [Doing devshop work](#doing-devshop-work)
- [When devshop changes take effect](#when-devshop-changes-take-effect)
- [Propagating build tooling updates](#propagating-build-tooling-updates)
- [Public contributors (without devshop)](#public-contributors-without-devshop)
- [Devshop Repo Layout](#devshop-repo-layout)
- [Known gotchas](#known-gotchas)
- [Documentation Structure](#documentation-structure)

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
├── BUILD-LOG.md           ← project-owned (template copied by ak-new-project)
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
| `BUILD-LOG.md`                            | project      | yes      | copied from template by ak-new-project during Phase A                   |
| `.devcontainer/`                          | project      | yes      | already there                                                           |
| `.husky/`, `.github/`, `turbo.json`, etc. | project      | yes      | already there                                                           |
| `apps/`, `packages/`, `supabase/`         | project      | yes      | already there                                                           |
| Sessions, API keys, credentials           | neither      | no       | `~/.claude/` volume (persists across rebuilds)                          |

## How init-devshop.sh works

Runs as root via sudo on every container start (`postStartCommand`). The project's `.devcontainer/init-devshop.sh` is a thin forwarder that delegates to `/devshop/kit/scripts/init-devshop.sh` (the real script). Includes a devshop-self guard that skips injection when the workspace IS the devshop (prevents destructive symlink-over-directory). Symlink creation is in `sync/create-devshop-symlinks.sh` (called by init-devshop.sh, and also by session-start.sh and .husky/pre-commit for reactive recovery when symlinks are lost by git ops).

## File lifecycle

`kit/manifest.txt` is the single source of truth for every workspace path managed by the devshop. Each declared path carries an inline `[tag]` annotation describing how it stays current. The shared parser is `kit/scripts/sync/lib/parse-manifest.sh`.

| Annotation        | Meaning                                                                                                                                                                                                                                                                    | Where it's enforced                                                                                       |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `[symlink]`       | Node-owned symlink to devshop, always matches devshop. Auto-recovered if lost by git ops.                                                                                                                                                                                  | `sync/create-devshop-symlinks.sh` (run by `init-devshop.sh`, `session-start.sh`, and `.husky/pre-commit`) |
| `[locked]`        | Root-owned copy, refreshed every container start. Project cannot edit (`chown root:root`; mode derived per-file from the template source — 644 for config, 755 for executables like `init-host-env.sh` + `supabase-runner/cmd-relay.mjs`). Freshness verified each commit. | `init-devshop.sh` install loop + `commit-hooks/check-security-files-freshness.sh`                         |
| `[locked-dir]`    | Sticky-bit dir (`chmod 1755`) holding `[locked]` leaves. Prevents node from deleting locked files.                                                                                                                                                                         | `init-devshop.sh` sticky-bit loop                                                                         |
| `[sync]`          | Manual bidirectional sync; project owns its copy and may diverge.                                                                                                                                                                                                          | `sync/from-devshop.sh` and `sync/to-devshop.sh`                                                           |
| `[scaffold-once]` | Copied once at `/ak-new-project` create time; project owns thereafter. Template's version becomes irrelevant.                                                                                                                                                              | `/ak-new-project` Phase A rsync                                                                           |

**Project-only files** (no devshop source): files that exist only in the project repo and are never managed by the manifest. Examples: `.devcontainer/.env` (secrets + derived port keys), `.claude/settings.local.json` (per-project permission grants), `CLAUDE.md` once it has diverged from the scaffold, `apps/`, `packages/`, `supabase/`. These don't appear in the manifest. `.devcontainer/.env.example` is `[scaffold-once]` — seeded from the template at create time, documents every `.env` key including the 5 derived port keys (with a note to edit `config.toml` not `.env` directly).

**Derived files.** `.devcontainer/.env` is a hybrid: operator-written secrets (`GITHUB_TOKEN`, `DEVCONTAINER_ROOT_PASSWORD`, etc.) live alongside mechanically-derived `SUPABASE_*_PORT` keys. The port keys are written by `derive-ports-from-config.sh` (sourced from `supabase/config.toml`) on every container start — operators should edit `config.toml` ports, not `.env` ports directly. The script runs host-side via `initializeCommand` and again container-side via `init-devshop.sh` as a backstop.

**Why copies instead of symlinks for `[locked]`:** symlinks are fragile — git ops can delete them, and node can replace symlink targets. Root-owned copies survive git ops and can't be tampered with.

**`[locked]` for operator recovery tools:** the annotation isn't only for security infrastructure (`init-firewall.sh`, `init-devshop.sh`). It also fits operator-callable scripts that need NOPASSWD sudo (e.g., `refresh-allowed-ips.sh`, which re-resolves volatile-IP CDN domains for the firewall ipset). The Dockerfile pattern is identical: `COPY <script> /usr/local/bin/` plus a per-script line in `/etc/sudoers.d/node-firewall`. This is the canonical shape for adding a new "node user can ask root to do <narrow thing>" entry-point — small-hole by construction because the script lives in a root-owned manifest-locked path the workspace user can't mutate.

**Boot-only companion scripts (no sudoers entry):** when an operator-callable script needs runtime input that should NOT be tamperable mid-session, the canonical shape is a paired boot-only script that copies the operator-set value from `.devcontainer/.env` (which sits on Docker Desktop's `fakeowner` virtiofs and is therefore writable by `node` despite appearing root-owned) into `/etc/<scope>/` (overlay-fs, kernel-enforced root-only writes). `init-prod-url.sh` is the canonical example — invoked from `init-firewall.sh`'s root context at container start, validates and writes `/etc/refresh-allowed-ips/production_url`, and is deliberately NOT given a NOPASSWD entry so a compromised npm dep cannot ask root to re-read a tampered `.env` mid-session. `refresh-allowed-ips.sh` then reads from the locked file. Cost: changing the value requires container rebuild, not just a script re-run. Use this shape whenever a sudo-callable script's behavior depends on operator-set config that must remain trustworthy in a long-lived session.

**Manifest as single source of truth:** every consumer reads the manifest via the shared parser. `init-devshop.sh` iterates `[locked]` and `[locked-dir]`; `sync/from-devshop.sh` and `sync/to-devshop.sh` iterate `[sync]` (and exclude `[locked]` leaves under `[sync]` directories); `commit-hooks/check-security-files-freshness.sh` verifies every `[locked]` file matches its template source. Two hardcoded carve-outs remain by design: (1) `sync/create-devshop-symlinks.sh`'s body stays inline because per-symlink source paths vary (kit/, .claude/skills/, hooks/) — a structural test asserts every `[symlink]` manifest entry has a matching `ln -sfn` line; (2) `init-devshop.sh`'s devshop-self lock loop and `.claude` sticky-bit stay hardcoded because they protect devshop-bootstrap files and a project-special directory not present under `template/`. Both carve-outs are documented inline in the scripts. `/ak-new-project` Phase A still uses an implicit `template/` rsync; `[scaffold-once]` annotations are declarative for now and will become a consumed list when `ak-new-project` is refactored.

**Hybrid lifecycle — `[scaffold-once]` + chown-on-every-start (firewall-extra-domains).** Some project-owned files need the project to be able to modify them via the operator (with `sudo`) but NOT via the `node` user (Claude / `pnpm install` / a compromised npm dep). `.devcontainer/firewall-extra-domains` is the canonical example: it's `[scaffold-once]` (seeded from `template/.devcontainer/firewall-extra-domains` at first container start; project owns the content thereafter), but `init-devshop.sh` chowns it to `root:root 644` on every subsequent start so node-user writes are blocked at the OS level. The seed-if-missing + always-chown logic is a bespoke block in `init-devshop.sh` — not expressible via a single manifest annotation today. This shape exists because the project's firewall additions must persist across container starts (which `[scaffold-once]` provides) AND must be tamper-resistant from inside the workspace (which `[locked]` would provide if it didn't also force template-overwrite on every start). The trade-off: a new manifest annotation could capture this third lifecycle, but with one consumer it stays bespoke. Promote to a manifest annotation when a second file needs the same shape. (Background: this overlay was added to fix the silent-revert trap where Step 6 of `/ak-new-project` told operators to edit `init-firewall.sh` directly — `[locked]` enforcement reverted those edits on every container start, so the executed `/usr/local/bin/` runtime kept stale or malformed entries while the workspace source-of-truth looked clean.)

## Doing project work

All project work happens in the project repo. Branches, PRs, commits — all on the project's GitHub.

- `git status` only shows project files (devshop files are gitignored)
- Commits use conventional commits (`feat:`, `fix:`, `chore:`, etc.)
- PRs go to the project repo — clean diffs, no devshop noise
- Edit `CLAUDE.md` for project-specific Claude guidance (tracked)
- Edit `BUILD-LOG.md`, `TODOS.md`, `METRICS.md` as normal project docs

## Doing devshop work

Devshop changes go to the abra-kadabra repo. Since `.devshopkit/` is a symlink to `/devshop/kit/`, edits to devshop files are automatically in the abra-kadabra working tree.

**No GitHub PRs on devshop** — devshop is a single-developer private repo where pre-commit guards (Layer 1 docs/tests-coverage hooks, mixed-commit, manifest, clean-tree, security-files-freshness, gitleaks, lint, typecheck, test suite) are the inner quality gate, and audit-time `/ak-check-docs-and-tests` (fired automatically inside `/ak-merge-devshop` Phase 1) is the outer gate. Land via feature branch + `/ak-merge-devshop` (squash-merge with structured commit message + push + cleanup); the skill is the canonical merge path.

```bash
cd /devshop                                          # abra-kadabra repo
git checkout -b feat/<topic>                         # branch off main
# ... edits + commits with conventional-commit messages ...
# then: invoke /ak-merge-devshop — it audits, composes the squash commit
# message (with operator approval gate), squash-merges, pushes, and
# deletes the feature branch local + remote.
```

For parallel work in flight, develop in a linked worktree
(`git worktree add .worktrees/<topic> -b <type>/<topic> origin/main && git -C .worktrees/<topic> submodule update --init --recursive`);
invoke `/ak-merge-devshop` from `/devshop` on `main` and the skill
auto-detects the worktree, runs the squash in it via `git -C`, and
tears the worktree down in Phase 4.2 cleanup. No manual `git worktree
remove` step. The submodule-init step is required because `git worktree
add` does NOT auto-checkout submodule contents into the new worktree —
bats tests fail without it (the bats vendored libraries are submodules).
See `CLAUDE.md § Parallel work via linked worktrees` for the convention.

- Devshop commits use conventional commits (`feat:`, `fix:`, `chore:`, etc.)
- Most injected files are symlinks — edits in `/devshop/` take effect immediately. The exceptions are `settings.json` and `.dcg.toml`, which are copies (see File Lifecycle above). The lock step (`chown root:root`) applies to both copies in `/workspace/` and the source files in `/devshop/`.

## When devshop changes take effect

| What you changed                                                       | When it takes effect               | Why                                                       |
| ---------------------------------------------------------------------- | ---------------------------------- | --------------------------------------------------------- |
| Skills, scripts, docs (`kit/`, `.claude/skills/`, `.claude/commands/`) | Immediately                        | Symlinks resolve live                                     |
| Devshop `CLAUDE.md` or project `CLAUDE.md`                             | Immediately                        | Claude Code watches CLAUDE.md files and reloads on change |
| Shared build tooling (`.husky/`, `turbo.json`, CI, etc.)               | Manual: run `sync/from-devshop.sh` | Project owns its copy — can diverge from devshop          |

## Propagating build tooling updates

Build tooling files (`turbo.json`, `eslint.config.mjs`, `.husky/`, etc.) are tracked in both repos — abra-kadabra has the base version, the project has its copy. They can diverge.

To pull devshop updates into a project:

```bash
.devshopkit/scripts/sync/from-devshop.sh          # previews diff, applies on confirm
.devshopkit/scripts/sync/from-devshop.sh --yes    # skip prompt (CI / scripted use)
```

To push project improvements back to the devshop:

```bash
.devshopkit/scripts/sync/to-devshop.sh             # previews diff, applies on confirm
.devshopkit/scripts/sync/to-devshop.sh --yes       # skip prompt (CI / scripted use)
```

`manifest.txt` defines which files the sync scripts operate on. See `kit/manifest.txt`.

**Invocation pattern.** Both sync scripts must be invoked from the project root via the `.devshopkit/...` symlink path (`bash .devshopkit/scripts/sync/from-devshop.sh`), not via the canonical `/devshop/kit/scripts/sync/...` path. The scripts compute `PROJECT_ROOT` as 3 path components up from `SCRIPT_DIR` — i.e. `<project>/.devshopkit/scripts/sync/` → `<project>` — and look up `manifest.txt` at `$PROJECT_ROOT/.devshopkit/manifest.txt` (which resolves via the same `.devshopkit` symlink). Invoking via the canonical path lands `PROJECT_ROOT` at `/devshop`, and `MANIFEST=/devshop/.devshopkit/manifest.txt` doesn't exist. If the `.devshopkit` symlink is missing (lost by a git op), recreate it first with `bash /devshop/kit/scripts/sync/create-devshop-symlinks.sh` — that script IS safe to invoke via the canonical path because it doesn't need the symlink it's about to create.

**Show-first-confirm-then-apply semantics.** Both sync scripts stage proposed changes to a temp directory, display a unified diff with a summary (`N files would change (M modified, K added, L deleted)`), then prompt `y/N/diff` via `/dev/tty`. Only on `y` does the script apply changes to the working tree. Aborting (`N` or empty input) is a clean no-op — nothing is modified. The `--yes` / `-y` flag bypasses the prompt for CI or scripted invocations.

**Three-source exclude model under `[sync]` directories.** When a `[sync]` entry in `kit/manifest.txt` is a directory, the `rsync -a --delete` that copies it must NOT touch leaves owned by other lifecycles. Both sync scripts build `--exclude` args from three manifest sources:

1. **`!path` exclusions** — explicit per-file opt-outs declared in the manifest. Required for gitignored project state living under a `[sync]` directory (`.devcontainer/.env` carries `LOCAL_WORKSPACE_FOLDER` + any per-project port overrides — clobbering it loses the file entirely since gitignored content isn't recoverable from `git checkout`).
2. **`[locked]` leaves** (via `manifest_locked_under <dir>`) — refreshed every container start by `init-devshop.sh`. The sync direction is template→project for from-devshop and project→template for to-devshop; in either direction, syncing these leaves would round-trip drift over the canonical version.
3. **`[scaffold-once]` leaves** (via `manifest_scaffold_once_under <dir>`) — project narrative (`firewall-extra-domains`, project `CLAUDE.md`, etc.). Project's local content has diverged from the template's seed value by design; syncing would clobber that divergence.

Without all three, a `.devcontainer/ [sync]` parent would propagate over its own `.env` exclusion + every `[locked]` config file + the `firewall-extra-domains` operator overlay. Regression coverage: `kit/tests/manifest-lifecycle.bats` § `from-devshop.sh excludes` / `to-devshop.sh excludes`.

**`.gitignore` is `[sync]` (clobber-not-merge).** Despite the manifest's `[sync]` annotation saying _"project owns its copy and may diverge,"_ `from-devshop.sh` does plain `cp` for most `[sync]` files (no merge). **Exception: `package.json`** — `from-devshop.sh` uses a jq merge that preserves the project's identity fields (`name`, `version`, `packageManager`) while syncing structural fields (`scripts`, `devDependencies`, `pnpm`, `lint-staged`) from the template. If jq is unavailable, falls back to raw copy. A project's local `.gitignore` additions get overwritten by the template's copy on each sync. The template `.gitignore` therefore must contain every exclusion a project would reasonably need — including the per-feature artifact sinks declared by `kit/docs/guide/conventions.md § Screenshot Routing` (`specs/*/screenshots/`, `specs/*/qa-walk/`). `kit/tests/structural-invariants.bats § wiring: template .gitignore matches Screenshot Routing convention` asserts both patterns are present so a future template refactor can't silently drop the exclusion. Regression context: `specs/*/screenshots/` was missing from `template/.gitignore` through 2026-05-22 — projects added it locally and lost it on first `from-devshop.sh` sync.

## Public contributors (without devshop)

Contributors who clone the project without abra-kadabra get a working repo:

- `pnpm install && pnpm turbo run dev` works
- `.devcontainer/` works (init-devshop.sh forwarder is a no-op without `/devshop`)
- `CLAUDE.md` is project-only by design (no `/devshop/...` paths, no devshop conventions duplicated) — works out of the box with Claude Code, points at nothing the public contributor can't see, reads as standard project documentation
- No devshop skills, hooks, or quality gates — just standard development

The "project CLAUDE.md is self-sufficient" property is structural — kept by the SessionStart hook delivering devshop context to project sessions at runtime instead of via file copy or sync. See `/devshop/CLAUDE.md § Session Start` for the mechanism, FAQ § "Why are there two CLAUDE files?" for the rationale, and `/ak-new-project § Step 12.6` for the operational what-goes-where checklist at scaffold time.

## Devshop Repo Layout

When working in the devshop repo (`/devshop/`):

- **Root** = devshop infrastructure only (minimal package.json, .devcontainer/, shared configs).
- **`template/`** = project skeleton. Copied by `/ak-new-project` Phase A. Deny-ruled — do not modify directly via Claude (use sync scripts after project changes).
- **`kit/`** = the devshop kit — docs (`kit/docs/`), scripts (`kit/scripts/`), hooks (`kit/hooks/`), tests (`kit/tests/`), notes, backlogs. Symlinked as `.devshopkit` into project repos.
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
- **Migration commits (one-time)**: `git rm --cached` on gitignored files can behave unexpectedly during pre-commit hooks. Use `--no-verify` for one-time migration commits that bulk-remove tracked files.
- **Heredoc terminal indentation**: Pasting heredocs in the terminal may add leading whitespace. Use `sed -i 's/^  //' file` to strip, or write from a script.

---

## Documentation Structure

All devshop docs live in `kit/docs/`. Three types: reference docs (living), backlogs (growing), and build blueprints (historical).

### Reference docs (living — update together in the same commit)

- `kit/docs/OVERVIEW.md` — bird's eye view (~60-80 lines). Read for orientation.
- `kit/docs/guide/` — operational reference (this directory). Read when implementing or shipping.

Doc coverage enforcement: per-commit Layer 1 hooks (`check-docs-coverage-{project,devshop}.sh`) catch obvious file-pairing gaps; bypass via `git -c devshop.docsCoverageReason="<reason>"` accepts on flag presence and emits a `Docs-Coverage-Bypass:` trailer. Audit-time Layer 2 (`/ak-docs-review`, fired by `/ak-check-docs-and-tests` at `/ak-pre-ship` Gate 5 and `/ak-build` Phase 5.8) judges the diff with the full doc context and harvests trailer entries as `[bypass-revisit]` findings. The per-commit `docs-reviewed` adversarial check that ran before PR-C of the audit-time migration was retired alongside the move — see `kit/ROADMAP.md § PR-C` and `kit/docs/guide/conventions.md § Bypass trailers`.

### Backlogs (living — grow independently)

- `kit/TODOS.md` — tactical (friction, bugs, small fixes). Items can have version tags (e.g., `[v0.2]`).
- `kit/ROADMAP.md` — strategic (capabilities, major improvements). Defines version milestones.

See "Backlog Routing Guide" in [`conventions.md`](conventions.md) for routing rules. Project backlogs (`TODOS.md`, `PRODUCT-ROADMAP.md`) are separate.

### Build blueprints (one-time — historical after execution)

- `kit/notes/bootstrap/v0-web.md` — web devshop construction.
- `kit/notes/bootstrap/v+-native.md` — native/mobile capability (deferred).

Blueprints are not synced to projects — they live in the devshop repo as construction history for the devshop maintainer.
