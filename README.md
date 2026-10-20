# Abra-Kadabra

A devshop for Claude Code. You say what you want, from a whole app to a one-line fix. Claude
helps you sharpen it, specs it and builds it, iterating against adversarial review until the
result is verified against your intent. Then you review the PR and its preview, and your
approval ships it. Claude works inside walls it can't move.

**Status:** v2 is being built in this repo (the 2026-Q4 revamp). It runs the owner's website on
Cloudflare, which has the first stack home ([`runtime/stacks/`](runtime/stacks/README.md)); the
first real app comes next. Plan and tracker: [`kit/notes/revamp/`](kit/notes/revamp/README.md).

**v1** is frozen at the `v1-final` tag and is no longer on `main`. It is reference only (the revamp
notes cite it as evidence), never instructions. To read it:

```sh
git fetch origin tag v1-final
git worktree add ../v1 v1-final
```

## Start a new project

Follow [the owner's steps](runtime/templates/new-project-steps.md): part 1 (the repo, its merge
settings, the agent as a collaborator, the cloud environment) before the first session; then, in
that session, ask to set up the new project. Its `new-project` skill places the devshop's files
and opens the first PR with green CI, and part 2 (protecting `main`) comes in that PR's body
([spec](specs/new-project.md)).

## Layout

| Path                                    | What                                                                                                                                                 |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`CLAUDE.md`](CLAUDE.md)                | Rules for Claude working in this repo (always loaded; kept short)                                                                                    |
| [`docs/README.md`](docs/README.md)      | Docs map: every doc in the repo is linked from it                                                                                                    |
| [`scripts/`](scripts)                   | Tested scripts for mechanical steps, incl. CI's two tiers (`check-fast.sh`, `check-slow.sh`)                                                         |
| [`package.json`](package.json)          | Pins the repo's own Node tools (Prettier); `npm ci` installs them                                                                                    |
| [`tests/`](tests)                       | Tests; `tests/run.sh [fast\|slow]` runs a tier or all. Named after what they test                                                                    |
| [`.gitleaks.toml`](.gitleaks.toml)      | Secret-scanning config, proven by `tests/gitleaks.test.sh`                                                                                           |
| [`.github/`](.github)                   | CI (`workflows/ci.yml`) and `CODEOWNERS` (the owner approves every change)                                                                           |
| [`bootstrap.sh`](bootstrap.sh)          | Entry point the cloud environments' setup script runs; its path must not change                                                                      |
| [`install/`](install/README.md)         | The install: bootstrap, plugin, dispatcher, the gstack and tools pins                                                                                |
| [`runtime/`](runtime)                   | What `.devshop-version` selects: `skills/`, `hooks/`, `git-hooks/`, `scripts/`, `reviewer/`, and `project-contract.txt`, what every project provides |
| [`kit/notes/revamp/`](kit/notes/revamp) | Revamp plan, decisions, findings, lessons, log, and the spikes (kept as notes)                                                                       |

Stack homes (`runtime/stacks/<name>/`) and discipline guidelines (`runtime/guidelines/`) live in
`runtime/`, because only `runtime/` reaches a project's session. The Cloudflare home and the UI
guideline ship; `nextjs-supabase/` is a placeholder until lalista (M3).
