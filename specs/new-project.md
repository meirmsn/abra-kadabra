# A new project starts from the devshop v2 with green CI

**Go:** pending

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
  devshop git dir (no network, as `check`/`plan`/`apply` do) and writes every entry: `devshop` files
  as identical copies (mode included), `seed` files once; then `.devshop-version` (V's full SHA)
  and `.github/CODEOWNERS`. It refuses, writing nothing, when any target path already exists,
  is a symlink or leaves the project, or when V is unknown or has no manifest. Rejected: copying by
  hand from prose (v1's rsync and sed), and `apply` for seeds (it refuses seeds on purpose: an
  upgrade never writes them) (Claude, 2026-10-16)
- **What is generated, not copied:** only what `init` takes as an argument: `.devshop-version` and
  `.github/CODEOWNERS` (`* @HANDLE`, the owner's GitHub handle, which the session asks for; it can't
  live in the devshop, L-01). `HANDLE` must be a GitHub user name, else `init` refuses. Everything
  else is a file in the devshop's manifest (Claude, 2026-10-16)
- **The manifest gains the seeds that make a bare project green**, each a template under
  `runtime/templates/`: `.gitleaks.toml` (gitleaks' default rules, as the devshop's own),
  `scripts/check-slow.sh` (says there are no slow tests yet and exits 0, the template's documented
  rule), `tests/README.md` (where tests live and that they name the spec item they prove; it is also
  the file `spec-check.py` needs under `tests/`, so no placeholder test), `specs/.gitkeep` (empty;
  `specs/` holds spec files only), and a project `CLAUDE.md` starter with no devshop paths (L-50).
  No `ROADMAP.md`/`FINDINGS.md`: each is created on its first entry (specs/findings-and-roadmap.md).
  No deploy-facts file: it comes with the project's first deploy (Claude, 2026-10-16)
- **The new project is stack-neutral at first.** The first PR is the skeleton alone, and its green
  CI on GitHub is the proof the skeleton works there. The stack comes with the first change: its
  spec names the stack (TARGET Reach 3) and loads its home; a home's `README.md` has a `## Set-up`
  section with its owner steps (accounts, tokens, environments) and Claude's steps. A stack with no
  real home yet builds it with the project, as the website does (W10.10.1, W10.10.2). Rejected: a
  stack choice inside the new-project skill (it would need a scaffold per stack, which is Reach 5,
  deferred by D-17) (Claude, 2026-10-16)
- **One skill, `devshop:new-project`, in `runtime/skills/new-project/`,** beside intent and build,
  one page. A fresh repo has no `.devshop-version`, so its session runs `HEAD`, which has the skill;
  no install-plugin special case (owner: "wherever is no nonsense", 2026-10-16). It runs in the new
  repo's first session: check the preconditions, ask for the handle, run `init` at `HEAD`'s SHA, run
  `scripts/check-fast.sh` and `scripts/check-slow.sh`, open the first PR, then give the owner the
  remaining steps
- **The owner's steps are one list, `runtime/templates/new-project-steps.md`,** linked from the
  devshop's `README.md` so it can be read before any session exists in the new repo. Before the first
  session: a private repo created with a README (so `main` exists for the first PR), squash merging
  the only merge method (F-NEW-76), the agent identity invited as a Write collaborator and the
  invitation accepted, a cloud environment with the shared two-line setup script and a Limited
  network (package registries, GitHub). After the first PR's CI has run: `main` protected (PR only,
  one approval, code-owner review, approval of the most recent push, dismiss stale approvals,
  conversation resolution, no bypass, no force push or delete, required checks `fast` and `slow`).
  Each step says how the session checks it from outside. The stack's own steps come from its home's
  `## Set-up` with its first change. The session fills in the exact names and gives the list in chat
  and in the first PR's body. Nothing is tracked in the devshop repo (F-VER-06) or left as paperwork
  in the project (TARGET Shape 3) (Claude, 2026-10-16)
- **The owner's steps are checked by hand this time:** the session checks each from outside as
  W10.10.1 does (refused direct push and unapproved merge, merge methods, environments), and re-runs
  the safety table once on the new repo (D-17). A tested walls-check script is a separate change if
  wanted (owner asked "what is sensible to do?"; Claude's call, 2026-10-16: it is a project-facing
  check needing its own known-bad tests, so its own spec)
- **Proof:** in the devshop's CI, `tests/new-project.test.sh` runs `init` into an empty git repo,
  then runs the placed project's own checks with no devshop present (L-50). On a real repo: the owner
  creates a throwaway private repo, a session there runs the skill, and the first PR's CI is green;
  then the repo is archived (owner, 2026-10-16). That run needs the skill on `main`, so it is a
  post-merge step recorded on the task line, not an acceptance item
- **Project impact:** conditional. An existing project's next `devshop:upgrade` lists the new seed
  templates as template changes; it adopts or skips each, as for any seed. No devshop file changes
- **Task line:** W10.4.10 in `kit/notes/revamp/workstreams/W10-v2.md` holds the status and the
  post-merge proof; no `ROADMAP.md` entry (owner: "now")

## Acceptance items

- **AC-1** `project-files.py init` into an empty git repo writes every entry of the version's
  manifest at its project path, `devshop` entries byte-identical to the version's file with its
  executable bit, plus `.devshop-version` holding the version's full SHA and `.github/CODEOWNERS`
  holding `* @HANDLE`, shown by `tests/project-files.test.sh`
- **AC-2** `init` writes nothing and exits 2 when any target path already exists (a file, a
  directory or a symlink), when a target's directory leaves the project, when the version is unknown
  or has no manifest, when a manifest source is missing at that version, or when `--codeowner` is
  missing or not a GitHub user name, shown by `tests/project-files.test.sh`
- **AC-3** After `init` at the devshop's current commit into an empty repo, committed, the project's
  `scripts/check-fast.sh` (empty base) and `scripts/check-slow.sh` exit 0 and `ci-tiers-check.py`
  passes its `.github/workflows/ci.yml`, run from the project with a PATH that holds no
  `/opt/devshop*` directory, shown by `tests/new-project.test.sh`
- **AC-4** The placed project fails its own fast tier on a planted fake secret and on a spec whose
  acceptance item no test names, shown by `tests/new-project.test.sh`
- **AC-5** No file `init` places contains `/opt/devshop` (the session-only devshop install a plain
  clone doesn't have, L-50), shown by `tests/new-project.test.sh`
- **AC-6** `runtime/skills/new-project/SKILL.md` exists, passes `scripts/skills-check.py` (the skill
  descriptions stay within 200 words together) and names `init` and `new-project-steps.md` by their
  `/opt/devshop-current/` paths — verified by review: the diff and the skills check
- **AC-7** `runtime/templates/new-project-steps.md` lists each owner step above with how the session
  checks it from outside, and has no project identifier; `README.md` links it, `docs/README.md` maps
  it, and `runtime/stacks/README.md` describes a home's `## Set-up` section — verified by review: the
  diff and `docs-map-check.py`
- **AC-8** `kit/notes/revamp/workstreams/W10-v2.md` has task W10.4.10 with the throwaway-repo run as
  its post-merge done-when — verified by review: the diff

## Out of scope

- A stack-specific scaffold or a stack choice in the skill; Reach 5 (every home proven by CI
  scaffolding a project) stays deferred (D-17)
- The deploy job and the deploy-facts file (the deploy-and-metrics change; a project's first deploy)
- A tested walls-check script (a separate change if wanted)
- Creating the GitHub repo or the cloud environment from a session (owner steps)
- Changing `apply`, `check` or `plan`, or the upgrade skill
