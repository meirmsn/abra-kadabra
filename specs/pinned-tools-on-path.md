# The project's own checks find the devshop's pinned tools

**Go:** pending

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

- The plugin's SessionStart dispatcher (`install/plugin/devshop/hooks/dispatch.sh`) puts
  `/opt/devshop-tools/bin` at the front of PATH for the session's commands by appending one line to
  `$CLAUDE_ENV_FILE`, which Claude Code sources for the session's Bash commands. Proven by experiment
  on 2026-10-14 (Claude Code 2.1.299, nested `claude -p` in a cloud session; recorded in the LOG
  entry): a SessionStart hook from `--settings` and one from a `--plugin-dir` plugin each got
  `CLAUDE_ENV_FILE`, appended `export PATH="<dir>:$PATH"`, and a Bash command in that session then
  resolved a probe binary from `<dir>`. The tests below simulate the sourcing; only AC-6 shows Claude
  Code doing it on the owner's surface
- The dispatcher, not a version's `runtime/hooks/session-start.sh`, and outside its version
  selection: the tools are installed per environment, not per pinned version, so a project pinned to
  a version from before this change (the fixture), or to a pin that doesn't resolve, gets them with
  no upgrade
- Rejected: symlinks into a directory already on the image's PATH (`/usr/local/bin`, or
  `~/.local/bin`, which is on the cloud image's PATH ahead of `/usr/local/bin`). They would reach
  every process, not just Claude's, and wouldn't need `CLAUDE_ENV_FILE`, but they rest on the image
  keeping that directory on PATH (observed, not promised) and share it with other installers.
  Rejected: an `env` setting, which can't extend `$PATH` (its value is taken literally)
- The env-file line is single-quoted when written, so `$PATH` expands when Claude Code sources it,
  not when the hook runs, and it prepends the directory unless PATH already starts with it:
  `case ":$PATH" in :/opt/devshop-tools/bin:*) ;; *) PATH="/opt/devshop-tools/bin:$PATH" ;; esac; export PATH`.
  Sourcing it any number of times leaves the directory first, once. Prepended, not appended: the
  pinned versions win over any other copy on the image's PATH, so a session runs what CI runs
- All three tools in `/opt/devshop-tools/bin` are exposed, dcg included: the directory is exactly the
  pinned set, this repo's `tests/pre-bash.test.sh` looks for dcg on PATH, and the guard calls dcg by
  its absolute path anyway. Rejected: a second directory with only gitleaks and shellcheck
- A missing tool stays missing: nothing usable is linked for a failed download, so the project's
  check reports it as not found. The dispatcher also prints one `DEVSHOP:` line naming each tool of
  `install/tools.pin` (read from the local copy at the environment's default ref, the same file the
  bootstrap installed from) that isn't an executable at `/opt/devshop-tools/bin/<name>` (`-x`, so a
  dangling link from a failed re-install counts as missing), pointing at `/tmp/devshop-setup.log`.
  dcg is left out of that line when the existing dcg line in `runtime/hooks/session-start.sh`
  already reports it
- Without `$CLAUDE_ENV_FILE` the dispatcher prints a `DEVSHOP:` line saying the pinned tools aren't
  on PATH this session. Feedback, not a wall: required CI installs the same pinned versions itself
- When the bootstrap primes the version (`DEVSHOP_PRIME_ONLY=1`, before the tools are installed and
  without `CLAUDE_ENV_FILE`), the dispatcher skips both the env-file line and the tools check
- The devshop's own hooks and git hooks keep calling the tools by `/opt/devshop-tools/bin`; hook
  processes don't source the env file, and git hooks started from a Bash command inherit the new
  PATH, which changes nothing for them
- The proof lives in `tests/bootstrap.test.sh`, which already replays the install and runs the
  installed dispatcher in a scratch `/opt` and `/tmp`

## Acceptance items

- **AC-1** In `tests/bootstrap.test.sh`, after the installed plugin's SessionStart hook runs with
  `CLAUDE_ENV_FILE` set and all pinned tools installed, a shell that sources that file resolves
  `gitleaks`, `shellcheck` and `dcg` to `/opt/devshop-tools/bin`, ahead of a same-named decoy earlier
  on the shell's original PATH
- **AC-2** The same holds when the project pins the pre-move commit the test already uses
  (`6190c0e0`, older than this change) and when its pin is not in the local copy
- **AC-3** When a pinned tool failed to install (a bad checksum on a fresh install, and a failed
  re-install that leaves a dangling link), the hook prints a `DEVSHOP:` line naming it, and a shell
  that sources the env file over a PATH of only system directories with no copy of it fails to run
  it with "not found" (non-zero exit)
- **AC-4** Without `CLAUDE_ENV_FILE` the hook prints a `DEVSHOP:` line saying the pinned tools are
  not on PATH, and its other lines are unchanged
- **AC-5** Sourcing the env file twice, and running the hook twice with the same env file, leaves
  `/opt/devshop-tools/bin` first on PATH and on it once
- **AC-6** The bootstrap's priming run logs no missing-tool or not-on-PATH line
- **AC-7** In a fresh fixture session after an environment rebuild, `gitleaks version` prints 8.30.1
  and `shellcheck --version` prints 0.11.0 from the project's shell, and the fixture's fast check
  (`scripts/check-fast.sh origin/main`) passes with no manual download — verified by review: the
  owner's fresh fixture session
- **AC-8** `install/README.md` § Pinned tools says the session's commands get the tools on PATH and
  what a missing tool looks like, and `kit/notes/revamp/workstreams/W10-v2.md` has the task line —
  verified by review: the diff

## Out of scope

- PATH for processes Claude Code doesn't start (no system-wide change)
- Another SessionStart hook's env file resetting PATH after ours (order between hooks' env files is
  Claude Code's)
- CI, which installs the pinned tools itself
- The dcg guard (`runtime/hooks/pre-bash.sh`) and the existing dcg `DEVSHOP:` line
- Tools beyond `install/tools.pin`, and the owner's local devcontainer
