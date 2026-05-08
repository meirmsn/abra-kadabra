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

## In scope

Concrete deliverables for this PR (devshop-only):

- **Template edit** — add a commented-out `changes:` setup job and a `needs: [fast, changes]` + `if: …` line on the commented `slow:` stub in `template/.github/workflows/ci.yml`. Both stay commented (template ships slow-job commented; the new `changes` job rides the same uncomment ritual — see Gotchas).
- **Template-shape BATS test** — assert the template's `ci.yml` carries the `changes` job stub, the canonical D2 ignore-list globs, the `runtime` output, and the slow-job's `needs:` + `if:` lines (all in their commented-out form). Lives in `kit/tests/template-ci-yml-shape.bats` (new file).
- **Slow-job-lifecycle gate extension (D3)** — extend `kit/scripts/preship/slow-job-lifecycle-check.sh` with a sub-check that fires only when the slow-job is uncommented in the project's `ci.yml`. Asserts (1) a `changes:` job exists, (2) it declares a `runtime` output, (3) the `slow:` job's `needs:` includes `changes`, (4) the `slow:` job's `if:` references `needs.changes.outputs.runtime == 'true'`. Failure produces a remediation message pointing at the new `conventions.md` sub-section.
- **Extended BATS coverage (D3)** — add pass + fail cases to `kit/tests/preship-slow-job-lifecycle.bats` covering the new sub-check (filter present in correct shape; filter absent; partial filter — `changes` job exists but slow-job's `needs:` / `if:` not wired).
- **Convention doc (D5)** — new sub-section `### Skip-on-docs-only filter` under `## Slow-Job Lifecycle` in `kit/docs/guide/conventions.md`, placed between `### Structural enforcement` and `### Codified prior art`. Captures: shape (changes job + slow-job gating), the D2 ignore list verbatim, why job-level `paths-ignore` is invalid (D1 rationale), branch-protection-with-skipped-job behavior (Gotchas), uncomment-together-with-the-slow-job ritual.
- **Operational bookkeeping** — flip PLAN.md row #1 from Planned to Active with Branch + Spec columns. (Removal from Active + ROADMAP deletion happens at Phase 5.6 of `/ak-build`, NOT in this spec — Active flip only.)

## Out of scope

- **Lalista's adoption PR** (D4). Lalista's `apps/web/.github/workflows/ci.yml` is a separate follow-up PR landed AFTER this devshop PR merges and the next devshop pull propagates the convention. Not touched here — concurrent lalista session + cross-repo blast radius.
- **Splitting CI into `ci-fast.yml` + `ci-slow.yml`** with workflow-level `paths-ignore:` (D1 alternative C). Bigger blast radius — every adopting project would need to update branch-protection contexts.
- **Third-party action** like `dorny/paths-filter@v3` (D1 alternative B). One-feature dependency; unnecessary when 15 lines of inline bash do the same job.
- **New METRICS event** for skip rate. CI infra; surfaces would be GitHub Actions run counts + the existing fast/slow-job duration telemetry. No new event added without explicit ask.
- **Project-side scripts that codify "uncomment changes-and-slow together"**. Operator-memory + the conventions.md ritual + the gate's failure message are sufficient.
- **Backfill / rewrite of historical CI runs**. Forward-only.
- **Branch-protection automation**. The convention's existing uncommenting-checklist Step 5 already covers this for the `slow` context; the `changes` job is intentionally NOT a required context (it always succeeds; gating happens via the slow-job's `if:`).

## Files to create / modify

| Path                                              | Change | What                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `template/.github/workflows/ci.yml`               | modify | Add the commented-out `changes:` job (above the existing commented `slow:` stub) with `actions/checkout@v4` + `fetch-depth: 0`, an inline bash classify step writing `runtime=…` to `$GITHUB_OUTPUT`, and `outputs: { runtime: … }`. Edit the commented `slow:` stub: change `needs: fast` → `needs: [fast, changes]` and append the runtime gate to the `if:` line. Comment block above the stubs explaining the uncomment-both ritual. |
| `kit/tests/template-ci-yml-shape.bats` (new)      | create | New BATS file. Asserts the template `ci.yml` contains: the commented `changes:` block, all D2 ignore globs verbatim (`**/*.md`, `specs/**`, `PLAN.md`, `BUILD-LOG.md`, `TODOS.md`, `.gstack/**`, `.devshop/**`), `runtime=` output emission, `outputs:` declaration, slow-job `needs: [fast, changes]`, slow-job `if:` includes `needs.changes.outputs.runtime == 'true'`. Tests target the literal template file, not a fixture.        |
| `kit/scripts/preship/slow-job-lifecycle-check.sh` | modify | Add **Check 6** (after Check 5, inside the `if [ "$SLOW_LIVE" = "1" ]` block): asserts the workflow file contains a `changes:` job with `runtime` output, slow-job's `needs:` mentions `changes`, slow-job's `if:` references `needs.changes.outputs.runtime`. Findings reference `conventions.md § Skip-on-docs-only filter`.                                                                                                           |
| `kit/tests/preship-slow-job-lifecycle.bats`       | modify | Extend the existing pass-shape fixtures so they include the `changes` job + filter wiring (otherwise they regress under the new check). Add 3 new cases: (a) filter absent → finding fires; (b) `changes` job present but slow-job's `if:` not wired → finding fires; (c) all four sub-asserts present in correct shape → pass.                                                                                                          |
| `kit/docs/guide/conventions.md`                   | modify | Insert new sub-section `### Skip-on-docs-only filter` under `## Slow-Job Lifecycle`, between `### Structural enforcement` (line 143) and `### Codified prior art` (line 155).                                                                                                                                                                                                                                                            |
| `PLAN.md`                                         | modify | Flip row #1 (`slow-job-skip-on-docs-only`) from Planned to Active with Branch=`feature/slow-job-skip-on-docs-only` + Spec=`specs/slow-job-skip-on-docs-only/spec.md`.                                                                                                                                                                                                                                                                    |

## Tests

New + extended BATS coverage. No unit / integration / E2E in this PR — devshop kit changes are bash + YAML.

**`kit/tests/template-ci-yml-shape.bats`** (new) — pure literal-file assertions against `template/.github/workflows/ci.yml`:

- `changes:` job stub present (commented form, leading `  # changes:`).
- Ignore globs all present, in canonical order, inside the commented stub: `**/*.md`, `specs/**`, `PLAN.md`, `BUILD-LOG.md`, `TODOS.md`, `.gstack/**`, `.devshop/**`.
- Stub uses `actions/checkout@v4` with `fetch-depth: 0`.
- Stub's classify step writes `runtime=` to `$GITHUB_OUTPUT` via the canonical `echo "runtime=$RUNTIME" >> "$GITHUB_OUTPUT"` pattern.
- Stub declares `outputs: { runtime: ${{ steps.<id>.outputs.runtime }} }` (or syntactic equivalent).
- Slow-job stub's `needs:` is `[fast, changes]` (commented).
- Slow-job stub's `if:` line includes `needs.changes.outputs.runtime == 'true'`.
- Diff-base is the canonical `${{ github.event.pull_request.base.sha }}...HEAD` form (catches refactors that drop the `...` and ship `..` — which would not match the merge-base semantics the classify step relies on).

**`kit/tests/preship-slow-job-lifecycle.bats`** (extend) — net-new cases for D3:

- `pass when slow-job has filter present in canonical shape` — fixture includes `changes:` job + slow-job's `needs: [fast, changes]` + `if:` referencing `needs.changes.outputs.runtime`. Asserts `pass`.
- `findings: filter absent on uncommented slow-job` — fixture has uncommented slow-job but no `changes:` job. Asserts finding `slow-job missing skip-on-docs-only filter` (or analogous phrase) referencing the new conventions sub-section.
- `findings: changes job exists but slow-job's needs/if not wired` — partial-wire fixture. Asserts finding fires.
- Existing pass fixtures updated to include the canonical filter shape so they don't regress under Check 6.

**Existing `slow-job-lifecycle` BATS not affected by D3** (n/a outcomes, threshold detection, branch-protection sub-check) — no change.

## Dependencies

None. Pure bash + YAML changes inside the kit:

- No new npm / Deno / pip packages.
- No new GitHub Actions (no `dorny/paths-filter@v3` per D1's dismissal of alternative B).
- No new CLI tools beyond `git` (already present in every runner) and `bash`'s built-in glob matching (`case "$path" in glob_pattern) ;; esac`).
- No edge-function changes.
- No migrations.
- No new secrets / variables / env vars.

(Confirmed: D1's chosen shape is intentionally inline-bash + native YAML to keep the dependency surface zero.)

## Task order

Numbered, dependency-ordered. Mirrors the Phase 0.4 tracker; ROADMAP deletion happens at Phase 5.6 of `/ak-build`, not in this task list.

1. **Edit `template/.github/workflows/ci.yml`** — add the commented `changes:` stub, edit the commented `slow:` stub's `needs:` + `if:` lines. Atomic commit (template-only). _Depends on: nothing._
2. **Add `kit/tests/template-ci-yml-shape.bats`** — new BATS file pinning the literal template shape. Atomic commit. _Depends on: Task 1 (template file must exist in target shape)._
3. **Extend `kit/scripts/preship/slow-job-lifecycle-check.sh` + `kit/tests/preship-slow-job-lifecycle.bats`** — new Check 6 in the gate + 3 new BATS cases + update existing pass fixtures. One commit (gate code + tests must land together so neither half ever appears in main without the other). _Depends on: Task 1 (the conventions doc the gate's remediation message points at lands in Task 4, but the gate references the path string — file order: gate → doc; reference order: doc-section text is finalized before the gate ships)._
4. **Document filter in `kit/docs/guide/conventions.md`** — insert `### Skip-on-docs-only filter` sub-section under `## Slow-Job Lifecycle`. _Depends on: Task 1 (concrete shape) + Task 3 (gate behavior to describe in "structural enforcement also asserts" paragraph)._
5. **Flip PLAN.md row #1 to Active** — Planned → Active table, Branch + Spec columns added. _Depends on: spec exists (this file)._

(Phase 5.6 of `/ak-build` separately deletes the matching `kit/ROADMAP.md § Slow-job skip-on-docs-only via CI workflow paths-ignore` entry. That's the standard post-ship ROADMAP cleanup — out of scope for this spec's task list.)

## Gotchas

Non-obvious rules surfaced during Phase 0 spec resolution. Read before touching the relevant area.

- **Job-level `paths-ignore:` is invalid YAML for GitHub Actions** — `actionlint v1.7.7` rejects it with: `unexpected key "paths-ignore" for "job" section. expected one of "concurrency", "container", …` (full keylist in D1's rationale). `paths-ignore` is a **workflow-trigger** key only (under `on.pull_request.paths-ignore` or `on.push.paths-ignore`). The ROADMAP entry's proposed `slow: paths-ignore:` shape was empirically verified invalid; that's why D1 picks the `changes` setup-job pattern instead. If a future PR is tempted to "simplify" by inlining `paths-ignore` on the slow job, run `actionlint` against it first — the rejection is fast and load-bearing.
- **`git diff` against the base ref needs `fetch-depth: 0`** — GitHub Actions' default checkout shallow-clones (depth 1), which means `git diff "${{ github.event.pull_request.base.sha }}...HEAD"` errors with "fatal: Invalid revision range" because the base SHA isn't in the local object store. The `changes:` job MUST set `fetch-depth: 0` on the `actions/checkout@v4` step. (This already matches the fast-job's existing `fetch-depth: 0` for gitleaks's `--log-opts` — same root cause.) Documented inline in the template stub's comments.
- **GitHub Actions glob syntax ≠ bash glob syntax** — but this PR's classify step runs in bash, NOT in `paths:` / `paths-ignore:` config, so we use bash globbing semantics via `case "$path" in pattern) ;; esac`. Bash's `**` requires `shopt -s globstar` (BUT `case` matches treat `**` as `*` collapsing two levels — close enough for this list, and the explicit `specs/**` / `.gstack/**` / `.devshop/**` patterns plus `**/*.md` work as expected). The classify step explicitly enables `shopt -s globstar` before pattern matching to avoid the trap. Don't lift the inline bash into a `paths:` filter at the workflow level — the trigger-level filter is GitHub-glob (which has different rules for `!` exclusions, leading `/`, and `**`) and would need separate verification.
- **Branch-protection with `if:`-skipped jobs counts as passing** — when `slow:` is gated by `if: needs.changes.outputs.runtime == 'true'` and the diff is docs-only, GitHub Actions reports the slow-job status as `skipped`. Per [GitHub's documented behavior](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging) on required status checks, a `skipped` status is treated as `success` for the purposes of branch protection — the PR is mergeable. This is the load-bearing design assumption: docs-only PRs skip the slow-job AND merge cleanly without operator intervention. If GitHub ever changes this behavior (or branch protection is configured with the "Require all jobs to be successful" stricter mode), the fallback is to flip `if:` to `if: always() && (github.event_name != 'pull_request' || needs.changes.outputs.runtime == 'true')` — but this is NOT done preemptively (the documented behavior is the contract).
- **The `changes:` job is itself ALSO commented out in the template** — same as the `slow:` stub. The Phase 1c / 1g uncomment ritual (already in `conventions.md § Slow-Job Lifecycle § Uncommenting checklist`) gets one new bullet: "uncomment the `changes:` job above the slow-job — slow-job's `needs:` and `if:` already reference it, but the upstream job must exist." This keeps the template's "ship slow-job + everything around it commented until threshold" convention intact. Don't ship the template with `changes:` live but `slow:` commented — `slow:`'s `needs: [fast, changes]` would be a dangling reference at YAML-load time if `changes:` weren't also live.
- **Diff classify must handle the no-files-changed edge case** — `git diff --name-only` returns empty on an empty diff. The classify shell logic must treat empty-diff as `runtime=true` (safer default — run the slow job rather than silently skip) OR as a special case that's logged. D1's chosen shape: empty-diff → `runtime=true`. Don't accidentally let the `for path in $changed_files; do …; done` loop short-circuit to `runtime=false` because the loop body never executes.
- **`base.sha` is the merge-base, NOT the target branch's tip** — `${{ github.event.pull_request.base.sha }}` is the commit on the base branch from which the PR diverged, captured at PR-event time. Using `...` (three-dot) syntax in `git diff base...HEAD` correctly finds the changes introduced by the PR (the merge-base diff). Using `..` (two-dot) would diff against base's current tip and might include unrelated commits if main has moved — wrong shape. The spec calls out `...HEAD` explicitly.
- **End-to-end testing the filter before merge** — the only way to verify the runtime classification on real GitHub infra is to push a docs-only commit to a feature branch with the new template wired in, open a PR, and observe the slow-job status (`skipped`). Local actionlint validates YAML shape but NOT the runtime classify behavior. Acceptance criteria below cover this — Phase 5 of `/ak-build` watches CI, and a docs-only follow-up commit (e.g., a PLAN.md update) is the minimum forcing function. (Lalista's adoption PR per D4 is the natural production verification.)
- **`shopt -s globstar` scope** — bash's `globstar` is a shell option, not a per-pattern flag. The classify step enables it at the top of the inline bash and relies on the step running in its own shell instance (default GitHub Actions behavior — each `run:` block is a fresh `bash -e`). Don't merge the classify step into a multi-purpose composite step that toggles options elsewhere.

## Acceptance / rollout / rollback

### Acceptance criteria

1. `template/.github/workflows/ci.yml` contains a commented `changes:` job stub with the canonical D1 shape: `actions/checkout@v4` + `fetch-depth: 0`, classify step using `git diff --name-only "${{ github.event.pull_request.base.sha }}...HEAD"` against the D2 ignore list, writes `runtime=…` to `$GITHUB_OUTPUT`, declares `outputs: { runtime: … }`.
2. The same template's commented `slow:` stub has `needs: [fast, changes]` and `if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'`.
3. `kit/tests/template-ci-yml-shape.bats` passes — pins all of the above.
4. `pnpm test:bats` (or the project's equivalent BATS runner) is green; the existing `preship-slow-job-lifecycle.bats` suite still passes after pass-fixture updates; new D3 cases pass.
5. `kit/scripts/preship/slow-job-lifecycle-check.sh` Check 6 fires the expected finding on a fixture missing the filter, and produces `pass` on a fixture with the canonical filter shape.
6. `kit/docs/guide/conventions.md` contains the new `### Skip-on-docs-only filter` sub-section in the documented placement (between `### Structural enforcement` and `### Codified prior art`).
7. `PLAN.md` row #1 has flipped from Planned to Active with Branch + Spec columns populated.
8. (Forward-verification, post-merge) The first docs-only PR landed AFTER lalista's adoption PR (per D4) ships shows the slow-job as `skipped` in the PR's checks panel — the live behavioral evidence.

### Rollout

No separate rollout — lands with normal devshop merge.

- Devshop's `main` PR merges → kit changes are immediately available to any project that pulls them in.
- Existing projects (lalista) see no behavioral change until their own `ci.yml` is updated (D4's separate adoption PR).
- New projects scaffolded via `/ak-new-project` after this PR merges get the new template stub by default; commented out, the same as today's slow-job — no behavior change until they cross Phase 1c / 1g.
- No GitHub Variables / Secrets / branch-protection changes required at the devshop or project level (the new gating is internal to the workflow file; existing required-context list is unchanged).

### Rollback

Two layers, both narrow:

- **Devshop side** — revert this PR's commit. `template/.github/workflows/ci.yml` reverts to the pre-PR shape; `slow-job-lifecycle-check.sh` Check 6 disappears; conventions.md sub-section disappears; BATS files revert. Zero impact on shipped projects unless they ALREADY pulled the change AND uncommented their copy AND adopted the filter — a narrow window.
- **Project side** (only relevant once a project has adopted, post-D4) — revert the project's adoption commit, which restores the pre-filter `slow:` job. CI returns to running the slow-job on every PR. No data migration needed; the filter is purely a CI-skip mechanism with no persistent state.

The classification step has no external side-effects (no secrets read, no API calls, no file writes outside `$GITHUB_OUTPUT`), so even partial rollback during a botched land is safe — worst case, the slow-job runs on a docs-only PR that the operator expected to skip.
