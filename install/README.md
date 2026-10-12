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
- **The project** holds one file, `.devshop-version`: a commit SHA for now (release tags once CI
  makes them, A-25). Bumping is a one-line PR. Without it the session uses `HEAD`: `main` as of the
  local copy.

## The `DEVSHOP:` line

The hook prints one line, and CLAUDE.md has Claude repeat it in its first reply. It always ends with
the local copy's date and age, because the copy only refreshes when the environment cache rebuilds.

| Case                                  | Line                                                                                                                    |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| No `.devshop-version`                 | `using HEAD (<sha12>) from environment default (no .devshop-version) · devshop copy of <date> (<n> days old)`           |
| Pinned SHA in the copy                | `using <pin> (<sha12>) from project .devshop-version · devshop copy of …`                                               |
| Pin not in the copy (newer, or wrong) | `version '<pin>' (…) is not in the local devshop copy — kept version <sha12> · devshop copy of …; the copy refreshes …` |
| Pin older than this install           | `version '<pin>' (<sha12>) has no devshop runtime at runtime/ (older than the v2 install?) — kept version <sha12> · …`  |
| Not a version (e.g. `--x`)            | `'<pin>' (…) is not a devshop version (a commit SHA) — kept version <sha12> · …`                                        |

"Kept" means the session keeps the default version primed at setup. Proven by
[`tests/bootstrap.test.sh`](../tests/bootstrap.test.sh). It replays the setup script (local bare
clone, second line verbatim) in a private mount namespace with a scratch `/opt`, then runs the
installed hook for every case above.

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
- Still to come in W10.4.4: devshop-owned git hooks (pre-push `gitleaks git`) via
  `runtime/hooks/session-start.sh`.
- `runtime/skills/` is where the v2 skills land (W10.6).
