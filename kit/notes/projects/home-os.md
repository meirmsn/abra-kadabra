---
supabase_port_offset: 100
---

# Init Tracker — home-os

Created by `/ak-new-project` on 2026-05-12.

## Progress

0. [x] **[HUMAN]** macOS host setup (per-machine, one-time — skip if already done for a previous devshop project)
1. [x] Check binary versions (delta + gitleaks current; supabase-cli 2.84.2→2.98.2 + dcg 0.4.0→0.5.2 deferred by user)
2. [x] Customize project docs (README already filled; BUILD-LOG + PRODUCT-ROADMAP kept as template; root package.json name → home-os)
       2b. [x] Choose local supabase reachability (compose-isolation; **+100 port offset** to avoid lalista collision)

   **Port offset for home-os local supabase stack** (lalista uses defaults):

   | service   | default | home-os |
   | --------- | ------- | ------- |
   | api/kong  | 54321   | 54421   |
   | db        | 54322   | 54422   |
   | studio    | 54323   | 54423   |
   | inbucket  | 54324   | 54424   |
   | realtime  | 54327   | 54427   |
   | analytics | 54327   | 54427   |

   Applied in this step to: `.devcontainer/compose.yml` (workspace `SUPABASE_URL`, both socat forwards), `.devcontainer/supabase-runner/Dockerfile` (EXPOSE), `.devcontainer/init-firewall.sh` (host.docker.internal allow rules), `.devcontainer/README.md` (docs).

   **MUST apply at Step 15** (`supabase init`): edit `supabase/config.toml` to set matching ports in `[api]`, `[db]`, `[studio]`, `[inbucket]`, `[analytics]` sections — otherwise spawned siblings still bind 54321/54322 (clash with lalista) and the socat forwards point nowhere.

   **Verify at Step 7** (devcontainer rebuild): `pnpm db:start` succeeds; `curl http://host.docker.internal:54421/health` reaches kong.

   **Surface to user before session end**: this port-rebind path isn't codified in `/ak-new-project` Step 2b. If a second devshop project commonly collides with the first, the template (or skill) should either ship a `SUPABASE_PORT_OFFSET` env knob or document the rebind recipe inline.

## Devshop generalizations to surface at session end

(Accumulating as we go. Decide at session end which to ship now vs file.)

1. **Supabase port-rebind path** (Step 2b) — if running 2+ projects concurrently is common, the template needs either a `SUPABASE_PORT_OFFSET` knob propagated through compose.yml + Dockerfile + init-firewall.sh + supabase/config.toml, OR an inline recipe in the skill's Step 2b sub-step for "second project".

2. **Sentry platform = Next.js, not React** (Step 3) — skill currently says "platform: React, slug: `<project-name>`". Template is Next.js-only; Sentry's Next.js SDK does SSR + Route Handler + Server Action error capture (React-only SDK doesn't). Fix the skill text.

3. **Pre-burn `SUPABASE_SERVICE_ROLE_KEY` published local-stack default JWT in the template `.env`** (Step 4) — the value is identical across every Supabase install (published default, hardcoded supabase-cli signing secret). Currently the operator has to either run `supabase start` to discover it, or ask Claude. Pre-filling it in `/devshop/template/.devcontainer/.env` (or an `.env.example` companion) eliminates a friction point and reinforces "this is public, not prod-sensitive". Keep the `# NOT the prod admin key` comment inline.

4. **Sentry DSN UI navigation guidance is stale** (Step 4 detail) — skill points at "Project Settings → Client Keys" which doesn't match current Sentry UI. The reliable path is the direct URL `https://sentry.io/settings/<org-slug>/projects/<project-slug>/keys/`. Either update the skill's Sentry-DSN paragraph to lead with the direct-URL form, or replace it with a `sentry-cli` invocation that fetches the DSN non-interactively.

5. **Drop `SUPABASE_DB_PASSWORD` from `.devcontainer/.env`** (Step 4) — same blast radius as prod service-role key (direct DB connection, no RLS), but the skill currently persists it locally while telling operators NOT to persist the service-role prod key. The .env line isn't what CI consumes (CI reads the GH Secret). The only operator-side use is rare ad-hoc prod DB ops, which can follow the same paste-from-password-manager-then-clear pattern as the prod service-role key. Asymmetric treatment is skill drift, not deliberate design. Proposal: remove `SUPABASE_DB_PASSWORD=` from `/devshop/template/.devcontainer/.env` (or the example shape in skill Step 4), update Step 4's "Three non-obvious things" + Security Posture surface matrix to mark it `❌ NEVER` in the `.devcontainer/.env` column with a "paste from PW manager for ad-hoc" note. Pairs with the existing service-role guidance — consistent narrative: prod-DB-admin credentials don't live on operator disks.

6. **Devcontainer rebuild wipes `~/.claude/` → loses conversation history** (Step 7) — `/workspace/.devcontainer/compose.yml` workspace service only mounts `..:/workspace:cached`. `/home/node/.claude` lives in the container's writable layer, so a rebuild discards `~/.claude/projects/<encoded-cwd>/*.jsonl` (where Claude Code stores resumable conversations). After today's Step 7 rebuild, `/resume` returned "No conversations found to resume" and the SessionStart hook logged `persist-to-disk failed: Directory not found: /home/node/.claude/projects/-workspace/<session-uuid>/...`. Fix: add a named volume in the template's `compose.yml`:

   ```yaml
   workspace:
     volumes:
       - ..:/workspace:cached
       - claude-home:/home/node/.claude
   volumes:
     claude-home:
   ```

   Survives rebuilds (only `docker compose down -v` wipes it). Every project scaffolded from the template hits this trap on their first Step 7 rebuild. Proposed devshop placement: patch `/devshop/template/.devcontainer/compose.yml`. Consider symmetric coverage for `~/.config/gh` (gh auth state) and any other in-container per-user state that's painful to re-bootstrap.

7. **Step 7 verification line in tracker is too aggressive** (this file, Step 2b note) — tracker says "Verify at Step 7: `pnpm db:start` succeeds; `curl http://host.docker.internal:54421/health` reaches kong." But Step 15 (`supabase init`) hasn't been run yet at Step 7, so `supabase/` is empty and `supabase start` exits non-zero. The kong-health check legitimately belongs at Step 15 verification, not Step 7. Step 7's verify scope is: env vars present (rebuild re-sourced `.devcontainer/.env`), `supabase-runner` container up, relay reachable on `:9000`. Proposed: when the port-rebind path generalization (#1) is codified into the skill's Step 2b, also split its verify guidance — "Step 7: env + relay + container" vs "Step 15: stack-up + kong health on the rebound port."

8. **Step 10 sed-substitution sentinel collision** (Step 10 Sub-step 1) — the template's `packages/core/src/supabase.ts` + `supabase.test.ts` use the same literal `'PROJECT_REF_PLACEHOLDER'` for two purposes: (a) the assignment that should be substituted with the real ref, and (b) the self-disable sentinel in `if (PRODUCTION_PROJECT_REF === '<sentinel>') return;`. The skill's `sed -i "s/PROJECT_REF_PLACEHOLDER/$PROJECT_REF/g"` replaces BOTH, so the self-disable check becomes always-true and the prod-URL guard is silently disabled in production (not just in scaffold-time skips). The test file has the symmetric bug: `const guardActive = PROD_REF !== 'PROJECT_REF_PLACEHOLDER'` collapses to `false` after substitution → all 4 `it.skipIf(!guardActive)(...)` tests silently skip → tests appear to pass but the guard never actually runs.
   Fix applied in home-os: use distinct sentinel literal `'UNSCAFFOLDED'` that the sed pattern never matches, restore the comparison to `=== 'UNSCAFFOLDED'` / `!== 'UNSCAFFOLDED'`, widen consts to `: string` so TS doesn't narrow-to-never the comparison.
   Proposed devshop placement: patch `/devshop/template/packages/core/src/supabase.ts` + `supabase.test.ts` to ship with the `'UNSCAFFOLDED'` sentinel + `: string` type widening pre-baked. Skill's sed lines need no change after the template fix — the substitution pattern doesn't match the sentinel anymore. **Severity: high** — silently disables the prod-URL guard in every project scaffolded via the current skill, defeating the whole point of `assertNotProdUrlInTestEnv`.

9. **Step 10 vitest `node` env lacks `WebSocket` after `@supabase/supabase-js` >= 2.105** (Step 10 Sub-step 1 verification) — `new SupabaseClient(...)` now eagerly constructs `RealtimeClient`, which calls `getWebSocketConstructor()` at construction time. Node test env has no global `WebSocket`, so `createClient()` crashes in unit tests. The template's `packages/core/vitest.config.ts` ships with the default `node` env and no setup, so the very first unit test that calls `createClient()` (the canonical "returns a Supabase client with the given config" test) fails immediately on a fresh scaffold.
   Fix applied in home-os: created `packages/core/vitest.setup.ts` with a trivial `WebSocketStub` class assigned to `globalThis.WebSocket` when undefined; wired via `setupFiles: ['./vitest.setup.ts']` in `vitest.config.ts`.
   Proposed devshop placement: ship `vitest.setup.ts` (the WebSocket stub) in `/devshop/template/packages/core/` and reference it from the template's `vitest.config.ts` `setupFiles`. **Severity: high** — every fresh scaffold's first test run fails on the first non-skipped test. The fix is template-side, one-line + one-file.

10. **Step 10 substitution misses `packages/core/vitest.config.ts` placeholder** (Step 10 Sub-step 1) — skill's sed runs on `src/supabase.ts src/supabase.test.ts` (PROJECT_REF) + `package.json src/index.ts` (PROJECT_NAME), but `vitest.config.ts` has a `// @PROJECT_NAME_PLACEHOLDER/core` comment header that stays unsubstituted. Cosmetic for tests (comment only), but it shows in `grep -r PROJECT_NAME_PLACEHOLDER` audits and confuses future readers. Proposed: extend skill Step 10's PROJECT_NAME sed list to include `vitest.config.ts`, or change the template comment to a placeholder-free phrasing.

11. **Step 12 docs-freshness gate fires before Step 18 fills the skeleton docs** — `kit/scripts/commit-hooks/check-docs-freshness-project.sh` blocks the apps/web scaffold commit because new `app/page.tsx` / `app/layout.tsx` / `middleware.ts` are user-visible-flow / module-map surfaces that require CLAUDE.md + OVERVIEW.md + ARCHITECTURE.md staging. The three docs all exist at HEAD (shipped as skeleton from the template), so the hook is active — but their content is still placeholder until Step 18 of the skill. Two consequences: (a) the operator either bypasses with `devshop.docsCoverageReason` at Step 12 and re-bypasses at every subsequent app-modifying commit until Step 18, OR (b) brings Step 18's doc-fill forward to Step 12, which is what home-os did. Brought-forward worked well: the design review gave enough source material to write coherent CLAUDE/OVERVIEW/ARCHITECTURE on first pass; no second pass needed at Step 18. Proposed: reorder the skill so Step 18 moves to ~Step 12.5 (after apps/web scaffold lands, before Sentry/PostHog), OR drop Step 18 entirely and bake "fill docs from design review (if present) or capture-as-you-go" into Step 12 itself. Lalista's pattern (CLAUDE.md filled gradually as features ship) is the alternative — but home-os benefited from front-loading because the design review existed.

12. **Step 12 build-script approval conflicts between root and create-next-app** — `create-next-app --use-pnpm` writes `apps/web/pnpm-workspace.yaml` with `ignoredBuiltDependencies: [sharp, unrs-resolver]`. The template's root `package.json` `pnpm.onlyBuiltDependencies` includes the same two packages. pnpm 10 surfaces this as conflicting policy. The clean reconciliation: drop sharp + unrs-resolver from root `onlyBuiltDependencies`, move them to root `ignoredBuiltDependencies`, delete apps/web/pnpm-workspace.yaml. Single source of truth. Proposed devshop placement: patch the template root `package.json` to ship without sharp + unrs-resolver in `onlyBuiltDependencies` (and add them to a root `ignoredBuiltDependencies`); add a Step 12 sub-step note about deleting apps/web/pnpm-workspace.yaml. Severity: low — discovery cost is one search + reconcile, but documenting prevents the next operator from re-experiencing it.

13. **Step 12's `pnpm create next-app` writes files even when the working tree isn't clean and there's no easy resume path** — the apps/web/ directory was partially created by an interrupted create-next-app run (before the user opted to check the design review). On second invocation, the tool refused with "directory contains files that could conflict." The partial scaffold is workable (everything I needed was there), but if it weren't, the operator would have to `rm -rf apps/web/` and rerun. Proposed Step 12 sub-step note: "If `pnpm create next-app` was interrupted, inspect `apps/web/` — if the package.json, app/, and tsconfig exist, proceed with customization; if anything's missing, `rm -rf apps/web/` and rerun." Low severity — interruption is rare — but the symptom is opaque enough to warrant a note.

14. **Step 6 tracker mark `[x]` without verifying the actual file state — multiple downstream steps silently failed** — the home-os tracker had `[x]` on Step 6 ("supabase ref + sentry ingest + posthog region"), but `.devcontainer/init-firewall.sh` showed none of those entries actually added (only the static template list ending at `ntfy.sh`). Discovered when Step 15 `supabase link` failed with `EHOSTUNREACH` to `api.supabase.com` and Step 14 chromium install failed similarly on `playwright.download.prss.microsoft.com`. Either the operator marked the step done prematurely OR the additions were rolled back somehow (unlikely — `.devcontainer/` is a host bind mount, not lost on rebuild). Proposed devshop placement: Step 6 should end with a verification command — `grep -E "supabase\\.co|ingest\\.sentry|posthog\\.com" .devcontainer/init-firewall.sh` — that the operator runs before marking [x]. Same pattern would catch similar slips at other tracker checkpoints. Severity: high — the silent failure mode is "Steps 14+ randomly EHOSTUNREACH when project-specific external services are dialed." Without inspection, the operator might attribute the failures to network flakiness, not missing firewall entries.

15. **Claude can't edit `.devcontainer/*` files; firewall additions + compose.yml volume-mount fixes are operator-only** — `.claude/settings.json` has `Edit(/workspace/.devcontainer/*)` in the deny list (good security posture: prevents accidental modification of attack-surface-critical files). But it means the `.claude` volume mount fix from generalization #6 AND the firewall additions from generalization #14 are BOTH operator-only edits. Two consequences: (a) the rebuild that fixes both is operator-driven, which becomes a natural batching moment — fix everything `.devcontainer/`-shaped at once, rebuild once; (b) skills that depend on `.devcontainer/*` (Step 6, Step 7, Step 21) must be more explicit about the operator-only constraint so Claude doesn't try-and-fail then mark partial-progress. Proposed: skill should explicitly say "STOP and ask the operator to apply the following diff to `.devcontainer/init-firewall.sh`" rather than implying Claude can patch.

16. **Steps blocked on firewall additions form a natural [HUMAN] batching moment** — looking at the deferred list in PR #8 (Step 14 binary install, Step 15 `supabase link`, Step 17b auth hardening) all share the same root cause: missing firewall entries for project-specific external services. A single operator-side action (edit init-firewall.sh + rebuild) unblocks ALL three. The skill currently spreads the discovery across Steps 14/15/17b individually. Proposed: Step 6 should end with a "smoke test the additions" sub-step that hits the actual endpoints once added, so Step 6 either fully unblocks downstream or surfaces the gap immediately rather than at Step 14 / 15 / 17b. Pairs with generalization #14.

17. **CRITICAL: `.devcontainer/init-firewall.sh` is locked-from-template — Step 6 edits silently revert on every container start** — `/devshop/kit/scripts/init-devshop.sh` runs as root on every container start (postStartCommand) and, for every path marked `[locked]` in `/devshop/kit/manifest.txt`, executes `install -D -m 644 -o root -g root /devshop/template/<path> /workspace/<path>`. `.devcontainer/init-firewall.sh` is on that locked list. So when the operator follows the skill's Step 6 ("Add project-specific domains to `.devcontainer/init-firewall.sh`"), their edits:
    - (a) Get captured into the Docker image at next rebuild (via the Dockerfile's `COPY init-firewall.sh /usr/local/bin/`),
    - (b) But get reverted in the workspace copy immediately after by init-devshop.sh,
    - (c) Leaving the executed runtime at `/usr/local/bin/init-firewall.sh` with the user's edits baked-in, while the auditable workspace source-of-truth shows template defaults.

    Evidence from home-os session (2026-05-13):
    - `diff /workspace/.devcontainer/init-firewall.sh /usr/local/bin/init-firewall.sh` shows the workspace copy reverted to 54321/54322 references, while `/usr/local/bin/` has the +100 port offsets AND three Step 6 entries (two of them MALFORMED — a Sentry DSN-shaped entry that can't resolve as a hostname, and the literal `<us-or-eu>.i.posthog.com` placeholder).
    - The operator can't iterate on fixing the malformed entries — every edit gets wiped on next start.
    - Pre-commit doesn't catch the drift because the workspace copy looks "clean" (matches template).

    **Severity: critical.** Three downstream Steps (14 chromium install, 15 `supabase link`, 17b Supabase auth hardening) silently fail with `EHOSTUNREACH` because the malformed entries don't resolve. The operator sees firewall-blocked symptoms but can't debug because the workspace source-of-truth doesn't reflect what's running.

    Proposed fix paths (pick one, devshop-side):
    - **Path A (smallest change):** Remove `.devcontainer/init-firewall.sh [locked]` from `kit/manifest.txt`. Make it `[sync]`-like (preserve operator edits across container starts). Other [locked] files (devcontainer.json, Dockerfile, etc.) stay locked. Trade-off: operator can drift from template, but template updates require explicit migration anyway. This is the right shape — Step 6 explicitly invites operator additions.
    - **Path B (overlay mechanism):** Introduce `.devcontainer/init-firewall.local.sh` (project-only, not in manifest, not [locked]). init-firewall.sh's last line sources `.local.sh` if it exists. Operators add project-specific domains to the overlay, leaving init-firewall.sh untouched and template-mirrored. Cleaner separation; one extra file per project; needs Dockerfile COPY for the .local.sh into /usr/local/bin/ too.
    - **Path C (template signpost):** Move project-specific extras to a different (non-locked) file the template references. Same as Path B but in a different shape.
    - **Skill update:** until devshop is fixed, `/ak-new-project § Step 6` MUST say "edits to `.devcontainer/init-firewall.sh` will be reverted on next container start; this step is currently a no-op. Tracked as generalization #17 — defer firewall additions until devshop ships Path A/B/C." That preserves operator sanity.

    Symptoms that surface this elsewhere:
    - Step 14 chromium download EHOSTUNREACH (CDN IP rotation, ipset stale)
    - Step 15 `supabase link` "no route to host" to api.supabase.com (not in template's firewall)
    - Step 17b auth hardening 4xx because api.supabase.com unreachable
    - Even after explicit Step 6 work, project-specific services remain blocked

    Cross-cuts generalizations #14 (tracker [x] without verification), #15 (Claude can't edit .devcontainer/\*), #16 (batched [HUMAN] moment) — all three were downstream symptoms of #17.

18. [x] **[HUMAN]** Create accounts (Vercel, Sentry, PostHog, Supabase) — MFA enabled, Vercel repo NOT yet imported (Step 12)
19. [x] **[HUMAN]** Fill .devcontainer/.env (sans SUPABASE_DB_PASSWORD per generalization #5 + ANTHROPIC_API_KEY_QA — no edge functions call Claude yet)
20. [x] **[HUMAN]** Add GitHub Secrets + Variables (5 Variables + 5 Secrets; Anthropic skipped; PRODUCTION_URL deferred to Step 13)
21. [x] **[HUMAN]** Add firewall domains (supabase ref + sentry ingest + posthog region; vercel domain deferred to Step 13)
22. [x] **[HUMAN]** Rebuild devcontainer (rebuild took effect; env vars all set; relay reachable on :9000; kong-health verify deferred to Step 15 per generalization #7 — `supabase/` empty until `supabase init`. Conversation history wiped → generalization #6.)
        7b. [x] **[HUMAN]** Set up Claude Code notifications — already set up for a prior project; NTFY_URL already in .devcontainer/.env (len=80)
23. [x] Disable turbo telemetry
24. [x] Install gstack (v0.15.1.0; binaries built; Playwright Chromium pending Step 14)
25. [x] Scaffold packages/core (PROJECT_REF=kxhxbbljgunpjfhivccb, PROJECT_NAME=home-os; 6/6 tests pass; models/index.ts placeholder added; Zod schemas/ scaffold present; +3 generalizations #8/#9/#10 — sed sentinel collision, WebSocket vitest stub, vitest.config.ts placeholder miss)
26. [x] Scaffold packages/ui (@home-os/ui, React 19 peer/dev, tokens.ts + Button.tsx proof-of-concept; refactored tokens to the design-review's design system after reading .gstack/design-review-home-os-2026-05-02.md; 20/20 tests, typecheck clean)
27. [x] Scaffold apps/web (Next 16.2.6 + React 19; @supabase/ssr SSR boilerplate Patterns 1/2/3; Tailwind v4 @theme mirroring packages/ui tokens; Inter font preload; security headers + CSP; PWA manifest + placeholder icon.svg; CLAUDE.md/OVERVIEW.md/ARCHITECTURE.md filled from the design review; 4/4 tests, typecheck clean. **Sentry + PostHog wiring deferred to a follow-up commit** — both involve env-dependent provider scaffolding that's cleaner to land alongside Step 13's `vercel env add` piping. **Vercel project import** is [HUMAN] and stays deferred to Step 13.)
28. [x] Scaffold packages/ui (@home-os/ui, React 19 peer/dev, tokens.ts + Button.tsx proof-of-concept, 5/5 tests, typecheck clean)
29. [x] Scaffold apps/web (see 27 — already done; tracker had a duplicate line)
30. [x] Add Vercel CLI + link + pipe env vars (2026-05-13 session: `vercel link --scope homeos --project home-os` succeeded; 14 env entries piped — NEXT*PUBLIC*\* × 3 envs + SENTRY_AUTH_TOKEN × 2 envs; `apps/web/.env.local` generated. DEFERRED [HUMAN]: GitHub Login Connection at vercel.com/account/login-connections (initial link returned "Failed to link meirmsn/home-os"); PRODUCTION_URL GH Variable + .devcontainer/.env bare-hostname paste — depends on first successful prod deploy. Sentry + PostHog wiring landed in same commit `1f3224e`.)
31. [x] Install Playwright (chromium 148.0.7778.96 + FFmpeg + headless-shell downloaded after firewall-extras overlay merged. Smoke test passed without `sudo apt-get install-deps` — devcontainer Dockerfile already provides OS libs. Generalization: skill's `sudo npx playwright install-deps chromium` line unnecessary here.)
32. [x] Supabase init + link (2026-05-13: `supabase link --project-ref kxhxbbljgunpjfhivccb` succeeded; `supabase/.temp/project-ref` written; covered by `supabase/.gitignore`. `api.supabase.com` reachable via firewall-extras.)
33. [x] Create METRICS.md (template ships skeleton; populated by `/ak-spec` on first feature)
34. [x] Run /setup-deploy (2026-05-13: Vercel platform detection done; CLAUDE.md § Deploy Configuration populated with prj_4dMkbHkxYohqABcKt1SwaprZv3JM, inferred prod URL https://home-os.vercel.app, squash-merge, auto-deploy. Vercel dashboard follow-ups flagged: framework preset Other→Next.js, root .→apps/web, install cmd→pnpm, GitHub Login Connection.)
        17b. [x] Harden Supabase auth defaults (2026-05-13: password_min_length 6→8, site_url=https://home-os.vercel.app, uri_allow_list=`{prod}/**,http://localhost:3000/**`. CAPTCHA + preview wildcard deferred per operator choice; BUILD-LOG.md prepended with two visible [TODO] headers.)
35. [x] Create project CLAUDE.md (done as part of Step 12 — docs-freshness hook forced it forward; CLAUDE.md, OVERVIEW.md, ARCHITECTURE.md filled from the design review)
36. [x] Enable doc enforcement hooks (`eslint-plugin-jsdoc` already configured in root `eslint.config.mjs` from template)
37. [x] Update .gitleaks.toml allowlist (added value-pattern regexes for `sb_publishable_*`, JWT, `phc_*`, Sentry DSN — commit `fbc4daf`)
38. [x] **[HUMAN]** Lock security-critical files — all `.devcontainer/*` files (always-present subset + compose-isolation siblings) auto-locked on container start by `init-devshop.sh`'s manifest loop. The compose-isolation manifest gap was closed 2026-05-20 (`compose-isolation-manifest-locked`): manifest extended to cover `compose.yml`, `init-host-env.sh`, `supabase-runner/Dockerfile`, `supabase-runner/cmd-relay.mjs`; lock loop now derives mode per-file from template (preserves 755 on `init-host-env.sh` + `cmd-relay.mjs`). Operator-driven `.env` chown remains the only manual piece of Step 21.
39. [x] Create keepalive.yml (template ships at `.github/workflows/keepalive.yml`; reads `vars.PRODUCTION_URL`, set in Step 13)
40. [ ] **[HUMAN]** Set up service quota alerts (Vercel + Sentry + PostHog dashboards)
41. [ ] **[HUMAN]** Enable branch protection — Claude PAT lacks `Administration:write`; `gh api .../branches/main/protection` returns 403. Operator: GitHub UI or admin-scoped PAT, per Step 24 block.
42. [x] Run /cso baseline security audit (2026-05-13: 6 findings, 0 CRITICAL. HIGH: branch protection not enabled. MEDIUM: 4 compose-isolation files still node:node (Step 21 remaining); postcss <8.5.10 transitive XSS CVE (GHSA-qx2v-qp2m-jg93) via next@16. LOW: Vercel project misconfig, hCaptcha deferred, gstack 0.15→1.33 drift. Report at `.gstack/security-reports/2026-05-13T125007Z.json` — gitignored.)

## 2026-05-13 session — devshop generalizations to surface

Surfaced during this session's resume + completion of Steps 13/14/15/17/17b/25:

19. **Vercel CLI 50.x non-interactive preview env-add requires `""` 3rd positional** — `pnpm exec vercel env add NAME preview --value X --yes --token ... --scope ...` returns `git_branch_required` error in agent / non-interactive mode even though the docs say "omit branch for all preview branches". The hint command in the JSON `next[]` array is the same command that just failed. Workaround: pass `""` (empty string) as the third positional: `vercel env add NAME preview "" --value X --yes --token ... --scope ...`. **Severity: low** but breaks every fresh scaffold's Step 13 loop. Proposed: update `/devshop/.claude/skills/ak-new-project/SKILL.md` Step 13's example loop to include the `""` arg for the preview iteration.

20. **Skill instruction echoes `--token` in CLI error output** — `vercel link --token $VERCEL_TOKEN` echoes the resolved token value in JSON-formatted error responses (e.g. when scope is ambiguous). The token reaches stdout, then conversation log. The skill should either (a) pipe `vercel ... 2>&1 | sed 's/vcp_[A-Za-z0-9]*/vcp_***/g'` in every example, or (b) `export VERCEL_TOKEN` so the CLI reads it from env without the explicit arg. **Severity: medium for log-hygiene** — VERCEL_TOKEN blast radius is "deploys to any of your Vercel projects." Proposed: skill's Step 13 example loop uses `export VERCEL_TOKEN=...` once at the top instead of passing `--token` on every line.

21. **Pre-commit clean-tree guard forbids stashes too, not just untracked/unstaged files** — when splitting commits via `git stash push <subset>` + `git commit` + `git stash pop`, the second commit step fails with `Stashed changes on current branch — address them before committing`. The hook treats stashes as "uncommitted work". Workaround: combine the logical groups into one atomic commit with sectioned message, OR use `git -c devshop.dirtyTreeReason="..." commit`. **Severity: low** — friction more than correctness — but the skill should mention that "one logical change per commit" doesn't pair with the clean-tree guard when split-via-stash. Proposed: `/devshop/CLAUDE.md § Two repos, two commit flows` could note that atomic commits MUST be one transition each; stash-then-commit will trip the guard.

22. **`/ak-new-project` Step 14 `sudo apt-get install-deps chromium` is unnecessary** — the devcontainer template's Dockerfile already installs the chromium runtime deps. After `pnpm exec playwright install chromium`, a smoke test (`chromium.launch()` against `about:blank`) succeeds without `sudo`. Generalization: skill should change Step 14 from "run install-deps" to "verify chromium.launch succeeds; if it fails, run install-deps".

23. **`@/` path alias not wired in vitest by default** — `apps/web/vitest.config.ts` (scaffolded by Step 12) doesn't read `tsconfig.json`'s `paths` field, so any test that imports from `@/lib/...` fails with "Failed to load url". Fix: add `resolve.alias: { '@': path.resolve(__dirname, './') }` to vitest.config.ts. Applied locally in home-os during Step 12.5; the template's apps/web scaffold should ship the alias pre-baked. **Severity: medium** — every project's first non-trivial test import will hit this.

24. **Next 16 `middleware.ts` → `proxy.ts` deprecation warning** — `pnpm build` in apps/web emits `⚠ The "middleware" file convention is deprecated. Please use "proxy" instead.` (https://nextjs.org/docs/messages/middleware-to-proxy). The Supabase SSR boilerplate guide at `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 1` (and the template's `apps/web/middleware.ts` scaffold) still uses the deprecated name. **Severity: low** today (warning only, still functional in Next 16), but will harden into an error in Next 17. Proposed: track in `kit/ROADMAP.md § v1` and update the boilerplate guide + template when Next 17 ships, OR proactively rename now.

25. **Vercel project import via `vercel link --yes --project` requires GitHub Login Connection** — first `vercel link` returned `Error: Failed to link meirmsn/home-os. You need to add a Login Connection to your GitHub account first.` even though the GH App was installed. The CLI did write `.vercel/project.json` successfully (so env-piping works), but auto-deploy on push won't fire until the operator establishes the Login Connection. Proposed: skill Step 3 (Vercel account creation) should include a sub-bullet for `vercel.com/account/login-connections` — "add GitHub Login Connection during account setup, before `vercel link` runs at Step 13."

26. **`init-devshop.sh` covers some Step 21 files but not the compose-isolation subset** — [SHIPPED 2026-05-20 as `compose-isolation-manifest-locked`] manifest extended to cover the four compose-isolation files; `init-devshop.sh`'s lock loop derives mode per-file from the template source so 755 executables (`init-host-env.sh`, `cmd-relay.mjs`) keep their exec bit. Step 21 simplified to a one-line `.env` chown + a `find` verification.

27. **`/setup-deploy` skill has lots of one-time prompts that delay actual deploy config** — preamble fires: gstack-upgrade check, Boil-the-Lake intro, telemetry, proactive, routing rules. Each is an AskUserQuestion. Five interruptions before the skill does its job. For `/ak-new-project` use, defaults (telemetry off, proactive true, routing decline, lake intro silently marked seen) are reasonable enough to set programmatically. Proposed: `/ak-new-project § Step 17` could prefix `/setup-deploy` invocation with a `gstack-config` batch that pre-answers the one-time prompts, OR add a `--non-interactive-skill-setup` flag to gstack's preamble.

28. **gstack binary path `~/.claude/skills/gstack/bin/...` doesn't match project-local install at `.claude/skills/gstack/bin/...`** — gstack-init under `/ak-new-project § Step 9` clones to `.claude/skills/gstack/` (project-local), but every gstack SKILL.md uses `~/.claude/skills/gstack/bin/gstack-config` etc. — those paths resolve to `/home/node/.claude/skills/gstack/bin/`, which doesn't exist. Workaround used this session: `GSTACK=/workspace/.claude/skills/gstack/bin` then `$GSTACK/gstack-config set ...`. **Severity: low** for daily use (the skills still work because gstack-update-check returns nothing without binaries) but breaks when one-time prompts try to write config. Proposed: either symlink `~/.claude/skills/gstack/ → /workspace/.claude/skills/gstack/` during Step 9, OR install gstack to `~/.claude/skills/` instead of `.claude/skills/`.

29. **Devshop main is missing 4 fixes already applied to home-os** — see § "Devshop sync gap inventory" in this session's surfacing. Critical: gen #8 (sed sentinel collision silently disables prod-URL guard) + gen #9 (vitest WebSocket stub) — both template-side, both block every new scaffold. #17 + #18 are uncommitted/unmerged on `feat/firewall-extras-overlay`; need `/ak-merge-devshop` to land them.
