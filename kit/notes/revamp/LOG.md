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
Local findings: a plugin installed by a SessionStart hook loads only in the *next* session; a
stub plugin whose `skills` is a symlink switched by its SessionStart hook works in the *same*
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
