# The project's own checks find the devshop's pinned tools

**Go:** "go", after "agreed!" to linking the tools into /usr/local/bin at bootstrap (owner, 2026-10-14)

## Intent

Seen 2026-10-14 (LOG #65): in the owner's fresh fixture session, the first
`scripts/check-fast.sh origin/main` failed 2 of 9 script test files with `FAIL: gitleaks not found
(set $GITLEAKS or put it on PATH)`. The bootstrap installs the pinned gitleaks, shellcheck and dcg
(`install/tools.pin`, the versions and checksums CI pins) into `/opt/devshop-tools/bin`, but only
the devshop's own hooks use that path. The project's checks look on PATH, which doesn't include it.
The session downloaded gitleaks by hand to get past it. Every project session hits this, and a
session that skips the workaround reports red checks that CI would pass, or skips them. The owner
wants the project's commands to find the pinned tools with no manual download, and a missing tool to
still fail loudly, never pass.

## Decisions

- Root cause: the tools are installed off PATH, so every caller has to know their directory. The
  devshop's own callers each work around it (`runtime/git-hooks/pre-push` and
  `runtime/hooks/post-edit.sh` prepend it to PATH, `runtime/hooks/pre-bash.sh` calls dcg by its
  absolute path); anything else misses the tools, this repo's `scripts/lint.sh` run by hand included.
  The fix is where they are installed: after the bootstrap links a verified tool into
  `/opt/devshop-tools/bin`, it also links `/usr/local/bin/<name>` to `/opt/devshop-tools/bin/<name>`.
  `/usr/local/bin` is on the default PATH of every process, and the cloud image already links its
  own tools there (owner, 2026-10-14). Rejected: a SessionStart step writing PATH to
  `$CLAUDE_ENV_FILE` (a second mechanism on top of the wrong location, only for commands Claude
  starts, depending on a Claude Code feature; owner, 2026-10-14)
- A missing tool stays missing: every `install/tools.pin` name gets its `/usr/local/bin` link, which
  points at `/opt/devshop-tools/bin/<name>`; a tool that didn't install leaves that link resolving to
  nothing, so the project's check reports it as not found. The bootstrap also drops a tool's
  `/opt/devshop-tools/bin/<name>` before installing it, so a failed install of a new version can't
  leave the old one running (today it can). The bootstrap logs `FAILED: tool …` and ends
  `RESULT: bootstrap FAILED` as today; `install/README.md` says a tool that isn't found means
  checking `/tmp/devshop-setup.log`. No new `DEVSHOP:` line
- The bootstrap never replaces what it didn't make: an existing `/usr/local/bin/<name>` that isn't
  exactly a symlink whose target is `/opt/devshop-tools/bin/<name>` (a file, a directory, or a link
  elsewhere, dangling or not) is left as it is and logged as `FAILED: tool <name>: …`
  (the pinned copy is then not the one on PATH; required CI still is). Its own link is replaced, so
  a re-run works
- All three tools are linked, dcg included: the set is exactly `install/tools.pin`, this repo's
  `tests/pre-bash.test.sh` looks for dcg on PATH, and the guard calls dcg by its absolute path, so
  PATH changes nothing for it
- The hooks' own PATH prepends stay: redundant now, harmless, and out of this change's files
- The proof lives in `tests/bootstrap.test.sh`, which already replays the install in a private mount
  namespace: it mounts a tmpfs on `/usr/local/bin` that mirrors the real one as links into a
  read-only bind of it, minus the pinned tools' names, so the real one is never touched, and fails
  with a clear message if either mount can't be made, never skips. Each fresh-VM setup in the test
  rebuilds that mirror. Changed after the go from an overlay, which needs overlay support in a user
  namespace on CI's runner: "Tmpfs mirror" (owner, 2026-10-14)
- `install/README.md` also says a copy of a tool in a directory ahead of `/usr/local/bin` on PATH
  (`~/.local/bin`, `~/.cargo/bin`, node's or bun's bin) would win over the pinned one

- The fresh fixture session after the environment's rebuild (`gitleaks version` prints 8.30.1,
  `shellcheck --version` 0.11.0, and the fixture's `scripts/check-fast.sh origin/main` passes with
  no manual download) can only run after the merge, so it is W10.4.9's done-when, recorded in the
  LOG, not an acceptance item of this PR. Changed after the go: "Move to task done-when" (owner,
  2026-10-14)

## Acceptance items

- **AC-1** After the bootstrap installs the pinned tools, `gitleaks`, `shellcheck` and `dcg` run
  the pinned binaries (their own version output, not another copy's) from a shell whose PATH is
  `/usr/local/bin:/usr/bin:/bin`, shown by `tests/bootstrap.test.sh`
- **AC-2** On a fresh install where gitleaks's download fails its checksum, `gitleaks` doesn't run
  from that shell ("not found", non-zero exit) and the setup log has its `FAILED: tool` line, shown
  by `tests/bootstrap.test.sh`
- **AC-3** When a bootstrap moves gitleaks to a new version whose download fails, over an install
  of the old version, `gitleaks` doesn't run from that shell either, shown by
  `tests/bootstrap.test.sh`
- **AC-4** An existing `/usr/local/bin/<name>` the devshop didn't make (a file, and a link
  elsewhere) is left unchanged and logged as a `FAILED: tool` line, shown by
  `tests/bootstrap.test.sh`
- **AC-5** Running the bootstrap a second time over a good install leaves the links in place and
  logs no failure for them, shown by `tests/bootstrap.test.sh`
- **AC-6** `install/README.md` § Pinned tools says the tools are on PATH via `/usr/local/bin`, what
  a missing tool looks like and where to look, and what wins over them on PATH; and
  `kit/notes/revamp/workstreams/W10-v2.md` has task W10.4.9 — verified by review: the diff

## Out of scope

- Removing the hooks' own PATH prepends
- Removing or detecting a copy of a tool earlier on PATH than `/usr/local/bin` (none on the image
  today; the README names the risk)
- CI, which installs the pinned tools itself
- Tools beyond `install/tools.pin`, and the owner's local devcontainer
