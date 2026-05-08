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

**Status:** pending

## Task 4 — `kit/docs/guide/conventions.md` sub-section

**Status:** pending

## Task 5 — PLAN.md flip to Active

**Status:** pending
