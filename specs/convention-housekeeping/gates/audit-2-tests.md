Tests look solid — no findings.

## Audit scope

- Range: `b17e123..HEAD` (single commit `d6fa560` — "fix(closure): unwind cross-refs missed by the convention-housekeeping bundle")
- Files touched (6): 5 docs (`kit/docs/guide/conventions.md`, `kit/docs/guide/hooks.md`, `kit/docs/guide/ops.md`, `kit/docs/guide/workflow.md`, `template/CLAUDE.md`) + 1 test (`kit/tests/guard-docs-coverage-project.bats`).
- No source-code changes. No new scripts, hooks, or skills. The audit-prose-exemption guard logic in `kit/scripts/commit-hooks/check-docs-coverage-project.sh` was already shipped in Audit 1's commits; this commit only tightens its test coverage and unwinds stale cross-refs.

## Section A — Coverage of new behavior

No new source files in range. Devshop-side rubric N/A — no new `kit/scripts/**.sh`, no new `kit/scripts/preship/**.sh`, no new `.claude/skills/devshop/**/SKILL.md`, no new `kit/hooks/**`.

The lone test-file change strengthens an existing test (`BLOCK: actual call site in apps/ still fires when matching prose also exists in specs/`, line 104+) — the test already asserted `assert_failure` + `assert_output --partial "METRICS.md"`; the diff adds two assertions that nail down the path-scope contract:

- `assert_output --partial "apps/web/lib/foo.ts"` — failure message must cite the real call site (the source file under `apps/`).
- `refute_output --partial "specs/foo/review.md"` — failure must NOT cite the exempt audit-prose path.

Both assertions map directly to the guard script's audit-prose exemption (`check-docs-coverage-project.sh:157` — `git diff --cached -- ':!specs/*/review.md' ':!specs/*/tasks.md'`). Coverage of the intended behavior is complete: the test now verifies BOTH that the block fires AND that the right path is named (not the wrong one).

## Section B — Test quality

- **Weak assertions**: none. Both new lines assert concrete substrings (`apps/web/lib/foo.ts`, `specs/foo/review.md`), not generic shape.
- **Missing error / invalid input tests**: N/A — this IS the error-path test (the BLOCK case).
- **Untested auth boundaries (RLS)**: N/A — bats guard test, no DB.
- **Implementation detail tests**: no. The assertions check user-visible CLI output (the failure message a developer sees), not internal state.
- **Missing boundary conditions**: existing companion tests already cover the symmetric PASS cases — `PASS: posthog.capture mention inside specs/<feature>/review.md is exempt` (line 88) and `PASS: Sentry.captureException mention inside specs/<feature>/tasks.md is exempt` (line 96). The new assertions in the BLOCK case complete the matrix.
- **Shape-only assertions**: the assertions ARE the user-visible-output assertions (CLI stderr substrings). Pairs correctly.
- **WebKit form-state hydration race**: N/A — not a Playwright test.
- **Realtime test missing publication migration**: N/A.
- **Wrapper API design**: N/A — no `packages/core/src/api/**` changes.
- **`routeWebSocket` after initial subscribe**: N/A.
- **Runtime validation at LLM / edge-function boundaries**: N/A.
- **Skipped tests audit**: no `.only` / `.skip` patterns added in range. Quick scan clean.

## Section C — Bypass trailer audit

`git log --format='%H%n%B%n---' b17e123..HEAD | grep Tests-Coverage-Bypass` returns zero rows. No bypasses to judge.

## Verification context

Full 30-test suite for `guard-docs-coverage-project.bats` passes locally (operator-confirmed). No source-code regressions possible — no source code changed.
