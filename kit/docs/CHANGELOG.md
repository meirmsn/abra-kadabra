# Devshop Changelog

Auto-appended by `sync-to-devshop.sh` and `release.sh` on version bumps.

## v1.3.0 (2026-04-15) — Kit Restructure

**Structural change**: `.devshop/` renamed to `kit/`, conceptual model added, GUIDE.md split.

- refactor: rename `.devshop/` to `kit/` (devshop repo) / `.devshopkit` (project symlink)
- feat: `kit/docs/MODEL.md` — conceptual model document (three layers, two repos, pipeline, file lifecycle)
- refactor: split 59KB GUIDE.md into `kit/docs/guide/` with 7 focused documents (workflow, conventions, hooks, security, architecture, ops)
- refactor: move OVERVIEW.md, FAQ.md, CHANGELOG.md into `kit/docs/`
- chore: group `kit/notes/` into subdirectories (security, design, research, setup)
- fix: use `.devshopkit/` paths in settings.json — hooks run relative to /workspace/
- fix: simplify init-devshop.sh — straight copy instead of sed replacement

## 2026-04-13 — Pre-Split Snapshot

Tagged `pre-split-snapshot` on the **lalista repo** at the bifurcation point (`24652cf`) where `main` diverged into `chore/separate-devshop`. Use this tag to compare against devshop files as they were before the split. See `notes/pre-split-comparison.md` for instructions.

## v1.2.0 (2026-04-14) — Template Separation

**Structural change**: Project template material separated from devshop tooling.

- feat: create `template/` directory at repo root with complete project skeleton (25 files)
- feat: `/ak-new-project` skill replaces `/ak-init` — two-phase: create GitHub repo (Phase A) + guided setup (Phase B)
- feat: `/ak-migrate-project` skeleton skill for adopting devshop on existing projects
- refactor: move `init-devshop.sh` from `.devcontainer/` to `.devshop/scripts/` — all scripts in one place
- refactor: eliminate `.devshop/templates/` — .tmpl files moved into `template/` at final locations
- refactor: simplify root `package.json` — remove turbo + vercel (template has full deps)
- feat: devshop-self guards in 4 scripts — safe to open devshop as its own devcontainer
- feat: `INIT-TRACKER.md` per-project replaces mutable checklist in GUIDE.md
- chore: genericize `init-firewall.sh` — project-specific domains replaced with placeholders
- chore: `.husky/pre-commit` turbo guard (`[ -f turbo.json ] &&`) — works in both contexts
- chore: sync scripts source from `template/` instead of repo root
- chore: `settings.json` deny rules for `template/**`
- chore: rename `v1-native.md` → `v+-native.md` (aligns with ROADMAP v+ section)
- docs: GUIDE.md, OVERVIEW.md, FAQ.md, CLAUDE.md, README.md, ROADMAP.md updated
- docs: detailed construction notes in `notes/bootstrap/v1.2-reorganization.md`
- docs: pre/post split comparison in `notes/bootstrap/v1.2-comparison-to-before-split.md`

Resolves ROADMAP "Repo layout clarification" item.

## v1.1.2 (2026-04-14)

- chore: workaround claude-code#22583 — inject devshop CLAUDE.md via session hook
- chore: simplify CLAUDE.md — no assembly, auto-loaded via additionalDirectories
- docs: add file lifecycle section, fix symlink/copy inaccuracies
- refactor: consolidate adversarial review into single shared script

## v1.1.1 (2026-04-14)

- docs: extract security model into dedicated reference note
- fix: harden security — symlink hooks, fail-closed reviews, complete lock loop

## v1.1.0 (2026-04-14)

- docs: document settings.json copy model in CLAUDE.md and FAQ.md
- fix: make settings.json and .dcg.toml root-owned copies, fix ak-\* bug
- fix: wrap .hooks/pre-commit call in if/fi
- refactor: extract symlink creation into create-devshop-symlinks.sh
- feat: add hook bypass protection (check-hook-bypass.sh)
- docs: remove stale devshop: commit prefix convention
- refactor: make .devshop/CLAUDE.md the single source of conventions
- fix: harden security for separated devshop infrastructure
- devshop: fix permission prompts for /devshop/ and common Bash commands
- chore: consolidate split audit into devshop-split.md, remove pre-split-comparison
- chore: auto-recreate devshop symlinks in pre-commit if missing
- fix: correct pre-split-snapshot tag location in docs
- chore: add explicit permission patterns for symlink-resolved paths
- chore: broaden docs drift check to review all docs on any devshop change
- fix: widen PostToolUse hook globs to match git -c flag
- chore: add devshop repo layout guidance to CLAUDE.md
- chore: add ak-commit design note and v1 roadmap item
- chore: strengthen check-dirty-after-commit.sh advisory language
- chore: add standalone devcontainer roadmap item + read/edit permissions
- fix: widen hook globs to match cd-prefixed git commands
- chore: add pre-split-snapshot tag and comparison notes
- chore: use sonnet for adversarial doc review
- feat: adversarial review in husky, semantic vs deterministic checks
- feat: three-layer commit guard enforcement
- chore: triage v0-gaps for separation architecture
- chore(security): add per-file rationale to lock list, deduplicate GUIDE
- fix(security): lock init-devshop.sh and settings.local.json
- feat(status): list all specs in ak-status for birds-eye project view
- chore: rename /devshop:_ to /ak-_ in user-facing docs
- chore: BUILD-LOG.md improvements
- chore: restore v0-web.md annotations, fix commit guard, sync message
- chore: restore v0-web.md annotations, sync commit message, BUILD-LOG template
- chore: restore lost skill content from main branch
- chore: restore lost content from main in README, ROADMAP, FAQ, TODOS
- chore: reconcile GUIDE.md with main, fix cross-references
- docs: remove duplicated init-devshop.sh steps from GUIDE.md
- docs: update GUIDE.md for new pre-commit hooks
- feat: add CLAUDE.md freshness check and devshop clean-tree hook
- fix: restore ak- prefix on devshop skill names and update all docs
- fix: strengthen bypass prompts, update GUIDE for husky guards
- fix: move commit guards to husky via .hooks/pre-commit
- chore: remove memory symlink from postCreateCommand
- fix: add cwd reminder after commits outside /workspace
- chore: move Claude memory to .claude/memory/
- refactor: rename template → devshop across scripts and docs
- fix: make check-clean-tree blocking, add advisory hook TODOs
- chore: add devshop testing section to roadmap
- fix: remove auto-pass from doc consistency check
- fix: remove auto-pass from docs drift check, update GUIDE.md hooks docs
- chore: remove public mirror concept, simplify manifest
- chore: add .gitattributes and .prettierignore templates
- chore: add .gitignore and track pnpm-lock.yaml
- chore: run pnpm install in devshop on container start
- refactor: move commit guard to Claude hook, add cross-repo awareness
- devshop: fix audit findings — skill names, cross-refs, FAQ layers
- devshop: remove stray INITEOF from init-devshop.sh
- devshop: harden docs for session continuity

## v1.0.0 (2026-04-12) — Devshop Separation

**Breaking change**: The devshop and project repos are now fully separate.

Previously, all devshop files (`.devshop/`, `.claude/skills/`, `settings.json`, `CLAUDE.md`, `BUILD-LOG.md`) were tracked in the project repo. Now they live in abra-kadabra and get injected into the workspace at container start via `init-devshop.sh` symlinks.

What changed:

- `init-devshop.sh`: new injection script symlinks devshop files into `/workspace/`
- Project repos have a thin forwarder at `.devcontainer/init-devshop.sh`
- `devcontainer.json` mounts abra-kadabra at `/devshop` (was `/template-repo`)
- `CLAUDE.md` is generated from `abra-kadabra/CLAUDE.md` + `CLAUDE.project.md`
- `.claude/settings.json` is symlinked (all injected files are symlinks)
- All injected files are gitignored in the project repo
- `devshop-commit-guard.sh` updated: project infra (`.devcontainer/`, `.husky/`, etc.) is now project-layer
- Sync scripts use `/devshop` mount path (`$DEVSHOP_DIR` env var)
- `/ak-init` updated for separation model (steps 19, 22, 25)
- Full documentation: `GUIDE.md` § Devshop Separation Architecture
- Template root configs added: `.editorconfig`, `.prettierrc`, `.npmrc`, `.nvmrc`, `package.json`
- `manifest.txt` rewritten: injected vs template distinction

Project repos need: `CLAUDE.project.md` (tracked), `.claude-memory/` (tracked), `.gitignore` entries for `.devshop .claude .dcg.toml CLAUDE.md BUILD-LOG.md`

## v0.2.0 (2026-04-09)

- Added `.devshop/templates/` folder with `.md.tmpl` convention (README, PRODUCT-ROADMAP, BUILD-LOG)
- Split build logs: devshop CHANGELOG (this file) vs project BUILD-LOG (root)
- Added changelog auto-append on version bumps (`changelog-entry.sh`)
- Added manifest exclude patterns (`!` prefix) for `.devcontainer/.env`
- Replaced broad `.devshop/` manifest entry with explicit file paths

## v0.1.0 (2026-04-09)

- Initial devshop construction (see Phase 0a appendix below)

---

## Appendix: Phase 0a Construction History

> Historical record of the initial devshop build. File paths referenced may use
> names from the time of writing — some have since been renamed/moved.

### Plan Deviations

Agreed-upon changes from the master plan (`kit/notes/bootstrap/v0-web.md`):

1. **Public mirror (Step 11)** deferred to ROADMAP v1
2. **EAS CLI removed** from Dockerfile — native/mobile deferred
3. **Checksum grep fix** — removed `^` anchor from grep/sed patterns
4. **DinD feature** needs `"moby": false` — Debian Trixie removed moby-cli
5. **gh auth setup-git** made conditional in postCreateCommand
6. **Dockerfile restructured** — single USER switch instead of 4
7. **`/build` + `/go-live` orchestrators** added; `/pre-ship` quality-gates-only; `/post-merge` deleted
8. **Vercel repo import** moved from Step 3 to Step 14
9. **Steps 5/6 swapped** — fill credentials first, then add GitHub Secrets
10. **"Create GitHub repo" removed** as init step — now a prerequisite
11. **Rebuild devcontainer step added** (Step 7)
12. **`/office-hours` + `/autoplan` removed from init** — product planning, not infrastructure
13. **Init scaffold boundary clarified** — no feature logic in init

### Phase 0a: Build the Devshop

#### Step 1: Update Dockerfile + devcontainer.json

- **Status**: done
- **What was done**:
  - Added `ghcr.io/devcontainers/features/docker-in-docker:2` feature to `devcontainer.json` — provides isolated Docker daemon for `supabase start` without mounting host Docker socket
  - Audited Dockerfile: all 4 binaries (git-delta, supabase-cli, DCG, gitleaks) already version-pinned via build args + checksum-verified via `checksums.sha256`. No changes needed.
  - Verified `.env` already loaded via `--env-file` in `runArgs` — `VERCEL_TOKEN` and `SUPABASE_ACCESS_TOKEN` will be available once user adds them. No changes needed.
  - Verified pnpm and bun already installed globally. No changes needed.
  - No Docker socket mount added (host Docker stays inaccessible).
- **Concern flagged**: DinD creates its own network bridges (`docker0`). Firewall `iptables` rules may block container-to-container traffic needed by `supabase start`. Must test after rebuild.
- **Rebuild deferred**: Step 2 (firewall) edits the same image — one rebuild covers both.

#### Step 2: Update firewall

- **Status**: done
- **What was done**:
  - Added 6 devshop-level domains to `init-firewall.sh`: `vercel.com`, `api.vercel.com`, `cdn.jsdelivr.net`, `objects.githubusercontent.com`, `fonts.googleapis.com`, `fonts.gstatic.com`
  - Replaced incorrect `fonts.google.com` (website) with the actual CDN domains
  - Added commented project-specific domain section above the for-loop with documentation for each domain and when to add it
- **Note**: After Step 8, `.devcontainer/` files become write-denied to Claude. All firewall edits must happen before then.
- **Rebuild**: Steps 1+2 both require container rebuild. **[HUMAN]** must rebuild before Step 4 (pnpm commands).

#### Step 3: Create .devshop/ portability layer

- **Status**: done
- **What was done**:
  - `.devshop/version` — initial version `0.1.0`
  - `.devshop/template-remote` — blank runtime config (already gitignored)
  - `.devshop/template-remote.example` — placeholder with format
  - `.devshop/manifest.txt` — file list with `[private]` annotations for mirror stripping
  - `.devshop/CLAUDE.md` — full devshop conventions source (context loading, philosophy, non-negotiables, confidence calibration, TODO protocol, naming, commit convention)
  - `.devshop/scripts/sync-to-template.sh` — v0: reads manifest, copies to template clone, auto-bumps version, creates PR via gh. Initial seed pushes directly.
  - `.devshop/scripts/sync-from-template.sh` — v0: copies from template, injects `.devshop/CLAUDE.md` into root CLAUDE.md's `## Devshop Conventions` section (heading-based, shows diff, asks confirmation). Shows full git diff for review.
  - `.devshop/scripts/release.sh` — bump version + tag for direct template repo edits
  - All scripts made executable
  - `.gitignore` already had `.devshop/template-remote` entry — no change needed
- **Note**: Scripts untestable until template repo exists (Phase 0b Step 7)

#### Step 4: Convert to Turborepo monorepo

- **Status**: done
- **What was done**:
  - `pnpm-workspace.yaml` — packages: apps/_, packages/_
  - `turbo.json` — pipeline: lint, typecheck, test:unit, test, build, dev. test tasks have cache:false.
  - `tsconfig.base.json` — shared baseline (strict, bundler moduleResolution, noUncheckedIndexedAccess)
  - Root `package.json` — replaced placeholder with monorepo config (turbo scripts, husky, lint-staged devDeps, lint-staged config). No `"workspaces"` field (pnpm ignores it).
  - ESLint deps (`@eslint/js`, `typescript-eslint`) listed in plan but not in package.json yet — will be added via `pnpm add -D -w` post-rebuild along with other deps.
- **Note**: `pnpm install` deferred to post-rebuild. Config files only.

#### Step 4b: Migrate ESLint to flat config

- **Status**: done
- **What was done**:
  - Deleted `.eslintrc.json` (minimal, no code depended on it)
  - Created `eslint.config.mjs` — flat config with typescript-eslint, no-unused-vars (ignore \_prefix), no-explicit-any warn. Prettier owns formatting.
- **Note**: `@eslint/js` and `typescript-eslint` packages installed post-rebuild.

#### Step 5: Set up pre-commit hooks

- **Status**: done
- **What was done**:
  - `.husky/pre-commit` — lint-staged + gitleaks (2 lines only; check-devshop-docs.sh added later in Phase 0b Step 6)
  - `.gitleaks.toml` — allowlist for Supabase anon key, PostHog public key, Sentry DSN. Prevents false-positive rot.
  - `.devshop/scripts/check-file-headers.sh` — checks staged .ts/.tsx under src/ or app/ for `// What:` header. NOT wired into pre-commit (enforcement by /pre-ship). Created for use by /pre-ship convention check.
  - `.devshop/scripts/check-devshop-docs.sh` — nudge if one devshop reference doc staged without the other. Created but NOT wired into pre-commit yet (Phase 0b Step 6).
  - `"prepare": "husky"` already in package.json from Step 4.
  - All scripts made executable.
- **Note**: `pnpm install` (which triggers husky setup) deferred to post-rebuild.

#### Step 6: Create GitHub Actions

- **Status**: done
- **What was done**:
  - `.github/workflows/ci.yml` — fast job: checkout, pnpm setup, install, gitleaks CLI detect (not the paid Action — free CLI works on private repos), turbo lint+typecheck+test:unit+build. Env vars mapped from secrets.
  - Mirror sync tests line commented out — uncomment after Step 11 (added to DEVSHOP-TODOS.md).
  - Slow job commented out as placeholder — Phase 1c adds Supabase integration, Phase 1g adds Playwright E2E.
  - Used gitleaks CLI (`detect`) instead of `gitleaks/gitleaks-action@v2` because the Action requires a paid license for private repos.
  - gitleaks version extracted from devcontainer.json build args for consistency.

#### Step 7: Write devshop documentation hierarchy

- **Status**: done
- **What was done**:
  - Verified DEVSHOP-OVERVIEW.md matches plan spec (~66 lines, all sections present)
  - Verified DEVSHOP.md matches plan spec (all sections present)
  - Added 3 missing sections to DEVSHOP.md per plan: "Local Development" (with/without DinD workflows), "Service Quotas" (table with free tier limits + dashboard placeholders), "Expected CI Minutes" (~260 min/month estimate)
  - DEVSHOP-OVERVIEW.md unchanged — new sections are operational detail, not bird's eye
  - Verified DEVSHOP-ROADMAP.md exists with correct structure (v1 + v+ items)
  - Verified DEVSHOP-TODOS.md exists with correct structure
  - Verified PRODUCT-ROADMAP.md exists with standard deferred items (PWA, visual regression, perf baselines, changesets, dependabot, offline)

#### Step 7b: Configure DCG

- **Status**: done
- **What was done**:
  - Created `.dcg.toml` at repo root — DCG project-level config
  - Enabled packs: core.git, core.filesystem, database.postgresql
  - Trust level: high for claude-code agent
  - Allowlisted: pnpm, turbo, supabase gen types (safe commands blocked by default patterns)

#### Step 8: Update .claude/settings.json

- **Status**: done
- **What was done**:
  - Preserved existing `defaultMode: "acceptEdits"` and core bash allowlist
  - Added to allowlist: `git branch*`, `git rm *`, `ls`, `ls *`, `docker ps*`, `docker images*` (DinD verification)
  - Removed EAS CLI entries (native/mobile — not in scope for web devshop)
  - No `rm` in allowlist — Claude asks user before any delete. DCG is the backup layer. Can tweak later if friction is too high.
  - Added write-deny for devcontainer files: `Edit/**/.devcontainer/*`, `Write/**/.devcontainer/*`, `Edit/**/init-firewall.sh`, `Write/**/init-firewall.sh`
  - Added `hooks.PreToolUse` with DCG hook on all Bash commands
- **Concern**: After this commit, Claude cannot edit devcontainer/firewall files. All such edits must be done before this point (Steps 1+2 are already committed).

#### Step 9: Update root CLAUDE.md

- **Status**: done
- **What was done**:
  - Restructured into two sections: `## Devshop Conventions` (from .devshop/CLAUDE.md) + `## Project: lalista`
  - Devshop section: full content from .devshop/CLAUDE.md (context loading, philosophy, non-negotiables, confidence calibration, TODO protocol, naming, commit convention)
  - Project section: preserved existing content (dev container, persistent storage, gstack, design system, code style) under project heading
  - Removed duplicate content now covered by devshop conventions

#### Step 10: Create devshop skill files

- **Status**: done
- **What was done**:
  - `spec/SKILL.md` — updated v1→v2: added METRICS.md check (first feature vs existing), offline behavior requirement, metrics section, quality checklist reference
  - `implement/SKILL.md` — updated v1→v2: added hats (FE/BE/PM), metrics instrumentation, test:unit as per-task command, noUncheckedIndexedAccess note, clarification escalation format, references to DEVSHOP.md shared conventions
  - `test-review/SKILL.md` — new: fresh-eyes test quality review, flags weak assertions/missing error paths/untested RLS/implementation detail tests, report-only (no auto-fix)
  - `pre-ship/SKILL.md` — new: 11-gate chain (docs→metrics→responsive+theme→simplify→test-review→review→cso→qa→design-review→benchmark→ship), convention check, pause on findings / auto-advance on clean
  - `post-merge/SKILL.md` — new: land-and-deploy→canary→rollback checkpoint→structured reflection routing learnings to committed files
  - `status/SKILL.md` — new: session orientation briefing, reads TASKS.md/SPEC.md/git state, one-paragraph output, read-only
  - `init/SKILL.md` — new: guided new-project walkthrough, version freshness check, walks checklist from DEVSHOP.md, handles [HUMAN] vs automated items, resumable via checkboxes

#### Step 11: Public mirror infrastructure

- **Status**: deferred to DEVSHOP-ROADMAP v1

#### Post-review fixes (applied after Phase 0a completion)

Added Shared Conventions nesting, removed stale mirror convention, added PR audit trail to /pre-ship, added decisions log to /implement, added GITHUB_TOKEN to new-project checklist, added /build + /go-live orchestrator skills, restructured /pre-ship as quality-gates-only, deprecated /post-merge.

---

### Devshop improvements during Phase 0b

#### Restructuring: v0-web / init relationship (2026-04-07)

- Expanded `init/SKILL.md` from 91 to 516 lines — embedded genericized Phase 0b step detail
- Restructured GUIDE.md checklist: added prerequisites, fixed sequencing
- Added auth middleware non-negotiable to `.devshop/CLAUDE.md`
- Moved Phase 2 items from v0-web to `.devshop/ROADMAP.md`

#### Pre-init improvements (2026-04-08)

- Numbered all 29 steps in GUIDE.md + SKILL.md for 1:1 mapping
- Added missing Step 4 (Create GitHub repo)
- Commits: `fa9cfda`, `16e0ac7`

#### Commit template-remote, remove from .gitignore

- Removed `.devshop/template-remote` from `.gitignore`
- Removed "fill template-remote" step from init
- Renumbered steps 25-28 → 25-27

#### Redesign template sync for bind-mounted repo

- Rewrote `sync-to-template.sh` and `sync-from-template.sh` for `/template-repo` bind mount
- Template repo lives on host, bind-mounted into devcontainer
- Human pushes from host (no credential scope creep)

> Phase 0b (lalista project init): see root `BUILD-LOG.md`
