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

## The revamp (being built)

- [kit/notes/revamp/README.md](../kit/notes/revamp/README.md): start here. It links the plan,
  target picture, decisions, findings, lessons, process and log.
