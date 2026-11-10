# Pinned tools survive a release-host outage

**Go:** "go" (owner, 2026-11-10)

## Intent

R-21 (F-NEW-158, F-NEW-159). The owner (2026-11-10), on the findings: "just start 1, 2, or 3
sessions that you need to fix those three"; the task names the candidates: the pinned,
checksum-verified binaries cached so an outage of the release host doesn't break setup; a sanctioned
repair command that only re-runs the pinned, checksum-verified installer and that the session may
run; and, when setup still fails, a session-start line that says plainly the session can't push and
what to do, with a degraded path to open the PR considered.

What the code shows: the bootstrap runs once, when the environment cache is built (about weekly;
`install/README.md`), not per session. A 504 from the release host at that moment leaves the tool
missing in every session on that cache until the next rebuild, which is how one project saw
`gitleaks` missing in five sessions at once. The devshop session writing this spec started on a
cache built on 2026-11-09 without `shellcheck` (a 504 in `/tmp/devshop-setup.log`); the same URL
answered 200 three times out of three a day later, and the session's hand install of the pinned,
checksum-verified `shellcheck` was allowed by the permission classifier without a prompt (one data
point, the opposite of the earlier sessions). So the cause this change fixes: a build-time failure
is frozen into a week of sessions, and nothing after the build tries again. The retry merged in PR
#189 (4 tries at build time) is a mitigation of the same cause. A lasting outage of the release
host is not fixed here unless the owner picks the mirror below.

Feedback, like every hook: the repair and the line tell and fix, they guard nothing. A session runs
as root and can write `/opt`, so anything it runs, the repair included, can be changed by it. The
walls (CI's secret scan and lint, `main`'s protection, the owner's approval) are unchanged.

## Decisions

- **Repair at session start, from the same pinned source:** the plugin's dispatcher
  (`install/plugin/devshop/hooks/dispatch.sh`, installed from the bootstrap's ref, `main` by
  default, so it reaches every project whatever version it pins) checks each tool in the
  `install/tools.pin` of the local copy at its default ref (`/opt/devshop-plugin/versions/default-ref`).
  A tool is missing when `/opt/devshop-tools/bin/<name>` isn't an executable file (a dangling or
  absent link included). The missing ones, and only those, are installed by the bootstrap's own tool
  step: the pinned URL and sha256, the same unpack and links. The repair writes only this session's
  container; the cache stays as built. It reaches an environment at its next cache rebuild, and helps
  every session on a cache whose build hit a failed download after that (Claude, 2026-11-10; for the
  owner's go)
- **Not during priming:** the bootstrap runs the dispatcher with `DEVSHOP_PRIME_ONLY=1` before its
  tool step; the repair is skipped then, so a cache build downloads each tool once (review, 2026-11-10)
- **Order at session start:** the repair runs first, then the main `DEVSHOP:` line is built, then
  the version's `session-start.sh` runs, so a `dcg` repaired at start gets no "dcg is not
  installed" line (review, 2026-11-10)
- **One installer, `install/plugin/devshop/tools.sh <build|repair> <tools.pin> <tools dir> <PATH dir> <log>`:**
  the tool step, `fetch_tool`'s retry (PR #189) with it, leaves `install/bootstrap.sh` for the
  plugin folder, which makes it the one place `tools.pin` is parsed; it is on disk wherever the
  plugin is, with explicit arguments and a test of each mode. `build` is today's step: every tool,
  4 tries with backoff, the old link removed first. `repair`: only the missing tools, each download
  `curl --connect-timeout 10` with at most 2 tries, all of it within one overall limit of 60 s, after
  which the tools not yet done count as still missing. It sets `PATH=/usr/bin:/bin` and ignores
  `DEVSHOP_*` overrides in `repair` mode. It takes a lock on `<tools dir>/.lock` (`flock`), so a
  hand-run repair and a session-start one in the same container don't write the same paths; a second
  run waits within its limit (review, 2026-11-10)
- **The SessionStart hook gets an explicit timeout in `hooks.json`,** large enough for the repair's
  60 s plus the version's script (whose project setup may take up to 600 s): 720 s. Claude Code's
  default for a hook with none is not relied on (review, 2026-11-10)
- **The repair logs to its own file, `/tmp/devshop-tools-repair.log`:** the bootstrap's clause
  (specs/bootstrap-result-at-session-start.md) keeps reading `/tmp/devshop-setup.log` unchanged, the
  record of the build (Claude, 2026-11-10)
- **The main `DEVSHOP:` line says the outcome, after the bootstrap clause:**
  - `; repaired at session start: <tools>` when the repair installed them;
  - `; still missing: <tool> (<cost>), …: run /opt/devshop-plugin/devshop/hooks/repair-tools.sh, or start a new session once the release host answers`
    when it didn't, each tool once, in `tools.pin` order. The costs: `dcg` "every Bash command is
    blocked, so this session can't push or open a PR: don't push through the GitHub API", `gitleaks`
    "this session can't push", any other tool "the checks that use it fail, which can stop a push";
  - `; couldn't read the pinned tools (<why>)` when the default ref, its `tools.pin` or a line of it
    can't be read: no download then;
  - nothing when no tool is missing. A tool installed whose `/usr/local/bin` link is taken by
    something the devshop didn't make counts as repaired; the build's existing FAILED step for that
    is unchanged (Claude, 2026-11-10)
- **A sanctioned repair command, `/opt/devshop-plugin/devshop/hooks/repair-tools.sh`, no
  arguments:** the session-start repair, run by hand mid-session (for an outage still on at session
  start). It runs `tools.sh repair` on the local copy's pin and exits 0 when no tool is missing
  afterwards, 1 otherwise. Two things stand between a session and running it:
  - _the Bash guard:_ without `dcg`, the version's `pre-bash.sh` blocks every command, this one
    included. The plugin's Bash hook becomes a tested plugin script, `hooks/bash-gate.sh`, still the
    first PreToolUse hook. It allows the command only when `jq -e '.tool_input.command ==
"/opt/devshop-plugin/devshop/hooks/repair-tools.sh"'` holds (byte-exact, inside jq, so no
    whitespace or newline is trimmed) and hands every other input to the version's `pre-bash.sh`
    as today; without `jq`, or on input jq can't parse, everything goes to `pre-bash.sh` (Claude,
    2026-11-10)
  - _the permission classifier:_ the bootstrap adds
    `Bash(/opt/devshop-plugin/devshop/hooks/repair-tools.sh)` to `permissions.allow` in
    `~/.claude/settings.json` (whether or not the image has Chromium), keeping what is there.
    Whether auto mode honours it, and whether the platform keeps that file into sessions, is
    untested: a new row in `kit/notes/revamp/ASSUMPTIONS.md`, and the experiment runs at the start
    of the build. If it doesn't hold, the command stays and the owner approves one fixed, named
    command per session (Claude, 2026-11-10)
- **Environment settings are not touched:** no setup-script or image change (the owner's, through
  the environment tools' approval prompts) (task, 2026-11-10)
- **Open, for the owner:** a mirror ("cached"), and the degraded PR path; see the questions at the
  go. Until answered, this spec has neither. Proposed: no mirror now; a lasting outage seen later
  is logged as a finding and brings the mirror back as a candidate (Claude, 2026-11-10)

## Acceptance items

- **AC-1** With a tool from `tools.pin` missing from `/opt/devshop-tools/bin` and its pinned
  download served, the dispatcher installs it at session start, checked against the pinned sha256
  and linked as the bootstrap links it, and the main `DEVSHOP:` line ends with
  `; repaired at session start: <tool>`
- **AC-2** With the download failing (a 504, a 404, or a file whose sha256 isn't the pinned one),
  nothing is installed for that tool and the main line ends with the `still missing` clause and that
  tool's cost; with two tools missing, each is named once, in `tools.pin` order
- **AC-3** With every tool present, the dispatcher calls no download (a fake `curl` that records its
  calls is never called) and adds no tools clause; with `DEVSHOP_PRIME_ONLY=1` and every tool
  missing, it calls none either
- **AC-4** In `repair` mode each missing tool is fetched with `--connect-timeout 10` at most twice,
  and the whole repair stops within its 60 s limit (a fake `curl` that hangs: the line is still
  printed, naming the tool as still missing); `build` mode still tries 4 times with backoff, as
  `tests/bootstrap.test.sh` checks; a `PATH` with a fake `sha256sum` first doesn't make `repair`
  install an unverified file
- **AC-5** `repair-tools.sh` installs the missing tools as AC-1 does and exits 0 when none is
  missing afterwards, 1 otherwise, naming each still-missing tool; two overlapping runs leave each
  tool installed once and both exit as AC-5 says
- **AC-6** With `dcg` missing, `bash-gate.sh` allows exactly
  `/opt/devshop-plugin/devshop/hooks/repair-tools.sh` and hands to `pre-bash.sh` (which blocks) that
  command with an argument, `; true`, `&& true`, `| cat`, a leading `bash ` or space, a trailing
  space or newline, any other command, input that isn't JSON, and any input when `jq` is missing;
  with `dcg` present every command reaches `pre-bash.sh`
- **AC-7** A dcg missing at session start and repaired there gives no "dcg is not installed" line
- **AC-8** A default ref that can't be read, a `tools.pin` missing at it, and a malformed line each
  give `; couldn't read the pinned tools (<why>)` and no download
- **AC-9** The bootstrap adds the repair command's allow rule to `~/.claude/settings.json` without
  removing what is there, with or without Chromium, and leaves a file that isn't a JSON object as it
  is, failing loudly, as the gstack browser step does
- **AC-10** `install/plugin/devshop/tools.sh` is the only tool installer: the bootstrap, the
  dispatcher and `repair-tools.sh` run it, and the bootstrap's existing tool tests pass against it;
  `hooks.json` gives SessionStart a timeout of 720 s
- **AC-11** `kit/notes/revamp/ASSUMPTIONS.md` has a row for the allow-rule assumption with the
  experiment's result — verified by review: the diff
- **AC-12** `install/README.md` describes the session-start repair, the new clauses in its table of
  `DEVSHOP:` lines and the repair command, and no longer says a missing dcg blocks Bash until the
  environment is rebuilt — verified by review: the diff

## Out of scope

- Rebuilding the environment cache from a session, or any environment setting
- The version's own `dcg` line in `runtime/hooks/session-start.sh`, which stays as it is
- gstack and impeccable, whose downloads are not from the release host
