# Decisions

Decisions that shape the plan and belong to the owner. Each lists options, a
recommendation, what it blocks, and — once made — the outcome and date.
Revisiting a decision: add a dated **Revisited** line under it (never rewrite
history) and record the plan impact in [PLAN.md § Changelog](PLAN.md#changelog).

Status: `open` · `decided` · `revisited`. Order below = order to decide in.

| ID   | Decision                                                | Blocks                             | Status   |
| ---- | ------------------------------------------------------- | ---------------------------------- | -------- |
| D-14 | **Thin devshop vs incremental revamp** (strategic fork) | everything after M0                | decided  |
| D-12 | May the devshop (or parts of it) be public?             | D-01, W4.2                         | decided  |
| D-13 | Separate GitHub identity for the agent                  | D-04, W0.6, W1.5                   | decided  |
| D-04 | Where the security boundary is                          | M0 (W0.6), M1                      | decided  |
| D-09 | Live projects during the revamp (freeze v1)             | M0 (W0.4)                          | decided  |
| D-15 | Tracking system: markdown vs GitHub Issues              | M0                                 | decided  |
| D-03 | How devshop changes land                                | M0 (W0.8)                          | decided  |
| D-02 | Fate of the local devcontainer                          | W1 scope, W4.4                     | decided  |
| D-01 | Distribution model                                      | M1 (W10.4.4) — after spike W10.1.2 | decided  |
| D-05 | Plan tier assumptions (Pro/Max vs Team/Enterprise)      | spikes W10.1                       | decided  |
| D-06 | Orchestration technology                                | M3 (W6.4)                          | decided  |
| D-07 | gstack install model and target version                 | M2 (with D-01)                     | open     |
| D-08 | Stack abstraction scope (recipes)                       | M4 (W5)                            | decided  |
| D-10 | Revamp versioning                                       | first v2 release (M1)              | open     |
| D-11 | Deletion list                                           | M5 (W9) or earlier under D-14 thin | obsolete |

---

## D-14 Thin devshop vs incremental revamp — `decided` (added by REVIEW-1)

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

Outcome: **decided 2026-10-09 — thin rewrite.** Build a new, lean devshop in a **new runtime repo**, with frozen v1 (abra-kadabra) as the reference. A lessons harvest from v1 + home-os + FINDINGS comes first; an explicit **go/no-go** follows the walking skeleton (fallback: incremental path A). Agreed top-down via [TARGET.md](TARGET.md) L0–L2 (LOG #5). "Small" means no bloat, not minimum size: one hard budget (always-loaded context), other sizes are warning signals.

**Revisited 2026-10-10:** the rewrite happens **in this repo**, not a new one — tag `v1-final`, the first v2 PR removes v1 from `main`, v1 stays readable from the tag. Reason: the new repo's only unique benefit was clean history for a possible public release; the revamp retires the weaknesses the notes describe, and the history scan + rotation (W0.7 → W0.5) neutralises leaked secrets (LOG #6).

## D-12 May the devshop be public? — `decided` (added by REVIEW-1)

The devshop is private and has **no LICENSE** (verified). Any model that commits
devshop files into project repos publishes them if the project is public.

- **A. Make the devshop public** (add a license) — unlocks in-project installs and
  public release tarballs that cloud setup scripts can fetch.
- **B. Public "runtime" part + private "workshop" part** — skills/scripts needed at
  runtime are public; notes/specs/history stay private.
- **C. Stay private** — then projects that receive a copy must be private, or the
  devshop reaches sessions only as an attached second repo (no hooks, D-01 B) or as a
  claude.ai-level plugin/skills (D-01 C).

Outcome: **decided (direction) 2026-10-09 — option B in a new form.** The new runtime repo has fresh history and no notes/project details: **private for now, public-safe by design**; flipping it public is decided after the distribution spike (A-09/A-10). abra-kadabra stays private as v1 + workshop. Concerns that ruled out publishing this repo: secrets in history (F-SEC-20), project/personal notes, a map of guardrail weaknesses, no license.

**Revisited 2026-10-10:** no new repo. abra-kadabra stays private for now; it may go public later once W0.7's history scan is clean, every hit is rotated (W0.5), and the owner has read the notes for personal details / infrastructure identifiers. Flipping it public is still decided after the distribution spike (W10.1.2).

**Revisited 2026-10-11:** history is **not** cleaned before going public. Project names, infrastructure identifiers (Supabase project refs, Vercel URLs, team slug) and personal details already in history are accepted. The one gate: re-scan the full history for secrets (`--all` + PR refs, as in W0.7.1) right before flipping, and the owner revokes/rotates every real hit. The 2026-10-09 "owner reads the notes" step is dropped.

## D-13 Separate GitHub identity for the agent — `decided` (added by REVIEW-1)

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

Outcome: **decided 2026-10-09 — A, a GitHub App for the agent** (owner's proposal): authors commits/PRs with contents + PR permissions only, no admin, no workflow edits; the owner approves from their own account. **Pending spike A-05** (can a cloud session push/open PRs as an App, given the proxy uses the owner's connected account?). Fallbacks in order: machine user; same identity + no-bypass rulesets (then stated honestly as a habit, not a gate).

**Revisited 2026-10-11:** a GitHub App can't be the agent's identity in Anthropic-hosted cloud sessions — the GitHub proxy swaps in the connected account's credential and blocks App token minting, and network secrets never reach GitHub (LOG #7). **Machine user `meirmsn-agent`** instead: Write collaborator, connected to claude.ai by reconnecting GitHub in the browser as the agent. Validated: PRs authored and merged by the agent only after the owner's code-owner approval; direct/force pushes and API writes to `main` refused (LOG #9, #10). Ruleset B ("only the owner merges") deferred — "approval ships" accepted ([PLATFORM.md § 3a](PLATFORM.md#3a-optional-ruleset-b--only-the-owner-merges)).

**Trial 2026-10-11 → 2026-10-25 (or until the walking skeleton W10.6 runs end to end, whichever first):** the machine-user setup splits the owner's GitHub profile — on github.com a squash merge's commit is credited to the **PR author** (the agent), co-authored commits don't count (the "or co-author" rule is GitHub Enterprise Server only), and the owner gets only reviews ([profile contributions reference](https://github.com/github/docs/blob/main/content/account-and-profile/reference/profile-contributions-reference.md); test on PR #42, LOG #13). Owner keeps the setup for the trial, then decides: keep it, or **switch back** to the owner's identity — reconnect claude.ai → GitHub as the owner, untick "require approvals / code-owner review" on `main` (the owner can't approve their own PRs), leave `meirmsn-agent` dormant (don't delete it: its PRs/comments would turn into "ghost"). Judge on: is the enforced approval gate worth it day to day; how much the split profile matters; any other surprises. Commit credit landed on the agent during the trial stays there.

## D-04 Where the security boundary is — `decided` (rewritten by REVIEW-1)

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

Outcome: **decided 2026-10-09 — recommendation adopted** (TARGET L2 Safety): Claude is untrusted; enforcement lives in GitHub rules, CI, credentials and protected deploys; in-session checks are feedback. Production access = read-only observability; production data only on an explicit, time-limited owner grant enforced outside Claude's reach. PR CI contains no agentic/LLM jobs.

## D-09 Live projects during the revamp — `decided` (moved to M0 by REVIEW-1)

Nothing pins live projects today (F-VER-01), so devshop changes reach lalista/home-os
immediately. Recommendation: tag `v1-frozen` + `v1` branch; live project containers
mount a `/devshop` worktree at that ref (host-side step); only security fixes are
cherry-picked to `v1`; projects move to the new model one at a time.

Outcome: **decided 2026-10-09 — superseded by the rewrite.** lalista is paused (no devshop work now) and home-os is frozen (lessons source only), so no freeze mechanism is needed: tag `v1-final`, v1 takes security fixes only. **lalista is the pilot** of the new devshop after the go/no-go (web first, then iOS).

## D-15 Tracking system — `decided` (added by REVIEW-1)

- **A. Markdown in repo** (current): versioned, greppable, offline; but status on an
  epic branch is invisible to other sessions until merged; drift-prone.
- **B. GitHub Issues + milestones** _(R3 recommends)_: one issue per epic (task
  checklist + done-when in body), GitHub milestone per M, `Closes #n` in PRs, label
  `finding` for discoveries; PLAN/DECISIONS/FINDINGS stay in repo. Agent uses REST via
  MCP. Note: GitHub Projects v2 boards are GraphQL-only and not reachable from cloud
  sessions.
- **C. Hybrid**: markdown structure, Issues for status.

Outcome: **decided 2026-10-09 — C, hybrid.** Target, decisions and plan stay markdown in the repo; tasks become GitHub Issues + milestones in the new devshop repo once it exists (phone-friendly, closed by PRs). Revamp tasks stay in `workstreams/` until then.

**Revisited 2026-10-10:** Issues + milestones live in this repo (no new repo); they start with M1.

## D-03 How devshop changes land — `decided` (rationale corrected by REVIEW-1)

- **A. Branch → PR → CI (bats) → owner merges** _(recommended)_ — gives the devshop CI
  and review; works the same locally and in cloud. (Correction: the cloud git proxy does
  **not** force this — it doesn't restrict branches; rulesets must, W0.6.) Update
  CLAUDE.md's "no PRs on devshop" rule (W0.8).
- **B. Keep `/ak-merge-devshop` local squash-to-main.**

Interim: revamp work goes through PRs on `claude/*` branches.

Outcome: **decided 2026-10-09 — A, branch → PR → CI → owner merges**, for the new repo and any remaining v1 security fixes. `/ak-merge-devshop`'s push-to-main path is retired; CLAUDE.md's "no PRs on devshop" rule is replaced (W0.8). Pacing rule: at most ~2 devshop PRs waiting on the owner at once.

**Revisited 2026-10-10:** applies to this repo for both v1 security fixes and v2 work.

## D-02 Fate of the local devcontainer — `decided`

- **A. Cloud-first, local supported via the same install script** _(recommended)_ —
  one `install-tools.sh` for cloud setup script and Dockerfile; retire the
  root-owned-copies/sticky-bit model (cosmetic on macOS, F-SEC-13) in favour of D-04;
  keep only the local fixes that close live root-escalation paths while local is used
  (F-SEC-01/02/03/13/15).
- **B. Keep local first-class with full hardening.**
- **C. Cloud-only** — use Remote Control for macOS/iOS/offline work.

Outcome: **decided 2026-10-09 — cloud-first; local = a dedicated Mac** (TARGET L2 Environments): native builds, simulators, devices, and fallback when the cloud falls short. Claude runs there as a non-admin user with only the developer accounts it needs (macOS VM only if insufficient). The v1 devcontainer + root-owned-copies model retires with v1; local services run in walled-off containers.

## D-01 Distribution model — `decided` (reopened by REVIEW-1; decided 2026-10-11 after spike W10.1.2)

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

Outcome: **open — direction set 2026-10-09:** the pinned devshop comes from the new runtime repo (D-12) with near-zero project footprint (TARGET L2 Shape). Mechanism (setup-script fetch, plugin, or user-scope install) decided after spike A-09/A-10 in M1.

**Revisited 2026-10-10:** source = this repo's tagged v2 releases (no separate runtime repo).

**Spike result 2026-10-11 (W10.1.2, LOG #16) — input for the owner's call, not a decision:** **D works with a private source.** A cloud setup script runs before the agent proxy, so it reaches GitHub directly: with a fine-grained read-only token (abra-kadabra only, Contents read) written inline in the script, it fetched a pinned commit and installed it as a user-scope plugin; the plugin's skill and SessionStart hook loaded in a lalista session. This falsifies A′'s "blocked in cloud" for setup-time fetches. Properties: zero project footprint; the pin is a SHA in the environment's setup script, and bumping it re-runs the script (environment cache rebuild); trade-offs: the token is readable by anyone using the environment, including the session (read-only, single repo — acceptable?), and the pin is per environment, not per project commit. Environment variables do not reach setup scripts, so the token can't live there.

**Spike result 2026-10-11 (W10.1.2b) — the refined option D, recommended:** one cloud environment for all projects whose setup script holds only a read-only fine-grained token + one line that clones the devshop (bare, HTTPS) into `/opt/devshop.git` and runs `bootstrap.sh` from it. The bootstrap installs a **stub plugin** whose skills are a symlink to `/opt/devshop-current`; its SessionStart hook reads the project's **`.devshop-version`** and points the symlink at that version, extracted from the local copy (no network). Version per project in code; bumping is a one-line PR; nothing in the environment to keep in sync. Limits: the local copy refreshes when the environment cache rebuilds (~weekly, or on a setup-script edit) — a newer pin warns until then; the token is readable by anyone using the environment. Ruled out: deploy keys (no ssh client, and the network policy blocks SSH); installing the real plugin from the hook (loads only next session).

**Decided 2026-10-11 (owner): option D** in the W10.1.2b form — one shared cloud environment whose setup script is a read-only token + `HEAD:bootstrap.sh`; stub plugin + SessionStart dispatcher; per-project `.devshop-version`. Built in W10.4.4. **Revisit trigger → D′** (private npm package fetched per session, no cache staleness; costs a paid private package + a CI publish step): move when D's limits bite in practice — sessions running on a stale devshop copy, or newer pins waiting on the environment cache to rebuild.

**Revisited 2026-10-12 (owner, L3 Environments, LOG #19):** **one cloud environment per project** instead of one shared by all — each holds only that project's tokens (read-only observability, Safety) and network allowlist. Every environment runs the same minimal shared setup script (read-only devshop token + `HEAD:bootstrap.sh`), which is why the shared part stays as small as possible.

## D-05 Plan tier assumptions — `decided`

Network secrets exist on Pro/Max (not Team/Enterprise yet); server-managed settings
exist on Team/Enterprise only and are "a client-side control, not a security
boundary"; Projects (plugins via Project settings) are Pro/Max beta; Workflows on all
paid plans (Pro needs a `/config` toggle). Recommendation: design for Pro/Max.

Outcome: **open — unchanged:** design for Pro/Max; revisit if a plan-tier limit blocks a spike.

Outcome: **decided 2026-10-11 — Claude Pro/Max + GitHub Pro** (owner stated). In scope: Projects,
Routines, Auto-fix, network secrets, `/web-setup`; GitHub rulesets, CODEOWNERS, auto-merge,
environments with branch policies on private repos. Out of scope: Claude Code Review (managed),
self-hosted environments, server-managed settings (Team/Ent); push rulesets, merge queue,
environment required reviewers on private repos (GitHub org/Enterprise). Consequences in
[PLATFORM.md § 5](PLATFORM.md): identity = machine user; deploy gate = "only the owner updates
`main`"; devshop reaches cloud sessions via repo files, claude.ai-enabled skills, or a VM install
at session start — no server-managed route.

## D-06 Orchestration technology — `decided` (recommendation changed by REVIEW-1)

- **A. Thin skills + deterministic gate runner as a required CI check** _(recommended)_ —
  the only place determinism is also enforcement (the agent can edit/skip in-VM scripts).
- **B. Workflow scripts** (saved `.claude/workflows/<name>.js`, invoked by name, allowed via
  `Workflow(<name>)`) — real halts and schemas in-session; no mid-run human input; newer
  surface. Optional later.
- **C. Agent SDK program** — most new code.

Outcome: **decided 2026-10-09 — thin skills + deterministic checks in CI; agentic review in-session.** PR CI runs tests and deterministic checks only (no LLM jobs, so contributors see plain CI). The adversarial reviewer is a small script running locked-down `claude -p` with read-only repo tools, invoked by the done/open-PR check itself (TARGET L2 Verify; isolation tested — A-04). Workflow scripts / Agent SDK not used.

## D-07 gstack install model and target — `open`

Recommendation: pinned copy (commit SHA) delivered with the devshop (per D-01),
upgraded to ≥ 1.91.13 in a dedicated branch with router-shim + `/ship` adaptations;
no hourly auto-update/team mode; neutralise setup's `~/.claude/settings.json` edits.

Outcome: **open — direction set 2026-10-09:** gstack used as a pinned upstream toolbox, never rebuilt or edited (TARGET L2 Shape); version/install mechanism decided with D-01.

## D-08 Stack abstraction scope — `decided` (recommendation changed by REVIEW-1)

Recommendation: **minimal now** — move vendor-specific scripts/docs under
`kit/stack/<vendor>/`, select by one `stack:` line, remove vendor names from core.
Build the capability contract / resolver / contract tests only when a real project
commits to a second stack, from two real examples.

Outcome: **decided 2026-10-09 — superseded by TARGET L2 Reach:** each stack has one home (setup, guidelines, lessons), added when a real project needs it and loaded only when a task touches it; no general capability contract up front. Second stack = iOS (lalista).

## D-10 Revamp versioning — `open`

Recommendation: freeze `v1` (D-09); v1.x patches = security fixes only; v2.0.0 at the
distribution switch.

Outcome: **open:** the new runtime repo gets its own versioning from its first release; v1 ends at `v1-final`.

**Revisited 2026-10-10:** v2 is versioned in this repo from its first release (`v2.0.0`), after `v1-final`.

## D-11 Deletion list — `obsolete`

Candidates: CLAUDE.md-placement machinery (F-DOC-05), most `adversarial-review.sh`
check-types (F-REV-06), per-gate n/a files (F-DOC-06), prose-pinning grep tests
(F-TEST-03), `/ak-handoff` (F-GS-07), `/ak-merge-devshop` push-to-main path (D-03),
manifest/symlink/lock/sync model (D-01/D-02). Under D-14 B, most move to M1.

Outcome: **obsolete 2026-10-09 (D-14):** v1 is not deleted piece by piece; it is retired as a whole once the pilot has moved to the new devshop. The candidates listed above are inputs to the lessons harvest (what _not_ to rebuild).
