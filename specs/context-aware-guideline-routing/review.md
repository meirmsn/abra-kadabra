<!-- audited-at: f9c093a1f8fdaae48ce78cce5b1ecbe4d8e94a8b -->

## Router Summary

| Gate                        | Owner | Dismissals                                  | Adversarial review            |
| --------------------------- | ----- | ------------------------------------------- | ----------------------------- |
| Phase 0 preflight           | ak    | None                                        | skipped (scoped parse = None) |
| `docs-check` (1)            | ak    | None                                        | skipped (scoped parse = None) |
| `metrics-check` (2)         | ak    | None — n/a (no user-facing code change)     | skipped (scoped parse = None) |
| `rls-coverage` (2b)         | ak    | None — n/a (no migrations / no client API)  | skipped (scoped parse = None) |
| `slow-job-lifecycle` (2c)   | ak    | None — n/a (no project workflow file)       | skipped (scoped parse = None) |
| `changed-tests-local` (2d)  | ak    | None — n/a (no stack-needing paths in diff) | skipped (scoped parse = None) |
| `responsive-theme` (3)      | ak    | None — n/a (no UI)                          | skipped (scoped parse = None) |
| `/simplify` (4)             | —     | None                                        | skipped (scoped parse = None) |
| `docs-and-tests-review` (5) | ak    | See Audit 1 section below                   | per gate                      |
| `/review` (6)               | —     | None                                        | skipped (scoped parse = None) |
| `/cso` (7)                  | —     | None — n/a (no security-boundary change)    | skipped (scoped parse = None) |
| `/design-review` (8)        | —     | None — n/a (no UI)                          | skipped (scoped parse = None) |
| `design-conformance` (8b)   | ak    | None — n/a (no DESIGN.md in /devshop)       | skipped (scoped parse = None) |
| `/qa` (9)                   | —     | None — n/a (no user-flow surface)           | skipped (scoped parse = None) |
| `/benchmark` (10)           | —     | None — n/a (no runtime perf surface)        | skipped (scoped parse = None) |
| `convention` (11)           | ak    | None                                        | skipped (scoped parse = None) |

**Total dismissed findings**: 0 (0 LLM-reviewed, 0 shim-mapped, 0 rejected).

---

## Phase 0 Preflight

**Outcome**: `pass`

- Scope detection: `grep -E '^(apps/|packages/ui/|components/)' /tmp/preship-changed.txt` returned no match → `TOUCHES_UI` is empty. Gates 3, 8, 9, 10 (and `design-review`, `qa`, `benchmark`) are advisory-only / `n/a` for this PR.
- Diff-needs-stack classifier (`kit/scripts/preship/path-classifier.sh diff-needs-stack`) returned exit 1 → no path in the diff needs the local Supabase stack. Supabase bootstrap is skipped.
- `gh auth status`: authenticated as `meirmsn`.
- `git branch --show-current`: `feature/context-aware-guideline-routing` (not main).
- BATS suite (`./kit/tests/lib/bats-core/bin/bats kit/tests/`) — full 745 tests pass.

**Deploy boundaries reminder**: diff includes no `supabase/migrations/**`, no `supabase/functions/**`. No race-window reminder fires.

## Dismissals

None.

---

## Gate 1 — `docs-check` (ak): Devshop docs diff review

**Outcome**: `pass`

The whole PR IS docs. Verification:

- All 13 markdown files under `kit/docs/guide/*.md` parse cleanly (BATS Test 1 — link-resolution — passes 5/5).
- Promoted `kit/docs/guide/README.md` is internally consistent: 22 routing rows across 5 grouped sections (Data, Auth+security, Frontend+UI, Ops+deploy, Dev+meta); 3 Out-of-routing entries (`architecture.md`, `macos-host-setup.md`, `workflow.md`); alphabetical orientation list mirrors disk (BATS Test 2: 5/5).
- Real-world grounding: ≥3 routing-row triggers fire on lalista specs at `/workspace/specs/*/spec.md` (BATS Test 3: 3/3).
- Cross-ref hygiene: `template/CLAUDE.md`, `template/packages/core/src/schemas/README.md`, `kit/tests/preship-rls-coverage.bats` cite the post-split anchors (verified by Task 12's commit). The pointer-redirect convention (Decision Impl-1) means existing external links to `conventions.md § <moved-section>` still resolve gracefully via the one-line pointer left behind in conventions.md.
- `workflow.md` orientation paragraph at line 424 — substantive (3 paragraphs explaining the routing index + fallback path + skill cross-citations), points at SKILL.md as canonical source.
- `kit/ROADMAP.md`: shipped entry `§ Context-aware guideline routing for /ak-spec and /ak-implement` is **deleted** (not just struck) per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`. New `§ PR-B: lalista CLAUDE.md gotcha audit + lift into routing system` entry filed at line 1708 with cross-ref back at this feature branch.

## Dismissals

None.

---

## Gate 2 — `metrics-check` (ak): Metrics coverage

**Outcome**: `n/a (no user-facing code change)`

Per spec § Metrics: "no new `METRICS.md` events. The routing system is a build-time / read-time mechanism inside the devshop tooling; no user-facing event surface." The PR touches zero files under `apps/web/**`, `packages/core/**`, `packages/ui/**`, or `supabase/functions/**`. Telemetry on routing-hit / routing-miss rates was deferred to a future pass (spec Out-of-scope).

## Dismissals

None.

---

## Gate 2b — `rls-coverage` (ak): RLS policy coverage

**Outcome**: `n/a (no supabase/migrations directory)`

`bash kit/scripts/preship/rls-coverage-check.sh` reports `n/a (no supabase/migrations directory)` — devshop itself doesn't ship migrations. Project-side `template/` does ship a placeholder, but no new tables nor client-write paths are added in this PR.

## Dismissals

None.

---

## Gate 2c — `slow-job-lifecycle` (ak): Slow-job CI enabled past Phase 1c/1g

**Outcome**: `n/a (no .github/workflows/ci.yml)`

`bash kit/scripts/preship/slow-job-lifecycle-check.sh` reports `n/a` — devshop itself is the kit, not a project. The slow-job lifecycle gate fires on project-side `.github/workflows/ci.yml`. No project-side workflow is touched.

## Dismissals

None.

---

## Gate 2d — `changed-tests-local` (ak): Cheap local test gates

**Outcome**: `n/a (no stack-needing paths in diff)`

`bash kit/scripts/preship/path-classifier.sh diff-needs-stack` returned exit 1. The diff is pure-docs + skills + BATS — no `apps/**`, no `packages/{core,ui}/**`, no `*.integration.test.ts`, no `apps/*/e2e/*.spec.ts`, no `supabase/{migrations,functions}/**`. BATS coverage (the 3 new test files + the rest of the kit suite) is exercised separately and passes 745/745.

## Dismissals

None.

---

## Gate 3 — `responsive-theme` (ak): Responsive + theme capture

**Outcome**: `n/a (no UI changes)`

`TOUCHES_UI` is empty per preflight. No `apps/web/**`, `packages/ui/src/**`, or `components/**` files in the diff. No primary-screen capture required.

## Dismissals

None.

---

## Gate 4 — `/simplify`: Code reuse + quality + efficiency

**Outcome**: `pass`

Markdown-and-skill review for over-engineering:

- **Routing rows**: 22 rows; each fires on at least one realistic file-glob or keyword token. BATS Test 3 ("at least 3 trigger signals fire on at least one lalista spec") provides empirical grounding — every row is reachable. No dead rows.
- **See-also footers**: per Decision Impl-4, only 6 new footers landed (down from the audit's 12 candidates). The other 6 were either already encoded by Task 3 splits (`database-queries.md` and `wrapper-boundaries.md` are themselves the See-also targets that would otherwise have been pointed at from inside conventions.md) or already present inline. No redundant chains.
- **Splits**: 3 new guide files (`migrations.md`, `database-queries.md`, `wrapper-boundaries.md`) — each is a meaningful standalone (47-172 lines). Each split section leaves a one-line pointer in `conventions.md` (Decision Impl-1) so external links resolve. Pointer-redirect is preferred to bulk-rewrite per the established `kit/docs/guide/conventions.md § Cross-skill awareness` pattern.
- **Skill patches**: `/ak-spec` Step 1.5 adds a ~50-line bash block that's bounded — does NOT recurse, does NOT mutate the spec being written automatically (the implementer encodes matches as Decisions manually). `/ak-implement` Step 1 replaces a 1-paragraph hardcoded directive with a 3-paragraph routing-lookup directive plus fallback — proportional to the convention being introduced.
- **BATS test surface**: 3 new files, 13 tests total. Each test asserts ONE invariant from D7. No over-coverage; no redundant assertions.

No simplifications needed.

## Dismissals

None.

---

## Gate 5 — `/ak-check-docs-and-tests` (ak): Docs + tests audit

**Outcome**: `pass`

See `## Audit 1` section below for the structured audit output. The orchestrator invoked `/ak-docs-review` and `/ak-tests-review` against the commit range `origin/main..HEAD` (16 commits) and appended a new `## Audit 1` section. Outcome: zero high-severity findings.

## Dismissals

None.

---

## Gate 6 — `/review`: Pre-landing PR review

**Outcome**: `pass`

Skill-equivalent review of the diff (markdown + SKILL.md + BATS):

- **SQL safety**: n/a — no SQL touched.
- **LLM trust boundaries**: n/a — no edge-fn / LLM-call paths added.
- **Conditional side effects**: n/a — markdown is declarative; SKILL.md prose is read by the LLM-orchestrator, not executed.
- **Structural issues — markdown**: routing tables conform to the convention (Trigger | Target | Notes columns; grouped under H2 domain headers). H2 / H3 anchors match the GitHub slugify algorithm (BATS Test 1 validates).
- **BATS shell safety**: the 3 new BATS files use `awk -F'|'` + `grep -oE`-bounded regex, do not invoke external network, do not mutate the working tree. Cross-boundary read (`/workspace/specs/`) is fenced behind an explicit `skip` with reason — no silent pass.
- **Skill-patch fallback path**: `/ak-implement` Step 1 line 30-34: "if routing-lookup yields zero matches (e.g., a project hasn't yet adopted the routing convention or its README.md is missing the index), fall back to reading `kit/docs/guide/conventions.md` as before." Unambiguous — no "if maybe..." hedging. Pre-adoption projects are explicitly named as the trigger case.

## Dismissals

None.

---

## Gate 7 — `/cso`: Security review

**Outcome**: `n/a (no security-boundary change)`

Per the task brief: "The split moved `§ DESIGN.md as Contract` and `§ Runtime Validation` references but didn't change the substance." Verification:

- `wrapper-boundaries.md` (170 lines) is verbatim extraction of conventions.md § Runtime Validation + § Wrapper API design — no semantic edits, no new threat model.
- `security.md` gained a 1-paragraph cross-reference at the new `§ Runtime Validation at Trust Boundaries` section (line 114) that points at `wrapper-boundaries.md` for substance. Cross-ref only; no new security rule.
- No `.claude/settings.json`, no `.dcg.toml`, no `.devcontainer/**`, no `.husky/**`, no `kit/scripts/**` (root-locked file) edits. Hook chain is unchanged.
- No new secrets touched, no new auth surface, no new CI credential wiring.

## Dismissals

None.

---

## Gate 8 — `/design-review`: Visual audit

**Outcome**: `n/a (no UI changes)`

No `apps/web/**`, no `packages/ui/src/**`, no `components/**`. No visual surface to audit.

## Dismissals

None.

---

## Gate 8b — `design-conformance` (ak): DESIGN.md contract check

**Outcome**: `n/a (no DESIGN.md at /devshop project root)`

`/devshop` is the kit, not a project. No `DESIGN.md` at the root. The DESIGN.md contract check fires on project-side DESIGN.md docs — the devshop has its own conventions doc system (now routed via `kit/docs/guide/README.md`).

## Dismissals

None.

---

## Gate 9 — `/qa`: Functional walk

**Outcome**: `n/a (no user-flow surface)`

Per spec § Core user story: this PR is docs + skills + BATS. The "user" is the orchestrator agent reading the routing index, not a human in a browser. The agent-facing verification is the BATS suite (which all passes) plus the empirical grounding test (Test 3 — confirms routing triggers fire on real specs). No `/qa` browser walk applies.

## Dismissals

None.

---

## Gate 10 — `/benchmark`: Performance regression

**Outcome**: `n/a (no runtime perf surface)`

No bundle, no client JS, no server runtime. Markdown + SKILL.md prose has no perf surface; routing-index lookup is a read-time bash grep operation bounded to a single file.

## Dismissals

None.

---

## Gate 11 — `convention` (ak): Convention headers + hook coverage

**Outcome**: `pass`

- `bash kit/scripts/commit-hooks/check-file-headers.sh main` → exit 0 (no flagged files).
- File headers (`// What:` / `// Why:` / `// Does NOT:`): n/a — no `.ts` / `.tsx` source files added.
- JSDoc on exported functions: n/a — no new exports.
- Migration `-- ROLLBACK` comment: n/a — no migration files.
- `ON DELETE` clause on `auth.users(id)` FKs: n/a — no migrations.
- Realtime publication membership: n/a — no `subscribeTo*` helpers added.
- Backlog placement: spec entry is properly in `kit/ROADMAP.md` and was deleted on close-out (verified above).
- No completed items left in `kit/ROADMAP.md` — the `§ Context-aware guideline routing` entry is deleted; `§ PR-B` is the new follow-on entry (still open, correct).
- Routing-index conforms to the convention introduced by THIS PR (Layer 1 ToC at `kit/docs/guide/README.md`; Layer 2 ToC at the top of every routed guide via Task 4; Layer 3 sub-ToCs on the two approved sections `§ Slow-Job Lifecycle` and `§ Non-Negotiables`).
- New BATS files follow the existing test-file naming + setup convention (load `helpers/setup`; use `$TESTS_DIR`; idempotent setup).

## Dismissals

None.

---

## Audit 1

**Audited range**: `origin/main..HEAD` (16 commits: `aa5f747`..`f9c093a`).

**Sub-skills invoked**:

- `/ak-docs-review`: coverage + adequacy + coherence audit of docs in the commit range.
- `/ak-tests-review`: coverage + quality audit of tests in the commit range.

### Docs review

**Coverage check**:

- The PR ships 3 new guide files (`migrations.md`, `database-queries.md`, `wrapper-boundaries.md`) and 10 modified guide files. Each new file is paired with a routing-index entry in `kit/docs/guide/README.md` (verified by BATS Test 2 — routing-completeness). No orphaned new guide.
- The PR ships 2 skill-file edits (`.claude/skills/devshop/spec/SKILL.md`, `.claude/skills/devshop/implement/SKILL.md`); both edits are paired with `workflow.md § Devshop Skill Map` orientation paragraph (line 424) per the docs-coverage convention. Decision Impl-2 captures the docs-coverage hook interaction.
- Cross-ref rewrites in `template/CLAUDE.md`, `template/packages/core/src/schemas/README.md`, and `kit/tests/preship-rls-coverage.bats` cite the post-split anchors. Verified by inspection — each citation lands on a real H2 in the new file (and BATS Test 1 would fail if any drifted).
- `tests-review/SKILL.md` and `new-project/SKILL.md` were updated as part of Task 12's paired-doc bundling (Impl-2) — verified to reference `wrapper-boundaries.md` rather than the now-pointed-at conventions.md anchor.

**Adequacy check**:

- Each new routing row has a Notes column entry (no row has bare Trigger/Target without context).
- Three Decisions sections (spec D1–D9 + tasks.md Impl-1 through Impl-4) provide audit-trail completeness. Impl-1 (deferred cross-ref rewrites via pointer-redirect) is sound: the pointer-redirect pattern is documented in `kit/docs/guide/conventions.md § Cross-skill awareness` as established convention; substance lives in the new file; conventions.md retains the heading-anchor for backwards compatibility (re-checked: the one-line pointers at lines 313, 538, 365 of conventions.md preserve the original H2 names, so external `conventions.md#supabase-hardening-defaults` etc. links still hit the pointer).
- Skill-patch fallback prose (`/ak-implement` Step 1 lines 30-34) is unambiguous — names the trigger case (pre-adoption projects), names the fallback target (`conventions.md`), and frames the fallback as preserving prior behavior.

**Coherence check**:

- Pre-/post-routing-index reading order is consistent: every new guide starts with a Contents (Layer 2 ToC) block immediately after the H1, mirroring the existing pattern in `conventions.md` and `workflow.md`.
- The split-section pointer prose ("_See [`<new-file>.md`](./<new-file>.md) for the canonical text._") follows the same shape as the pre-existing `latency-feedback.md` pointer cited by Decision Impl-1.
- Decision Impl-3 (Target column = routing target; Notes column = free-text including OOR citations) is reflected in BATS Test 2's parser (extracts `$3` column only as the routed target).

**Severity**: zero high. Zero medium. Zero low.

### Tests review

**Coverage check** (every user-observable surface has a test):

- 3 new BATS files exercise the 3 D7 invariants:
  - `routing-link-resolution.bats` (5 tests) — every routing-row `(file, anchor)` resolves.
  - `routing-completeness.bats` (5 tests) — every guide is routed OR explicitly OOR.
  - `routing-real-world-grounding.bats` (3 tests) — ≥3 triggers fire on real lalista specs.
- The `/workspace`-not-mounted path is fenced by `skip "/workspace not mounted — cross-boundary grounding check requires devcontainer fixture"` (line 22 of `routing-real-world-grounding.bats`). Explicit skip with reason — never silent pass per spec § Gotchas.
- Skill prose changes are validated by skill convention rather than automated test — Decision Impl-2's paired-doc bundling is the lever (workflow.md paragraph documents the routing surface so a regression in either skill or in the index surfaces during a future docs-coverage check).

**Quality check**:

- BATS test assertions are deep, not shape-only:
  - Test "every (file, anchor) routing link resolves to a real H2/H3" — extracts every link, slugifies each H2/H3 in target files via GitHub's algorithm, asserts membership.
  - Test "alphabetical file list mirrors every disk file exactly once" — bi-directional drift check (disk → alpha AND alpha → disk).
  - Test "specific high-confidence routing-row triggers fire on lalista specs" — names 4 high-confidence triggers (`supabase/migrations`, `PostgREST`, `optimistic mutation`, `PWA`) and requires ≥3 to fire (one degree of robustness if a single spec gets renamed).
- BATS shell-safety: `set -e` semantics via bats-core; all subshells use proper quoting; `awk -F'|'` field extraction is bounded; no eval / no untrusted input.

**Severity**: zero high. Zero medium. Zero low.

### Findings

None. Audit clean.

<!-- audited-at: f9c093a1f8fdaae48ce78cce5b1ecbe4d8e94a8b -->

## Audit 2: post-polish (2026-05-11)

<!-- audited-at: b8f260dac0f898d1c796ba9c4fb26c01427c8a37 -->
<!-- range: f9c093a1f8fdaae48ce78cce5b1ecbe4d8e94a8b..HEAD -->

findings: high=0 medium=0 low=1

**Audited range**: 2 commits — `90d6baa` (pre-ship review.md, audit trail) and `b8f260d` (BUILD-LOG.md + PLAN.md bookkeeping). No runtime code, no test changes, no doc body changes outside the spec/ artifacts.

**Sub-skills invoked**:

- `/ak-docs-review`: 1 low-severity finding (BUILD-LOG numeric-claim phrasing).
- `/ak-tests-review`: clean — no test files in range.

### Docs findings

- [low] BUILD-LOG.md:10 — Summary line claims "12 routing rows shipped on the audit's proposed initial set + 10 expansion"; actual `kit/docs/guide/README.md` table has 13 rows. Audit proposed 22, spec floor was ≥10. Phrasing parses ambiguously (12+10=22, neither matches). Suggested rewording: "13 routing rows shipped (spec floor: ≥10; audit proposed 22; scoped down per Impl-4)". Low because BUILD-LOG is internal history and the claim does not gate behavior, but the numeric mis-statement is concrete and worth correcting in a future cleanup pass.

### Tests findings

- (none)

### Bypass trailer audit

- (none)

### Verifications performed

- Total commits since `origin/main`: 19. Commits up through claimed Final SHA `90d6baa`: 18 (matches BUILD-LOG breakdown 1+1+2+3+9+1+1). The 19th commit is `b8f260d` itself (the BUILD-LOG bookkeeping commit, which cannot reference its own SHA).
- BATS test count at HEAD: **745** top-level `@test` declarations across 47 `.bats` files in `kit/tests/`. Matches BUILD-LOG claim. Routing tests: `routing-link-resolution.bats` (5) + `routing-completeness.bats` (5) + `routing-real-world-grounding.bats` (3) = 13, matching the "13 new routing tests" claim and the "732 existing + 13 new = 745" arithmetic.
- Audit 1 status verified clean at HEAD (zero/zero/zero from f9c093a). BUILD-LOG claim "Audit 1 clean at HEAD" is accurate.
- `specs/context-aware-guideline-routing/spec.md` exists at the path BUILD-LOG cites.
- PLAN.md transition is consistent: Active table replaced with `_No work in progress._`; Planned section preserved with 2 forward-looking entries (gstack-helper-path-resolution, pr-body-img-merge-sha-survival). No accidental data loss.
- No file renames or deletions in the audit range, so no cross-doc coherence sweep needed beyond claim-by-claim verification.
