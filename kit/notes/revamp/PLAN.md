# Revamp plan

Level 1 (workstreams) and Level 2 (epics, one line each). Tasks and their status
live in `workstreams/Wn-*.md`. Evidence lives in [FINDINGS.md](FINDINGS.md).

## Principles

1. **Intent over ceremony.** Keep the artifact chain (product → design → spec →
   tasks → code); spend LLM judgement on _does the change do what the spec says_.
2. **Deterministic where possible, LLM where necessary.** Gate selection, tallies,
   halts, and anything checkable by script are scripts that exit non-zero.
3. **Boundary outside the VM.** Security relies on things the agent can't change
   (git proxy, GitHub protections, network policy, secrets that never enter the VM);
   in-VM hooks are feedback (D-04).
4. **Pinned and portable.** A project runs one explicit devshop version, the same
   way in cloud sessions and locally (D-01, D-02).
5. **Core + recipes.** Nothing in the core names a vendor; services are recipes
   selected by `stack.yaml` (D-08).
6. **Right-sized workflows.** Product / fix / patch / hotfix tiers with explicit artifacts.
7. **One fact, one home.** Docs have one entry point and link instead of restating.
8. **Verified increments.** Every step proven at its declared verification level
   before the next builds on it ([PROCESS.md](PROCESS.md)).

## Milestones and exit criteria

| #      | Milestone             | Workstreams          | Exit criteria (all demonstrated, not asserted)                                                                                                                                                        |
| ------ | --------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M0** | Groundwork            | W0, W3.1, W3.2, W4.1 | Plan reviewed; D-01…D-06 decided; baseline metrics in LOG; full bats suite green in GitHub Actions from a clean clone **and** in a cloud session                                                      |
| **M1** | Close the holes       | W1, W2, W3.3 (start) | Every P0/P1 finding in SEC/HOOK/REV/PIPE/INFRA/TPL closed with a regression test; attack-scenario suite (V3) all blocked; fresh template project passes its own CI; v1.x patch released               |
| **M2** | Cloud-native & pinned | W4, W3.3             | Fixture project installed at a pinned version runs hooks + a patch-tier change end-to-end in a cloud session; upgrade between two versions demonstrated; one real project piloted (V5); v2.0.0        |
| **M3** | Verifies intent       | W6, W7               | Spec-conformance gate catches a seeded spec violation on the fixture (and passes the honest version); product/fix/patch tiers each exercised once; gstack ≥1.91.13 with router-shim + `/ship` adapted |
| **M4** | Stack-agnostic        | W5                   | Current stack runs via recipes with no behaviour change (fixture + one real project); a second recipe (e.g. Cloudflare) passes the capability contract tests on a tiny fixture                        |
| **M5** | Lean & legible        | W8, W9, W3.4         | One-entry docs; link + count lint green; size targets (W0.2) met; deletions done; old v1 machinery removed after last project migrated                                                                |

Order rationale: M0 makes verification possible; M1 removes live risk cheaply
inside today's architecture; M2 changes the foundation everything else sits on;
M3 delivers the core promise; M4/M5 broaden and slim. W7 (gstack) may start any
time after M1; W2 fixes can be picked opportunistically; the docs rule
"update docs in the same commit" applies from M1 onward even before W8.

## Workstreams → epics

Priority: **P0** do first · **P1** next · **P2** later. Size: S ≤½ day · M 1–2 days · L 3+ days.

### W0 — Groundwork · [workstreams/W0-groundwork.md](workstreams/W0-groundwork.md)

- **W0.1** Revamp scaffolding + plan review session — P0 · M0 · S
- **W0.2** Baseline metrics (tests, sizes, gates, context load, time-to-PR) + targets — P0 · M0 · S
- **W0.3** Decisions D-01…D-06 made and recorded — P0 · M0 · S

### W1 — Security hardening · [workstreams/W1-security.md](workstreams/W1-security.md)

- **W1.1** Git hooks actually block (errexit, public-safe hooks, no env/FS bypass, push gates) — P0 · M1 · M
- **W1.2** Reviewer fail-closed, locked-down, not self-approvable — P0 · M1 · M
- **W1.3** Container privilege & secrets (scope per D-02) — P0 · M1 · M
- **W1.4** Permission rules correct; security docs truthful — P0 · M1 · S
- **W1.5** GitHub-side controls + supply-chain pins in the template — P0 · M1 · M

### W2 — Correctness fixes · [workstreams/W2-correctness.md](workstreams/W2-correctness.md)

- **W2.1** Pipeline/skill bugs (parsers, preflight, links, friction-log root) — P1 · M1 · M
- **W2.2** Infra script bugs (session-start, release, port offset, propagation) — P1 · M1 · S
- **W2.3** Hook correctness (partial staging, index vs worktree) — P1 · M1 · S
- **W2.4** Template passes its own CI on a fresh project — P1 · M1 · M

### W3 — Verification foundation · [workstreams/W3-verification.md](workstreams/W3-verification.md)

- **W3.1** Devshop CI (bats + shellcheck + link lint) — P0 · M0 · S
- **W3.2** Tests run anywhere (self-locating scripts, no hardcoded `/devshop`, deps) — P0 · M0 · M
- **W3.3** Fixture project + end-to-end harness (V3/V4 scenarios, attack suite) — P0 · M1→M2 · L
- **W3.4** Test-suite triage (behaviour over prose-grep) — P2 · M5 · M

### W4 — Cloud-native & pinned distribution · [workstreams/W4-cloud-distribution.md](workstreams/W4-cloud-distribution.md)

- **W4.1** Cloud environment for the devshop repo — P0 · M0 · S
- **W4.2** Pinned in-project install + upgrade (`devshop install/upgrade`) — P1 · M2 · L
- **W4.3** Project cloud environment + outside-the-VM boundary — P1 · M2 · M
- **W4.4** Local parity (shared install script, managed settings, firewall) — P1 · M2 · M
- **W4.5** Move project state out of the devshop — P1 · M2 · S
- **W4.6** Devshop lands via PRs + release flow (D-03) — P1 · M2 · S
- **W4.7** Notifications, routines, PR auto-fix mapping — P2 · M2 · S

### W5 — Stack-agnostic core + recipes · [workstreams/W5-recipes.md](workstreams/W5-recipes.md)

- **W5.1** Capability contract, `stack.yaml`, deterministic gate resolution — P2 · M4 · M
- **W5.2** Extract Supabase / Vercel / Next.js / Playwright recipes (no behaviour change) — P2 · M4 · L
- **W5.3** Neutral core template + starters — P2 · M4 · M
- **W5.4** Stack detection + real `/ak-migrate-project` — P2 · M4 · M
- **W5.5** Second recipe via contract tests (Cloudflare when a project needs it) — P2 · M4 · M

### W6 — Pipeline: verify intent, tiers, deterministic orchestration · [workstreams/W6-pipeline.md](workstreams/W6-pipeline.md)

- **W6.1** Spec-conformance gate (independent, claim-by-claim) — P1 · M3 · M
- **W6.2** Traceability: tasks `Implements:`, tests ↔ acceptance — P1 · M3 · S
- **W6.3** Workflow tiers (product / fix / patch / hotfix) — P1 · M3 · M
- **W6.4** Deterministic orchestration; split `/ak-build` per phase (D-06) — P1 · M3 · L
- **W6.5** Check taxonomy cleanup (LLM→script, dedupe, reviewer only for intent) — P1 · M3 · M
- **W6.6** Greenfield chain + `/ak-new-project` fixes — P2 · M3 · M
- **W6.7** Resolve skill contradictions (`/ak-spec`, `/ak-implement`) — P1 · M3 · S

### W7 — gstack upgrade · [workstreams/W7-gstack.md](workstreams/W7-gstack.md)

- **W7.1** Pinned upgrade to ≥1.91.13 (D-07) — P1 · M3 · M
- **W7.2** router-shim for `/cso` v3 — P1 · M3 · S
- **W7.3** `/ship` interplay (title prefix, body ownership) — P1 · M3 · S
- **W7.4** Remove obsolete workarounds — P2 · M3 · S
- **W7.5** Link missing skills; fix design-html path — P1 · M3 · S
- **W7.6** Decide overlaps (handoff/status/spec/test-audit/docs audit) — P2 · M3 · S

### W8 — Documentation restructure · [workstreams/W8-docs.md](workstreams/W8-docs.md)

- **W8.1** Single entry README + reading ladder — P2 · M5 · S
- **W8.2** OVERVIEW concept-only + WORKFLOWS.md — P2 · M5 · M
- **W8.3** Guide split, routing index separated, canonical homes — P2 · M5 · M
- **W8.4** Generated counts (gates, hook steps) — P2 · M5 · S
- **W8.5** Link lint + fix broken links — P1 · M1 · S
- **W8.6** CLAUDE.md ≤2k words; skills procedure-only — P2 · M5 · M
- **W8.7** Template/project docs public-safe — P2 · M4 · S

### W9 — Simplify & delete · [workstreams/W9-simplify.md](workstreams/W9-simplify.md)

- **W9.1** Retire superseded v1 machinery (symlink/sync model, push-to-main merge, `/ak-handoff`) — P2 · M5 · M
- **W9.2** Remove CLAUDE.md-placement machinery — P2 · M5 · S
- **W9.3** Slim process artifacts (n/a gate files, spec dir contents) — P2 · M5 · S
- **W9.4** Evaluate first-party replacements (Bash sandbox, prompt/agent hooks, dcg) — P2 · M5 · S
- **W9.5** Size targets met — P2 · M5 · S

## Dependencies (critical path)

```
W0 ─┬─ W3.1/W3.2 + W4.1 ──▶ (M0) ──▶ W1 + W2 + W3.3 ──▶ (M1) ──▶ W4.2–W4.6 ──▶ (M2)
    │                                                                  │
    └─ D-01..D-06 ─────────────────────────────────────────────────────┘
(M2) ──▶ W6 (+ W7 any time after M1) ──▶ (M3) ──▶ W5 ──▶ (M4) ──▶ W8 + W9 ──▶ (M5)
```

Notable cross-links: W1.3 scope depends on D-02; W4.2 depends on D-01; W6.4 on
D-06; W5 builds on W4.2's install layout; W9.1 needs every project migrated (D-09).

## Changelog

| Date       | Change                             | Why    |
| ---------- | ---------------------------------- | ------ |
| 2026-10-08 | Plan created from analysis session | LOG #1 |
