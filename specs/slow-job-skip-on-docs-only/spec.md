<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: slow-job-skip-on-docs-only -->
<!-- date: 2026-05-08 -->

# Spec: slow-job-skip-on-docs-only (devshop)

**Sources:**

- `PLAN.md` row #1 — primary scope summary (~1h: template edit + BATS coverage + lalista adoption follow-up)
- `kit/ROADMAP.md § Slow-job skip-on-docs-only via CI workflow paths-ignore` — full problem statement, proposed shape, false-positive analysis, and "shape (allowlist preferred)" intent (line 943) cross-reference
- `kit/docs/guide/conventions.md § Slow-Job Lifecycle` — existing convention home; this PR appends a sub-section
- `template/.github/workflows/ci.yml` lines 80-123 — the commented slow-job stub being modified
- `kit/scripts/preship/slow-job-lifecycle-check.sh` + `kit/tests/preship-slow-job-lifecycle.bats` — the existing structural-enforcement gate being extended (D3)
- Empirical verification artifact: actionlint v1.7.7 against ROADMAP's literal `slow: paths-ignore:` YAML (output captured in D1's rationale below)

PR adds a job-level CI filter that skips the slow-job (Supabase + integration tests + Playwright × 2 viewports, 8–10 min) when the diff is docs-only — `**/*.md`, `specs/**`, `PLAN.md`, `BUILD-LOG.md`, `TODOS.md`, `.gstack/**`, `.devshop/**`. The fast-job continues running on every push. Saves ~8–10 min of CI per docs-only PR push (lalista PR #52 burned three full slow-job cycles for one logical change; abra-kadabra PR #27 added bookkeeping commits that compound the cost).

---

## Decisions (resolved at spec time)

5 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Filter shape — `changes` setup job + per-job `if:` (single workflow file)

**Decision:** Add a tiny `changes` setup job to `template/.github/workflows/ci.yml` that always runs (~5s), classifies the PR's diff via inline bash + glob match, and exposes `runtime: 'true'/'false'` as a job output. The slow-job adds `needs: [fast, changes]` and `if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'`. Stays within the existing single-workflow-file structure; no third-party action; branch-protection contexts (`fast` + `slow`) stay unchanged.

**Rationale:** ROADMAP's proposed `slow: paths-ignore:` is **invalid at job level** — verified empirically via actionlint v1.7.7 against the ROADMAP's literal YAML, output: `unexpected key "paths-ignore" for "job" section. expected one of "concurrency", "container", "continue-on-error", "defaults", "env", "environment", "if", "name", "needs", "outputs", "permissions", "runs-on", "secrets", "services", "steps", "strategy", "timeout-minutes", "uses", "with"`. `paths-ignore` is only a workflow-trigger key. Two alternatives considered and dismissed: (B) `dorny/paths-filter@v3` adds a third-party action dependency for one feature; (C) splitting into `ci-fast.yml` + `ci-slow.yml` with `on: paths-ignore:` at trigger level requires every adopting project to update branch-protection contexts (bigger blast radius).

### D2: Ignore list contents

**Decision:** The deny-list classifies a path as docs-only if it matches any of:

- `**/*.md`
- `specs/**`
- `PLAN.md`
- `BUILD-LOG.md`
- `TODOS.md`
- `.gstack/**`
- `.devshop/**`

A diff is "docs-only" iff EVERY changed file matches at least one of these globs. The `changes` job emits `runtime=false` only when the diff is fully docs-only.

**Rationale:** Matches PLAN.md row #1 and the ROADMAP entry verbatim. `**/*.md` already structurally covers the named `*.md` files; the explicit names are kept for reader clarity and to defend against a future YAML refactor that drops the broad glob. False-positive surface is mathematically narrow: only a runtime file misnamed `*.md` could match, which is structurally implausible (build tooling treats `.md` as docs).

### D3: Extend `slow-job-lifecycle-check.sh` to assert the filter is present once uncommented

**Decision:** Add a sub-check to `kit/scripts/preship/slow-job-lifecycle-check.sh` that fires when the slow-job is uncommented in a project's `.github/workflows/ci.yml`. The sub-check asserts the workflow contains:

1. A `changes` job at the top level with the `runtime` output declared.
2. The `slow:` job's `needs:` includes `changes`.
3. The `slow:` job's `if:` references `needs.changes.outputs.runtime == 'true'` (or syntactic equivalent).

Failure produces a remediation message pointing at the new `kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter` sub-section. New BATS cases in `kit/tests/preship-slow-job-lifecycle.bats` cover both pass (filter present) and fail (filter absent) shapes.

**Rationale:** ROADMAP § "CI slow-job lifecycle convention" line 943 explicitly says: "Convention should pick one shape and enforce it in the same `/ak-pre-ship` gate that asserts uncommenting + branch-protection." Aligns this PR with the existing structural-enforcement contract — the gate that currently asserts uncommenting + retry pattern + branch protection now also asserts the filter. Without this, the convention propagates to new projects via the template stub but degrades to operator-memory once the slow-job is uncommented.

### D4: Lalista adoption — separate follow-up PR

**Decision:** This PR is devshop-only: template edit + BATS + slow-job-lifecycle gate extension + conventions doc. Lalista's adoption (a one-line edit to `apps/web/.github/workflows/ci.yml` adding the `changes` job + filter) is a separate follow-up PR landed AFTER this PR merges to devshop main and the next devshop pull propagates to the lalista project.

**Rationale:** PLAN.md row #1 states verbatim: "Lalista adopts via a one-line PR after the template change lands." Confirmed by the operator at Phase 0 due to a concurrent lalista session — touching `/workspace/` from this devshop session risks corrupting the other session's working tree.

### D5: Where in `conventions.md`

**Decision:** New sub-section `### Skip-on-docs-only filter` under the existing `## Slow-Job Lifecycle` heading in `kit/docs/guide/conventions.md`. Place it after `### Structural enforcement` (line 143) and before `### Codified prior art` (line 155) so the gate-extension narrative flows naturally: lifecycle → uncommenting checklist → helper scripts → structural enforcement → **skip-on-docs-only filter** → codified prior art.

**Rationale:** `## Slow-Job Lifecycle` (line 112) is the existing canonical home for slow-job convention material. Sub-section keeps related convention text together rather than creating a sibling top-level section. The placement (between structural enforcement and prior art) puts it in the "what the gate also enforces now" position, which is where a reader looking up "why did the slow-job-lifecycle gate just block me?" will find it.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Files to
     create/modify, Tests, Dependencies, Task order, Gotchas, Acceptance /
     rollout / rollback. The Decisions section above stays verbatim. -->
