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

Where a decision below says "asked on the go screen", the owner's answer is recorded on it at the
go, with the date.

- **The contract is `runtime/project-contract.txt`**, a text file read by people and by the check:
  UTF-8 with LF line ends, blocks separated by blank lines, `#` starting a comment line. Each block
  is one item, one `key: value` line per field, every field once, no other key:
  - `item`: the path in the project, relative to its root, as git would spell it (no `./`, `//`
    or `..`; absolute refused); a trailing `/` means a directory and goes with `check: directory`
    only, and the reverse. It names files in the project, never a devshop path, and so does every
    other field: the whole file holds no `runtime/`, `install/`, `kit/` or `/opt/` path (owner,
    2026-10-20: collaborators run the project with no devshop; the devshop only checks).
  - `owner`: `devshop` (an identical copy of a devshop file, replaced whole by the upgrade), `seed`
    (placed once from a template, then the project's own) or `project` (the project writes it).
  - `when`: `required` or `optional`. Two fields instead of the accepted four owners (`devshop`
    copy, seed, project-owned, optional), because the UI checks are optional _and_ devshop copies:
    absent in a project with no UI, identical to the devshop's where present. Asked on the go
    screen.
  - `check`: what the check verifies: `file` (a regular file, not a symlink, with at least one
    non-whitespace byte), `executable` (a `file` with its executable bit on disk and, when `git`
    runs and the file is tracked, committed as `100755`; otherwise the disk bit alone), `directory`
    (a real directory, not a symlink), `version-pin` (the content, surrounding whitespace stripped,
    is one token: a release tag `vX.Y.Z` or a 40-hex commit SHA, the two pins the install README
    documents for `.devshop-version`; `init` still writes only a tag). A `devshop` item's `check` is
    `executable` exactly when its source is committed `100755`, so the contract and
    `project-files.py check` demand the same bit.
  - `must`: what the item must do, in one or two sentences, for the collaborator and the reviewer.
  - `for`: who relies on it, by role (CI's `fast` job, the reviewer, the upgrade, a skill by name),
    never by path, so a change to either side finds the other.
    Rejected: YAML or JSON (the check runs in project CI, where only the Python standard library is
    sure to exist: PyYAML is what keeps `ci-tiers-check.py` out of project CI today; JSON holds prose
    badly); a Markdown table (a project's formatter reflows it, and a `devshop` copy must stay
    byte-identical); embedding the contract in the check script (two sources that drift) (Claude,
    2026-10-20)
- **The items.** Required: `.devshop-version` (project, version-pin), `.github/CODEOWNERS`
  (project, file), `.github/workflows/ci.yml` (seed, file), `scripts/check-fast.sh` and
  `scripts/check-slow.sh` (seed, executable), `scripts/secret-scan.sh`, `scripts/spec-check.py`,
  `scripts/pr-title-check.py`, `scripts/contract-check.py` and `scripts/deploy-comment.mjs`
  (devshop, executable), `scripts/project-contract.txt` (devshop, file), `.gitleaks.toml` (seed,
  file), `specs/` (project, directory), `CLAUDE.md` (seed, file). Optional: `scripts/setup.sh`,
  `scripts/lint.sh`, `scripts/lint-file.sh`, `scripts/deploy.sh`, `scripts/local-run.sh` (project,
  executable), `scripts/ui/tokens-check.mjs` and `scripts/ui/render-check.mjs` (devshop, their
  source's mode), `DESIGN.md`, `ROADMAP.md`, `FINDINGS.md`, `docs/README.md` (project, file). Not
  items: `tests/README.md` and `specs/.gitkeep` (seeds that only start a project; `TEST_DIRS` in
  `check-fast.sh` says where tests live, so `tests/` is the project's choice), `base.css` and
  `theme.js` (the project copies and owns them with its first UI change; placing them in every
  new project would put a UI into projects that have none), the audit's rows that are GitHub
  settings (squash only, environments, branch protection: the owner's steps), a pin inside
  `package.json` (the UI checks exit 2 themselves), the reviewer's allowlist (row 35), screenshots
  (row 12), the deploy-facts file (row 38, never built). Stack-only names (`wrangler.jsonc`,
  `.nvmrc`, `scripts/build.sh`, `quality/routes.json`, the preview files) stay in their stack
  home, not in the generic contract (owner: "the generic tooling lives on devshop, and the
  particular lives in each project") (Claude, 2026-10-20)
- **One check, `runtime/scripts/contract-check.py`**, placed in the project as
  `scripts/contract-check.py` beside its contract copy `scripts/project-contract.txt`, both
  `devshop` copies, so a plain clone, a ZIP download included, runs it with no devshop and no git.
  Usage: `contract-check.py [--contract FILE] [--project DIR] [--supplies FILE]... [--list]`; the
  defaults are the current directory and `scripts/project-contract.txt` under it
  (`check-fast.sh` already changes to the repo root). Standard library only. Stdout gets
  `<item>: <problem>` for each required item missing or failing its check and for each optional
  item present but failing its check, and `absent (optional): <item>` for each optional item not
  there. Exit 0 = no problems (absent optional items are not problems); 1 = problems; 2 = can't
  run, the reason on stderr: no contract, a contract it can't parse (an unknown, missing or
  repeated key, an unknown `owner`, `when` or `check`, a trailing `/` without `check: directory`
  or the reverse, an `item` that is absolute, not git-spelled or leaves the project, an `item`
  listed twice, a devshop path anywhere, CR or a BOM), a `--supplies` file naming anything but an
  optional item of the contract spelled as the contract spells it, bad arguments. `--list` prints
  every item as `<item>  <owner>  <required|optional|required (stack)>` followed by its `must` and
  `for` lines, after the same parse (exit 2 on a bad contract), with `--supplies` applied; it is
  how the project's `CLAUDE.md` points at the contract without copying it. The same item named by
  two `--supplies` files is one requirement (Claude, 2026-10-20)
- **In the project's `fast` tier:** `runtime/templates/check-fast.sh` runs
  `part scripts/contract-check.py` after the spec check. A project that adapted its `check-fast.sh`
  adds the line itself; the upgrade shows the seed's change (Claude, 2026-10-20)
- **At session start, in a pinned project:** when `.devshop-version` exists, `session-start.sh`
  runs the version's own copy under `timeout 30`,
  `/opt/devshop-current/scripts/contract-check.py --contract /opt/devshop-current/project-contract.txt --project <top>`,
  plus `--supplies <home>/supplies` for each stack home `stack-homes.sh` prints (its README paths,
  the `STACKS:` line skipped) that has one, so a project missing its copy is still checked. Exit 1
  or 2 is one `DEVSHOP:` line naming the items and problems (or why it couldn't run, a
  `stack-homes.sh` exit 2 included: then the contract is not checked that session, and the line
  says so). Absent optional items go out as one plain line to Claude, not a `DEVSHOP:` line:
  "never silent", but a list the owner would read at every session's start is noise. Asked on the
  go screen. Without `.devshop-version` there is no agreed contract version, as there is no agreed
  version for the copies check today: a repo with `.github/workflows/ci.yml` and no pin (this
  devshop itself, which is not a project) gets nothing from the contract check, and a repo with
  neither gets one `DEVSHOP:` line pointing at `/devshop:new-project`, replacing today's "start
  from the devshop's two-tier template" (F-NEW-116). Today's "no CI" line goes: a pinned project
  without `ci.yml` hears it from the contract line, and `ci-tiers-check.py` runs, as today, only
  when the file exists. `ci-tiers-check.py` and `project-files.py check` stay beside the contract
  check: the first needs PyYAML (the image has it, project CI doesn't) and checks the _shape_ of an
  item the contract only requires to exist; the second needs the devshop git dir to compare
  copies. The contract check is the one place that says what must be there; those two say whether
  two of the items are right. Asked on the go screen (Claude, 2026-10-20)
- **A stack home declares what it supplies** in `runtime/stacks/<stack>/supplies`: one optional
  contract item per line (`#` comments), spelled as the contract spells it. "Supplies" means the
  home's rules give a project on that stack these items (the Cloudflare home has every project
  carry `scripts/setup.sh` and `scripts/deploy.sh`, and after this change `scripts/local-run.sh`
  and `scripts/ui/render-check.mjs`; it holds no file to copy yet, F-NEW-100), so when the stack
  applies they are required at session start; in project CI, where no devshop is present, they
  stay optional. A `supplies` line naming anything but an optional contract item is can't-run,
  never skipped. A home with no `supplies` supplies nothing (Claude, 2026-10-20)
- **The manifest grows and gains `optional`:** `runtime/project-files.txt` adds
  `devshop scripts/pr-title-check.py scripts/pr-title-check.py`,
  `devshop runtime/scripts/contract-check.py scripts/contract-check.py`,
  `devshop runtime/project-contract.txt scripts/project-contract.txt`, and, with a fourth field
  `optional`, `runtime/templates/ui/tokens-check.mjs` → `scripts/ui/tokens-check.mjs` and
  `runtime/templates/ui/render-check.mjs` → `scripts/ui/render-check.mjs`, which
  `runtime/guidelines/ui.md` already says the upgrade re-copies. `project-files.py`: `check` skips
  an optional entry whose project path doesn't exist (`lexists`: a symlink there is compared and
  reported, as today) and compares a present one; `init` doesn't place optional entries; `plan`
  shows them with their state; `apply` writes one on request; a fourth field other than `optional`,
  five fields, or `optional` on a `seed` is can't-run. The upgrade skill says so, and that a
  project's formatter must leave `devshop` copies alone (the `.mjs` copies are what Prettier would
  rewrite) (Claude, 2026-10-20)
- **R-12 enters as the first entry:** the devshop's `scripts/pr-title-check.py` becomes a
  `devshop` copy in every project, its docstring reworded for both (a Conventional Commit type so
  release notes and versions can be computed from the subjects on `main`; the tokens `release.py`
  and `devshop-releases` are gone from it). `runtime/templates/ci.yml`'s `fast` job gains the
  devshop's own title step (the PR's title, or on a push the head commit's first line, passed
  through `env`), and `ci-tiers-check.py` gains the rule that `fast` runs `scripts/pr-title-check.py`
  in a step without its own `if` or `continue-on-error`. On a push to `main` the step reads the
  merge commit's first line, so it holds only under squash-only merging, which is an owner step
  every project has (the new-project steps). `ship.sh` already runs the project's copy when
  present. R-12 is `Done` with this change on the devshop's side; a project gets the copy and the
  step with its upgrade (owner, 2026-10-19: "do it"; placement decided here, 2026-10-20)
- **F-NEW-108 is fixed in passing:** `ci-tiers-check.py` follows `needs` transitively with a
  visited set (a cycle terminates), so a job with an `environment` that needs `deploy`, which needs
  both tiers, passes; a `needs` naming a job the workflow lacks is a listed problem. It is in a
  file this change edits and the website's canary job is the case (Claude, 2026-10-20)
- **Duplicates collapsed in the same change** (owner's list, 2026-10-20):
  - _One way to start the site locally:_ `scripts/local-run.sh` (`PORT` given, bound to
    `127.0.0.1`, runs until stopped). `runtime/guidelines/ui.md` § Design review starts the app
    with it and says "can't run: no `scripts/local-run.sh`" otherwise, replacing "as the project's
    `CLAUDE.md` or stack home says"; the Cloudflare home's quality bar serves the built site
    through it instead of an inline `wrangler dev`, and names it in Claude's part of the set-up.
    F-NEW-103 closes.
  - _Lint, in the template_ (the owner's two options were "in the template or out of the spec";
    the spec can't be edited here, since the reviewer takes exactly one spec file per change):
    `runtime/templates/check-fast.sh` runs `part scripts/lint.sh "$base"` when the project has an
    executable `scripts/lint.sh`, and prints `no scripts/lint.sh: lint is the stack's part` when
    it doesn't, so the template, the ci-fast-slow-tiers spec, the install README and the pre-push
    hook agree: `lint.sh` is the stack's, optional, run wherever it exists. The install README's
    "The repo declares its checks" paragraph points at the contract.
  - _One routes-list name:_ `quality/routes.json`; the Cloudflare home drops the fixture's
    `traffic/routes.json` alias (the fixture's PR renames).
  - _One AC-naming rule_, whose home is the contract (the `must` of `scripts/spec-check.py`, which
    every project carries and `--list` prints): a test names the item it proves as `AC-<n>`, and
    puts the spec's file name before it (`<spec> AC-<n>`) once the repo has more than one spec,
    since `spec-check.py` matches numbers per spec and checks nothing of the prefix (F-NEW-92
    stays). The `tests/README.md` seed and the Cloudflare home point at it. The reviewer's prompt
    (`AC-<n>` in the test's title or body) already accepts both. Asked on the go screen.
  - _What a project holds:_ the install README's "one file" becomes "the contract's items".
  - The template `ci.yml`'s and `check-fast.sh`'s header comments list the parts as they now are.
- **The project `CLAUDE.md` seed** (F-NEW-105) gains, under Rules: what this repo must keep is
  listed by `scripts/contract-check.py --list` and checked by `scripts/check-fast.sh`; the files
  it marks `devshop` are copies kept identical and replaced whole on an upgrade, not edited here
  and left alone by the formatter; a change that needs to move away from an item (rename, drop, do
  it another way) doesn't change or skip the check: it tells the owner and proposes a path. The
  seed names the devshop by name where the contract does (`devshop` as an owner), never by path
  (Claude, 2026-10-20)
- **Findings** (owner, 2026-10-20: the PR body says for each of F-NEW-103 and F-NEW-106 to
  F-NEW-116 whether R-13 closes it, it moves to a stack home, or it stays; F-NEW-110 already moved
  in PR #148). Closed here: F-NEW-103, F-NEW-108, F-NEW-116, rows deleted. Moved to the Cloudflare
  home's canary paragraph, rows deleted: F-NEW-107 (a canary job can't share the deploy's
  concurrency group) and F-NEW-109 (a health check holding a secret runs on `pull_request_target`
  from `main`), facts a second Cloudflare project needs. Asked on the go screen. Stay: F-NEW-106,
  F-NEW-111 to F-NEW-115. `ROADMAP.md`: R-12 and R-13 `Done` with this PR; `LOG.md` gets the
  session's entry (Claude, 2026-10-20)
- **Proof:** every check ships proven to fail (CLAUDE.md): `tests/contract-check.test.sh` feeds the
  check known-bad projects, contracts and `supplies` files, and its mutants are killed; the real
  contract, manifest and templates are tied together by a test, so adding to one without the
  others is red. The project copies carry no `/opt/devshop` path (`tests/new-project.test.sh`
  already greps). `tests/check-fast-template.test.sh` uses a stub `contract-check.py` (it proves
  the part's plumbing, as it stubs the secret scan); the real check is proven by its own test and,
  inside a placed project with the devshop hidden, by `tests/new-project.test.sh`. Feedback, not a
  wall: the check is a CI failure and a session-start line; required CI and the owner's approval
  are the walls (Claude, 2026-10-20)
- **Project impact and step 2:** a project's session runs the version it pins, so the website and
  the fixture see nothing of this until they pin a release that carries it. Step 2 is therefore,
  per project, one `/devshop:upgrade` PR to that release: it brings the new `devshop` copies
  (`pr-title-check.py`, `contract-check.py`, `project-contract.txt`) and shows the seed changes
  (`check-fast.sh`'s new parts, `ci.yml`'s title step, the `CLAUDE.md` rules), and the project adds
  what the check then reports (the fixture: `tests/README.md` is not required, but its SHA pin
  predates every manifest, so the upgrade is its first drift check). Until then the new version's
  `contract-check.py` can be run by hand against a project clone. This change touches neither repo
  and needs a devshop release after it merges (the owner's button) (Claude, 2026-10-20)

## Acceptance items

- **AC-1** `runtime/project-contract.txt` lists every item of the Decisions' list, each block with
  exactly the fields `item`, `owner`, `when`, `check`, `must`, `for`, no item twice, and the file
  holds no `runtime/`, `install/`, `kit/` or `/opt/` path; `contract-check.py --list` on it prints
  every item with its owner, when, `must` and `for`. Shown by a test on the real file
- **AC-2** `contract-check.py` on a project holding every required item exits 0 and prints
  `absent (optional): <item>` for each optional item not there and nothing else about them; exits 1
  with `<item>: <problem>` on stdout for each of: a required `file` missing, whitespace-only, a
  symlink or a directory; a required `executable` without its bit on disk, or tracked as `100644`
  with the bit on disk; a `directory` item that is a file or a symlink; `.devshop-version`
  whitespace-only, two tokens, or neither `vX.Y.Z` nor 40 hex (a tag with surrounding whitespace
  and a newline passes); an optional `executable` present without its bit; an optional item named
  by `--supplies` and absent, and by two `--supplies` files once (and nothing for the same project
  without `--supplies`); and exits 2, the reason on stderr, for: no contract; a block with an
  unknown, missing or repeated key, an unknown `owner`, `when` or `check`, a trailing `/` with
  `check: file` or `check: directory` without it, an `item` that is absolute, has `./` or `..`, or
  is listed twice, a `runtime/` path in a `for` line, a CR line end; a `--supplies` file naming a
  required item, one not in the contract, or an optional item spelled with a trailing `/`. With no
  git on `PATH` the same project's disk bits decide. Shown by a test feeding each case
- **AC-3** `runtime/templates/check-fast.sh` runs `scripts/contract-check.py` as a part after the
  spec check, and `scripts/lint.sh "$base"` as a part when the project has it executable, printing
  the no-lint line when it doesn't; a failing contract check or lint gives exit 1 with the other
  parts still run, a missing `scripts/contract-check.py` exit 2. Shown by
  `tests/check-fast-template.test.sh` with stub parts
- **AC-4** A project placed by `init` passes its fast tier with every `/opt/devshop*` hidden, the
  contract check included, and fails it, naming the item, when `scripts/check-slow.sh` is deleted.
  Shown by `tests/new-project.test.sh`
- **AC-5** Session start in a fixture of its own that pins a version: prints exactly one `DEVSHOP:`
  line about the contract, naming each item and problem, when the version's `contract-check.py`
  exits 1, and one saying it couldn't run on exit 2 or when `stack-homes.sh` exits 2; prints the
  absent optional items on one line that doesn't start with `DEVSHOP:`; prints nothing about the
  contract when every item holds and none is absent (the fixture's `scripts/setup.sh` exits 0);
  makes an applying stack home's `supplies` items required and ignores a non-applying home's (shown
  with stack fixtures). A repo with `ci.yml` and no `.devshop-version` gets no line about the
  contract (the existing fixtures of the test stay as they are, minus the "no CI" case). A repo
  with neither gets one `DEVSHOP:` line naming `/devshop:new-project` and no line about missing
  items or the CI template. Shown in `tests/git-hooks.test.sh`
- **AC-6** `runtime/project-files.txt` has the five new entries of the Decisions, the two UI checks
  marked `optional`; `project-files.py check` exits 0 with an optional entry absent and 1 when it is
  present and differs, or is a symlink; `init` writes no optional entry; `plan` lists an optional
  entry with its state; `apply` writes one; a manifest line with a fourth field other than
  `optional`, five fields, or `optional` on a `seed` is exit 2. Shown by `tests/project-files.test.sh`
- **AC-7** `ci-tiers-check.py` exits 1, naming the rule, when `fast` has no step running
  `scripts/pr-title-check.py`, or only one with its own `if` or `continue-on-error`; exits 0 for a
  job with an `environment` whose `needs` reach `fast` and `slow` through another job (F-NEW-108)
  and 1 when they don't; terminates with 1 on a `needs` cycle and on a `needs` naming a job the
  workflow lacks; `runtime/templates/ci.yml` (with the title step) and this repo's `ci.yml` pass.
  Shown by `tests/ci-tiers-check.test.sh`
- **AC-8** `scripts/pr-title-check.py` holds neither `release.py` nor `devshop-releases`, and the
  titles it accepts and refuses are unchanged. Shown by `tests/pr-title-check.test.sh`
- **AC-9** Every `runtime/stacks/<stack>/supplies` names only optional items of the contract,
  spelled as it spells them, and `runtime/stacks/cloudflare/supplies` names the four of the
  Decisions. Shown by a test over the real stack homes
- **AC-10** The real contract, manifest and templates agree: every manifest `devshop` entry's
  project path is a contract item with `owner: devshop` and the source's mode decides its `check`;
  every contract item with `owner: devshop` or `seed` is in the manifest with that owner; every
  `scripts/<name>` on a non-comment line of the template `ci.yml` and `check-fast.sh` is a contract
  item. Shown by a test, which fails when one of them is edited alone
- **AC-11** Docs collapsed and pointed at the contract: `runtime/guidelines/ui.md` § Design review
  starts the app with `scripts/local-run.sh` and the phrase "as the project's `CLAUDE.md` or stack
  home says" is gone from `runtime/`; the Cloudflare home's quality bar serves through
  `scripts/local-run.sh`, `traffic/routes.json` is gone, its AC-naming paragraph points at the
  contract's rule and its canary paragraph carries F-NEW-107 and F-NEW-109; the `tests/README.md`
  seed points at the rule; the project `CLAUDE.md` seed has the contract, formatter and departure
  rules; the template `ci.yml` and `check-fast.sh` headers list the new parts; `install/README.md`,
  `docs/README.md`, `runtime/stacks/README.md` and the upgrade skill describe the contract,
  `supplies` and optional copies — verified by review: the diff and a grep for the removed phrases
- **AC-12** Records: F-NEW-103, F-NEW-107, F-NEW-108, F-NEW-109 and F-NEW-116 rows deleted; R-12
  and R-13 `Done` with this PR's number; the LOG entry — verified by review: the diff

## Out of scope

- The website's and the fixture's PRs: their own sessions, each an upgrade to the release that
  carries this change plus what the check reports; the release itself is the owner's button
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
- Editing `specs/ci-fast-slow-tiers.md` (one spec per change; the template now matches it)
- The reviewer's command allowlist (audit row 35), PR screenshots (row 12), a deploy-facts file
  (row 38), GitHub settings (rows 31 to 33)
- Changing the reviewer's prompt or `review.sh`: they already read `scripts/check-fast.sh` and
  `scripts/local-run.sh` at the base
