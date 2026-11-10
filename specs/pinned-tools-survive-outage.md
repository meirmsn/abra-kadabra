# Pinned tools survive a release-host outage

**Go:** pending

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
`gitleaks` missing in five sessions at once. In the devshop session writing this spec, the cache
built on 2026-11-09 has no `shellcheck` (a 504 in `/tmp/devshop-setup.log`), and the same URL
answered 200 three times out of three a day later. So the root cause is narrower than "no cache":
the cache is built once and a transient download failure is frozen into it, and nothing after the
build tries again. The retry merged in PR #189 (4 tries at build time) is a mitigation of the same
cause.

Feedback, like every hook: the repair and the line tell and fix, they guard nothing. The walls (the
pre-push hook's gitleaks, CI's secret scan, `main`'s protection) are unchanged.

## Decisions

- **Repair at session start, from the same pinned source:** the plugin's dispatcher
  (`install/plugin/devshop/hooks/dispatch.sh`, installed from `main` at the cache build, so it
  reaches every project whatever version it pins) checks each tool in `install/tools.pin` at the
  default ref of the local copy. When one is missing from `/opt/devshop-tools/bin`, it installs the
  missing ones with the bootstrap's own tool step: the pinned URL, the pinned sha256, the same
  unpack and links. A tool that is present is never downloaded again. The repair writes only this
  session's container; the cache stays as built. Rejected: a fix only at cache build (it can't
  help sessions on a cache that is already broken) (Claude, 2026-11-10; for the owner's go)
- **The tool step moves into one tested script, `install/tools.sh <tools.pin> <tools dir> <PATH
dir> <log>`:** the bootstrap, the session-start repair and the repair command all run it, so
  there is one installer. Its behaviour at the bootstrap is today's (4 tries with backoff); at
  session start it tries each download twice with `curl --max-time 30`, so a host that is still down
  costs at most about a minute per missing tool and a session with nothing missing costs no
  download (Claude, 2026-11-10)
- **The repair logs to its own file, `/tmp/devshop-tools-repair.log`:** the bootstrap's clause
  (specs/bootstrap-result-at-session-start.md) keeps reading `/tmp/devshop-setup.log` unchanged,
  since it is the record of the build (Claude, 2026-11-10)
- **The main `DEVSHOP:` line says the outcome, after the bootstrap clause:**
  `; repaired at session start: <tools>` when the repair installed them, and
  `; still missing: <tool> (<what it costs>), …: run /opt/devshop-plugin/devshop/hooks/repair-tools.sh or start a new session`
  when it didn't. The costs: `dcg` "every Bash command is blocked", `gitleaks` "this session can't
  push", any other tool "its checks can't run". Nothing is added when no tool is missing (Claude,
  2026-11-10)
- **A sanctioned repair command, `/opt/devshop-plugin/devshop/hooks/repair-tools.sh`, no
  arguments:** the session-start repair, run by hand mid-session (for an outage still on at session
  start). It reads only the local copy's pin and runs `install/tools.sh`; it takes no input that
  could change what is installed. Two things stand between a session and running it, and the change
  handles both, pending the owner's answers below:
  - _the Bash guard:_ without `dcg` the version's `pre-bash.sh` blocks every command, this one
    included. The plugin's Bash hook (from `main`) lets through exactly the command
    `/opt/devshop-plugin/devshop/hooks/repair-tools.sh`, compared as a whole string, before handing
    any other command to the version's `pre-bash.sh` as today. Any other text in the command
    (arguments, `;`, `&&`, a pipe, a different path) goes to `pre-bash.sh` as today (Claude,
    2026-11-10)
  - _the permission classifier:_ the bootstrap adds `Bash(/opt/devshop-plugin/devshop/hooks/repair-tools.sh)`
    to `permissions.allow` in `~/.claude/settings.json`, as it already adds the gstack browser env.
    Whether auto mode honours that allow rule is untested: a new ASSUMPTIONS.md row, and the
    experiment runs before the build relies on it. If it doesn't, the repair command stays and the
    owner approves it once per session, as today but with one fixed, named command (Claude,
    2026-11-10)
- **No degraded path to open a PR without `ship.sh`:** a PR opened around `ship.sh` skips the
  reviewer, which the review guard exists to stop; with the repair, a session whose tools are
  missing at the end of its start is a session whose release host is still down, and the line now
  tells it at the start to start a new session. Rejected: letting `create_pull_request` through
  when a tool is missing (Claude, 2026-11-10; the owner's call)
- **No mirror of the binaries for now:** the evidence is a transient outage (the host answered a day
  later) and the git clone of the devshop succeeded at the same build while the release download
  failed. A copy of the pinned binaries under a non-branch ref of the devshop repo (fetched only on
  a failed download, still checked against the pinned sha256) is the next step if a lasting outage
  is seen; it means committing about 20 MB of third-party binaries per tool upgrade, one of them
  GPL. Rejected for now, logged as a candidate (Claude, 2026-11-10; the owner's call)
- **Environment settings are not touched:** no setup-script or image change (the owner's, through
  the environment tools' approval prompts) (task, 2026-11-10)

## Acceptance items

- **AC-1** With a tool from `tools.pin` missing from `/opt/devshop-tools/bin` and its pinned
  download served, the dispatcher installs it at session start, checked against the pinned sha256
  and linked as the bootstrap links it, and the main `DEVSHOP:` line ends with
  `; repaired at session start: <tool>`
- **AC-2** With the download failing (an HTTP error, or a file whose sha256 isn't the pinned one),
  nothing is installed for that tool, and the main line ends with
  `; still missing: <tool> (<cost>): run /opt/devshop-plugin/devshop/hooks/repair-tools.sh or start a new session`,
  with the cost as the Decisions list it; several missing tools are each named once, in
  `tools.pin` order
- **AC-3** With every tool present, the dispatcher runs no download (a fake `curl` that records
  calls is never called) and adds neither clause
- **AC-4** At session start each missing tool's download is tried at most twice, each try bounded
  by `curl --max-time 30`; the bootstrap still tries 4 times with backoff, as
  `tests/bootstrap.test.sh` already checks
- **AC-5** `repair-tools.sh` run in a session installs the missing tools as AC-1 does, exits 0 when
  none is missing afterwards and 1 otherwise, naming each still-missing tool
- **AC-6** With `dcg` missing, the plugin's Bash hook allows the exact command
  `/opt/devshop-plugin/devshop/hooks/repair-tools.sh` and blocks, as `pre-bash.sh` does today, that
  command with anything added (an argument, `; true`, `&& true`, `| cat`, a leading `bash `, a
  trailing newline) and any other command; with `dcg` present every command still reaches
  `pre-bash.sh`
- **AC-7** The bootstrap adds the repair command's allow rule to `~/.claude/settings.json` without
  removing what is there, and leaves a file that isn't a JSON object as it is, failing loudly, as
  the gstack browser step does
- **AC-8** `install/tools.sh` is the only tool installer: the bootstrap, the dispatcher and
  `repair-tools.sh` run it, and the bootstrap's existing tool tests pass against it
- **AC-9** `install/README.md` describes the session-start repair, the two new clauses in its table
  of `DEVSHOP:` lines, and the repair command — verified by review: the diff

## Out of scope

- A mirror or cache of the binaries outside the release host (a candidate, above)
- Rebuilding the environment cache from a session, or any environment setting
- A degraded PR path around `ship.sh`
- The version's own `dcg` line in `runtime/hooks/session-start.sh`, which stays as it is
- gstack and impeccable, whose downloads are not from the release host
