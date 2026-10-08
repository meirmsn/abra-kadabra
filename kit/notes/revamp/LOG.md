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
