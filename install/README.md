# The devshop install (D-01 D)

How a project's cloud session gets the devshop version that project pins. Built in W10.4.4 from the
W10.1.2b spike (`kit/notes/revamp/spikes/w10-1-2b-thin/`, kept as notes).

## Two parts, read at different times

| Path                                     | Read from                    | When                                                              |
| ---------------------------------------- | ---------------------------- | ----------------------------------------------------------------- |
| [`bootstrap.sh`](../bootstrap.sh) (root) | `main`, via the setup script | Environment cache build: delegates to `install/bootstrap.sh`      |
| [`install/`](.)                          | `main` as of the cache build | Environment cache build (about weekly, or on a setup-script edit) |
| [`runtime/`](../runtime)                 | The version the project pins | Every session start                                               |

- **Environment (one per project, D-01 revisited).** The setup script is two lines and never
  changes: a bare clone of the devshop into `/opt/devshop.git` with a read-only token, then
  `git --git-dir=/opt/devshop.git show HEAD:bootstrap.sh | bash`. So whatever is on `main` reaches
  every environment at its next cache rebuild.
- **`install/bootstrap.sh`** drops the token from the clone's remote URL (keeping the URL itself,
  L-01), records the copy's date in `/opt/devshop-versions/copy-date`, extracts `install/plugin/` to
  `/opt/devshop-plugin`, primes `/opt/devshop-current` with the default version (`HEAD`), and
  installs the plugin at user scope. It never prompts, runs every step even after a failure, and
  logs to `/tmp/devshop-setup.log`.
- **The plugin** (`install/plugin/devshop/`) is a stub: its `skills` is a symlink to
  `/opt/devshop-current/skills`, and its SessionStart hook (`hooks/dispatch.sh`) reads the project's
  `.devshop-version` (else the default), extracts that version's `runtime/` from the local copy into
  `/opt/devshop-versions/<sha>` (no network), repoints `/opt/devshop-current`, and runs the version's
  `runtime/hooks/session-start.sh` if it has one. Why a stub: a plugin installed by a hook loads only
  in the next session, but a symlinked skills dir switched by the hook works in the same one.
- **gstack** (TARGET Shape 7, D-07): [`install/gstack.pin`](gstack.pin) names one upstream commit.
  After the devshop's own steps, so a gstack failure can't stop them, the bootstrap fetches that
  commit into `~/.claude/skills/gstack`, unmodified, checks that `bun` is the version that commit is
  tested on (`GSTACK_BUN_TESTED` in its `bin/gstack-bun-version.sh`), so the gstack pin pins Bun
  too, installs its npm dependencies with
  `bun install --frozen-lockfile` (failing closed: gstack's setup would otherwise fall back to an
  unfrozen install), and runs its `./setup` with stdin closed and
  `--no-team --no-plan-tune-hooks --no-timeline-stop-hook`, so gstack registers no Claude hooks and
  leaves `~/.claude/settings.json` to the devshop plugin (F-GS-08). It then turns gstack's update
  check off (`auto_upgrade` is off by default): the pin is the only upgrade path. `--no-browser`:
  Chromium installs on a browser skill's first run. Output: `/tmp/devshop-gstack.log`.
- **Pinned tools** (L-45): [`install/tools.pin`](tools.pin) names gitleaks, shellcheck and dcg at
  the version and checksum CI pins (`tests/bootstrap.test.sh` fails if they differ). The bootstrap
  downloads each, checks its sha256, and links it into `/opt/devshop-tools/bin`, where the devshop's
  hooks run it. A bad or missing download is a loud `FAILED: tool …`; the other steps still run.
- **The project** holds one file, `.devshop-version`: a commit SHA for now (release tags once CI
  makes them, A-25). The `upgrade` skill bumps it in a PR that also brings the project's copies of devshop files (below). Without it the session uses `HEAD`: `main` as of the
  local copy.

## The `DEVSHOP:` line

The hook emits one line as Claude Code's hook JSON, because hook output otherwise reaches only Claude.
`additionalContext` gives Claude the line plus "Repeat every DEVSHOP: line above to the owner word for
word in your first reply", because a project carries no devshop rule saying so (LOG #43; this repo's
CLAUDE.md also asks). That is how the owner sees it: the macOS desktop and web apps do not display a SessionStart
`systemMessage` (LOG #45), which the hook still sets for surfaces that do. `jq` builds the JSON, since
output that fails to parse is dropped whole; without `jq`, the plain line and that request go out
instead. Lines the version's own session-start script prints travel the same way. It always ends with
the local copy's date, time and age, because the copy only refreshes when the environment cache
rebuilds and a same-day stale copy is otherwise invisible, then the project the session runs in. The
session can't read its environment's name, and with one environment per project the project names it.

| Case                                  | Line                                                                                                                                       |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| No `.devshop-version`                 | `using HEAD (<sha12>) from environment default (no .devshop-version) · devshop copy of <date> <HH:MM> UTC (<n> days old) · project <name>` |
| Pinned SHA in the copy                | `using <pin> (<sha12>) from project .devshop-version · devshop copy of …`                                                                  |
| Pin not in the copy (newer, or wrong) | `version '<pin>' (…) is not in the local devshop copy — kept version <sha12> · devshop copy of …; the copy refreshes …`                    |
| Pin older than this install           | `version '<pin>' (<sha12>) has no devshop runtime at runtime/ (older than the v2 install?) — kept version <sha12> · …`                     |
| Not a version (e.g. `--x`)            | `'<pin>' (…) is not a devshop version (a commit SHA) — kept version <sha12> · …`                                                           |

"Kept" means the session keeps the default version primed at setup. Proven by
[`tests/bootstrap.test.sh`](../tests/bootstrap.test.sh). It replays the setup script (local bare
clone, second line verbatim) in a private mount namespace with a scratch `/opt`, then runs the
installed hook for every case above.

## Git hooks and the per-edit nudge

Feedback, not walls: everything here runs in the session's VM, where the agent can bypass it
(`git push --no-verify`, changing `core.hooksPath`). The wall is required CI (`ci / fast`,
`ci / slow`), which runs the same checks outside the session (L-36).

- **Where they come from.** The version's [`runtime/hooks/session-start.sh`](../runtime/hooks/session-start.sh)
  points the project's `core.hooksPath` at [`runtime/git-hooks/`](../runtime/git-hooks) (via
  `/opt/devshop-current`), keeping the project's own path in `devshop.chainHooksPath`. It is
  session-local git config; nothing is committed to the project, and the hooks come from the version
  the project pins. A later change of `core.hooksPath` is set back, with a `DEVSHOP:` line.
- **Pre-push** ([`runtime/git-hooks/pre-push`](../runtime/git-hooks/pre-push)) stops the push when
  the pinned gitleaks finds a secret in the commits the push adds (the repo's `.gitleaks.toml` if it
  has one), when the repo's own lint `scripts/lint.sh <base>` finds problems or can't run, or when
  the project's own pre-push fails. A missing gitleaks stops it too.
- **The project's hooks still run, if it configured them.** Every other hook name links to
  [`_chain`](../runtime/git-hooks/_chain), which runs the project's hook of the same name from its
  former `core.hooksPath` (e.g. husky's after `npm install`), else `.git/hooks`. Hook scripts that
  are only committed (`.husky/*` with husky not set up) never run: git never runs committed hooks, so
  checking out an untrusted branch doesn't run its code.
- **Per-edit nudge.** The plugin's PostToolUse hook on Claude's edit tools runs the version's
  [`runtime/hooks/post-edit.sh`](../runtime/hooks/post-edit.sh), which runs the repo's own
  `scripts/lint-file.sh <file>`. Findings or "couldn't run" go back to Claude in the same turn;
  clean is silent. It only sees Claude's edit tools; the pre-push hook sees every change.
- **Bash guard.** The plugin's PreToolUse hook on Bash runs the version's
  [`runtime/hooks/pre-bash.sh`](../runtime/hooks/pre-bash.sh), which hands the command to the pinned
  [dcg](https://github.com/Dicklesworthstone/destructive_command_guard) (Destructive Command Guard,
  as in v1). dcg blocks destructive commands (`git reset --hard`, force pushes, `git clean -f`,
  `git checkout -- .`, `rm -rf`, …) and tells Claude why and what to do instead; everything else
  passes silently. It fails closed: a missing dcg, one that fails or runs past 10 s, or hook input it
  can't parse blocks the command, with a message telling Claude to tell the owner. So a failed dcg
  download blocks every Bash command until the environment is rebuilt (`FAILED: tool dcg` in
  `/tmp/devshop-setup.log`); session start says so up front in a `DEVSHOP:` line, when the
  installed plugin registers the guard. It reads only the command's text, so a destructive command inside a
  script file or an interpreter gets through, and dcg ignores what a heredoc writes.
- **The review guard.** Changes reach a PR only through the version's
  [`runtime/reviewer/ship.sh`](../runtime/reviewer/ship.sh), which runs the independent reviewer in
  the VM and pushes code and words together only on a pass. The plugin's PreToolUse hook runs
  [`runtime/hooks/review-guard.py`](../runtime/hooks/review-guard.py), which refuses the other ways
  (`gh pr create`, a push to a branch with an open PR, the GitHub tools that create, edit or commit).
  If the pinned guard or `python3` is missing, the fallback refuses the same calls. Details:
  [`runtime/reviewer/README.md`](../runtime/reviewer/README.md#ship).
- **Session setup.** Session start also runs the repo's own `scripts/setup.sh`, if it has one
  (this repo's: `npm ci`, so Prettier is there for its checks): silent when it works, a `DEVSHOP:`
  line when it fails (log: `/tmp/devshop-project-setup.log`). It is the repo's own code, like its
  tests and lint scripts.
- **CI in two tiers.** Session start checks the project's `.github/workflows/ci.yml` against the
  version's [`templates/ci.yml`](../runtime/templates/ci.yml) with
  [`scripts/ci-tiers-check.py`](../runtime/scripts/ci-tiers-check.py) (30 s limit): a `DEVSHOP:`
  line when there is no `ci.yml`, when it breaks a rule (named), or when the check can't run (e.g.
  no PyYAML); nothing when it follows the template. Feedback for the owner; required CI is the wall.
- **The project's copies of devshop files.** A project's CI can't reach the devshop, so the project
  keeps copies of the scripts its CI runs. The version's
  [`project-files.txt`](../runtime/project-files.txt) names them (owner `devshop`) and the templates
  the project adapted (owner `seed`). When the project pins a version, session start runs
  [`scripts/project-files.py`](../runtime/scripts/project-files.py) `check` against it (30 s
  limit): a `DEVSHOP:` line naming each copy that differs, is missing, is a symlink or lost its
  executable bit (on disk or as committed), or that the check can't run; nothing when they match, or
  when the pinned version predates the manifest. Without a pin it stays silent, as the default
  (`HEAD` of the local copy) would report every devshop change. Seeds are never compared. The
  [`upgrade`](../runtime/skills/upgrade/SKILL.md) skill re-pins the project and brings the copies in
  one PR. Feedback, not a wall.
- **The repo declares its checks.** The devshop carries no project-specific checks (Shape 3): a repo
  declares `scripts/lint.sh` (full; the pre-push hook runs it), `scripts/lint-file.sh` (one file),
  and CI's two tiers `scripts/check-fast.sh <base>` (secret scan, `lint.sh`, unit tests) and
  `scripts/check-slow.sh` (end-to-end tests). This repo's are in [`scripts/`](../scripts); a project
  gets them from its stack home (W10.5.2). Without `lint.sh`, only the secret scan runs on push.

Proven by [`tests/git-hooks.test.sh`](../tests/git-hooks.test.sh) (real `git push`, real gitleaks),
[`tests/post-edit.test.sh`](../tests/post-edit.test.sh) and
[`tests/pre-bash.test.sh`](../tests/pre-bash.test.sh) (real dcg).

## Limits and next steps

- The local copy is up to about a week old. A newer pin keeps the default, with the line above,
  until the cache rebuilds (D-01's revisit trigger → D′).
- Environments whose cache predates this install still run the spike's stub, which reads
  `spikes/w10-1-2b-thin/runtime`. The spike files stay, so those sessions keep working until their
  next rebuild.
- gstack comes from `main`'s pin at cache build, not from the project's pinned devshop version.
- gstack takes about 1.7 GB in the environment cache and about 20 s of setup.
- Bun comes from the environment image. When the image's Bun stops matching the pinned gstack's
  tested version, the gstack step fails loudly (the devshop still installs); then install a pinned
  Bun release with a checksum, or move the gstack pin.
- `/gstack-upgrade` stays available: gstack refuses to disable it ("it is how gstack upgrades and
  routes"). Its update check is off, so nothing prompts an upgrade; one run by hand changes only
  that session's VM.
- Chromium for gstack's browser skills (`/qa`) is untested here; the image ships Playwright's in
  `/opt/pw-browsers`. Decided with the A-13 smoke check on the fixture.
- Upgrading gstack: change the SHA in `install/gstack.pin` by PR, then run the smoke check: in a
  fresh session the `DEVSHOP:` line still appears and `/autoplan` runs (F-GS-04, F-GS-08), plus the
  skills v2 uses (A-13).
- The pre-push hook's lint checks the working tree, not exactly the commits pushed; CI checks the
  commits. Pushing to a URL rather than a remote name scans the whole history (slower, never less).
- The repo's declared `scripts/lint.sh` and `scripts/lint-file.sh` run from the working tree, on
  each push and edit, like its tests do. So a session working on an untrusted branch (a fork's PR)
  runs that branch's versions: review such a branch in a clone without the devshop's hooks path.
- A project that sets up husky after session start (`npm install` runs its `prepare`) points
  `core.hooksPath` back at husky, turning the devshop's hooks off until the next session start,
  which sets them back and keeps husky's chained.
- A repo's `scripts/lint.sh` needs its own tools in the session (here `npm ci` for Prettier); when
  one is missing, the push stops and the check names it.
- An upgrade can only target a version in the local copy; a newer one waits for the cache rebuild,
  and the `upgrade` skill says so and stops.
- The v2 skills (`intent`, `build`, `pr`, `devshop-version`, `upgrade`) load from the pinned version's
  `runtime/skills/`; `tests/bootstrap.test.sh` checks the plugin resolves each one there.
