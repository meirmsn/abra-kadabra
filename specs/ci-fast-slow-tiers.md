# CI in two tiers, fast and slow, for the devshop and every project

**Go:** pending

## Intent

The owner asked whether lint in both CI and the devshop's pre-push hook wastes resources, then
proposed splitting checks into a fast tier (programmatic checks: lint, secret scan, unit tests) and
a slow tier (Playwright, end-to-end), chosen "by concept: unit tests vs integration/e2e tests"
rather than by time. They asked how new projects pick up the pattern, and then: "do it all", with
the existing checks moved into the two tiers and the fixture retrofitted in the same change.

## Decisions

- Tier by concept, not time: **fast** is static checks (lint, format, typecheck, secret scan) and
  tests that run in-process or against local stubs and emulators; **slow** is tests that need
  something real: elevated privileges, the network, a running service, a browser, or a deploy. A
  time budget is not part of the rule; rejected: a seconds threshold (owner, 2026-10-13)
- The pre-push hook stays as it is: the pinned gitleaks plus the repo's `scripts/lint.sh`; unit
  tests run in CI's fast job, not on every push; rejected: the whole fast tier on push, about a
  minute per push here (owner, 2026-10-13)
- The contract a project declares is `scripts/check-fast.sh <base>` and, when it has a slow tier,
  `scripts/check-slow.sh`. The existing checks move into them: `check-fast.sh` runs the secret scan,
  `scripts/lint.sh` and the fast tests; `scripts/lint.sh` stays as the piece the hook runs;
  rejected: keeping `lint.sh` plus new `test-unit.sh` / `test-integration.sh` (owner, 2026-10-13)
- CI has a job `fast` running `check-fast.sh`, and a job `slow` running `check-slow.sh` with
  `needs: fast`, so a fast failure doesn't spend minutes on the slow tier; rejected: running both in
  parallel (owner agreed to `needs:`, 2026-10-13)
- The CI shape comes from one stack-agnostic template, `runtime/templates/ci.yml`, because the
  stack-specific part lives in the project's scripts; rejected: a cross-repo reusable workflow, which
  ties every project's CI to the devshop repo's access settings (2026-10-13)
- A check, `runtime/scripts/ci-tiers-check.py`, reads a workflow and fails when it doesn't follow
  the shape. Session start runs it on the project's `.github/workflows/ci.yml` and reports a
  `DEVSHOP:` line when it fails: feedback for the agent, not a wall. This repo's lint also runs it on
  its own `ci.yml`
- In this repo the slow tier is `tests/bootstrap.test.sh` (it needs unprivileged user namespaces).
  A test file is slow when it carries the line `# tier: slow`; `tests/run.sh fast|slow` runs one
  tier and `tests/run.sh` with no argument still runs all
- The fixture is retrofitted in the same change, in its own PR (owner, 2026-10-13). It gains
  `scripts/lint.sh` (`npm run lint`), so the hook lints there too. Its current tests (vitest in the
  Workers runtime against a local D1, schema check, script tests with stubs) are all fast by the
  rule, so it has no slow tier yet
- Required checks change names: here `lint` and `secret-scan` become `fast` and `slow`; in the
  fixture `lint`, `test` and `secret-scan` become `fast`, and `deploy` needs `fast`. Only the owner
  can change branch protection, so each PR needs the owner to swap its required checks before merge

## Acceptance items

- **AC-1** `ci-tiers-check.py <workflow>`, run from a repo root, exits 0 when the workflow has a job
  `fast` with a step running `scripts/check-fast.sh`, and, when the repo has `scripts/check-slow.sh`,
  a job `slow` with a step running it and `fast` in its `needs`. It exits 1, naming the rule, when
  any of those is missing, when a `slow` job exists without the script, or when any job running
  `check-slow.sh` doesn't need `fast`; it exits 2 on a missing or unparseable workflow. Shown by a
  test that feeds it each bad shape
- **AC-2** `runtime/templates/ci.yml` passes `ci-tiers-check.py` both with and without a
  `scripts/check-slow.sh` in the repo, shown by a test
- **AC-3** Session start prints one `DEVSHOP:` line naming the failed rule when the project has
  `.github/workflows/ci.yml` and `ci-tiers-check.py` fails on it, and prints nothing about tiers when
  it passes or the project has no `ci.yml`; shown by a test
- **AC-4** In this repo, `tests/run.sh fast` runs every test file except those marked
  `# tier: slow`, `tests/run.sh slow` runs only those, `tests/run.sh` runs all, and an unknown
  argument fails; shown by a test
- **AC-5** This repo's `ci.yml` has jobs `fast` and `slow` only, `slow` needs `fast`, and each runs
  `scripts/check-fast.sh "$BASE"` / `scripts/check-slow.sh`; `scripts/lint.sh` runs
  `ci-tiers-check.py` on it. Shown by `ci-tiers-check.py` passing on it in `tests/run.sh`
- **AC-6** This repo's `check-fast.sh <base>` runs the secret scan, `scripts/lint.sh <base>` and
  `tests/run.sh fast`, runs all three even after one fails, and exits non-zero when any fails;
  `check-slow.sh` runs `tests/run.sh slow`. Shown by a test with stubbed parts
- **AC-7** On this repo's PR, CI's `fast` and `slow` both pass on the head commit — verified by
  review: the PR's checks read from GitHub
- **AC-8** The fixture's `ci.yml` passes `ci-tiers-check.py`; its `check-fast.sh <base>` runs its
  secret scan, `scripts/lint.sh`, `npm test`, the schema check and `tests/run.sh`; its `deploy` job
  needs `fast`; and its PR's `fast` check passes on the head commit — verified by review: the
  fixture PR's checks read from GitHub
- **AC-9** The docs that name the old jobs or describe the hook and the contract (`install/README.md`,
  `docs/README.md`, the comments in `scripts/lint.sh` and `tests/lint.test.sh`) describe the tiers,
  and a workstream task line records the change — verified by review: grep for the old job names
  finds only history

## Out of scope

- A real stack home or Playwright tests: the first comes with M2; the template is what it will use
- Running `check-fast.sh` in the pre-push hook (decided against above)
- Changing branch protection: the owner's step on each repo
- A wall that enforces the tier shape in project CI: the check is feedback; the wall for new
  projects stays TARGET Stacks 5 (scaffold from a stack home, require its CI green)
