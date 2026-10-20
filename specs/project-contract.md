# One project contract: what every project must provide, checked

**Go:** pending

## Intent

R-13 ([ROADMAP.md](../ROADMAP.md)), with R-12 as its first entry. The owner, 2026-10-19 and
2026-10-20, after the survey of every name the devshop relies on finding in a project
([the audit](../kit/notes/revamp/project-contract-audit-2026-10-19.md): 39 items, 9 written down,
13 places where two components disagree):

> i think we should think really hard if the devshop will work or not to work on different
> projects and be cionsistent across them

> the project can be cloned by otuside collaborators and should work (they can run locally,
> submit PRs) without access to devshop

> the generic tooling lives on devshop, and the particular lives in each project

The shape the owner accepted ("yes", then "do step 0", 2026-10-20): one file in `runtime/` lists
every name the devshop relies on in a project, with its owner, what it must do and who relies on
it; one check reads that file at session start and in the project's `fast` tier, required items
red when missing or malformed, optional ones named as absent, never silent; the duplicates
collapse while writing it down; the manifest grows to cover what the upgrade claims to re-copy; a
stack home declares which optional items it supplies; R-12's `pr-title-check.py` enters as the
first entry. Then one short PR per project (website, fixture) from what the check reports, in
their own sessions. F-NEW-105 (what the project's `CLAUDE.md` says to a collaborator who moves the
project away from the contract) is part of this.

## Decisions

- **The contract is `runtime/project-contract.txt`**, a text file read by people and by the check,
  in blocks separated by blank lines (`#` starts a comment). Each block is one item, one
  `key: value` line per field, every field required, no other key:
  - `item`: the path in the project, relative to its root; a trailing `/` means a directory. It
    names files in the project, never a devshop path (owner, 2026-10-20: collaborators run the
    project with no devshop; the devshop only checks).
  - `owner`: `devshop` (an identical copy of a devshop file, replaced whole by the upgrade), `seed`
    (placed once from a template, then the project's own) or `project` (the project writes it).
  - `when`: `required` or `optional`. Two fields instead of the accepted four owners (`devshop`
    copy, seed, project-owned, optional), because the UI checks are optional _and_ devshop copies:
    absent in a project with no UI, identical to the devshop's where present. The go screen asks
    (open question 1).
  - `check`: what the check verifies, one of `file` (a regular file with content, not a symlink),
    `executable` (a `file` with its executable bit on disk and, when tracked, committed as
    `100755`), `directory`, `version-pin` (one line, a release tag `vX.Y.Z` or a 40-hex commit
    SHA, the two forms the dispatcher accepts; `init` still writes only a tag).
  - `must`: what the item must do, in one or two sentences, for the collaborator and the reviewer.
  - `for`: who relies on it (CI's job, a devshop script, a skill), so a change to either side finds
    the other.
    Rejected: YAML or JSON (the check runs in project CI, where only the Python standard library is
    sure to exist: PyYAML is what keeps `ci-tiers-check.py` out of project CI today; JSON holds prose
    badly); a Markdown table (a project's formatter reflows it, and a `devshop` copy must stay
    byte-identical); embedding the contract in the check script (two sources that drift) (Claude,
    2026-10-20)
- **The items.** Required: `.devshop-version` (project, version-pin), `.github/CODEOWNERS`
  (project, file), `.github/workflows/ci.yml` (seed, file), `scripts/check-fast.sh` and
  `scripts/check-slow.sh` (seed, executable), `scripts/secret-scan.sh`, `scripts/spec-check.py`,
  `scripts/pr-title-check.py`, `scripts/contract-check.py` and `scripts/deploy-comment.mjs`
  (devshop, executable; the last one `file`), `scripts/project-contract.txt` (devshop, file),
  `.gitleaks.toml` (seed, file), `specs/` (project, directory), `CLAUDE.md` (seed, file). Optional:
  `scripts/setup.sh`, `scripts/lint.sh`, `scripts/lint-file.sh`, `scripts/deploy.sh`,
  `scripts/local-run.sh` (project, executable), `scripts/ui/tokens-check.mjs` and
  `scripts/ui/render-check.mjs` (devshop, file), `DESIGN.md`, `ROADMAP.md`, `FINDINGS.md`,
  `docs/README.md` (project, file). Not items: `tests/README.md` and `specs/.gitkeep` (seeds that
  only start a project; `TEST_DIRS` in `check-fast.sh` says where tests live, so `tests/` is the
  project's choice), the audit's rows that are GitHub settings (squash only, environments, branch
  protection: the owner's steps), a pin inside `package.json` (the UI checks exit 2 themselves),
  the reviewer's allowlist (row 35), screenshots (row 12), the deploy-facts file (row 38, never
  built). Stack-only names (`wrangler.jsonc`, `.nvmrc`, `scripts/build.sh`, `quality/routes.json`,
  the preview files) stay in their stack home, not in the generic contract (owner: "the generic
  tooling lives on devshop, and the particular lives in each project") (Claude, 2026-10-20)
- **One check, `runtime/scripts/contract-check.py`**, placed in the project as
  `scripts/contract-check.py` beside its contract copy `scripts/project-contract.txt`, both
  `devshop` copies, so a plain clone runs it with no devshop present. Usage:
  `contract-check.py [--contract FILE] [--project DIR] [--supplies FILE]... [--list]`; the
  defaults are `scripts/project-contract.txt` under the current directory's repo root. It prints
  `<item>: <problem>` for each required item missing or failing its check and for each optional
  item present but failing its check, and `absent (optional): <item>` for each optional item not
  there; exit 0 = every required item holds; 1 = problems; 2 = can't run: no contract, a contract
  it can't parse (unknown or missing key, duplicate item, unknown `owner`, `when` or `check`, a
  path that is absolute or leaves the project), a `--supplies` file naming an item that isn't an
  optional item of the contract, bad arguments. `--list` prints every item with its fields, for
  the collaborator; it is how the project's `CLAUDE.md` points at the contract without copying
  it. Standard library only (Claude, 2026-10-20)
- **In the project's `fast` tier:** `runtime/templates/check-fast.sh` runs
  `part scripts/contract-check.py` after the spec check. A project that adapted its `check-fast.sh`
  adds the line itself; the upgrade shows the seed's change (Claude, 2026-10-20)
- **At session start:** `session-start.sh` runs the version's own copy,
  `/opt/devshop-current/scripts/contract-check.py --contract /opt/devshop-current/project-contract.txt --project <top>`,
  plus `--supplies <home>/supplies` for each stack home `stack-homes.sh` prints that has one, so a
  project missing its copy is still checked. Exit 1 or 2 is one `DEVSHOP:` line naming the items
  and problems (or why it couldn't run). Absent optional items go out as one plain line to Claude,
  not a `DEVSHOP:` line: "never silent", but a list the owner would read at every session's start
  is noise (open question 3). When the project has neither `.devshop-version` nor
  `.github/workflows/ci.yml`, the line is instead one sentence pointing at `/devshop:new-project`,
  replacing today's "start from the devshop's two-tier template" (F-NEW-116). `ci-tiers-check.py`
  and `project-files.py check` stay beside it as today: the first needs PyYAML (the image has it,
  project CI doesn't) and checks the _shape_ of an item the contract only requires to exist; the
  second needs the devshop git dir to compare copies. The contract check is the one place that
  says what must be there; those two say whether two of the items are right (open question 2)
  (Claude, 2026-10-20)
- **A stack home declares what it supplies** in `runtime/stacks/<stack>/supplies`: one optional
  contract item per line (`#` comments). When the stack applies, those items are required at
  session start; in project CI, where no devshop is present, they stay optional. A `supplies` line
  naming anything but an optional contract item is can't-run, never skipped. The Cloudflare home
  supplies `scripts/setup.sh`, `scripts/deploy.sh`, `scripts/local-run.sh` and
  `scripts/ui/render-check.mjs`. A home with no `supplies` supplies nothing (Claude, 2026-10-20)
- **The manifest grows and gains `optional`:** `runtime/project-files.txt` adds
  `devshop scripts/pr-title-check.py scripts/pr-title-check.py`,
  `devshop runtime/scripts/contract-check.py scripts/contract-check.py`,
  `devshop runtime/project-contract.txt scripts/project-contract.txt`, and, with a fourth field
  `optional`, `runtime/templates/ui/tokens-check.mjs` → `scripts/ui/tokens-check.mjs` and
  `runtime/templates/ui/render-check.mjs` → `scripts/ui/render-check.mjs`, which
  `runtime/guidelines/ui.md` already says the upgrade re-copies. `project-files.py`: `check` skips
  an absent optional entry and compares a present one; `init` doesn't place optional entries;
  `plan` shows them; `apply` writes one on request; a fourth field other than `optional` can't
  run. The upgrade skill says so (Claude, 2026-10-20)
- **R-12 enters as the first entry:** the devshop's `scripts/pr-title-check.py` becomes a
  `devshop` copy in every project, its docstring reworded for both (a Conventional Commit type so
  release notes and versions can be computed from the subjects on `main`; no devshop-only file
  named). `runtime/templates/ci.yml`'s `fast` job gains the devshop's own title step (the PR's
  title, or on a push the head commit's first line, passed through `env`), and
  `ci-tiers-check.py` gains the rule that `fast` runs `scripts/pr-title-check.py` in a step
  without its own `if` or `continue-on-error`. `ship.sh` already runs the project's copy when
  present (owner, 2026-10-19: "do it"; placement decided here, 2026-10-20)
- **F-NEW-108 is fixed in passing:** `ci-tiers-check.py` follows `needs` transitively, so a job
  with an `environment` that needs `deploy`, which needs both tiers, passes. It is in a file this
  change edits and the website's canary job is the case (Claude, 2026-10-20)
- **Duplicates collapsed in the same change** (owner's list, 2026-10-20):
  - _One way to start the site locally:_ `scripts/local-run.sh` (`PORT` given, bound to
    `127.0.0.1`, runs until stopped). `runtime/guidelines/ui.md` § Design review starts the app
    with it and says "can't run: no `scripts/local-run.sh`" otherwise, replacing "as the project's
    `CLAUDE.md` or stack home says"; the Cloudflare home's quality bar serves the built site
    through it instead of an inline `wrangler dev`, and names it in Claude's part of the set-up.
    F-NEW-103 closes.
  - _Lint:_ out of the generic required set. `scripts/lint.sh` is an optional item ("the pre-push
    hook runs it when present; `check-fast.sh` runs it where the stack home says so"); the install
    README's "The repo declares its checks" paragraph points at the contract instead of listing
    `lint.sh` as declared by every repo. The ci-fast-slow-tiers spec stays as the 2026-10-13
    record; the contract is what holds now.
  - _One routes-list name:_ `quality/routes.json`; the Cloudflare home drops the fixture's
    `traffic/routes.json` alias (the fixture's PR renames).
  - _One AC-naming rule_, stated once in the `tests/README.md` seed and pointed at from the
    Cloudflare home: a test names the item it proves as `AC-<n>`, and puts the spec's file name
    before it (`<spec> AC-<n>`) once the repo has more than one spec, since `spec-check.py`
    matches numbers per spec (F-NEW-92). The reviewer's prompt (`AC-<n>` in the test's title or
    body) already accepts both (open question 4).
  - _What a project holds:_ the install README's "one file" becomes "the contract's items".
- **The project `CLAUDE.md` seed** (F-NEW-105) gains, under Rules: what this repo must keep is
  listed by `scripts/contract-check.py --list` and checked by `scripts/check-fast.sh`; the files
  it marks `devshop` are copies kept identical and replaced whole on an upgrade, not edited here;
  a change that needs to move away from an item (rename, drop, do it another way) doesn't change
  or skip the check: it tells the owner and proposes a path. The seed names the devshop by name
  where the contract does (`owner: devshop`), never by path (Claude, 2026-10-20)
- **Findings** (owner, 2026-10-20: the PR body says for each of F-NEW-103 and F-NEW-106 to
  F-NEW-116 whether R-13 closes it, it moves to a stack home, or it stays; F-NEW-110 already moved
  in PR #148). Closed here: F-NEW-103, F-NEW-108, F-NEW-116, rows deleted. Moved to the Cloudflare
  home's canary paragraph, rows deleted: F-NEW-107 (a canary job can't share the deploy's
  concurrency group) and F-NEW-109 (a health check holding a secret runs on `pull_request_target`
  from `main`), facts a second Cloudflare project needs (open question 5). Stay: F-NEW-106,
  F-NEW-111 to F-NEW-115. `ROADMAP.md`: R-12 and R-13 `Done` with this PR; `LOG.md` gets the
  session's entry (Claude, 2026-10-20)
- **Proof:** every check ships proven to fail (CLAUDE.md): `tests/contract-check.test.sh` feeds the
  check known-bad projects, contracts and `supplies` files, and its mutants are killed; the real
  contract, manifest and templates are tied together by a test, so adding to one without the
  others is red. The project copies carry no `/opt/devshop` path (`tests/new-project.test.sh`
  already greps). Feedback, not a wall: the check is a CI failure and a session-start line;
  required CI and the owner's approval are the walls (Claude, 2026-10-20)
- **Project impact:** the website and the fixture go red at session start and, once they take the
  new `check-fast.sh` line, in `fast`, until their one short PR each (owner, 2026-10-20: "step 2
  one short PR per project from what the check reports", in their own sessions). This change
  touches neither repo (Claude, 2026-10-20)

## Acceptance items

- **AC-1** `runtime/project-contract.txt` lists every item of the Decisions' list, each block with
  exactly the fields `item`, `owner`, `when`, `check`, `must`, `for`, no item twice, no devshop path
  in `item`; `contract-check.py --list` on it prints every item with its fields. Shown by a test on
  the real file
- **AC-2** `contract-check.py` on a project holding every required item exits 0 and prints
  `absent (optional): <item>` for each optional item not there and nothing else about them; exits 1
  with `<item>: <problem>` for each of: a required `file` missing, empty, a symlink or a directory;
  a required `executable` without its bit on disk, or committed `100644`; a `directory` item that
  is a file; `.devshop-version` empty, two lines, or neither `vX.Y.Z` nor 40 hex; an optional
  `executable` present without its bit; an optional item named by `--supplies` and absent (and
  nothing for the same project without `--supplies`); and exits 2, naming the reason, for: no
  contract; a block with an unknown key, a missing key, an unknown `owner`, `when` or `check`, an
  `item` that is absolute or leaves the project, or an `item` listed twice; a `--supplies` file
  naming a required item or one not in the contract. Shown by a test feeding each case
- **AC-3** `runtime/templates/check-fast.sh` runs `scripts/contract-check.py` as a part after the
  spec check; a failing contract check gives exit 1 with the other parts still run, a missing
  `scripts/contract-check.py` exit 2. Shown by `tests/check-fast-template.test.sh`
- **AC-4** A project placed by `init` passes its fast tier with every `/opt/devshop*` hidden, the
  contract check included, and fails it, naming the item, when `scripts/check-slow.sh` is deleted.
  Shown by `tests/new-project.test.sh`
- **AC-5** Session start prints exactly one `DEVSHOP:` line about the contract, naming each item
  and problem, when the version's `contract-check.py` exits 1, and one saying it couldn't run on
  exit 2; prints the absent optional items on one line that doesn't start with `DEVSHOP:`; prints
  nothing about the contract when every item holds and none is absent; makes an applying stack
  home's `supplies` items required (shown with a stack fixture); and in a project with neither
  `.devshop-version` nor `.github/workflows/ci.yml` prints one `DEVSHOP:` line naming
  `/devshop:new-project` and no line about missing items or the CI template. Shown in
  `tests/git-hooks.test.sh`
- **AC-6** `runtime/project-files.txt` has the five new entries of the Decisions, the two UI checks
  marked `optional`; `project-files.py check` exits 0 with an optional entry absent and 1 when it is
  present and differs; `init` writes no optional entry; `plan` lists an optional entry with its
  state; `apply` writes one; a manifest line with a fourth field other than `optional`, or five
  fields, is exit 2. Shown by `tests/project-files.test.sh`
- **AC-7** `ci-tiers-check.py` exits 1, naming the rule, when `fast` has no step running
  `scripts/pr-title-check.py`, or only one with its own `if` or `continue-on-error`; exits 0 for a
  job with an `environment` whose `needs` reach `fast` and `slow` through another job (F-NEW-108)
  and still 1 when they don't; `runtime/templates/ci.yml` (with the title step) and this repo's
  `ci.yml` pass. Shown by `tests/ci-tiers-check.test.sh`
- **AC-8** `scripts/pr-title-check.py`'s docstring names no file that exists only in the devshop,
  and the title it accepts and refuses is unchanged. Shown by `tests/pr-title-check.test.sh` and a
  grep in the manifest test
- **AC-9** Every `runtime/stacks/<stack>/supplies` names only optional items of the contract, and
  `runtime/stacks/cloudflare/supplies` names the four of the Decisions. Shown by a test over the
  real stack homes
- **AC-10** The real contract, manifest and templates agree: every manifest `devshop` entry's
  project path is a contract item with `owner: devshop`; every contract item with `owner: devshop`
  or `seed` is in the manifest with that owner; every `scripts/<name>` the template `ci.yml` and
  `check-fast.sh` run is a contract item. Shown by a test, which fails when one of them is edited
  alone
- **AC-11** Docs collapsed and pointed at the contract: `runtime/guidelines/ui.md` § Design review
  starts the app with `scripts/local-run.sh` and the phrase "as the project's `CLAUDE.md` or stack
  home says" is gone from `runtime/`; the Cloudflare home's quality bar serves through
  `scripts/local-run.sh`, `traffic/routes.json` is gone, its AC-naming paragraph points at
  `tests/README.md`'s rule and its canary paragraph carries F-NEW-107 and F-NEW-109; the
  `tests/README.md` seed states the rule; the project `CLAUDE.md` seed has the contract and
  departure rules; `install/README.md`, `docs/README.md`, `runtime/stacks/README.md` and the
  upgrade skill describe the contract, `supplies` and optional copies — verified by review: the
  diff and a grep for the removed phrases
- **AC-12** Records: F-NEW-103, F-NEW-107, F-NEW-108, F-NEW-109 and F-NEW-116 rows deleted; R-12
  and R-13 `Done` with this PR's number; the LOG entry — verified by review: the diff

## Out of scope

- The website's and the fixture's PRs: their own sessions, from what the check reports
- A wall: the contract check is feedback (a CI failure, a session-start line); GitHub's protection,
  required CI and the owner's approval stay the walls
- Running `ci-tiers-check.py` in project CI (it would need PyYAML in every project's CI), or
  comparing `devshop` copies there (it would need the devshop)
- Contract items for stack-only names (`wrangler.jsonc`, `.nvmrc`, `scripts/build.sh`,
  `quality/routes.json`, the preview files): they stay in their stack home's prose; tested stack
  templates wait for a second Cloudflare project (F-NEW-100)
- Checking what a script does (that `deploy.sh` writes its seven outputs, that `local-run.sh`
  binds `127.0.0.1`): the contract states it in `must`; the tool that relies on it fails loudly
  when it doesn't
- The reviewer's command allowlist (audit row 35), PR screenshots (row 12), a deploy-facts file
  (row 38), GitHub settings (rows 31 to 33)
- Changing the reviewer's prompt or `review.sh`: they already read `scripts/check-fast.sh` and
  `scripts/local-run.sh` at the base
