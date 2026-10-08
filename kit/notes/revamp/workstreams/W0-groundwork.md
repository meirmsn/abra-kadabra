# W0 — Stop the bleeding + groundwork

Path-independent work: needed whatever D-14 decides. `[owner]` = needs the owner
(GitHub settings, credentials, host machine).
Status markers: `[ ]` todo · `[~]` doing · `[x]` done (verified) · `[!]` blocked · `[-]` dropped.
Done line: `- [x] **ID** text — YYYY-MM-DD · PR #n` (or commit when no PR).

## W0.1 Revamp scaffolding + plan review — P0 · M0 · S

Done when: plan docs exist, adversarially reviewed, owner review session held, outcomes recorded.

- [x] **W0.1.1** Create `kit/notes/revamp/` (README, PLAN, FINDINGS, DECISIONS, PROCESS, LOG, workstreams) — V1 links resolve — 2026-10-08 · PR #36
- [x] **W0.1.2** Pointer to the revamp in root `PLAN.md § Active` — V1 — 2026-10-08 · PR #36
- [x] **W0.1.4** Coverage check (findings → tasks/decisions; task IDs exist; links) — V1, scripted, LOG #1/#2 — 2026-10-08 · PR #36
- [x] **W0.1.5** Adversarial review of the plan (4 independent reviewers) + corrections — [REVIEW-1.md](../REVIEW-1.md) — 2026-10-08 · PR #36
- [ ] **W0.1.3** `[owner]` Plan review session ([PROCESS.md § Plan review session](../PROCESS.md#plan-review-session-next)); record outcomes in LOG + PLAN changelog

## W0.2 Baseline metrics + targets — P0 · M0 · S

Done when: a dated baseline table is in LOG and targets are agreed.

- [ ] **W0.2.1** Record baseline: bats count/pass/fail/skip + runtime; words in always-loaded context; words per devshop skill; guide words; gate count; `specs/` file count — V1 (commands in LOG)
- [ ] **W0.2.2** One timed end-to-end run of today's pipeline on a tiny change (time-to-PR, tool calls) — on the fixture once W3.3.1 decides it; else from history
- [ ] **W0.2.3** `[owner]` Agree targets (proposal: always-loaded context ≤ 3k words; largest skill ≤ 4k words; guides ≤ 40k words; gates per patch-tier change ≤ 5; CI ≤ 10 min) and owner capacity (hours/week) + agent budget

## W0.3 Decisions — P0 · M0 · S

Done when: listed decisions have outcomes in [DECISIONS.md](../DECISIONS.md) and PLAN M1+ is re-planned per D-14.

- [ ] **W0.3.1** D-14 thin vs incremental (half-day comparison first)
- [ ] **W0.3.2** D-12 devshop public/private
- [ ] **W0.3.3** D-13 agent GitHub identity (spike: can a cloud session use a non-owner identity?)
- [ ] **W0.3.4** D-04 boundary statement
- [ ] **W0.3.5** D-09 live projects / freeze v1
- [ ] **W0.3.6** D-15 tracking system
- [ ] **W0.3.7** D-03 landing flow
- [ ] **W0.3.8** Re-plan M1+ in PLAN.md per D-14 (changelog entry)

## W0.4 Freeze v1 for live projects — P0 · M0 · S

Finding: F-VER-01 (+ REVIEW-1 E6). Done when: lalista and home-os containers run the devshop at `v1-frozen` and a revamp merge to `main` demonstrably doesn't reach them.

- [ ] **W0.4.1** Tag `v1-frozen` at current `main`; create `v1` branch (security fixes only, cherry-picked) — V1
- [ ] **W0.4.2** `[owner]` Host step: a `../abra-kadabra-v1` worktree at `v1`; project devcontainers mount it as `/devshop` (one-line change in each project's devcontainer bind or a host symlink) — documented in LOG
- [ ] **W0.4.3** Smoke check on one live project after the switch (session starts, commit hook runs) — V5

## W0.5 Rotate exposed credentials — P0 · M0 · S

Findings: F-SEC-02, F-SEC-03, F-SEC-15, F-NEW-07. Done when: every token that was in `.devcontainer/.env` or `/etc/devshop-env` on any machine is rotated and re-scoped; LOG records "rotated <date>" (never values).

- [ ] **W0.5.1** `[owner]` List affected credentials (GitHub PATs, Vercel, Supabase access token, Sentry, Anthropic QA key, root password) per project
- [ ] **W0.5.2** `[owner]` Rotate; narrow scopes (least privilege; no admin; no `workflow` scope for agent-used tokens)

## W0.6 No-bypass rulesets + secret hygiene on the real repos — P0 · M0 · M

Findings: F-SEC-07, F-SEC-08, F-CLOUD-03 (corrected), F-NEW-09, F-NEW-12. Depends on D-13/D-04.
Done when: on abra-kadabra, lalista, home-os — a direct push to `main` is rejected, a force-push is rejected, a PR can't merge with failing required checks, and no `pull_request` workflow can read a deploy secret. Verified by attempts recorded in LOG.

- [ ] **W0.6.1** `[owner]` Ruleset on `main`: require PR, required checks (CI once W3.1 exists), block force-push/deletion, **bypass list empty (incl. admins)**; disable repo auto-merge
- [ ] **W0.6.2** `[owner]` Move secrets used by CI on `pull_request` (e.g. `SENTRY_AUTH_TOKEN`) out of repo scope into environments limited to `main`; production environment with required reviewer + prevent self-review; workflows default `permissions: contents: read`
- [ ] **W0.6.3** If D-13 = A: create the agent identity and point cloud sessions at it; add CODEOWNERS for `.github/ .claude/ .devshop/` + migrations, require code-owner review
- [ ] **W0.6.4** Verification attempts (direct push, force-push, red-check merge, secret read from a PR workflow) — V3 against GitHub, results in LOG

## W0.7 Make gitleaks actually detect secrets — P0 · M0 · S

Finding: F-SEC-20 (reproduced). Done when: committing a planted fake token is blocked by the pre-commit hook, CI, and the template, using the repo config.

- [ ] **W0.7.1** Add `[extend] useDefault = true` to `.gitleaks.toml` and `template/.gitleaks.toml`; add bats test that stages a fake AWS/GitHub token in a scratch repo and expects detection with the repo config — V2
- [ ] **W0.7.2** Re-scan full history of abra-kadabra, lalista, home-os with the fixed config; rotate anything found (feeds W0.5) — V3
- [ ] **W0.7.3** Cherry-pick to `v1` (W0.4) and propagate to projects

## W0.8 CLAUDE.md "revamp mode" section — P0 · M0 · S

Findings: REVIEW-1 E9, F-PIPE-16. Done when: CLAUDE.md states, in ≤15 lines: revamp work follows `kit/notes/revamp/PROCESS.md`; devshop changes land via PR (per D-03); `/ak-build`/`/ak-merge-devshop` are not used for revamp work; where to find the next task.

- [ ] **W0.8.1** Write the section; remove/annotate contradicting lines ("do not propose a GitHub PR on devshop", "run `/ak-build` for devshop work") — V1

## W0.10 Target picture + north-star scenario — P0 · M0 · S

Done when: [TARGET.md](../TARGET.md) is agreed with the owner (after D-14) and the
north-star scenario has been run once on the fixture as a baseline (most steps
expected to fail; record which).

- [ ] **W0.10.1** `[owner]` Review/adjust TARGET.md in the plan review session
- [ ] **W0.10.2** Baseline run of the north-star scenario; results in LOG
- [ ] **W0.10.3** Test the assumptions M1 builds on (ASSUMPTIONS.md A-05…A-08) before M1 starts

## W0.9 Triage old backlogs — P1 · M0 · S

Done when: every entry in `kit/ROADMAP.md`, `kit/TODOS.md`, `kit/FRICTION-LOG.md`, and root `PLAN.md` Planned rows is mapped to a finding/task, marked "closed by revamp", or archived; the files carry a banner pointing to the revamp.

- [ ] **W0.9.1** Map entries (scripted list + judgement), add `F-NEW` rows for anything real and unplanned
- [ ] **W0.9.2** Banner + archive (move to `kit/notes/archive/` or keep with status)
