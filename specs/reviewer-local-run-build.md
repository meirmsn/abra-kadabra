# The reviewer installs a pnpm workspace and runs the project's build before its local run

**Go:** pending

## Intent

The owner (2026-11-10), in a devshop session: "Fix the devshop's reviewer so it can run the local
run of a project whose site must be built first and that is a pnpm workspace. Then release the fix
so projects can pin it." Done when: the reviewer can serve a project that needs a build (a declared
build step it runs in its clone with its own time limit, and/or a workspace-correct install), the
design and why recorded here, with `scripts/local-run.sh`'s "installs nothing" kept true or the
contract item reworded; a PR that adds or changes `scripts/local-run.sh` gets its local run
exercised, at least as a smoke check, so the PR that breaks it is the one that fails; a fixture for
a pnpm-workspace project whose site needs a build, beside `tests/fixtures/reviewer-browser/`, with
tests for build OK and served, build fails (a clear could-not-run reason) and build too slow; a
release tag, and a note on how a project moves to it. The pilot web app is not touched from this
session; it keeps its `scripts/local-run.sh` and waits for this release.

The bug, as the owner reported it (the pilot web app on v3.0.0; `runtime/reviewer/review.sh` on
`main` has the same code): `review.sh` turns the browser on when `scripts/local-run.sh` is at the
base commit, clones the head, links in only the real worktree's root `node_modules`, runs the script
with `PORT` set and waits `LOCAL_RUN_WAIT` (60 s) for an HTTP answer, else could-not-run (`ship.sh`
exits 2). The pilot is a Next.js app built with OpenNext in a pnpm workspace's app package, served
with `wrangler dev`; its script needs the build output, which a fresh clone never has (it isn't
committed, and the build takes a minute or more), and the clone lacks the per-package
`node_modules` pnpm creates, so `wrangler` and `next` aren't found from the app's directory. Every
one of its reviews is could-not-run. It slipped through because the PR that added the script was
reviewed against a base without it, and the break showed only on the next PR.

## Decisions

- **The experiment that picked the install** (Claude, 2026-11-10, in this session's scratch
  directory): a minimal pnpm workspace with a Next.js 15 app package built by
  `@opennextjs/cloudflare` and served by `wrangler dev`. In its own worktree: built in 36 s, served
  the page. In a fresh clone with the worktree's root and app `node_modules` symlinked in (the
  "link every package's `node_modules`" option): the build exited 0 in 13 s, but `wrangler dev`
  answered 500 (`Dynamic require of "/.next/server/middleware-manifest.json" is not supported`): the
  build traced through the links to paths outside the clone and bundled a broken Worker, silently.
  In a fresh clone with `pnpm install --offline --frozen-lockfile`: the install took 2 s from the
  session's store, the build 34 s, and the page served. Links are rejected; the install is chosen
- **A pnpm project gets an offline install in the clone** (Claude's proposal, 2026-11-10): on a
  review that runs a local run (declared or smoke, below), when the head has `pnpm-lock.yaml` at its
  root, `review.sh` runs `pnpm install --offline --frozen-lockfile` in the clone (its own process
  group, `drop_session_ties`, its log in the scratch directory, limit `INSTALL_WAIT=120` s) instead
  of linking `node_modules`. Offline: only the session's pnpm store is read, so a review reaches no
  registry, and the store holds what the session installed. Frozen: the lockfile is the head's,
  never rewritten. Every package's `node_modules` is then pnpm's own, inside the clone. `pnpm` not
  on `PATH` is could-not-run; so is a failed install, naming the command and the log's tail (the
  usual cause: the head's lockfile needs a package the session never installed, fixed by installing
  in the session). The store is the session's, passed explicitly (`--store-dir` set to what
  `pnpm store path` prints in the real worktree), so a store path the project's `.npmrc` sets
  relative to the repo still points at the session's store. A `packageManager` pin whose pnpm
  corepack hasn't cached makes the install reach the network or fail: could-not-run, never a pass,
  and said in the move note. The scratch directory and the store share a filesystem in a cloud session (one
  disk), so pnpm hard-links; elsewhere it copies, slower but correct. Other projects (`npm`) keep
  today's link of the root `node_modules`: nothing showed it broken, and npm workspaces hoist to the
  root. Rejected: links (the experiment); `npm ci --offline` for npm projects too (a change of
  behaviour for every npm project with no evidence it is needed)
- **A declared build step, `scripts/build.sh`, a new optional contract item** (Claude's proposal,
  2026-11-10; it reverses `specs/project-contract.md`'s out-of-scope line that kept `scripts/build.sh`
  in the stack home's prose as a stack-only name: the reviewer, which serves every stack, now
  relies on it): `owner: project`, `when: optional`, `check: executable`. Must: "Builds what
  `scripts/local-run.sh` serves, from the repo root with the installed `node_modules`, `BUILD_SHA`
  naming the commit; installs nothing, reaches no other host (telemetry off), needs no secret (the
  reviewer runs it in its clone with the session's environment); exit 0 built." For:
  the devshop's reviewer, before its local run; `scripts/deploy.sh` and `scripts/check-slow.sh`
  where the stack home says so. When the review runs a local run and the head has
  `scripts/build.sh`, `review.sh` runs the head's `bash scripts/build.sh` in the clone after the
  install and before it picks the port and starts the local run: its own process group,
  `drop_session_ties`, `BUILD_SHA` the head commit, its log in the scratch directory, limit
  `BUILD_WAIT=300` s (a constant beside `LOCAL_RUN_WAIT`; five times the pilot's build). Past the
  limit the group gets TERM, then KILL after 5 s. After it exits, any process of its group still
  alive is killed and the review is could-not-run ("left a process behind"); the same holds for the
  install, whose lifecycle scripts can start processes. The EXIT, INT, TERM and
  HUP cleanup stops the install's and the build's groups as it stops the local run's. The head
  decides whether there is a build (the build's code is the change's, like the local run's); the
  base still decides whether a change is browsed, so a project moves its build out of
  `scripts/local-run.sh` in the same PR that adds `scripts/build.sh`. A base with `scripts/build.sh`
  whose head deleted it adds "the head deleted scripts/build.sh" to a later could-not-run reason.
  The Cloudflare home already has a `scripts/build.sh` (the website's), so it is run before every
  review's local run from this release on; the home's `supplies` doesn't change. Rejected:
  building inside `scripts/local-run.sh` under a longer `LOCAL_RUN_WAIT` (one limit for two jobs; a
  slow build looks like a server that never answers); `review.sh` guessing the build from
  `package.json` (the project knows its build)
- **"Installs nothing" stays true for the project's scripts:** the install is the reviewer's, as the
  link was. The `scripts/local-run.sh` item becomes: "Serves the site on `127.0.0.1:$PORT` (bound to
  that address) until stopped, from the repo root with the installed `node_modules` and what
  `scripts/build.sh` built when the project has one; installs nothing, builds nothing, reaches no
  other host. The one way to run the site locally." Its other callers then build first: the
  Cloudflare and Next.js homes say `scripts/check-slow.sh` and the design review before `ship` run
  `scripts/build.sh` before `scripts/local-run.sh` (else CI's slow tier serves nothing and the
  design review judges a stale build), and the Next.js home's "On a Workers app the local run is the
  OpenNext build and `wrangler dev`" becomes the build in `scripts/build.sh` and `wrangler dev` in
  `scripts/local-run.sh`
- **Playwright stays at the root:** `devshop-browse` loads Playwright from the clone's root
  `node_modules`, as the render check does from the project root, so a workspace declares it in its
  root `package.json`; said in the README and the move note. `browse.mjs` doesn't change
- **A change that adds `scripts/local-run.sh` gets a smoke run** (Claude's proposal, 2026-11-10): on
  a full review whose base has no `scripts/local-run.sh` and whose head has one, `review.sh` does
  the install, the build and the local run exactly as for a declared one, waits for an HTTP answer,
  then stops it before the model runs. Any failure is could-not-run with the same reasons. The
  reviewer gets no browser and the prompt is unchanged (the no-local-run line): the base still
  decides whether a change is browsed. `node` is required only when browsing; the smoke run needs
  `curl` and `python3`. This supersedes the clause "a script the change adds (absent at the base) is
  not run" of `specs/reviewer-browser.md` AC-1 (one change, one spec, so that spec isn't edited; its
  test of that clause is rewritten under AC-5 here, and the README's "a change can't declare it for
  itself" says "can't turn the browser on for itself"). A change to either script, with the local
  run at the base, is exercised by every full review already (the head's copies run). A words-only
  review runs nothing: no install, build, smoke or local run. Could-not-run, not a `fail` finding:
  the outcome a declared local run that can't start already gets, and `ship.sh` pushes nothing on
  it. Rejected: the browser on the adding PR (a change would opt itself into being browsed)
- **Log tails without colour codes:** the could-not-run reason carries the last 300 bytes of the
  failing step's log with ANSI escape sequences removed (a Next build log is mostly colour codes)
- **The fixture needs no network and no store:** `tests/fixtures/reviewer-workspace/`, beside
  `tests/fixtures/reviewer-browser/`: a pnpm workspace whose `apps/web` depends only on a scoped
  workspace package two levels deep (`packages/tools/site-tool`, `workspace:*`) that has a bin; its
  `pnpm-lock.yaml` committed. `scripts/build.sh` runs that bin from `apps/web` (found only through
  `apps/web/node_modules/.bin`, which pnpm creates) to write `apps/web/dist/`, and
  `scripts/local-run.sh` serves `apps/web/dist/`. Variants by file: a build that exits 1 with a
  message; one that sleeps past a shortened `BUILD_WAIT`; one that leaves a background child; a
  lockfile that doesn't match its `package.json`. `pnpm` is pinned in this repo's `package.json`
  (devDependency), so `npm ci` brings it to CI and tests put `node_modules/.bin` on `PATH`; a test
  that finds no `pnpm` fails
- **Limits are constants, and `ship.sh` runs in the background** (adversarial review of the open
  questions, 2026-11-10, asked for by the owner): `INSTALL_WAIT=120` (60 times the measured install)
  and `BUILD_WAIT=300` (3 to 5 times the pilot's build; its cold-clone time is unmeasured, the
  spike's cold build was no slower than its warm one) stay constants, as `LOCAL_RUN_WAIT` is; a
  project that needs more is a finding when it happens, and a project-set limit, if ever added, is
  read at the base and capped, so a change can't set its own. The worst case is `INSTALL_WAIT` +
  `BUILD_WAIT` + `LOCAL_RUN_WAIT` + `TIMEOUT` = 120 + 300 + 60 + 900 s, about 23 minutes per full
  review round, past the agent's 600 s foreground command limit (already true of `TIMEOUT` alone),
  so the PR skill runs `ship.sh` in the background and waits for its exit; stated in the README and
  W10.6.2
- **The reviewer eval isn't rerun:** the prompt, `prompt-browse.md`, `browse.mjs`, `settings.json`,
  the schema and the model are unchanged; what changes is how the local run is prepared before the
  model runs, and when a review is could-not-run, which the stub-`claude` tests cover. The live
  browser test isn't rerun for the same reason
- **The release is the owner's, and it is a minor:** only the owner's release button makes a tag
  (`specs/devshop-releases.md`; a session can't push tags). The PR is titled `feat:` (adversarial
  review, 2026-11-10): a new contract item and a script newly run on reviews is a feature; no
  project needs a migration (the website's `scripts/build.sh` copies files and writes the commit; the
  pilot is could-not-run today), so no `!`. Rejected: `fix:` (a patch reads as no new surface). The move note, in the reviewer README's local-run section and the
  Cloudflare home's "Running locally": declare Playwright at the workspace root; add
  `scripts/build.sh` (the build the local run needed, telemetry off:
  `NEXT_TELEMETRY_DISABLED=1`, `WRANGLER_SEND_METRICS=false`); make `scripts/local-run.sh` serve
  that output only; move `.devshop-version` to the release in the same PR (an upgrade that carries
  the project's own two scripts beside the devshop's files), with Playwright's move run through
  `pnpm install` in the session first so the store holds the new lockfile's packages. The reviewer
  that runs is `/opt/devshop-current`, which the session-start dispatcher points at the worktree's
  pin; it runs on start, resume, clear and compact, so today it flips mid-session by accident, and a
  new session starts on `main`'s pin. So `ak:upgrade` re-runs the dispatcher
  (`install/plugin/devshop/hooks/dispatch.sh`) right after it commits the pin, and checks that the
  `DEVSHOP:` line names the new version before it invokes `ak:pr`; the upgrade PR is then reviewed
  by the version it moves to, which the owner released (adversarial review, 2026-11-10). The skill
  comes with the install, not the pin, so it reaches a project at its environment's next cache
  rebuild after this merges; until then the move note names the same command and the line to check.
  The new version must be in the environment's devshop copy (a cache rebuild after the release).
  Rejected: `ship.sh` taking the reviewer from the head's `.devshop-version` (a change would pick its
  own reviewer, on every PR); two PRs, trimming `scripts/local-run.sh` under the old reviewer first
  (any head copy is could-not-run there, and so is deleting it)
- **Feedback, not a wall:** the install and the build run the change's code (pnpm's lifecycle
  scripts, the build), as the local run and a test run do; pnpm hard-links from the session's store,
  so code that writes into an installed package's file writes the store's copy. Stated in the
  README's lock-down section. A build daemon that leaves its process group (`setsid`) isn't seen by
  the leftover check; a stated limit

## Acceptance items

- **AC-1** On a full review with `scripts/local-run.sh` at the base and `pnpm-lock.yaml` at the
  head's root, `review.sh` runs `pnpm install --offline --frozen-lockfile` in the clone, links no
  `node_modules`, and the fixture's build and local run find their tool through
  `apps/web/node_modules/.bin` only; without `pnpm-lock.yaml` the root `node_modules` is linked as
  before. Could-not-run, naming the cause, for: no `pnpm` on `PATH`; an install that fails (the
  mismatched lockfile); an install past `INSTALL_WAIT`. Shown by `tests/reviewer.test.sh`
- **AC-2** With `scripts/build.sh` at the head, the head's build runs after the install, with the
  session-tie variables dropped and `BUILD_SHA` the head commit, before the port is picked and the
  local run starts; the local run serves what it wrote and the review passes. Shown by tests on the
  workspace fixture, stub `claude` and `browse.mjs`
- **AC-3** Could-not-run, naming `scripts/build.sh`, its exit code or `BUILD_WAIT`, and the log's
  tail without ANSI codes, with no process of it left and no local run started, for: a build that
  exits 1; a build still running at `BUILD_WAIT`; a build that leaves a background child; a review
  interrupted (TERM) during the build. A base with `scripts/build.sh` and a head without it says so
  in the reason. Shown by tests
- **AC-4** A full review whose base has no `scripts/local-run.sh` and whose head adds one runs the
  install, the build and the local run, and is could-not-run when any fails or the run doesn't
  answer; when it answers, it is stopped before the model runs, the reviewer has no
  `devshop-browse` and the prompt has the no-local-run line. No `scripts/local-run.sh` at the head,
  or a words-only review: nothing runs, `scripts/build.sh` included. Shown by tests
- **AC-5** `tests/reviewer.test.sh`'s case "a change that adds scripts/local-run.sh itself" checks
  AC-4's smoke run instead of "not run". Shown by the test file
- **AC-6** `runtime/project-contract.txt` has the `scripts/build.sh` item and the reworded
  `scripts/local-run.sh` item from Decisions, and `runtime/scripts/contract-check.py --list` reads it
  and lists both. Shown by a test
- **AC-7** `package.json` pins `pnpm` as a devDependency, and the workspace tests fail, not skip,
  without it. Shown by tests
- **AC-8** `ak:upgrade`'s skill re-runs the dispatcher after committing the pin and stops, telling
  the owner, unless the `DEVSHOP:` line it prints names the new version; the PR skill runs
  `ship.sh` in the background and waits for its exit. Shown by `tests/skills-check.test.sh` or a
  test beside it that greps both skills for the step
- **AC-9** The reviewer README (the local-run section with the install, the build, the smoke run,
  Playwright at the root and the move note; the lock-down section; Proof; the worst case), the
  Cloudflare home's "Running locally" and the Next.js home's local-run line (the move note, the
  callers that build first), the W10.6.2 interface on `W10-v2.md` and the
  docs map describe the change — verified by review: the diff

## Out of scope

- Touching the pilot web app's repo or its scripts
- An install for npm projects in the review's clone
- `browse.mjs` finding Playwright in a package below the root
- Pressing the release button, or the upgrade PR in any project
- Browsing a change that adds `scripts/local-run.sh` (it gets a smoke run, not the browser)
- Changing `scripts/check-slow.sh` templates or the design review's code: their homes' prose says
  to build first; the projects' own scripts are the projects'
