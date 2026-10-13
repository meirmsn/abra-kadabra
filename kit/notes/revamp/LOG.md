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

## #29 — 2026-10-12 · W10.5.2 fixture app, CI and deploy wiring (in progress); W10.5.3 design proposed

**What moved**: first session in the `devshop-fixture` environment with the fixture repo attached.
Fixture PR 2 adds a one-page Worker (lists one D1 table; `/healthz` checks the database), tests in
the Workers runtime against a local D1 with the real migrations, and plain CI. CI runs `lint`,
`test` (app tests + script tests, incl. the planted-secret test) and `secret-scan` (the devshop's
pinned gitleaks 8.30.1 and its tested scan script). The deploy is a job in the same workflow:
push to `main` only, `needs` all three checks on that commit, `environment: production`,
`concurrency: production`. Its steps live in a tested `scripts/deploy.sh`: ensure the D1 database
exists (by name, so no account or database id is in the repo; wrangler 4.149 resolves D1 by
`database_name`), apply migrations before the code, deploy, then smoke-check the live
`workers.dev` URL. It fails closed at every step and never prints a credential.

**Evidence**

- Check first: the app tests failed with no worker and pass 8/8 after. Mutation check: dropping
  the HTML escaping fails the escaping test. `tests/deploy.test.sh` (fake `wrangler`/`curl`) failed
  before the script existed and passes 13 cases after, covering the order and each failure path.
  `wrangler deploy --dry-run` bundles with the `DB` binding; the migration applies to a local D1.
- Fixture PR 2's CI on its head: `lint`, `test`, `secret-scan` green; `deploy` skipped (not
  `main`).
- **Wall probe failed (F-NEW-20).** A throwaway branch with a job asking for `production`, run on
  `push` and on `pull_request` (draft PR), was not refused: both runs green, and the log says
  `PROBE: job ran, no token`. A `main`-only deployment-branch rule refuses such a job before any
  step, so the environment isn't in the state W10.5.1 recorded. No token leaked; the cause can't
  be read from the session (environments are 403 to the agent). The first probe run failed for a
  different reason: invalid YAML (a `: ` in a plain scalar), so zero jobs. That is not wall
  evidence.

**Open for the owner**

- F-NEW-20: check the `production` environment (name, deployment branches = `main`, the secret);
  then the probe is re-run until GitHub refuses it, and the refusal text is recorded. The deploy
  PR waits for that.
- Preview deploys need a credential on PR runs. Options: (a) none at M1, with screenshots from
  local `wrangler dev`; (b) a `preview` environment holding a token for a **second, preview-only
  Cloudflare account** (its own Workers + D1), so a PR job can only ever reach preview resources;
  (c) same-account preview URLs. (c) is rejected because the token would reach production from a
  PR run. Recommended: (b).
- W10.5.3 design proposed (synthetic-traffic cron Worker, an owner-held harness repo for the
  plant pool, the plant script, the idea pool and run records, a reset-to-baseline PR script, a
  decoy stack home). It waits for the owner's "go".

**Surprises**

- `@cloudflare/vitest-pool-workers` is deprecated in favour of `@cloudflare/vitest-plugin`. With
  vitest 4, npm 10 crashed resolving an optional peer chain; vitest 5 + the plugin install cleanly.
- The Workers test integration doesn't isolate D1 between tests in a file. The setup resets D1 to
  the migrated baseline before each test.
- A `git add -A` on a branch without `.gitignore` swept in `node_modules`. GitHub's 100 MB limit
  rejected the push (GH001), so nothing landed.

**Owner's answers (same day)**

- F-NEW-20 cause: the `production` environment, its secret and its variable had been set up in
  **the devshop repo**, not the fixture. The fixture's `production` existed with no branch rule
  and nothing in it, probably created automatically when the probe job named it. **Correction to
  LOG #25:** the token was never in the fixture's environment then. The owner moved the secret
  and variable to the fixture's environment, limited it to `main`, removed them from the devshop
  repo, and rolled the token as a precaution: the devshop repo's environment had no branch rule,
  so a workflow on any of its branches could have read the token.
- Re-run of the same probe runs (attempt 2): both refused in about 2 s, with no runner and no
  steps. GitHub's annotations: `Branch "claude/probe-production-refusal" is not allowed to deploy to
production due to environment protection rules.` (push) and `Branch "refs/pull/1/merge" is not
allowed to deploy to production due to environment protection rules.` (pull_request). The
  probe PR is closed. The branch remains because the session's git proxy refuses branch
  deletion.
- Previews: option (c), a separate preview-only Cloudflare account.

**First deploy from `main` (same day)**

- The owner set `lint`, `test` and `secret-scan` as required checks on the fixture's `main` and
  approved fixture PR 2. Claude squash-merged it on green.
- Push run on `main`, attempt 1. `lint`, `test` and `secret-scan` passed. The deploy job:
  - created the D1 database (by name) and applied `0001_create_items.sql` remotely;
  - deployed the Worker and reported its `workers.dev` URL;
  - needed no token permission beyond Workers Scripts Edit + D1 Edit.

  Then the smoke check failed: `/healthz` was ok on try 3, but the page request seconds later
  returned 404 (`FAIL: the page did not load`). Root cause: the brand-new `workers.dev` route was
  still propagating across the edge, and the script retried `/healthz` but not the page.

- One re-run of the failed job (same commit, same script): `No migrations to apply!`, deploy ok,
  `smoke: ok` on the first try. **Production is live and healthy.**
- Fix: fixture PR 3. Each smoke try checks `/healthz` and the page, either failure is retried,
  and two passing tries in a row are required. The check came first: the run-2 pattern, fed to
  the old script in the test, fails with the same line as production.
- Synthetic traffic (W10.5.3 design, owner): a request every minute for 5 minutes after each
  deploy, then exponential back-off capped at one round an hour. It's one scheduled Worker
  waking each minute, and each deploy restarts the schedule. The cap keeps the next-day check
  and the pre-merge health check fed.

**Next**: fixture PR 3; then the preview-only account (owner) and preview wiring, including one
self-updating preview comment per PR (the PR body template links it, LOG #27). W10.5.3 waits on
the owner's "go" and the harness repo.

## #30 — 2026-10-12 · W10.6.2 the independent reviewer script

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

## #31 — 2026-10-12 · Reviewer follow-ups get owners (W10.6.6 added)

**What moved**: after PR #61, a check of the tracker on `main` found that two next steps for the
reviewer had no owner. The hook that starts the reviewer was only implied: W10.6.2's line names it,
but W10.4.4's sub-items don't. Putting the verdict on the PR was handed to W10.6.3, which closed as
the PR body template only. W10.6.3's own hand-off (the reviewer checks the PR body against the
final commit, Review 5) points back at W10.6.2, which is done.

**Owner calls**: the hook goes to the session already working on W10.4.4, by message, not a new
tracker line. The verdict on the PR and the PR-body check become **W10.6.6**, needed before the
north-star run (W10.6.4).

The W10.4.4 session then asked how a hook finds `--spec`; the owner folded the answer into W10.6.6:
the reviewer finds the one `specs/` file the branch adds or changes (none → it reviews against the
PR's own words, and the failing test is the spec for a bug fix; two or more → could-not-run).

**Next**: W10.6.6 as its own task; the W10.4.4 session adds the reviewer hook.

## #32 — 2026-10-12 · W10.4.4 part 3: gstack fresh-session check passed; git hooks next

**Fresh-session check (owner, after PR #64 merged), abra-kadabra environment** (cache rebuilt by a
comment edit): `DEVSHOP: using HEAD (cde1959ce7bf) … · devshop copy of 2026-10-12 (0 days old)`
(`cde1959` = the #64 merge); setup log `gstack e23f7b8…` and `RESULT: bootstrap done`, no `FAILED`;
installed gstack `e23f7b8`, `VERSION` 1.91.93.0; `settings.json` only the devshop entries;
`/autoplan` on a one-line scratch plan ran through Phase 1 (CEO review) with **no phase-guard
message** (F-GS-04, F-GS-08 in a real session). gstack's done-when is met.

**Surprise**: an earlier attempt ran in the devshop-fixture environment, whose cache predated the
merge (bootstrap at 08:11, merge at 08:58), and showed no gstack. Its `DEVSHOP:` line said "0 days
old": day resolution hides a same-day stale copy, and nothing names the environment. The git-hooks
PR adds the copy's time and the environment to the line.

**Owner calls (2026-10-12)**: the hand-off from the W10.4.2 session (#63) is built here. The W10.6.2
session handed over the hook that starts the reviewer; W10.6.6 (#68) changes the reviewer's call to
`review.sh --base <rev>`, so that hook comes in a later PR, after W10.6.6. Hooks: a repo declares its
own checks (`scripts/lint.sh`, `scripts/lint-file.sh`) and the devshop's hooks run them; the git
pre-push hook is the main in-session layer (it sees every change), the PostToolUse hook only a
nudge (Claude's edit tools); per edit, Prettier fixes (`--write`) and shellcheck reports. v1's
"agent can't edit the hooks" guard is not ported: L-36 shows it never held, and required CI is the
wall. No wall can fire before CI: everything before a push is inside the VM.

**Built**: `runtime/hooks/session-start.sh` points `core.hooksPath` at `runtime/git-hooks/`
(`pre-push`; every other hook links to `_chain`, which runs the project's own hook: former
`core.hooksPath`, husky, or `.git/hooks`). `runtime/hooks/post-edit.sh` behind a PostToolUse hook.
`install/tools.pin` (gitleaks, shellcheck; the bootstrap downloads, checks, links them into
`/opt/devshop-tools/bin`). This repo's `scripts/lint.sh` (CI's `lint` job runs it) and
`scripts/lint-file.sh`. The `DEVSHOP:` line gives the copy's time and the project (the session can't
read its environment's name).

**Evidence**: tests written first, each failing before its change: `bootstrap.test.sh` (time and
project in the line; tools pinned as in `ci.yml`, installed, a bad checksum refused),
`git-hooks.test.sh` (14 cases, real `git push` and gitleaks: secrets in unpushed commits, removed
again, on a new branch; `--no-verify` bypasses; missing gitleaks; lint findings and can't-run;
project hooks and husky chained), `post-edit.test.sh`, `lint.test.sh`, `lint-file.test.sh`. Real run
(private namespace, real CLI, real downloads): tools installed at 8.30.1 and 0.11.0; the line read
`… · devshop copy of 2026-10-12 18:01 UTC (0 days old) · project proj`; `core.hooksPath` set; a push
with a planted key stopped; a `Write` of `echo $1` came back to Claude as SC2086 in the same turn.

**Security review**: nothing exploitable from outside. One medium finding, fixed: the first
version also ran a committed `.husky/<hook>` when husky wasn't configured, so checking out an
untrusted branch would run its `post-checkout` (reproduced by a test first; now only hooks the
project configured in the clone run). Hardening taken: a tool `version` that could leave
`/opt/devshop-tools` is refused (test first), tools unpack with `--no-same-owner`. Documented: the
repo's declared lint scripts run from the working tree, like its tests.

**Next**: the reviewer hook after W10.6.6; the owner's fresh-session check of this PR.

## #33 — 2026-10-12 · W10.4.4: hooks fresh-session check; new-branch fix, env note, session setup

**Fresh-session check of #69 (owner, abra-kadabra)**: the line read `… · devshop copy of 2026-10-12
18:33 UTC (0 days old) · project abra-kadabra`; gitleaks 8.30.1 and shellcheck 0.11.0 installed, no
`FAILED`; `core.hooksPath` set; a push of a fake key to a scratch remote was stopped by gitleaks; a
`Write` of `echo $1` came back as SC2086. It also showed: (1) a bug: a new branch's lint base was
empty without `refs/remotes/origin/HEAD` (fresh cloud clones have none), so the identity check
scanned all history and v1's six `test@test.com` commits would stop every first push of a branch;
(2) friction: without `npm ci`, every push and edit reported "prettier not found". The empty scratch
remote made gitleaks scan all history too (six known v1 findings, LOG #11); real pushes to `origin`
scan only the branch's new commits.

**Fixed, tests first**: a new branch's base is the parent of its oldest commit not on the remote
(the test reproduced the empty base first). Session start runs the repo's declared `scripts/setup.sh`
(this repo: `npm ci`), loud on failure (owner, option a). The `DEVSHOP:` line ends with an env note:
the setup script's first comment line, read during setup from the script's process; only that line
is kept (a test plants a fake token on the next line and checks it is stored nowhere); `bash -c` and
file runs tested, stdin gives `env note unavailable`. Owner: keep it only if the real environment
shows the note; otherwise drop it.

**Next**: owner's fresh-session check of this PR; the reviewer hook after W10.6.6.

## #34 — 2026-10-12 · W10.4.4: fresh-session check of #70; env note skips the shebang

**Owner's check of #70 (abra-kadabra)**: `npm ci` ran at session start and Prettier was there. The
env note read `"!/bin/bash"`: the environment runs the setup script as a file with a shebang added
above the owner's comment, so the file path works and only the line choice was wrong. Fixed (test
first): the note is the first comment line after any `#!` lines; reading still stops at the first
non-comment line. The checklist's scratch remote got `main` through the hook, which rightly scanned
all history and stopped on v1's known findings (LOG #11); seed such a remote with `--no-verify`.

**Next**: owner's check of this fix; the reviewer hook after W10.6.6.

## #35 — 2026-10-12 · W10.5.2 done: deploys from `main`, per-PR previews in their own account

**What moved**: the rest of W10.5.2, after LOG #29.

- Fixture PR 3: the deploy smoke check needs two clean passes in a row, because the first deploy
  404'd while the new route propagated.
- Fixture PR 4: per-PR previews.
- Fixture PR 6: preview cleanup through the Cloudflare API.

The owner chose previews in a **separate, preview-only Cloudflare account** under the same login.
D1 permissions can't be scoped to one database, so a same-account preview token could reach
production's data. Cloudflare's new single-Worker tokens (2026-09-15) don't solve that, and they are
reported to fail to create. The preview token is account-owned: legacy Workers Scripts Edit + D1 Edit,
on that account only. It sits in the fixture's `preview` environment, with no branch restriction.

Each PR gets its own Worker and D1 database (`devshop-fixture-pr-N`, migrations applied), so PRs
with different migrations don't collide. The cost is the Free plan's ~10-database limit, and a
failed create names it. The deploy reuses the tested production script through a config switch.
One PR comment links the preview and is updated in place on every push. A close deletes the Worker
and database; the cleanup runs `main`'s scripts and can be started by hand for any PR.

**Evidence** (all read from the Actions API and job logs in the session)

- **Production:** deploys from `main` after PRs 3, 4 and 6 passed their smoke checks. After PR 3,
  the log showed `smoke: try 1/10 ok`, `try 2/10 ok`, `smoke: ok`.
- **Preview, PR 4's own run:**
  - its own database was created and migrated, and its own Worker deployed;
  - the smoke check rode out propagation (ok, page 404, ok, ok), then passed;
  - `preview-comment: deployed (created)`.
- **Isolation probe** (a throwaway branch, the `preview` environment, the preview token):
  - `accounts visible: 1 (preview account among them: yes; production among them: no)`;
  - production D1 list `HTTP 401 … Authentication error`;
  - preview D1 list `HTTP 200`.
- **Cleanup:**
  - PR 4's close failed: `wrangler delete` also reads KV namespaces, and the token has no KV
    permission (`Authentication error [code: 10000]` on `/storage/kv/namespaces`).
  - Fix (PR 6): call the API directly, with the token on stdin, so no new permission is needed.
  - Live: PR 6's close logged `deleting Worker`, `deleting database`, `PR 6 removed`,
    `preview-comment: removed (updated)`.
  - The manual run for PR 4 logged `Worker … was already gone` (the failed `wrangler delete` had
    removed it), `deleting database`, `PR 4 removed`.
- **PR body check** (hand-off from LOG #27): PR 4's and PR 6's bodies, written from
  `runtime/templates/pr-body.md` with the real preview-comment link, pass `pr-body-check.py`
  (`shape ok`). The check first caught a 169-character summary. The same body with the link
  replaced is refused.
- **Checks written first:** every new script failed its tests before it existed.
  - `tests/deploy.test.sh`: 20 cases.
  - `tests/preview.test.sh`: 11 cases.
  - `tests/node/*.test.mjs`: 9 cases, against a fake GitHub API.

**Surprises**

- Fake tools hide real permission checks: the `wrangler delete` KV lookup only showed up live.
  Mitigation: every new Cloudflare call path gets one live run before its PR is called done.
  Root cause: the fakes model wrangler's interface, not the permissions it needs.
- Vitest's default file pattern also collected the Node script tests; the include is now pinned.
- A single green request proves little during route propagation, which is why the smoke check
  needs two passes in a row.
- A stray `git checkout origin/main -- runtime` staged newer files onto an old branch. It was caught
  before commit and undone.

**Next**: W10.5.3 is in the owner's separate session (traffic schedule: every minute for 5 minutes
after a deploy, then back-off to a 60-minute cap; LOG #29).

## #36 — 2026-10-12 · W10.4.4: fresh-session check of #71; env note dropped

**Owner's check of #71 (abra-kadabra)**: the devshop pre-push hook scanned the push's 1 new commit
and passed; session setup ran `npm ci`; the `DEVSHOP:` line still ended `env note unavailable`.
The real environment's setup file has wrapper lines before the owner's comment, so the first
comment line after `#!` is never the owner's.

**Owner decision**: drop the env note. The line's project still names the environment (one
environment per project).

**Done, test first**: `tests/bootstrap.test.sh` back to requiring the line to end with
`· project <name>` (or its `;` tail) and to replaying the setup script's line 2 verbatim on stdin.
Against the old HEAD it failed (`FAILED: write env-note`, line ending `· env note unavailable`);
after removing `env_note`/`lead_comment` from `install/bootstrap.sh` and the note from
`install/plugin/devshop/hooks/dispatch.sh` (both now byte-identical to before #70), all cases pass.
`install/README.md` no longer describes the note.

**Not started**: the reviewer hook. It waits for W10.6.6 (`review.sh --base <rev>` without
`--spec`); `runtime/reviewer/review.sh` on `main` still requires `--spec`, which a hook can't know.

**Next**: W10.6.6; then the reviewer hook and the owner's fresh-session check of it.

## #37 — 2026-10-12 · W10.4.4: fresh-session check of #73 passed; hook handed off

**Owner's fresh-session check of #73 (abra-kadabra)**: the line read `DEVSHOP: using HEAD
(ce5512950c2c) from environment default (no .devshop-version) · devshop copy of 2026-10-12 19:55 UTC
(0 days old) · project abra-kadabra`, with no env note. The copy contains `ce55129` (#73), and
`/opt/devshop-versions/` has no `env-note`. The setup log ends `RESULT: bootstrap done` with no
`FAILED`. `/tmp/devshop-project-setup.log` shows `added 1 package`, the output of `scripts/setup.sh`
(`npm ci --no-audit --no-fund`), with no failure line. `npx prettier --version` printed 3.9.9.
**Passed**.

**W10.4.4 closed (owner: split)**: the install/upgrade mechanism is done. The reviewer hook, the one
part that waits on W10.6.6, is now its own task, W10.6.7, with the owner's spec. W10.6.6 points to
it, and the docs that named W10.4.4 for the hook now name W10.6.7.

**Next**: W10.6.6; then W10.6.7 and the owner's fresh-session check of it.

## #38 — 2026-10-12 · W10.5.3: synthetic traffic, baseline reset, harness repo (in progress)

**What moved**: the owner said "go" on the W10.5.3 design (LOG #29), with option D for the harness
repo and a Next.js + Supabase stub as the decoy stack home.

- **Synthetic traffic** (fixture PR 5): a second Worker on a cron every minute.
  - **Requests:** it calls the app through a **service binding**, because a Worker can't fetch
    another Worker's `workers.dev` URL in the same account. This also keeps every URL out of the
    repo.
  - **Schedule:** a round every minute for 5 minutes after a deploy, then at minutes 6, 10, 18,
    34 and 66, then hourly. It counts from the traffic Worker's own version timestamp, and the
    deploy job uploads a new version right after the app's smoke check.
  - **Rounds:** each requests `/healthz` and the paths in `traffic/routes.json`. A failed round
    fails that cron run.
  - **Previews:** fixture PR 4 (merged meanwhile by another session) made `deploy.sh` shared with
    previews, so the traffic step is production-only.
- **Reset to baseline** (fixture PR 7): `scripts/reset-to-baseline.sh <tag>` opens a normal PR.
  - It restores everything outside `migrations/` to the tag and adds one generated forward
    migration. `scripts/schema.mjs` writes it in D1's order (indexes and views, then added
    columns, then new tables children first) and self-checks it with foreign keys on.
  - It stops (exit 3) when a run dropped or changed a baseline table or column. Data rows are
    not reset.
  - CI's `test` job asserts the schema equals the tag's when the newest migration is a reset.
- **Baseline:** `baseline-1` on the merge of fixture PR 7, made by the owner (F-NEW-22). The tag
  had to wait for PR 7: a baseline without the reset script would delete it on the first reset.
- **Harness repo** (option D): owner-held, private, protected like the fixture, squash only.
  - The agent identity has Write only while the tooling is built and loses access before the
    first real run. Plants are then applied by an Action the owner triggers, with a fixture-only
    token, so the builder can't read them: a wall, not a habit.
  - Harness PR 1 (merged): 8 same-shape ideas plus a picker that records each pick and prints
    only the pitch.
  - Harness PR 2: the plant runner, the `loosened-test` plant, and the `apply-plants` Action.
    Records go on a `run-records` branch, because `main` is protected.

**Evidence**

- **Checks written first,** each failing before its code existed:
  - traffic Worker: 13 tests; deploy script: 17, then 21 after the previews merge;
  - traffic config check: 11 known-bad configs;
  - reset: 12 cases in scratch repos;
  - harness picker: 7 tests; harness plants and runner: 13 tests.
- **Mutants:** traffic Worker 8 of 9 (the survivor equivalent, removed); idea picker 9 of 9;
  plant runner 13 of 13, after closing 3 gaps the first pass found.
- **Production** (deploy job logs after fixture PRs 5 and 7):
  - `smoke: ok`, then `Deployed devshop-fixture-traffic triggers … schedule: * * * * *`, with
    bindings `env.APP` and `env.CF_VERSION_METADATA`;
  - no token permission beyond Workers Scripts Edit + D1 Edit was needed;
  - a PR preview logged `deploy: no synthetic traffic for wrangler.preview.json (production only)`.
- **Reset:**
  - on a real local D1 (`wrangler d1 migrations apply --local`), rows in place: D1 refuses to drop
    a parent table while child rows reference it (`FOREIGN KEY constraint failed`) but allows
    dropping a referencing column. Generated migrations for both cases applied and restored the
    baseline schema;
  - a dry run against `baseline-1` in a scratch clone produced a no-op migration, and the schema
    check passed.
- **Plant on real fixture code:** `test/index.test.js:14`
  `toContain("<li>First item</li>")` → `toBeDefined()`. The fixture suite still passes 21/21:
  silent in CI, so only the reviewer can catch it.
- **Walls:** a direct push to the harness repo's `main` as the agent was refused with `GH006`,
  and `main` stayed at its first commit.

**Surprises**

- The design suggested reading the app's version from `/healthz` each minute. The traffic Worker's
  own version timestamp does the same job with no requests between rounds. Known limit: a dashboard
  rollback doesn't restart the schedule.
- My first reset version passed its foreign-key test by alphabetical luck; swapping the table names
  made it fail, and the fix followed. A test that can pass by accident isn't a check.
- F-NEW-21: a clean base-merge push kept the owner's approval on fixture PR 7.
- F-NEW-22: the session proxy refuses tag pushes.
- The owner merged fixture PRs 5 and 7 as merge commits. The fixture now allows squash only.

**Next**: the harness's four spec plants and the decoy wait for W10.6.1's formats. The reviewer
already names acceptance items `AC-<n>` (W10.6.2), which the spec plants will target. Before the
first real run (W10.6.4), the owner adds the fixture-only token to the harness repo and removes
the agent from it.

## #39 — 2026-10-12 · W10.6.1: the Intent and Build skills, from the pinned install

**What moved**: the two v2 skills, one page each, in `runtime/skills/`, so a session gets the
copies its project pins.

- **`intent`**: say the request's kind first (no change → just do it; bug fix → the failing test
  is the spec, no "go"; anything else → the steps). `/office-hours` when the why is unsettled,
  `/spec --file-only --no-gate` for the interview, the spec in the project's `specs/` from
  `runtime/templates/spec.md` with items `AC-<n>`, checked by `runtime/scripts/spec-check.py`, the
  adversarial spec review, the one-screen summary, and the "go" recorded on the spec's `**Go:**`
  line (`spec-check.py --go`).
- **`build`**: one writer, helpers only read; the project's rules, the stack homes
  `runtime/scripts/stack-homes.sh` picks (its `STACKS:` line goes in the PR), and the discipline
  guidelines; code, tests and docs end up describing the new behaviour; the PR body from the
  template, checked by `pr-body-check.py` before ready; the reviewer is started by the W10.6.7 hook
  on PR create/ready, never by the builder.
- **Layouts** (what W10.5.3's decoy and spec plants wait on): a stack home is
  `runtime/stacks/<stack>/` with `README.md` and `detect` (project paths or globs, or `<path>: <pattern>` to match a file's content, as the decoy's `package.json: "next" *:` needs); guidelines are
  `runtime/guidelines/<discipline>.md`. The README had planned top-level `stacks/` and `docs/`, but
  only `runtime/` reaches a session. None ship yet.

**Evidence**: each check was written and run failing first: `tests/skills-check.test.sh` (the
real skills missing), `tests/spec-check.test.sh` and `tests/stack-homes.test.sh` (scripts
missing), and the new `tests/bootstrap.test.sh` step (`skill intent: … resolves to ''`). After the
change all pass; results are in the PR.

**Mitigation**: TARGET Intent 5 has the independent reviewer review the spec; `review.sh` reviews
only a diff against a spec. Until it has a spec mode, the skill hands the spec to a fresh
read-only helper. Root cause: no spec-review mode in the reviewer.

**Next**: the owner's fresh-session check in the fixture environment: `devshop:intent` and
`devshop:build` listed, and the session uses them on a request.

## #40 — 2026-10-12 · W10.6.6 the reviewer finds the spec; its verdict goes on the PR

**What moved**: the W10.6.2 interface note changed first. `review.sh --base <rev> [--pr <file>]`
drops `--spec`. The spec is the one `specs/**.md` file the change adds, changes or renames; two or
more are could-not-run. With none, the intent is the PR's words, else the commit messages, and a
change that should have had a spec fails on the `intent` lens. `--pr` is a JSON file with the PR's
title and body, which the W10.6.7 hook builds from the tool call it intercepts. The reviewer checks
them against the commit (Review 5, the `pr` lens), and the verdict records their hash
(`devshop-review/2`). The verdict reaches the PR as one comment per review (`pr-comment.sh`), and
the `review-verdict` workflow (`verdict-wait.sh` → `verdict-check.sh`) shows a missing, stale or
failing one for the head commit.

**Owner calls**: (1) the verdict lives on the PR as a comment. The first pick was a commit status
plus a comment, but the session's GitHub access refuses status writes (`HTTP 403: Write access to
this GitHub API path is not permitted through this proxy`, tried once on this branch). (2) The PR
opens only after the review passes, and each later push is reviewed first (TARGET Verify 2). There
is no draft-to-ready step, so A-23 is obsolete. Recorded in TARGET, PLAN changelog and W10.6.6/7.

**Evidence**

- Tests written first, failing (`--spec is required`, missing scripts). `tests/reviewer.test.sh`:
  the old cases kept; new ones for the spec (none, one, two, nested, changed, deleted, non-`.md`,
  no `AC-`), `--pr` (verbatim into the prompt, not executed, hashed, the `pr` lens must match, 6 bad
  files), no-spec intent. Mutants: W10.6.2's core logic 14/14 killed; W10.6.6's 21/22, the survivor
  equivalent (`specs/*.md`: git's default pathspec `*` crosses `/`). Two survivors on the first pass
  were real gaps, now tested.
- `tests/reviewer-pr.test.sh`: rendering (per lens and item, the marker not forgeable from model
  text), ok / missing / stale / failing, the latest marker decides, the wait with a stub `gh`, and
  could-not-run for bad input. Mutants 27/28 killed, the survivor equivalent.
- `tests/reviewer-live.sh 10` (real model, ~$0.02–0.03 per review): seeded 10/10 fail with exactly
  AC-4 unmet; honest with true PR words 10/10 pass; PR body with a false claim 10/10 fail on `pr`;
  new feature with no spec 10/10 fail on `intent`; two specs 10/10 could-not-run; honest bug fix
  with no spec 9/10 pass.

**Surprises**

- The miss: one bug-fix run failed on an `unsure` code finding. Stripped characters can still leave
  double dashes (`'a ! b'` → `'a--b'`), an issue that predates the fix, which the PR doesn't claim
  to cover. `unsure` blocks by design (Verify 6). The fixture is not tuned to pass. A data point for
  W10.6.5 (precision), and maybe a prompt line: issues that predate the change and lie outside its
  stated scope are `low`.
- A comment-triggered workflow reports on the default branch, not on the PR, so the PR's check
  can't turn green when the comment lands. It waits instead: it polls the comments for up to 10
  minutes after each push.

**Next**: W10.6.7, the hook: review before PR create and before each push to an open PR, post the
comment after. Probe whether a hook can post the comment with the session's GitHub access (status
writes are refused).

## #41 — 2026-10-12 · W10.6.6 follow-ups filed or fixed

**What moved**: the five loose ends from W10.6.6 (PR #78's two low findings and LOG #40's notes)
each got a FINDINGS row. F-NEW-25: the verdict comment no longer renders model text as mentions,
markdown links or images (`@` and `[` escaped; bare URLs and `#123` still autolink), and paths in
code spans stay literal. The test was written first and failed, and the escapes are
mutation-tested. The reviewer's first pass on this change failed it (medium): the words claimed
"no links" while bare URLs still autolink, and code spans would have shown entities. Both fixed, test
first. F-NEW-26: `specs/` holds spec files only (Intent skill, reviewer README). F-NEW-27
(post exactly the reviewed PR words) went onto the W10.6.7 line. F-NEW-23 (the reviewer can't run
this repo's tests) waits for an owner call, proposed for W10.6.5. F-NEW-24 (a precision data point)
goes to W10.6.5 without a prompt change.

**Next**: W10.6.7 in a new session (the owner has its prompt).

## #42 — 2026-10-12 · W10.5.3 done: spec plants, decoy stack home, fixture CLAUDE.md

**What moved**: the rest of W10.5.3 after LOG #38, once W10.6.1 (#76) put the spec and stack-home
formats on `main`. The W10.6.1 session got the hand-off as a message from this session (owner's
request) and added the `<path>: <pattern>` detect form the decoy needs.

- **Fixture `CLAUDE.md`** (fixture PR 8): the Build skill reads a project's `CLAUDE.md`; the
  fixture had none, so its conventions (new routes in `traffic/routes.json`, append-only migrations,
  deploys only from `main`, no ids in the repo) never reached a builder. It says nothing about the
  harness. A reset restores every file outside `migrations/` to its tag, so the owner tagged
  **`baseline-2`** on that merge; `baseline-1` would delete the new file.
- **Spec plants** (harness PR 3): `untested-acceptance`, `false-verified`, `skipped-state-row`,
  `reworded-acceptance`, on the PR's `specs/*.md` in W10.6.1's format. Plants in one run never pick
  the same item; items already verified by review, the state table's header and non-spec files are
  never touched. The harness now has all five plant types.
- **Decoy** (this PR): `runtime/stacks/nextjs-supabase/`, detected by `package.json: "next" *:`,
  `next.config.*` or `supabase/config.toml`. Its README says plainly it is a placeholder until
  lalista's real home at M2, so a real Next.js project that loads it isn't misled.

**Evidence**

- `0ccde19` (fixture PR 8's merge): `lint`, `test` (with the schema check), `secret-scan` and the
  production `deploy` passed; `baseline-2` points at it (`git ls-remote --tags`).
- Spec plants, checks written first: 7 tests failed before the plants existed; all 27 harness
  tests pass. The first mutation pass left 10 of 13 mutants alive (the test spec couldn't tell the
  review-only item, the header row, a second test file, bracket leftovers, non-spec files or the
  shared item set from real targets); after strengthening, 13 of 13 are killed. On a template-shaped
  spec, all four plants in one run hit four different targets, and W10.6.1's real
  `spec-check.py --go` passed before and after (silent to the shape check). The merged format on
  `main` is byte-identical to the branch the plants were built against.
- Decoy, check first: `tests/decoy-stack.test.sh` failed with no home, then passes 5 cases with
  the real `stack-homes.sh` and `runtime/stacks/`: the fixture's shape and near misses (`next` in a
  description, a `next build` script, `next-auth`) don't load it; a `next` dependency, a
  `next.config.*` and a `supabase/config.toml` do. 4 of 4 detector mutants killed. On the real
  fixture repo (`main`), `stack-homes.sh` prints `STACKS: none`.
- **W10.5's Done-when, re-checked:** fixture repo with plain CI (`lint`, `test`, `secret-scan`
  required on `main`); protection refused direct pushes as the agent (GH006, LOG #25, #38); per-PR
  previews deployed on every PR this session (comment updated per push); production deploys only
  from `main` (non-`main` refusal, LOG #29); harness: traffic, reset + baseline, idea pool, all five
  plants and the apply Action, decoy. The apply Action's first live run is W10.6.4's.

**Surprises**

- The north-star's "expected set" for step 2 is `none` at M1: no Cloudflare stack home exists
  until M2, so only the decoy half can be checked now (noted on W10.6.4).
- A file added to the fixture after a baseline tag is deleted by the next reset to that tag; every
  such change needs a new baseline (here `baseline-2`).

**Next**: W10.6.4 (north-star run) once W10.6.7 lands; before it, the owner's harness steps listed
there.

## #43 — 2026-10-12 · W10.6.1 done: owner's fresh-session check in the fixture environment

**Owner's check** (`devshop-fixture` environment, fixture repo, cache rebuilt after #76): the session
ran devshop HEAD `06ba34c` from a copy made that day.

- **Skills:** asked which devshop skills it has, it listed `devshop:intent`, `devshop:build` and
  `devshop:devshop-version`, each described as the skill says.
- **Status question** ("where are we?"): answered as a no-change request, with no spec and no "go".
- **A change** ("show the app version in the page footer"), throwaway, not from the idea pool:
  - it ran `/devshop:intent`, named the request a change, and asked the owner the one real
    decision (version = git commit SHA);
  - it proved the tool behaviour first: a no-credentials `wrangler` dry run showed
    `--var APP_VERSION:<sha>` reaching the Worker as `env.APP_VERSION`;
  - it wrote `specs/footer-version.md` (AC-1…9) and `spec-check.py` passed;
  - the read-only helper review raised blocking findings, e.g. the version check ran after the D1
    migrations; Claude checked them against the code before fixing;
  - it showed a summary with two open questions, one flagging its own preview addition as beyond
    the ask, and **stopped for the "go"**. No code was changed and no PR opened.

**Passed.** The owner deleted the fixture branch afterwards; the fixture stays at its baseline.

**Deviations, fixed here** (in `runtime/skills/intent/SKILL.md`):

- It skipped gstack's `/spec` interview. TARGET Intent 1 gives every change the interview, so the
  skill now says "every change, however small".
- It committed and pushed the draft spec before the "go", to outlive the container. That is right:
  the skill said "commit on go", which loses work. It now says to commit and push the draft as it
  goes; only building waits for the go.
- Not fixed: the summary ran longer than one phone screen. Watched in W10.6.4.

**Found:** the `DEVSHOP:` line was not repeated word for word. The rule to repeat it lives only in
this repo's `CLAUDE.md`, and projects carry no devshop rules (Shape 3), so in a project session
nothing asks for it; Claude paraphrased it. Owner: the hook shows the line to the owner directly,
with a "repeat it" nudge as backup. Next, as its own PR.

**Owner decisions:** the adversarial spec review stays a read-only helper at M1 (TARGET allows a
crude spec review at M1); the reviewer's spec mode is an M2 item. Stack homes and guidelines stay
under `runtime/`.

**Next:** the `DEVSHOP:` line fix; W10.6.7 runs in another session.

## #44 — 2026-10-12 · The `DEVSHOP:` line reaches the owner in project sessions

**Why**: in the owner's fixture check (LOG #43), Claude paraphrased the `DEVSHOP:` line instead of
repeating it. Hook output reaches only Claude, and the rule to repeat it lives only in this repo's
`CLAUDE.md`; projects carry no devshop rules (Shape 3).

**What moved** (owner's choice): the plugin's SessionStart hook (`install/plugin/devshop/hooks/dispatch.sh`)
collects everything it and the version's `session-start.sh` print, then emits one hook JSON object:

- `systemMessage`: the lines, shown to the owner by Claude Code;
- `hookSpecificOutput.additionalContext`: the same lines plus "Repeat every DEVSHOP: line above to
  the owner word for word in your first reply.", the backup if the message isn't shown.

`jq` builds it: per the hooks docs, stdout that fails to parse as JSON is dropped whole. Without
`jq` the hook prints the plain lines and the request instead.

**Evidence**: `tests/bootstrap.test.sh` was changed first and failed against the old hook (`SessionStart
output is not JSON with a systemMessage`). It now checks the JSON for every pin case and the plain
fallback with `jq` off `PATH` and with a `jq` that fails; all scenarios pass. Three mutants (no request in the context, plain
output always, fallback without the request) are all killed.

**Owner's decision** (2026-10-12, in chat, after LOG #43's options): the hook shows the line to the
owner directly, with the request to Claude as backup; no spec, the decision is recorded here. If the
apps don't show the message, nothing is reverted: Claude still gets the line and the request, and
the result is recorded. Any other line the version's `session-start.sh` prints (such as a failed
`scripts/setup.sh`) is now shown to the owner too.

**Open (experiment)**: the hooks docs don't say whether the web and mobile apps show a SessionStart
`systemMessage`. The owner's fresh-session check in the fixture environment answers it: does the owner
see the line directly, on web and on the phone, and does Claude repeat it word for word?

**Next**: that check (after a trivial setup-script edit so the environment's devshop copy rebuilds).

## #45 — 2026-10-12 · `DEVSHOP:` line: owner's fresh-session check of #83

**Owner's check** (`devshop-fixture` environment, setup script edited so the devshop copy rebuilt;
fresh session, first message "hi"):

- **Claude repeats the line:** the first reply opened with `DEVSHOP: using HEAD (c6a84a563757) from
environment default (no .devshop-version) · devshop copy of 2026-10-12 23:46 UTC (0 days old) ·
project devshop-fixture`, word for word. **Passed.**
- **The session ran the new hook:** asked afterwards, Claude quoted the same line and said the hook
  output ended with the request to repeat it. `readlink /opt/devshop-current` →
  `/opt/devshop-versions/c6a84a5…`; `/opt/devshop.git` HEAD → `c6a84a5` (#83's merge); the installed
  `/opt/devshop-plugin/devshop/hooks/dispatch.sh` contains `systemMessage`.
- **The experiment:** the macOS desktop app does **not** display a SessionStart `systemMessage`. The
  owner's screenshots show only Claude's reply, and the expanded "Initialized session" row lists only
  the four setup steps (container, clone, setup script, Claude Code). Not checked on the phone. The web app was checked afterwards (2026-10-13, same session): it looks the same, the line only inside Claude's reply and the same four steps under "Initialized session".

**Result:** the owner sees the line because Claude repeats it, the backup in #83. The hook still
sets `systemMessage` for surfaces that show it; `install/README.md` and the hook's comments no
longer claim it shows the line to the owner. A first try earlier was void: the environment hadn't
rebuilt, so the session ran the old hook.

**Next:** W10.6.7 (another session).

## #46 — 2026-10-13 · W10.6.4 prep: the harness's apply Action proven live; agent cut off

**What moved**: the owner did W10.6.4's harness steps: the fixture-only token and the
`FIXTURE_REPO` variable in the harness repo, then removed the agent identity as a collaborator. In
between, one smoke test of the `apply-plants` Action, its first live run, on a throwaway fixture PR
(a draft with one probe test, closed without merging).

**Evidence**

- Owner ran apply-plants with plant `loosened-test`, run id `smoke-1`: run green. On the PR
  branch, exactly one new commit, "Follow-up edits" by `github-actions[bot]`, changing only
  `expect(res.status).toBe(200)` to `toBeDefined()`. The fixture's `lint`, `test` and
  `secret-scan` all passed on it (the plant is silent in CI). The `smoke-1` record (ref, file, line,
  before/after, commit) is on the harness's `run-records` branch. In the job log both tokens show
  only as `***` and no token-carrying URL is printed.
- After the removal, `git ls-remote` on the harness repo as the agent: `repository … not found`.
  Hiding the plants from the builder is now a wall, not a habit.

**Surprises**: the plant push is the token owner's push, so under "approval of the most recent
push" the owner can't approve a planted PR until someone else pushes; in a real run the builder's
fixes come after it, so this doesn't block.

**Next**: W10.6.4 once W10.6.7 lands. The `smoke-1` record stays on `run-records`; real runs use
their own run ids.

## #47 — 2026-10-13 · W10.4.5: dcg back as the Bash guard

**Why**: v1 ran dcg (Destructive Command Guard) as a PreToolUse hook on Bash. v2 carried the lesson
(F-HOOK-06, a missing tool must not pass) but not the tool: it went with v1's hook layer (D-14), and
no decision dropped it. The owner asked for it back.

**What moved**: the plugin registers a PreToolUse hook on Bash (timeout 30 s) that runs the
version's `runtime/hooks/pre-bash.sh`, which hands the hook input to the pinned dcg (0.14.4, the
newest release at least two weeks old; the release ships a static `musl` build for x86_64 Linux and a
`SHA256SUMS` file). dcg's own deny JSON goes back to Claude. The script fails closed where dcg
doesn't: a missing dcg, a non-zero exit, more than 10 s, and (via `DCG_FAIL_CLOSED=1`) hook input it
can't parse. dcg runs with its default packs; v1's `.dcg.toml` is not carried. `install/tools.pin`
and `ci.yml` pin the same version and checksum. Feedback, not a wall (L-36). Session start (the
version's `session-start.sh`) prints a `DEVSHOP:` line when the installed plugin registers the guard
but dcg is missing, so a broken install shows in the first reply, not at the first blocked command
(owner, in review).

**Evidence**: `tests/pre-bash.test.sh`, written first, failed against `main` (`the plugin registers
no PreToolUse hook`). With the change it passes against the real dcg: five destructive commands
blocked with dcg's reason, five ordinary ones silent, unparseable input blocked, and missing,
failing and hung dcg each blocked with exit 2. Four mutants (no `DCG_FAIL_CLOSED`, no timeout, a
missing dcg passing, a failing dcg passing) are all killed. The session-start line's scenarios in
`tests/git-hooks.test.sh` (missing dcg reported, also outside a git repo; silent with dcg installed;
silent with a plugin from before the guard) failed before that change and pass after; two mutants
(no plugin check, no dcg check) are killed. `tests/bootstrap.test.sh` now installs a fake dcg from
the pinned tools and checks it lands in `/opt/devshop-tools/bin`.

**Surprises**: dcg 0.14.4 fails open on unparseable input unless `DCG_FAIL_CLOSED=1` is set, and
lets `rm -rf /` written inside a heredoc through (v1's friction-log case now goes the other way).

**Next**: the owner's fresh-session check after the environment rebuilds: `git reset --hard` from
Claude is blocked with dcg's reason, and `ls` runs.

## #48 — 2026-10-13 · W10.6.7 the reviewer runs by itself (in progress)

**What moved**: the hook's contract went into the W10.6.7 line first, then the owner's calls were
folded in. `runtime/hooks/review-hook.py` is registered by the plugin as a PreToolUse `gate` (PR
create through the GitHub tool or `gh pr create`, a `git push` to a branch with an open PR, an edit
of the PR's title or body) and a PostToolUse `post`. Only `REVIEW: pass` with exit 0 lets the call
through. Every other result blocks it: a fail returns its findings, and anything else says to ask
the owner. After the call, the pass is posted as the `pr-comment.sh` comment. If GitHub's copy of
the words differs from the reviewed one (PR #78 gained a footer after its review), the posted words
are reviewed again and that verdict is posted. The marker now carries `words`, the sha256 of the
reviewed words (`pr-words.sh`), and `review-verdict` (also run on `edited`) reads changed words as
stale.

**Owner calls**: (1) post only verdicts for a commit the PR contains: passes, and any re-review of
the posted words; (2) catch edited words in the hook and in the check; (3) block the GitHub tools
that commit on GitHub (`push_files`, `create_or_update_file`, `delete_file`) on a branch with an
open PR.

**Evidence**

- Tests written first, failing (no hook registered, no `pr-words.sh`). `tests/review-hook.test.sh`
  (stub `review.sh` and `gh`, a local origin) covers every case in the task, plus the registration
  and a missing hook. `tests/reviewer-pr.test.sh` gained `pr-words.sh` (known-bad inputs refused)
  and `--words`. Mutants: 58/58 killed. The first run left 11 survivors: 3 redundant checks, now
  removed, and 8 test gaps, now tested.
- The real harness runs it: with this branch's hook registered for the session only
  (`.claude/settings.local.json`, not committed), `gh pr create --fill --dry-run` was blocked with
  "the hook can't know the PR's words".
- In this session, `tests/bootstrap.test.sh` and `tests/git-hooks.test.sh` fail on `main` too:
  there's no `gitleaks` at `/opt/devshop-tools/bin`. They're not affected by this change, and CI
  installs the pinned tools.

**Surprises**

- Dogfood caught a false block: a Bash heredoc whose body had an apostrophe and the words "git push"
  couldn't be split into words, and the fallback matched "push" anywhere. Heredoc bodies are now
  dropped before splitting, and the fallback matches only a command at a line start or after an
  operator. Regression tests were written first and failed first.
- Opening this PR through the hook was blocked: `REVIEW: could-not-run … could not make the
throwaway clone`. Cause: a cloud session's clone is shallow, and `git fetch` from a shallow repo
  into `review.sh`'s empty clone rejects the refs but exits 0. Fixed with `--update-shallow` (owner's
  go). The test was written first: `tests/reviewer.test.sh` runs the reviewer from a shallow clone,
  and it failed with the same reason before the fix.
- The retry ran the real reviewer, and it failed the create on a medium finding: a pass recorded for
  a call that then failed (a create that errored, a rejected push) stayed behind, and a later call's
  post used it. Now every gate clears the branch's recorded pass first, and the pass carries its call
  kind. The tests were written first (one for each rule), and both mutants are killed.
- The next retry failed too (medium): in `--body "$(cat <<'EOF' …)"` or `--body "$(cat f)"` the
  shell expands the value, but the gate would have reviewed the literal text. Values with `$(`, a
  backtick, `${` or `$VAR` are now could-not-run ("use `--body-file`"). Tests first, 3 mutants killed.
- Round 3 became ask-owner (owner: fix all and retry). Medium: a `cd` before the operation was
  ignored, so the wrong worktree could be reviewed; a command that changes directory and creates,
  pushes or edits is now refused. Low: `git --git-dir x push` went unreviewed (now refused); an
  unquoted `--body $(cat f)` left a bare `$` (any `$` or backtick in a title or body is now
  refused); `update_pull_request_branch` commits on GitHub unreviewed (now blocked); a Build skill
  bullet was unwrapped. The hook's own gap: ask-owner printed no findings (now it does). Tests first.

- Round 4 became ask-owner too. Unsure (blocks): pushes wrapped in `bash -c`, `eval`, `sudo`,
  `timeout`, `env -i` and the like go through unreviewed. Owner: keep that as a documented limit; the
  `review-verdict` check is the backstop. Low, fixed test first: the branch name now goes into the
  PR lookup URL-encoded (a ref with `&` could hide its open PR); the W10.6.2 `--pr` note now names
  `pr-words.sh`. Low, not fixable here: the reviewer can't run this repo's tests (F-NEW-23).
- **Round counter (data point for W10.6.4–5):** rounds 3 and 4 asked the owner although each round's
  blocking findings were new and the earlier ones fixed. Owner's question: should the count reset
  for a new issue? Proposed: reset when no blocking finding repeats the previous round's (matched by
  lens and file), with a hard cap of reviews per branch that always asks. It changes the W10.6.2
  interface, so it is its own task.
- Round 5 passed, and the create went through: PR #88. GitHub then appended its footer to the body,
  so the post hook re-reviewed the words as posted, as designed. That review failed (unsure):
  redirections such as `git push 2>&1` and `gh pr create … >out` were read as arguments. Fixed test
  first: redirections are dropped with their target. The fail verdict was posted on the PR; the
  `review-verdict` check reads it as failing until a pass is posted. The hook's message after a
  re-review also said "the call was blocked" though the PR existed; now it says to fix and push.
- **Order of edits:** a push is reviewed with the PR's current words, and an edit of the words with
  the PR's current head, so code and words can't change in one step. A body that lists every fix
  goes stale with each new fix. The body now points here for round details. For the Build skill:
  keep per-round detail out of the PR body.
- The body edit's review (at the PR's head) failed (medium): the fallback pattern for a missing hook
  didn't name `update_pull_request_branch` (caught only as a substring), and nothing tested the
  hook's tool list, the matcher and the fallback against each other. Now one test reads all three.
- The push with those fixes passed its review (`dc5c3b70e949`), but the post read the PR a moment
  before GitHub showed the new head and gave up. Re-run by hand from the recorded pass, it posted
  the pass for that head. Fixed test first: the post re-reads the PR for up to 10 s.

- **Redesign (owner, 2026-10-13).** The PR did open through the hook, and its `review-verdict` check
  went green from the comment the hook posted (head `dc5c3b70e949`). But the next fix deadlocked: a
  push is reviewed with the PR's old body (which named a stale mutant count), and the body edit is
  reviewed against the PR's old code (where the next review found a loop-wrapped push unseen). The
  owner asked whether the flow was simple and reliable, and expected the review to be local before
  anything reaches the PR. It wasn't: it inferred PR-bound calls from shell commands, reviewed code
  and words apart, and leaned on a CI job that was no wall. Owner: replace it with `ship` (review in
  the VM, then push, PR words and verdict together) and a guard that only refuses the other ways;
  drop the `review-verdict` job, `verdict-check.sh` and `verdict-wait.sh`; reset rounds on new
  issues with a cap of 6 failing commits. `596db38` (the post hook's wait for GitHub to show the
  head) stays in the branch's history; the redesign deletes its code.

**Evidence (redesign)**

- Contract first (W10.6.7 line), then tests written first and failing: `tests/ship.test.sh` (no
  `ship.sh`), `tests/review-guard.test.sh` (the post hook still registered), and the rounds cases in
  `tests/reviewer.test.sh` (a new finding after a repeat asked the owner).
- Mutants on the guard, `ship`, the rounds rule and `pr-words.sh`: 39/40 killed (34/35 before the
  fixes below). The first pass left
  5: the guard's redirection handling (unneeded once the guard stopped reading arguments: removed),
  two missing tests (a branch name that quietly misparses unencoded; an error inside the guard), and
  `ship`'s `REVIEW:` line count, equivalent (two lines also fail the exit check).
- The harness runs the guard: with it registered for this session only, `gh pr create --dry-run`
  was refused, pointing to `ship`.

- **Dogfood: `ship` on PR #88.** First run: `REVIEW: fail` (medium), and nothing was pushed: in a
  single-branch clone, `git fetch origin <base>` doesn't update `origin/<base>`, so the review would
  diff against a stale or missing base. Fixed test first (a `--single-branch` clone in
  `tests/ship.test.sh`, which also showed the default-branch fallback broken: `gh api --jq`, now
  `| jq`). Lows fixed too: the guard now skips gh's global flags (`gh -R o/r pr create`) and sees
  glued short flags (`gh pr edit -tTitle`); the W10.6.6 lines naming the removed check are marked.

- Second run: `REVIEW: pass`; pushed, PR words set, verdict posted. Then exit 2: the session's
  GitHub access appends an attribution footer to every PR body write, so set-back never stuck. Owner:
  post what the reviewer saw and let GitHub append; `ship` now accepts the PR when the title is the
  same and the body starts with the reviewed one, with no set-back and no footer text in the code.
  A rewritten body or changed title is still reported. Tests first; 39/40 mutants killed.
- Tests and the reviewer (F-NEW-23): the tests already run in the VM while building and in CI after
  the push; the reviewer judges whether they cover the change. Proposed for W10.6.5: one prompt line
  saying CI runs them, instead of a second run inside `ship`.

- Merging `main` (#89, dcg back as a PreToolUse hook on Bash) left `hooks.json` with two
  `PreToolUse` keys and no conflict marker; a JSON reader keeps one, so dcg would have been dropped.
  Fixed: one array, dcg first (its test reads `PreToolUse[0]`), then the guard; the guard's test now
  finds its entry by command and fails on a duplicate key (proven on a known-bad file).

**Next**: ship again; then the owner's fresh-session check (W10.6.7's done-when).

## #49 — 2026-10-13 · W10.6.7 done: owner's fresh-session check of `ship` and the guard

**Owner's check** (a fresh session on this repo, devshop HEAD `8597c6e05207`, copy of 2026-10-13
04:14 UTC; the merge of PR #88, shipped through `ship` with a pass verdict, CI green):

- **Parts:** `/opt/devshop-current/reviewer/ship.sh` and `/opt/devshop-current/hooks/review-guard.py`
  present and executable.
- **Direct PR create refused:** `gh pr create --dry-run -t probe -b probe` was blocked by the guard
  ("gh pr create is refused"), pointing to `ship`; nothing created.
- **A failing review stops at `ship`:** branch `check/fail` adds an untested `scripts/hello.sh`, and
  its body falsely claims `tests/hello.test.sh`. `ship` printed `REVIEW: fail · round 1 · 3
blocking` (high on `tests`: the claimed test doesn't exist; medium on `pr`: the false claim;
  medium on `intent`: no stated purpose or go), exit 1. `git ls-remote origin check/fail` printed
  nothing: never pushed, no PR.
- **A passing review opens the PR:** branch `check/pass` clarifies one sentence in
  `runtime/stacks/README.md` (checked against the script). `ship` printed `REVIEW: pass`, pushed
  (pre-push secret scan and lint ran), and `SHIPPED: PR #90`, with the pass verdict comment for its
  head.
- **A direct push to the open PR refused:** a second commit on `check/pass`; `git push` was blocked
  ("git push to check/pass, which has an open PR, is refused"). The session's stop hook then asked
  for the push; Claude didn't get around the guard but shipped the commit: a new review passed, a
  second verdict comment landed for the new head, and CI was green on it.

**Passed.** W10.6.7 is done.

**Seen in passing:** writing the check's files through a shell redirect to a path held in a
variable was blocked by dcg (W10.4.5); the session wrote them with the file tool instead. A data
point for dcg's false positives, not a W10.6.7 issue. A shipped PR body's CI line says "not run
yet", true when shipped; by design it changes only through a new `ship`.

**Next**: W10.6.5 (the reviewer eval; F-NEW-23 handed to that session) and W10.6.4 (the north-star
run, which W10.6.7 unblocks).

## #50 — 2026-10-13 · W10.6.5 reviewer eval: recall 0.33 → 1.0 after the owner-agreed fix

**What moved**: the first eval of the real reviewer (unchanged, `main` at `c6a84a5`) on the
fixture, for A-12. 5 honest changes × 3 runs: 3 features with specs (`starred`, `done`, `priority`
from the idea pool) and 2 bug fixes with no spec, on a base with two real search bugs so each fix
leaves one pre-existing, out-of-scope bug beside it. 15 planted changes: each of the 5 harness
plant types on each feature, applied by the harness's own `apply-plants.mjs` (seed 1) and
committed like `plant-run.sh`. Each run is a fresh local worktree. Nothing was pushed to the
fixture, so its `main` and `baseline-2` never moved. Record:
[spikes/w10-6-5-reviewer-eval](spikes/w10-6-5-reviewer-eval/README.md) (driver, patches, PR
words, the 30 verdict files and plant records).

**Evidence**

- Honest: 15/15 pass, 0 blocking findings, 0 `unsure` (34 `low` findings across all 30 runs). Each
  honest change passed the fixture's full CI locally first (`npm test`, `tests/run.sh` with the
  pinned gitleaks and shellcheck, `npm run lint`).
- Planted: 5/15 fail. **Precision 1.0, recall 0.33**; 0.27 counting only fails that name the plant.
  By type: `loosened-test` 2/3, `reworded-acceptance` 2/3, `skipped-state-row` 1/3 (on the plant's
  leftover blank line, not the skipped row), `untested-acceptance` 0/3, `false-verified` 0/3. All
  15 planted commits keep `npm test` green (2 fail Prettier).
- Cost $2.50 for 30 reviews ($0.03–0.12 each), about 30 s each.
- **Likely root cause of the misses:** by the verdicts' own words, 19/30 say Bash was refused and
  they reviewed by reading (planted: 2/10 failed), 8 say Bash ran but vitest isn't installed in
  the throwaway clone (planted: 2/3 failed), 3 say neither. Two re-runs through a pass-through
  `claude` that kept the output showed the mechanism: the first Bash call is a compound command
  (`cat …; git log | head; …; npx vitest run`), the allowlist refuses it, and the prompt says "If
  a command is refused, read instead", so the reviewer stops using Bash. A direct probe with the
  same flags ran `git log`, `git diff` and `npm test` one at a time without trouble. A reviewer
  that only reads never sees a "Follow-up edits" commit as a commit. The groups are small; the
  re-run after the fix is the test.

**Surprises**

- The reviewer's first pass on my own first `starred` change was a correct `high`. The fixture's
  route check rejects a route with a query, so CI's `tests/run.sh` would have failed. I had run
  only `npm test`. It found this by reading a script the change didn't touch. All three features
  were fixed (test first) before the eval.
- Harness quirks (owner-held, not changed): `skipped-state-row` matches a state name anywhere in
  a test title (it removed an AC test once and the wrong state's test once) and leaves a blank
  line that fails Prettier; `reworded-acceptance` can rewrite a quoted UI label; `false-verified`
  marks a wrapped item mid-sentence.
- Every verdict records the calling session's id as `reviewer.session_id`: the nested `claude -p`
  inherits `CLAUDE_CODE_SESSION_ID`, so the field can't tell reviews apart (found by the reviewer
  on this PR, `low`). Not fixed here: it is `review.sh`'s environment, an owner call.
- This session cloned the harness before the agent identity lost access (LOG #46). Its clone stays
  in this container only.

**Owner calls** (2026-10-13, after the run-1 numbers): (1) fix the reviewer; (2) F-NEW-23 → B,
the reviewer reviews tests by reading and CI runs the suite: every plant kept the tests green and
the one real bug was found by reading; (3) F-NEW-24 → no prompt line: 0 `unsure` in 30 runs, and
such a line would have downgraded the one real catch, a pre-existing limit the change made
reachable. The small items too: fix the session id, fix the harness quirks, file the findings.

**The fix** (W10.6.2 interface note first; `tests/reviewer.test.sh` written failing; 8 of 8
mutants killed after closing one survivor):

- `prompt.md`: one simple command per Bash call; a refused command means use an allowed one,
  never stop; start from `git log base..head` and review commit by commit. With a spec: each
  `AC-<n>` named by its test (as the Build skill already asks), "verified by review" needs a real
  step, a test per state-table row, an item edited after the go without a recorded owner call is
  `high`; an assertion that can never fail is at least `medium` (F-NEW-28).
- `review.sh`: the reviewer's `claude` runs without the calling session's identity variables. The
  cause was `CLAUDE_CODE_REMOTE_SESSION_ID` (found by unsetting one at a time); the messaging and
  ingress variables go too, so the reviewer can't reach the builder's session (F-NEW-29).

**Run 2** (same changes, plants and seeds): honest 15/15 pass, planted 15/15 fail, each naming its
plant; **precision 1.0, recall 1.0**; 0 refused commands and 0 `unsure` across the 30 runs; 30
distinct session ids; $1.83. Two planted runs first picked up a harness copy I was editing and got
different plants; I discarded them and re-ran both on the original harness (`d382e2e`), so every
run-2 plant record equals its run-1 record. `tests/reviewer-live.sh 1`: 6 of 6 as expected.
**Run 3** (seed 2, original harness): 15 new plant targets, 15 of 15 caught on their plant, 0
refused commands, $1.02. The reviewer, run on this PR, rightly said run 2 isn't held out: the
prompt's new rules name these plant types. Run 3 shows they generalise within the types, not
across them. Caveat: the plant is always its own commit, which commit-by-commit review makes easy
to spot. W10.6.4 tests the reviewer again.

**F-NEW-23, follow-up** (owner: option A, raised by the W10.6.7 session): every review of this
repo listed a `low` "couldn't run the tests". The prompt now says the tests run while building and
in CI on every push, so the reviewer judges coverage and puts a command it can't run in the `tests`
lens note, not a finding. Interface note first; the prompt test failed first; removing the line is
caught. The rejected option: `ship.sh` running the suite again before each review. The reviewer, run on
this PR, failed the first ship of it (medium): no eval covered the new rule. **Run 4** on the final
prompt (honest set, seed-1 plants, original harness): honest 15/15 pass, planted 15/15 fail on
their plant, plant records equal to run 1's, 0 refused commands, no "couldn't run the tests"
finding (20 verdicts say it in the `tests` note), $1.86. Its next review flagged the rule
(`unsure`): stated as fact, it would let a project without CI pass with tests nobody ran. Now it
applies only when the project runs its tests in CI, else an unrunnable test is `unsure` (test
updated first; the old and a partial prompt both fail it). **Run 5** on that wording: honest 15/15,
planted 15/15 on their plant, $1.93; one slip in 30, a planted run that filed "could not run the
tests" as `unsure` despite naming the CI workflow (1 in 60 over runs 4–5; known residual).

**Harness** (F-NEW-30): the three quirks fixed test first (5 new tests failing first, 32 of 32
after, 8 of 8 mutants killed); on the real fixture changes the state plant now removes a state's
own test and the planted tree passes Prettier. The agent has no access to the harness (LOG #46),
so the owner applied the patch as harness PR 4. Checked live: on a throwaway fixture PR
carrying the eval's `starred` change, the owner ran `apply-plants` with the three fixed plants.
Its "Follow-up edits" commit removed the "Starred view:" state test (not an AC test), reworded
AC-3's unquoted "only" (the quoted labels untouched), and marked AC-6 "verified by review" at its
end; three different items. The fixture's `lint` (which the old state plant failed) and `test`
passed on it. The wrapped-item case of `false-verified` wasn't hit by this run's pick; the harness
tests cover it. The fixture PR was closed unmerged.

**Next**: W10.6.4 (W10.6.7 is done, LOG #49).

## #51 — 2026-10-13 · W10.4.6 CI in two tiers, fast and slow

**Why**: the owner asked whether lint in both CI and the pre-push hook wastes resources. It
doesn't: CI is the wall and the hook is skippable feedback that saves a CI round trip. The waste
was in CI itself: two jobs repeating the checkout, tool downloads and `npm ci` for checks that take
seconds. The owner then asked for two tiers, chosen by concept (unit vs end to end), not time, and
for new projects to pick the pattern up. Spec: `specs/ci-fast-slow-tiers.md`, with the owner's go.

**What moved**: every project declares `scripts/check-fast.sh <base>` (secret scan, `lint.sh`,
unit tests) and `scripts/check-slow.sh` (end-to-end tests; a placeholder that says so when there
are none). CI runs job `fast`, then job `slow` with `needs: fast`, from the stack-agnostic
`runtime/templates/ci.yml`. `runtime/scripts/ci-tiers-check.py` checks that shape (PyYAML,
hash-pinned in CI; missing is "couldn't run"). This repo's lint runs it on its own `ci.yml`, and
session start runs it on the project's, with one `DEVSHOP:` line when the CI is missing, breaks a
rule, or can't be checked. The `build` skill points a project without CI at the template. Here,
`tests/run.sh fast|slow` picks a tier by a `# tier: slow` header line; only
`tests/bootstrap.test.sh` (the whole install) is slow. The three tests that sandbox with `unshare`
stay fast: a sandbox doesn't make a test end to end. The pre-push hook is unchanged (owner). The
fixture is retrofitted in its own PR: `lint.sh` (so the hook lints there too), `setup.sh`, both
tier scripts, and `deploy` needs `fast` and `slow`.

**Evidence**: each check was written failing first. `tests/ci-tiers-check.test.sh` has 27 cases,
including this repo's real `ci.yml` (exact jobs and tools), and 8 of 8 mutants are killed. `tests/run-tiers.test.sh` has 5 cases (3 of 3 mutants killed).
`tests/check-tiers.test.sh` has 4. The AC-3 cases in `tests/git-hooks.test.sh` give 4 (3 of 3
mutants killed). `tests/lint.test.sh` now covers five checks. Locally on the final head,
`check-fast.sh` passed (23 fast test files) and `check-slow.sh` passed (1 slow), the slow one with
a bare PATH (no gitleaks, shellcheck, dcg or npm packages). The fixture's own test has 6 cases
(3 of 3 mutants killed), and its real `check-fast.sh` passed after `setup.sh`. The new check fails
on the fixture's CI on `main` (no `fast`, no `slow`, deploy needs neither) and passes on the branch.

**Surprises**: the adversarial spec review caught that an optional slow job can't be in a single
template, which gave the always-present `check-slow.sh` placeholder. It also caught that three
"fast" tests need user namespaces, so the rule became end to end vs unit, not sandboxed or not.
Locally, three suites only ran once the tools were copied out of `/opt` (the tests mount a scratch
`/opt`) and the clone was unshallowed (bootstrap pins a pre-move commit).

**Fixture**: fixture PR #11 passed its review, then `fast` and `slow` on its head; the owner
approved and merged it, and on its `main` both tiers passed before the production deploy.

**Changed after the go** (owner, "option 1"): the reviewer can't read GitHub or the fixture, so
this PR's CI and the fixture's retrofit are the owner's checks at merge, not acceptance items, and
AC-1 names the step-level `if` / `continue-on-error` rule (spec, Decisions).

**Done**: PR #92 had `fast` and `slow` green on its head (a1ebd87); the owner approved and merged
it. Fixture PR #11 merged too, and on the fixture's `main` `fast`, `slow` and the production deploy
passed. Whether the required checks on `main` were swapped to `fast` and `slow` is owner-held: the
agent can't read branch protection.

## #52 — 2026-10-13 · W10.6.8: three reviewer limits from the W10.6.5 eval

**What moved**: the follow-up to LOG #50, filed first as F-NEW-31–33 and the W10.6.8 task line; the
W10.6.2 interface note changed before any code. Tests came first: each new check in
`tests/reviewer.test.sh` failed on the old code, and 13 of 13 mutants are killed.

- **Session ties by pattern (F-NEW-31).** `review.sh` removes every variable matching
  `CLAUDE_CODE_*SESSION*`, `*INGRESS*`, `*MESSAGING*` or `CLAUDE_CODE_*SDK*`, a superset of the old
  11 names. The test sets those 11 plus made-up future names, and checks that auth and proxy
  variables (`ANTHROPIC_*`, `CLAUDE_CODE_OAUTH_TOKEN`, `HTTPS_PROXY`, CA files) still get through. In
  this cloud session the reviewer authenticates through the API endpoint and proxy variables, none of
  which match. `tests/reviewer-live.sh` now fails a review whose `session_id` is empty, the caller's,
  or another run's. `tests/reviewer-live.sh 1` gave 6 of 6 with 5 distinct ids of its own, and the
  same script on a copy that keeps the session's variables gave `NOT OK`, carrying the caller's id.
- **One source of allowed commands (F-NEW-32).** `prompt.md` has `{{COMMANDS}}`, and `review.sh`
  fills it from the `settings.json` allowlist's `Bash(<command>:*)` entries. Unreadable, empty or
  other-shaped entries are could-not-run. A test edits a copy of `settings.json` and the prompt
  follows. The entries were reordered so the prompt lists them in the old order.
- **CI stated, not inferred (F-NEW-33).** The prompt says whether the base commit has
  `scripts/check-fast.sh` and has no branch asking the model to work it out. Declared: an unrunnable
  test goes in the `tests` note. Not declared: it is `unsure`, with the fix "a CI job that runs the
  tests". The backstop line: a finding whose only fix is to run the tests or confirm CI is never a
  finding.

**Owner calls**: the declaration was first `scripts/test.sh` (owner, picked from my proposal). Then
the owner pointed me at the parallel "Lint in CI vs devshop hook" session, whose draft spec
(`specs/ci-fast-slow-tiers.md`) makes `scripts/check-fast.sh` the script CI's `fast` job runs. The
owner switched to that file: one contract, not two. So this change adds no script and doesn't touch
`ci.yml`.

**Eval run 6** (spike README § Run 6): honest 15/15 pass, planted 15/15 fail on their plant,
**precision 1.0, recall 1.0** (before: 1.0 / 1.0 with 1 tests-note slip in 60). 0 refused commands,
0 `unsure`, no "couldn't run the tests" finding, 30 distinct session ids, none the caller's. $1.81.

**Surprises**

- This session couldn't reach the harness (LOG #46) and had no fixture clone. With the owner's OK I
  attached the fixture read-only (nothing pushed). The seed-1 plants were replayed from their
  records by a new `replay-plants.py`, checked line by line against each record's `before` text, and
  all 15 matched. `prepare.sh` rebuilt the cases from the spike's patches on a local base that adds
  `scripts/check-fast.sh`.
- `tests/run.sh` here: 18 of 21 files pass. `bootstrap`, `git-hooks` and `pre-bash` fail the same way
  on unmodified `main` in this container (a shallow clone, and the push and dcg checks depend on the
  environment). CI runs them.

**Order** (owner): `ship` first failed this change on one `medium`: merged before the CI tiers change, honest reviews here and in the fixture would get `unsure` for tests they can't run. The owner held it until the tiers change landed (LOG #51: this repo's PR #92, fixture PR 11, both with `scripts/check-fast.sh` at the root). Then `main` was merged in and it shipped again.

**Next**: W10.6.4.

## #53 — 2026-10-13 · W10.6.9: PR body for the owner's reading, screenshots on the PR

**What moved**: the owner's feedback on the PR bodies of a W10.6.4 run, filed first as W10.6.9. Tests
came first: 12 new cases in `tests/pr-body-check.test.sh` each failed on the old check, and every
old case still passed.

- **Second level.** Under the one-line summary, one plain paragraph of 2–3 sentences on what
  changed and why it matters, before the **Preview:** line. The template quotes the owner's example
  as the register. The check counts sentences (an end before a capital or the end, so "e.g. the
  bus" is one sentence) and refuses markup or a second paragraph.
- **Announcement as a release note.** The template's guidance says what the person who uses the app
  can now do, in their words. The check refuses developer words there: code, `AC-<n>`, routes, file
  names and status codes ("a 404 page", "error 500"; "500 items" passes).
- **Screenshots on the PR.** `**Screenshots:**` needs an image or "no UI change", so "not embedded
  here (no image host in this session)" fails. An image on `raw.githubusercontent.com` fails even
  when pinned: a private repo's viewers get a 404 there.
- **Code is quoted, not checked.** The image and GitHub-link checks read code spans, while the
  placeholder check skipped them, so a body quoting an image line in code failed (found writing
  this PR's body). Now all three skip code. Two more cases, each failing on the previous version.
- **The image host** (owner: option B, a hidden ref first). The session's git proxy accepts pushes
  to the session branch only (LOG W0.4.1), so `runtime/scripts/pr-assets.sh` uses GitHub's REST
  git-data API through `gh`. Each blob's SHA must equal `git hash-object` of the file. The tree and
  an orphan commit naming the branch and HEAD follow, then `refs/devshop-assets/<branch>/<head12>`,
  created or moved with force when the screenshots are retaken. Ref, commit and tree are all read
  back, and the script prints `![label](https://github.com/<owner>/<repo>/raw/<commit>/<file>)`
  lines. `tests/pr-assets.test.sh` runs it against a stub `gh` with a fake object store; 11 of 11
  mutants are killed (the tree read-back survived at first, and the test gained a case for it).

**Owner calls**: Git LFS ruled out: its pointers still land on `main`, its objects can't be deleted,
and every clone downloads them. Adding and then removing the images on the PR branch was ruled out
as fiddly. A `devshop-assets` branch is the fallback, if GitHub refuses a ref outside `refs/heads/`.

**Decision**: the Build skill runs `pr-assets.sh` before writing the body, and `ship` doesn't run it
after the pass. The links have to be in the words `ship` reviews and posts (F-NEW-27), and they
depend on the upload. An upload for a change that then fails review only leaves a hidden ref.

**Surprises**: in this session auto mode refused a probe write of an unreferenced blob to this
repo ("modify shared resources"). Projects will need `gh api` writes allowed for `pr-assets.sh`;
the live run on the fixture will show the prompt. `tests/run.sh`: 22 of 25 files pass; `bootstrap`,
`git-hooks` and `pre-bash` fail identically on a clean `main` worktree here (LOG #52).

**First ship, and a live probe** (owner's go, 2026-10-13): `ship` passed the review (0 blocking, 2
low) and opened PR #95, then stopped with exit 2: something on the session's path to GitHub dropped
the `!` from a code-quoted image line in the body. Both low findings were fixed: each upload now
gets its own never-moved ref, `refs/devshop-assets/<branch>/<head12>-<commit12>`; and a template
line was rewrapped (14 of 14 mutants killed). The probe on this repo found the REST git-data path
**closed**: the session's GitHub proxy answers "Write access to this GitHub API path is not
permitted through this proxy" (HTTP 403) on the first blob, and `pr-assets.sh` failed closed. A plain
`git push` of the same commit to the hidden ref never left the session: the review guard refuses any
push while the branch has an open PR, and auto mode refused it too. Whether the git proxy accepts a
ref outside `refs/heads/` is still unknown.

**Left**: the owner's call on the upload route: (A) push the hidden ref with plain git (needs the
guard to allow `refs/devshop-assets/*`, a permission rule, and the proxy to accept it), or (B) carry
the screenshots on the PR branch as the second parent of a merge commit whose files equal the code
(the push the proxy allows; nothing to remove). Then the live render check in the browser and the
GitHub mobile app, before and after merge.

**Next**: W10.6.4.

**The one probe push** (owner's go): `git push origin <commit>:refs/devshop-assets/…` from a
detached worktree (the review guard refuses any push from a branch with an open PR) got `HTTP 403`
from the session's git proxy; `git ls-remote` shows nothing was created. So a cloud session can push
only its own branch, and the screenshots ride on it. **Route B, built test-first**:
`pr-assets.sh` writes the images as a parentless commit S (local `git hash-object`, `mktree`,
`commit-tree`) and moves the branch to a merge of HEAD and S with HEAD's tree, so the PR's files and
diff don't change. `ship`'s ordinary push carries S; GitHub keeps it with the PR
(`refs/pull/<n>/head`) after the merge and the branch's deletion. The script reads the repo's
merge settings and refuses unless squash is the only method (a merge commit or rebase merge would
carry S into the default branch). The test walks a PR's life on a local remote: two uploads, a
retake, a fix round, a squash merge, the branch deleted, a fresh `file://` clone without S; 16 of 16
mutants killed. The reviewer prompt names the two screenshot commits as not part of the change. The
PR body check's inline code no longer crosses a blank line (the reviewer's low finding), test first.

**Signing** (found by the session's stop hook before anything was pushed): `git commit-tree` ignores
`commit.gpgsign`, so the two screenshot commits were unsigned, which GitHub shows as Unverified and a
signed-commits rule would refuse. `ship` was stopped before its push and the branch reset to the last
signed commit; the script now passes `-S` when `commit.gpgsign` is on (test first, with a stub
signer).
