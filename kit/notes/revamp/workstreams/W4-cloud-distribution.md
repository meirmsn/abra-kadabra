# W4 — Cloud-native runtime & pinned distribution

Run the devshop in Claude Code cloud sessions (and locally), one explicit version
per project. Depends on D-01, D-02, D-03, D-04, D-05.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W4.1 Cloud environment for the devshop repo — P0 · M0 · S

Findings: F-CLOUD-01, F-CLOUD-06.
Done when: a fresh cloud session on this repo runs the full bats suite green with no manual steps.

- [ ] **W4.1.1** Environment setup script (owner configures in the cloud environment UI; script text kept in-repo at `kit/cloud/setup-devshop.sh`): install rsync, gawk, gitleaks (pinned), bats deps; `ln -sfn` devshop link only if still needed after W3.2.1 — V4
- [ ] **W4.1.2** Make repo hooks cloud-safe: SessionStart/other hooks resolve paths relatively and exit 0 with a clear message when not applicable (F-CLOUD-06) — V4
- [ ] **W4.1.3** Network policy: list domains the devshop needs (GitHub, npm, Anthropic, …) in `kit/cloud/README.md`; owner sets "Custom" or confirms "Trusted" — V4

## W4.2 Pinned in-project install + upgrade — P1 · M2 · L (D-01)

Findings: F-VER-01..04, F-VER-07, F-TPL-07, F-DOC-07, F-CLOUD-02.
Done when: `devshop install vX` and `devshop upgrade vY` produce a reviewed diff in a
fixture project; a cloud session on that project gets skills, agents, hooks and
permissions; two projects at different versions coexist; public clone works without the devshop.

- [ ] **W4.2.1** Design the install layout: `.devshop/{version,stack.yaml,kit/,recipes/}`, `.claude/{skills,agents,settings.json}`, generated files marked; ownership rules (what the project may edit) — design note + review
- [ ] **W4.2.2** `install`/`upgrade` command (script or skill + script): fetch tag, copy, record version + checksums; **refuse** to install from a dirty/unreleased devshop; compatibility checks replace silent degradation (F-VER-02, F-VER-04) — V3
- [ ] **W4.2.3** Upgrade = 3-way merge with clear diff, never silent deletion of project-added files; upgrade notes from PROPAGATION become the PR body (F-VER-03) — V3
- [ ] **W4.2.4** Public-contributor path: project clones/builds/commits/opens devcontainer without any devshop present (F-TPL-07, F-DOC-07) — V3
- [ ] **W4.2.5** Hooks + permissions in the installed `.claude/settings.json` use project-relative paths only — V4 in a cloud session
- [ ] **W4.2.6** gstack pinned within the install (with W7.1) — V4

## W4.3 Project cloud environment + outside-the-VM boundary — P1 · M2 · M (D-04, D-05)

Findings: F-SEC-02, F-SEC-11, F-CLOUD-03..05.
Done when: documented and demonstrated on the fixture: no production secret is
reachable from the session; deploy needs owner approval; agent cannot push to main
or change workflows without review.

- [ ] **W4.3.1** Project cloud environment recipe: setup script (tools, `docker compose pull` for local services), network allowlist, which keys go to **network secrets** vs env vars vs GitHub environment secrets only — doc + V4
- [ ] **W4.3.2** Local services in cloud: start on demand (`docker compose up` / `supabase start`) via a script the pipeline calls; measure startup time — V4
- [ ] **W4.3.3** Boundary checklist executed on the fixture repo (branch protection, CODEOWNERS, environments from W1.5) and recorded — V4

## W4.4 Local parity — P1 · M2 · M (D-02)

Findings: F-SEC-13, F-SEC-16, F-INFRA-07. Opportunity: O-04.

- [ ] **W4.4.1** One `install-tools.sh` shared by the Dockerfile and the cloud setup script; optional local `/etc/claude-code/managed-settings.json` baked into the image for deny rules/hooks (replaces root-owned settings copies) — V3 local + V4 cloud
- [ ] **W4.4.2** Remove the `postStartCommand` `&&` deadlock (firewall failure must not block init/self-heal) (F-INFRA-07) — V3
- [ ] **W4.4.3** Retire (or keep, per D-02) root-owned copies, sticky-bit dirs, symlink injection; update docs (F-SEC-13, F-SEC-16)

## W4.5 Move project state out of the devshop — P1 · M2 · S

Findings: F-VER-06, F-PIPE-17.

- [ ] **W4.5.1** Init tracker + port offset → project-side `.devshop/state.md` (+ host-level registry for local ports if still needed) — V3
- [ ] **W4.5.2** Friction intake from project sessions → GitHub issue on the devshop repo (label `friction`) or a file in the project; never write into another repo implicitly — V3
- [ ] **W4.5.3** Remove `pnpm install`/chown inside the devshop from project container start — V3

## W4.6 Devshop lands via PRs + release flow — P1 · M2 · S (D-03)

Findings: F-PIPE-16, F-CLOUD-03.

- [ ] **W4.6.1** Update CLAUDE.md/workflow docs: devshop changes via branch → PR → CI → owner merge; keep squash-message conventions as PR template — V1
- [ ] **W4.6.2** Release via GitHub Action on tag/merge (or a human-run script) — no agent commits on main; remove `CLAUDECODE=` unset in `release.sh` — V3
- [ ] **W4.6.3** `/ak-merge-devshop`: retire push-to-main path; keep useful audit steps as CI or PR checklist (deletion in W9.1) — V1

## W4.7 Notifications, routines, PR auto-fix — P2 · M2 · S

Opportunities: O-07, O-08.

- [ ] **W4.7.1** Map ntfy notifications → app push (cloud) / `http` hook (local); lock or retire `notify/*` — V4
- [ ] **W4.7.2** `/ak-build` Phase 5 CI-watch → PR auto-fix/subscriptions in cloud; keep local fallback — V4
- [ ] **W4.7.3** Scheduled jobs (keepalive check, deps watch, retro) → Routines where useful — V4
