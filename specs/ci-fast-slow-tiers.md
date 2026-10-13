# CI in two tiers, fast and slow, for the devshop and every project

**Go:** "do it all"; on the open questions: "1. yes use placeholder as you recommend 2. yes" (owner, 2026-10-13)

## Intent

The owner asked whether lint in both CI and the devshop's pre-push hook wastes resources, then
proposed splitting checks into a fast tier (programmatic checks: lint, secret scan, unit tests) and
a slow tier (Playwright, end-to-end), chosen "by concept: unit tests vs integration/e2e tests"
rather than by time. They asked how new projects pick up the pattern, and then: "do it all", with
the existing checks moved into the two tiers and the fixture retrofitted in the same change.

## Decisions

- Lint stays in both places: CI is the wall (required, can't be skipped); the hook is feedback that
  saves a CI round trip and `--no-verify` skips it. The saving is in CI itself: one runner's setup
  instead of two or three for the same fast checks (2026-10-13)
- Tier by concept, not time: **fast** is static checks (lint, format, typecheck, secret scan) and
  tests of one unit (a script, a module) in-process or against local stubs, emulators or sandboxes;
  **slow** is tests of the system end to end: a full install, a deployed app, a browser, real
  external services. A sandbox such as `unshare` doesn't make a test slow. Rejected: a seconds
  threshold (owner, 2026-10-13)
- The pre-push hook stays as it is: the pinned gitleaks plus the repo's `scripts/lint.sh`; unit
  tests run in CI's fast job, not on every push. Rejected: the whole fast tier on push, about a
  minute per push here (owner, 2026-10-13)
- Every project declares both `scripts/check-fast.sh <base>` and `scripts/check-slow.sh`, and the
  existing checks move into them: `check-fast.sh` runs the secret scan, `scripts/lint.sh` and the
  fast tests; `scripts/lint.sh` stays as the part the hook runs. A project with no slow tests yet
  has a `check-slow.sh` that says so and exits 0, so every project has the same two required checks
  and adding slow tests later changes no CI or branch protection. Rejected: `lint.sh` plus
  `test-unit.sh` / `test-integration.sh` (owner, 2026-10-13); an optional slow job (a single
  template can't both have and lack it)
- Each script exits with the worst result of its parts, as `lint.sh` does: 0 clean, 1 findings, 2
  couldn't run; every part runs even after one fails
- CI has a job `fast` running `check-fast.sh "$BASE"` and a job `slow` running `check-slow.sh` with
  `needs: fast`, so a fast failure doesn't spend minutes on the slow tier. Neither has a job-level
  `if:` or `continue-on-error` (a skipped required job counts as passed on GitHub). In `ci.yml` any
  job with an `environment:` (a deploy) needs both. Rejected: the tiers in parallel (2026-10-13)
- One stack-agnostic template, `runtime/templates/ci.yml`: `fast` checks out with full history,
  runs `scripts/setup.sh` when present, installs the pinned gitleaks, runs `check-fast.sh "$BASE"`;
  `slow` does the same setup and runs `check-slow.sh`. A marked block is where a stack adds its
  tool installs (e.g. setup-node). Rejected: a cross-repo reusable workflow, which ties every
  project's CI to the devshop repo's access settings (2026-10-13)
- `runtime/scripts/ci-tiers-check.py <workflow>` checks those rules. It parses YAML with PyYAML:
  CI installs it hash-pinned, sessions use the image's; missing PyYAML is "couldn't run" (exit 2),
  never a pass. A step counts as running a script when a line of its `run:` starts with the script's
  path (comment lines don't count). It is feedback in two places: this repo's `scripts/lint.sh` runs
  it on its own `ci.yml`, and session start runs it on the project's (30 s limit) and prints one
  `DEVSHOP:` line, which reaches the owner, when it fails, couldn't run, or the project has no
  `.github/workflows/ci.yml`
- New projects find the template two ways: that `DEVSHOP:` line names it, and the `build` skill
  says a project without CI starts from it
- In this repo the slow tier is `tests/bootstrap.test.sh`, which replays the whole cloud install. A
  test file is slow when its leading comment block (after the shebang) has the exact line
  `# tier: slow`. `tests/run.sh fast|slow` runs one tier, `tests/run.sh` still runs all, and a tier
  with no files fails like an empty suite does
- Tools per job here: `fast` gets gitleaks, shellcheck, dcg, `npm ci`, PyYAML, the user-namespace
  sysctl (three fast tests sandbox with `unshare`) and full history; `slow` gets the sysctl, full
  history and `jq`
- The fixture is retrofitted in the same change, in its own PR (owner, 2026-10-13): `scripts/lint.sh`
  (`npm run lint`; exit 2 when `node_modules` is missing) so the hook lints there too,
  `scripts/setup.sh` (`npm ci`) so a session can run it, `check-fast.sh` (its secret scan, lint,
  `npm test`, schema check, `tests/run.sh`), and a `check-slow.sh` with no slow tests yet: its
  current tests are all unit tests by the rule. Its `deploy` needs `fast` and `slow`
- Branch protection changes: here `lint` and `secret-scan` become `fast` and `slow`; in the fixture
  `lint`, `test` and `secret-scan` do. Only the owner can change it. Order: the owner swaps the
  required checks just before merging each PR, then open PRs merge `main` to get the new jobs
- Evidence names the fixture by project name and PR number only, no URL or `owner/repo`
- Changed after the go (owner, 2026-10-13, "option 1"): the reviewer can't read GitHub or the
  fixture, so it could never confirm the former items 7 (this PR's CI green) and 8 (the
  fixture retrofit, PR checks included). Those become the owner's checks at merge, outside the acceptance
  items: this PR's `fast` and `slow` green on its head commit, and the fixture's retrofit (fixture
  PR #11: its `ci.yml`, `lint.sh`, docs, and `fast`, `slow` and the deploy green). The former item 9
  becomes AC-7, this repo's docs only. AC-1 gains the stricter rule the check already had: the
  step that runs a tier's script has no `if` or `continue-on-error` of its own, which could skip
  the tier as silently as a job-level one

## Acceptance items

- **AC-1** `ci-tiers-check.py <workflow>` exits 0 on a workflow following the rules above; exits 1,
  naming the rule, for each of: no `fast` job; `fast` not running `scripts/check-fast.sh "$BASE"`;
  no `slow` job; `slow` not running `scripts/check-slow.sh`; `slow` not needing `fast` (string or
  list form both accepted when right); a job-level `if:` or `continue-on-error` on `fast` or
  `slow`; the step running the script with its own `if:` or `continue-on-error`; a job with an
  `environment:` not needing both; the script named only in a comment line;
  and exits 2 on a missing file, unparseable YAML, or PyYAML not importable. Shown by a test feeding
  each case
- **AC-2** `runtime/templates/ci.yml` passes `ci-tiers-check.py`, shown by a test
- **AC-3** Session start prints exactly one `DEVSHOP:` line about CI, naming the template and the
  failed rule or the reason, when the project's `ci.yml` fails the check, the check couldn't run,
  or there is no `ci.yml`; and nothing about CI when it passes. Shown in `tests/git-hooks.test.sh`
- **AC-4** `tests/run.sh fast` runs every test file without the marker, `tests/run.sh slow` only
  those with it, `tests/run.sh` all; an unknown argument and a tier with no files fail; the marker
  appearing below the leading comment block doesn't count. Shown by a test
- **AC-5** This repo's `check-fast.sh <base>` runs `scripts/secret-scan.sh <base>`,
  `scripts/lint.sh <base>` and `tests/run.sh fast`; `check-slow.sh` runs `tests/run.sh slow`; both
  run every part and exit with the worst code. Shown by a test with stubbed parts
- **AC-6** This repo's `ci.yml` has exactly the jobs `fast` and `slow` with the tools listed above,
  passes `ci-tiers-check.py`, and `scripts/lint.sh` runs that check on it (so `tests/lint.test.sh`
  covers five checks). Shown by `tests/run.sh`
- **AC-7** Docs match in this repo: `install/README.md`, `docs/README.md`, `README.md` and the
  `build` skill describe the tiers, and a workstream task line records the change — verified by
  review: a grep for the old job names finds only history

## Out of scope

- A real stack home or Playwright tests: the first comes with M2; the template is what it will use
- Running `check-fast.sh` in the pre-push hook (decided against above)
- Changing branch protection: the owner's step on each repo, in the order above
- Confirming CI on this PR and the fixture's retrofit: the owner's checks at merge (decided above)
- A wall that enforces the tier shape in project CI: the check is feedback; the wall for new
  projects stays TARGET Stacks 5 (scaffold from a stack home, require its CI green)
- `CLAUDE.md`'s "run `tests/run.sh` before pushing": still true, as it runs both tiers
