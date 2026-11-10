# The reviewer runs a project's build, and a workspace's packages, before its local run

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

- **A declared build step, `scripts/build.sh`, a new optional contract item** (Claude's proposal,
  2026-11-10): when the review has a local run, and the head has `scripts/build.sh`, `review.sh`
  runs the head's `bash scripts/build.sh` in the clone first, as it runs the local run (its own
  process group, the session's variables dropped, `BUILD_SHA` set to the head commit, output to a
  log in the scratch directory), with its own limit `BUILD_WAIT=600` seconds (a constant beside
  `LOCAL_RUN_WAIT`); the local run starts only after it exits 0. The head decides whether there is
  a build, as it already decides the local run's code; the base still decides whether there is a
  local run, so a change still can't turn the browser on for itself, and a project can move its
  build out of `scripts/local-run.sh` in the same PR that adds `scripts/build.sh`. The contract
  item: "Builds what `scripts/local-run.sh` serves, from the repo root with the installed
  `node_modules`, `BUILD_SHA` naming the commit; installs nothing, reaches no other host; exit 0
  built." The Cloudflare home already has a `scripts/build.sh` (the website's); it isn't added to
  the home's `supplies` (optional for every stack). Rejected: building inside `scripts/local-run.sh`
  under a longer `LOCAL_RUN_WAIT` (one limit for two jobs, and a slow build is indistinguishable from
  a server that never answers); `review.sh` guessing the build command from `package.json` (the
  project knows its build; a guess is a second place it can drift)
- **Every package's `node_modules`, linked** (Claude's proposal, 2026-11-10): the clone gets a link
  to each `node_modules` directory of the real worktree that sits at the repo root or directly in a
  directory the head commit tracks a `package.json` in (a workspace package), unless the head tracks
  a path at or under that `node_modules`, not only the root's. The links go into the clone's
  `.git/info/exclude`. In a pnpm workspace a package's `node_modules` holds relative links into the
  root's `node_modules/.pnpm`, which resolve inside the real worktree through the link, so each
  package's own tools (`next`, `wrangler`) are found from its directory. The real worktree is at the
  head and clean (checked before), so it is the head's tree; the install is still whatever the
  session last ran, not proven to match the head's lockfile, as today. Rejected: an install in the
  clone (`pnpm install --offline --frozen-lockfile`, `npm ci --offline`): it needs the package
  manager and its whole store present, adds a second, slower install per review and per package
  manager, and a missing store entry fails the review for a reason that isn't the change's. If a
  project's build refuses packages that resolve outside its root, the install in the clone is the
  next step, logged as a finding then
- **"Installs nothing" stays true:** the local run and the build install nothing; the reviewer links
  what the session installed. The `scripts/local-run.sh` item is reworded: "Serves the site on
  `127.0.0.1:$PORT` (bound to that address) until stopped, from the repo root, with the installed
  `node_modules` (each workspace package's too) and what `scripts/build.sh` built when the project
  has one; installs nothing, reaches no other host. The one way to run the site locally." A
  project that already has `scripts/build.sh` (the website) gets it run before each review's local
  run from this release on.
- **A change that adds `scripts/local-run.sh` gets a smoke run** (Claude's proposal, 2026-11-10): on
  a full review where the base has no `scripts/local-run.sh` and the head has one, `review.sh` runs
  the build (as above) and the local run exactly as for a declared one, waits for an HTTP answer,
  then stops it before the review; any failure is could-not-run with the same reasons. The reviewer
  gets no browser and the prompt is unchanged (the no-local-run line): the base still decides
  whether a change is browsed. A change to the script, or to `scripts/build.sh`, with the script at
  the base is already exercised by every full review (the head's copies run). Could-not-run, not a
  `fail` finding: the same outcome a declared local run that can't start gets today, and `ship.sh`
  pushes nothing on it. Rejected: the full browser on the adding PR (a change would opt itself into
  being browsed); no smoke (the break shows on the next PR, the bug above)
- **The fixture is synthetic and offline:** `tests/fixtures/reviewer-workspace/` beside
  `tests/fixtures/reviewer-browser/`: a pnpm workspace (`pnpm-workspace.yaml`, a root and an
  `apps/web` `package.json`), a `scripts/build.sh` that runs a tool found only through
  `apps/web/node_modules` to write `apps/web/dist/`, and a `scripts/local-run.sh` that serves
  `apps/web/dist/` with a tool found the same way. The test lays out `node_modules` as pnpm does (the
  tool in the root's `node_modules/.pnpm/<name>@<version>/node_modules/<name>`, a relative link to it
  from `apps/web/node_modules/<name>` and a bin in `apps/web/node_modules/.bin`), so CI needs neither
  pnpm nor the network. Variants by file: a build that exits 1 with a message; a build that sleeps
  past a shortened `BUILD_WAIT`
- **The reviewer eval isn't rerun:** the prompt, `prompt-browse.md`, `browse.mjs`, `settings.json`,
  the schema and the model are unchanged; what changes is how the local run is prepared before the
  model runs, and whether a review is could-not-run, which the stub-`claude` tests cover. The
  live browser test (`tests/reviewer-browser-live.sh`) isn't rerun either, for the same reason
- **The release is the owner's:** a release tag is made only by the owner's release button
  (`specs/devshop-releases.md`); this PR is `fix:`, so it bumps the patch. After the merge, the
  owner presses the button; a project then moves to the tag with `ak:upgrade` in one PR. The note on
  how a project moves goes in the reviewer README's local-run section and the Cloudflare home's
  "Running locally": add `scripts/build.sh` (the build the local run used to need), make
  `scripts/local-run.sh` serve that output only, and pin the release; on the release before this
  one, the upgrade PR's own review is could-not-run unless the base already serves without a build
- **Feedback, not a wall:** the build runs the change's code, as the local run and a test run do,
  and can write through the linked `node_modules` (each package's now, not only the root's); stated
  in the README's lock-down section

## Acceptance items

- **AC-1** With `scripts/local-run.sh` at the base and `scripts/build.sh` at the head, a full review
  runs the head's build in the clone (session variables dropped, `BUILD_SHA` the head commit) to
  exit 0 before it starts the local run, and the local run serves what the build wrote. Shown by
  `tests/reviewer.test.sh` on the workspace fixture, stub `claude` and `browse.mjs`
- **AC-2** In a project with workspace packages, the clone gets a link to the real worktree's
  `node_modules` at the root and in each directory where the head tracks a `package.json`, and none
  where the head tracks a path under that `node_modules`, or where the directory isn't a package;
  the fixture's build and local run find their tools only through `apps/web/node_modules`. Shown by
  tests
- **AC-3** Could-not-run, naming `scripts/build.sh`, its exit code or the limit, and the log's tail,
  with no process of it left and the local run never started, for: a build that exits non-zero; a
  build still running after `BUILD_WAIT`; a build that leaves a process behind after it exits. Shown
  by tests
- **AC-4** A full review whose base has no `scripts/local-run.sh` and whose head adds one runs the
  build (when the head has one) and the local run, and is could-not-run when either fails, as in
  AC-3 and the reviewer-browser spec's AC-2; when it answers, it is stopped before the review, the
  reviewer has no `devshop-browse` and the prompt has the no-local-run line. With no
  `scripts/local-run.sh` at the head nothing runs, `scripts/build.sh` included. Shown by tests
- **AC-5** `runtime/project-contract.txt` has the `scripts/build.sh` item and the reworded
  `scripts/local-run.sh` item from Decisions; `scripts/contract-check.py` and its test accept them.
  Shown by tests
- **AC-6** The reviewer README (the local run section with the build, the package links, the smoke
  run and the note on moving to the release; the lock-down section; Proof), the Cloudflare home's
  "Running locally" (the same note), the W10.6.2 interface on `W10-v2.md` and the docs map describe
  the build and the smoke run — verified by review: the diff

## Out of scope

- Touching the pilot web app's repo or its scripts
- An install in the review's clone (`pnpm install`, `npm ci`)
- Pressing the release button, or the upgrade PR in any project
- Browsing a change that adds `scripts/local-run.sh` (it gets a smoke run, not the browser)
- `scripts/check-slow.sh` and the design review before `ship`, which run the local run in the
  session's own worktree, already built and installed
