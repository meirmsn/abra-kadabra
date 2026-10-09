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
