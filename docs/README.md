# Docs map

Every doc in this repo is linked from here, in a hierarchy (TARGET § Build 3). A new doc gets
a line here in the same change, and a removed one loses its line. CI holds this:
[`scripts/docs-map-check.py`](../scripts/docs-map-check.py) fails when a Markdown file is not
reachable from this page through links, or when a relative link or `#anchor` is broken.

## The repo

- [README.md](../README.md): what the devshop is, its status, and the repo layout.
- [CLAUDE.md](../CLAUDE.md): rules for Claude working in this repo.
- [ROADMAP.md](../ROADMAP.md): what the owner decided will happen to the devshop, in priority
  order; the top `Open` entry is the next task.
- [FINDINGS.md](../FINDINGS.md): what Claude noticed and didn't fix, kept to see what comes back
  ([spec](../specs/findings-and-roadmap.md)).

## Releases

SemVer tags from `v2.0.0` (D-10); a major release needs a migration. Every PR title starts with a
Conventional Commit type ([`scripts/pr-title-check.py`](../scripts/pr-title-check.py): CI's fast
job and `ship.sh` run it), and the squash merge makes the title the subject on `main`. To release,
the owner clicks "Run workflow" on [`release.yml`](../.github/workflows/release.yml) in the
Actions tab, on `main`: its first step refuses anyone but the repository's owner and any branch
but `main` (feedback against accidents, not a wall: a branch carrying its own workflow could still
create a tag, F-NEW-96); [`scripts/release.py`](../scripts/release.py) `plan` computes the next version from the
subjects since the last release (`!` major, `feat` minor, `fix`/`perf`/`revert` patch, nothing
else releases) and its notes, unless the button's "Manual override" input picks `major`, `minor` or
`patch` instead of `auto` (for a title that got the type wrong; the notes then say so); then CI creates the tag on `main`'s head and the GitHub release with
those notes (a session can't push tags, A-25). There is no release PR and no changelog file: the
notes are on each release's page, and the owner's release immutability setting locks a published
release's tag. `scripts/release.py next` previews the next release from a full clone with tags.
Projects pin the tag; `/devshop:upgrade` defaults to the newest one. Proven by
[`tests/release.test.sh`](../tests/release.test.sh) and
[`tests/pr-title-check.test.sh`](../tests/pr-title-check.test.sh).

## Checks

- CI ([`ci.yml`](../.github/workflows/ci.yml)) runs two tiers, the required checks on `main`
  ([spec](../specs/ci-fast-slow-tiers.md)): job `fast` runs [`scripts/check-fast.sh`](../scripts/check-fast.sh)
  (the secret scan, lint and every test not marked slow), then job `slow` runs
  [`scripts/check-slow.sh`](../scripts/check-slow.sh) (the tests marked `# tier: slow`: the whole
  install, the UI render check and the reviewer's `devshop-browse` in Chromium, at the Playwright version `package.json` pins). A test is slow when it tests the system end to end, not because it takes long.
  `tests/run.sh fast|slow` runs one tier, `tests/run.sh` all. Proven by
  [`tests/check-tiers.test.sh`](../tests/check-tiers.test.sh) and
  [`tests/run-tiers.test.sh`](../tests/run-tiers.test.sh).
- The devshop's release: on `main`, after both tiers, the same `announce`, `deploy` and `report` jobs
  as a project's give the merged PR its deploy comment (Checking on `main`, then On `main`,
  ships in the next release, since a release tag ships it); [`scripts/deploy.sh`](../scripts/deploy.sh) deploys nothing and writes what the comment
  reads ([spec](../specs/devshop-deploy-comment.md); proven by
  [`tests/deploy-sh.test.sh`](../tests/deploy-sh.test.sh) and
  [`tests/ci-template-deploy.test.sh`](../tests/ci-template-deploy.test.sh)).
- Secret scanning: [`.gitleaks.toml`](../.gitleaks.toml) is gitleaks' default rule set. CI's fast
  tier first runs [`scripts/secret-scan.sh`](../scripts/secret-scan.sh) over the commits a change
  adds and the whole tree, then, with the other tests,
  [`tests/gitleaks.test.sh`](../tests/gitleaks.test.sh), which commits fake secrets to a scratch
  repo and fails unless every one is caught; [`tests/secret-scan.test.sh`](../tests/secret-scan.test.sh)
  proves the scan fails on a secret in either place. To run it locally, install gitleaks (the
  version pinned in `ci.yml`) and run `tests/run.sh`.
- Lint: CI's fast tier runs [`scripts/lint.sh`](../scripts/lint.sh), the same script the devshop's
  pre-push hook runs in a session; [`scripts/lint-file.sh`](../scripts/lint-file.sh)
  is the per-file version the per-edit nudge runs. Each check is a script proven by the test of the
  same name in `tests/` (it feeds a known-bad input, and a missing tool fails):
  - [`format-check.sh`](../scripts/format-check.sh): `prettier --check .` with the version
    [`package.json`](../package.json) pins (`npm ci` installs it); `.prettierignore` skips the spikes.
  - [`shellcheck.sh`](../scripts/shellcheck.sh): shellcheck (version pinned in `ci.yml`) over every
    shell script, found by extension or shebang; the spikes are skipped.
  - [`commit-identity-check.sh`](../scripts/commit-identity-check.sh): rejects commits a change adds
    under a test identity, such as the one tests commit as (L-41).
  - [`docs-map-check.py`](../scripts/docs-map-check.py): this page's rule, above.
  - [`ci-tiers-check.py`](../runtime/scripts/ci-tiers-check.py) on this repo's own `ci.yml` (below).
- Skills: [`scripts/skills-check.py`](../scripts/skills-check.py) checks every skill in
  `runtime/skills/` and the install plugin's own (`--plugin-skills`) names itself after its
  directory, has a description, names only `/opt/devshop-current/` files its
  version has and hands over only to skills that exist (`devshop:<name>`); no two share a name, and
  all the descriptions together stay within the always-loaded budget, 200 words (TARGET Shape 2).
  A skill past one page (60 lines, 600 words) is a warning, not a failure (D-17).
  Run on the real skills by
  [`tests/skills-check.test.sh`](../tests/skills-check.test.sh), after feeding it bad ones.

## Skills

- [`devshop-version`](../runtime/skills/devshop-version/SKILL.md): which devshop version a session
  runs and how old its local copy is.
- [`intent`](../runtime/skills/intent/SKILL.md): the start of every request: its kind, then for a
  change the spec, the adversarial spec review and the owner's "go" (TARGET § L3 Intent).
- [`build`](../runtime/skills/build/SKILL.md): one writer builds code, tests and docs together,
  loads what applies, and hands over to `pr` (TARGET § L3 Build).
- [`pr`](../runtime/skills/pr/SKILL.md): the PR for a built change: the body from the template,
  screenshots, `ship.sh` through the reviewer, low findings, telling the owner (TARGET § L3 Review).
- [`new-project`](../runtime/skills/new-project/SKILL.md): a new repo's first session places the
  devshop's files and opens the first PR with green CI (below, New project).
- [`upgrade`](../install/plugin/devshop/upgrade/skills/upgrade/SKILL.md): moves a
  project's `.devshop-version` in one PR, bringing its copies of devshop files along (below, Project
  files). It comes with the installed plugin, not the pinned version, so any pin has it; its
  [`project-files-at.sh`](../install/plugin/devshop/upgrade/project-files-at.sh) runs the target
  version's script (proven by [`tests/project-files-at.test.sh`](../tests/project-files-at.test.sh)).

## Specs

One file per change in [`specs/`](../specs), kept after merge as context (TARGET § L3 Intent).

- [`ci-fast-slow-tiers.md`](../specs/ci-fast-slow-tiers.md): CI in two tiers, fast and slow, for
  the devshop and every project.
- [`deploy-and-metrics-comments.md`](../specs/deploy-and-metrics-comments.md): a merged PR's deploy
  comment follows the deploy to a final state, then the session posts how the change went.
- [`devshop-deploy-comment.md`](../specs/devshop-deploy-comment.md): the devshop's own PRs follow
  their release, and the metrics count every reviewer round.
- [`design-first-spec-review.md`](../specs/design-first-spec-review.md): design questions first in
  the spec review, replayed and dropped (they missed the case they were for); the finding is
  F-NEW-65.
- [`design-review-in-build.md`](../specs/design-review-in-build.md): build runs gstack's
  `/design-review` on a local run of every UI change before it ships.
- [`findings-and-roadmap.md`](../specs/findings-and-roadmap.md): every repo keeps a roadmap of
  what the owner decided and a findings log of what Claude noticed.
- [`metrics-hours.md`](../specs/metrics-hours.md): the metrics comment shows hours and minutes
  from an hour up.
- [`metrics-clock-after-merge.md`](../specs/metrics-clock-after-merge.md): a change the session
  starts on its own is timed from the previous merge.
- [`new-project.md`](../specs/new-project.md): a new project starts from the devshop with
  green CI: the files placed, the owner's steps and the proof on a fresh repo.
- [`pinned-tools-on-path.md`](../specs/pinned-tools-on-path.md): the project's own checks find the
  devshop's pinned gitleaks, shellcheck and dcg on PATH.
- [`project-contract.md`](../specs/project-contract.md): one project contract, what every project
  must provide, checked at session start and in its `fast` tier.
- [`reviewer-browser.md`](../specs/reviewer-browser.md): the reviewer judges a local run of the
  site against `DESIGN.md`, with a browser that reaches only that run.
- [`ui-baseline.md`](../specs/ui-baseline.md): every web app starts from a design baseline, phone
  first, light and dark.

## The install

- [install/README.md](../install/README.md): how a project's cloud session gets the devshop version
  it pins (`.devshop-version`), what each `DEVSHOP:` line means, the devshop's git hooks, per-edit
  nudge and Bash guard (dcg), and the limits. Proven by [`tests/bootstrap.test.sh`](../tests/bootstrap.test.sh),
  [`tests/git-hooks.test.sh`](../tests/git-hooks.test.sh),
  [`tests/post-edit.test.sh`](../tests/post-edit.test.sh) and
  [`tests/pre-bash.test.sh`](../tests/pre-bash.test.sh).

## What projects get (`runtime/`)

- PR body: [`runtime/templates/pr-body.md`](../runtime/templates/pr-body.md) is the template for
  every project PR (TARGET § L3 Review): one-line summary, a 2–3 sentence paragraph, preview link,
  announcement (a release note in the app user's words, only when user-facing), what you should
  know, evidence, then engineering details collapsed.
  [`runtime/scripts/pr-body-check.py`](../runtime/scripts/pr-body-check.py) checks a filled-in
  body has that shape (the summary line, sections and labelled lines in order, preview present,
  screenshots on the PR or "no UI change", no placeholder left, images pinned to a commit and never
  on `raw.githubusercontent.com`); it judges no words (W10.9.2): the paragraph's length and the
  announcement's wording are guidance the reviewer and the owner check. `ship.sh` runs it before every review and refuses a body without the
  shape (F-NEW-52). Proven by [`tests/pr-body-check.test.sh`](../tests/pr-body-check.test.sh).
- PR screenshots: [`runtime/scripts/pr-assets.sh`](../runtime/scripts/pr-assets.sh) puts them in
  one parentless commit and moves the PR's branch to a merge of HEAD and that commit whose files
  are HEAD's, so the PR's files and diff don't change and nothing needs removing. `ship`'s push of
  the branch carries them to GitHub, which keeps them with the PR after the merge. It prints the
  image lines (`https://github.com/<owner>/<repo>/raw/<sha>/<file>`) for the body's
  **Screenshots:**, and refuses a repo that allows merge commits or rebase merges (they would carry
  the images into the default branch). The GitHub mobile app doesn't show them for a private repo
  (F-NEW-50, open). Proven by
  [`tests/pr-assets.test.sh`](../tests/pr-assets.test.sh), which also walks a PR's life on a local
  remote: retakes, fix rounds, a squash merge, the branch deleted, a fresh clone.
- Roadmap and findings: [`runtime/templates/roadmap.md`](../runtime/templates/roadmap.md) and
  [`runtime/templates/findings.md`](../runtime/templates/findings.md) are the templates, rules
  included, for every repo's root `ROADMAP.md` (what the owner decided) and `FINDINGS.md` (what
  Claude noticed); a project creates each on its first entry
  ([spec](../specs/findings-and-roadmap.md)).
- Spec: [`runtime/templates/spec.md`](../runtime/templates/spec.md) is the template for a change's
  spec in the project's `specs/` (TARGET § L3 Intent 2): intent, decisions, acceptance items
  `AC-<n>`, core flow and states for UI, out of scope, and the owner's recorded "go".
  [`runtime/scripts/spec-check.py`](../runtime/scripts/spec-check.py) checks that shape (`--go`:
  the go is recorded; `--tests <dir>`: every `AC-<n>` not "verified by review" is named by a test,
  run by the project's CI). Proven by [`tests/spec-check.test.sh`](../tests/spec-check.test.sh).
- CI: [`runtime/templates/ci.yml`](../runtime/templates/ci.yml) is every project's CI in two tiers
  ([spec](../specs/ci-fast-slow-tiers.md)): `fast` runs the PR title check
  ([`scripts/pr-title-check.py`](../scripts/pr-title-check.py), the project's copy) and the project's
  `scripts/check-fast.sh "$BASE"`
  (template [`runtime/templates/check-fast.sh`](../runtime/templates/check-fast.sh): secret scan; the
  spec check with `--tests`, so an acceptance item no test names fails CI; the contract check; lint
  where the project has `scripts/lint.sh`; unit tests; proven by
  [`tests/check-fast-template.test.sh`](../tests/check-fast-template.test.sh)), `slow` needs it and runs `scripts/check-slow.sh` (end-to-end
  tests; a project with none yet has one that says so). On `main`, its `deploy` job runs the
  project's `scripts/deploy.sh` after both tiers, and the merged PR gets one deploy comment that
  follows it (Merged → Deploying → Live, or a final state saying why not):
  [`runtime/scripts/deploy-comment.mjs`](../runtime/scripts/deploy-comment.mjs), a copy the project
  keeps, run by the template's `announce`, `deploy` and `report` jobs; the template's comments name the
  outputs `deploy.sh` writes for it ([spec](../specs/deploy-and-metrics-comments.md); proven by
  [`tests/deploy-comment.test.sh`](../tests/deploy-comment.test.sh) and
  [`tests/ci-template-deploy.test.sh`](../tests/ci-template-deploy.test.sh)). The stack-specific part
  lives in those scripts, so the template is the same for every stack.
- How a change went: once the deploy comment is final, the session posts a second comment on its
  merged PR (time from the request to live, Claude working, waiting on the owner, deploying; the
  owner's input; cost; pushes, red CI runs, reviewer rounds), `devshop:pr` § 5 checking in with
  `send_later`. [`runtime/scripts/change-metrics.sh`](../runtime/scripts/change-metrics.sh) gathers
  the PR's data with `gh api` and posts;
  [`runtime/scripts/change-metrics.py`](../runtime/scripts/change-metrics.py) computes every number
  from it and the session's transcript ([spec](../specs/deploy-and-metrics-comments.md); proven by
  [`tests/change-metrics.test.sh`](../tests/change-metrics.test.sh), on a fixture rebuilt from a real
  change and anonymised). [`runtime/scripts/ci-tiers-check.py`](../runtime/scripts/ci-tiers-check.py)
  checks a workflow has that shape; session start runs it on the project's and says so in a
  `DEVSHOP:` line. Proven by [`tests/ci-tiers-check.test.sh`](../tests/ci-tiers-check.test.sh).
- The project contract: [`runtime/project-contract.txt`](../runtime/project-contract.txt) lists every
  item the devshop relies on finding in a project, with its owner (`devshop` copy, `seed`, `project`),
  whether it is required or optional, what the check verifies, what it must do and who relies on it
  ([spec](../specs/project-contract.md)). [`runtime/scripts/contract-check.py`](../runtime/scripts/contract-check.py)
  checks a project against it: as a `devshop` copy in the project's fast tier, and at session start
  with the version's own copy and the applying stack homes' `supplies` (one `DEVSHOP:` line for
  required items missing or malformed, a plain line for absent optional ones). `--list` prints the
  contract for a collaborator. The manifest below and the templates agree with it by test. Proven
  by [`tests/contract-check.test.sh`](../tests/contract-check.test.sh).
- Project files: [`runtime/project-files.txt`](../runtime/project-files.txt) lists each file the
  devshop places in a project and its owner (L-49): `devshop`, an identical copy the project keeps
  (the secret scan, the spec check, the title check, the contract and its check; the UI checks marked
  `optional`, brought only where the project has them), or `seed`, a template the project adapts and
  owns (CI, the fast tier). [`runtime/scripts/project-files.py`](../runtime/scripts/project-files.py) `check`s the
  copies against a version (session start reports drift from the pinned one in a `DEVSHOP:` line),
  `plan`s an upgrade, `apply`s one copy, and `init`s a new project (every entry, `.devshop-version`
  pinned to a `vX.Y.Z` release tag, and `CODEOWNERS`, or nothing). The `upgrade` skill runs
  `check`, `plan` and `apply`; the `new-project` skill runs `init`. Proven by
  [`tests/project-files.test.sh`](../tests/project-files.test.sh).
- New project ([spec](../specs/new-project.md)): the
  [`new-project`](../runtime/skills/new-project/SKILL.md) skill runs `init` in a repo's first
  session and opens its first PR; [the owner's steps](../runtime/templates/new-project-steps.md)
  come before and with it. The seeds that make a bare project green: `check-slow.sh`,
  `gitleaks.toml`, [`tests-readme.md`](../runtime/templates/tests-readme.md), `gitkeep` and a
  [`CLAUDE.md` starter](../runtime/templates/project-claude.md). Proven by
  [`tests/new-project.test.sh`](../tests/new-project.test.sh): a placed project passes its own fast
  and slow tiers with no devshop present, and fails them on a planted secret or an untested item.
- Stack homes: [runtime/stacks/README.md](../runtime/stacks/README.md) is their layout;
  [`runtime/scripts/stack-homes.sh`](../runtime/scripts/stack-homes.sh) picks the ones a project
  uses. Proven by [`tests/stack-homes.test.sh`](../tests/stack-homes.test.sh). The
  [Cloudflare home](../runtime/stacks/cloudflare/README.md) (Workers: the deploy with its rollback
  record, previews in a separate account, the quality bar, the owner's set-up steps, the platform
  controls in use, cloud-session facts) is written from the owner's website and the M1 fixture;
  [`tests/cloudflare-stack.test.sh`](../tests/cloudflare-stack.test.sh) proves it loads only for a
  project with a wrangler config. [`nextjs-supabase/`](../runtime/stacks/nextjs-supabase/README.md)
  is a placeholder until M3.
- Discipline guidelines: [runtime/guidelines/README.md](../runtime/guidelines/README.md). The UI
  guideline [`ui.md`](../runtime/guidelines/ui.md) ([spec](../specs/ui-baseline.md)) starts every
  interface from [`runtime/templates/ui/`](../runtime/templates/ui/): `base.css` (shadcn/ui's token
  names, light and dark), `theme.js` (the theme toggle), an example page, and two checks a project
  copies: `tokens-check.mjs` (every token defined in both themes, contrast pairs; proven by
  [`tests/ui-tokens-check.test.sh`](../tests/ui-tokens-check.test.sh)) and `render-check.mjs`
  (the page in Chromium at 375, 768 and 1280 px in both themes; proven by
  [`tests/ui-render-check.test.sh`](../tests/ui-render-check.test.sh)). Its § Design review is how
  `build` runs gstack's `/design-review` before `ship`
  ([spec](../specs/design-review-in-build.md)).
- Reviewer: [runtime/reviewer/README.md](../runtime/reviewer/README.md) is the independent
  reviewer script, its browser on the project's local run, how it is locked down and what that is
  worth, `ship` (review in the VM, then
  code, words and the verdict comment go on the PR together), the guard that refuses other ways to a
  PR, and its proof ([`tests/reviewer.test.sh`](../tests/reviewer.test.sh),
  [`tests/reviewer-pr.test.sh`](../tests/reviewer-pr.test.sh),
  [`tests/ship.test.sh`](../tests/ship.test.sh),
  [`tests/review-guard.test.sh`](../tests/review-guard.test.sh),
  [`tests/reviewer-browse.test.sh`](../tests/reviewer-browse.test.sh) and
  [`tests/reviewer-eval.test.sh`](../tests/reviewer-eval.test.sh) in CI,
  [`tests/reviewer-live.sh`](../tests/reviewer-live.sh) and
  [`tests/reviewer-browser-live.sh`](../tests/reviewer-browser-live.sh) in a session), and the eval run by hand
  before a change to how it reviews (W10.10.7).

## The revamp (being built)

- [kit/notes/revamp/README.md](../kit/notes/revamp/README.md): start here. It links the plan,
  target picture, decisions, findings, lessons, process and log.
- Spikes, kept as notes (records of what was run, not live code):
  - A-04 reviewer stability: the fixed inputs, an [honest](../kit/notes/revamp/spikes/a04-reviewer/honest/spec.md)
    and a [seeded](../kit/notes/revamp/spikes/a04-reviewer/seeded/spec.md) spec.
  - W10.8.1 UI baseline: the example page as rendered,
    [README](../kit/notes/revamp/spikes/w10-8-ui-baseline/README.md).
  - W10.1.2 install probe: [README](../kit/notes/revamp/spikes/w10-1-2-install/README.md) and its
    [probe skill](../kit/notes/revamp/spikes/w10-1-2-install/plugin/skills/devshop-probe/SKILL.md).
  - W10.1.2b thin install: [README](../kit/notes/revamp/spikes/w10-1-2b-thin/README.md) and its
    [probe skill](../kit/notes/revamp/spikes/w10-1-2b-thin/runtime/skills/devshop-probe2/SKILL.md).
