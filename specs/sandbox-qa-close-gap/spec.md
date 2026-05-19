<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: sandbox-qa-close-gap -->
<!-- date: 2026-05-19 -->

# Spec: sandbox-qa-close-gap (devshop change — ships via /ak-merge-devshop)

**Sources:**

- `PLAN.md § Planned` row `sandbox-qa-close-gap` — priority 15.0, XL Risk × XL Impact ÷ M Cost
- `kit/ROADMAP.md § Close the sandbox /qa gap — Playwright in workspace + firewall fix-up` — original three-deliverable framing (A/B/C). Phase 0 audit found the entry significantly stale; this spec rescopes to the actual remaining gap.
- Current state of `template/.devcontainer/Dockerfile` (lines 24-60 already apt-install Chromium; commit `1df36b0` 2026-04-23) and `template/.devcontainer/devcontainer.json` (line 76-77 sets `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium`)
- Current state of `template/.devcontainer/init-firewall.sh` (lines 115-116 already allowlist `fonts.googleapis.com` + `fonts.gstatic.com`; lines 230-237 hardcode Supabase 54321/54322 — this is the remaining gap)
- Current state of `/devshop/.claude/skills/ak-pre-ship/SKILL.md` (preflight at lines 117-205 correctly checks Chromium presence and emits `blocked (Chromium not available — run fix)` only when missing — outcome logic is already correct; prose elsewhere can drift)
- Prior devshop spec `specs/v0-triage-shipped-entries-and-plan-sync/spec.md` — style + structure reference

The devshop is the abra-kadabra repo (`/devshop/`). It ships via `/ak-merge-devshop` (audit → squash on feature branch → fast-forward main), not via `/ak-build`'s Phase 4-7 (PR + CI). Phase 0-3 of `/ak-build` still apply; Phase 4 routes to `/ak-merge-devshop` instead.

Feature one-liner: close the small remaining gap from the "sandbox /qa close" ROADMAP entry — add `ffmpeg` to the workspace Dockerfile, make Supabase port ACCEPT rules env-aware so rebound-port projects work, and bring the `/ak-pre-ship` + `/ak-build` prose in line with the actual (already-correct) outcome logic.

---

## Product update

Both blurbs as approved at Phase 0.2. Single source-of-truth — surfaces downstream via the devshop merge / changelog flow (not a project /ak-go-live).

### Headline (user-facing)

Quality gates that need a running app plus video capture now work from the workspace, and projects that move Supabase off the default ports stop hitting silent network failures.

### Detail (team-facing)

Adds `ffmpeg` to the workspace Dockerfile (Playwright's `video: 'retain-on-failure'` was silently producing zero-byte recordings without it) and makes `init-firewall.sh`'s Supabase port ACCEPT rules read `SUPABASE_API_PORT` / `SUPABASE_DB_PORT` from `.devcontainer/.env` (defaulting to 54321/54322). The `/ak-pre-ship` Gate 3/8/9/10 preflight prose and `/ak-build` Phase 5.9 hero-shot prose stop describing `blocked (n/a per scope: sandbox)` as the expected outcome — workspace has Playwright + dev server reachable, gates run for real. The ROADMAP entry's full Playwright tarball pinning, WebKit support, and home-os verification step are explicit non-scope (Chromium-via-apt already covers the failure modes those would address).

---

## Decisions (resolved at spec time)

Six `/ak-spec`-time decisions resolved at Phase 0 against the current state of the template + skills.

### D1: Rescope vs. ROADMAP entry's full three-deliverable scope

**Decision:** ship the focused remainder, not the full ROADMAP A/B/C. Concrete diff:

- ROADMAP A "workspace Dockerfile — Playwright + ffmpeg pre-installed": already shipped via apt-Chromium (2026-04-23 `1df36b0`) + `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` env. **This PR**: add `ffmpeg`. **Punt**: pinned Playwright tarball download + checksums (apt-Chromium covers every gate that fires).
- ROADMAP B "firewall — Google Fonts + rebound-port allowance": fonts already shipped (lines 115-116 of `init-firewall.sh`). **This PR**: env-aware Supabase ports (the unshipped half).
- ROADMAP C "Gates 3/8/9/10 + Phase 5.9 contract revision": preflight logic is already correct (emits `blocked` only when Chromium IS missing). **This PR**: prose revision in `/ak-pre-ship` + `/ak-build` + ROADMAP so the documented expectation matches reality.

**Rationale:** The ROADMAP entry was written 2026-05-18 against home-os PR #28's operator experience; the prior fixes that closed two-thirds of the scope shipped weeks earlier (2026-04-23 / 2026-05-14) but the entry was never updated. Per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`, the surviving entry should describe only the actual remaining gap.

### D2: ffmpeg via apt, no checksum entry

**Decision:** `apt-get install -y ffmpeg` in the existing apt block (alongside `chromium`, `libnspr4`, etc., lines 43-60 of the Dockerfile). Do NOT add an entry to `checksums.sha256`.

**Rationale:** ffmpeg is in Debian stable's main repo; apt repo signing (already trusted via `signed-by=/usr/share/keyrings/...`) handles integrity verification. The `checksums.sha256` recipe is reserved for binaries fetched outside apt (git-delta, supabase-cli, dcg, gitleaks) where there's no repo signature.

### D3: env-var fallback shape

**Decision:** read `SUPABASE_API_PORT` / `SUPABASE_DB_PORT` from environment in `init-firewall.sh`, with shell-default `${VAR:-54321}` / `${VAR:-54322}`. Source: the variables are set via compose's `env_file: .env` directive (in `compose.yml`), so they're already in the script's environment when `postStartCommand: sudo /usr/local/bin/init-firewall.sh` fires. No explicit `set -a; . .env; set +a` needed.

**Rationale:** `${VAR:-default}` is portable bash, idiomatic for env-driven scripts, and degrades cleanly when projects never rebind (the default matches upstream Supabase). The comment block at lines 213-229 of `init-firewall.sh` will be updated to explain the rebind escape hatch.

### D4: Skill-prose revision scope

**Decision:** revise prose only in `/ak-pre-ship` SKILL.md (Gates 3/8/9/10 preflight section + any literal `blocked (n/a per scope: sandbox)` strings) and `/ak-build` SKILL.md (Phase 5.9 hero-shot section). Do NOT change the actual outcome logic — preflight already emits `blocked` only when Chromium IS missing, not unconditionally.

**Rationale:** The framing decay was the operator-side cost: home-os PRs #27/#28 paid the manual-capture tax because audit comments described sandbox-block as expected. The skill's outcome logic is fine; the gap is the documentation/contract describing what operators should EXPECT to see.

### D5: home-os verification is out of scope

**Decision:** do not run `/ak-pre-ship` on home-os as part of this PR. Add a note to the BUILD-LOG entry instructing the next home-os `/ak-build` invocation to confirm Gates 3/8/9/10 surface real outcomes post-rebuild.

**Rationale:** Devshop PRs ship via `/ak-merge-devshop`, which has no cross-project validation step. Cross-project verification is structurally an operator workflow (run home-os's container rebuild, then exercise its pre-ship pipeline). Bundling it into this devshop PR would block the merge on home-os's session being available.

### D6: WebKit / Firefox support is out of scope

**Decision:** do not add WebKit or Firefox apt packages or Playwright tarball downloads in this PR. Apt only ships Chromium for the workspace; cross-browser tests are not currently a devshop need.

**Rationale:** No current project (lalista, home-os) uses cross-browser Playwright tests. Adding WebKit would require Playwright's CDN tarball, which has exactly the IP-rotation problem that apt-Chromium exists to avoid. Defer to a future ROADMAP entry if a project actually needs it.

---

<!-- Phase 1 expansion inlined (Phase-1 subagent crashed mid-call; expansion
     completed by /ak-build orchestrator following the same outline). -->

## In scope

- ~~**D1 / D2 — Dockerfile**: add `ffmpeg` to the existing apt-install block~~ — **DROPPED post-Phase-2 per operator review**. No current devshop or template consumer wires Playwright's `video:` config option (grep across `.claude/skills/` + `template/` returned zero hits). Shipping ffmpeg without a consumer is YAGNI — the binary adds image bloat for tooling capability nobody currently uses. The full architectural context (apt-Chromium foundation, Playwright config wiring, WebM→GIF for PR embedding) is preserved in a new `kit/ROADMAP.md § v+ § Playwright video recording` entry so the next implementer doesn't redo the research. Ship ffmpeg in the same PR as the first playwright.config.ts video-recording wiring, not before.
- **D1 / D3 — init-firewall.sh**: replace hardcoded `54321` / `54322` references in the HOST_DOCKER_INTERNAL ACCEPT-rule block (`template/.devcontainer/init-firewall.sh` lines 230-237) with `${SUPABASE_API_PORT:-54321}` / `${SUPABASE_DB_PORT:-54322}`. Update the comment block at lines 213-229 to explain the rebind escape hatch and name the canonical source (`.devcontainer/.env`).
- **D4 — Skill prose revision**: revise `/ak-pre-ship` SKILL.md (Gates 3/8/9/10 preflight section + any literal `blocked (n/a per scope: sandbox)` strings) and `/ak-build` SKILL.md (Phase 5.9 hero-shot section) so the documented expectation matches the actual outcome logic. Workspace has Playwright + dev server reachable; gates run for real; sandbox-block is reserved for genuine tooling-broken cases.
- **D1 — Bookkeeping**: close `PLAN.md` row `sandbox-qa-close-gap`; rewrite `kit/ROADMAP.md § Close the sandbox /qa gap` to either delete (entry is shipped) or collapse to a brief retrospective; drop `⛔ sandbox-qa-close-gap` from `fault-injected-qa-gate` PLAN row's Deps cell.
- **Tests**: new `kit/tests/init-firewall-port-allowance.bats` exercises the env-var resolution path. ffmpeg add has no committed test (the install is verified at container build; `which ffmpeg` post-rebuild is the smoke check).

## Screens

n/a — devshop change, no UI.

## Data model changes

n/a — no DB, no migrations, no schema work.

## API contracts

n/a — no APIs touched.

## Offline behavior

n/a — devshop has no runtime user surface.

## Metrics

n/a — devshop has no `METRICS.md`. The change has no user-observable analytics; pre-ship gate evidence is recorded in `specs/<feature>/review.md` per the existing audit-trail convention.

## Files to create/modify

| File | Change | Locked? | Notes |
|---|---|---|---|
| `template/.devcontainer/init-firewall.sh` | edit | yes (root:root 644) | replace hardcoded ports + revise comment block. Locked-file recipe: write to `/tmp/staging/init-firewall.sh.new`, then `sudo install -m 644 -o root -g root /tmp/staging/init-firewall.sh.new <worktree-path>` to land the file at root:root 644 in the worktree (git then sees it as a normal change). |
| `kit/tests/init-firewall-port-allowance.bats` | new | no (node:node) | bats test asserting default-on-unset / override-on-set behavior. Extracts the env-var resolution snippet via `grep`-based fixture rather than invoking iptables, so the test never needs sudo and never touches host state. |
| `.claude/skills/ak-pre-ship/SKILL.md` | edit | no (symlinked, devshop-owned) | prose revision per D4. Outcome logic untouched. |
| `.claude/skills/ak-build/SKILL.md` | edit | no | prose revision in Phase 5.9 section per D4. |
| `kit/ROADMAP.md` | edit | no | close the `Close the sandbox /qa gap` section per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`: delete the entry. Also delete the historical `init-firewall.sh env-aware Supabase port allowance` placeholder (absorbed-into pointer, no longer needed). |
| `PLAN.md` | edit | no | delete the `sandbox-qa-close-gap` row from `## Planned`; drop `⛔ sandbox-qa-close-gap` from `fault-injected-qa-gate` row's Deps cell. |

## Tests

**New: `kit/tests/init-firewall-port-allowance.bats`**

Tests the env-var resolution snippet in isolation. Pure-bash test — does NOT invoke `iptables` / `ipset` / `sudo` (those would need root + would modify host state; the bats test must be safe to run from a node-user shell on CI or locally).

Assertions:

1. **Default-on-unset**: `unset SUPABASE_API_PORT SUPABASE_DB_PORT; api_port=${SUPABASE_API_PORT:-54321}; db_port=${SUPABASE_DB_PORT:-54322}; [ "$api_port" = "54321" ] && [ "$db_port" = "54322" ]`.
2. **Override-on-set**: `SUPABASE_API_PORT=54421 SUPABASE_DB_PORT=54422; api_port=${SUPABASE_API_PORT:-54321}; [ "$api_port" = "54421" ] && [ "$db_port" = "54422" ]`.
3. **Partial-override**: only `SUPABASE_API_PORT=54421` set; `db_port` falls back to `54322` (the two vars are independent).
4. **Numeric-validation**: the snippet's downstream `iptables --dport` call rejects non-numeric values with a clear error. Assert that `init-firewall.sh` validates each port is `^[0-9]+$` before passing to iptables; non-numeric → script exits non-zero with a named error.

Strategy: bats source-includes a *snippet fixture* (`fixtures/firewall-port-resolution.sh` extracted from the real script via `awk` at test setup time, or hand-mirrored if `awk` extraction is brittle) and exercises the snippet directly. The "extract from real script" path is preferred over "hand-mirror" because hand-mirror drifts.

**No new test for ffmpeg add.** It's apt-installed; the build either succeeds (ffmpeg available) or fails the container build entirely. A `which ffmpeg` smoke check at first-rebuild is the verification; recording it in a unit test adds nothing.

## Dependencies

- **External**: none (ffmpeg is in Debian stable apt; bash `${VAR:-default}` is POSIX).
- **Internal task ordering**: Task 4 (prose revision) depends on Tasks 1-2 landing first — the new prose claims gates run for real, which is only true once the firewall + Dockerfile changes ship. Task 5 (close PLAN/ROADMAP) can run anywhere but is grouped at the end so the close-out commit is atomic.

## Task order

1. **Add ffmpeg to template Dockerfile** (~10 min). Affects: `template/.devcontainer/Dockerfile`. Locked file — `/tmp + sudo install` recipe.
2. **Env-aware Supabase ports in init-firewall.sh** (~20 min). Affects: `template/.devcontainer/init-firewall.sh`. Locked file — same recipe. Includes comment-block revision at lines 213-229.
3. **Bats test for env-aware port logic** (~25 min). Affects: `kit/tests/init-firewall-port-allowance.bats` (new), plus possibly `kit/tests/fixtures/` for the extracted snippet fixture. Verify it runs locally with `bats kit/tests/init-firewall-port-allowance.bats`.
4. **Revise /ak-pre-ship + /ak-build prose** (~25 min). Affects: `.claude/skills/ak-pre-ship/SKILL.md`, `.claude/skills/ak-build/SKILL.md`. Grep for stale `blocked (n/a per scope: sandbox)` framing + Phase 5.9 prose claiming workspace can't run.
5. **Close PLAN row + update ROADMAP entry + sweep cross-refs** (~15 min). Affects: `PLAN.md`, `kit/ROADMAP.md`. Per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`: delete entries, rewrite any "Without this, X fails" framing in skills/guides to imperative present tense, sweep cross-refs via `grep -rE "sandbox-qa-close-gap" /devshop/ kit/docs/`. Update `fault-injected-qa-gate`'s Deps cell.

Total estimate: ~95 min wallclock, matching the M-cost row in PLAN.md (4-6 hr ROADMAP estimate compressed by the upfront rescope finding that two-thirds of the scope already shipped).

## Gotchas

- **Locked-file recipe**. `template/.devcontainer/Dockerfile` and `init-firewall.sh` are root:root 644 and denied for Edit/Write per `.claude/settings.json` deny list (`Edit(/devshop/template/**)`, `Write(/devshop/template/**)`). Use:
  ```bash
  cp /devshop/template/.devcontainer/Dockerfile /tmp/staging/Dockerfile.new
  # edit /tmp/staging/Dockerfile.new
  sudo install -m 644 -o root -g root /tmp/staging/Dockerfile.new /devshop/template/.devcontainer/Dockerfile
  ```
  The `-o root -g root -m 644` flags are required to match the existing layout — without them, the file ownership flips to node:node, breaking init-devshop.sh's locked-file refresh invariant.

- **Bats test must not invoke iptables/sudo**. The bats test exercises the env-var resolution path only. If the test sources a fixture extracted from the real script, the fixture must stop short of any `iptables -A OUTPUT ...` call. Extract just the `${SUPABASE_API_PORT:-54321}` + numeric-validation lines. Test runs from node-user shell on developer machines and on whatever CI configuration runs `kit/tests/*.bats`.

- **Numeric validation matters**. If a project's `.env` has `SUPABASE_API_PORT=abc` (typo), `iptables --dport abc` errors out with a non-obvious "invalid argument" message and `init-firewall.sh` fails closed (`set -e`). The script already has `set -euo pipefail` at line 2, so the failure path is clean — but the error message is opaque. Add an explicit numeric-regex check that fails with a clear message naming the bad var.

- **Comment-block revision shape**. The existing comment block at `init-firewall.sh` lines 213-229 explains the IPv4-vs-IPv6 `getent ahostsv4` rationale. Don't delete it. The revision adds *additional* lines naming `.devcontainer/.env` as the source of truth for `SUPABASE_API_PORT` / `SUPABASE_DB_PORT` overrides; the existing IPv4 explanation stays.

- **Cross-reference unwinding** (per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`). Search `/devshop/` and `kit/docs/` for any string mentioning the dropped entries. Likely hits: `kit/docs/guide/ops.md` (sandbox firewall recipe section), older ROADMAP cross-refs, `.claude/skills/ak-pre-ship/SKILL.md` prose claiming sandbox-block is expected. Each hit gets rewritten in imperative present tense (per the convention) or deleted.

- **Devshop pre-commit checks**. Each Dockerfile/init-firewall.sh change will fire `check-tests-coverage-devshop.sh`. The test (Task 3) is the coverage answer; sequence the commits so the test ships alongside the env-var change (Task 2 + 3 in one commit, or Task 2 commit ships with `-c devshop.testsExempt="..."` reason if separated).

## Acceptance / rollout / rollback

**Acceptance** (devshop side, after `/ak-merge-devshop`):

1. `grep ffmpeg /devshop/template/.devcontainer/Dockerfile` returns a line in the apt-install block.
2. `grep 'SUPABASE_API_PORT' /devshop/template/.devcontainer/init-firewall.sh` returns the env-var-driven `${SUPABASE_API_PORT:-54321}` line.
3. `bats /devshop/.worktrees/sandbox-qa-close-gap/kit/tests/init-firewall-port-allowance.bats` is green.
4. `grep -r 'blocked (n/a per scope: sandbox)' /devshop/.claude/skills/` returns no hits (stale framing scrubbed).
5. `grep -E '^\| .sandbox-qa-close-gap' /devshop/PLAN.md` returns nothing (row deleted).

**Rollout**:

- New projects: pick up automatically — `/ak-new-project` Phase A copies `template/.devcontainer/` at scaffold.
- Existing projects (lalista, home-os, etc.): rebuild the devcontainer (`Cmd+Shift+P → Dev Containers: Rebuild Container`). The `[locked]` lifecycle means `init-devshop.sh` refreshes the two template files at container start from `/devshop/template/.devcontainer/`. No project-side action needed beyond rebuild.

**Rollback**: revert the merge commit on `/devshop main` via a follow-up commit (no `--amend`, no force-push). Operator-side: projects rebuild devcontainer to pick up the reverted files. No data state to migrate.

**Post-merge note for next home-os session** (carried into the BUILD-LOG entry): the operator should re-run `/ak-build` (or just `/ak-pre-ship` directly) on a home-os feature branch after a devcontainer rebuild to confirm Gates 3/8/9/10 now emit `pass` / `findings (N)` / `n/a (no UI in diff)` outcomes instead of `blocked (n/a per scope: sandbox)`. This is the verification step deferred per D5; it doesn't gate the devshop merge.

