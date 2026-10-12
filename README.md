# Abra-Kadabra

A devshop for Claude Code. You say what you want, from a whole app to a one-line fix. Claude
helps you sharpen it, specs it and builds it, iterating against adversarial review until the
result is verified against your intent. Then you review the PR and its preview, and your
approval ships it. Claude works inside walls it can't move.

**Status:** v2 is being built in this repo (the 2026-Q4 revamp). It doesn't do anything for
projects yet. Plan and tracker: [`kit/notes/revamp/`](kit/notes/revamp/README.md).

**v1** is frozen at the `v1-final` tag and is no longer on `main`. It is reference only (the revamp
notes cite it as evidence), never instructions. To read it:

```sh
git fetch origin tag v1-final
git worktree add ../v1 v1-final
```

## Layout

| Path                                    | What                                                                                  |
| --------------------------------------- | ------------------------------------------------------------------------------------- |
| [`CLAUDE.md`](CLAUDE.md)                | Rules for Claude working in this repo (always loaded; kept short)                     |
| [`docs/README.md`](docs/README.md)      | Docs map: every doc in the repo is linked from it                                     |
| [`scripts/`](scripts)                   | Tested scripts for mechanical steps, incl. the checks CI runs (secret scan, lint)     |
| [`package.json`](package.json)          | Pins the repo's own Node tools (Prettier); `npm ci` installs them                     |
| [`tests/`](tests)                       | Tests; `tests/run.sh` runs them all. Named after what they test (`gitleaks` → config) |
| [`.gitleaks.toml`](.gitleaks.toml)      | Secret-scanning config, proven by `tests/gitleaks.test.sh`                            |
| [`.github/`](.github)                   | CI (`workflows/ci.yml`) and `CODEOWNERS` (the owner approves every change)            |
| [`bootstrap.sh`](bootstrap.sh)          | Entry point the cloud environments' setup script runs; its path must not change       |
| [`install/`](install/README.md)         | The install: bootstrap, plugin and dispatcher that select a project's pinned version  |
| [`runtime/`](runtime)                   | What a project's `.devshop-version` selects: `skills/` and `hooks/` of that version   |
| [`kit/notes/revamp/`](kit/notes/revamp) | Revamp plan, decisions, findings, lessons, log, and the spikes (kept as notes)        |

Planned, added when their task lands: skills under `runtime/skills/` (W10.6), stack homes
`stacks/<name>/` (W10.5.2) and discipline guidelines under `docs/`.
