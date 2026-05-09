<!-- generated-by: /ak-pre-ship -->
<!-- feature: slow-job-skip-on-docs-only -->
<!-- date: 2026-05-08 -->

# Pre-ship review: slow-job-skip-on-docs-only

PR scope: devshop kit changes only (bash + YAML + markdown). No runtime app code,
no UI, no migrations, no edge functions, no design system, no DB schema. Many UI
gates legitimately resolve `n/a`.

Range: `1f7c737..HEAD` (Phase 0 spec skeleton through Task 5).

## Gate matrix

| Gate                                 | Result | Notes                                                                                                                                                                                                 |
| ------------------------------------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Preflight (tooling)                  | pass   | bats 1.13.0 vendored at `kit/tests/lib/bats-core/`; actionlint 1.7.7 at `/tmp/actionlint`. shellcheck n/a (none present) — no blast-radius for this PR's surface (manual review covers bash quality). |
| Docs check (Docs-Coverage-Bypass)    | pass   | 2 bypass trailers (Task 1: 221aaa1, Task 3: 11eb814). Final tree IS docs-covered by Task 4 (d44c85e). Bypasses resolve cleanly at audit time.                                                         |
| Metrics check                        | n/a    | Spec § In scope explicitly excludes a new METRICS event.                                                                                                                                              |
| Responsive                           | n/a    | No UI surface.                                                                                                                                                                                        |
| `/simplify`                          | pass   | classify shell logic is already minimal — see "Simplify review" below.                                                                                                                                |
| `/ak-check-docs-and-tests` (Audit 1) | pass   | Appended below as `## Audit 1`. Docs landed (Task 4); tests landed (Tasks 2+3). Bypass trailers cleared.                                                                                              |
| `/review` (gstack code review)       | pass   | bash quality, YAML validity, BATS test quality — see "Code review" below.                                                                                                                             |
| `/cso` (security)                    | pass   | classify step is read-only, no secrets, no API calls, no writes outside `$GITHUB_OUTPUT`. Injection surface analysed.                                                                                 |
| `/design-review`                     | n/a    | No UI surface.                                                                                                                                                                                        |
| `/qa`                                | n/a    | No app to QA — CI infra only.                                                                                                                                                                         |
| `/benchmark`                         | n/a    | No perf surface.                                                                                                                                                                                      |
| Convention check                     | pass   | Follows `kit/docs/guide/conventions.md` and `/devshop/CLAUDE.md`. Atomic commits per task; bypass trailers used + resolved.                                                                           |
| Slow-job-lifecycle (dogfood)         | n/a    | `/devshop/.github/workflows/ci.yml` doesn't have a slow job — gate is `n/a` for devshop-on-devshop run.                                                                                               |
| BATS suite-wide                      | pass   | 715 tests pass.                                                                                                                                                                                       |
| Hero shots                           | n/a    | No visual surface.                                                                                                                                                                                    |

## Counts

- `passed`: 8
- `findings_pending`: 0
- `n_a`: 6
- `blocked`: 0

---

## Detail

### Preflight

- bats 1.13.0 → vendored at `kit/tests/lib/bats-core/bin/bats`. Used directly.
- actionlint 1.7.7 → `/tmp/actionlint`. Used to validate `template/.github/workflows/ci.yml` shape.
- shellcheck → not installed in this environment. Not blocking: the only new bash is in two places (the inline classify step inside YAML — covered by actionlint's pyflakes-equivalent built-in shellcheck, and the `slow-job-lifecycle-check.sh` Check 6 — pure regex grep with no string interpolation into shell). Manual code review below covers what shellcheck would catch.

### Docs check

Two intermediate commits carry `Docs-Coverage-Bypass:` trailers:

- `221aaa1` (Task 1) — template stub commit; conventions doc didn't exist yet.
- `11eb814` (Task 3) — gate code commit; conventions doc still in flight.

Final tree (after Task 4 `d44c85e`) lands the canonical `### Skip-on-docs-only filter`
sub-section under `## Slow-Job Lifecycle` in `kit/docs/guide/conventions.md`. The sub-section
captures shape, ignore list, alternatives-dismissed (D1), branch-protection contract, and
uncomment-both ritual. Both bypass trailers are intermediate-commit bookkeeping; the audit-time
view of the PR-as-a-whole is fully docs-covered.

### `/simplify` review

The classify shell script in `template/.github/workflows/ci.yml` uses the
canonical shape: `set -euo pipefail` + `shopt -s globstar`, three-dot diff
(`base.sha...HEAD`), empty-diff → `runtime=true` early-return, per-path `case`
against the D2 ignore list, single `echo "runtime=…" >> "$GITHUB_OUTPUT"`.

Rejected simplifications:

- **Combine empty-diff with the loop** — the loop body would never execute on empty
  input, leaving `runtime=false` (the unsafe default). Spec D6 explicitly chose
  `runtime=true` on empty diff as the safer fallback. The early-return is load-bearing.
- **Replace `case` with `grep -vE`** — would lose the bash-glob semantics (`**` for nested dirs)
  that `shopt -s globstar` enables, forcing a regex translation that's harder to audit.
- **Move ignore list to a YAML array** — would couple list-of-globs to YAML parser quirks
  in `paths-ignore`-adjacent ways that the spec D1 actively rejects.

The 15-line classify step is at the structural minimum for the chosen shape.

The Check 6 addition to `slow-job-lifecycle-check.sh` reuses the existing YAML-line-extract
helpers (`yaml_lines_for_job`, `slow_job_block`); does not duplicate parsing logic. No further
simplification opportunity.

### `/review` (code review)

**Bash:**

- `slow-job-lifecycle-check.sh` Check 6: pure read-only `grep` against captured-text variables.
  No `eval`, no command substitution into shell, no path concatenation. Inputs are filenames
  the gate passes through (already validated by Check 1's "workflow file exists" gate).
- Inline classify step in `template/.github/workflows/ci.yml`: uses `set -euo pipefail`, quotes
  all variables, three-dot diff (`base...HEAD`) per spec Gotcha. `${{ github.event.pull_request.base.sha }}`
  is interpolated by GitHub Actions BEFORE the shell starts; the value is a 40-char SHA validated
  by GitHub's webhook layer. No injection surface (this is the "should be inspected for command
  injection" item from the gate runner brief — verified clean).

**YAML (actionlint 1.7.7):** template/.github/workflows/ci.yml passes actionlint against the live
fast-job. The commented-out `changes:` + `slow:` stubs are not parseable as live YAML (they're
`#`-prefixed lines), so actionlint correctly skips them — the BATS test suite (`template-ci-yml-shape.bats`)
pins their literal text shape instead.

**BATS:** 23 + 22 + existing = 715 total. Each test asserts a single literal-text or single
behavioural property; failures point at the exact missing globs / lines / phrases.

### `/cso` (security)

The PR's surface area for security analysis:

1. **Classify step (template ci.yml)** — runs in PR context; no secrets read; no API calls; no
   writes outside `$GITHUB_OUTPUT` (which is GitHub-managed and step-scoped). Inputs:
   - `${{ github.event.pull_request.base.sha }}` — a webhook-validated 40-char SHA. Even if a malicious
     PR could spoof this, the worst-case is a `git diff` that returns garbage paths, which the loop
     classifies as "non-docs" → `runtime=true` (slow-job runs). No privilege escalation.
   - `git diff --name-only` output — filenames in the repo. Not interpolated into shell; passed via
     `mapfile` to a `case` pattern. No injection.

2. **Slow-job-lifecycle gate** — runs in `/ak-pre-ship` context, locally. Reads project's
   `ci.yml` via `cat` into a bash variable; greps. Read-only. No new attack surface.

3. **No new dependencies, no new env vars, no new GitHub secrets, no new actions.** Spec § Dependencies confirmed.

Verdict: clean. `passed`.

### Convention check

- Atomic commits per task: 5 tasks → 5 task commits + 1 spec commit. Verified via `git log`.
- Commit message format: matches `feat(scope): subject` / `test(scope): subject` / `docs(scope): subject` / `chore(...)` per `CLAUDE.md`'s Conventional Commits row.
- `Docs-Coverage-Bypass:` trailers used on intermediate commits where the doc didn't yet exist; resolved by Task 4 in the same PR.
- Co-authorship trailer present per `CLAUDE.md`.
- No skipped hooks (`--no-verify` not used).

### Slow-job-lifecycle dogfood

`/devshop/.github/` does NOT exist — devshop ships no top-level GitHub workflows of its own
(only `template/.github/` for projects to adopt). The skip-on-docs-only filter is a
template-level convention for adopting projects (lalista is the first); the devshop's own CI
doesn't surface it. This gate is `n/a` for the devshop-on-devshop run. Live verification
will come at lalista's adoption PR (D4) per spec § Acceptance criteria 8.

### BATS suite-wide

(Confirmed below in the run output.)

---

## Audit 1

Range: `1f7c737..HEAD` (Phase 0 spec skeleton through Task 5 PLAN flip).
Audit invokes `/ak-docs-review` and `/ak-tests-review` against the merged tree.

### [domain: docs]

**Finding 1 — Bypass trailers resolved cleanly at audit time.** severity: low (noted)

- **Trailers in range:**
  - `221aaa1` (Task 1, template stub) — Bypass body cites Task 4 as the future doc; distinctive phrase `'changes-job + slow-job gating'`.
  - `11eb814` (Task 3, gate code + tests) — Bypass body cites Task 4 as the future doc; distinctive phrase `'Skip-on-docs-only filter'`.
- **Final-tree verification:**
  - `kit/docs/guide/conventions.md:152` — line "The skip-on-docs-only filter is wired (changes-job + slow-job's `needs:`/`if:` reference the runtime gate)" — matches Task 1's `'changes-job + slow-job gating'` phrase.
  - `kit/docs/guide/conventions.md:156` — heading `### Skip-on-docs-only filter` — matches Task 3's distinctive phrase.
  - Task 4's commit (`d44c85e`) lands a 65-line sub-section covering shape (with full canonical YAML snippet), D2 ignore list verbatim, D1 alternatives-dismissed (with actionlint v1.7.7 rejection output verbatim), branch-protection `skipped`-as-success contract with fallback `if:` shape, uncomment-both ritual with dangling-needs trap in both directions, and forward verification (live PR is the run-time test).
- **Per-doc audit (13 catalog guides):**
  - AFFECTED + UPDATED: `kit/docs/guide/conventions.md` (Task 4).
  - NOT-AFFECTED (with reason): `architecture.md` (no architectural shape change — pure CI workflow filter), `security.md` (no auth/secret/RLS surface change — classify step is read-only, no secrets), `ops.md` (CI runtime behavior unchanged for non-uncommented slow-jobs; this is purely additive when projects uncomment), `hooks.md` (no commit-hook change), `workflow.md` (no PR/branch workflow change — adopting projects opt in via uncomment), `testing.md` (BATS coverage extension paired with test code in same commits per spec § Task order Task 3's "one commit" rule), `README.md` (index doc — refreshed at audit time when whole feature lands), `latency-feedback.md` (UI feedback tiers — irrelevant), `local-supabase-compose-isolation.md` (devcontainer compose — irrelevant), `macos-host-setup.md` (operator host — irrelevant), `notifications.md` (ntfy/notify — irrelevant), `supabase-ssr-boilerplate.md` (Supabase SSR — irrelevant).
- **Adversarial review of bypass justifications:** both bypass trailers correctly call out the spec's atomic-commit-per-task convention as the structural cost. The doc landed in the same PR (Task 4, `d44c85e`), within the agreed 5-task window. Distinctive phrases land verbatim. No bypass was used to defer doc work to a later PR.
- **Action:** noted; no fix required. Both bypass trailers are valid and resolved.

### [domain: tests]

**Finding 1 — Test coverage matches spec § Tests acceptance criteria.** severity: low (noted)

- **Tests landed in range:**
  - `kit/tests/template-ci-yml-shape.bats` (NEW, 23 cases, Task 2, `c73cc6c`) — pins literal commented template shape: `changes:` job presence, ignore-list globs (presence + canonical order), `actions/checkout@v4` + `fetch-depth: 0`, classify-step `runtime=…` emission, three-dot diff form, `shopt -s globstar`, empty-diff `runtime=true` default, slow-job `needs: [fast, changes]`, slow-job `if:` runtime gate, comment-block cross-reference + dangling-needs warning. 23/23 pass.
  - `kit/tests/preship-slow-job-lifecycle.bats` (extended, Task 3, `11eb814`) — 4 new D3 cases (filter present canonical, filter absent, partial-wire needs:, partial-wire if:); existing 3 pass-fixtures updated to include canonical filter so they don't regress under Check 6. 22/22 pass.
- **Suite-wide:** 715/715 BATS pass (verified above).
- **Coverage shape:** Task 2 covers the template-shipped surface (literal-text assertions). Task 3 covers the gate-extension behavior (Check 6 triggers + remediation phrase). The two layers are complementary — template-shape tests pin what ships in the box; gate tests pin what fires at adopt-time.
- **Adversarial review:**
  - **Shape-only escape hatch?** No — Task 2 is intentionally shape-only (the test target is "the template shipped in the canonical commented form"), which is the correct test for a static template artifact. Task 3 is behavioral (gate emits expected finding strings on fixture inputs).
  - **Untested boundary conditions?** D6's empty-diff default (`runtime=true`) is asserted by `template-ci-yml-shape.bats:9`. The dangling-needs trap is asserted by case 23 (warning text in comment block). Branch-protection `skipped`-as-success behavior is GitHub-side and not unit-testable; documented in conventions.md as the load-bearing assumption.
  - **Wrapper API / runtime validation?** N/A — no API wrapper or LLM/edge-function boundary in this PR.
  - **Skipped tests?** None.
- **Action:** noted; no fix required. Test coverage matches spec § Tests bullet list.

### Summary

- **Docs:** pass. 2 bypass trailers in range, both resolved by Task 4's conventions.md sub-section in same PR. Per-doc audit: 1 doc affected and updated, 12 docs verified not-affected with rationale.
- **Tests:** pass. 23 + 4 new D3 cases + 3 fixture updates = 30 changes in 2 BATS files. 715/715 suite-wide.
- **Severity:** all findings low (noted) — no medium or high blockers.

---

## Audit 2

<!-- audited-at: 3fb17e437829b360e51faa5c604a178b9248cfbc -->

Range: `61957cf..3fb17e4` (post-pre-ship polish range — exactly 1 bookkeeping commit).
Audit invokes `/ak-docs-review` and `/ak-tests-review` against the merged tree.

Polish range contents:

- `3fb17e4` `chore(build-log): record slow-job-skip-on-docs-only` — pure bookkeeping. Three files: `PLAN.md` (-4/+1, Active row removed, placeholder restored), `BUILD-LOG.md` (+9/-0, slow-job-skip-on-docs-only entry prepended most-recent-first), `kit/ROADMAP.md` (+1/-58, deleted the standalone entry; revised the "CI slow-job lifecycle convention" gate-asserts list from 5 to 6 with cross-link). No code, no tests, no runtime.

### [domain: docs]

**Finding 1 — BUILD-LOG entry follows adjacent-entry convention.** severity: low (noted)

- Compared the new `### slow-job-skip-on-docs-only (2026-05-08)` entry against its two immediate neighbors (`postgrest-null-and-tier-a2-retry-docs (2026-05-08)`, `cheap-test-gates-local (2026-05-06)`):
  - All three use the `### <feature> (YYYY-MM-DD)` heading shape.
  - All three carry the same bullet schema: **Branch** / **PR** / **Spec** / **Summary** / **Commits** / **Quality gates**.
  - Most-recent-first ordering preserved (new entry inserted at top under the file preamble, before `postgrest-null-and-tier-a2-retry-docs`).
  - Summary length proportional to scope (single paragraph; cites the empirical `paths-ignore`-at-job-level rejection that justified the chosen shape).
  - Quality gates row uses the same numeric-rollup convention as adjacent entries (`8 pass + 0 findings_pending + 6 n/a + 0 blocked. Audit 1 clean.`).
- **Action:** noted; no fix required.

**Finding 2 — Deleted ROADMAP entry has no surviving cross-references outside the spec/tasks files.** severity: low (noted)

- Repo-wide sweep for the deleted entry's distinctive title `Slow-job skip-on-docs-only via CI workflow paths-ignore`:
  - `specs/slow-job-skip-on-docs-only/tasks.md:103` — references the entry as the planned-deletion target. **Expected** — the spec itself documents the cleanup.
  - `specs/slow-job-skip-on-docs-only/spec.md:10,157` — same. **Expected** — the spec records ROADMAP cross-references as audit trail.
  - No hits in `CLAUDE.md`, `README.md`, `kit/docs/guide/*.md`, or any other top-level doc.
- Repo-wide sweep for `paths-ignore` (the deleted entry's distinctive technical term):
  - `BUILD-LOG.md:12` — the new entry's prose, citing the shape rejection. **Expected.**
  - `specs/cheap-test-gates-local/spec.md:282` — historical "Out of scope" item from a previously-shipped feature; was the original promotion source for what became the now-shipped slow-job-skip-on-docs-only entry. **Expected** — historical audit trail.
  - `kit/docs/guide/conventions.md:213` — the "alternatives-dismissed" paragraph in the new sub-section, citing the actionlint rejection. **Expected.**
  - `kit/ROADMAP.md` — only the new Check 6 cross-link. **Expected.**
- **Action:** noted; no fix required.

**Finding 3 — ROADMAP "CI slow-job lifecycle convention" gate-asserts list reads coherently with Check 6 inline; cross-link target resolves.** severity: low (noted)

- Inspected the revised list at `kit/ROADMAP.md:909–917`:
  - Numbering is contiguous (1–6); structural parallel preserved (each sub-bullet states a declarative property the gate asserts).
  - Check 6's parenthetical "(Shipped via #29; see `kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter`.)" is the only past-tense entry in a forward-looking list. That asymmetry is intentional and matches the existing convention used elsewhere in the ROADMAP for "this part of a v0 entry has already shipped" — clarifies that the gate already knows how to assert this without needing the rest of the v0 entry to ship.
  - Block-on-failure remediation message at the end of the list ("uncomment + add to branch protection") is unchanged. Adding Check 6 doesn't break the remediation framing.
- Cross-link target verification: `grep -n "Skip-on-docs-only filter" /devshop/kit/docs/guide/conventions.md` → line 156, heading `### Skip-on-docs-only filter`. Anchor exists.
- Outer section header verification: `## Slow-Job Lifecycle` exists in the same file (the parent heading). Cross-link's `§ Slow-Job Lifecycle § Skip-on-docs-only filter` chain is fully resolvable.
- **Action:** noted; no fix required.

**Finding 4 — PLAN.md placeholder restored to the canonical empty-state.** severity: low (noted)

- The Active row removal restores `_No work in progress._` — the same placeholder used by adjacent merged-feature post-states across the devshop's lifecycle. Visual diff is two-line table → one-line italic placeholder. No structural drift.
- No "next-up" feature is queued in the Active row, which matches PLAN's convention (Active is for in-flight work; Planned is the next-up queue, untouched by this commit).
- **Action:** noted; no fix required.

**Per-doc audit (13 catalog guides + top-level):**

- AFFECTED + UPDATED in polish range: `BUILD-LOG.md` (entry prepended), `PLAN.md` (Active row removed, placeholder restored), `kit/ROADMAP.md` (entry deleted, gate-asserts list grown 5→6).
- NOT-AFFECTED (with reason): `CLAUDE.md` (no orientation/instruction change — pure devshop-internal bookkeeping), `README.md` (no surface change), `kit/docs/guide/conventions.md` (already updated in Audit 1 range; the polish commit's ROADMAP cross-link points _at_ this file but doesn't modify it), `architecture.md` / `security.md` / `ops.md` / `hooks.md` / `workflow.md` / `testing.md` / `latency-feedback.md` / `local-supabase-compose-isolation.md` / `macos-host-setup.md` / `notifications.md` / `supabase-ssr-boilerplate.md` (none of these surfaces are bookkeeping-relevant).

### [domain: tests]

**Finding 1 — Polish range contains zero test changes.** severity: low (noted)

- Polish range diff scope: `BUILD-LOG.md`, `PLAN.md`, `kit/ROADMAP.md`. All three are markdown bookkeeping files.
- No new test files. No edits to existing test files. No edits to fixtures, helpers, or test infrastructure.
- BATS suite total unchanged from Audit 1's 715/715. No re-run required for a markdown-only polish range.
- **Action:** noted; no fix required. Trivial pass — there is no test surface to audit.

### Summary

- **Docs:** pass. 4 low-severity findings, all noted. BUILD-LOG entry follows adjacent-entry convention; deleted ROADMAP entry has no surviving cross-refs outside the spec; revised gate-asserts list is coherent with the new Check 6; PLAN.md placeholder restored canonically. Cross-link from `kit/ROADMAP.md` Check 6 → `kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter` resolves at line 156.
- **Tests:** pass. Trivial — polish range is markdown-only.
- **Severity:** all findings low (noted) — no medium or high blockers.

findings: high=0 medium=0 low=5

---

## Audit 3: manual (2026-05-08)

<!-- audited-at: c4e58d5b8337333b2ad1c33eed555509122178d6 -->
<!-- range: 3fb17e4..c4e58d5 -->

findings: high=0 medium=0 low=0

Pre-merge audit invoked by `/ak-merge-devshop` Phase 1. Range is exactly the
`docs(slow-job-skip-on-docs-only): post-pre-ship review.md (Audit 2)` commit
itself — by construction, an audit-stamp commit cannot stamp its own SHA, so
this recursive "audit the audit" trivial pass is the expected structural
state. Diff scope: `specs/slow-job-skip-on-docs-only/review.md` only
(+76/-0). No code, no tests, no runtime, no reference docs, no bypass
trailers.

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)
