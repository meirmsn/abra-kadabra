# A new project starts from the devshop v2 with green CI

**Go:** "go" (owner, 2026-10-16)

## Intent

The owner (2026-10-16): "A new project should be able to start from the devshop v2 reliably: its
repo, the files the devshop places (`runtime/project-files.txt`: `devshop` copies and `seed`
templates such as `runtime/templates/ci.yml` and `runtime/templates/check-fast.sh`), its CI in two
tiers, its stack home, and the steps only I can do (accounts, secrets, environments, branch
protection). Today v2 has no setup guide and no new-project skill." The ask: the simplest reliable
approach: what a new project gets, what is copied vs generated, which steps are the owner's and how
they are told, and how it is proven on a fresh repo. Asked "roadmap or now?", the owner said "now".

Seen while sharpening (2026-10-16): a git repo holding exactly today's manifest files (plus
`specs/.gitkeep`) fails its own `scripts/check-fast.sh`: the secret scan can't load `.gitleaks.toml`
(not placed), `spec-check.py` can't run without a `tests/` file, and the template's `slow` job calls a
`scripts/check-slow.sh` nothing places. So a fresh project's CI is red on day one, as in v1 (L-46,
F-TPL-01/02). v1's 1,600-line skill, its tracker kept in the devshop (F-VER-06), sed-filled
placeholders and prose deploy facts (L-47) are what not to rebuild.

## Decisions

- **Placed by a tested script, not by the model:** `project-files.py` gets an `init` command:
  `init --devshop-git D --version V --project P --codeowner HANDLE`. It reads V's manifest from the
  devshop git dir (no network, as `check`/`plan`/`apply` do) and writes every entry, `devshop` and
  `seed` alike, with its content and its git mode (CI calls `scripts/check-fast.sh` and
  `scripts/check-slow.sh` directly, so a seed written without its executable bit is red CI); then
  `.devshop-version` (V's full SHA) and `.github/CODEOWNERS`. Every check runs before the first
  write: it refuses, writing nothing, when any target (the manifest's and those two) already exists
  or is a symlink, when a target's directory leaves the project, when V is unknown or has no
  manifest, or when a source is missing at V. Files it doesn't target (the README GitHub creates, a
  `.gitignore`, a LICENSE) are left alone. On success it lists what it wrote. Rejected: copying by
  hand from prose (v1's rsync and sed), and `apply` for seeds (it refuses seeds on purpose: an
  upgrade never writes them) (Claude, 2026-10-16)
- **What is generated, not copied:** only what `init` takes as an argument: `.devshop-version` and
  `.github/CODEOWNERS` (`* @HANDLE`; the owner's GitHub handle, which the session asks for; it can't
  live in the devshop, L-01). `init` refuses a HANDLE that doesn't match GitHub's user-name shape,
  `^[A-Za-z0-9](-?[A-Za-z0-9]){0,38}$`; GitHub ignores a code owner that doesn't exist or can't
  write, so the owner's steps include an outside check that GitHub reads the file without errors.
  Everything else is a file in the devshop's manifest (Claude, 2026-10-16)
- **The manifest gains the seeds that make a bare project green**, each a template under
  `runtime/templates/` named so it isn't live in the devshop (no `CLAUDE.md` there, which Claude
  Code would load in devshop sessions): `gitleaks.toml` → `.gitleaks.toml` (gitleaks' default
  rules, its own wording, no devshop references); `check-slow.sh` → `scripts/check-slow.sh`
  (executable; says there are no slow tests yet and exits 0, the template's documented rule, and
  says to replace that with the first end-to-end test); `tests-readme.md` → `tests/README.md` (where
  tests live and that each names the spec item it proves; also the file `spec-check.py` needs under
  `tests/`, so no placeholder test; it contains no `AC-<n>` token, which `spec-check.py` would count
  as naming that item); `gitkeep` → `specs/.gitkeep` (empty; `specs/` holds spec files only);
  `project-claude.md` → `CLAUDE.md` (a short starter: the walls, running `scripts/check-fast.sh`
  before pushing, and where the roadmap and findings go; no devshop paths, L-50). Templates carry no
  relative links, which would break in the devshop repo. No `ROADMAP.md`/`FINDINGS.md`: each is
  created on its first entry (specs/findings-and-roadmap.md). No deploy-facts file: it comes with
  the project's first deploy (Claude, 2026-10-16)
- **The deploy job, if the deploy-and-metrics change merges first:** the seed `ci.yml` is placed as
  it is on `main`. That change's deploy job runs the project's `scripts/deploy.sh` only when present,
  so a new project has none and must stay green on its first push to `main`; `tests/new-project.test.sh`
  runs `ci-tiers-check.py` on the placed `ci.yml`, and the throwaway repo's push to `main` shows it.
  If that job turns out to need an environment or a secret a new project lacks, that is a bug in that
  change, raised with the owner, not worked around here (owner: "ok", 2026-10-16)
- **The new project is stack-neutral at first.** The first PR is the skeleton alone, and its green
  CI on GitHub is the proof the skeleton works there. The stack comes with the first change: its
  spec names the stack (TARGET Reach 3) and loads its home; a home's `README.md` has a `## Set-up`
  section with its owner steps (accounts, tokens, environments) and Claude's steps. A stack with no
  real home yet builds it with the project, as the website does (W10.10.1, W10.10.2). Rejected: a
  stack choice inside the new-project skill (it would need a scaffold per stack, which is Reach 5,
  deferred by D-17) (Claude, 2026-10-16)
- **One skill, `devshop:new-project`, in `runtime/skills/new-project/`,** beside intent and build,
  one page, its description under 45 words. A fresh repo has no `.devshop-version`, so its session
  runs `HEAD`, `main` as of the environment's last cache build, which has the skill once the
  environment is built after the merge; no install-plugin special case (owner: "wherever is no
  nonsense", 2026-10-16). `intent` routes to it: no `.devshop-version` and no
  `.github/workflows/ci.yml` means set-up, no spec. The skill:
  1. Checks the preconditions, each with a stop message: `origin/main` exists (an empty repo has
     none: the owner creates it with a README); no `.devshop-version`; a clean tree on a branch cut
     from `origin/main`; `gitleaks` and `python3` on PATH.
  2. Asks the owner's GitHub handle; runs `init` at `HEAD`'s SHA. On a failure after a write (disk,
     I/O), it deletes the untracked files `init` listed and stops.
  3. Runs `scripts/check-fast.sh origin/main` and `scripts/check-slow.sh`; both pass or it stops.
  4. Opens the first PR (`devshop:pr`), its body carrying the filled owner's steps.
  5. Keeps that PR unmerged until the owner has protected `main`; then checks the walls on it
     (below) and asks for the approval.
- **The owner's steps are one list, `runtime/templates/new-project-steps.md`,** linked from the
  devshop's `README.md` so it can be read before any session exists in the new repo. Before the first
  session: a private repo created with a README (so `main` exists for the first PR); squash merging
  the only merge method (F-NEW-76) with the squash commit message set to the PR title
  (`squash_merge_commit_title=PR_TITLE`: under GitHub's default a one-commit PR lands with its
  commit's subject, not the reviewed title; reported by the devshop releases session, R-11,
  2026-10-16); the agent identity invited as a Write collaborator and the invitation accepted; the
  Claude GitHub App given access to the repo; a cloud environment with the shared two-line setup
  script and a Limited network (package registries, GitHub). After the first PR's CI has run:
  `main` protected (PR only, one approval, code-owner review, approval of the most recent push,
  dismiss stale approvals, conversation resolution, no bypass, no force push or delete, required
  checks `fast` and `slow`). Each step says how the session checks it from outside with the agent's
  Write access: the repo's merge settings, the rules that apply to `main`
  (`repos/{owner}/{repo}/rules/branches/main`), `codeowners/errors` empty, and the refusals (a
  direct push to `main`, a merge without approval). The stack's own steps come from its home's
  `## Set-up` with its first change. The session fills in the exact names and gives the list in chat
  and in the first PR's body. Nothing is tracked in the devshop repo (F-VER-06) or left as paperwork
  in the project (TARGET Shape 3) (Claude, 2026-10-16)
- **The walls are checked by hand this time:** the session checks each step from outside as
  W10.10.1 does. A tested walls-check script is a separate change if wanted (owner asked "what is
  sensible to do?"; Claude's call, 2026-10-16: it is a project-facing check needing its own
  known-bad tests, so its own spec)
- **Proof:** in the devshop's CI, `tests/new-project.test.sh` builds a repo with a README commit,
  runs `init` and commits, then runs the placed project's own checks from a copy outside the devshop
  checkout with `/opt/devshop*` unreadable (L-50), against the README commit as base (a PR) and an
  empty base. On GitHub: the owner creates a throwaway private repo, the files `init` places from
  this branch go up as its first PR, and its CI must be green on the PR and on the push to `main`
  before this change merges (owner: "a throwaway repo", 2026-10-16; the repo is `test-project`, attached to this session with push access: "test-project is the name, you have access now", 2026-10-16). The skill run end to end in a
  fresh session there needs the skill on `main` and an environment built after the merge, so it is a
  post-merge step on the task line; then the repo is archived
- **`.devshop-version` holds a commit SHA for now:** once the devshop cuts release tags (R-11,
  `specs/devshop-releases.md`, not yet on `main`), a project pins a tag; moving `init` and the skill
  to the newest tag belongs to that change or a follow-up, not this one (Claude, 2026-10-16)
- **Project impact:** conditional. An existing project's next `devshop:upgrade` lists the five new
  seed templates as new; the upgrade asks per file, and the project adopts or skips each. No devshop
  file changes
- **Task line:** W10.10.9 in `kit/notes/revamp/workstreams/W10-v2.md` (M2, the website's
  milestone; M1 is closed) holds the status and the post-merge run; no `ROADMAP.md` entry (owner:
  "now"). W10.10.1 stays as written: the website's set-up is under way by hand

## Acceptance items

- **AC-1** `project-files.py init` into a repo holding only a README commit writes every entry of
  the version's manifest at its project path, byte-identical to the version's file and with its
  executable bit (seeds included), plus `.devshop-version` holding the version's full SHA and
  `.github/CODEOWNERS` holding `* @HANDLE`, and leaves the README unchanged, shown by
  `tests/project-files.test.sh`
- **AC-2** `init` writes nothing and exits 2 when any target, `.devshop-version` and
  `.github/CODEOWNERS` included, already exists as a file, a directory or a symlink; when a
  target's directory leaves the project; when the version is unknown or has no manifest; when a
  manifest source is missing at that version; or when `--codeowner` is missing or doesn't match
  `^[A-Za-z0-9](-?[A-Za-z0-9]){0,38}$`, shown by `tests/project-files.test.sh`
- **AC-3** After `init` at the devshop's current commit, committed, the placed project's
  `scripts/check-fast.sh` (with the README commit as base, and with an empty base) and
  `scripts/check-slow.sh` exit 0, and `ci-tiers-check.py` passes its `.github/workflows/ci.yml`,
  run from a copy outside the devshop checkout with `/opt/devshop*` unreadable, shown by
  `tests/new-project.test.sh`
- **AC-4** The placed project's fast tier exits 1 naming the failed part on a planted fake secret
  (`scripts/secret-scan.sh failed`) and on a spec whose AC-1 no test names
  (`scripts/spec-check.py failed`), shown by `tests/new-project.test.sh`
- **AC-5** No file `init` places contains `/opt/devshop` (the session-only devshop install a plain
  clone doesn't have, L-50), and the `tests/README.md` it places contains no `AC-<n>` token, shown
  by `tests/new-project.test.sh`
- **AC-6** `runtime/skills/new-project/SKILL.md` exists and passes `scripts/skills-check.py` (it
  names only `/opt/devshop-current/` files its version has; the descriptions stay within 200 words
  together), shown by `tests/skills-check.test.sh`; its steps and `intent`'s routing line say what
  the decisions above say — verified by review: the diff
- **AC-7** `runtime/templates/new-project-steps.md` lists each owner step above with how the session
  checks it from outside and has no project identifier; `README.md` links it; every new Markdown
  file is reachable from `docs/README.md`; `runtime/stacks/README.md` describes a home's `## Set-up`
  section — verified by review: the diff and `docs-map-check.py`
- **AC-8** `kit/notes/revamp/workstreams/W10-v2.md` has task W10.10.9 with the end-to-end skill run
  on the throwaway repo as its post-merge done-when — verified by review: the diff

## Out of scope

- A stack-specific scaffold or a stack choice in the skill; Reach 5 (every home proven by CI
  scaffolding a project) stays deferred (D-17)
- The deploy job itself and the deploy-facts file (the deploy-and-metrics change; a project's first
  deploy)
- A tested walls-check script (a separate change if wanted)
- Creating the GitHub repo or the cloud environment from a session (owner steps)
- Changing `apply`, `check` or `plan`, or the upgrade skill
- Changing W10.10.1 or the website's set-up
