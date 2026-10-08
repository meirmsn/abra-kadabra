# Decisions

Decisions that shape the plan and belong to the owner. Each lists options, a
recommendation, what it blocks, and — once made — the outcome and date.
Revisiting a decision: add a dated **Revisited** line under it (never rewrite
history) and record the plan impact in [PLAN.md § Changelog](PLAN.md#changelog).

Status: `open` · `decided` · `revisited`.

| ID   | Decision                                           | Blocks                      | Status |
| ---- | -------------------------------------------------- | --------------------------- | ------ |
| D-01 | Distribution model                                 | M2 (W4, W5, W8)             | open   |
| D-02 | Fate of the local devcontainer                     | M1 scope of W1.3, M2 (W4.4) | open   |
| D-03 | How devshop changes land                           | M0 (process), W4.6          | open   |
| D-04 | Where the security boundary is                     | M1 (W1), M2 (W4.3)          | open   |
| D-05 | Plan tier assumptions (Pro/Max vs Team/Enterprise) | W4.3                        | open   |
| D-06 | Orchestration technology                           | M3 (W6.4)                   | open   |
| D-07 | gstack install model and target version            | W7                          | open   |
| D-08 | Recipe model naming + `stack.yaml` schema          | M4 (W5)                     | open   |
| D-09 | Migration of existing projects (lalista, home-os)  | M2/M4 exits                 | open   |
| D-10 | Revamp versioning                                  | M2                          | open   |
| D-11 | Deletion list                                      | M5 (W9)                     | open   |

---

## D-01 Distribution model — `open`

How does a project get the devshop, and which version?

- **A. Pinned in-project install** _(recommended)_ — `devshop install vX.Y.Z` writes
  `.devshop/` (version, `stack.yaml`, kit scripts, recipes) and `.claude/`
  (skills, agents, settings hooks) into the project; upgrades are a reviewed PR.
  Works in single-repo cloud sessions with hooks + permissions (F-CLOUD-02), locally,
  and gives real per-project versions (fixes F-VER-01..04). Cost: project repo
  carries devshop files (scoped to two dirs; inert without Claude).
- **B. Two-repo session (devshop + project)** — skills/CLAUDE.md load from both, no
  copying; but no hooks/permissions and no pinning (devshop default branch is live).
- **C. Claude Code plugin + marketplace (pinned ref)** — native versioning, but
  repo-declared plugins don't load in cloud sessions today (F-CLOUD-02); doesn't
  cover template/CI/git hooks.
- Recommendation: **A** for projects; **B** only for sessions that edit the devshop
  itself; revisit **C** if cloud starts loading repo-declared plugins.

Outcome: —

## D-02 Fate of the local devcontainer — `open`

- **A. Cloud-first, local supported via the same install script** _(recommended)_ —
  one `install-tools.sh` used by both the cloud setup script and the Dockerfile;
  drop the root-owned-copies/sticky-bit locking model (cosmetic on macOS anyway,
  F-SEC-13) in favour of the outside-the-VM boundary (D-04); keep only cheap local
  hardening (F-SEC-01/02/03/15).
- **B. Keep local as first-class with full hardening** — fix every container
  finding (sticky bits, sudoers, firewall gaps); large effort, macOS still weak.
- **C. Cloud-only** — delete devcontainer; loses offline/macOS/iOS work (use Remote
  Control for those).

Outcome: —

## D-03 How devshop changes land — `open`

- **A. Branch → PR → CI (bats) → owner approves → merge** _(recommended)_ — the only
  path that works in cloud (F-CLOUD-03); gives devshop CI and review. Retire the
  push-to-main parts of `/ak-merge-devshop`; keep its squash-message composer as PR
  body guidance. Requires updating CLAUDE.md's "no PRs on devshop" rule.
- **B. Keep `/ak-merge-devshop` local squash-to-main** — local-only.

Interim (until decided): revamp work goes through PRs on `claude/*` branches, since
that's what this cloud environment supports.

Outcome: —

## D-04 Where the security boundary is — `open`

- **Recommendation:** "The boundary is outside the agent's machine": git proxy
  (no credentials in VM, branch-scoped pushes), GitHub branch protection + required
  checks + required owner approval + CODEOWNERS on `.devshop/ .claude/ .github/`,
  deploys only via Actions environments with owner approval, network allowlist set
  in the environment, production secrets never in the agent environment. In-VM
  hooks/reviewers are **feedback and hygiene**, documented as such — not claimed as
  a boundary.
- Alternative: keep claiming in-VM guardrails as the boundary (then all of W1.3 +
  sandboxing become mandatory, and macOS remains weak).

Outcome: —

## D-05 Plan tier assumptions — `open`

Network secrets exist on Pro/Max (not Team/Enterprise yet); server-managed settings
exist on Team/Enterprise only (F-CLOUD-04/05). Which plan(s) must the devshop
support? Recommendation: design for Pro/Max (network secrets); treat managed
settings as optional extra.

Outcome: —

## D-06 Orchestration technology — `open`

- **A. Slim skills + deterministic scripts** — phases stay skills (split per phase),
  tallies/halts/gate resolution move into scripts that exit non-zero.
- **B. Workflow scripts** (O-03) — real halts, schemas, cached resume.
- **C. Agent SDK program** — maximum control, most new code.
- Recommendation: **A now, pilot B on the pre-ship gate fan-out** in M3; decide on
  full B after the pilot.

Outcome: —

## D-07 gstack install model and target — `open`

Recommendation: pinned copy inside the project install (D-01 A), upgraded to
≥ 1.91.13 (F-GS-04) in a dedicated branch with router-shim + `/ship` adaptations
in the same change; no hourly auto-update/team mode.

Outcome: —

## D-08 Recipe model — `open`

Names: "recipes" (per service) grouped by "capability" (hosting, database, auth,
frontend, e2e, analytics, errors); `starters` = recipe bundles. `stack.yaml` schema
to be drafted in W5.1. Confirm naming + whether recipes ship as skills.

Outcome: —

## D-09 Existing projects — `open`

Which real projects migrate to the pinned model, when, and what compatibility
window the old symlink model keeps (recommend: old model frozen at v1.x; projects
move to v2 one at a time at M2/M4 exits).

Outcome: —

## D-10 Revamp versioning — `open`

Recommendation: keep v1.x patch releases for M1 fixes; cut **v2.0.0** at the
distribution switch (M2); minor releases after.

Outcome: —

## D-11 Deletion list — `open`

Candidates (W9): CLAUDE.md-placement machinery (F-DOC-05), most of
`adversarial-review.sh` check-types (F-REV-06), per-gate n/a files (F-DOC-06),
prose-pinning grep tests (F-TEST-03), `/ak-handoff` (F-GS-07),
`/ak-merge-devshop` push-to-main path (D-03). Confirm each before deletion.

Outcome: —
