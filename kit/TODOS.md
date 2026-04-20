# Devshop TODOs

Devshop friction, bugs, and small fixes — things to do soon.
Strategic capabilities go in `ROADMAP.md`. Project issues go in root `TODOS.md`.

---

<!-- Items discovered during use. Tag with [v0.2], [v1] etc. to schedule into ROADMAP versions. -->

- [ ] **When GitHub re-enables Checks permission on fine-grained PATs, revert `/ak-build` Phase 5 to `gh pr checks`.** The Check Runs API isn't accessible to fine-grained PATs — GitHub removed the Checks permission after initial release (see https://github.com/orgs/community/discussions/129512). Phase 5 currently uses `gh run list` + `gh run watch` which goes through the Actions API and works with `Actions: Read`. When the Checks permission returns:
  - Swap `gh run list --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId' | xargs gh run watch --exit-status` back to `gh pr checks "$PR" --watch --fail-fast` in `.claude/skills/devshop/build/SKILL.md § Phase 5.2`.
  - Update `.claude/skills/devshop/new-project/SKILL.md § Step 4` to add `Checks: Read` to the required PAT permissions.
  - Remove the link-to-discussion rationale from both files.

- [ ] **Pin template base image by digest.** `template/.devcontainer/Dockerfile` currently uses `FROM mcr.microsoft.com/devcontainers/javascript-node:20` — an unpinned tag. Every rebuild could theoretically pick up a different upstream base (security patches, package-universe drift). Every apt + binary install below inherits the drift. Tags are mutable; digests are not.

  **Fix**: resolve the current digest (`docker buildx imagetools inspect mcr.microsoft.com/devcontainers/javascript-node:20 | grep -m1 Digest`) and pin it:

  ```dockerfile
  FROM mcr.microsoft.com/devcontainers/javascript-node:20@sha256:<digest>
  ```

  Apply to:
  - `template/.devcontainer/Dockerfile`
  - Document a refresh cadence (when to re-resolve the digest — e.g. when Microsoft ships a base-image security advisory, or every N months).

  Surfaced during lalista PR 2 hardening discussion — deferred because we didn't have registry access from the sandbox to resolve the digest. User should run the resolve command from their host.

- [ ] **Upstream fix: gstack `browse` daemon Chromium version autodetection.** The compiled daemon is pinned to `chromium-1208` path; Playwright may install newer versions (1217 observed). `/ak-pre-ship` Phase 0 now creates a symlink as a workaround, but the daemon should discover the highest-version dir under `~/.cache/ms-playwright/` on its own. File upstream in gstack, remove the symlink workaround when the fix ships.

- [ ] **Route init tracking out of project BUILD-LOG.** Currently `ak-new-project` logs all 25 init steps into the project's `BUILD-LOG.md`, mixing devshop infrastructure with project setup. BUILD-LOG should only contain entries from `/ak-build` (feature ships).

  **Changes needed:**
  1. `ak-new-project/SKILL.md`: write INIT-TRACKER to `/devshop/kit/notes/projects/<name>.md` instead of project root
  2. `session-start.sh`: read init progress from devshop notes file (not BUILD-LOG Status section); surface both project build status and init progress
  3. `init-devshop.sh`: remove BUILD-LOG.md creation (lines 77-81) — `ak-new-project` copies it from template during Phase A
  4. `template/BUILD-LOG.md`: remove init-tracking Status fields (`Current phase`, `Current step`, `Remaining`); keep only `Last build`
  5. Separate ak-new-project steps into devshop-infra vs project-setup so only project steps appear in project-facing records

  **Devshop infrastructure steps** (go to `/devshop/kit/notes/projects/<name>.md`):

  | Step                                     | Why devshop-specific                     |
  | ---------------------------------------- | ---------------------------------------- |
  | 1. Check binary versions                 | Devshop-managed binaries in devcontainer |
  | 4. [HUMAN] Fill credentials              | Devshop `.devcontainer/.env` pattern     |
  | 6. [HUMAN] Add firewall domains          | Devshop firewall infrastructure          |
  | 7. [HUMAN] Rebuild devcontainer          | Devshop container lifecycle              |
  | 8. Disable turbo telemetry               | Container env config                     |
  | 9. Install gstack                        | Devshop tooling dependency               |
  | 19. Enable doc enforcement hooks         | Devshop convention enforcement           |
  | 21. [HUMAN] Lock security-critical files | Devshop security model                   |
  | 25. Run /cso baseline audit              | Devshop quality gate                     |

  **Project setup steps** (could appear in project-facing records):

  | Step                                      | What it does                      |
  | ----------------------------------------- | --------------------------------- |
  | 2. Customize project docs                 | README, PRODUCT-ROADMAP           |
  | 3. [HUMAN] Create accounts                | Vercel, Sentry, PostHog, Supabase |
  | 5. [HUMAN] Add GitHub Secrets + Variables | Repo configuration                |
  | 10-16. Scaffold packages + apps           | Core project code                 |
  | 17. Run /setup-deploy                     | Deploy configuration              |
  | 18. Create project CLAUDE.md              | Project docs                      |
  | 20. Update .gitleaks.toml                 | Project-specific secret patterns  |
  | 22. Create keepalive.yml                  | Project CI                        |
  | 23. [HUMAN] Service quota alerts          | Project ops                       |
  | 24. [HUMAN] Branch protection             | Repo configuration                |

  [post-separation, documented 2026-04-16]

- [x] Review plan gaps after Phase 1: `notes/bootstrap/v0-gaps.md` — reviewed 2026-04-13 after devshop separation. 3 resolved by separation (#8 local dev docs, #9 mirror, minor gaps), 2 fixed (#1 dependabot, minor check-file-headers), 3 project decisions routed (#3 Zod, #4 state mgmt, #5 i18n), 3 added to ROADMAP (#2 staging v1, #10 axe-core v1, #11 logging v+), 2 already in ROADMAP (#6 tiered pre-ship, #7 subagent).
- [ ] Investigate scoping node user's sudo access — base image gives full passwordless sudo, which means Claude could bypass root-owned file protections via `sudo chown`. See `kit/notes/sudo-hardening.md` for analysis and approach. [post-Phase-1]
- [ ] **Investigate merging `docs-drift` and `doc-consistency` checks.** Currently separate checks in `devshop-commit-guard.sh`, each with its own bypass flag (`docsVerified` / `docSyncReason`). They ask related-but-different questions: `docs-drift` fires when tooling changes (code → do docs need updating?), `doc-consistency` fires when a ref doc changes (doc → are cross-referenced docs still consistent?). In practice most devshop commits stage both code AND doc updates, so both checks fire and the committer must write two justifications for what feels like one logical review. Investigate whether a single merged check (`docs-review`?) with one bypass flag could cover both concerns without losing signal. Main risk: the adversarial reviewer may do a weaker job if both concerns are merged into one prompt — currently it can focus narrowly on each. Mitigation: give the reviewer explicit context about which trigger fired (code changed / doc changed / both) and tailored criteria per case. Decision criteria: does the merged reviewer catch all cases the split reviewers caught in recent commits (survey this session's commits + previous few releases). If yes → merge. If no → keep separate and document the rationale in `kit/docs/guide/hooks.md` so the two-flag friction is a known intentional cost. [ergonomics, documented 2026-04-16]

- [x] **RESOLVED 2026-04-19: Re-run Smoke 1 (subagent-noise elimination) before `/ak-build` PR 3.** Re-ran in this same session (container post-rebuild, fresh settings). Spawned `general-purpose` subagent against a dirty /workspace tree with a narrow `git commit` prompt. Subagent output contained ZERO banned strings (no BLOCKING/MANDATORY/⚠️/You-MUST/Working-tree-dirty/release-reminder/PR-desc nudge). Pre-commit husky gates fired as expected (agent-agnostic invariants). Migration's primary payoff confirmed. See `kit/notes/roadmap/hook-migration-test.md` Rollup row updated ⧗ → ✅. Unblocks PR 3.

- [ ] **Instrument subagent drift rate, then decide whether to codify a cleanup pattern.** Phased plan in [`kit/notes/roadmap/subagent-cleanup-pattern.md`](notes/roadmap/subagent-cleanup-pattern.md). Phase 1 adds a deterministic bash logger (`subagent-drift-log.sh`) to `/ak-build` and `/ak-implement` `Agent()` call-sites that snapshots repo state before + after each subagent spawn and writes deltas to a gitignored log. Phase 2 (contingent on Phase 1 data) codifies a clean-state prompt block in `kit/docs/guide/agents.md` + optional helper script `check-subagent-cleanup.sh` — parent verifies subagent-left state against baseline and negotiates via `SendMessage` if drift lacks a structural reason. **Decision gate after ~30 spawns**: <5% drift → skip Phase 2; 5–15% → prompt block only; >15% or multi-session accumulation → full helper + bats tests. **Hard guardrail**: pattern MUST stay at prompt/agent-to-agent layer — a `SubagentStop` hook would recreate the hook-injection bug the 2026-04-19 hook migration killed. [ergonomics, measured-before-built, documented 2026-04-19]

- [ ] **`prDescStaleReason` reviewer auto-rejects even when PR description matches commits.** `.husky/pre-push` Check 1 always invokes `adversarial-review.sh prDescStaleReason` on non-trivial commits + open PR; when no bypass reason is set the reviewer short-circuits to FAIL even when the PR description genuinely matches the commits (adversarial prompt item 8(a): _"PR description genuinely matches the commits — the reviewer is wrong"_). Surfaced during hook-migration verification — pushed an aligned-description PR update and still got blocked with `"No reason given — automatic rejection."`

  **Full analysis** (alternatives A–E, current lean B + E, decision trigger): see [`kit/ROADMAP.md` § "PR-description staleness check — layer + approach decision"](ROADMAP.md#pr-description-staleness-check--layer--approach-decision). Trigger to act: post-PR-3 (`/ak-build core-flows`) data on the false-positive rate of the current always-fires implementation. [ergonomics, 2026-04-19]

- [x] **RESOLVED: settings.json symlink fragility.** Fixed: settings.json and .dcg.toml are now root-owned copies (not symlinks). Sticky bit on `.claude/` prevents deletion. Freshness check (`check-security-files-freshness.sh`) runs at session start and pre-commit to detect staleness. [critical, 2026-04-14]
- [x] **RESOLVED: CLAUDE.md simplification.** Eliminated `CLAUDE.project.md` — project repo now has `CLAUDE.md` (tracked, project-only). Devshop conventions live in devshop repo root `CLAUDE.md`, auto-loaded via `additionalDirectories`. No assembly, no freshness checks. Public clones just work. [post-separation, 2026-04-14]
- [x] **RESOLVED 2026-04-19: Session-start uncommitted changes check.** `session-start.sh` now includes a cross-repo "WIP heads-up" section that warns (non-blocking) on uncommitted or stashed state in either `/workspace` or `/devshop` at session boundaries. Part of the hook architecture migration — see `kit/notes/roadmap/hook-migration-plan.md`.
- [x] **RESOLVED 2026-04-19: Make `check-pr-description.sh` blocking.** Replaced by `.husky/pre-push` "PR description" check — now blocking (was PostToolUse advisory), fires at git layer (agent-agnostic), adversarially reviewed via `devshop.prDescStaleReason` bypass flag, with conventional-commit short-circuit (`chore:`/`docs:`/`style:`/`test:`/`ci:`/`build:`/`perf:`-only pushes skip the LLM review). Part of the hook architecture migration — see `kit/notes/roadmap/hook-migration-plan.md`.
- [x] **RESOLVED 2026-04-19: Make `check-dirty-after-commit.sh` blocking.** Deleted as redundant with existing husky pre-commit guards (`check-clean-tree.sh` in `devshop-commit-guard.sh` — same dirty-tree concern, commit-time, blocking). Additional push-time dirty/stash check added via `.husky/pre-push` with `devshop.dirtyPushReason` bypass. Part of the hook architecture migration — see `kit/notes/roadmap/hook-migration-plan.md`.
- [x] Rename `/devshop:*` to `/ak-*` in user-facing docs — CLAUDE.md glossary, README.md glossary, GUIDE.md init heading, templates/README.md.tmpl. Skill-to-skill invocations left as `/devshop:*` (fully qualified name) — both forms work at runtime. [minor]
- [ ] Upgrade root ESLint from v9 to v10 — blocked by `eslint-config-next` which depends on `eslint-plugin-react@7.x` (uses `getFilename()` API removed in ESLint 10). **Trigger**: when Next.js ships an `eslint-config-next` version that supports ESLint 10, bump root `eslint` + `@eslint/js` to `^10` across all projects. Check: `npm info eslint-config-next peerDependencies` for eslint range. [blocked-upstream]
- [ ] Check if `anthropics/claude-code#22583` is resolved — CLAUDE.md from `additionalDirectories` not loaded despite `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1`. Workaround in `session-start.sh` injects `/devshop/CLAUDE.md` via hook context. Remove workaround when fixed. [blocked-upstream]
- [ ] **Deny rules with absolute paths don't fire for paths outside cwd.** Confirmed empirically 2026-04-16 during a security audit session. From cwd=`/workspace`: `Edit(/workspace/.devcontainer/devcontainer.json)` was DENIED (matched by the relative `**/.devcontainer/*` glob, normalized against cwd), but parallel `Edit(/devshop/.devcontainer/devcontainer.json)` and `Edit(/devshop/template/.devcontainer/devcontainer.json)` calls **succeeded** — neither the relative `**/.devcontainer/*` rule nor the explicit absolute `Edit(/devshop/.devcontainer/*)` and `Edit(/devshop/template/**)` rules fired. Claude Code's permission matcher appears to be cwd-anchored: relative globs only match paths under the current workspace root, and absolute-path deny patterns for other `additionalDirectories` targets aren't enforced.

  **Scope of affected deny rules** (in `/devshop/.claude/settings.json`) — all of these look enforced but don't fire from the "wrong" cwd:
  - `Edit(/devshop/.devcontainer/*)` + `Write(/devshop/.devcontainer/*)`
  - `Edit(/devshop/.claude/settings.json)` + `Write(/devshop/.claude/settings.json)`
  - `Edit(/devshop/.dcg.toml)` + `Write(/devshop/.dcg.toml)`
  - `Edit(/devshop/kit/scripts/*)` + `Write(/devshop/kit/scripts/*)`
  - `Edit(/devshop/template/**)` + `Write(/devshop/template/**)`
  - `Read(/devshop/.devcontainer/.env)` + `Read(/workspace/.devcontainer/.env)`

  (Symmetric assumption: when cwd=`/devshop`, the `/workspace/...` absolute denies likewise don't fire. Not directly verified but same matcher logic.)

  **Now mitigated at the filesystem layer (as of v1.5.5, 2026-04-16):** critical files are `root:root 644` and parent dirs have the sticky bit (`chmod 1755`) on both repos' `.claude/` and `.devcontainer/` plus `template/.devcontainer/`. So `settings.json`, `.dcg.toml`, `devcontainer.json`, `Dockerfile`, `init-*.sh`, `.env`, and all `kit/scripts/*.sh` are kernel-protected against node regardless of which cwd Claude is working from. The deny rules become belt-and-suspenders with a known cwd-asymmetric limitation.

  **What remains vulnerable** — non-critical cross-repo files still editable from any cwd: `/devshop/kit/notes/*.md`, `/devshop/CLAUDE.md`, `/devshop/kit/docs/*.md`, `/devshop/README.md`. These aren't filesystem-locked. Commit guards catch changes before they reach remote, but in-session edits happen freely. This is acceptable for the doc/notes files but means the absolute-path deny rules in `settings.json` read more protectively than they actually behave.

  **Resolution options** (pick when triggered):
  - **A. Document the limitation in-place**: add a comment block above the absolute-path deny rules in `settings.json` noting they only enforce when cwd matches. Also update `guide/security.md` §"Layer 3" to spell out the cwd-relativity. Low effort, calibrates reader expectations.
  - **B. File upstream issue**: report to `anthropics/claude-code` — "absolute-path Edit/Write deny rules don't enforce when target is outside the primary working directory, even when the target is in `additionalDirectories`." Include the minimal repro from this session.
  - **C. Custom PreToolUse hook**: a bash script that parses Edit/Write tool calls and rejects based on a path-matcher that handles absolute paths correctly. Bypasses Claude Code's matcher entirely for the paths we care about. More robust but more moving parts.
  - **D. Rely on filesystem + drop absolute denies**: since Layer 2 (root ownership + sticky bit) is the real defense after v1.5.5, remove the `Edit(/devshop/...)` rules from `settings.json` to stop giving false confidence. Keep relative forms as advisory. Accepts that non-critical files are editable cross-cwd.

  **Trigger**: when someone files upstream and it's fixed (resolves automatically), OR when a real attack/mistake exploits the gap (bump priority), OR when a second audit surfaces the false-confidence cost. Until then, filesystem locks carry the load.

  [blocked-upstream, security-hygiene, documented 2026-04-16]
