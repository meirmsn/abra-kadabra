# Pre-ship review: ak-go-live-arm-a-preflight

<!-- audited-at: HEAD-pre-ship -->

## Phase 3 quality gates

| Gate                               | Result                                                                                                                                                                                                                                                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| preflight (tooling)                | n/a — pure-prose change, no browser / Chromium gates needed                                                                                                                                                                                                                                                   |
| docs-check                         | pass — paired `kit/docs/guide/workflow.md` paragraph staged in same commit; pre-commit docs-coverage hook accepted (test 70+71 pass)                                                                                                                                                                          |
| metrics-check                      | n/a — no event taxonomy changes                                                                                                                                                                                                                                                                               |
| rls-coverage                       | n/a — no SQL                                                                                                                                                                                                                                                                                                  |
| slow-job-lifecycle                 | n/a — devshop CI runs the bats suite only                                                                                                                                                                                                                                                                     |
| changed-tests-local                | n/a — no source-code changes                                                                                                                                                                                                                                                                                  |
| responsive-theme                   | n/a — no UI                                                                                                                                                                                                                                                                                                   |
| /simplify                          | pass — Step 1.8 prose has no duplication; classifier table covers every recognized + default case; one-paragraph workflow.md note is at intended grain                                                                                                                                                        |
| /ak-check-docs-and-tests (Audit 1) | pass — 0 high / 0 medium / 0 low. Docs: SKILL.md + workflow.md + ROADMAP move in lockstep; ROADMAP heading rename propagated to both citations. Tests: convention has no bats coverage for SKILL.md prose-only steps (1.5 / 1.6 / 1.7 don't either) — symmetric with existing convention; not a coverage gap. |
| /review                            | pass — awk classifier handles h2-vs-h3 section nesting via top-down rule evaluation; `exit 0` early-skip on no-PR matches Step 1.5's pattern; gh comment scan filtered to canonical /ak-build headers (`Pre-ship audit trail` / `Ready for review`) so reviewer chatter doesn't pollute the parser            |
| /cso                               | n/a — no security boundary, no new credentials, no secret handling (Arm B's `SUPABASE_ACCESS_TOKEN` is deferred and explicitly NOT introduced here)                                                                                                                                                           |
| /design-review                     | n/a — no UI                                                                                                                                                                                                                                                                                                   |
| /qa                                | n/a — pure-prose; behavioral test would require live PR + live AskUserQuestion round-trip                                                                                                                                                                                                                     |
| /benchmark                         | n/a — Step 1.8 adds ~5s wall-time (one `gh pr view` call); negligible per ROADMAP cost estimate                                                                                                                                                                                                               |
| convention                         | pass — Step 1.8 mirrors Step 1.5/1.6/1.7 idiom: bash blocks the agent runs, `AskUserQuestion` as the blocking gate, "Codified from" footer, ROADMAP cross-ref. Version bump 1.2.0 → 1.3.0 follows semver conventions.md.                                                                                      |

**Counts:** passed=4, n_a=10, blocked=0, findings_pending=0.

## Self-review notes

- **Strict (not fuzzy) section matching is intentional**. The awk classifier matches exact case-sensitive headers from `/ak-build § PR body conventions`. Divergent projects that use different casing or punctuation fall through to the "Other" non-blocking bucket — safe degradation, not silent wrong-block.
- **No `[auto]` items in Arm A output**. The classifier never emits `[auto]` because no automation core exists yet. Phase 6's audit comment for this PR confirms the omission is intentional, not a coverage gap.
- **Multi-line checkboxes**: the awk parser only matches the first line of a `- [ ] ...` item; any continuation (the `\n  Run X then Y` shape) is dropped from the parsed label. Per `/ak-build § PR body conventions`, every checkbox is single-line by convention — no false negative on real-world inputs.
- **Comment-scan filter is canonical-headers-only**: `gh pr view --json comments` returns ALL comments including reviewer chatter. The `select(.body | test("^## (Pre-ship audit trail|Ready for review)"; "m"))` jq filter scopes to the two `/ak-build`-emitted comments.

## Findings during pre-ship

None. The diff is a clean prose addition + cross-ref propagation; no churn introduced.

## Audit 1: manual (2026-05-10)

<!-- audited-at: 80f002323555210753bceb5ff95a8997092e9cb3 -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

Coverage (Section A) PASS: SKILL.md surface-trigger requires `kit/docs/guide/workflow.md` OR `CLAUDE.md` — workflow.md staged in lockstep (commit `8bddac9`). Adequacy (Section B) PASS: workflow.md new paragraph is substantive; all cross-refs verified (`kit/ROADMAP.md § ... (Arm B — automation core)` at L1372; `## Pre-ship audit trail` / `## Ready for review` in /ak-build SKILL.md at L1237/L1501; `## Out-of-band deploy items` matches lalista PR #58 empirical evidence). Coherence (Section C) PASS: no renames/deletes; no contradictions. Bypass trailers (Section D): none in range.

### Tests findings

- (none)

Coverage (Section A) PASS-by-precedent: modified SKILL.md trigger maps to "new SKILL.md → smoke bats OR proven-by existing bats"; this is a modification adding Step 1.8 to a skill whose existing Steps 1.5/1.6/1.7 are agent-executable prose without bats. Step 1.8 mirrors that exact shape. Quality (Section B) N/A: no test files modified — the 5 commits land prose only. Bypass trailers (Section C): none in range.

### Bypass trailer audit

- (none)
