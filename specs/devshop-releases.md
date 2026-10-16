# Devshop releases: projects pin a release tag, not a commit SHA

**Go:** "sounds good", after the spec added the title check in ship.sh and the newer-release note, with the squash commit title set to the PR title (owner, 2026-10-16). Second change, a release button instead of a release PR: "yes" (owner, 2026-10-16)

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

After the first change merged (PR 128), before any release was cut (2026-10-16):

> Do we really need a PR? I have done this in the past where we release the job, we do the release
> from action. And if I remember correctly there's no PR involved.

## Decisions

- **Conventional Commit prefixes on the subjects that land on `main`:**
  `<type>[(<scope>)][!]: <subject>`, with type one of `feat`, `fix`, `perf`, `revert`, `docs`,
  `test`, `ci`, `build`, `refactor`, `style`, `chore`. The subject still describes the observable
  change, and the title stays ≤ 72 characters (CLAUDE.md), not counting the ` (#n)` GitHub appends.
  The owner chose prefixes over a release PR where the owner picks the bump (owner, 2026-10-16)
- **The subject on `main` is the PR's title:** this repo squash-merges only. Its squash title
  setting was "commit or PR title" (read 2026-10-16), under which a one-commit PR lands with its
  commit's subject; the owner set it to "Pull request title" (message: blank) the same day. The
  push-to-`main` title check below goes red if that's ever undone
- **The bump comes from the first-parent subjects on `main` since the last `vX.Y.Z` tag at or above
  `v2.0.0`:** a `!` before the colon is major ("this upgrade needs a migration", TARGET Shape 5);
  else any `feat` is minor; else any `fix`, `perf` or `revert` is a patch; else there is nothing to
  release. Breaking is marked by `!` only, not a `BREAKING CHANGE:` footer, because a squash commit's
  body can hold the branch's commit messages (the setting's other options). Subjects without a known prefix bump nothing and are
  listed under "Other changes"
- **The first release is `v2.0.0`,** whatever the subjects say; its notes cover `main`'s first-parent
  subjects since `v1-final` (84 today). `v1.*` tags and `v1-final` never count as releases here
- **A release is a button, not a PR** (owner, 2026-10-16, replacing the release PR of the first
  change): the owner clicks "Run workflow" on `.github/workflows/release.yml` (`workflow_dispatch`).
  It computes the next version and notes from `main` and creates the tag and the GitHub release; no
  PR, no commit, no `VERSION` or `CHANGELOG.md` file (the notes live on the release page). Rejected:
  release-please (a PR it opens with the workflow's `GITHUB_TOKEN` starts no CI, so it could never
  pass the required checks without a second credential) and the first change's release PR (a PR,
  two CI tiers and a review round for a version number, and a failure mode when `main` moved after
  it was prepared)
- **Only the owner can release:** the workflow's first step fails the run unless the run is on
  `main` and both the actor who started it and the one who re-ran it (`github.actor`,
  `github.triggering_actor`) are the repository's owner (`github.repository_owner`), read through
  `env:`. The agent identity has write access and could start the workflow through the API; this
  stops it. The guard sits in a file on `main`, which changes only by a reviewed PR, so it holds
  (a wall, with branch protection)
- **CI creates the tag and the GitHub release** (A-25: a session's git proxy refuses tag pushes):
  the workflow runs with `contents: write`, one run at a time, on a full clone with tags;
  `scripts/release.py plan --notes-file <path>` prints the tag and `main`'s head SHA and writes the
  notes, or exits 1 when nothing since the last release bumps the version (the run goes red, saying
  so); then `gh release create` makes the tag on that SHA and the release. The script refuses a
  shallow clone or one without tags, since either silently shortens the history. The published
  release's tag is locked by the owner's release immutability setting (F-NEW-95)
- **The title is checked wherever it is set:** in CI's `fast` job (already a required check),
  `scripts/pr-title-check.py` reads the PR's title on a pull request and the head commit's subject
  on a push to `main`, both through `env:`, never interpolated into the script. And `ship.sh`, the
  one way a session sets or edits a PR's title and body (the reviewer re-runs on such an edit), runs
  the repo's own `scripts/pr-title-check.py` on the title when the repo has one, before the review;
  a failing title stops `ship.sh` like a malformed body. A title check that exists but can't run
  (not executable) stops `ship.sh` as could-not-run, never lets the title through (owner,
  2026-10-16, after the go, when the reviewer found the guard outside the spec). Projects have no such script, so nothing
  changes for them. CI keeps today's pull request triggers (adding `edited` would re-run both tiers
  on every body edit); a title edited by hand on GitHub after the last push is caught by the check
  on `main` after the merge (owner, 2026-10-16: keep the check where body and title edits are
  checked)
- **Projects pin a release tag:** `.devshop-version` holds e.g. `v2.0.0`; a commit SHA stays valid
  for testing a branch (TARGET Shape 5). The dispatcher already resolves either in the local copy,
  whose bare clone carries tags (git prefers a tag over a branch of the same name); its wording,
  and that of `project-files-at.sh` and `project-files.py`, says "a release tag or commit SHA", and
  messages show a tag in full (a SHA still as 12 characters). The `upgrade` skill's default NEW
  becomes the newest `vX.Y.Z` tag in the local copy by version order (`main` only when there is
  none, or when the owner names it), and it writes NEW as named. It shows what changed as the
  commits between OLD and NEW, which the local copy holds offline. A release made after the
  environment's cache was built isn't in the copy until it rebuilds, as for SHAs today
- **A newer release shows in the `DEVSHOP:` line:** when the project pins a `vX.Y.Z` tag and the
  local copy holds a higher one, the line adds "newer release v<newest> in the copy
  (/devshop:upgrade)". Feedback only; a SHA pin or no pin adds nothing (owner, 2026-10-16: "if
  trivial")
- **This repo's CLAUDE.md** gains the prefix rule on its commit-subject line. Projects don't release,
  so their titles and the `pr` skill are untouched

## Acceptance items

- **AC-1** `scripts/pr-title-check.py` exits 0 for a title in the agreed form (each type, with and
  without a scope, with `!`, a 72-character title followed by ` (#123)`) and 1 with a reason for: no
  prefix, an unknown type, an upper-case type, no space after the colon, an empty subject, and a
  title over 72 characters before the ` (#n)`; it exits 2 when given no title
- **AC-2** CI's `fast` job runs the title check on the pull request's title, and on a push on the
  head commit's subject, passed through `env:`, as a step without `if:` or `continue-on-error`
- **AC-3** `scripts/release.py next` prints the next version and its notes from a repo's tags and
  first-parent subjects: `v2.0.0` when no v2 tag exists; major for a `!`; minor for a `feat`; patch
  for `fix`, `perf` or `revert`; it exits 1 with "nothing to release" when only other types or
  unprefixed subjects follow the last tag. It ignores `v1.*` and `v1-final`, compares versions
  numerically (`v2.10.0` is above `v2.9.0`), and exits 2 in a shallow clone or when neither a v2 tag
  nor `v1-final` is present
- **AC-4** The notes group subjects under "Breaking changes", "Features", "Fixes" and "Other changes"
  (unprefixed and non-bumping types), in history order, each without its prefix; an empty group is
  left out
- **AC-5** `scripts/release.py plan --notes-file <path>` prints `tag=v<version>` and
  `sha=<HEAD's full SHA>` and writes the notes when there is something to release, and exits 1 with
  "nothing to release", writing nothing, when there isn't (`main`'s head already released included);
  it exits 2 when the computed tag already exists on a commit `main` doesn't reach
- **AC-6** `scripts/release.py` has no other command: no `prepare`, no `tag-plan`, and it writes no
  `VERSION` or `CHANGELOG.md`
- **AC-7** `.github/workflows/release.yml` runs only on `workflow_dispatch`, with `contents: write`
  and a `concurrency` group; its first step fails unless the ref is `refs/heads/main` and the actor
  and triggering actor are the repository owner, all read through `env:`; it checks out with
  `fetch-depth: 0`, runs `plan`, then `gh release create` with the planned tag, `--target` the
  planned SHA and the notes file (checked by a test that parses the workflow and runs its steps'
  commands against a scratch repo with a fake `gh`, the guard with an owner, another actor, a
  re-run by another actor and another branch)
- **AC-8** In the install test that replays the setup script, a project whose `.devshop-version`
  holds a release tag gets the line `DEVSHOP: using <tag> (<sha12>) from project .devshop-version`
  and that tag's runtime; a tag missing from the copy gets the "not in the local devshop copy" line
- **AC-9** The `upgrade` skill's step 1 picks the newest `vX.Y.Z` tag in the local copy as NEW unless
  the owner names a version, and step 3 writes NEW as named to `.devshop-version`; the wrapper
  (`project-files-at.sh`) and the drift check in `session-start.sh` accept a tag as the version
- **AC-10** CLAUDE.md, `docs/README.md`, `install/README.md`, D-10 and A-25's rows say how a release
  is cut (the button) and pinned now — verified by review: the diff of those files
- **AC-11** `ship.sh` stops before the review, with the check's reason and nothing pushed, when the
  repo has an executable `scripts/pr-title-check.py` that fails the title; it goes on when that
  check passes or the repo has none; it stops as could-not-run (exit 2, nothing pushed) when the
  repo's `scripts/pr-title-check.py` exists but isn't executable (owner, 2026-10-16, after the go)
- **AC-12** In the same install test, a project pinning a release tag while the copy holds a higher
  `vX.Y.Z` tag gets "newer release v<newest> in the copy (/devshop:upgrade)" on its `DEVSHOP:` line;
  pinning the newest tag, a SHA, or no pin adds nothing

## Out of scope

- Cutting `v2.0.0` itself: after this merges, the owner clicks "Run workflow". That run is the live
  check of A-25 (the tag and release appear) and, with the owner's try at moving `v2.0.0`, of
  F-NEW-95; recorded on R-11 and A-25 then. R-11 is `Done` only after it
- A wall on tags beyond release immutability: F-NEW-95
- Release-please, a GitHub App or a second token; v1's `release.sh` and its skill (v1 is frozen)
- Conventional Commit prefixes in projects, and checks on the commit subjects inside a PR's branch
  (only the title lands, once the squash setting is changed)
- Pre-release tags (`v2.1.0-rc.1`)
