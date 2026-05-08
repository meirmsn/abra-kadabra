<!-- generated-by: /ak-implement -->
<!-- feature: slow-job-skip-on-docs-only -->
<!-- date: 2026-05-08 -->

# Tasks: slow-job-skip-on-docs-only

Companion to `spec.md`. Mirrors `## Task order` (lines 147-157) with implementation notes + commits.

## Task 1 — Edit `template/.github/workflows/ci.yml`

**Status:** done

Added the commented `changes:` job stub above the existing commented `slow:` stub. Both stay commented (template "ship slow-job + everything around it commented until threshold" convention). Edits to the `slow:` stub:

- `needs: fast` → `needs: [fast, changes]`
- `if: github.event_name == 'pull_request'` → `if: github.event_name == 'pull_request' && needs.changes.outputs.runtime == 'true'`

`changes:` stub shape (D1):

- `actions/checkout@v4` with `fetch-depth: 0` (default depth-1 clone breaks `git diff base.sha...HEAD`).
- `id: classify` step: `set -euo pipefail` + `shopt -s globstar`, three-dot diff (`base.sha...HEAD`), empty-diff → `runtime=true` (safer default), per-path `case` against the D2 ignore list.
- `outputs: { runtime: ${{ steps.classify.outputs.runtime }} }`.

Comment block above the stubs explains the uncomment-both ritual + cross-references conventions.md.

**Commit:** Task 1 atomic.

## Task 2 — `kit/tests/template-ci-yml-shape.bats`

**Status:** done

New BATS file pinning the literal commented-out shape of the `changes:` setup-job stub + slow-job's `needs:` / `if:` wiring + the D2 ignore list (in canonical order). 23 assertions covering:

- changes-job stub presence + canonical shape (checkout@v4, fetch-depth: 0, classify step writes `runtime=` to `$GITHUB_OUTPUT`, three-dot diff, `shopt -s globstar`, empty-diff defaults to `runtime=true`, outputs.runtime declaration).
- D2 ignore list — every glob present (`**/*.md`, `specs/**`, `PLAN.md`, `BUILD-LOG.md`, `TODOS.md`, `.gstack/**`, `.devshop/**`) AND in canonical order (line-number ascending check pins the read-flow).
- Slow-job stub still commented; `needs: [fast, changes]` and `if:` carries pull_request gate AND runtime gate.
- Comment block cross-references conventions.md § Skip-on-docs-only filter and warns about the dangling-needs trap.

23/23 pass.

**Commit:** Task 2 atomic.

## Task 3 — Extend slow-job-lifecycle gate + BATS

**Status:** done

### Gate code (`kit/scripts/preship/slow-job-lifecycle-check.sh`)

Added Check 6 inside the existing `if [ "$SLOW_LIVE" = "1" ]` block (after Check 5). Asserts four sub-conditions:

1. A live `changes:` job (not commented).
2. The `changes:` job declares `runtime:` as an output referencing `${{ steps.<id>.outputs.runtime }}`.
3. The slow-job's `needs:` includes `changes` (matches both inline-list `[fast, changes]` and YAML block-list `- changes`).
4. The slow-job's `if:` references `needs.changes.outputs.runtime`.

Each sub-failure produces its own finding with a remediation message pointing at `kit/docs/guide/conventions.md § Slow-Job Lifecycle § Skip-on-docs-only filter`. The four findings are independent — a fully missing filter fires only one (the live-changes-job check); a partial-wire fires one per misalignment.

### BATS (`kit/tests/preship-slow-job-lifecycle.bats`)

- **Updated 3 existing pass fixtures** so they include the canonical filter shape (otherwise they'd regress under Check 6):
  - "pass when slow-job is correctly configured …" — added `changes:` job + `needs: [fast, changes]` + runtime gate to `if:`.
  - "pass when E2E specs trigger threshold and slow-job invokes playwright" — same.
  - "findings: multiple gaps reported together" — added the filter wiring so the fixture intentionally tests the legacy 3-gap shape (predicate + retry + invocation), not Check 6.
  - `write_good_slow_job_yml` helper — same.
- **Added 3 new D3 cases**:
  - `pass when slow-job has skip-on-docs-only filter present in canonical shape`.
  - `findings: filter absent on uncommented slow-job (no changes: job)` — asserts both `missing skip-on-docs-only filter` and the `Skip-on-docs-only filter` remediation phrase.
  - `findings: changes: job exists but slow-job's needs: not wired` — partial-wire variant.
  - `findings: changes: job exists but slow-job's if: does not reference runtime` — second partial-wire variant.

22/22 BATS pass; combined with template-ci-yml-shape.bats: 45/45.

**Commit:** Task 3 atomic (gate code + tests must land together).

## Task 4 — `kit/docs/guide/conventions.md` sub-section

**Status:** done

Inserted `### Skip-on-docs-only filter` between `### Structural enforcement` (line 143) and `### Codified prior art` (line 155+) per D5. Also extended the Structural enforcement list from 5 to 6 sub-asserts to include Check 6.

The new sub-section captures:

- **Shape** — full `changes:` + `slow:` job snippet with `actions/checkout@v4` + `fetch-depth: 0`, classify step writing `runtime=` to `$GITHUB_OUTPUT`, three-dot diff (`base.sha...HEAD`), `shopt -s globstar`, empty-diff → `runtime=true` (safer default).
- **Ignore list** (D2 verbatim) — `**/*.md`, `specs/**`, `PLAN.md`, `BUILD-LOG.md`, `TODOS.md`, `.gstack/**`, `.devshop/**`.
- **Why a `changes:` setup-job and not job-level `paths-ignore:`** — D1 rationale with the actionlint v1.7.7 rejection output verbatim. Two alternatives dismissed (third-party action + workflow split).
- **Branch-protection contract** — `skipped`-as-success per GitHub's documented behavior; `changes:` is intentionally NOT a required context. Includes the fallback `if:` shape if GitHub changes the behavior.
- **Uncomment-both ritual** — the dangling-needs trap in both directions; pre-ship Check 6 catches the mistake.
- **Forward verification** — local actionlint validates shape only, not runtime; the first docs-only PR is the live test.

**Commit:** Task 4 atomic.

## Task 5 — PLAN.md flip to Active

**Status:** pending
