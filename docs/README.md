# Docs map

Every doc in this repo is linked from here, in a hierarchy (TARGET § Build 3). A new doc gets
a line here in the same change, and a removed one loses its line. A CI check for this (every doc
linked, no broken links) comes with W10.4.2.

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

## The install

- [install/README.md](../install/README.md): how a project's cloud session gets the devshop version
  it pins (`.devshop-version`), what each `DEVSHOP:` line means, and the limits. Proven by
  [`tests/bootstrap.test.sh`](../tests/bootstrap.test.sh).

## What projects get (`runtime/`)

- PR body: [`runtime/templates/pr-body.md`](../runtime/templates/pr-body.md) is the template for
  every project PR (TARGET § L3 Review): one-line summary, preview link, announcement (only when
  user-facing), what you should know, evidence, then engineering details collapsed.
  [`runtime/scripts/pr-body-check.py`](../runtime/scripts/pr-body-check.py) checks a filled-in
  body has that shape (sections and lines in order, preview present, no placeholder left,
  evidence pinned to a commit); whether the words are true is the reviewer's job. Proven by
  [`tests/pr-body-check.test.sh`](../tests/pr-body-check.test.sh).

## The revamp (being built)

- [kit/notes/revamp/README.md](../kit/notes/revamp/README.md): start here. It links the plan,
  target picture, decisions, findings, lessons, process and log.
