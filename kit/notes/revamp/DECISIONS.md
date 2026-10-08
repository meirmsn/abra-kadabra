# Decisions

Decisions that shape the plan and belong to the owner. Each lists options, a
recommendation, what it blocks, and — once made — the outcome and date.
Revisiting a decision: add a dated **Revisited** line under it (never rewrite
history) and record the plan impact in [PLAN.md § Changelog](PLAN.md#changelog).

Status: `open` · `decided` · `revisited`. Order below = order to decide in.

| ID   | Decision                                                | Blocks                             | Status |
| ---- | ------------------------------------------------------- | ---------------------------------- | ------ |
| D-14 | **Thin devshop vs incremental revamp** (strategic fork) | everything after M0                | open   |
| D-12 | May the devshop (or parts of it) be public?             | D-01, W4.2                         | open   |
| D-13 | Separate GitHub identity for the agent                  | D-04, W0.6, W1.5                   | open   |
| D-04 | Where the security boundary is                          | M0 (W0.6), M1                      | open   |
| D-09 | Live projects during the revamp (freeze v1)             | M0 (W0.4)                          | open   |
| D-15 | Tracking system: markdown vs GitHub Issues              | M0                                 | open   |
| D-03 | How devshop changes land                                | M0 (W0.8)                          | open   |
| D-02 | Fate of the local devcontainer                          | W1 scope, W4.4                     | open   |
| D-01 | Distribution model                                      | M2 (W4.2) — after spike W4.2.0     | open   |
| D-05 | Plan tier assumptions (Pro/Max vs Team/Enterprise)      | W4.3                               | open   |
| D-06 | Orchestration technology                                | M3 (W6.4)                          | open   |
| D-07 | gstack install model and target version                 | W7                                 | open   |
| D-08 | Stack abstraction scope (recipes)                       | M4 (W5)                            | open   |
| D-10 | Revamp versioning                                       | M2                                 | open   |
| D-11 | Deletion list                                           | M5 (W9) or earlier under D-14 thin | open   |

---

## D-14 Thin devshop vs incremental revamp — `open` (added by REVIEW-1)

- **A. Incremental revamp** (the original plan): fix today's system (M1), then move
  to pinned/cloud (M2), add conformance + tiers (M3), recipes (M4), delete last (M5).
  Realistic effort ~100–130 agent-days + ~40 owner-hours (REVIEW-1 R3).
- **B. Thin devshop** _(orchestrator leans here)_: define the target as a small
  system and build it directly, deleting early:
  1. Boundary = GitHub only (rulesets with no bypass, path rules on `.github/ .claude/ .devshop/` + migrations, environment-gated deploys with main-only secrets, required CI checks; separate agent identity per D-13). No in-VM security claims.
  2. ~6 skills, each ≤ ~1.5k words: spec (with owner approval step), implement, fix, ship (wraps pinned upstream gstack `/ship` + `/land-and-deploy`), status, new-project. Tiers = which skill you run.
  3. Deterministic gate runner + acceptance→test check as **required CI**.
  4. Template: CI, CLAUDE.md, stack scripts under `stack/<vendor>/`.
  5. Distribution per D-01/D-12.
  6. Delete early: manifest/symlink/lock/sync model, root-copy/sticky-bit model, most of `adversarial-review.sh`, clean-tree/stash guards, `/ak-merge-devshop`, CLAUDE.md-placement machinery, per-gate n/a files, prose-grep tests; friction → GitHub issue label.
     Gives up: offline/macOS hardening (already weak, F-SEC-13), rich in-session gating (moves to CI), the stack abstraction (not needed yet).
- **Way to decide:** half-day comparison — rewrite the milestone table under B and
  compare task count, effort, and risk retired per milestone (owner + Claude, in the
  review session).

Outcome: —

## D-12 May the devshop be public? — `open` (added by REVIEW-1)

The devshop is private and has **no LICENSE** (verified). Any model that commits
devshop files into project repos publishes them if the project is public.

- **A. Make the devshop public** (add a license) — unlocks in-project installs and
  public release tarballs that cloud setup scripts can fetch.
- **B. Public "runtime" part + private "workshop" part** — skills/scripts needed at
  runtime are public; notes/specs/history stay private.
- **C. Stay private** — then projects that receive a copy must be private, or the
  devshop reaches sessions only as an attached second repo (no hooks, D-01 B) or as a
  claude.ai-level plugin/skills (D-01 C).

Outcome: —

## D-13 Separate GitHub identity for the agent — `open` (added by REVIEW-1)

Today the agent acts as the owner: commits, PRs, approvals, merges carry the
owner's identity with admin rights, and the session exposes merge / auto-merge /
workflow-dispatch / contents-API tools (REVIEW-1 E2). GitHub doesn't let an
author approve their own PR, so "owner approves" is unenforceable.

- **A. Machine user or GitHub App for the agent** _(recommended if the platform
  allows it)_: write access to contents + PRs, no admin, no `workflows` permission;
  owner approves from their own account; CODEOWNERS and required reviews become real.
  Needs a spike: can cloud sessions use a different GitHub identity (e.g. `/web-setup`
  with a machine-user token)?
- **B. Same identity + no-bypass rulesets** — require PR + checks, block force push
  and deletions, no bypass for admins; accept that the agent could still merge its
  own PR via the API; say so honestly in D-04.

Outcome: —

## D-04 Where the security boundary is — `open` (rewritten by REVIEW-1)

- **Recommendation:** "The boundary is on GitHub and in credentials, not in the VM":
  - GitHub rulesets on `main` with **no bypass** (incl. admins): PR required, required
    checks, no force-push/deletion; path restrictions for `.github/`, `.claude/`,
    `.devshop/`, migrations (enforceable only with D-13 A).
  - Secrets: none at repo level for `pull_request` workflows; all in environments whose
    deployment branches are `main` only, with required reviewer + prevent self-review;
    default `permissions: contents: read`.
  - Production credentials never in the agent's environment; tokens it does get are
    least-privilege and rotated (W0.5).
  - The cloud git proxy keeps credentials out of the VM but **does not restrict
    branches** (REVIEW-1 E1); the network allowlist limits egress.
  - LLM verdicts in CI are advisory, never the only required check.
  - In-VM hooks/reviewers are feedback and hygiene, documented as such.
- Alternative: keep claiming in-VM guardrails as the boundary (then all of W1.1–W1.3 +
  sandboxing are mandatory, and macOS remains weak).

Outcome: —

## D-09 Live projects during the revamp — `open` (moved to M0 by REVIEW-1)

Nothing pins live projects today (F-VER-01), so devshop changes reach lalista/home-os
immediately. Recommendation: tag `v1-frozen` + `v1` branch; live project containers
mount a `/devshop` worktree at that ref (host-side step); only security fixes are
cherry-picked to `v1`; projects move to the new model one at a time.

Outcome: —

## D-15 Tracking system — `open` (added by REVIEW-1)

- **A. Markdown in repo** (current): versioned, greppable, offline; but status on an
  epic branch is invisible to other sessions until merged; drift-prone.
- **B. GitHub Issues + milestones** _(R3 recommends)_: one issue per epic (task
  checklist + done-when in body), GitHub milestone per M, `Closes #n` in PRs, label
  `finding` for discoveries; PLAN/DECISIONS/FINDINGS stay in repo. Agent uses REST via
  MCP. Note: GitHub Projects v2 boards are GraphQL-only and not reachable from cloud
  sessions.
- **C. Hybrid**: markdown structure, Issues for status.

Outcome: —

## D-03 How devshop changes land — `open` (rationale corrected by REVIEW-1)

- **A. Branch → PR → CI (bats) → owner merges** _(recommended)_ — gives the devshop CI
  and review; works the same locally and in cloud. (Correction: the cloud git proxy does
  **not** force this — it doesn't restrict branches; rulesets must, W0.6.) Update
  CLAUDE.md's "no PRs on devshop" rule (W0.8).
- **B. Keep `/ak-merge-devshop` local squash-to-main.**

Interim: revamp work goes through PRs on `claude/*` branches.

Outcome: —

## D-02 Fate of the local devcontainer — `open`

- **A. Cloud-first, local supported via the same install script** _(recommended)_ —
  one `install-tools.sh` for cloud setup script and Dockerfile; retire the
  root-owned-copies/sticky-bit model (cosmetic on macOS, F-SEC-13) in favour of D-04;
  keep only the local fixes that close live root-escalation paths while local is used
  (F-SEC-01/02/03/13/15).
- **B. Keep local first-class with full hardening.**
- **C. Cloud-only** — use Remote Control for macOS/iOS/offline work.

Outcome: —

## D-01 Distribution model — `open` (reopened by REVIEW-1; decide after D-12 + spike W4.2.0)

How does a project get the devshop, and which version?

- **A. Pinned in-project install** — `.devshop/` + `.claude/` committed into the
  project; works in single-repo cloud sessions with hooks; real per-project versions.
  **Costs:** publishes the devshop if the project is public (D-12); hook/settings files
  become agent-editable project files; upgrades touch many files.
- **A′. Split install** — public-safe runtime committed; private remainder fetched at
  setup. **Blocked in cloud** unless fetched from a public source: a setup script can't
  clone a second private repo (proxy 403 for non-attached repos — REVIEW-1 R4).
- **B. Two-repo session** (devshop + project) — no copying, but hooks/permissions off
  and no pinning (devshop default branch is live).
- **C. Plugin** — versioned via plugin-entry `sha`; reaches cloud via Project settings
  (Pro/Max beta) or claude.ai-synced plugins/skills; doesn't cover template/CI/git hooks.
- **D. Out-of-repo pinned install into user scope** (`~/.claude/…`) via setup script —
  keeps projects clean; needs a fetchable source (public tarball, D-12 A/B) and
  confirmation that user-scope settings/hooks load in cloud.
- Recommendation: run spike **W4.2.0** (can cloud fetch a pinned source? do user-scope
  hooks load? how do Project-level plugins pin?), decide D-12, then pick. If D-12 = A or
  B: **D** (or A for public runtime); if C: **C** for skills + template files in-project.

Outcome: —

## D-05 Plan tier assumptions — `open`

Network secrets exist on Pro/Max (not Team/Enterprise yet); server-managed settings
exist on Team/Enterprise only and are "a client-side control, not a security
boundary"; Projects (plugins via Project settings) are Pro/Max beta; Workflows on all
paid plans (Pro needs a `/config` toggle). Recommendation: design for Pro/Max.

Outcome: —

## D-06 Orchestration technology — `open` (recommendation changed by REVIEW-1)

- **A. Thin skills + deterministic gate runner as a required CI check** _(recommended)_ —
  the only place determinism is also enforcement (the agent can edit/skip in-VM scripts).
- **B. Workflow scripts** (saved `.claude/workflows/<name>.js`, invoked by name, allowed via
  `Workflow(<name>)`) — real halts and schemas in-session; no mid-run human input; newer
  surface. Optional later.
- **C. Agent SDK program** — most new code.

Outcome: —

## D-07 gstack install model and target — `open`

Recommendation: pinned copy (commit SHA) delivered with the devshop (per D-01),
upgraded to ≥ 1.91.13 in a dedicated branch with router-shim + `/ship` adaptations;
no hourly auto-update/team mode; neutralise setup's `~/.claude/settings.json` edits.

Outcome: —

## D-08 Stack abstraction scope — `open` (recommendation changed by REVIEW-1)

Recommendation: **minimal now** — move vendor-specific scripts/docs under
`kit/stack/<vendor>/`, select by one `stack:` line, remove vendor names from core.
Build the capability contract / resolver / contract tests only when a real project
commits to a second stack, from two real examples.

Outcome: —

## D-10 Revamp versioning — `open`

Recommendation: freeze `v1` (D-09); v1.x patches = security fixes only; v2.0.0 at the
distribution switch.

Outcome: —

## D-11 Deletion list — `open`

Candidates: CLAUDE.md-placement machinery (F-DOC-05), most `adversarial-review.sh`
check-types (F-REV-06), per-gate n/a files (F-DOC-06), prose-pinning grep tests
(F-TEST-03), `/ak-handoff` (F-GS-07), `/ak-merge-devshop` push-to-main path (D-03),
manifest/symlink/lock/sync model (D-01/D-02). Under D-14 B, most move to M1.

Outcome: —
