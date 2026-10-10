# W6 — Pipeline: verify intent, workflow tiers, orchestration _(provisional — re-plan after D-14)_

> **Superseded by D-14 (2026-10-09).** The devshop is rewritten lean in a new repo
> ([W10-v2.md](W10-v2.md)); these v1 tasks are **not executed** (`[-]`). They stay as
> reference: each finding below is dispositioned by the lessons harvest **W10.3.3**
> (v2 requirement, not applicable, or won't fix — v1 retired). Security exposure that is
> live today is handled in W0.5–W0.7.

Deliver the core promise: each change is independently checked against what was
specified, with ceremony proportional to the change. Depends on D-06.
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W6.1 Spec lock + acceptance→test check + advisory conformance reviewer — P1 · M3 · L

Findings: F-PIPE-12. Opportunities: O-06, O-10. Pattern: `design-conformance`.
Redesigned by REVIEW-1: the agent writes spec, code and tests, so an LLM judging
agent-written inputs isn't independent. Order: owner-locked intent → deterministic
check → LLM for the residue, advisory until measured.
Done when: (a) changing a locked spec section after approval fails CI without owner
sign-off; (b) "every acceptance item has a test that names it" is a required CI
check; (c) the LLM reviewer's precision and recall are measured on the W3.4.3 eval set
(≥5 seeded violations + ≥5 honest branches) and recorded — blocking only if both ≥ 0.8.

- [-] **W6.1.1** Spec lock: the owner approves Decisions + Acceptance (+ core story) before implementation; their hash is recorded; CI fails if they change later without an owner-approved bump — V2
- [-] **W6.1.2** Acceptance→test check in CI (uses W6.2 IDs): every acceptance item is named by ≥1 test; report unpinned items — V2
- [-] **W6.1.3** Conformance reviewer for the residue (decisions, non-testable items): claim extraction → per-claim verdict (met / partial / unmet / deviated-with-reason, with file:line evidence); runs **in CI**, posts an advisory PR comment; different vendor/model where available (`/codex`, code-review plugin, claude-code-action) (O-06)
- [-] **W6.1.4** Measure the reviewer on the W3.4.3 eval set; decide blocking vs advisory from the numbers
- [-] **W6.1.5** Acceptance boxes ticked only from W6.1.2/W6.1.3 results; Headline/blurb drift **flagged**, never auto-rewritten to fit the diff (F-PIPE-12)

## W6.2 Traceability — P1 · M3 · S

Findings: F-PIPE-12.

- [-] **W6.2.1** `tasks.md` gains `Implements: D3, A2, S1` per task; implement step refuses tasks without it — V2
- [-] **W6.2.2** Test naming/annotation convention linking tests to acceptance IDs; checker script reports unpinned acceptance items — V2

## W6.3 Workflow tiers — P1 · M3 · M

Findings: F-PIPE-13, F-PIPE-14.
Done when: product, fix and patch tiers each exercised once on the fixture (V4);
hotfix documented and dry-run.

- [-] **W6.3.1** Tier definitions (artifacts + gates per tier) in one table — design note reviewed:
  - product: full chain + spec-conformance
  - fix: investigate → failing regression test first → root-cause note → reduced gates → conformance against the bug report; no gstack prerequisite
  - patch (chore/copy/deps/refactor): spec-lite (decisions + acceptance) → fast CI + review + conformance; refactor adds behaviour-equivalence check
  - hotfix: branch → fix + test → PR; mandatory follow-up record after deploy
- [-] **W6.3.2** Phase 0 selects the tier (proposed by Claude, confirmed by owner); tier recorded in spec header — V4
- [-] **W6.3.3** Dependency-upgrade path (uses DEPS-WATCH + dependabot) as a patch-tier variant — V4

## W6.4 Gate runner as a required CI check; thin skills — P1 · M3 · L (D-06)

Findings: F-PIPE-06, F-PIPE-09, F-PIPE-11, F-PIPE-18. Opportunity: O-03.
Done when: gate selection/tally/halt is a script whose result is a **required CI
check** (the only place determinism is also enforcement); `/ak-build` is a short router
plus per-phase files (≤ 4k words each); F-PIPE-09 contradictions gone.

- [-] **W6.4.1** Single source of truth for gates (one file consumed by scripts; counts generated) — removes the F-PIPE-09 class
- [-] **W6.4.2** `gate-runner`: runs/collects gates, tallies, applies n/a-by-scope deterministically (fixes F-PIPE-06), exits non-zero; wired as a required CI check — V3
- [-] **W6.4.3** Split `build/SKILL.md` into router + phase files; incident narratives → BUILD-LOG/notes — V1 + dogfood run
- [-] **W6.4.4** Workflow pilot dropped unless in-session fan-out is measurably the bottleneck (REVIEW-1 R2 §6; D-06)

## W6.5 Check taxonomy cleanup — P1 · M3 · M

Findings: F-REV-06, F-HOOK-09, F-SEC-17. Opportunity: O-02.

- [-] **W6.5.1** Convert mechanically checkable LLM check-types to scripts (dirty-tree paths, manifest tag, PR body section order, bats-skip names, relocation staged, file headers) — V2
- [-] **W6.5.2** Every bypass leaves a durable record (trailer or log); coverage bypass reasons reviewed at audit time (F-HOOK-09) — V3
- [-] **W6.5.3** Security review runs on security-relevant devshop changes (hooks, settings, scripts, firewall) instead of blanket n/a (F-SEC-17) — V4
- [-] **W6.5.4** Dedupe repeated checks (gitleaks ×4, bats ×5, lint/typecheck ×4): one owner per check in the gate table — V1

## W6.6 Greenfield chain + `/ak-new-project` fixes — P2 · M3 · M

Findings: F-PIPE-13, F-PIPE-15.

- [-] **W6.6.1** Fix `$DEVSHOP` unset, step numbering, "any container" claim (F-PIPE-15)
- [-] **W6.6.2** Documented greenfield chain: new-project → `/office-hours` → `/design-consultation` → `/autoplan` → seed PLAN → loop product-tier builds — V4 on fixture

## W6.7 Resolve skill contradictions — P1 · M3 · S

Findings: F-PIPE-07, F-PIPE-08.

- [-] **W6.7.1** `/ak-spec`: works from Phase 0 skeleton without gstack artifacts; never overwrites decisions; always emits `## Task order`; `/ak-implement`: honours devshop/recipe-specific commands instead of hardcoded pnpm/posthog — V4

## W6.8 Model routing + native advisor — P1 · M3 (pilot from M1) · S

Opportunities: O-11, O-12. Assumptions: A-17 (validated), A-18.
Replaces hand-rolled parts of the stuck protocol (devil's-advocate subagent, "fix ×2 → investigate") and in-session "pre-done" reviews with the first-party advisor, and sets per-role models.
Done when: the devshop's settings/agents define the routing below; the A/B (A-18) is recorded; the stuck protocol and pre-done checks in skills are reduced to one line ("consult the advisor") if the A/B supports it.

- [-] **W6.8.1** Routing defaults: main session Sonnet 5.5 (effort high) for execution, Opus for planning-heavy sessions; `advisorModel: opus`; search/discovery subagents `model: haiku` + read-only `tools`; **reviewer subagents stay Sonnet/Opus** (no `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` — it would downgrade adversarial reviewers). Set in project `.claude/settings.json` + `.claude/agents/*.md` (user `~/.claude` settings don't reach cloud sessions)
- [-] **W6.8.2** CLAUDE.md: 3 lines asking Claude to consult the advisor before locking a plan, after the same failure twice, and before declaring done (guidance — timing stays model-driven; it is **not** an enforcement point; CI remains the gate)
- [-] **W6.8.3** A/B on the walking skeleton + one real epic (A-18): with vs without advisor; rework, tokens, defects caught — record in LOG; keep or drop based on numbers
