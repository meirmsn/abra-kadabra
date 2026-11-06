# The plugin is `ak`, and its runtime skills load again

**Go:** pending

## Intent

F-NEW-147 (logged on the skills eval's branch, `high`): on Claude Code 2.1.318 and 2.1.319 a session
in a devshop environment lists only `devshop:upgrade`, the plugin's own skill; `intent`, `split`,
`build`, `pr`, `new-project` and `devshop-version` never load, and in the skills eval's first run one
of three sessions built a change with no spec. 2.1.316 listed all seven on the same install. The
owner, in chat on 2026-11-06, asked to fix it and to name the plugin `ak`, so the skills read
`ak:intent`, `ak:build` and so on: "Yeah, do it with AK and fix them." This change is R-20.

**Root cause, settled by experiment** (CLI 2.1.319, a throwaway `HOME` with the plugin installed as
the bootstrap installs it, throwaway copies of the marketplace folder): for a plugin read in place
from a local marketplace folder, the CLI follows a symlink only when its resolved path is inside
that folder. The plugin's `skills` link resolves to `/opt/devshop-versions/<sha>/skills`, outside
`/opt/devshop-plugin`, so it is skipped without a word. The CLI's own validator text says so ("An
installed plugin follows one only if it points inside the plugin's installed folder, or, for a
plugin read in place from a local marketplace folder, inside that folder").

| Layout of the plugin's `skills`                                           | Listed                     |
| ------------------------------------------------------------------------- | -------------------------- |
| link to `/opt/devshop-current/skills` (today), with or without the entry  | `upgrade` only, or nothing |
| the same link, and `./skills/` added to the manifest's `skills` list      | `upgrade` only             |
| a real folder holding links per skill, or per `SKILL.md`, out of the tree | `upgrade` only             |
| a real copy, with the manifest's entry / without it / both listed         | 7 / 6 / 7                  |
| a link, relative or absolute, resolving inside the marketplace folder     | all 7                      |
| a link through a folder outside the marketplace, resolving back inside it | all 7                      |

So the manifest's `skills` entry adds to the default folder, it doesn't replace it; and what
matters is only where the link ends.

## Decisions

- **The versions move inside the marketplace folder:** the dispatcher extracts each version's
  `runtime/` to `/opt/devshop-plugin/versions/<sha>`, and `default-ref` and `copy-date` move there
  with it. `/opt/devshop-current` stays the one link the dispatcher re-points, and the plugin's
  `skills` stays a link to `/opt/devshop-current/skills`, which now ends inside the marketplace
  folder; the version stays switchable per session. Rejected: a real copy of the skills in the plugin
  (frozen at the cache build, not switchable by pin); copying them in at session start (a second copy
  of every version to keep right); per-skill links (skipped by the same rule) (Claude, 2026-11-06)
- **The bootstrap extracts the plugin first:** it empties `/opt/devshop-plugin` before extracting,
  so it now writes `default-ref` and `copy-date` after that, not before (Claude, 2026-11-06)
- **Named `ak`, folders kept:** the plugin and its marketplace are both `ak`, installed as `ak@ak`,
  so its skills are `ak:<name>`. The folders keep their names, `install/plugin/devshop/` and
  `/opt/devshop-plugin/devshop/`: a pinned older version's runtime reads files at those paths (its
  session-start script, its `new-project` skill), and the owner didn't ask to move them. The
  `DEVSHOP:` line stays as it is (Claude, 2026-11-06)
- **Every hand-over says `ak:`:** the runtime's skills, guidelines, templates, hooks and scripts, the
  plugin's `upgrade` skill and dispatcher, the docs and tests. Specs and `kit/notes/` are records of
  past changes and keep their words; `FINDINGS.md` rows keep theirs (Claude, 2026-11-06)
- **`skills-check.py` checks the new name:** a hand-over is `ak:<skill>`, and one by the old name,
  `devshop:<skill>`, is a problem, since no session lists it (Claude, 2026-11-06)
- **Older pins:** a project pinning a version from before this change gets that version's skills as
  `ak:<name>`, whose words still hand over to `devshop:<name>`, and its session-start lines name
  `/devshop:upgrade`. The skills load (the fix is in the dispatcher, from `main`); re-pinning with
  `/ak:upgrade` brings the new words. Breaking, hence `fix!:` (Claude, 2026-11-06)
- **When it takes effect:** the plugin and the bootstrap come from `main` at each environment's cache
  build, so each environment gets the fix at its next cache rebuild (about weekly, or when its setup
  script is edited). The owner needs to do nothing else; to have it sooner in an environment, edit
  its setup script (Claude, 2026-11-06)
- **The ID is R-20:** R-16 to R-19 are taken on the skills eval's open branch (Claude, 2026-11-06)
- **The check, written first:** `tests/bootstrap.test.sh` asserts every runtime skill the installed
  plugin offers resolves inside `/opt/devshop-plugin`, the CLI's rule, and that the plugin installs
  as `ak@ak`; both fail on `main`. A probe of the real CLI in a throwaway `HOME`, after the bootstrap
  of this branch, goes in the PR body (Claude, 2026-11-06)

## Acceptance items

- **AC-1** After the bootstrap, every runtime skill under `/opt/devshop-plugin/devshop/skills/`
  resolves to a path inside `/opt/devshop-plugin`, for the default version and for a pinned one;
  `/opt/devshop-current` points at `/opt/devshop-plugin/versions/<sha>`, re-pointed per project pin
- **AC-2** The bootstrap writes `default-ref` and `copy-date` to `/opt/devshop-plugin/versions/`,
  and the `DEVSHOP:` line still dates the copy and names the default version
- **AC-3** The marketplace and the plugin are named `ak`, and the bootstrap runs
  `claude plugin install ak@ak --scope user`
- **AC-4** No file under `runtime/`, `install/`, `scripts/`, `tests/` or `docs/` hands over by
  `devshop:<skill>`, or names `/devshop:<skill>`, except the tests that feed the old name to the check
- **AC-5** `scripts/skills-check.py` fails a skill, the runtime's or the plugin's, that hands over by
  `devshop:<skill>`, and passes one handing over by `ak:<skill>` to a skill that exists
- **AC-6** On the current CLI, a plain session in a throwaway `HOME`, after this branch's bootstrap,
  lists `ak:build`, `ak:devshop-version`, `ak:intent`, `ak:new-project`, `ak:pr`, `ak:split` and
  `ak:upgrade` in its init event — verified by review: the probe's output in the PR body
- **AC-7** `install/README.md` and `docs/README.md` describe the new layout and names — verified by
  review: the diff

## Out of scope

- Re-pinning the projects that pin an older version (each project's own `/ak:upgrade`)
- Renaming the folders, the `DEVSHOP:` line or the `devshop` words in prose
- A bootstrap re-run in a container that already holds `devshop@devshop`: environments run the
  bootstrap on a fresh container
- A CI check that runs the real CLI against the installed plugin (logged as a finding)
