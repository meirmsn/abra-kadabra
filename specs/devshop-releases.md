# Devshop releases: projects pin a release tag, not a commit SHA

**Go:** pending

## Intent

v1 had a way to cut a devshop version (`/ak-release-devshop` and `kit/scripts/release.sh`, which
tagged from the agent's session). v2 has none: a project pins the devshop with a bare commit SHA in
`.devshop-version`. D-10 decided SemVer releases from `v2.0.0` on 2026-10-12 (a release PR, the
owner merges it, CI creates the tag; A-25), and REVIEW-2 deferred it because SHA pins work. The
owner's words (2026-10-16):

> on devshop v1 we had a way to cut a new devshop version, what is the equivalent or related notions
> in devshop v2? i think u saw something about pinning devshop in the repos which i think it
> currently done with commit hashes? i think we should move to releases

> use conventional commit prefixes, put it on roadmap, and implement (and test as much as you can
> reasonable can to make sure it will work)

## Decisions

- **Conventional Commit prefixes on PR titles, which become the squash commit subjects on `main`:**
  `<type>[(<scope>)][!]: <subject>`, with type one of `feat`, `fix`, `perf`, `revert`, `docs`,
  `test`, `ci`, `build`, `refactor`, `style`, `chore`. The subject still describes the observable
  change, and the whole title stays ≤ 72 characters (CLAUDE.md). The owner chose prefixes over a
  release PR where the owner picks the bump (owner, 2026-10-16)
- **The bump comes from the subjects since the last `v2.*` tag (first parent of `main`):** a `!`
  before the colon is major ("this upgrade needs a migration", TARGET Shape 5); else any `feat` is
  minor; else any `fix`, `perf` or `revert` is a patch; else there is nothing to release. Breaking is
  marked by `!` only, not a `BREAKING CHANGE:` footer, because a squash commit's body holds the PR's
  body, which can quote that text. Subjects without a prefix (every commit before this change) bump
  nothing and are listed under "Other changes"
- **The first release is `v2.0.0`,** whatever the subjects say; its notes list every `main` subject
  since `v1-final` (D-10)
- **Releases are cut by a tested script and a release PR, not by release-please:** D-10 named
  release-please, but a PR it opens with the workflow's `GITHUB_TOKEN` starts no CI run (GitHub
  doesn't trigger workflows from that token's events), so its PR could never pass the required
  `fast` and `slow` checks, and making it work needs a second token or app in the repo. Instead
  `scripts/release.py prepare` (run in a session, on the owner's ask) writes the next version to
  `VERSION` and its notes to the top of `CHANGELOG.md`; the session opens that as a normal PR titled
  `chore(release): v<version>`, which runs CI like any other and which the owner approves and
  merges. Same shape D-10 decided (release PR, owner merges, CI tags), one moving part fewer.
  Recorded here as Claude's proposal for the owner's go
- **CI creates the tag and the GitHub release on the merge** (A-25: a session's git proxy refuses
  tag pushes): `.github/workflows/release.yml` runs on every push to `main`; `scripts/release.py
tag-plan` prints the tag to create only when that push changed `VERSION`, its version is higher
  than every `v2.*` tag and no such tag exists; then `gh release create` makes the tag on that
  commit and the release, with the version's `CHANGELOG.md` section as notes. It needs
  `contents: write`; every other push does nothing. The workflow is not a required check
- **The PR title check runs in the `fast` job** (a required check, so no new required check to
  add): `scripts/pr-title-check.py` checks the PR's title on a pull request and the head commit's
  subject on a push to `main`. CI keeps today's pull request triggers, so a title edited after the
  last push isn't re-checked until the next push (a mitigation: the release notes list any subject
  that slipped through under "Other changes", and the owner sees them in the release PR)
- **Projects pin a release tag:** `.devshop-version` holds e.g. `v2.0.0`; a commit SHA stays valid
  for testing a branch (TARGET Shape 5). The SessionStart dispatcher already resolves either in the
  local copy, whose bare clone carries tags; its wording says "a release tag or commit SHA". The
  `upgrade` skill's default NEW becomes the newest `v2.*` tag in the local copy (`main` only when
  there is none, or when the owner names it), and it writes the tag, not its SHA
- **This repo's CLAUDE.md** gains the prefix rule on the existing commit-subject line, and `pr`
  stays as it is for projects: projects don't release, so their titles are untouched

## Acceptance items

- **AC-1** `scripts/pr-title-check.py` exits 0 for a title in the agreed form (each type, with and
  without a scope, with `!`, with a `(#123)` suffix) and 1 with a reason for: no prefix, an unknown
  type, an upper-case type, no space after the colon, an empty subject, and a title over 72
  characters; it exits 2 when given no title
- **AC-2** CI's `fast` job runs the PR title check on the pull request's title, and on a push to
  `main` on the head commit's subject, as a step without `if:` or `continue-on-error`
- **AC-3** `scripts/release.py next` computes, from a repo's tags and `main`'s first-parent
  subjects: `v2.0.0` when no `v2.*` tag exists; major for a `!`; minor for a `feat`; patch for
  `fix`, `perf` or `revert`; "nothing to release" (exit 1) when only other types or unprefixed
  subjects follow the last tag. It ignores `v1.*` and `v1-final` tags and compares versions
  numerically (`v2.10.0` is above `v2.9.0`)
- **AC-4** The notes `next` prints group subjects under "Breaking changes", "Features", "Fixes" and
  "Other changes" (unprefixed and non-bumping types), each subject once, without its prefix
- **AC-5** `scripts/release.py prepare` writes the version to `VERSION` and puts its notes under a
  `## v<version> (<date>)` heading at the top of `CHANGELOG.md` (creating it if missing, keeping
  earlier sections), and refuses (exit 1, nothing written) when there is nothing to release or the
  working tree has uncommitted changes
- **AC-6** `scripts/release.py tag-plan <before-sha>` prints the tag and writes its notes file only
  when `VERSION` changed between `<before-sha>` and `HEAD`, its version is above every `v2.*` tag
  and the tag doesn't exist; otherwise it prints nothing and exits 0. It exits 2 on a `VERSION` that
  isn't `X.Y.Z`, a version not above the latest tag, or a version with no `CHANGELOG.md` section
- **AC-7** `.github/workflows/release.yml` runs on push to `main`, has `contents: write`, calls
  `tag-plan` with the push's `before` SHA, and runs `gh release create` with the planned tag,
  `--target` the pushed SHA and the notes file only when a tag was planned
- **AC-8** In the install test that replays the setup script, a project whose `.devshop-version`
  holds a release tag gets the line `DEVSHOP: using <tag> (<sha12>) from project .devshop-version`
  and that tag's runtime; a tag missing from the copy gets the "not in the local devshop copy" line
- **AC-9** The `upgrade` skill's step 1 picks the newest `v2.*` tag in the local copy as NEW unless
  the owner names a version, and step 3 writes NEW as given (the tag) to `.devshop-version`; the
  wrapper (`project-files-at.sh`) and the drift check in `session-start.sh` accept a tag as the
  version
- **AC-10** CLAUDE.md, `install/README.md`, D-10 and A-25's rows say how a release is cut and pinned
  now — verified by review: the diff of those files

## Out of scope

- Cutting `v2.0.0` itself: after this merges, a separate release PR made with `release.py prepare`,
  which the owner merges. Its merge is the live check of A-25 and AC-7 (the tag and release appear),
  recorded on R-11 and A-25 then; R-11 is `Done` only after it
- A wall on tags (a ruleset so only CI can create, move or delete `v2.*` tags): logged as a finding
- A `DEVSHOP:` line saying a newer release exists than the one pinned
- Release-please, a GitHub App or a second token; v1's `release.sh` and its skill (v1 is frozen)
- Conventional Commit prefixes in projects, and checks on commit subjects inside a PR's branch (the
  squash merge keeps only the title)
