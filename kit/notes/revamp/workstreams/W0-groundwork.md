# W0 — Stop the bleeding + groundwork

Needed whatever happens next. `[owner]` = needs the owner (GitHub settings, credentials, host machine).
Status markers: `[ ]` todo · `[~]` doing · `[x]` done (verified) · `[!]` blocked · `[-]` dropped.
Done line: `- [x] **ID** text — YYYY-MM-DD · PR #n` (or commit when no PR).

**M0 order (agreed 2026-10-09, most exposure first):** W0.5 rotate credentials → W0.7 history
secret scan → W0.6 rulesets + archive home-os → W0.4 tag `v1-final` → W0.8 CLAUDE.md note.
Context: lalista is paused and home-os frozen, so no live project needs protecting from v1 changes (D-09).

## W0.1 Revamp scaffolding + plan review — P0 · M0 · S

Done when: plan docs exist, adversarially reviewed, owner review session held, outcomes recorded.

- [x] **W0.1.1** Create `kit/notes/revamp/` (README, PLAN, FINDINGS, DECISIONS, PROCESS, LOG, workstreams) — V1 links resolve — 2026-10-08 · PR #36
- [x] **W0.1.2** Pointer to the revamp in root `PLAN.md § Active` — V1 — 2026-10-08 · PR #36
- [x] **W0.1.4** Coverage check (findings → tasks/decisions; task IDs exist; links) — V1, scripted, LOG #1/#2 — 2026-10-08 · PR #36
- [x] **W0.1.5** Adversarial review of the plan (4 independent reviewers) + corrections — [REVIEW-1.md](../REVIEW-1.md) — 2026-10-08 · PR #36
- [x] **W0.1.3** `[owner]` Plan review session — run top-down (TARGET L0–L2) instead of decision by decision; outcomes in LOG #5 + PLAN changelog — 2026-10-09 · PR #36

## W0.2 Baseline metrics + targets — P0 · M0 · S

- [-] **W0.2.1** v1 baseline — v1 is not being improved (D-14); the v1 numbers in LOG #1 and #5 serve as the reference
- [-] **W0.2.2** Timed v1 pipeline run — replaced by the skeleton run W10.6.4
- [x] **W0.2.3** `[owner]` Targets + capacity — one hard budget (always-loaded context stays tight; other sizes are warning signals); pacing rule instead of hours: at most ~2 devshop PRs waiting on the owner — 2026-10-09 · PR #36

## W0.3 Decisions — P0 · M0 · S

Done when: listed decisions have outcomes in [DECISIONS.md](../DECISIONS.md) and PLAN M1+ is re-planned per D-14.

- [x] **W0.3.1** D-14 thin rewrite (revisited 2026-10-10: in this repo); go/no-go at the walking skeleton — 2026-10-09 · PR #36
- [x] **W0.3.2** D-12 private for now (revisited 2026-10-10: no new repo; public later only after scan + rotation) — 2026-10-09 · PR #36
- [x] **W0.3.3** D-13 GitHub App for the agent (spike moved to W10.1.1) — 2026-10-09 · PR #36
- [x] **W0.3.4** D-04 boundary = GitHub + credentials; read-only production observability — 2026-10-09 · PR #36
- [x] **W0.3.5** D-09 no freeze needed; tag `v1-final`; lalista = pilot — 2026-10-09 · PR #36
- [x] **W0.3.6** D-15 hybrid (markdown plan, Issues for tasks in this repo) — 2026-10-09 · PR #36
- [x] **W0.3.7** D-03 PR → CI → owner merges — 2026-10-09 · PR #36
- [x] **W0.3.8** Re-plan M1+ per D-14 — [W10-v2.md](W10-v2.md), PLAN changelog — 2026-10-09 · PR #36

## W0.4 Tag `v1-final` — P0 · M0 · S

Finding: F-VER-01 (no longer live: lalista paused, home-os frozen — D-09).

- [ ] **W0.4.1** Tag `v1-final` at current `main`; v1 takes security fixes only (stated in W0.8 note) — V1
- [-] **W0.4.2** Host worktree mount for live projects — not needed (D-09)
- [-] **W0.4.3** Live-project smoke check — not needed (D-09)

## W0.5 Rotate exposed credentials — P0 · M0 · S

Findings: F-SEC-02, F-SEC-03, F-SEC-15, F-NEW-07. Done when: every token that was in `.devcontainer/.env` or `/etc/devshop-env` on any machine is rotated and re-scoped; LOG records "rotated <date>" (never values).

Deferred (owner, 2026-10-10): nothing was committed (W0.7), the apps aren't in use and the old dev envs are stale, so rotation moves to the end of the revamp. Revoking needs no dev env — it's a delete in each provider dashboard; replacements are issued only when something needs them.

- [x] **W0.5.1** List affected credentials — from `template/.devcontainer/.env.example` + `init-devshop.sh`: `GITHUB_TOKEN`/`GH_TOKEN`/`DEVSHOP_GITHUB_TOKEN`, `VERCEL_TOKEN`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_SERVICE_ROLE_KEY` (+ anon key), `SENTRY_AUTH_TOKEN` (+ DSN), `ANTHROPIC_API_KEY_QA`, `DEVCONTAINER_ROOT_PASSWORD`, `NTFY_URL` topic — per project + devshop — 2026-10-10 · LOG #11
- [ ] **W0.5.2** `[owner]` Optional now: revoke the old GitHub PAT(s) (account-wide, admin + `workflow`; not tied to the paused apps)
- [ ] **W0.5.3** `[owner]` **Once the v2 devshop works (after W10.6.4):** revoke every credential in W0.5.1 on every machine; issue new ones only as needed, least privilege (no admin; no `workflow` scope for agent-used tokens); LOG records "revoked <date>" (never values)

## W0.6 No-bypass rulesets on the real repos — P0 · M0 · M

Findings: F-SEC-07, F-SEC-08, F-CLOUD-03 (corrected), F-NEW-09, F-NEW-12.
Done when: on abra-kadabra and lalista, a direct push to `main` and a force-push are rejected; home-os is archived (read-only). Verified by attempts recorded in LOG.

- [x] **W0.6.1** `[owner]` Protection on `main` (abra-kadabra, lalista): require PR, block force-push/deletion, no bypass (incl. admins) — classic branch protection for now; lalista also requires 2 status checks; abra-kadabra has no CI yet (required check comes with W3.1.2) — 2026-10-10 · LOG #11
- [ ] **W0.6.2** `[owner]` **Before lalista resumes** (deferred 2026-10-10; lalista paused): move secrets used by CI on `pull_request` (e.g. `SENTRY_AUTH_TOKEN`) out of repo scope into a `main`-only environment
- [ ] **W0.6.3** `[owner]` Archive home-os on GitHub (read-only)
- [-] **W0.6.4** Agent identity + CODEOWNERS — moved to W10.1.1 / W10.4.3
- [x] **W0.6.5** Verification attempts (direct push, force-push) — V3 against GitHub: both rejected (`GH006 … Changes must be made through a pull request`) on both repos — 2026-10-10 · LOG #11
  - 2026-10-11: re-run as the agent identity (`meirmsn-agent`): direct push, force-push and contents-API write to `main` all refused (LOG #10)
- [-] **W0.6.6** `[owner]` After the agent has its own identity (done: `meirmsn-agent`, W10.1.1): convert to a ruleset; decide together with W10.1.3 / A-20 (ruleset B, owner-only merge) — require 1 approval, dismiss stale approvals on new commits, require approval of the most recent push; bypass = Repository admin **for pull requests only** (owner can merge own PRs; nobody pushes to `main`); repo auto-merge **on** (the agent can enable it, but nothing merges without the owner's approval) — V3: agent PR with auto-merge waits for approval; agent push after approval dismisses it
  - 2026-10-11: superseded — the same options are on the classic rule (owner-confirmed) + `CODEOWNERS`; ruleset B deferred ("approval ships", PLATFORM § 3a); auto-merge + dismissal checks move to W10.6.4 (LOG #12)

## W0.7 History secret scan with a working config — P0 · M0 · S

Finding: F-SEC-20 (reproduced: v1's `.gitleaks.toml` detects nothing). v1 is retiring, so v1's own config is not repaired; the scan uses a scratch config with `[extend] useDefault = true`.
Done when: full history of abra-kadabra, lalista and home-os scanned; findings (if any) rotated via W0.5; result in LOG. Also flag (for the owner, not rotation) personal details and infrastructure identifiers (project refs, internal URLs) — input to a later public/private call (D-12).

- [~] **W0.7.1** Scan all three histories with gitleaks defaults (scratch config) — V3; feed any hit into W0.5. abra-kadabra done: 616 commits, 7 hits, all false positives (LOG #11). lalista + home-os pending: Claude GitHub App not installed on them
- [-] **W0.7.2** Fix `.gitleaks.toml` in v1 + template — v1 retiring; v2 starts with a working config (W10.4.1)
- [-] **W0.7.3** Cherry-pick to v1 / propagate — not needed

## W0.8 CLAUDE.md "revamp mode" note — P0 · M0 · S

Findings: REVIEW-1 E9, F-PIPE-16. Done when: CLAUDE.md states, in ≤15 lines: revamp work follows `kit/notes/revamp/PROCESS.md`; changes land via PR (D-03); v1 takes security fixes only; `/ak-build`/`/ak-merge-devshop` are not used for revamp work; where the next task is.

- [ ] **W0.8.1** Write the note; annotate contradicting lines ("do not propose a GitHub PR on devshop", "run `/ak-build` for devshop work") — V1

## W0.9 Triage old backlogs — dropped

- [-] **W0.9.1** / **W0.9.2** — replaced by the lessons harvest W10.3 (2026-10-09)

## W0.10 Target picture + north-star scenario — P0 · M0 · S

- [x] **W0.10.1** `[owner]` TARGET.md L0, L1, L2 agreed top-down — 2026-10-09 · PR #36
- [-] **W0.10.2** Baseline run on v1 — replaced by the skeleton run W10.6.4 (scenario rewritten in W10.2.2)
- [-] **W0.10.3** Test assumptions before M1 — moved to W10.1 (spikes are M1's first epic)
