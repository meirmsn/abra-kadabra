# W4 — Cloud-native runtime & pinned distribution _(provisional — re-plan after D-14; W4.2 after D-12 + spike)_

Run the devshop in Claude Code cloud sessions (and locally), one explicit version
per project. Depends on D-01, D-02, D-03, D-04, D-05, D-12.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W4.1 Cloud environment for the devshop repo — P0 · M0 · S

Findings: F-CLOUD-01, F-CLOUD-06.
Done when: a fresh cloud session on this repo runs the full bats suite green with no manual steps.

- [ ] **W4.1.1** `[owner]` Environment setup script (configured in the cloud environment UI; text kept in-repo at `kit/cloud/setup-devshop.sh`): rsync, gawk, gitleaks (pinned + checksum), bats deps — evidence: suite run in a fresh session, LOG
- [ ] **W4.1.2** Repo hooks cloud-safe: resolve paths relatively; exit 0 with a clear message when not applicable (F-CLOUD-06)
- [ ] **W4.1.3** Network domains the devshop needs listed in `kit/cloud/README.md`; `[owner]` sets "Custom" or confirms "Trusted"

## W4.2 Distribution: spike, then pinned install/upgrade/rollback — P1 · M2 · L+ (D-01, D-12)

Findings: F-VER-01..04, F-VER-07, F-TPL-07, F-DOC-07, F-CLOUD-02, F-NEW-10, F-NEW-11.
Done when: per the chosen D-01 option, a fixture project at a pinned devshop version
gets skills/agents/hooks/permissions in a cloud session; two projects at different
versions coexist; upgrade and rollback demonstrated; public clone works without the devshop.

- [ ] **W4.2.0** **Spike** (answers recorded in DECISIONS D-01): (a) can a cloud setup script fetch a pinned devshop from a public release tarball (private repos 403 — REVIEW-1 R4)? (b) do user-scope (`~/.claude`) skills/settings/hooks written by a setup script load in cloud sessions? (c) how do Project-level / claude.ai-synced plugins pin versions? (d) does `add_repo` mid-session disable hooks? — V4
- [ ] **W4.2.1** Install layout per D-01 outcome (what lives where, what the project may edit, how hooks/settings are protected) — decision entry with acceptance criteria
- [ ] **W4.2.2** `install`/`upgrade`: fetch tag, install, record version + checksums; refuse dirty/unreleased sources; compatibility check instead of silent degradation (F-VER-02, F-VER-04) — V3
- [ ] **W4.2.3** Upgrade never silently deletes project-added files; upgrade notes become the PR body (F-VER-03). Prefer "installed files are never edited → overwrite whole" over a 3-way merge — V3
- [ ] **W4.2.4** Public-contributor path: clone/build/commit/open devcontainer without the devshop (F-TPL-07, F-DOC-07) — V3
- [ ] **W4.2.5** Installed hooks/permissions use project-relative paths — V4 in a cloud session
- [ ] **W4.2.6** gstack delivered pinned with the install (implements W7.1's chosen version; W7.1 owns the upgrade) — V4
- [ ] **W4.2.7** **Rollback**: documented and demonstrated return of a project from v2 to `v1` (W0.4) — V4

## W4.3 Project cloud environment + boundary checklist — P1 · M2 · M (D-04, D-05, D-13)

Findings: F-SEC-02, F-SEC-11, F-CLOUD-03..05.
Done when: on the fixture — no production secret reachable from the session; deploy needs owner approval; outside-VM attack suite (W3.3.3) passes.

- [ ] **W4.3.1** Project cloud environment recipe: setup script (tools, `docker compose pull`), network allowlist, which keys go to network secrets vs env vars vs GitHub environment secrets only (note: env vars are readable by anyone using the environment) — doc + V4
- [ ] **W4.3.2** Local services in cloud on demand (`docker compose up` / `supabase start`); measure startup time — V4
- [ ] **W4.3.3** Boundary checklist (W0.6/W1.5) executed on the fixture repo — V4

## W4.4 Local parity — P1 · M2 · M (D-02)

Findings: F-SEC-13, F-SEC-16, F-INFRA-07. Opportunity: O-04.
Done when: one install script builds both the local image and the cloud environment; no init deadlock.

- [ ] **W4.4.1** One `install-tools.sh` for Dockerfile + cloud setup script; optional `/etc/claude-code/managed-settings.json` in the image (replaces root-owned settings copies) — V3 local + V4 cloud
- [ ] **W4.4.2** Remove the `postStartCommand` `&&` deadlock (F-INFRA-07) — V3
- [ ] **W4.4.3** Retire (or keep, per D-02) root-owned copies, sticky-bit dirs, symlink injection; update docs (F-SEC-13, F-SEC-16)

## W4.5 Move project state out of the devshop — P1 · M2 · S

Findings: F-VER-06, F-PIPE-17, F-NEW-04.
Done when: no project session writes into the devshop repo.

- [ ] **W4.5.1** Init tracker + port offset → project-side state file (+ host registry for local ports if needed) — V3
- [ ] **W4.5.2** Friction intake from project sessions → GitHub issue on the devshop repo (label `friction`); never write into another repo implicitly — V3
- [ ] **W4.5.3** No `pnpm install`/chown inside the devshop from project container start — V3

## W4.6 Devshop release flow without agent commits on main — P1 · M2 · S (D-03)

Findings: F-PIPE-16, F-NEW-08. (CLAUDE.md update moved to W0.8.)
Done when: releases happen via a GitHub Action or a human-run script; no `CLAUDECODE=` unset anywhere.

- [-] **W4.6.1** moved to W0.8 (REVIEW-1 R3 B5)
- [ ] **W4.6.2** Release via GitHub Action on tag/merge (or human-run script); remove `CLAUDECODE=` unset and token-in-URL from `release.sh` (F-PIPE-16, F-NEW-08) — V3
- [ ] **W4.6.3** `/ak-merge-devshop`: retire push-to-main path; useful audit steps → CI or PR checklist (deletion in W9.1) — V1

## W4.7 Notifications, routines, PR auto-fix — P2 · M2 · S

Opportunities: O-07, O-08.
Done when: each local-only convenience has a cloud equivalent or is documented as local-only.

- [ ] **W4.7.1** ntfy notifications → app push (cloud) / `http` hook (local); lock or retire `notify/*`
- [ ] **W4.7.2** `/ak-build` Phase 5 CI-watch → PR auto-fix/subscriptions in cloud
- [ ] **W4.7.3** Scheduled jobs (keepalive check, deps watch, retro) → Routines where useful
