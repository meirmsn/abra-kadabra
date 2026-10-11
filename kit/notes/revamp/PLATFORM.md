# Platform analysis — what Claude Code + GitHub already intend, and where the devshop fits

Researched 2026-10-11 from current official docs (code.claude.com/docs, GitHub docs source
`github/docs@main`, GitHub changelog), plus spikes W10.1 (LOG #7). Each claim names its
source page; `[inferred]` marks reasoning not stated in a doc. Purpose: stop rebuilding
platform mechanics and find the real conflicts **before** the L3 design pass (W10.2).

## 1. The intended workflows, in one picture each

### Anthropic (Claude Code cloud + desktop + Claude GitHub App)

Claude is **the developer's hands, acting as the developer**:

1. Intent in a cloud session (web/mobile/desktop/`claude --cloud`) or a **Project**
   conversation that dispatches **threads** (one cloud session + branch + PR each).
2. Session runs in a **cloud environment** (network level, setup script, env vars,
   network secrets); repo `CLAUDE.md`, `.claude/rules`, `.claude/skills` load from the
   clone; org policy via **server-managed settings**.
3. Build in Auto / Accept-edits mode; the **auto-mode classifier** refuses risky actions
   (incl. "merging a PR no human has approved, approving Claude's own PR, disabling CI").
4. Push branch → human clicks **Create PR** (Projects threads open their own).
5. AI review **on the PR, advisory**: Code Review (Team/Ent, neutral check, never blocks),
   `/code-review`, `/code-review ultra` (`claude ultrareview --json` exits 0/1).
6. **Auto-fix** wakes the session on CI failures / review comments (needs the Claude App).
7. Human merges (Desktop "Auto-merge when ready", Projects "Merge it").
8. After merge: **Routines** (schedule / API fire / GitHub `pull_request`/`release`
   events) for follow-ups; Remote Control / Desktop local sessions for machine-bound work
   (iOS Simulator pane is local-only).

Identity: everything in cloud sessions, Auto-fix, Routines, Projects "carries your GitHub
user" (routines doc). Only Code Review and `claude-code-action` act as the shared
`claude[bot]` App — with broad permissions (Contents/Workflows/Actions write).
Credentials never enter the VM (GitHub proxy); the proxy blocks tags/branch deletion and
GraphQL but **not pushes to `main`** — "use branch protection or rulesets".

### GitHub (rulesets + its own agent model)

GitHub's reference agent (Copilot cloud agent; Claude also offered there via "Agent HQ",
public preview, needs a Copilot plan) is **a separate, distrusted identity**: works only on
`copilot/*` branches, opens a draft PR, can't approve/merge or mark ready, the requester
can't approve it, workflows on its PRs wait for a human, egress firewall on, all rulesets
apply. Governance tools for anyone else: rulesets (require PR, approvals, code-owner
review, approval of most recent push, status checks pinned to an app, restrict updates,
bypass lists), CODEOWNERS, environments with branch policies.

**Plan gating that bites us (personal account, private repos):** rulesets, branch
protection, CODEOWNERS enforcement, auto-merge need **GitHub Pro** (Free = public repos
only). Even on Pro: no push rulesets (file-path rules → Team org), no environment required
reviewers / wait timers on private repos, no merge queue, collaborators are always Write.

## 2. The three philosophies side by side

| Question                    | Anthropic default                                                         | GitHub agent model               | Devshop TARGET                                           |
| --------------------------- | ------------------------------------------------------------------------- | -------------------------------- | -------------------------------------------------------- |
| Who is the agent?           | You (your GitHub user)                                                    | Its own App identity             | Its own limited identity                                 |
| Where is the hard wall?     | Your branch protection; classifier is soft                                | Rulesets + built-in agent limits | Outside Claude's reach (GitHub, CI, credentials)         |
| When does AI review happen? | On the PR, advisory, after it opens                                       | Human review on the PR           | **Before** you see the PR, adversarial, against the spec |
| What is the human for?      | Developer who drives + merges                                             | Reviewer/merger                  | Intent owner + approver                                  |
| How is process shipped?     | Plugins/marketplaces, server-managed settings, claude.ai sync, repo files | Repo settings, rulesets          | Pinned devshop, projects nearly clean                    |

The core tension: **Anthropic's cloud product assumes a trusted agent acting as you; the
devshop (and GitHub's own agent model) assume a distrusted agent with its own identity.**
Almost every conflict below is a consequence of that one difference.

## 3. Pillar by pillar — fits, overlaps, conflicts

Legend: ✅ use as is · 🔁 overlap (adopt platform, drop our version) · ⚠️ conflict (needs a
decision) · 🧩 gap (devshop must provide).

**Intent** — 🧩 gap. Platform offers plan mode, Projects conversation, gstack skills; nothing
for "spec you'd recognise + one-screen go". This is core devshop value. ✅ Projects can be the
_front door_ (one conversation, many threads) — Pro/Max only, public beta.

**Build** — ✅ cloud sessions, environments, setup scripts, subagents, skills with `paths:`
frontmatter and path-scoped `.claude/rules` (the documented "load only when relevant"
mechanism → per-stack homes). 🧩 the guidelines themselves. 🔁 v1's devcontainer/firewall
scripts → cloud environment settings.

**Verify** — ⚠️ timing conflict. Platform review is on-PR + advisory; TARGET wants it
before you see the PR. **Reconciliation:** treat **"draft PR" as "not yet for you"**
(GitHub's own agent works this way) — the session opens a draft, runs our spec-conformance
reviewer (locked-down `claude -p`, validated stable in A-04) plus optionally
`claude ultrareview --json` / `/security-review` as extra lenses, and only marks
_Ready for review_ when they pass. 🧩 spec-conformance is ours — no platform reviewer
checks against a spec (`REVIEW.md` can only steer Code Review). ✅ "PR CI stays plain" is
compatible: Code Review's check is always neutral; we just don't add `claude-code-action`.
Note: `--bare` needs an API key (F-NEW-10) → reviewer stays non-bare with
`--setting-sources ""` as tested.

**Review** — ✅ Auto-fix / PR subscriptions = the "you comment, Claude revises" loop
(🔁 drop v1 CI-watch polling). 🧩 PR body format, preview links. ⚠️ Auto-fix would also
react to the reviewer's own comments — keep the reviewer's output in the session, not as
PR comments, until ready.

**Ship** — ✅ Routines for production watch (API fire from the deploy job → a session runs
canary/metrics checks), gstack `/canary`. ⚠️ GitHub can't hold a **private** deploy for
your approval on Pro → the gate is "only you can update `main`" (ruleset B below) + deploy
secrets in a `main`-only environment. Required reviewers appear only if the repo is public
or the account moves to an org on Enterprise.

**Safety** — ⚠️ **identity**: hosted cloud acts as whoever connected GitHub. Options:
(a) machine user via `/web-setup` (supported, works on Pro/Max; makes ALL cloud work run
as the agent); (b) self-hosted runners minting per-session bot tokens (Team/Ent, public
beta, you run the runners); (c) GitHub Agent HQ's Claude agent (App identity + Copilot
protections, but runs in GitHub's sandbox, not Claude Code cloud; Copilot plan).
✅ hard walls on GitHub Pro, all with **empty bypass**:

- Ruleset A (main): require PR, 1 approval, dismiss stale, **approval of most recent
  push**, **code-owner review**, conversation resolution, required checks pinned to the
  GitHub Actions app; block force-push/deletion. CODEOWNERS `* @owner`.
- Ruleset B (main): **Restrict updates**, bypass = Repository admin _for pull requests
  only_ → only you merge, only via PR. **Optional — not applied** (2026-10-11); see
  [§ 3a](#3a-optional-ruleset-b--only-the-owner-merges).
- No repo-level secrets (an agent branch can edit or add workflows — the browser
  GitHub connection carries workflow write, PR #39 — and what they run; F-NEW-16), deploy
  secrets in environment `production` limited to `main`.
- **As applied 2026-10-11:** classic branch protection on `main` (PR required, force-push
  and deletion blocked) + `CODEOWNERS` `* @meirmsn`; the agent's direct push, force-push
  and contents-API write were all refused (LOG #10). Ruleset A's remaining items (1 approval,
  dismiss stale, code-owner review, approval of most recent push, conversation resolution)
  can be ticked on the same classic rule — no ruleset needed.
- Gap on Pro: no server-side path rules for `.github/ .claude/` (Team org needed) →
  CODEOWNERS review is the control.
  ✅ The classifier and GitHub proxy are useful **soft** layers; both docs say hooks /
  classifier are not security boundaries — matches D-04. 🔁 delete v1's in-VM guard hooks.

### 3a. Optional: ruleset B — only the owner merges

**Status:** not applied (owner, 2026-10-11). Today an approved, conflict-free PR can be merged
by the agent (PR #39 showed `mergeable_state: clean` after approval) — "your approval ships it".

**What it adds:** classic branch protection decides _whether_ a PR may merge (your approval of
the latest push); it can't decide _who_ clicks Merge — "Restrict who can push" is org-only.
Ruleset B adds that: only you can update `main`, and only by merging a PR. You gain:

- **Timing control** — approve now, merge when you choose (e.g. after watching a preview, or
  to batch releases); the agent can't merge or turn on auto-merge to land it early.
- **A second hard step** — approval _and_ your own merge, in case an approval was a slip.
- **Not gained:** protection against unreviewed code — the approval rules already block that;
  any push after your approval dismisses it.

**Cost:** you click Merge on every PR (no "approve and walk away"); one more rule to keep
consistent with the classic one.

**How to add it** (Settings → Rules → Rulesets → New branch ruleset): name `main-owner-merge`,
Enforcement **Active**, target **Include default branch**, rule **Restrict updates** only,
bypass list **Repository admin** set to **For pull requests only**. It layers on top of the
classic rule (strictest wins). **Test:** approve an agent PR, have the agent try to merge it
via the API and to enable auto-merge — both must be refused; then you merge it (A-20).

**Environments** — ✅ cloud environments by default. ✅ Mac: Desktop **local** sessions
(iOS Simulator pane is local-only) driven from phone via **Remote Control** server mode;
or a self-hosted runner on macOS (Team/Ent). 🔁 drop the devcontainer as a target.

**Reach** — ✅ per-stack knowledge as skills/rules with `paths:`; stacks added on demand.
🧩 the stack homes' content.

**Shape / distribution** — ⚠️ partial conflict. Platform ships process as **plugins**
(pinned by `sha`, validated: A-10) but in cloud sessions **repo-declared plugins never
load** and `~/.claude` from your machine isn't there. What reaches a cloud session: files
committed in the repo, claude.ai-enabled skills/plugins, server-managed settings
(Team/Ent), and anything a **setup script / SessionStart hook installs into the VM**
(`[inferred — A-09 test]`). Plugins also can't ship CLAUDE.md, rules, permissions or env —
guidelines must be skills or SessionStart `additionalContext`. Per-project pinning: the
pin has to live in the project (a one-line `.devshop-version` read by a SessionStart
hook, or the plugin `sha` in project settings) — "nearly clean", not "zero files".
🧩 repo files the platform never ships: CI template, ruleset recipe, CODEOWNERS,
`.claude/settings.json` → the new-project/upgrade step owns these.

**Orchestration (cross-cutting)** — 🔁 Projects (dispatch + tracking), Routines
(scheduling), Auto-fix (fix loop), `/loop` (in-session babysitting) replace most of v1's
`/ak-build` orchestration and status plumbing. 🧩 the ordering/stop rules (spec approved
before build; 3 failed review rounds → ask you).

## 4. What this means — the devshop's real job

The platform supplies **mechanics** (sessions, environments, credentials isolation,
wake-ups, scheduling, packaging, PR plumbing, review engines). GitHub supplies **walls**.
The devshop's durable value is **judgment + glue**:

1. Intent → spec discipline (with your one-screen go).
2. Spec-conformance reviewer before "ready for review" + the stop-and-ask rules.
3. Guidelines per discipline and per stack (skills/rules, path-scoped).
4. PR format and announcement section.
5. A bootstrap/upgrade step that writes the repo files the platform doesn't ship (CI,
   CODEOWNERS, settings, version pin) and documents the GitHub settings (rulesets,
   environments) you apply.
6. Lessons loop.

Stop building: in-VM guard hooks as security, CI-watch polling, the sync/symlink/lock
install model, `/ak-merge-devshop`-style transports, custom orchestration that Projects/
Routines/Auto-fix cover.

## 5. Decisions and checks this surfaces

**Plan tiers — answered 2026-10-11 (D-05):** GitHub **Pro**, Claude **Pro/Max**. So:
rulesets + CODEOWNERS + `main`-only environment secrets are available (the recipe in § 3
Safety applies as written); Projects, Routines, Auto-fix, network secrets are available;
Code Review (managed), self-hosted runners and server-managed settings are **not** — the
identity is the machine user, the independent reviewer is ours (plus optional
`ultrareview`), and the devshop must reach cloud sessions without server-managed settings.

**New assumptions to test (ASSUMPTIONS A-19…A-23):** Pro rulesets as specified block the
machine user's merge and auto-merge; Auto-fix / PR subscriptions / Projects / Routines work
and act as the machine user after `/web-setup`; a plugin installed by a setup script or
SessionStart hook loads in a cloud session; draft-PR + ready-for-review flow works with
subscriptions.

**Proposed plan changes (for your agreement, not applied):**

- TARGET Shape: add "Claude Code and GitHub are the platform; the devshop adds judgment
  and thin glue only where they fall short" (mirrors the gstack line).
- TARGET Verify: "before you see a PR" → "before the PR is marked ready for review".
- W10.2: start L3 from this table; W10.4/W10.5 adopt the ruleset recipe above.
- D-01 direction: plugin pinned by `sha`, installed into the VM at session start, version
  pin as one small file in the project.
- D-13: machine user now; revisit Agent HQ or self-hosted only if the plan tier changes.

## Sources (main pages)

code.claude.com/docs/en/: claude-code-on-the-web, web-quickstart, cloud-environments,
settings (cloud table), permission-modes, auto-mode-config, self-hosted-environments(-deploy,
-identity), desktop, desktop-ios-simulator, remote-control, claude-projects, routines,
scheduled-tasks, code-review, ultrareview, commands, github-actions, plugins/_, skills,
hooks, memory, headless, server-managed-settings. GitHub (`github/docs@main`):
managing-rulesets/_, about-code-owners, permission-levels-for-a-personal-account-repository,
managing-your-personal-access-tokens, deployments-and-environments, gated-features/\*,
copilot cloud agent risks-and-mitigations, about-third-party-coding-agents; github.blog
changelog 2026-04-24 / 2026-05-15 (`ghs_` token format), 2026-03-13.
