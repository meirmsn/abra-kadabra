# Revamp log

Dated journal, newest last. One entry per work session (or per task when
significant). Each entry: **what**, **evidence** (commands + result summary),
**commits**, **surprises / discoveries** (→ F-NEW ids), **next**.

---

## #1 — 2026-10-07/08 · Analysis session + plan creation

**What**

- Full read-only review of the repo (v1.38.0, `e0f082a`) via parallel deep-dives:
  enforcement layer, skill pipeline, runtime/template/sync, tests/docs/history,
  security access matrix + check taxonomy, gstack upstream delta, workflows/intent/docs
  hierarchy, multi-project/versioning, modern Claude Code features, cloud sessions,
  stack coupling. Key claims spot-verified by reading code, running commands, and
  official docs (code.claude.com/docs: cli-reference, hooks, permissions, settings,
  managed/server-managed settings, sandboxing, plugin marketplaces, cloud
  environments, claude-code-on-the-web, claude-projects).
- Created this plan: README, PLAN, FINDINGS (113 rows), DECISIONS (D-01…D-11),
  PROCESS, workstreams W0–W9.

**Evidence (baseline facts)**

- bats suite: `1..1647` tests.
  - Without `/devshop` present: 139 failures + many silent skips (tests hardcode `/devshop`).
  - With `/devshop` → checkout symlink: 18 failures — 7 `rsync: command not found`,
    9 in `preship-fault-injected-qa.bats` (516–533, empty awk output; mawk 1.3.4 here),
    1 `util-adversarial-review-narrowing.bats:589`, 1 `util-vendor-bats-libs.bats`
    (`-x` vs tracked 644).
- Reproduced/verified by hand: F-HOOK-01 (no errexit after re-exec), F-REV-01
  (`grep -qi "^FAIL"`), F-HOOK-02 (prepare-commit-msg tail), F-PIPE-01 (awk range
  returns 0 bytes), F-REV-04 (`fastJobSkipReason` absent), F-PIPE-03 (preflight
  reset at build/SKILL.md:1019), F-INFRA-01, F-INFRA-02, F-SEC-01 (parser regex
  accepts `../`), F-SEC-02 (`env_file: .env`), F-SEC-08 (`required_approving_review_count":0`),
  F-SEC-09 (`[ -x ]` on 644 file), F-PIPE-17, F-TPL-01, F-GS-02/03/05 (upstream files),
  F-CLOUD-01 (dockerd + `hello-world` ran in this cloud VM).
- Plan coverage check (scripted grep): all 113 FINDINGS rows map to a task or
  decision; every referenced task ID exists; relative links resolve.

**Environment notes**

- Cloud VM: Ubuntu 24.04, root, 4 vCPU / 15 GB; Node 22, pnpm present; no rsync,
  gitleaks, supabase CLI; Chromium 1194 in `/opt/pw-browsers`.
- Left behind in this (ephemeral) container: `/devshop` → `/home/user/abra-kadabra`
  symlink (removal needs owner approval); a `dockerd` started for the Docker check.

**Commits**

- Plan docs on branch `claude/magical-feynman-59qltk` (see PR).

**Discoveries**: none beyond FINDINGS.

**Next**: plan review session (W0.1.3) → decisions D-01…D-06 (W0.3) → M0.

---

## #2 — 2026-10-08 · Adversarial review of the plan (REVIEW-1)

**What**

- Four independent reviewers (fresh context): fact-check of FINDINGS, architecture
  attack, plan-as-a-plan critique, Claude Code/cloud/GitHub feasibility (docs + live tests).
- Orchestrator re-verified the decisive claims: git proxy branch behaviour (docs quote),
  `.gitleaks.toml` has no rules / no `[extend]`, no LICENSE file, `ci.yml` passes
  `SENTRY_AUTH_TOKEN` on `pull_request`, notify hooks unlocked.
- Applied corrections: REVIEW-1.md written; DECISIONS rewritten (D-12…D-15 added; D-01,
  D-03, D-04, D-06, D-08, D-09 revised); PLAN re-cut (M0 = stop the bleeding + groundwork;
  M1+ provisional pending D-14; testable exit criteria; capacity + cut line); W0 gained
  W0.4–W0.9; W1/W2 carry a live-risk ⚠ filter; W3 attack suites split in-VM/outside-VM and
  fixture moved to M0; W4 gained spike W4.2.0 + rollback; W5 shrunk to vendor isolation;
  W6.1 redesigned (spec lock + CI acceptance check + measured advisory reviewer);
  FINDINGS corrected (~45 rows) + F-NEW-01…14; PROCESS lightened.

**Evidence**

- R1 reproduced F-SEC-20 with gitleaks 8.30.1 (repo config → "no leaks"; default → leaks found).
- R4 ran `claude -p --bare` in this cloud VM → `Authentication error` (`is_error:true`,
  `subtype:"success"`); non-bare locked-down variant returned `structured_output`.
- R4: `gh api user` → owner; PR #36 author = owner; repo permission `admin:true`;
  fetching a non-attached private repo → 403.
- Coverage check re-run after edits (see PR): all findings mapped; all referenced IDs exist.

**Discoveries**: F-NEW-01…F-NEW-14 (see FINDINGS).

**Next**: plan review session → D-14 first.

---

## #3 — 2026-10-08 · Continuous verification + whole-picture loop

**What**: owner asked that every step be tested and that the whole picture be checked
continuously — and noted the devshop should run this same loop when building apps.
Added: [ASSUMPTIONS.md](ASSUMPTIONS.md) (16 load-bearing assumptions, 3 already falsified
by REVIEW-1, each with its cheapest test); [TARGET.md](TARGET.md) (one-page target +
north-star scenario re-run at each milestone); PROCESS § 0 "the loop" (assumptions
first · check first · walking skeleton · whole-picture review) + codification queue;
W3.5 walking skeleton as an M1 exit (confirms or revises D-14); W0.10 target +
baseline run; PLAN principle 9.

**Next**: plan review session.

---

## #4 — 2026-10-08 · Advisor / model-routing proposal evaluated

**What**: owner shared a "Opus advises, Sonnet builds, Haiku swarms" setup. Checked
against docs + one live call. Real: `--advisor`, `advisorModel`, `/advisor`; advisor
reads the full transcript; Claude chooses when to consult (no forcing setting); subagents
inherit it; per-agent `model` frontmatter; `CLAUDE_CODE_SUBAGENT_MODEL`; effort levels.
Not real / unverifiable: `--subagents` flag, "parallel dispatcher pool (3x workers)"
setting, "JEV micro-fork layer … 16 ms", "340 tok/s". Live test in this cloud VM:
`claude -p --model sonnet --advisor opus …` billed both `claude-sonnet-5-5` and
`claude-opus-5-5` (A-17 validated).
Added: O-11, O-12, A-17, A-18, epic W6.8 (routing + advisor, A/B before relying on it).

---

## #5 — 2026-10-08/09 · Plan review session (owner)

**What**

- Owner redirected the session from decision-by-decision to **top-down alignment**: one
  sentence (L0) → one paragraph (L1) → one line per pillar (L2), details (L3) later. All
  three levels agreed and written to [TARGET.md](TARGET.md); owner inputs parked for L3.
- Nine pillars: Intent, Build, Verify, Review, Ship, Safety, Environments, Reach, Shape.
  Key owner calls inside them: one-screen "go" before building bigger changes; code, tests
  and docs change together; independent adversarial reviewer before any PR, **no skip
  knobs**, 3 rounds then ask; **PR CI plain** (no agentic jobs, so outside contributors see
  normal CI); approval ships (web + backend auto-deploy; native per version via testing
  tracks, owner's call); rollback manual with a revert ready; read-only production
  observability, production data only on an explicit expiring grant; cloud-first plus a
  **dedicated Mac**; one home per stack, added when a project needs it; lean not minimal.
- Decisions: D-14 thin rewrite in a **new runtime repo** (v1 as reference, lessons harvest
  first, go/no-go at the walking skeleton); D-12 new repo private for now, public-safe by
  design; D-13 GitHub App (spike); D-04, D-02, D-06, D-08 settled by the pillars; D-09 no
  freeze needed (lalista paused, home-os frozen; lalista = pilot); D-15 hybrid; D-03 PR flow;
  D-11 obsolete; D-01/D-05/D-07/D-10 open with direction.
- Re-plan: M0 reordered (credentials → history scan → rulesets + archive home-os → tag
  `v1-final` → CLAUDE.md note); M1 = walking skeleton → go/no-go, detailed in
  [W10-v2.md](workstreams/W10-v2.md); M2 pilot lalista web, M3 iOS + Mac, M4 retire v1
  (coarse). W1–W9 superseded (`[-]`); findings dispositioned by W10.3.3.
- Pacing rule instead of capacity hours: ≤ ~2 devshop PRs waiting on the owner.

**Evidence**

- Reviewer isolation (A-04), three `claude -p` calls in this cloud VM from inside the repo:
  with `--setting-sources "" --tools ""` the context did **not** contain CLAUDE.md text
  ("NO"); with `--tools "Read,Grep,Glob"` it grepped/read the repo correctly; asked to
  write a file it could not (file absent afterwards).
- Template CI cadence: `ci.yml` runs on every `pull_request` push (fast, then slow if
  runtime changed) and on `main` pushes — the inner-loop cost the owner wants to avoid.
- v1 sizes for reference: CLAUDE.md 3.3k words; 17 devshop skills 87k words (largest
  22.8k); `kit/docs` 89k words; 64 scripts/hooks ~11k lines; `adversarial-review.sh`
  1,349 lines with 16 check-types (11 are bypass justifications).
- GitHub-identity docs (`read_documentation github.access`) don't cover using a non-owner
  identity from a cloud session → A-05 stays a spike.

**Commits**: checkpoint commits per agreed pillar on `claude/magical-feynman-59qltk` (PR #36), then this recording commit.

**Surprises / discoveries**: top-down alignment resolved most open decisions as by-products
(codification-queue candidate). No new F-NEW findings.

**Next**: M0 in order (W0.5 owner first); M1 spikes W10.1 can start in parallel.

---

## #6 — 2026-10-10 · D-14/D-12 revisited: rewrite in this repo

**What**: owner asked why a new repo was needed. Its only unique benefit was a clean history
for a possible public release; the other reasons (clean slate for sessions, v1 as reference)
are met by tagging `v1-final` and letting the first v2 PR remove v1 from `main`. Owner's
point accepted: the revamp retires the weaknesses the notes describe, and leaked secrets are
neutralised by the history scan + rotation (W0.7 → W0.5) — rotated secrets in history are
harmless. Residual item for any later public call: personal details / infrastructure
identifiers in notes, flagged by the W0.7 scan for the owner.

**Changes**: DECISIONS — Revisited lines on D-14, D-12, D-01, D-03, D-10, D-15; PLAN status +
changelog; README; TARGET Shape note; W0.7 done-when (also flag identifiers); W10.4 is now
"v2 bootstrap in this repo" (W10.4.1 = first v2 PR removes v1 from `main`).

**Note**: removing v1 from `main` changes what `/devshop` sessions load; fine while lalista
is paused, and it must happen only after `v1-final` is tagged (W0.4).

**Next**: unchanged — M0 in order, starting with W0.5 (owner).

---

## #7 — 2026-10-10 · M1 spikes W10.1 (cloud session)

**What**: ran the four W10.1 spikes as far as one cloud session can. W10.1.4 is done;
W10.1.1 and W10.1.3 are blocked on owner setup; W10.1.2 is partly done.

**Evidence**

- **A-04 reviewer stability (W10.1.4) — validated.** Fixed fixture: a 4-item `slugify()`
  spec; "seeded" case skips AC-4 (no type check, no test), "honest" case meets all four.
  Call: `claude -p … --setting-sources "" --tools "Read,Grep,Glob" --strict-mcp-config
--no-session-persistence --model sonnet --output-format json --json-schema <verdict
schema>`, 20 runs per case, 4 in parallel. Result: seeded 20/20 `fail ["AC-4"]`, honest
  20/20 `pass []`, 0 schema or exit errors, ~$0.01 and ~8 s (max 10 s) per call. Easy case
  only; hard-case precision/recall stays A-12.
- **A-05 agent identity (W10.1.1) — native path falsified.** `GH_TOKEN` in the session is a
  placeholder; the proxy injects the real credential. `gh api user` → the owner (`User`);
  response header `X-Oauth-Client-Id` = a GitHub App client id (the Claude app); branch
  protection read → "Resource not accessible by integration". PR #36: author + merger = owner;
  commits authored as the owner, committer `web-flow`. `read_documentation github.access`
  offers no other identity. Follow-up probe with fake credentials: a bogus
  `Authorization: token ghs_…` on `api.github.com` still returned the private repo (200), and
  `git ls-remote` with bogus basic auth still listed `main` — **the proxy replaces any
  Authorization header with the owner's credential**. The App token-mint path
  (`POST /app/installations/{id}/access_tokens`) is blocked by the proxy. So an App token
  cannot be minted or used from inside a session. Docs (cloud-environments § network secrets / GitHub
  proxy) rule out two more routes: network secrets are **never** attached to GitHub requests, and
  the allowlist doesn't apply to GitHub traffic. The supported route is `/web-setup`: it sends a
  `gh` token to the Claude account and **replaces** the GitHub connection for all cloud sessions
  → run it with `gh` logged in as a **machine user** (Write collaborator, no `workflow` scope).
  A GitHub App can't be used this way (no in-session minting, hourly expiry), so D-13 A narrows
  to the machine user.
- **A-06/A-07 rulesets + workflows (W10.1.3).** This repo has 0 rulesets and no branch rules
  on `main`. The proxy 403s admin paths (`hooks`, `collaborators`, `environments`,
  `actions/permissions`), so the agent cannot create or weaken rulesets via REST — the owner
  must set them. A-07: a dispatch-only workflow file pushed to the session branch was
  accepted (`97140dc`, removed in `a870fb7`) → F-NEW-16. That probe commit used
  `--no-verify`; no hooks exist in cloud anyway → F-NEW-15.
- **A-09/A-10 distribution (W10.1.2).** With an isolated `CLAUDE_CONFIG_DIR` (login still
  works): a local marketplace whose plugin entry is pinned by `sha` to commit v1 installed
  0.1.0 although the source HEAD was v2; a fresh `claude -p` used its skill ("VERSION-ONE")
  and ran its SessionStart hook; `marketplace update` + `plugin update` kept 0.1.0; moving the
  pin to v2 upgraded to 0.2.0. A project's committed `extraKnownMarketplaces` +
  `enabledPlugins` did **not** install the plugin in headless runs (agrees with F-CLOUD-02).
  A probe session without this repo attached (to re-check F-NEW-11) was refused by the
  permission classifier — F-NEW-11 stands as recorded.

**Surprises / discoveries**: F-NEW-15, F-NEW-16. A-05's native path being the owner is the
expected-but-now-observed blocker for D-13 A: CODEOWNERS / required reviews mean nothing until
a second identity works.

**Next (owner)**: (1) create the agent GitHub App (or machine user) and store its token as a
cloud environment secret → rerun W10.1.1; (2) add a no-bypass ruleset (PR required, no
force-push, path rule on `.github/`) on the fixture or this repo → rerun W10.1.3 attacks;
(3) try a setup script that clones a devshop tag with a read-only token secret and runs
`claude plugin marketplace add` + `install` → closes W10.1.2. D-01 leans to **C/D hybrid**:
sha-pinned plugin installed at user scope by the setup script.

---

## #8 — 2026-10-11 · Platform analysis (Claude Code + GitHub vs devshop intent)

**What**: owner asked why the devshop and Claude Code cloud seem to overlap or conflict.
Four parallel doc-research passes (cloud/desktop, Claude-on-GitHub, packaging/distribution,
GitHub governance) → [PLATFORM.md](PLATFORM.md).

**Key findings**: Anthropic's cloud product assumes a trusted agent acting **as you**;
GitHub's own agent model and the devshop assume a distrusted agent with its own identity —
most conflicts follow from that. AI review on the platform is on-PR and advisory (Code
Review's check is always neutral) → reconcile "before you see it" as "before ready for
review" on a draft PR. GitHub **Pro** is the minimum for any enforceable merge control on
private personal repos; private deploys can't wait for a reviewer on Pro → the gate is
"only the owner can update `main`". Repo-declared plugins never load in cloud sessions.
Projects (Pro/Max) and Code Review / self-hosted (Team/Ent) sit on different plan tiers.

**Changes**: PLATFORM.md; ASSUMPTIONS A-19…A-23. Proposed (not applied, owner to agree):
TARGET Shape "platform-first" line, Verify wording, D-01/D-13 directions.

**Next (owner)**: state GitHub plan and Claude plan; agree or amend the proposed changes;
then machine-user setup (W10.1.1) continues.

**Update 2026-10-11**: owner stated GitHub **Pro** and Claude **Pro/Max** → D-05 decided, A-19
validated, PLATFORM § 5 updated.

---

## #9 — 2026-10-11 · Agent identity working (W10.1.1 done)

**What**: owner created machine user `meirmsn-agent` (Write collaborator on abra-kadabra) and,
in a private window, disconnected claude.ai's GitHub connection and reconnected it while GitHub
was logged in as the agent — simpler than `gh` + `/web-setup`, no CLI needed. The Claude App stays
installed on `meirmsn` (repo owner); "Not installed" on the agent's own account is irrelevant.

**Evidence** (fresh cloud session, PR #39): `gh api user` → `meirmsn-agent User`; repo permissions
`admin:false, push:true`; branch push OK; PR #39 `user.login = meirmsn-agent`; PR activity
subscription OK. This session also switched to the agent (`gh api user` → `meirmsn-agent`).
**Surprise:** the workflow-file push was **accepted** — the browser connection uses the Claude
App's user token, which has workflow write, so "no `workflow` scope" isn't available on this route
→ F-NEW-16 controls move to CODEOWNERS + secret placement (A-07).

**Next**: rulesets on abra-kadabra (W10.1.3 / A-06, A-20), tested against PR #39; then close #39.

---

## #10 — 2026-10-11 · Agent can't get around `main` protection (W10.1.3)

**What**: with the owner's explicit go-ahead, tried to change `main` as `meirmsn-agent` against the
classic branch protection already on `main` (from the parallel M0 session, PR #38).

**Evidence**: direct push of an empty commit → `remote rejected … Changes must be made through a
pull request`; force-push rewinding `main` one commit → `Cannot force-push to this branch`;
`PUT /contents` on `main` → 403 "Write access to this GitHub API path is not permitted through this
proxy"; `main` stayed at `46f6b41`. A first attempt was refused **in-session** by the auto-mode
classifier ("Git Destructive") before reaching GitHub — the soft layer works as documented.
After the owner approved PR #39 it showed `mergeable_state: clean` → without a "restrict updates"
ruleset the agent can merge an owner-approved PR ("approval ships"); owner to decide whether to add
ruleset B (A-20).

---

## #11 — 2026-10-10/11 · M0: protection verified, abra-kadabra history scanned, rotation deferred

**W0.6 (owner)**: classic branch protection on `main` of abra-kadabra and lalista (require
PR, no force-push/deletion, no admin bypass). Verified from fresh clones with an empty
commit: `git push origin HEAD:main` and `git push -f` both rejected with
`GH006: Protected branch update failed … Changes must be made through a pull request`
(lalista also: `2 of 2 required status checks are expected`). abra-kadabra has no CI
workflows yet → no required check until W3.1.2. Ruleset conversion (approvals, PR-only
admin bypass, auto-merge on) waits for the agent identity → W0.6.6. home-os archive in
progress (owner); reversible, so a later cleanup just unarchives.

**W0.7 (abra-kadabra only)**: gitleaks 8.30.1 (release checksum verified), scratch config
`[extend] useDefault = true`, `--log-opts=--all --redact`, full history (unshallowed).
616 commits, 7 hits, all false positives:

- `template/.devcontainer/compose.yml` ×2, `.claude/skills/devshop/new-project/SKILL.md` —
  Supabase local-stack demo JWTs (payload issuer `supabase-demo`, checked by prefix match).
- `template/.devcontainer/.env.example` — placeholder: JWT header + `...`.
- `.claude/skills/gstack/` ×3 — upstream test fixtures + gstack's public telemetry anon key.
  No personal details or infra identifiers flagged beyond gstack's own project URL. lalista
  and home-os not reachable from cloud sessions (Claude GitHub App not installed) → pending.

**W0.5 (owner decision)**: deferred to the end of the revamp — nothing was committed, the
apps aren't in use, old dev envs are stale, Supabase project is frozen. Key insight:
revoking needs no dev env (dashboard delete), so the end-of-revamp task is "revoke all,
reissue as needed" (W0.5.3). Optional now: revoke the old GitHub PAT (W0.5.2) — it's
account-wide and not tied to the paused apps.

**Next**: agent identity is done (`meirmsn-agent`, LOG #9) and protection holds against it
(LOG #10) → owner installs the Claude GitHub App on lalista + home-os → finish W0.7.1 →
W0.6.6 ruleset (with the A-20 call) → W0.4 tag.

---

## #12 — 2026-10-11 · Owner calls after the identity work

**What**: owner confirmed the classic rule on `main` also requires 1 approval, code-owner review,
approval of the most recent push, dismissal of stale approvals and conversation resolution (A-06),
and chose **"approval ships"**: ruleset B (owner-only merge) deferred, documented in
[PLATFORM § 3a](PLATFORM.md#3a-optional-ruleset-b--only-the-owner-merges). PR #40 was merged by
the agent after the owner's approval. → W10.1.3, W10.4.3 done; W0.6.6's ruleset conversion is
not needed (same options on the classic rule); its remaining checks (auto-merge waits for
approval, a push after approval dismisses it) fold into the walking-skeleton run (W10.6.4).
The A-04 reviewer fixture is kept in [`spikes/a04-reviewer/`](spikes/a04-reviewer/) for W10.6.2.

---

## #13 — 2026-10-11 · Contribution credit test; agent identity goes on trial

**What**: owner noticed the agent identity moves their GitHub contribution history to the agent.
Test on PR #42: one branch commit authored as the owner, squash-merged by the owner with the
default message — the `main` commit was authored by `meirmsn-agent` with
`Co-authored-by: meirmsn`; afterwards the owner's profile gained only the review, the agent's the
commit and opened PR. GitHub's docs confirm it: a commit counts only for the email that **authored**
it on the default branch; "or co-author" applies to GitHub Enterprise Server only; rebasing credits
original authors + the rebaser (but rebased commits aren't signed); squash's author isn't documented
— observed = PR author (#41).

**Considered and dropped**: rebase/merge-commit merges (clutter `main`, need commit-count limits);
owner opens each PR + admin-override merge (works, but awkward). **Decision**: keep the machine-user
setup as a **trial until 2026-10-25** (or W10.6), then keep or switch back (steps in D-13; A-24).

---

## #14 — 2026-10-11 · M0 wrap-up: CLAUDE.md revamp note, all histories scanned, `v1-final` tagged

**W0.8.1 done**: `CLAUDE.md` opens with a 10-line `## Revamp mode` section (PROCESS.md, PRs to
`main`, v1 tooling not used, v1 frozen at `v1-final`, this section wins). The three
contradicting v1 lines (`/ak-status` first, no-PR shipping flow, "don't propose a GitHub PR on
devshop") are annotated as superseded.

**W0.4.1 done (owner-pushed)**: `git push origin refs/tags/v1-final` from the session →
HTTP 403 (the session's git proxy only accepts pushes to the session branch; the GitHub tools
have no tag creation). The owner pushed the annotated tag; verified with `git ls-remote`:
`refs/tags/v1-final^{}` = `525cd49`. Side note: the owner's local clone used an HTTPS remote
that relied on the stale dev env's token, so the push prompted for a username; switching the
remote to SSH fixed it. Lesson for v2: tags/releases are an owner (or CI) step, not something a cloud
session can do.

**W0.7.1 done**: once the agent had access to lalista and home-os, all three histories were
scanned with gitleaks 8.30.1 (release checksum verified), scratch config
`[extend] useDefault = true`, `--log-opts=--all --redact`, full clones **plus every PR head ref**
(`refs/pull/*/head`). The PR refs matter: squash merges delete branch history, so lalista goes
from 93 to 567 commits and home-os from 39 to 411; abra-kadabra 616 → 770 (LOG #11 missed them).

| Repo         | Commits | Hits | Verdict                                                                                                        |
| ------------ | ------- | ---- | -------------------------------------------------------------------------------------------------------------- |
| abra-kadabra | 770     | 7    | same 7 false positives as LOG #11                                                                              |
| lalista      | 567     | 6    | Supabase demo JWTs (`iss=supabase-demo`, anon + service_role) ×5, `.env.example` placeholder (JWT header only) |
| home-os      | 411     | 4    | Supabase demo JWTs ×2, `.env.example` placeholder ×2                                                           |

Hits were classified by decoding only the JWT payload's `iss`/`role`/`ref` (no values printed).
Nothing to rotate. **Flagged for D-12** (not secrets): Supabase project refs for lalista (also
3× in abra-kadabra) and home-os; Vercel production + preview URLs incl. the team slug; lalista's
Sentry org ingest id (DSN key elided); owner email in commits/docs. Lesson for v2's scanner
(W10.4.1): scan PR refs too, not only branches.

**Owner call**: W0.5.2, W0.5.3, W0.6.2, W0.6.3 deferred to the end of the revamp; not raised
again until then.

**Owner calls on project references**: abra-kadabra's history mentions lalista/home-os in 303
commits (174 files on `main`; ~9 hold specific identifiers). Not cleaned: if the repo goes
public, re-scan for secrets and rotate hits only (D-12 revisited). For v2: never project identifiers
(URLs, project refs, team slugs, Sentry ids) in the devshop; project context only where it
explains a change (seeded into W10.3.1).

**M0 tasks done** (deferred owner steps moved to M4 exit, PLAN changelog). **Next**: M0 exit
review (PROCESS § 5, light — no skeleton to re-run yet) once this PR merges, then W10.3.1. Meanwhile
W10.3.1 (lessons harvest from v1).

---

## #15 — 2026-10-11 · M0 exit review

Light review per PROCESS § 5 — no skeleton exists yet, so step 1 (north-star re-run) starts at M1.

**Exit criteria** (PLAN, as amended in #14): review session held (W0.1.3) ✓; history scanned with
a working config, all three repos incl. PR refs (W0.7.1) ✓; no-bypass protection on abra-kadabra
and lalista verified by rejected pushes, also as the agent (W0.6.1/.5) ✓; `v1-final` tagged and
verified with `git ls-remote` (W0.4.1) ✓; CLAUDE.md revamp note merged (W0.8.1, PR #44) ✓.
Owner-deferred steps sit in the M4 exit. **M0 done.**

**Assumptions M1 builds on that are still untested** — each gets its cheap test before the
task that needs it:

| Assumption                                          | Needed by             | Test where                       |
| --------------------------------------------------- | --------------------- | -------------------------------- |
| A-08 committed hooks/permissions apply in cloud     | W10.4.1, W10.5.2      | fixture, first cloud session     |
| A-09/A-22 pinned install loads in a cloud session   | W10.4.4, W10.6.1      | W10.1.2 owner setup-script step  |
| A-11 Supabase starts fast enough in cloud           | W10.5.2 (pilot stack) | `supabase start` on the fixture  |
| A-25 (new) CI can create the tags/releases that pin | W10.4.4               | tag-on-merge workflow on fixture |
| A-16 CI fast enough · A-23 draft→ready gate · A-15  | W10.6                 | the skeleton run itself          |

A-12 (reviewer precision) and A-13 (gstack) are M2+/M4 concerns; A-24 trial runs to 2026-10-25.

**Direction**: nothing learned in M0 contradicts TARGET L0–L2. Two inputs for M1 design:
(1) a cloud session can push only its own branch — no tags, no other branches — so anything
v2 publishes (version tags, releases) must come from CI or the owner (A-25, feeds D-01);
(2) v2's secret scan must cover PR refs, not just branches (W10.4.1). Plus the owner's rule:
never project identifiers in the devshop (W10.3.1). Open findings get walked as part of
W10.3.3 (every row dispositioned), so not repeated here. Metrics re-baseline: none for v1
(W0.2.1 dropped); v2's first numbers come from W10.6.4.

**Next**: W10.3.1 lessons harvest (Claude). Owner, when ready: W10.1.2 setup-script spike,
W10.2 L3 design pass.

---

## #16 — 2026-10-11 · W10.1.2 setup-script spike prepared

**Done**: probe plugin (one skill, one SessionStart hook) + a pasteable `setup.sh` in
`spikes/w10-1-2-install/`, with owner steps for two runs. The script fetches a pinned commit
(routes: attached clone → git + token → REST + token → git without a token), then
`claude plugin marketplace add` + `install` at user scope, logging to `/tmp/devshop-setup.log`.

**Verified in this session** (isolated `CLAUDE_CONFIG_DIR`): routes 0 and C fetched the pin
(this repo is attached here); install succeeded; a fresh `claude -p` ran the skill and the hook.
The plugin is read in place from the fetched tree, so that tree must persist.

**Discovery — the planned D-01 route likely fails.** The GitHub path enforces the session's
repo scope independent of the client's Authorization header: a git fetch of the attached repo
with a bogus token succeeded (the proxy supplies its own credentials), and a non-attached
private repo got the proxy's 403 "GitHub access to this repository is not enabled for this
session" via REST with and without a token header. A user token in the setup script therefore
probably can't open abra-kadabra from a project session. Further probing of other GitHub hosts
was stopped by the permission classifier (read as exfiltration scouting) — not pursued.

**Implication for D-01** if Run 1 confirms: the remaining routes are (a) devshop attached as a
second repo, setup script installs the pin from its clone — costs repo `settings.json` hooks
(F-CLOUD-02) but user-scope plugin hooks may still load (Run 2 tests this); (b) claude.ai-synced
plugins (pinning untested, A-10); (c) a public runtime part (D-12 — owner: not soon).

**Next (owner)**: Run 1 and Run 2 per the spike README; revoke the token afterwards.

**Owner run, 2026-10-11 10:28 (session on abra-kadabra):** `FETCH FAILED`. Three facts from the
log: (1) the session repo is already cloned at `/home/user/<repo>` when the setup script runs;
(2) the setup script runs **without the agent proxy** (`HTTPS_PROXY` empty) and with no GitHub
credentials — git got GitHub's own "could not read Username", so GitHub is reached directly and
the in-session proxy scope check does not apply there, which reopens the token route; (3)
`DEVSHOP_READ_TOKEN` was empty in the setup script, while this session (same environment) sees it
set — so environment variables may not reach the setup script (to confirm). Route 0 failed because
the pin is a PR-branch commit, absent from the clone, and couldn't be fetched without credentials.
Script fixed to log route-0 reasons and a no-auth reachability check.

**Owner runs 2–3, 2026-10-11:** Run on lalista with the token as an environment variable →
`FETCH FAILED`, `token set:` empty, `github.com reachable: 200`. Docs confirm: environment
variables are read when Claude Code starts, after the setup script; the setup script runs once
per environment and is snapshotted (re-run on script/network change or ~7 days). Token moved
inline into the setup script → **passed**: `A:git+token`, plugin 0.1.0 installed at user scope
from `/opt/devshop-pin`, SessionStart hook ran and injected its line, skill listed as
`devshop-probe:devshop-probe` and ran. Docs had suggested only repo/server-managed hooks run in
cloud — user-scope plugin hooks run too. **W10.1.2 done**; A-09, A-22 validated; D-01 gets the
spike result (option D viable with a private source). Residual for W10.4.4: confirm a second
session started from the cached snapshot still has the plugin. Owner: revoke the spike token
when done with the environment.

**Owner run 4, 2026-10-11 11:44 — cache reuse:** a second lalista session in the same
environment had the plugin installed and enabled from `/opt/devshop-pin`; the hook ran again and
injected its line; the skill ran. The hook log still held the first session's 10:45 entry, so the
VM started from the cached filesystem rather than a clean re-run of the setup script. Residual
closed.

**W10.1.2b, 2026-10-11 — thin, code-based install (owner: minimum UI work, version in code).**
Local findings: a plugin installed by a SessionStart hook loads only in the _next_ session; a
stub plugin whose `skills` is a symlink switched by its SessionStart hook works in the _same_
session, including skills present only in the new target. Per-project pin via
`.devshop-version`, default fallback, and bad-pin handling verified locally. Owner runs: (1) no
`ssh` in the image; (2) with `openssh-client` installed, `ssh.github.com` doesn't resolve and port
22 times out — the network policy allows HTTPS only, so deploy keys are out; (3) HTTPS + read-only
token → **passed**: clean clone, bootstrap from code, `DEVSHOP: using … from environment default`,
pinned version's hook ran, skill resolved to the same commit. Bootstrap priming also ran the
runtime hook once during setup — fixed. D-01 gets the refined design as the recommendation.

**W10.1.2b final form, 2026-10-11 13:02 (after #46 merged):** the environment setup script is two
generic lines — clone with the token, then `show HEAD:bootstrap.sh | bash` (root entry point on
`main`; names no branch, path or version). Owner run on lalista passed: clean clone; token absent
from `/opt/devshop.git/config` (remote rewritten); `DEVSHOP: using HEAD (7fa3832…) from
environment default`; the version's hook ran **once**, at session start (priming fix confirmed);
probe skill resolved to the same commit.

---

## #17 — 2026-10-11 · W10.3.1 lessons harvest from v1

**What**: [lessons.md](lessons.md) — 72 lessons carried, 52 "considered, not carried" (after the owner's review; 64/62 at first draft), grouped by
TARGET pillar plus a by-stack section (web, Next.js, Supabase; no Vercel-only lesson met the bar).
Seed requirement L-01 (no project identifiers in the devshop) listed first with its v1
counter-examples by path:line and kind only.

**How**: six parallel read-only mining passes, each against a shared brief (bar, pillar list,
identifier rule, FINDINGS cross-ref): core guides · ops/architecture/stack guides ·
FRICTION-LOG + TODOS + CLAUDE.md · ROADMAP + CHANGELOG + BUILD-LOG · pipeline skills' incident
notes · ship-side skills + identifier hunt. ~165 candidate lessons merged and re-judged against the
bar into 64; single-incident project rules went to "not carried" (14 of them marked ↻ for a
re-check against home-os in W10.3.2).

**Evidence**

- Every lesson has a pillar, a scope and a source (scripted check: 64/64, IDs sequential, no
  dangling `L-nn` refs).
- 169 `path § heading` citations resolve to a real heading in the cited file (scripted; the
  three misses were a line-wrap artifact ×2 and one bold-paragraph "heading", re-cited).
- `lessons.md` has no URL, project ref, team slug, org id or email (grep for host/ingest/email
  patterns: only the generic words in L-01's own rule text).
- Identifier counter-examples checked by kind without printing values: `extract-prod-url.sh` +
  bats, go-live, new-project and four notes/trackers hold real project hosts or a project ref;
  `kit/ROADMAP.md` uses placeholders only (its one Sentry-shaped id is a well-known placeholder
  shared with gstack tests).
- v1 sources are unchanged since `v1-final` (`git diff v1-final HEAD` on them is empty), so
  path:line citations are stable.

**Surprises**

- The clone is shallow, so the original incident commits are mostly out of reach; citations lean on
  the incident notes v1 wrote down. Good enough for the bar, but W10.3.3 shouldn't expect SHAs.
- The strongest lesson by count (L-09, could-not-run is never a pass) bit 10+ times across both
  projects and the devshop, through at least five different mechanisms; v1 kept fixing instances.
- The identifier leaks came from the "worked incident" habit (paste the failing line verbatim into
  code, tests and skills) plus the lack of structured project config (L-47).

**Owner calls (PR 47 review)**

- Supabase migrations keep rollback blocks, and CI tests them (L-59); forward-only was not chosen.
- The bar also admits a **nasty** single incident (reached users or production, or failed silently
  and took real time to diagnose). That moved 9 one-incident rules up: 7 new lessons (L-65–L-71:
  realtime wrapper errors, auth error capture, first-prod smoke, env trimming, public assets + real
  mail client, RLS policy coverage, auth defaults) and one folded into L-56 (optimistic failure
  path). 5 mild ones stay ↻ for W10.3.2 (4 after L-72).
- L-01 also covers **personal identifiers** (handles, emails): v1's real-identity test fixture and
  hard-coded push URL needed neither.
- **Interactive controls** get a full state contract (L-72, owner requirement): clear affordance,
  hover change, immediate press state, a processing state past a threshold, restore on failure.
  It replaces the ↻ "iOS press cue" row, which now leaves 4 ↻ rows for W10.3.2.

**Next**: W10.3.2 (home-os lessons; re-check the ↻ rows), then W10.3.3 (disposition every FINDINGS
row; lessons cite FINDINGS ids to speed it up).

## #18 — 2026-10-11 · W10.3.2 lessons harvest from home-os

**What moved**: W10.3.2 done (PR 50). home-os was attached to the session read-only and mined in
three passes: root docs, migration headers and CI comments by hand; `specs/` (16 features' gotchas,
review findings and gate shards) and the PR history (all 57 PRs listed, the 32 non-dependabot
bodies and comments read; no issues, no human review threads) by two delegated readers, with
their key claims re-checked against the files. Result in [lessons.md](lessons.md): **10 new
lessons** (L-73–L-82), home-os evidence added to **15** existing ones, 11 home-os rules recorded
as not carried.

- New: conditional UI as a state table (L-73, moved up from ↻), server enforces client limits
  (L-74), one rule one implementation (L-75), code-prescribing specs checked against the code
  (L-76), test data from the schema (L-77), design tokens resolve (L-78), Playwright `page.request`
  (L-79), async tests wait on state (L-80), safe redirect targets (L-81), Supabase functions run as
  the caller + upstream advisor in CI and on production (L-82).
- Widened: L-66 from auth callbacks to every server error path (second production bite: a `42501`
  shown as a 404); L-24 now requires production's schema to be reproducible from migrations; L-71
  adds the preview origin, a real SMTP provider and a per-environment magic-link proof; L-72 adds a
  44 px target owned by the shared primitive.
- ↻ rows: shown/hidden tables moved up (L-73); page-level `getUser()` **refuted** (the race behind
  it was a misdiagnosis, the real cause a missing grant); Host-header redirects and primitive sizes
  stay not carried. L-56 got no new evidence either way.

**Evidence**

- 82 lessons, IDs 1–82 each defined once, no dangling `L-nn` references (scripted).
- No URL, project ref, team slug, deploy or project id, handle or email from home-os in
  `lessons.md` (grep for host, ref, slug and id shapes plus home-os's own values; the only URL-like
  hits are generic: `*.supabase.co`, a loopback address, `http://`/`https://` as scheme words).
- Prettier clean on the changed docs (same version as base passes).
- Spot checks of delegated claims against the source: PR 22's body (the speculative race fix),
  migration 016's header (41 warnings), the advisor gate results in three review files.

**Surprises**

- home-os's custom advisor probe was worse than "couldn't run": the one time it connected it
  reported per-row `auth.uid()` as clean over 20 offending policies. Strong evidence for L-11 and
  for using upstream lints (L-82). Its template copy is v1 (frozen); W10.3.3 dispositions F-VER-04.
- Rollback blocks, not flaky tests, were home-os's dominant CI cost (~20 cycles over 8+ PRs). The
  owner kept rollbacks in PR 47; L-59 now notes the round-trip must be cheap to run before pushing.
- Two production bugs (PR 22, PR 24) were hot-fixed by pasting SQL into the production editor, and
  a function existed only in production — the drift class L-24 now covers.

**Next**: W10.3.3 (disposition every FINDINGS row).

## #19 — 2026-10-11 · W10.2 L3 design pass: all nine pillars

**What moved**: W10.2 started (`[~]`) in parallel with W10.1.2 and W10.3.1, which both landed
mid-session (D-01 decided; `lessons.md` done) — the branch was brought up to `main` and the
Intent bullets re-checked against the harvest. **Intent L3 agreed** with the owner in chat and
written to [TARGET.md § L3](TARGET.md#l3--a-few-bullets-per-pillar).

- Cross-pillar rule (owner): the chat surfaces things and collects answers; decisions are then
  recorded where they belong (spec, PR, decision log) and that record is the source of truth.
- "Go" is needed for every change except bug fixes; no-change requests (analysis, status) need none.
- Upstream gstack `/spec` (checked at 1.91.8: an interview skill whose output is a GitHub issue
  plus a local archive, with a Codex quality gate) is used for the interview and draft only; the
  spec file in the project's `specs/` is the record. Our adversarial spec review replaces its
  Codex gate.
- New: adversarial review of the spec before the "go" (v1 had none). Harvest lessons folded in:
  L-02, L-03, L-19, L-20, L-73, L-76.
- v1's stop-and-ask category list dropped, kept by reference as the starting point for possible
  future spec auto-approval.

- **Verify agreed:** one reviewer script (fresh, locked-down `claude -p`, read + run, never write)
  for the spec review and the final review, started by a hook; diff checked against spec and intent
  first, then the lenses; medium-or-unsure findings fixed, low listed; same checks run in the
  session for speed, GitHub CI repeats only the deterministic part (now incl. an acceptance→test
  mapping check). D-06 unchanged.
- Discussed and deferred: an air-gapped reviewer (owner-only repo, GitHub runners, separate
  identity, required check) as the wall against a rogue agent — recorded in
  [PLAN.md § After the revamp](PLAN.md#after-the-revamp). Until then the in-session reviewer covers
  corner-cutting; GitHub rules, plain CI and the owner's approval are the walls against a rogue
  agent.

- **Review agreed:** summary → announcement → what you should know → evidence → collapsed
  details; preview link = the deploy platform's self-updating PR comment; approval ships by
  default unless the owner says wait or Claude flags a reason to hold.

- **Safety agreed:** walls outside the session; least-privilege read-only observability tokens;
  production-data grant = principle now, mechanism at M4 (red flags checked, none blocking);
  prefer the platform's own controls, recorded per stack home — Cloudflare first (likely default
  platform for new projects).

- **Build agreed:** one central agent writes the change (helpers read-only); guidelines loaded per
  discipline + stack home + project; the end state of the test suite must describe the new
  behaviour (existing tests reviewed, edited, removed, added). Verify's tests and docs lenses
  sharpened: a test that passes against broken code is a finding; every deleted or loosened test
  must be justified by the spec. v1 non-negotiables re-decided (headers dropped; responsive +
  light/dark cross-platform).
- Docs get the same end-state rule and adversarial depth as tests; related tests/docs are found by
  layout + tool lookups (related-tests mode, coverage, name search) + spec→test links, not a
  hand-kept index; the docs map is checked by CI.

- **Ship agreed (2026-10-12):** merge on approval + green checks by default; canary now + a
  next-day follow-up check; both rollback paths prepared and checked (revert PR with green CI;
  previous deployment confirmed healthy); product metrics added only where existing ones don't
  cover the new functionality.

- Ship amended: migrations backward-compatible by default; destructive steps separate, with a
  CI-tested reverse migration or a confirmed restore point.
- **Environments agreed:** least-privilege network allowlist; **one cloud environment per project**
  (D-01 revisited) running the same minimal shared setup script; work survives only in GitHub.

- **Reach agreed:** one home per stack, loaded only when touched; stacks detected from the project's
  files (new projects: from the agreed plan); every stack home proven by a fresh scaffold's CI.
  Cloudflare home comes with the owner's personal website, started in parallel once lalista begins
  moving (M2).

- **Shape agreed:** D-10 decided (SemVer from `v2.0.0`, release PR via release-please, CI tags);
  D-07 decided (gstack pinned per devshop release, never edited). Devshop ledger = GitHub issues on
  the devshop: Claude asks the owner, attaches the devshop with `add_repo`, files or comments (A-26,
  untested; if it can't be made to work when built, ask the owner). Test: the GitHub proxy returns
  403 for any repo not attached to the session, even with a caller-supplied token — so attaching is
  required. A routine fired from the project session was considered (same reach, more to build).
  New finding F-NEW-17: the session tools are a separate channel that can start sessions or attach
  other repos — Safety bullet 9.

**Next**: W10.2.2 north-star rewrite (all nine pillars).

## #20 — 2026-10-12 · W10.2.2 north-star rewritten — W10.2 done

**What moved**: PR #51 (L3 for all nine pillars) merged on the owner's approval. The north-star
scenario in [TARGET.md](TARGET.md#north-star-scenario-re-run-at-every-milestone-review) is
rewritten to exercise all nine pillars: a status question with no spec; a two-line idea through
`/spec`, spec review and "go"; planted failures the reviewer and CI must catch (untested acceptance
item, skipped state-table row, loosened test); a spec-changing PR comment; bypass attempts GitHub
must reject; ship with canary, next-day check and an executed rollback drill; environment, reach and
shape checks (budget, plain clone, guided upgrade, ledger flow).

- Owner decisions: M1 exit = steps 1–6 pass (minus next-day check and rollback drill); the rest
  baseline at M1, pass by M2. The rollback drill is executed for real on the fixture. Owner
  touchpoint target: "go", genuine decisions, approval — anything else counts as friction.

**Next**: W10.3.3 (FINDINGS disposition, Claude) and W10.4/W10.5 (v2 bootstrap, fixture — owner
steps), toward the walking skeleton W10.6.

- **Adversarial review of the scenario** (fresh-context reviewer, same day): as first written, the
  agent under test planted the failures, ran the attacks and graded itself. Hardened: plants from
  an owner-held pool applied by script after the builder finishes, a named detector per plant and
  two new plants (false "verified by review", silent rewording); GitHub's refusal + `main` SHA as
  evidence and five more attacks (branch-protection edit, push after approval, auto-merge, guarded
  paths, planted secret); injection through fetched content; synthetic traffic + a planted
  production fault that triggers the rollback drill (owner executes); a fresh idea each run from a
  reset fixture; stale-verdict check; observable stack loading with a decoy; touchpoints counted
  from the owner's own events. M1 bar gains the reviewer eval (A-12) and timings (A-11, A-16).
- **Platform constraints found and checked:** Vercel Hobby blocks deploys of agent-authored commits
  on private repos (F-NEW-18); Supabase Free pauses after ~7 days idle (F-NEW-19). Owner: the
  **fixture moves to Cloudflare** (Workers + D1, Action-based deploy; A-27) — Cloudflare becomes the
  first stack home; lalista's Vercel/Supabase plans become an M2 precondition. New tasks W10.5.3
  (north-star harness) and W10.6.5 (reviewer eval).

## #21 — 2026-10-12 · W10.3.3 every finding dispositioned

**What moved**: W10.3.3 done (PR 55). [FINDINGS.md](FINDINGS.md) has a **v2 disposition** column; all 134
rows (122 findings + 12 opportunities) carry exactly one of: **v2 requirement** (82 — Shape 21,
Safety 21, Verify 19, Reach 7, Environments 6, Build 5, Intent 2, Ship 1), **not applicable to v2**
(15 — platform facts already designed around, and opportunities L3 didn't adopt), **won't fix — v1
retired** (37 — bugs in v1 machinery v2 drops: devcontainer locks and sudo, husky, bypass
trailers, `release.sh`, `/ak-*` skills, sync). Each requirement names its `L-nn` and TARGET L3
bullet. Rule of thumb: when a lesson cites the finding and its rule prevents the bug class, it is a
requirement; when only the mechanism was broken and v2 has none, it is won't fix.

**Evidence**

- A scratch script lists every `F-*`/`O-*` table row and checks the column: before, 134 missing;
  after, 0 missing, no duplicate ids. Proven to fail: blanking one cell in a copy exits 1 and names
  the row. Its first run also caught its own bug (escaped `\|` in three findings split the cells).
- Prettier 3.8.1 clean on FINDINGS.md; only table rows and the header note changed.

**Surprises — requirements with no explicit home in TARGET L3 or lessons.md** (flagged on the PR,
TARGET not edited): the devshop's own changes getting the security lens (F-SEC-17); the reviewer
ignoring test-only overrides in real runs (F-HOOK-10); gstack's setup not clobbering the devshop's
SessionStart hook, and a minimum gstack version (F-GS-08, F-GS-04); licensing if the devshop goes
public (F-NEW-13).

**Next**: W10.4 v2 bootstrap (W10.4.1 in progress in a parallel session); owner: W10.5.1.

## #22 — 2026-10-12 · Owner calls on the four W10.3.3 gaps

**What moved**: the owner decided the four requirements LOG #21 found without a home (PR 55):
the devshop's own changes go through the same reviewer, security lens included (F-SEC-17 →
TARGET Verify 9); the reviewer's model, prompt and tools come only from the pinned devshop, with no
test switches in real runs (F-HOOK-10 → TARGET Verify 3); gstack's install must leave the
`DEVSHOP:` hook working and `/autoplan` running — a W10.4.4 done-when and part of every gstack
upgrade smoke check, not a TARGET rule (F-GS-08, F-GS-04); a license with third-party notices
joins the "may go public" conditions (F-NEW-13 → TARGET L2 Shape, DECISIONS D-14). FINDINGS
dispositions updated to point at the new homes.

**Evidence**: the disposition check from PR 55 still passes (134 rows, 0 missing); Prettier clean.

**Next**: W10.4 v2 bootstrap.

## #23 — 2026-10-12 · W10.4.1 first v2 PR: v1 off `main`, working secret scan

**What moved**: `v1-final` checked first (annotated, peels to `525cd49`, as #14 says); since it,
only `CLAUDE.md`, `bootstrap.sh` and the revamp notes changed. Removed 1729 v1 files (`.claude/`
incl. vendored gstack, `.devcontainer/`, `.husky/`, `kit/` except `kit/notes/revamp/`, `specs/`,
`template/`, root `BUILD-LOG.md`/`PLAN.md`, Node/lint tooling). Kept `kit/notes/revamp/` as is,
`bootstrap.sh` (the cloud environments' entry point — the W10.1.2b spike it delegates to stays, a
local dispatcher run against the new tree still prints `DEVSHOP: using …`), `CODEOWNERS`,
`.editorconfig`, `.gitattributes`, `.prettierrc`, `.vscode/` (now formats on save). New: v2
`CLAUDE.md`, `README.md` (layout), `docs/README.md` (docs map), `.gitleaks.toml`
(`[extend] useDefault = true`), `scripts/secret-scan.sh`, `tests/`, CI (`ci.yml`).

**Evidence**: `tests/gitleaks.test.sh` plants five generated fake secrets — against v1's config it
fails ("expected exit 1 (leaks found), got 0": F-SEC-20 reproduced), with the new config all five
are caught and a clean repo passes; 50/50 runs stable. `tests/secret-scan.test.sh` proves the CI
scan fails on secrets added, added-then-removed and uncommitted, and fails closed on a bad base or
missing gitleaks; six mutants of the script (and the v1 config) all killed. `/security-review`: no
findings. CI result on the PR.

**Owner calls in the session**: v1's husky/lint-staged/ESLint setup is not ported (its few lessons
are recorded already; no stub files kept). An adversarial review of the hooks plan reshaped it.
Hand-offs, not done here:

- **W10.4.2**: pinned `prettier --check`, shellcheck, typecheck once there's code, a CI check
  rejecting fixture-identity commits (L-41), the docs-map link check.
- **W10.4.4**: SessionStart runs the detected stack's dependency install (timeout, loud `DEVSHOP:`
  on failure); a session-local `core.hooksPath` to devshop-owned git hooks (chaining to the
  project's, husky included) with a pre-push `gitleaks git` over unpushed commits; optionally a
  PostToolUse formatter step using only the project's own formatter. `bootstrap.sh` should take
  the repo URL from config, not a hard-coded account (L-01).
- **JS/TS stack home (W10.5.2)**: pinned Prettier + ESLint `recommended`, formatting left to
  Prettier; `lint-staged --no-stash` if ever used (v1 `BUILD-LOG` § lint-staged-rename-symlink);
  hooks under bash strict mode (L-11); start from `v1-final:template/eslint.config.mjs`.
- **Rollback-prose lint** → Supabase stack home (M2). `lessons.md` L-41 could gain the
  `--no-stash` lesson (follow-up; that file was out of this session's scope).

**Surprises**: links from the revamp notes into v1 paths now resolve only at `v1-final`; the CI
scan is the only scan until W10.4.4 (a secret can reach a pushed branch before CI flags it).

**Next**: owner marks `ci / secret-scan` required (W10.4.2); W10.4.4. (PR #57)

## #24 — 2026-10-12 · W10.4.4 part 1: the install moves out of spikes/, dated `DEVSHOP:` lines

**What moved**: the W10.1.2b design now lives in `install/` (bootstrap, stub plugin, dispatcher:
read from `main` when the environment cache builds) and `runtime/` (what a project's
`.devshop-version` selects: `skills/`, optional `hooks/session-start.sh`). Root `bootstrap.sh`
keeps its path and only delegates; the two-line setup script is unchanged. Every `DEVSHOP:` line
ends with the local copy's date and age (the bootstrap records it). The bootstrap keeps the URL the
clone used, without the token, instead of a hard-coded account (L-01). Malformed pins are refused
before git sees them. The spike files stay as notes, and environments cached before this keep
running the spike stub until their next rebuild. First runtime skill: `devshop-version`.

**Evidence**: `tests/bootstrap.test.sh` written first. It replays the setup script (local bare
clone; second line verbatim) in a private mount namespace with a scratch `/opt` and `/tmp`, then
runs the installed hook. On the old main it passed HEAD, pinned SHA, unknown pin and pre-move pin.
The new checks failed there first: URL kept the hard-coded account, lines carried no date. They
pass after the move, and a missing copy date that first read as "0 days old" is fixed. 7 mutants of
the install all killed. The real `claude` CLI (overlay on `/opt`) installed the plugin, listed
`devshop:devshop-version` and showed the dated line in context.

**Owner calls in the session**: gstack gets its own PR next, then the git hooks; stack-detected
dependency install goes to W10.5.2; PostToolUse formatter parked.

**Next**: owner's fresh-session check (PR checklist) → W10.4.4 stays `[~]`; pinned gstack. (PR #59)

## #25 — 2026-10-12 · W10.5.1 fixture repo, Cloudflare account and cloud environment (owner)

**What moved**: the owner set up the fixture step by step, with Claude checking each step from the
session as the agent identity. The fixture is the private repo `devshop-fixture` (public-safe
content: a README and CODEOWNERS so far), with the agent as a Write collaborator, classic
protection on `main` like this repo (PR, 1 approval, code-owner review, approval of the latest
push, stale approvals dismissed, conversation resolution, no bypass, no force-push or deletion),
and the Claude GitHub App installed. Cloudflare: a **separate account** under the owner's login,
not the one for the owner's personal site. A token can't be scoped below the account (Workers
Scripts Edit reaches every Worker, D1 Edit every database), and the fixture's synthetic traffic
would share the Free plan's daily request limit. The token has Workers Scripts Edit and D1 Edit
on that account only. It is stored as `CLOUDFLARE_API_TOKEN` in the fixture's `production`
environment (deployment branches: `main` only, no required reviewers), with
`CLOUDFLARE_ACCOUNT_ID` as a variable there. Nothing is repo-level. Cloud environment
`devshop-fixture`: the same two-line setup script with the same read-only devshop token, network
Limited (package managers + `github.com`; the UI needs at least one domain), no environment
variables.

**Evidence**

- As the agent, from a fresh clone: direct push and force push of an empty commit to `main` →
  both `GH006: Protected branch update failed … Changes must be made through a pull request`;
  `main` stayed at `6042661`. Collaborators API: owner admin, agent write. CODEOWNERS on `main`.
- Check session started by Claude in the new environment (read-only, archived after):
  `/tmp/devshop-clone.log` empty; `/opt/devshop.git` at `da33b9b` (current `main`); remote URL
  holds no credential; context line `DEVSHOP: using HEAD (da33b9bceb4b) from environment default
(no .devshop-version) · devshop copy of 2026-10-12 (0 days old)` — the PR #59 install, dated,
  in a real session; 0 `CLOUDFLARE`/`CF_API`/`WRANGLER` variables; npm registry 200,
  `api.cloudflare.com` and `example.com` refused by the proxy (403 on CONNECT), `github.com`
  reachable.
- **Owner-reported, not readable by the agent** (the proxy returns 403 on branch protection,
  environments and Actions secrets): the protection rule's options, the `production` environment,
  its branch rule and secret. Proof moves to W10.5.2 (deploy from `main` succeeds; a PR-branch
  job asking for `production` is refused) and W10.6.4 (approval rules under attack).

**Surprises**

- Current Cloudflare accounts get a `workers.dev` subdomain automatically (Workers & Pages →
  Account details); no "create application" step is needed before an Action-based deploy.
- Rule for later projects (lalista at M2 if it moves to Cloudflare): **one provider account per
  project**, because provider tokens rarely scope below the account. Same reasoning as one cloud
  environment per project (D-01 revisited).
- The preview deploy in W10.5's Done-when needs a deploy credential on PR runs, which the
  `production` environment deliberately can't provide. Open question handed to W10.5.2.

**Next**: a session in the `devshop-fixture` environment with the fixture repo attached, for
W10.5.2–3.

## #26 — 2026-10-12 · W10.4.2 the lint checks handed off in #23

**What moved**: new CI job `ci / lint` runs four checks, each a script in `scripts/` with a test of
the same name in `tests/` (run by `tests/run.sh` in `ci / secret-scan`):

- `format-check.sh`: `prettier --check .` with Prettier pinned in a new root `package.json` (exact
  version, integrity in `package-lock.json`, `npm ci` in CI). It refuses any other Prettier version.
- `shellcheck.sh`: shellcheck 0.11.0 (pinned with a sha256 in `ci.yml`; the release publishes no
  checksums, so the pin is the hash of the asset as downloaded today) over every shell script git
  knows of, by extension or shebang.
- `commit-identity-check.sh` (L-41): rejects commits a change adds whose author or committer email
  is at a domain reserved for tests (example.com/.net/.org, .test, .invalid, .localhost, .example)
  or at `test.com`, the domain of v1's fixture identity. The tests' own identity (`tests/lib.sh`)
  is one of them, so a test that leaks commits into a real repo is caught.
- `docs-map-check.py`: every Markdown file git knows of is reachable from `docs/README.md` through
  links, and no relative link or `#anchor` is broken (GitHub's heading slugs, duplicates included).

Kept out: the spikes (`kit/notes/revamp/spikes/`) are skipped by Prettier and shellcheck. They are
records, and some are the fixed inputs of the A-04 run. The docs map now links the seven docs it
missed: the spike READMEs and specs, and the runtime skill. `tests/lib.sh` gained a `shellcheck
shell=bash` directive. Typecheck waits for code.

**Evidence**: tests written before the scripts. Each check fails on a known-bad input and fails
closed on a missing tool or nothing to check (format: unformatted JSON, wrong Prettier version;
shellcheck: SC2086 in a `.sh`, in an extensionless script and in an uncommitted one; identity: the
tests' own identity, a test committer under a real author, eight reserved-domain forms, lookalike
real domains pass; docs map: orphan, island, missing file, anchor, image, link outside the repo).
24 mutants of the four scripts: 23 killed; the survivor (dropping format-check's `command -v`) is
equivalent, as `--version` still fails closed. Replay of the real incident: the identity check over
this repo's whole history reports exactly the 19 `test.com` commits L-41 records, and a reserved-
domain-only first draft missed all 19 (that is why `test.com` is listed). On the repo: all four
checks pass; `tests/run.sh` 7/7. CI's first run failed on the lookalike case `ada@myexample.com`:
the runner's awk is gawk, which turns `\.` in a `-v` value into `.`, and the session's mawk
doesn't. Reproduced with gawk, fixed by passing the regex through `ENVIRON`. Tests and mutants
pass under both.

**Owner calls in the session**: the lint must also run in a faster loop than CI. The PostToolUse
formatter parked in #24 is un-parked: a hook checks each file Claude edits (Prettier, shellcheck),
and the devshop pre-push hook runs the `scripts/` checks as a backstop. Both go to W10.4.4.

**Next**: `[owner]` mark `ci / lint` required on `main` once this merges; then W10.4.2 is done.
(PR #63) — Done 2026-10-12: the owner marked it required after the merge (owner-reported).

## #27 — 2026-10-12 · W10.6.3 the PR body template and its shape check

**What moved**: `runtime/templates/pr-body.md` is the body for every project PR, in TARGET § L3
Review's order: one-line summary, a **Preview:** line, announcement (only when user-facing), what
you should know (behaviour change, decisions with the spec link, changes after the "go", tests
deleted or loosened, manual steps for the owner), evidence (screenshots, reviewer verdict per lens,
CI, low findings), then engineering details collapsed in `<details>`. It lives in `runtime/`, so a
project gets the version it pins. `runtime/scripts/pr-body-check.py BODY [TITLE]` checks the
shape: title ≤ 72 chars, summary one line ≤ 120 chars, preview present before the sections and
holding a link or `none — <reason>`, sections in order and non-empty with their labelled lines,
details collapsed and closed, no `{{placeholder}}` left, images absolute and GitHub file links
pinned to a commit SHA (L-30). Whether the words are true stays with the reviewer (Review 5, L-29).

Choices made here (the owner can flip them): the preview line sits right under the summary, not
inside the evidence, so it is the second thing seen on a phone. "Manual steps for you" sits in
"what you should know", not in the collapsed details, because the owner must act on it.

**Evidence**: `tests/pr-body-check.test.sh` written before the check. 28 cases: a filled-in body,
one without an announcement, a native one and one quoting template syntax in code pass; the
unfilled template and 21 broken variants fail, each asserting the problem it targets (so none
fails for an unrelated reason); a missing file and no arguments fail closed. 21 of 21 mutants of
the check killed. Dogfood: the PR for this task uses the template for its own body, and the check
passes on that body as read back from GitHub. Its first draft failed: the check took
`{{placeholder}}` quoted in inline code for a leftover one. Fixed (code is skipped) after a
failing regression case.

**Surprises**: TARGET Review 3's preview link is "the deploy platform's own PR comment", which
Vercel's bot posts. The fixture deploys with `wrangler` from a GitHub Action (W10.5.2), and that
posts no comment. So the deploy job must post one comment per PR and update it on every push.
Handed to W10.5.2.

**Next**: W10.6.1 (Build skill fills the template, runs the check before ready). (PR #65)

## #28 — 2026-10-12 · W10.4.4 part 2: fresh-session check passed; pinned gstack

**Fresh-session check (owner, after PR #59 merged):** cache rebuilt by a comment-only edit to the
setup script. The first reply opened with `DEVSHOP: using HEAD (da33b9bceb4b) from environment
default (no .devshop-version) · devshop copy of 2026-10-12 (0 days old)` (`da33b9b` = the #59 merge
on `main`). The setup log ended `RESULT: bootstrap done`; `/opt/devshop-current` and the skill
`devshop-version` agreed; the clone's remote URL had no token; `devshop@devshop` enabled.

**Pinned gstack:** `install/gstack.pin` names one upstream commit (`e23f7b8`, v1.91.93.0 — past
1.91.13, which fixed `/autoplan` in sessions with a SessionStart hook, F-GS-04). The bootstrap
installs it into `~/.claude/skills/gstack` after the devshop's own steps and runs `./setup` with
stdin closed, `--no-team --no-plan-tune-hooks --no-timeline-stop-hook --no-browser --quiet`, then
turns gstack's update check off. It checks that `bun` matches the version the pinned gstack is
tested on (so the gstack pin pins Bun too; owner, 2026-10-12). Before its setup, the bootstrap runs `bun install --frozen-lockfile`
and stops if that fails: gstack's setup falls back to an unfrozen install (re-resolving npm ranges,
running install scripts as root) when its frozen attempt fails (found by the security review).
Found on the way: with stdin open, gstack's setup could read the
rest of the bootstrap, which reaches bash through the setup script's pipe. Tried and dropped:
disabling `/gstack-upgrade` via `gstack-config set disabled_skills` — the real gstack refuses it
(the fake in the test had accepted it; the real-CLI run caught it). Owner: gstack's upstream URL in
`install/gstack.pin` is fine (a public dependency).

**Evidence**: scenario test extended first (failed: no pin), then green: gstack at the pinned commit
via the pin's own URL (git `insteadOf` to a local fake), exact flags, stdin closed, update check
off; a gstack whose setup fails or whose commit is missing is logged as `FAILED: gstack …` while the
plugin installs and the `DEVSHOP:` line appears; lockfile drift stops before gstack's setup runs.
5 mutants of the gstack step killed. Real run
(private namespace, real CLI, real gstack): bootstrap done in 27 s; `settings.json` held only the
devshop plugin; the frozen install took 235 packages from `bun.lock` and left the gstack tree
unmodified; a session saw the `DEVSHOP:` line; `/autoplan` on a toy plan finished Phase 1 (CEO
review) with no phase-guard message (F-GS-04, F-GS-08 locally).

**Slip**: a nested heredoc ended an edit command early; its tail ran with empty variables and left
two empty git repos at `/` in this container (no repo, config or skill touched; checked). Lesson:
edits go through script files, never heredocs inside heredocs.

**Next**: owner's fresh-session check for gstack (PR checklist); then the devshop git hooks.

## #29 — 2026-10-12 · W10.6.2 the independent reviewer script

**What moved**: the reviewer's interface went into W10-v2.md § W10.6.2 first (PR #61, for the
W10.4.4 hooks), then it was built to it in `runtime/reviewer/`. That is `review.sh` plus its pinned
`prompt.md`, `verdict.schema.json` and Bash allowlist `settings.json`. It runs
`claude -p --restricted --safe-mode` (no CLAUDE.md, skills, hooks or MCP; Read/Grep/Glob/Bash, with
Bash only on the allowlist in `dontAsk` mode) in a throwaway clone of the base and head commits.
It checks the real worktree is unchanged afterwards. The outcome comes from the script, not the
model: an unmet `AC-<n>` or any non-`low` finding fails. Malformed or incomplete replies are
could-not-run. A fail at round 3 asks the owner. The verdict is a JSON file under
`.git/devshop/reviews/<branch>/`.

**Evidence**

- Lockdown probed before the interface was written, with the real CLI in a scratch clone that had
  a planted CLAUDE.md. Allowlisted `git log` ran, `touch` was refused, Write was absent, the
  CLAUDE.md wasn't loaded, and `claude-sonnet-5-5` resolved. Gap: `git diff/log --output=<file>`
  can still write. Hence the throwaway clone and the after-check. All of it is feedback, not a
  wall.
- `tests/reviewer.test.sh` was written first and failed (no script). Its 34 checks now pass. It
  runs a harness copy of the directory with a stub `claude` and covers the locked-down flags and
  the pinned model with `ANTHROPIC_MODEL` set, the outcome rule, rounds, the verdict file, and
  could-not-run for 7 bad replies, a claude error, a timeout, a missing claude, a changed real
  worktree, dirty tree, unknown base, missing or AC-less spec, bad arguments and no repo. All
  14 mutants of the script are killed; the one that first survived (could-not-run counted as a
  round) led to a sharper test.
- `tests/reviewer-live.sh 10` (real reviewer, real model): planted 10/10 `fail` with exactly AC-4
  unmet, honest 10/10 `pass` with 0 findings; ~$0.02 and ~11 s per review.

**Surprises**

- **The spike's "honest" fixture fails the v2 reviewer.** On the first live run of 10, 9 failed
  with the same blocking finding: no `package.json` or runner, Jest globals, so the tests can't
  run. The spike only asked "implemented and has a test". TARGET Verify 4 and L-17 ask more, and
  the reviewer was right. The fixtures in `tests/fixtures/reviewer/` keep the spike's spec and
  `src/` byte for byte. They now use `node:test` plus a `package.json` (`npm test`, allowlisted).
  The planted mistake is unchanged and invisible to its own green tests. The spike files stay as
  they were.
- Prettier rewrote the fixture spec's `"a  b"` (AC-2's two spaces) to `"a b"`. `tests/fixtures/` is
  now in `.prettierignore`.
- `tests/bootstrap.test.sh` fails in a shallow clone ("shallow update not allowed"). Cloud sessions
  clone shallow; `git fetch --unshallow` before `tests/run.sh`.
- Only 5 of 20 live verdicts cite a test run as evidence. The rest reason from the code. The
  script doesn't require a run.

**Owner calls in the session**: (1) keep the runnable fixtures and the strict test rule rather
than loosen the reviewer. (2) Run `/security-review` on this PR. Result: no findings at
confidence ≥ 8. It found a bash 5.2 bug (an `&` in the spec path was mangled in the prompt), now
fixed with a regression test, and an overclaim in the reviewer README (allowlisted writes are not
confined to the clone), now corrected. (3) Rounds don't reset after the owner decides, for now. If
W10.6.4–5 show repeat questions, reset when a commit changes the spec.

**Next**: W10.4.4 hooks call `review.sh` per the interface; W10.6.3 puts the verdict on the PR;
W10.6.5 measures precision and recall (A-12) on harder plants, including prompt injection in the
diff.
