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
- **Pinned tools** (L-45): [`install/tools.pin`](tools.pin) names gitleaks and shellcheck at the
  version and checksum CI pins (`tests/bootstrap.test.sh` fails if they differ). The bootstrap
  downloads each, checks its sha256, and links it into `/opt/devshop-tools/bin`, where the devshop's
  hooks run it. A bad or missing download is a loud `FAILED: tool …`; the other steps still run.
- **The project** holds one file, `.devshop-version`: a commit SHA for now (release tags once CI
  makes them, A-25). Bumping is a one-line PR. Without it the session uses `HEAD`: `main` as of the
  local copy.

## The `DEVSHOP:` line

The hook prints one line, and CLAUDE.md has Claude repeat it in its first reply. It always ends with
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
(`git push --no-verify`, changing `core.hooksPath`). The wall is required CI (`ci / lint`,
`ci / secret-scan`), which runs the same checks outside the session (L-36).

- **Where they come from.** The version's [`runtime/hooks/session-start.sh`](../runtime/hooks/session-start.sh)
  points the project's `core.hooksPath` at [`runtime/git-hooks/`](../runtime/git-hooks) (via
  `/opt/devshop-current`), keeping the project's own path in `devshop.chainHooksPath`. It is
  session-local git config; nothing is committed to the project, and the hooks come from the version
  the project pins. A later change of `core.hooksPath` is set back, with a `DEVSHOP:` line.
- **Pre-push** ([`runtime/git-hooks/pre-push`](../runtime/git-hooks/pre-push)) stops the push when
  the pinned gitleaks finds a secret in the commits the push adds (the repo's `.gitleaks.toml` if it
  has one), when the repo's own lint `scripts/lint.sh <base>` finds problems or can't run, or when
  the project's own pre-push fails. A missing gitleaks stops it too.
- **The project's hooks still run.** Every other hook name links to
  [`_chain`](../runtime/git-hooks/_chain), which runs the project's hook of the same name: from its
  former `core.hooksPath`, else husky's `.husky/<hook>`, else `.git/hooks`.
- **Per-edit nudge.** The plugin's PostToolUse hook on Claude's edit tools runs the version's
  [`runtime/hooks/post-edit.sh`](../runtime/hooks/post-edit.sh), which runs the repo's own
  `scripts/lint-file.sh <file>`. Findings or "couldn't run" go back to Claude in the same turn;
  clean is silent. It only sees Claude's edit tools; the pre-push hook sees every change.
- **The repo declares its checks.** The devshop carries no project-specific checks (Shape 3): a repo
  declares `scripts/lint.sh` (full, also what its CI runs) and `scripts/lint-file.sh` (one file). This
  repo's are [`scripts/lint.sh`](../scripts/lint.sh) and [`scripts/lint-file.sh`](../scripts/lint-file.sh);
  a project gets them from its stack home (W10.5.2). Without them, only the secret scan runs.

Proven by [`tests/git-hooks.test.sh`](../tests/git-hooks.test.sh) (real `git push`, real gitleaks)
and [`tests/post-edit.test.sh`](../tests/post-edit.test.sh).

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
- A repo's `scripts/lint.sh` needs its own tools in the session (here `npm ci` for Prettier); when
  one is missing, the push stops and the check names it.
- Still to come in W10.4.4: the hook that starts the independent reviewer on PR create/ready (after
  W10.6.6 changes the reviewer's call to `review.sh --base <rev>`).
- `runtime/skills/` is where the v2 skills land (W10.6).
