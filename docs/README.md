# Docs map

Every doc in this repo is linked from here, in a hierarchy (TARGET § Build 3). A new doc gets
a line here in the same change, and a removed one loses its line. CI holds this:
[`scripts/docs-map-check.py`](../scripts/docs-map-check.py) fails when a Markdown file is not
reachable from this page through links, or when a relative link or `#anchor` is broken.

## The repo

- [README.md](../README.md): what the devshop is, its status, and the repo layout.
- [CLAUDE.md](../CLAUDE.md): rules for Claude working in this repo.

## Checks

- Secret scanning: [`.gitleaks.toml`](../.gitleaks.toml) is gitleaks' default rule set. CI
  ([`ci.yml`](../.github/workflows/ci.yml)) runs [`tests/gitleaks.test.sh`](../tests/gitleaks.test.sh),
  which commits fake secrets to a scratch repo and fails unless every one is caught. CI then
  runs [`scripts/secret-scan.sh`](../scripts/secret-scan.sh) over the commits a change adds and
  the whole tree; [`tests/secret-scan.test.sh`](../tests/secret-scan.test.sh) proves it fails
  on a secret in either place. To run it locally, install gitleaks (the version pinned in
  `ci.yml`) and run `tests/run.sh`.
- Lint ([`ci.yml`](../.github/workflows/ci.yml) job `lint`), each check a script proven by the
  test of the same name in `tests/` (it feeds a known-bad input, and a missing tool fails):
  - [`format-check.sh`](../scripts/format-check.sh): `prettier --check .` with the version
    [`package.json`](../package.json) pins (`npm ci` installs it); `.prettierignore` skips the spikes.
  - [`shellcheck.sh`](../scripts/shellcheck.sh): shellcheck (version pinned in `ci.yml`) over every
    shell script, found by extension or shebang; the spikes are skipped.
  - [`commit-identity-check.sh`](../scripts/commit-identity-check.sh): rejects commits a change adds
    under a test identity, such as the one tests commit as (L-41).
  - [`docs-map-check.py`](../scripts/docs-map-check.py): this page's rule, above.

## Skills

- [`devshop-version`](../runtime/skills/devshop-version/SKILL.md): which devshop version a session
  runs and how old its local copy is.

## The install

- [install/README.md](../install/README.md): how a project's cloud session gets the devshop version
  it pins (`.devshop-version`), what each `DEVSHOP:` line means, and the limits. Proven by
  [`tests/bootstrap.test.sh`](../tests/bootstrap.test.sh).

## The revamp (being built)

- [kit/notes/revamp/README.md](../kit/notes/revamp/README.md): start here. It links the plan,
  target picture, decisions, findings, lessons, process and log.
- Spikes, kept as notes (records of what was run, not live code):
  - A-04 reviewer stability: the fixed inputs, an [honest](../kit/notes/revamp/spikes/a04-reviewer/honest/spec.md)
    and a [seeded](../kit/notes/revamp/spikes/a04-reviewer/seeded/spec.md) spec.
  - W10.1.2 install probe: [README](../kit/notes/revamp/spikes/w10-1-2-install/README.md) and its
    [probe skill](../kit/notes/revamp/spikes/w10-1-2-install/plugin/skills/devshop-probe/SKILL.md).
  - W10.1.2b thin install: [README](../kit/notes/revamp/spikes/w10-1-2b-thin/README.md) and its
    [probe skill](../kit/notes/revamp/spikes/w10-1-2b-thin/runtime/skills/devshop-probe2/SKILL.md).
