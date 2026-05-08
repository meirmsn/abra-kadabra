# Devshop TODOs

Devshop friction, bugs, and small fixes — things to do soon.
Strategic capabilities go in `ROADMAP.md`. Project issues go in root `TODOS.md`.

---

<!-- Items discovered during use. Tag with [v0.2], [v1] etc. to schedule into ROADMAP versions. -->

- [x] **lalista-option3-template-variant: convert lalista's compose-isolation setup into the `/devshop/template/.devcontainer/` shape (and an `/ak-new-project` choice for it).** ✅ **shipped 2026-04-28** (devshop `feat/template-option3` branch, v1.23.0; semantic-name cleanup `fix/option-labels-to-semantic-names` v1.23.1). Five new template files (`compose.yml`, `init-host-env.sh`, `supabase-runner/{Dockerfile,cmd-relay.mjs}`); modifications to `devcontainer.json` (dockerComposeFile + initializeCommand), `Dockerfile` (drop docker-ce-cli + init-docker-socket), `init-firewall.sh` (host.docker.internal allow rule + drop docker hub allowlist), `README.md` (full sync from lalista 97eec6b), `package.json` (db:\* scripts), `.github/workflows/ci.yml` (gitleaks grep flips to compose.yml); deletion of `init-docker-socket.sh`. `/ak-new-project` SKILL.md gains Step 2b "Local supabase reachability" 3-choice prompt (host-supabase / compose-isolation / skip; default = compose-isolation) + per-choice file strips. Migration recipe for stranded host-docker-socket-bind-mount projects deliberately NOT shipped — no project needs it (lalista migrated directly via PR 34 the same day; no other host-docker-socket-bind-mount project exists). Doc updates: `kit/docs/guide/ops.md` "Local Development" + "Compose isolation" sections; `kit/docs/guide/security.md` "Local Supabase Isolation" section; `kit/notes/roadmap/lalista-launch.md` operator-pain section marks devcontainer migration recipe + bats coverage as ✅ shipped. New BATS file `kit/tests/template-compose-isolation.bats` covers structural assertions. Original entry preserved below for context.

  Original entry (was the working spec for the port): lalista PR 34 (`devcontainer-compose-isolated`, 2026-04-28) shipped Option 3: two-container compose (workspace + supabase-runner sibling), workspace has NO docker socket, narrow `<host>/supabase` bind on the runner, RPC relay on :9000 for orchestration commands, socat tunnels in the runner for supabase CLI's hardcoded-localhost healthchecks, host.docker.internal-routed data plane. Architecture doc at `kit/docs/guide/local-supabase-compose-isolation.md`. After-the-fact recipe based on the real diff (NOT aspirational): copy `<lalista>/.devcontainer/{compose.yml,init-host-env.sh,supabase-runner/}` (5 new files) + the modified versions of `{devcontainer.json,init-firewall.sh}` (2 modified) + the `db:*` scripts in `package.json` to `template/.devcontainer/` (they're project-name-agnostic; only `LOCAL_WORKSPACE_FOLDER` is operator-host-derived, auto-resolved by `initializeCommand` → `init-host-env.sh`). Add a `/ak-new-project` interactive choice early in Phase B: "Local supabase reachability: (a) Option 1 — supabase CLI on macOS host (`brew install`); (b) Option 3 — compose isolation [recommended]; (c) skip — CI-only integration tests." Picks which template variant gets installed. Default = Option 3 since most operators have other code under `~/dev/` whose contents shouldn't be readable by a compromised npm dep. Pattern reference: lalista PR 34 (commits `75a02f6` → `7231cb9` → `3d4ef2d` → `cf71aad` → `a76b5f8` — keep the diagnostic arc visible so future operators recognize the failure modes documented in those commit messages). Threat model + decision matrix: `kit/notes/security/local-supabase-isolation-options.md`. Once template lands, add a peer section to `/ak-new-project § Migration: existing project to current credential layout` (SKILL.md ~lines 1033-1148): `§ Migration: existing project to Option 3 compose isolation` covering the same 5-files-new + 2-files-modified migration on stranded projects (replaces the older "host docker socket bind-mount" framing — that path was a fallback branch only and never merged anywhere). [v0+, surfaced-by lalista-PR-34, 2026-04-28]

- [x] **Bun test for `gstack/browse/src/cli.ts`'s server-resolution path.** Cluster 1 (shipped 2026-04-27) added structural fallback in `cli.ts`: `resolveServerScript` returns `null` instead of throwing when src isn't shipped, plus a `USE_NODE_SERVER` env-var fallback for Linux/macOS that switches the launch path from Bun-compiled binary to bundled `server-node.mjs` (Node). Surfaced 2026-04-27 by `release-coverage` adversarial review of v1.22.0 — no `test/cli.test.ts` exists despite the substantive behavioral change. **Closed 2026-04-27**: shipped at `.claude/skills/gstack/browse/test/cli.test.ts` (11 tests covering all three required cases: `resolveServerScript` null-when-absent + path-when-present, `resolveNodeServerScript` bundled-mjs lookup, and `USE_NODE_SERVER` launch-path flip contract). [v0, surfaced-by v1.22.0-release-coverage-review, 2026-04-27, closed 2026-04-27]

- [x] **Pre-ship gate: RLS coverage check.** ✅ **shipped 2026-04-27** as `kit/scripts/preship/rls-coverage-check.sh` + new `rls-coverage` gate in `/ak-pre-ship` SKILL.md (verified caught the simulated PR 5 Bug #1 gap). Original entry preserved below.

  Original entry: When the diff adds a new `.from('<table>').insert(...)` / `.update(...)` / `.delete(...)` call in `supabase/functions/**` or `packages/core/src/api/**`, fail the gate unless `supabase/migrations/*.sql` contains a corresponding `policy "..." on <table> for insert|update|delete to <role>` for the role that will execute the call. Deterministic check, no AI needed.

  **Context**: lalista PR 5 (disambig-add-new) shipped a force-create branch that called `supabase.from('items').insert(...)`. The `items` table only had an `items_select` RLS policy — no INSERT — so PostgREST returned 42501 and the function returned a generic 500. The front-end's catch-all hid the root cause as "Couldn't save your pick" until dogfooding caught it. A simple grep-the-diff-vs-grep-the-migrations check would have failed the gate at /ak-pre-ship time and surfaced the missing policy before the function deployed.

  **Implementation**: bash script in `kit/scripts/preship/rls-coverage.sh`, invoked from /ak-pre-ship Gate 7 (/cso) or as a standalone Gate 12. Parse new write call sites with `git diff main...HEAD --name-only -- 'supabase/functions/**' 'packages/core/src/api/**' | xargs grep -nE "\.from\([\"'][^\"']+[\"']\)\.(insert|update|delete)\("` then check each table+verb against the migrations corpus.

  **Edit targets**: `kit/scripts/preship/rls-coverage.sh` (new), `.claude/skills/devshop/pre-ship/SKILL.md` (add gate invocation).

  [pre-ship-gate, surfaced-by lalista-PR5-bug-1, 2026-04-23, closed 2026-04-27]

- [x] **`/ak-spec` requires a render-condition matrix for new UI elements.** ✅ **shipped 2026-04-27** as a `## Render conditions` matrix requirement in `/ak-spec` SKILL.md + paired quality-checklist row. Original entry preserved below.

  Original entry: When a spec adds a new UI element (button, row, banner, etc.), require a "Render Conditions" matrix: rows = element render conditions, columns = parent states (e.g. `followup_type` × `already_on_list` × exact-match-against-input). Forces the spec author to enumerate WHEN the element renders across the state lattice instead of relying on implicit "always" or "happy-path only" intent.

  **Context**: lalista PR 5's D1 said "always shown" for the add-new row. The implementation took it literally. The row then showed up in cascading store/brand follow-ups (where it's nonsensical — you can't "add as new" a store) AND when the user's utterance matched a candidate exactly (where it's misleading — picking add-new force-creates an item that already exists, hits the unique constraint, falls through to the same candidate). A render-condition matrix would have read: "show when followup_type === 'item' AND no exact-match candidate" — surfacing both gaps at spec time, before code.

  **Implementation**: extend the `/ak-spec` skill prompt template with a "Render Conditions" requirement for new UI elements. Sample matrix in `kit/docs/guide/conventions.md` for reference. The /ak-spec subagent fails the spec if any new UI element in the diff is missing its matrix.

  **Edit targets**: `.claude/skills/devshop/spec/SKILL.md` (prompt template extension), maybe a worked example in `kit/docs/guide/conventions.md`.

  [spec-template, surfaced-by lalista-PR5-bug-2-and-3, 2026-04-23, closed 2026-04-27]

- [x] **`/plan-design-review` checklist gains "input duplicates existing data" prompt.** ✅ **shipped 2026-04-27** as a standing prompt in `/plan-design-review` Pass 1 (SKILL.md + .tmpl). Original entry preserved below.

  Original entry: Standing checklist item: "For each new UI element that takes user input, what happens when the input duplicates existing data already visible in the same view?" Catches the "autocomplete shows my-typed-value AND lets me click 'add new my-typed-value'" anti-pattern (and similar duplication-confusion design pitfalls).

  **Context**: lalista PR 5's add-new row showed even when the user's utterance exactly matched a candidate row visible in the same disambig sheet. Confusing — picking the candidate vs. picking add-new lead to the same row in the items table (force-create hits the unique constraint, falls through). A standing checklist item in design-review would have surfaced this design pitfall before implementation.

  **Implementation**: add the prompt to the gstack `plan-design-review` skill (lives in `~/.claude/skills/gstack/plan-design-review/`, separate from the devshop kit) under a "Standing checks" / "Common pitfalls" section. One sentence + a brief example.

  **Edit targets**: gstack skill file for plan-design-review (upstream PR to gstack — not a devshop-side change).

  [plan-design-review, surfaced-by lalista-PR5-bug-3, 2026-04-23, closed 2026-04-27]

- [ ] **`sudo /usr/local/bin/init-firewall.sh` hangs the Claude Code session when re-run mid-session.** Observed twice during lalista PR 2 close-out (2026-04-20). Container rebuild is the only known recovery. Root-cause hypothesis (unconfirmed): iptables/ipset rebuild drops the session's own established API connection; when Claude Code reconnects against the new network state, commands stall indefinitely.

  **Workaround**: never re-init the firewall during a session. If outbound HTTPS to a new domain fails mid-session (CDN IPs rotate), treat it as an infrastructure TODO — don't hot-patch.

  **Proper fix**: investigate whether `init-firewall.sh` can be made connection-preserving (atomic ipset swap instead of destroy-and-recreate), or run in a separate network namespace so the current session's TCP state isn't affected. Target file is the one shipped in the devcontainer image at `/usr/local/bin/init-firewall.sh` — locate the source in `template/.devcontainer/` (Dockerfile COPY target) and fix there.

  **Related: bootstrap chicken-and-egg in the [locked] file refresh model.** Surfaced 2026-05-02 (lalista rebuild failed when `statsig.anthropic.com` NXDOMAIN'd — Anthropic appears to have retired that subdomain). `init-devshop.sh:115` refreshes `<workspace>/.devcontainer/init-firewall.sh` from `/devshop/template/.devcontainer/init-firewall.sh` on every container start, but it runs _after_ `init-firewall.sh` in `postStartCommand` (gated by `&&`). When init-firewall itself is broken, init-devshop never runs, the workspace copy stays stale, and the next rebuild bakes the old broken version into `/usr/local/bin/` again — because the Dockerfile's `COPY init-firewall.sh /usr/local/bin/` reads from the workspace's local copy (Docker build context can't reach outside the workspace, so `/devshop/template/` is invisible at build time). The `[locked]` model assumes init-firewall succeeded at least once on a previous start; there's no out-of-band bootstrap path when the locked file itself is what's broken.

  **Practical mitigation shipped 2026-05-02**: made `init-firewall.sh`'s domain loop tolerant of single-domain DNS misses — warn-and-continue instead of `exit 1`, with a loud yellow inline banner + an end-of-run summary banner listing all skipped domains. Same warn-pattern the GitHub Actions blob-shards loop already used in the template variant. Applied to both `template/.devcontainer/init-firewall.sh` (every Option-3 project) and `.devcontainer/init-firewall.sh` (devshop's own container); also dropped the now-NXDOMAIN'd `statsig.anthropic.com` from the allowlist. This collapses bootstrap-breaking failure modes into a much narrower set (e.g. github.com unreachable, which would brick a lot more than this one script). Operator workaround when the bootstrap _does_ break: `sudo /usr/local/bin/init-devshop.sh` from inside the degraded container hand-cranks the [locked] refresh (this is the wrapper path with the Dockerfile-baked NOPASSWD entry; `sudo bash /devshop/kit/scripts/init-devshop.sh` looks like the same thing but isn't — that path doesn't match the sudoers rule and prompts for `node`'s password, which isn't set), then rebuild bakes the patched version normally.

  **Architectural fixes worth considering** (deferred — practical mitigation closes the immediate concrete failure mode):
  - Move the [locked] refresh portion of init-devshop into `initializeCommand` (host-side, pre-build) so workspace is synced from template _before_ Dockerfile reads it. `init-host-env.sh` already runs in initializeCommand and resolves `/devshop/` on the host for compose isolation, so the plumbing exists — but splits init-devshop into pre-build + post-start halves.
  - Reorder postStartCommand so init-devshop runs first. init-devshop's [locked] refresh is a pure-filesystem operation (template→workspace `install`) so doesn't strictly need network — but doesn't help the immediately-running `/usr/local/bin/init-firewall.sh` (which is the baked image copy); only helps the _next_ rebuild.
  - Multi-stage Dockerfile that exposes `/devshop/template/` as a build stage so `COPY --from=devshop-source` works at build time. More invasive; ties build to a path layout; doesn't survive scaffold-from-zero where `/devshop/` doesn't exist yet.

  [container-infrastructure, documented 2026-04-20, related-bootstrap-finding 2026-05-02, mitigation-shipped 2026-05-02]

- [ ] **Docker Desktop daemon-level `no-new-privileges: true` breaks the workspace devcontainer's postStartCommand.** Surfaced 2026-05-02 (lalista operator). Setting `"no-new-privileges": true` in Docker Desktop's Engine JSON applies it as the default to every new container, including the workspace devcontainer. The workspace's `postStartCommand` (`devcontainer.json:80`) is `sudo /usr/local/bin/init-firewall.sh && sudo /usr/local/bin/init-devshop.sh && …` — and sudo is a setuid binary, which NNP disables. Container rebuild fails with: `sudo: The "no new privileges" flag is set, which prevents sudo from running as root.` The other two flags currently recommended alongside it (`userland-proxy: false`, `icc: false`) are safe. Currently documented in `kit/docs/guide/macos-host-setup.md` Step 2, `kit/docs/guide/local-supabase-compose-isolation.md`'s Option 3 hardening table, and `kit/notes/security/local-supabase-isolation-options.md`.

  **Two ways to resolve in the doc**, pick one:
  1. **Add per-container opt-out instructions.** Tell the operator to also add `security_opt: ["no-new-privileges:false"]` to the `workspace` service in `template/.devcontainer/compose.yml`. Daemon default still hardens rogue ad-hoc `docker run` and the supabase-runner sibling + spawned supabase containers; only the trusted workspace opts back in. Better security posture, but creates a divergence operators need to maintain.

  2. **Drop NNP from the recommendation entirely** for Option 3 setups. Under Option 3 the workspace has no docker socket, so the threat NNP is supposed to mitigate (compromised dep → `docker run -v /Users:/h alpine`) is already closed by no-socket + File Sharing allowlist. NNP becomes belt-and-suspenders that breaks more than it adds. Cleaner for the operator; loses defense-in-depth against an unlikely path.

  **Architectural alternative (deferred)**: refactor the devcontainer so postStartCommand doesn't need sudo — e.g. run init-firewall.sh + init-devshop.sh as root via a tini-wrapped entrypoint, or move the firewall init into `initializeCommand` (host-side) and the devshop refresh into a USER-root step in the Dockerfile. Eliminates the conflict at the root, makes NNP straightforwardly compatible. More invasive than fixing the doc.

  **Edit targets**: `kit/docs/guide/macos-host-setup.md` (the Step 2 JSON block + the rationale paragraph), `kit/docs/guide/local-supabase-compose-isolation.md` (the matching row in its Option 3 hardening table), `kit/notes/security/local-supabase-isolation-options.md` (the `daemon.json` snippet at line 61).

  [container-infrastructure, doc-bug, surfaced-by lalista-operator-2026-05-02]

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
- [x] **RESOLVED 2026-04-27: Merged `docs-drift` + `doc-consistency` into `docs-reviewed`.** Single check, single bypass flag (`devshop.docsReviewed`), single adversarial-review call. The merged prompt rule covers per-doc enumeration (formerly docs-drift) AND cross-file coherence when reference docs are staged (formerly doc-consistency). Decision: merge happened during the cost-optimization session that also added per-check-type model routing — the dual-call cost was real (2× adversarial reviews per docs commit) and the rejection criteria were near-identical. Risk mitigation worked: the merged prompt explicitly surfaces "Reference docs staged in this commit:" so the reviewer knows whether the cross-file-coherence rule applies. See commit-guard.sh + adversarial-review.sh `docsReviewed` case for the new structure.

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

- [ ] **`/home/node/.gstack/` not volume-backed — container rebuild wipes gstack state.** [v+] The gstack state dir (`~/.gstack/`) holds per-project fingerprints, analytics, learnings, session timeline, and review history. The `claude-code-config-${devcontainerId}` volume mount only covers `/home/node/.claude/`, not `/home/node/.gstack/` — so every container rebuild wipes gstack state, even though nothing about the project changed.

  **Concrete impact**: `/land-and-deploy` Step 1.5 checks `~/.gstack/projects/$SLUG/land-deploy-confirmed` to decide whether to run the full dry-run walkthrough. After a rebuild, the file is gone and the skill re-presents the full "teacher mode" dry-run table (deploy platform, prod URL, what-will-happen) asking for re-approval, even though the deploy config is byte-identical to the previous approved version. Not broken, but annoying — one extra confirmation every rebuild. Observed on lalista PR-15 and PR-17 post-merge cycles (2026-04-23).

  Same footgun affects any gstack state future skills accumulate: timeline history, learning records, analytics trends.

  **Fix options**:
  1. Add `/home/node/.gstack` to the template `devcontainer.json` volume mount list (cleanest — one line, maps to a named volume like `claude-code-gstack-${devcontainerId}`).
  2. Move gstack state under `/home/node/.claude/gstack/` which IS volume-backed (cleaner from a "one mount, many state dirs" perspective, but requires touching gstack binaries that resolve `$GSTACK_HOME`).

  **Edit targets**: `template/.devcontainer/devcontainer.json` (option 1), or `kit/docs/guide/ops.md` + gstack skill files for the env var override (option 2).

  [v+, deploy-hygiene, surfaced-by lalista-PR17-land, 2026-04-23]

- [ ] **`git ls-remote` via HTTPS-with-token URL produces garbled output against abra-kadabra.** [v+] `/ak-clean-branches` Phase 1 enumerates remote branches via `git ls-remote "https://x-access-token:${TOKEN}@github.com/meirmsn/abra-kadabra.git" 'refs/heads/*'`. Output arrived as broken fragments ("Permission", "Could", "make", "the" — one word per line) instead of the expected `<sha>\trefs/heads/<branch>` rows. Fetch with the same URL worked fine; only ls-remote broke.

  **Workaround**: swap to `gh api repos/meirmsn/abra-kadabra/branches --paginate --jq '.[].name'`, which returns clean branch names and respects PAT scope. Already used this path in the lalista-PR17 cleanup run.

  **Hypothesis**: token contains a special character (`$` / newline / URL-reserved) that's interpreted by the shell or by git's URL parser, breaking the argv. `/etc/devshop-env` is `echo DEVSHOP_GITHUB_TOKEN=$TOKEN` into a file — if the token has an embedded newline or `$` it'd mangle. Low-effort fix is switching the skill to `gh api` unconditionally; higher-effort is sanitizing the URL construction.

  **Edit targets**: `.claude/skills/devshop/clean-branches/SKILL.md` (swap Phase 1 remote enumeration to `gh api`).

  [v+, tooling-nit, surfaced-by lalista-PR17-cleanup, 2026-04-23]

- [ ] **Wrapper-API design rule: expose lifecycle events, not just data.** [v0] When a wrapper around an event-emitter-style library (Supabase Realtime channel, EventEmitter, MQTT client, SSE, WebSocket) returns only the data callback and swallows error/lifecycle events, async failures silently degrade UX — the user-facing surface that should react to errors never gets the signal. Add this as both a `conventions.md` rule and a deterministic `ak-test-review` check.

  **Context**: lalista PR 27 (`fix/skipped-tests-cleanup`). `subscribeToList(client, householdId, callback)` in `packages/core/src/api/realtime.ts` wrapped supabase-js's channel and exposed only the postgres-changes `callback`. The `.subscribe()` call was passed no status callback — so `'CHANNEL_ERROR'` and `'TIMED_OUT'` (the ASYNC failure paths, which are the common case in production) never surfaced to consumers. `ListClient.tsx` had a try/catch around `subscribeToList` that handled SYNCHRONOUS WebSocket-constructor throws (a near-zero-frequency path) and nothing else. Result: real WS failures in production silently no-op'd the sync-error banner that was supposed to fire. The unit test (`SyncErrorBanner.test.tsx`) covered banner-rendering given state ✓ but no test covered the trigger path; the gap survived multiple PR cycles. The fix extended `subscribeToList(client, householdId, callback, onError?)` to pass a status callback to `.subscribe()` and invoke `onError` on `'CHANNEL_ERROR'` / `'TIMED_OUT'`.

  **Implementation**:
  1. **`conventions.md § Wrapper API design`** (new section): one-paragraph rule. _"When wrapping an event-emitter-style library, the wrapper's signature must include a way for consumers to receive error / lifecycle events, not only the data event. If the library's API has a status callback (e.g. supabase-js's `.subscribe(callback)`), pass it through. If consumers ignore it, that's their choice — but the wrapper must not foreclose the option."_ Include the `subscribeToList` before/after as the worked example.
  2. **`ak-test-review` deterministic check**: grep the diff for new wrappers in `packages/core/src/api/**` that call `.subscribe(` / `.on(` / `addEventListener(` and don't accept an `onError`-shaped parameter. Flag as a `critical` finding so it can't be silently dismissed. Heuristic, but cheap to run; false positives are negotiated at review time.

  **Edit targets**: `kit/docs/guide/conventions.md` (new "Wrapper API design" section), `.claude/skills/devshop/test-review/SKILL.md` (new check under "What to flag").

  [v0, surfaced-by lalista-PR27, 2026-04-26]

- [ ] **WS-failure E2E recipe: `page.routeWebSocket`, not `page.route().fulfill(503)`.** [v0] Document the canonical Playwright pattern for testing "what happens when the realtime WebSocket fails?" so the next Supabase project doesn't re-debug the silent-retry trap.

  **Context**: lalista PR 26 originally wrote a `realtime.spec.ts` banner test using `page.route('**/realtime/v1/websocket**', route => route.fulfill({status: 503}))` — assuming a 503 on the WS upgrade would surface CHANNEL_ERROR through supabase-js. It doesn't. supabase-js's realtime client absorbs the 503 into its onerror→onclose→silent-retry loop without emitting CHANNEL_ERROR within any reasonable test budget; the test stayed `test.skip(true, ...)` for an entire PR cycle while diagnosis ran (PR 26 trace investigation, then PR 27's actual fix). The right API is `page.routeWebSocket('**/realtime/v1/websocket**', ws => ws.close())` (Playwright 1.48+) — purpose-built for WS interception, triggers a deterministic close that supabase-js converts to CHANNEL_ERROR via the subscribe-status callback.

  **Implementation**: add a "Pattern N: Testing realtime WS failures" section to `kit/docs/guide/supabase-ssr-boilerplate.md`. The file already has Pattern 4 (realtime publication setup) and Pattern 5 (WebKit form-state hydration race) — Pattern 6 fits the cadence. Body: the trap (route.fulfill 503 silently retried), the fix (page.routeWebSocket close), the assertion shape (banner copy via getByText), the prereq (Playwright ≥ 1.48; check `apps/web/package.json`). Cite lalista PR 26 trace evidence + PR 27 fix as worked examples.

  **Edit targets**: `kit/docs/guide/supabase-ssr-boilerplate.md` (new Pattern 6 section).

  [v0, surfaced-by lalista-PR26-and-PR27, 2026-04-26]

- [ ] **Backport lalista's CI slow-job + helper scripts to the template.** [v0] Lalista PR 4 (merged) shipped a working slow-job: `supabase start` + `supabase db reset`, integration tests gated on `VITEST_INTEGRATION=1`, type-drift via `scripts/ci-type-drift.sh`, rollback-EXPLAIN via `scripts/ci-rollback-explain.sh`, edge-fn deploy, Playwright at mobile + desktop. The shape is now proven on a real project; the next devshop project shouldn't have to re-derive ~200 lines of bash + ~140 lines of YAML from `kit/ROADMAP.md § CI slow job expansion`'s prose checklist.

  **Context**: `kit/ROADMAP.md:526-561` documents Trigger 1 / Trigger 2 expansion as if both checks need to be authored from scratch when the first DB-backed feature lands. They don't anymore — the bash + YAML exist in `/workspace/`. Without this backport, every future project re-implements them from prose, defeating the "lalista is the template-validation project" framing that already works for Auth UX and zod-validation conventions (lalista `TODOS.md`).

  **Implementation**:
  1. Copy `/workspace/scripts/ci-type-drift.sh` → `template/scripts/ci-type-drift.sh`; parameterize anything lalista-specific (verify the types path `packages/core/src/supabase.types.ts` is shared convention).
  2. Copy `/workspace/scripts/ci-rollback-explain.sh` → `template/scripts/ci-rollback-explain.sh`; verify no lalista-specific assumptions.
  3. Replace `template/.github/workflows/ci.yml`'s commented-out stub (lines 43-56) with the live lalista-shape slow-job, kept commented behind a sentinel like `# UNCOMMENT WHEN: first DB-backed feature ships — see kit/ROADMAP.md § CI slow job expansion`.
  4. Rewrite `kit/ROADMAP.md § CI slow job expansion` Trigger 1 from "write a type drift check, write a rollback validator…" to "uncomment the slow-job block; fill in `SUPABASE_SERVICE_ROLE_KEY` + `ANTHROPIC_API_KEY_QA` secrets (the latter re-exported as `ANTHROPIC_API_KEY` for the function process); helpers already ship in `template/scripts/`."
  5. Optional follow-up (defer until a second project actually scaffolds): `.claude/skills/devshop/new-project/SKILL.md` Phase B gains a question "does this project ship a DB at scaffold time? If yes, uncomment the slow-job stub now."

  **Edit targets**: `template/scripts/ci-type-drift.sh` (new), `template/scripts/ci-rollback-explain.sh` (new), `template/.github/workflows/ci.yml` (replace stub lines 43-56), `kit/ROADMAP.md § CI slow job expansion` (rewrite Trigger 1), optional `.claude/skills/devshop/new-project/SKILL.md`.

  [v0, devshop-template-backport, surfaced-by lalista-PR4-merged, 2026-04-24]

- [ ] **PR-body "Manual review" category guardrail + Phase 6 auto-attest.** [v0] PR-body `[ ]` items under "Manual review" should be ONLY genuinely judgmental items the automation cannot answer (intent match, design review, live QA walkthrough, post-deploy metrics). Today the section drifts to include factually-verifiable items (idempotent guard pattern correct, JSDoc cites coverage, doc paragraph reads correctly) — items that pre-ship gates already attested. Reviewers see these as `[ ]` and feel obligated to re-verify; meaningful judgment items get diluted.

  **Context**: lalista PR 27 shipped with 4 "Manual review" items: (1) spec reflects intent — judgmental, kept `[ ]` correctly; (2) migration idempotent guard correct — factually verified by reading `supabase/migrations/013_realtime_publication.sql:12-20`; (3) JSDoc cites E2E coverage — factually verified by reading `packages/core/src/api/realtime.ts:28-31`; (4) CLAUDE.md gotcha reads correctly — factually verified by reading `CLAUDE.md:28`. Items (2)/(3)/(4) were ALREADY attested by pre-ship Gate 1 (Docs check), Gate 5 (/ak-test-review), Gate 6 (/review), and Gate 11 (Convention check); restating them in Manual review duplicated the work and obscured (1) — the only item that genuinely needs a human.

  **Implementation** — two-layer fix:
  1. **Layer A (prevention)**: extend `/ak-build` Phase 4 § "Checkbox semantics + timing" with a "What belongs in Manual review" rule. Canonical set: spec/intent match, visual/design audit, live QA walkthrough, post-deploy metrics. Anything resolvable by `cat <file>` / `grep <symbol>` / fixed-shape comparison is NOT a manual-review item — either drop it (pre-ship gate already covered it; audit comment carries the attestation) or self-attest under "Pre-push automated gates" with `[x]` + file:line.

  2. **Layer B (Phase 6 auto-attest)**: add Part C to Phase 6's checkbox sweep. For each `[ ]` line under "Manual review", classify as `factual` (resolvable by file/symbol/value lookup) or `judgmental` (spec/design/UX/intent). Behavior:
     - `factual` + verifies ✓ → mark `[x]` with file:line attestation inline (no halt, no operator prompt — autonomous closure is Phase 6's job).
     - `factual` + verifies ✗ → halt, same shape as Part B's "evidence missing" branch (the body claims something the artifact contradicts — real problem).
     - `judgmental` → leave `[ ]` for the human reviewer.

     Heuristic for classification: keywords like "is correct", "cites", "reads correctly", "matches schema X", "follows convention Y" → factual. Keywords like "reflects intent", "looks right", "feels good", "tests pass on prod" → judgmental. When ambiguous, default to factual (the verification is cheap; halting on a false positive is recoverable).

  **Edit targets**: `.claude/skills/devshop/build/SKILL.md § Phase 4 / PR body conventions / Checkbox semantics + timing` (Layer A rule + canonical-set list), `.claude/skills/devshop/build/SKILL.md § Phase 6 / Part C` (Layer B sweep — new sub-section after Part B's evidence-on-disk sweep).

  **Why Phase 6 auto-attests rather than surfacing**: Phase 6's existing Parts A and B already do autonomous closure (state-based reconciliation marks CI/preview `[x]`; evidence sweep halts only on missing artifacts). The factual-checkbox case is symmetric to Part A — auto-attest when verifiable, halt only when something is genuinely wrong. Surfacing a factual item to the operator just to do the verification I could have done myself wastes their attention; surfacing only on real failure preserves it.

  [v0, ak-build-skill-improvement, surfaced-by lalista-PR27, 2026-04-27]

- [ ] **Filesystem-lock erosion via git operations.** [v1] `init-devshop.sh` runs at container start as root and locks security-critical scripts (`chown root:root + chmod 644` on the recursive `find $DEVSHOP/kit/scripts/ -name '*.sh'`). The lock is intended as Layer 2 of the agent-bypass-prevention model (Layer 1 = settings.json deny rules). But the lock erodes whenever git modifies a locked file: `git checkout`, `git merge`, `git pull`, `git rebase` etc. all rewrite file content via the running user (`node`), and the rewritten file is recreated with `node:node` ownership. After that, the root lock is gone until the next container restart — and the agent (running as `node`) can `Edit` / `Write` the file freely.

  **Empirical state at v1.20.0** (devshop main, post-session 2026-04-27): `kit/scripts/release.sh` + `kit/scripts/init-devshop.sh` + `kit/scripts/commit-hooks/check-clean-tree.sh` etc. are still `root:root 644` (haven't been git-modified since last container start). But `kit/scripts/commit-hooks/commit-guard.sh` and `kit/scripts/adversarial-review.sh` are `node:node 644` — both are actively-evolving files that git has rewritten in recent sessions. The lock loop ran at container start and locked them then; subsequent git activity un-locked them. This was directly exploited (without intent) in the 2026-04-27 session: cross-repo blocking check removal edited `commit-guard.sh` + `adversarial-review.sh` via the standard `Edit` tool with no friction at the filesystem layer. Layer 1 (settings.json deny `kit/scripts/*` single-segment glob) had a separate gap that didn't cover `commit-hooks/`; that gap was fixed in the same session by widening the glob to `kit/scripts/**`. With Layer 1 hardened, Layer 2's erosion is the remaining vector.

  **Why v1, not v0**: the model still works for any file git hasn't recently touched, and the single-character Layer 1 fix landed in v1.20.0 closes the immediate concrete attack surface (any kit/scripts subdirectory script is now blocked by deny rules at the Claude Code permission layer, regardless of filesystem ownership). Layer 2 erosion is a defense-in-depth gap, not a load-bearing one once Layer 1 is correct. v1 is the right tier — fix before second-project onboarding so two-layer defense is real, not aspirational.

  **Implementation options** (pick one or combine):
  1. **Re-lock on commit**: add a `kit/scripts/init-devshop.sh`-equivalent lock loop to a `pre-commit` or `post-merge` git hook. Idempotent (chown is a no-op when ownership is already correct); cheap; runs in every interactive git operation that could erode the lock. Caveat: requires sudo to chown to root, which means the hook either needs passwordless sudo (already true in devshop devcontainer per init-devshop.sh's sudoers config) or the hook's chown step gets gated behind a condition.

  2. **Use immutable bit instead of ownership**: `chattr +i $f` makes the file immutable even to root. git can't modify an immutable file at all (write fails). This removes the erosion path entirely — git rewrites become hard errors instead of silent ownership-flips. Caveat: requires `CAP_LINUX_IMMUTABLE` in the container; need to verify devcontainer has it.

  3. **Check + restore at session start**: extend `kit/scripts/session-start.sh` to verify that all scripts in the lock list are still root:root, and re-lock any that aren't (with sudo). This catches erosion at session boundaries rather than every commit. Slightly less defense-in-depth than (1) but cheaper and simpler. Caveat: gap window between erosion and next session-start.

  4. **Move logic out of locked files**: rewrite `commit-guard.sh` etc. as a thin wrapper that exec's a binary or jq config. The binary/config is signed/verified rather than just owned. Higher complexity.

  Recommend (1) + (3) combo: session-start re-lock as a baseline + pre-commit re-lock as the immediate-correction layer.

  **Edit targets**: `kit/scripts/init-devshop.sh` (factor out the lock loop into a reusable function), `kit/scripts/session-start.sh` (call the lock function), `template/.husky/pre-commit` (call the lock function before guard checks fire). Update `kit/docs/guide/security.md` to document Layer 2's actual semantics (locked-at-session-start, re-locked-at-commit) rather than the current (incorrect) "All `kit/scripts/*.sh` are also root-locked" claim that doesn't survive git operations.

  **Cross-ref**: 2026-04-27 session — the cross-repo check removal exercised this gap directly. Fix landed in v1.20.0 was Layer 1 only (`kit/scripts/*` → `kit/scripts/**` in settings.json deny rules). Layer 2 erosion remains. See devshop commit history for the v1.20.0 Layer 1 fix.

  [v1, security-defense-in-depth, surfaced-by 2026-04-27-session, 2026-04-27]

- [ ] **Pre-ship gate: middleware-matcher public-asset coverage check.** When `apps/web/middleware.ts` exists and uses a negative-lookahead matcher (`'/((?!...).*)'` shape), scan `apps/web/public/` for root-level static assets and warn if any aren't covered by the matcher's exclusions. Specifically: any file with `.png`/`.jpg`/`.jpeg`/`.gif`/`.svg`/`.webp`/`.ico` extension at the public root that isn't matched by an exclusion pattern → warn. Catches the failure mode where browsers (and Gmail's image proxy) get auth-walled when fetching public assets, with no error visible to the developer.

  **Context**: lalista PR 45 (2026-05-05). Chapter 1l (2026-05-04) shipped an inline email-template logo at `https://lalista-ten.vercel.app/lalista-email-logo.png` (later `lalista.store/...`). Middleware matcher excluded `_next/static`, `_next/image`, `favicon.ico`, `manifest.json`, and the `/icons/` folder — but NOT root-level public images. Result: every confirmation/recovery email rendered Gmail's blue-square question-mark placeholder where the lalista logo should be, because Gmail's image proxy hit the auth wall and got HTML back instead of PNG. Bug pre-existed since chapter 1l ship; surfaced 2026-05-05 only because the lalista.store custom-domain cutover triggered a smoke-test of the rendered email body. Fix in PR 45 extended the negative-lookahead with `.*\.(?:png|jpg|jpeg|gif|svg|webp|ico)$`.

  **Why this generalizes**: every Next.js + Supabase Auth project ships a middleware that gates auth, and most ship root-level public assets (icons, OG images, robots.txt, email-template logos). The default Next middleware matcher example in the official docs only excludes `_next/static`/`_next/image`/`favicon.ico` — same gap. Without this gate, the next project that adds a new email-template logo or PWA-related root asset re-discovers the bug.

  **Implementation**: bash script in `kit/scripts/preship/middleware-public-coverage.sh`, invoked from `/ak-pre-ship` (likely as a Gate alongside RLS coverage). Parse the matcher's negative-lookahead string, list `apps/web/public/*.{png,jpg,jpeg,gif,svg,webp,ico}` files, fail-with-recipe if any aren't covered. Recipe is the regex pattern that would close the gap.

  **Edit targets**: `kit/scripts/preship/middleware-public-coverage.sh` (new), `.claude/skills/devshop/pre-ship/SKILL.md` (add gate invocation). Reference implementation: lalista commit `ec62818` in PR 45.

  [pre-ship-gate, surfaced-by lalista-PR45-cutover-smoke-test, 2026-05-05]

- [ ] **Email-template visual-QA gate / convention.** When PR diff touches files matching `supabase/templates/*.html` (or future analogues — `apps/*/email-templates/**`, `packages/*/emails/**`), require the test plan to include a "rendered email screenshot" attachment OR an explicit "trigger fresh email + open in real client" step. Prevents shipping email-template changes that pass typecheck/lint but render broken in actual mail clients (logo missing, layout breaking, fonts not falling back, links wrong).

  **Context**: lalista chapter 1l (2026-05-04, PR #43) shipped two new branded email templates (`confirmation.html`, `recovery.html`) and a logo asset. Code review + visual review of the HTML in a browser passed. Nobody triggered an actual email and opened it in Gmail — so nobody saw that the inline logo was broken (Gmail's image proxy hit the auth wall, blue-square placeholder rendered). Bug shipped silently for 24 hours until lalista.store cutover smoke test triggered a fresh email and the operator visually saw the broken logo.

  **Why visual QA is non-substitutable**: HTML in a browser ≠ HTML in Gmail (or Outlook, or Apple Mail). Email clients aggressively rewrite/strip styles, proxy images, sandbox CSS, override colors in dark mode, and rate-limit external fetches. The only way to know an email template renders correctly is to send a real email and open it in a real client. Static review catches HTML errors, not deliverability or rendering quirks.

  **Why this generalizes**: every project that ships transactional emails will have email templates. Every operator will be tempted to skip "send a real email and open it" because it's a manual step in an otherwise-automated pipeline. Encoding the convention prevents the omission.

  **Implementation options**:
  1. **`/ak-spec` checkpoint** — when spec adds/touches email templates, prompt for a "rendered email screenshot will be attached to PR test plan before merge" commitment in the spec's test plan section. Soft enforcement via spec review.
  2. **`/ak-pre-ship` gate** — when diff touches `supabase/templates/*.html`, require a `specs/<feature>/email-rendered.png` attachment (or similar evidence) before merge. Hard enforcement.
  3. **`/ak-test-review` checkpoint** — when reviewing tests, flag the gap if email-template files are touched but no E2E test exercises an end-to-end send (paired with reading the rendered output via mailpit + screenshot).

  Option (2) has highest leverage since /ak-pre-ship runs on every PR. Option (1) prevents the issue at the planning stage. Best is probably both.

  **Edit targets**: `.claude/skills/devshop/pre-ship/SKILL.md` (add gate, possibly conditional on `supabase/templates/**` or `apps/*/emails/**` glob), `.claude/skills/devshop/spec/SKILL.md` (add test-plan checkpoint when emails touched). Reference: lalista PR 45's "Smoke test from a fresh inbox" line in the test plan — that's the convention codified.

  [pre-ship-gate, spec-checkpoint, surfaced-by lalista-chapter-1l-broken-logo, 2026-05-05]

- [ ] **Generalize lalista's `scripts/ci-rollback-explain.sh` + `scripts/ci-type-drift.sh` into devshop kit-level scripts.** Both are project-specific in implementation but the patterns are reusable: every Supabase project with `-- ROLLBACK:` blocks in migrations wants the round-trip EXPLAIN check, and every project with codegen'd types (`supabase gen types typescript`) wants the drift check. Today these live in lalista's `scripts/` folder, hand-edited, and would need to be re-derived for any second project that adopts the devshop.

  **Context**: surfaced 2026-05-05 in PR #46 review (lalista email-logo cutover follow-up). The user noted "those other 2 scripts in there look like hooks that should be devshop level." Correct — they're CI gates, not project-specific business logic.

  **Project-specific bits today** (to abstract):
  - Hardcoded paths: `supabase/migrations/*.sql`, `packages/core/src/supabase.types.ts`, the local Supabase REST URL, project-specific seed loading
  - Project-specific assumptions: lalista runs Supabase via `pnpm db:start` (the compose-isolation runner relay); other projects might use direct host-Supabase or skip-supabase variants

  **Shape for kit-scripts version**:
  - `kit/scripts/ci/rollback-explain.sh` — accepts the migrations-glob + the local Supabase URL as args (or reads from CLAUDE.md § Deploy Configuration like `/setup-deploy` does). Falls back to project-default paths.
  - `kit/scripts/ci/type-drift.sh` — same pattern; configurable types-file path + supabase project ref.
  - `template/.github/workflows/ci.yml` — references `kit/scripts/ci/...` paths (cross-repo: workflows in projects, scripts in devshop kit). Or copied per-project via `/ak-new-project` Step 17 (the `/setup-deploy` path).

  **Migration**: existing projects (lalista) keep their hand-edited copies until the next `/ak-migrate-project` adoption sweep, OR the `template/scripts/` shipped variant gets a clean diff against lalista's that surfaces drift to address. The "second project adopts devshop" event is the natural trigger to do this work — until then lalista's are functional.

  **Edit targets**: `template/scripts/ci/{rollback-explain,type-drift}.sh` (new), `template/.github/workflows/ci.yml` (path updates), `.claude/skills/devshop/new-project/SKILL.md` (Step 17 — sync these alongside `/setup-deploy`'s output).

  [v1, kit-script-generalization, surfaced-by lalista-PR46-review, 2026-05-05]

- [ ] **lint-staged stash backup chokes on rename + new-symlink-at-old-path.** Surfaced 2026-05-07 during `/ak-merge-devshop`'s post-ship layout fix. When a single staging round combines (a) `git mv OLD/file -> NEW/file` AND (b) a new symlink at OLD pointing to NEW, the pre-commit hook's lint-staged backup fails with `error: 'OLD/file' is beyond a symbolic link` from `git stash` itself. This is a git-plumbing limitation, not strictly a lint-staged bug — but lint-staged unconditionally runs `git stash` for backup, so the failure surfaces as a hook block.

  **Blast radius**: blocks `git merge --squash` whenever the squashed diff has this combination. Any future skill with a "move to canonical layout + symlink-at-old-path-for-back-compat" diff hits this. Caught during the `/ak-merge-devshop` layout-fix's failed squash; fallback was a 2-commit ff-merge of the fix branch (loses the squash convention).

  **Implementation options**:
  1. **lint-staged config tweak** — set `stash: false` (suppresses the stash backup entirely; loses the rollback-on-failure safety net but unblocks the rename+symlink combo).
  2. **Custom backup strategy** — replace lint-staged's default with a thin wrapper that uses `git diff > /tmp/backup.patch` instead of `git stash`. Preserves the rollback safety, dodges the symbolic-link limitation.
  3. **Detect-and-defer in /ak-merge-devshop** — Phase 2 detects the rename+symlink-at-old-path combo in the staged diff before invoking commit; suggests the ff-merge fallback automatically. See companion entry below.

  Option (1) is fastest but reduces safety; option (2) is the cleanest long-term fix; option (3) is complementary (fixes the user-visible blast at the skill level even if the hook stays as-is).

  **Edit targets** (option 1): `package.json` lint-staged config OR `.lintstagedrc` (whichever the repo uses). **Edit targets** (option 2): replace lint-staged with a thin wrapper script under `kit/scripts/`. **Edit targets** (option 3): see companion entry.

  [v0+, hook-bug, surfaced-by ak-merge-devshop-smoke-test, 2026-05-07]

- [ ] **`/ak-merge-devshop` Phase 2: detect rename-plus-symlink-at-old-path combo and fallback to ff-merge.** Companion to the lint-staged stash bug above. When the skill's Phase 2 attempts `git merge --squash` and the staged diff includes both `R OLD -> NEW` and `A OLD` (a new symlink at the rename source), the squash WILL fail at commit time on the lint-staged stash bug. The skill should detect this combo BEFORE attempting the squash, surface the issue, and offer the ff-merge fallback inline.

  **Behavior shape**:
  - After `git merge --squash <branch>` stages changes, scan `git diff --cached --name-status` for matching `R<sim>` + `A` entries where the `A` path equals the `R`'s source path.
  - On hit: abort the squash (`git reset`), print a one-screen explanation referencing this TODOS entry + the lint-staged-stash entry, AND surface ff-merge as an alternative ("the fix branch's commits will land as-is on main, preserving N separate commits instead of squashing — same end-state on the file system, different git history shape").
  - On the operator's confirmation, run `git merge --ff-only <branch>` instead of the squash.

  **Why detect-and-defer is the right shape**: the hook bug is harder to fix (option 2 from the companion entry); `/ak-merge-devshop`'s user surface is where operators feel the pain; surfacing the workaround at skill-invocation time avoids the manual recovery dance every time.

  **Edit targets**: `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2` adds the detection block; new `## Known limitations` section documents the rename-plus-symlink combo; `kit/tests/util-ak-merge-devshop.bats` adds a content-validation test for the detection prose.

  [v0+, skill-improvement, surfaced-by ak-merge-devshop-smoke-test, 2026-05-07]

- [ ] **SKILL.md gstack-helper path resolution falls through silently when user-global gstack is auto-pruned.** [v0] When a SKILL.md preamble hardcodes `~/.claude/skills/gstack/bin/<helper>` (or any path under `~/.claude/skills/gstack/`), the helper goes silently no-op when Claude Code's settings-file maintenance prunes the user-global gstack folder (sometimes happens on devcontainer rebuilds or settings refreshes). Telemetry, timeline, and learnings have been silently no-op'ing across multiple deploy cycles on lalista. Only `gstack-slug` failed visibly, because `/land-and-deploy` depends on its output — every other helper that "fires and forgets" silently degraded.

  **Fix**: SKILL.md preambles should resolve the helper path via the same fallback the `browse` SETUP block uses (`/devshop/.claude/skills/gstack/browse/SKILL.md` lines 358-361) — try `$_ROOT/.claude/skills/gstack/<helper>` (project-local, survives Claude Code prune) first, fall back to `~/.claude/skills/gstack/<helper>`. Either inline as a `B=` resolver pattern in every SKILL.md preamble, OR factor into a single helper `bin/gstack-resolve-bin <helper-name>` and call that from each SKILL.md preamble.

  Reference shape from `browse` SETUP:

  ```bash
  _ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
  B=""
  [ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/<helper>" ] && B="$_ROOT/.claude/skills/gstack/<helper>"
  [ -z "$B" ] && B=~/.claude/skills/gstack/<helper>
  ```

  **Edit targets**: enumerate all SKILL.md files in `/devshop/.claude/skills/` that hardcode a `~/.claude/skills/gstack/...` path (telemetry, timeline, learnings emitters at minimum) + their lalista counterparts in `/workspace/.claude/skills/`. Apply the resolver pattern (or factor into `bin/gstack-resolve-bin`). Lalista has a project-local `.claude/skills/gstack/` (per `MEMORY.md § gstack Setup — virtiofs Build Workaround`); that's the structural defense the fallback pattern leans on.

  **Why v0 — blocks next-project adoption**: affected EVERY skill silently for an entire deploy cycle on lalista. The next project that scaffolds inherits the same bug — and worse, the next project may not have a project-local `.claude/skills/gstack/` yet (lalista does because of the virtiofs rebuild workaround). Defending against it now costs ~20 min; the next debugging session that surfaces "why did my telemetry never log?" will cost more.

  [v0, surfaced-by lalista-PR49-deploy-cycle, 2026-05-07]

- [ ] **PostgREST returns `data: null` + `error` field for non-existent columns; downstream null-deref masks the typo.** [v0] When a Supabase query selects a column that doesn't exist (`from('table').select('id, nonexistent').single()`), PostgREST returns `data: null` AND populates the `error` field. But most call sites only consume `data` and crash later with `TypeError: Cannot read properties of null (reading 'id')`. The actual error message ("column does not exist") is swallowed by the developer's catch-the-data-is-null pattern.

  **Context**: hit twice in lalista PR #49 — `items.name` (column doesn't exist; `items` table has `name_canonical`) and `purchase_history.list_entry_id` (FK was deliberately not added per migration 010 design — `purchase_history` doesn't carry it back). Both crashed Playwright E2E tests with generic null-deref errors; root cause was found by re-reading the query against the schema, not by reading the swallowed error message.

  **Fix options** (pick one or combine):
  1. **Convention doc** — `kit/docs/guide/conventions.md § Database queries`: require all `.select()` call sites to either use `.single()` AND check `error` first, OR use a typed wrapper that throws on `error`. Soft enforcement.
  2. **Typed query helper** in `template/packages/core/src/supabase.ts` (or a new `@devshop-template/core` export): wrap supabase-js's `.from().select()` to throw immediately if `error` is set, regardless of `data`. Hard enforcement at the API boundary. Requires consumer migration.
  3. **CLAUDE.md gotcha template** in `template/CLAUDE.md` — preemptive entry warning future projects of the failure mode + the "always check `error` first" pattern.

  Recommend (1) + (3) for cheap proportionate coverage; (2) is durable but invasive — defer until a third project hits the same bug.

  **Edit targets**: `kit/docs/guide/conventions.md` (new "Database queries" section), `template/CLAUDE.md` (new gotcha entry), optionally `template/packages/core/src/supabase.ts` (typed wrapper).

  **Why v0 — blocks next-project adoption**: every Supabase project will hit this. Lalista alone hit it twice in one PR. The cost of (1) + (3) is ~10 min for prose; the cost of NOT shipping it is one debugging session per project per occurrence — and the symptom ("test crashes with null data") looks like a null-data bug, not a column-name typo, so the debugging path is unintuitive.

  [v0, surfaced-by lalista-PR49-fix-loop, 2026-05-07]

- [ ] **`/ak-pre-ship` Gate 9 (`/qa`) doesn't run fault-injected scenarios — happy-path crawl misses banner / error-state UI bugs.** [v0] UI flows pass under happy-path QA conditions but break under fault-injected ones (network failure, RPC abort, timeout). PR #49's `AddItemSheet` overlay-intercepts-Undo bug only surfaced when CI ran `page.route().abort()` to simulate a network failure — `/qa`'s happy-path crawl never tickled the failing-mutation banner state, so the overlay-z-index bug shipped past pre-ship and only got caught by Playwright's slow-job CI run.

  **Shape**: extend `/ak-pre-ship` Gate 9 with a "fault-injected QA pass" sub-step. For each Tier A2 surface (looked up via spec or convention — the new `kit/docs/guide/latency-feedback.md` will tell us which surfaces are Tier A2; until that ships, parse the diff for `useOptimisticMutation({ failureMode: 'banner' })` call sites), abort the relevant edge-function/RPC route via `page.route().abort()` and assert the banner Retry/Undo affordances render and are clickable (no overlay intercept, no z-index regression).

  Could be deterministic (parse spec for "Tier A2" annotations) or heuristic (grep diff for `useOptimisticMutation` + `failureMode: 'banner'`). Either works for v0.

  **Edit targets**: `.claude/skills/devshop/pre-ship/SKILL.md` Gate 9 amendment + new helper `kit/scripts/preship/fault-injected-qa.sh` for the route-pattern detection logic.

  **Why v0 — blocks next-project adoption**: pattern is reusable for any Tier A2 surface; lalista PR #49 paid 3 CI fix-loop iterations worth of cycles on bugs this gate would have caught pre-ship. Every next project that ships optimistic UI will hit the same class of bug (overlay z-index, focus management, banner accessibility under failure). The convention has to exist before a second project onboards or each project re-pays the same iteration cost.

  **Cross-ref**: depends on the latency-feedback framework (`kit/ROADMAP.md § Latency feedback framework — 4-tier decision rule + primitives`) for the "which surfaces are Tier A2?" lookup. Either ships first; if this lands first, the lookup is a manual spec annotation; once the framework ships, the lookup is automatic via `useOptimisticMutation` call-site detection.

  [v0, pre-ship-gate, surfaced-by lalista-PR49-fix-loop, 2026-05-07]

- [ ] **Tier A2 retry-budget E2E tests need `page.clock.fastForward()` instead of bumped per-test timeouts.** [v0] When a Playwright test exercises a retry sequence with backoff (e.g. lalista's `RETRY_BACKOFF_MS = [1000, 3000, 7000]` totaling 11s of wall-clock backoff), the test runtime explodes past Playwright's default 30s timeout once you add sign-in flow + abort RTT + post-banner assertions. Lalista's `add-item-banner.spec.ts` workaround was `test.setTimeout(60000)` and `bannerLabel toBeVisible({ timeout: 25000 })` — works but inheritable-pattern-shaped, not a one-off. Future Tier A2 surfaces will write similarly-shaped tests and rediscover the workaround instead of the right answer.

  **Fix**: document the canonical `page.clock.fastForward()` pattern (Playwright 1.45+) for tests against retry-budget-shaped surfaces. Fast-forward fake time past the backoff intervals so the test runs in <2s wall-clock instead of 11s+. Pattern reference: Playwright docs at https://playwright.dev/docs/clock + lalista's `add-item-banner.spec.ts` as the "DO NOT do it this way" prior art.

  Sketch:

  ```ts
  await page.clock.install();
  // ... trigger the optimistic mutation ...
  await page.clock.fastForward('00:11'); // skip past 11s of backoff
  await expect(bannerLabel).toBeVisible(); // banner appears at fake-time-end
  ```

  **Edit targets**: `kit/docs/guide/testing.md` (new "Pattern N: Tier A2 retry-budget tests" section, alongside the existing supabase-ssr-boilerplate.md patterns) + an example helper showing the install / fastForward / assertion shape. Verify Playwright version in `template/apps/web/package.json` is ≥1.45 (lalista is on 1.55, fine).

  **Why v0 — blocks next-project adoption**: future Tier A2 surfaces in the next project (or in lalista as the surface count grows) will write similarly-shaped tests. Without this guide, each rediscovers the timeout-bumping workaround. Cost is ~15 min for doc + helper; cost of NOT shipping it is one debugging session per Tier A2 test per project.

  **Cross-ref**: depends on the latency-feedback framework (`kit/ROADMAP.md § Latency feedback framework — 4-tier decision rule + primitives`) for the "which surfaces are Tier A2?" definition. Pairs with the fault-injected QA gate above — both are Tier-A2-shaped test infrastructure gaps lalista PR #49 surfaced.

  [v0, surfaced-by lalista-PR49-add-item-banner-spec, 2026-05-07]
