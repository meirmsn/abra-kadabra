# The design detector engine in every cloud session, from a pinned npm package

**Go:** "2. keep 3. accept" then "ok" on the five departures from the brief's shape (owner, 2026-11-01, the three questions on the go screen: all five adjustments kept, the prune kept, the one-time command in an existing environment accepted)

## Intent

Spec B of the UI tooling strategy, the second of the four changes the owner accepted on 2026-10-31
("agree with your 4 recs"; at spec A's go, "1. yes" to call 1: install the pinned detector engine;
[spec A](design-guideline.md) records the order A, B, C, D). The owner's brief for this change
(2026-11-01): "every cloud session has the engine at gstack's READY path, placed by the bootstrap
from the npm platform package at a pinned version and checksum, never from GitHub; a design review's
Evidence line on a PR says whether the detector ran", with the recorded yes: "a pinned third-party
binary, Impeccable's design detector engine, may run over project files in every session".

Why: the pinned gstack's `/design-review` probes for impeccable's engine and, when it finds one,
opens every review with its deterministic rules (61 mechanical checks: the AI-slop tells, contrast,
type hierarchy) before its own judgement. Without one, in the builder's session, it asks its install
question on every design review, which `ui.md` § Design review's list of answered questions doesn't
cover, and the two design-review spikes' reports read "Detector: not installed". gstack's own install
downloads from GitHub releases, which the cloud session's network policy answers with 403;
`registry.npmjs.org` is allowed, and impeccable publishes the same raw binary there as a platform
package.

## Decisions

- **The source: the npm platform package, never GitHub.** `@impeccable/cli-linux-x64` at the pinned
  version holds the engine at `package/bin/impeccable`. Verified on 2026-11-01 in a cloud session:
  its 0.1.3 binary's sha256 and size (`afc7a424…`, 15 991 120 bytes) equal the `linux-x64` entry
  gstack's `lib/design-detect-contract.ts` pins for 0.1.3, so the npm route places the byte-identical
  file gstack would have fetched. The package ships an Apache-2.0 licence file. Rejected: gstack's
  own `install` verb (GitHub, blocked; it also asks); building from impeccable's source (a toolchain
  per session) (Claude's proposal, 2026-11-01, from the brief)
- **The pin, `install/impeccable.pin`:** one data line `<version> <sha256>`, the npm package version
  (also the directory name gstack reads the engine's version from, and compares with its
  `TESTED_ENGINE_VERSIONS`) and the sha256 of the binary itself, not of the tarball, so the number
  can be compared by eye with gstack's pin. The binary's own `--version` prints a different number
  (4.0.0, impeccable's skills version); the pin's comment says so. A second data line
  `gstack <40-hex commit>` names the gstack commit whose `TESTED_ENGINE_VERSIONS` and `ENGINE_PINS`
  the engine pin was checked against. That line is read by the test only, never by the script or
  the bootstrap: `tests/bootstrap.test.sh` compares it with `install/gstack.pin`'s commit at HEAD,
  beside its tools.pin-against-ci.yml check, and fails when they differ, so moving the gstack pin
  forces a look at the engine pin (the brief: "move the engine pin with the gstack pin"); the test's
  fake-gstack branches rewrite both pins together. Pinned now: 0.1.3, the one version the pinned
  gstack has tested; a newer engine would print an "untested" note and unmapped rule ids. Rejected:
  the newest version (0.1.18 today) (Claude's proposal, 2026-11-01)
- **One tested script, two callers: `install/impeccable.sh <pin file> <home>`.** It reads the pin,
  fetches `https://registry.npmjs.org/@impeccable/cli-linux-x64/-/cli-linux-x64-<version>.tgz`
  with `curl` into a fresh temporary directory, extracts the one member `package/bin/impeccable`
  there (`tar --no-same-owner`, as `install_tools` does; a member that isn't a regular file is
  refused), checks its sha256 against the pin, and only then moves it into place at
  `<home>/.impeccable/bin/<version>/impeccable`, mode 0755, replacing whatever was there, and
  removes every other `<home>/.impeccable/bin/<semver>/` directory, so gstack's "newest semver
  directory" choice is always the pinned engine (a pin moved backwards included; in a cloud session
  and in CI that directory is the devshop's). It always fetches: no "already there" shortcut, so one
  path is tested and a wrong file in place is replaced. It prints `placed <path>`. A pin line that
  isn't `<version> <sha256>`, a failed fetch (no network, 403, 404), a tarball without the member,
  a checksum mismatch, or a machine that isn't Linux x86_64 places nothing, removes nothing, says
  why on stderr and exits 1 (2 for bad arguments). The bootstrap gets a step `install_impeccable`
  right after `install_gstack`: it materialises `install/impeccable.pin` and `install/impeccable.sh`
  from the mirror at `$REF` into a temporary directory (`git show` into files, as it has no
  checkout), runs `bash <dir>/impeccable.sh <dir>/impeccable.pin "$HOME"`, and logs
  `impeccable <version> placed <path>` or `FAILED: impeccable: <why>` through `step_failed`, so the
  log ends `RESULT: bootstrap FAILED` and the exit status is non-zero while every other step still
  runs (L-43, as a gstack failure does). CI's `slow` job runs the same script from the checkout
  (`install/impeccable.sh install/impeccable.pin "$HOME"`) before `scripts/check-slow.sh`, so the
  slow test below has the same engine CI and a session have. Rejected: the step inline in
  `bootstrap.sh` with CI retyping it (CLAUDE.md: mechanical steps live in tested scripts, once); a
  Node or Bun installer for the package (`npm install -g` runs the package's scripts; it has none
  today, but the script needs only `curl`, `tar` and `sha256sum`) (Claude's proposal, 2026-11-01)
- **No gstack setting changes.** With the engine at `~/.impeccable/bin/<version>/impeccable`,
  gstack's probe prints `IMPECCABLE_READY` (verified 2026-11-01 with `IMPECCABLE_HOME` pointing at a
  scratch copy: `READY`, `engineVersion: 0.1.3`, a scan with the planted page's four rule ids) and
  the install offer never appears. When the bootstrap couldn't place it, the offer comes back; `ui.md`
  § Design review's "its questions don't go to the owner" covers it: the builder declines it
  (gstack's "continue without"), and the Evidence line says the detector did not run. Rejected:
  setting `design_detector_install_prompted` in the bootstrap (it would silence the offer in the
  failure case too, hiding the failure) (Claude's proposal, 2026-11-01)
- **The slow-tier test, `tests/design-detector.test.sh`:** it finds the engine as gstack does
  (`$IMPECCABLE_HOME`, else `~/.impeccable`, then `bin/<pinned version>/impeccable`, the pinned
  version rather than the newest, so the test proves the pin) and runs the engine's own file-scan
  mode (`impeccable detect`), which needs no browser, network or Bun; DOM mode is gstack's at review
  time. A missing engine prints why, names the command that places it
  (`install/impeccable.sh install/impeccable.pin "$HOME"`) and exits 2: `tests/run.sh` counts any
  non-zero exit as a failed file, so it is never a skip (CLAUDE.md: a missing tool fails). Its
  cases, observed with 0.1.3 on 2026-11-01, each printed as `design-detector-in-bootstrap AC-4`
  for the acceptance→test check: the committed fixture `tests/fixtures/design-detector/planted.html`
  (a purple-violet gradient hero with white text on violet, Inter as the display face, a tracked
  ALL-CAPS eyebrow above an oversized h1, three nested rounded cards) exits 2 and its `--json` list
  names at least the `antipattern`s `ai-color-palette`, `overused-font` and `hero-eyebrow-chip`
  (`low-contrast` fires too; the nested cards did not fire in file mode and are not asserted);
  `runtime/templates/ui/example.html` with its `base.css` and `theme.js`, copied to a scratch
  directory, exits 0, which the engine documents as "no primary findings" (advisory rules never
  change its exit), and its `--json --no-advisory` list is empty: the brief's "no `high` finding",
  made stricter by what was observed; a target that doesn't exist exits 1; the binary's sha256
  equals the pin. The engine runs on the fixture and the template only, never on the repo. Proven to
  fail, each mutant run once and its failure shown under the PR's Evidence: the fixture with one
  tell removed (the test fails naming the missing id); the pin with another checksum (the sha256
  case fails); no engine (the test, re-run by itself with `IMPECCABLE_HOME` at an empty directory,
  exits 2; this one is a case inside the test, run every time) (Claude's proposal, 2026-11-01)
- **In an existing environment,** `~/.impeccable` is empty until its cache rebuilds with the new
  bootstrap, so `tests/run.sh slow` in the builder's session exits non-zero until the script has
  run once by hand (`install/impeccable.sh install/impeccable.pin "$HOME"`): `CLAUDE.md`'s
  `tests/run.sh` line says so, and the test's exit-2 message names the command (Claude's proposal,
  2026-11-01, from the spec review)
- **The CI tiers test keeps the step:** `tests/ci-tiers-check.test.sh` AC-6's needles for the
  `slow` job gain the full command `install/impeccable.sh install/impeccable.pin "$HOME"` (a
  step's `name:` alone can't satisfy it), so a future edit can't drop the engine from CI without a
  failing test. The `fast` job is unchanged: the engine is slow-tier only (Claude's proposal,
  2026-11-01)
- **What the owner sees:** `runtime/templates/pr-body.md`'s Design review line gains, in words
  only: "detector: ran, N → M findings (engine `<version>`)", or "detector: did not run: `<why>`";
  N → M is what gstack's own report prints (`Detector: N → M`), the brief's "n findings" with the
  after count. `runtime/scripts/pr-body-check.py` is unchanged (spec A's reasoning: a check change
  for a line the owner already reads). No link to gstack's report: it is a local file under gstack's
  state directory, and `pr-assets.sh` pins images only; the rule ids of what was fixed and logged
  are already in the line's "findings fixed and logged" words (Claude's proposal, 2026-11-01)
- **`ui.md` § Design review, two sentences in existing bullets,** accepting that each may wrap: the
  Unattended bullet says the engine is the bootstrap's, so gstack's install offer, when it appears,
  is declined ("continue without"); the On the PR bullet says the review opens with impeccable's
  detector when the bootstrap placed its engine (gstack's `IMPECCABLE_READY`), that a detector hit
  is evidence the review confirms in the rendered page, never a finding by itself (gstack's own
  rule), and that the Evidence line says whether it ran. Nothing else in `ui.md` changes (Claude's
  proposal, 2026-11-01)
- **Where this departs from the brief's suggested shape,** for the owner's call at the go: (a) the
  step's logic is a separate tested script the bootstrap and CI both run, not inline in
  `bootstrap.sh`; (b) the pin has a second data line naming the gstack commit; (c) the template
  case asserts no primary finding, stricter than "no `high` finding"; (d) the Evidence words carry
  N → M rather than one count, and no link to the report; (e) the `ui.md` change is two sentences,
  not one line
- **Risks, stated.** (1) A third-party binary runs over project files in every session: the owner's
  recorded yes (2026-10-31, call 1; restated in the brief of 2026-11-01). What bounds it: one
  version and checksum, placed from the registry's bytes; gstack runs it with a minimal environment,
  a timeout, a stdout cap and URLs refused, and treats every string it prints as untrusted content;
  the devshop's test runs it on two fixtures in scratch directories. The engine itself loads a
  project's `DESIGN.md` and `.impeccable/` config as context (its `--no-design-system` and
  `--no-config` flags say so), which can only shape or narrow what it reports; content read from a
  project is data (CLAUDE.md). (2) The engine pin must move with the gstack pin: the
  `gstack <commit>` line and its test. (3) The package may vanish from the registry, or the network
  policy may stop allowing `registry.npmjs.org`: the step fails loudly, nothing is placed, the
  design review runs without the detector and says so; the environment's allowed hosts are the
  owner's setting, not this repo's. (4) Linux x86_64 only: the cloud image and CI's runners; another
  platform refuses with a line, and gstack's pins list the other platforms' checksums when one is
  needed. (5) The slow tests in a session needed the Playwright re-pin (F-NEW-132, fixed by the
  change merged on 2026-11-01); this test needs no browser. (6) The script removes other version
  directories under `~/.impeccable/bin`: in a cloud session and in CI that directory holds only
  what this script placed; on a developer's own machine it would remove an engine installed by
  hand, which `install/README.md` says
- **The proof is a dry run, graded before it runs,** recorded under
  `kit/notes/revamp/spikes/design-detector/` and linked from the docs map, as the earlier
  design-review spike was: a scratch site from `runtime/templates/ui/` with a `DESIGN.md` in gstack's
  spec format and one page carrying the fixture's tells, on a branch, served on a local port. The
  engine placed in the session by `install/impeccable.sh` against the committed pin into `$HOME`
  (the script's one live run against the real registry, recorded). One fresh `general-purpose`
  helper runs `/design-review` with the URL, as `ui.md` § Design review words it, and returns
  gstack's report verbatim and every question it would have put to the owner. Pass, fixed before
  the run: the report's set-up shows `IMPECCABLE_READY: <path>` naming the placed engine; its
  summary's `Detector: N → M` line (gstack's wording; "not installed" or "off" when it did not run)
  has N ≥ 3; `[ai-color-palette]`, `[overused-font]` and `[hero-eyebrow-chip]` appear as rule tags
  on findings; the install offer does not appear, and no other question is put to the owner except
  gstack's telemetry-consent question, which comes back on every run while its marker is unset and
  the guideline already covers. The baseline is the earlier spike's reports ("Detector: not
  installed", the offer declined); no control run. A helper that can't start its browser is a
  could-not-run, re-run once; a second is recorded, no pass is claimed, and the owner hears it.
  Rejected: a CI test of the review (CI runs no LLM jobs) (Claude's proposal, 2026-11-01)
- **Not here:** gstack's pin (its own change; this one follows it); the `/impeccable` skill, its
  editor hook and its installer (a second design voice, spec A); any wall on detector findings (it is
  feedback: the design review fixes High on the touched lines as today, CI and the owner's approval
  stay the walls); `pr-body-check.py`, the reviewer's prompt, `build`'s and `pr`'s skills (the
  review step and the Evidence line are already theirs)

## Acceptance items

- **AC-1** `install/impeccable.sh`, given `install/impeccable.pin` and a registry answering the
  tarball, places `<home>/.impeccable/bin/<version>/impeccable` with mode 0755 and the pinned
  sha256, removes other version directories beside it, and prints `placed <path>`; a pin line not
  `<version> <sha256>`, a failed fetch, a tarball without `package/bin/impeccable` and a checksum
  mismatch each place nothing, remove nothing and exit non-zero saying why; `tests/bootstrap.test.sh`
  replays each through the bootstrap against its fake registry, with `~/.impeccable` cleared
  between cases, fails without the change and passes with it
- **AC-2** `install/bootstrap.sh` runs the step after the gstack step: the engine lands under
  `$HOME` and the log says `impeccable <version> placed <path>`; when the script fails, the log says
  `FAILED: impeccable: <why>`, `RESULT: bootstrap FAILED`, and the plugin is still installed;
  `tests/bootstrap.test.sh` proves both
- **AC-3** `install/impeccable.pin`'s `gstack <commit>` line names `install/gstack.pin`'s commit at
  HEAD, and `tests/bootstrap.test.sh` fails when it doesn't
- **AC-4** `tests/design-detector.test.sh` is slow-tier and, with the pinned engine at gstack's
  path: the planted fixture exits 2 and names `ai-color-palette`, `overused-font` and
  `hero-eyebrow-chip`; the UI template exits 0 with an empty `--json --no-advisory` list; a missing
  target exits 1; the engine's sha256 equals the pin; and with no engine it exits 2, never 0, naming
  the command that places one
- **AC-5** `.github/workflows/ci.yml`'s `slow` job runs
  `install/impeccable.sh install/impeccable.pin "$HOME"` before `scripts/check-slow.sh`, and
  `tests/ci-tiers-check.test.sh` fails when that command is missing
- **AC-6** `runtime/guidelines/ui.md` § Design review has the two sentences and nothing else in the
  file changes; `runtime/templates/pr-body.md`'s Design review line carries the detector words;
  `runtime/scripts/pr-body-check.py` is unchanged and `tests/pr-body-check.test.sh` passes;
  `install/README.md` explains the step, the pin and what the script removes; `CLAUDE.md`'s
  `tests/run.sh` line and `docs/README.md`'s slow-tier line name the engine and the one-time
  command; `docs/README.md` links the spike and `scripts/docs-map-check.py` passes — verified by
  review: the diff and CI on the PR's head
- **AC-7** The spike record holds the grading (committed before the run), the scratch site, the
  script's live run, the helper's prompt and report verbatim, and the result against the pass rule
  in Decisions, could-not-runs included — verified by review: the record and its commits' order
- **AC-8** The PR's Evidence shows each mutant in Decisions run once and failing — verified by
  review: the PR body
- **AC-9** `kit/notes/revamp/LOG.md` has an entry — verified by review: the diff

## Out of scope

- Moving the gstack pin, or any engine version the pinned gstack hasn't tested
- The `/impeccable` skill, its editor hook, its installer and `npx impeccable` (spec A: no second
  design voice); a project-level `.impeccable/` config
- Platforms other than Linux x86_64 (the Mac and the iOS stack are M4)
- A CI gate or check script on detector findings, in the devshop or in projects
- The `DESIGN.md` shape check (spec C) and the React home's defaults (spec D)
- Any change to `pr-body-check.py`, the reviewer's prompt or `review.sh`, `build` or `pr`
- gstack's browser check (F-NEW-101) and the rest of F-NEW-87
