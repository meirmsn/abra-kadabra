# Other projects appear here by description and lesson, never by name

**Go:** "[for the frozen project:] "the 2nd pilot web app" go!" (owner, 2026-10-30)

## Intent

The owner (2026-10-28), with the two project names replaced by their descriptions (below): "sharpen
the no-identifiers rule in CLAUDE.md. Today the rule bans URLs, database refs, team slugs,
monitoring ids, owner/repo slugs, GitHub handles, email addresses and session links, and then says
'A project's name plus enough context to explain a change is fine.' That last clause lets the
revamp notes carry details of my other projects that I don't want in a public repo:
kit/notes/revamp/lessons.md cites [the pilot web app] and [the 2nd pilot web app] PRs by number and
names their features and internal spec files (about 77 lines); LOG.md and W10-v2.md have a few
more."

What they asked for:

1. A clearer rule in one CLAUDE.md bullet. It says what about another project may be written here
   and what may not (its PR numbers, feature and spec names, and anything that describes its
   product rather than the devshop's lesson).
2. A sweep of `kit/notes/revamp/`, and anywhere else `git grep` finds these shapes, that rewrites
   each hit to comply. Each lesson stays and the project detail goes. What changed is reported as
   one list.
3. A call on whether a mechanical check is worth it or this stays a prose rule.

Then (2026-10-30), on keeping project names: "I'm not sure we should mention the old projects at
all. Like I'm thinking like somebody if somebody were to get this [repo] and then they would not
understand what this means, right?"

## Decisions

- **No names. Other projects appear only by a fixed plain description.** Someone reading this repo
  can't know what a project's name means (owner, 2026-10-30). The descriptions:
  - **"the pilot web app"** for the M3 project (proposed by Claude and accepted at the go);
  - **"the 2nd pilot web app"** for the frozen project mined in W10.3.2 (owner, 2026-10-30);
  - **"the owner's website"** (or "the website" where the context is clear) for the M2 project.
    This is already a description, so it stays, minus its PR numbers and feature detail.

  Rejected: keeping the names, as proposed on 2026-10-28.

- **Where the line is.** For a project the devshop serves, the repo may hold:
  - its description;
  - its role in the devshop's plan: pilot, paused, frozen, which milestone;
  - the stack and platform it runs on, as far as the devshop needs them to choose a stack home or
    a wall (Next.js, Supabase, Cloudflare, iOS);
  - the lesson, stated as the devshop's rule, with evidence reduced to shape and count ("twice in
    one project, both caught by review", "4 PRs across 2 projects");
  - generic technical facts that are true of the tool, not of the project (a Tailwind v4 token
    override, a Postgres `ALTER TYPE … ADD VALUE` transaction rule).

  The repo may never hold:
  - its name;
  - its PR or issue numbers;
  - the names of its features, screens, specs, tables, RPCs or functions;
  - file paths that carry a feature or spec name;
  - quotes from its documents or PRs;
  - anything that says what its product does or how its users use it.

  The role and stack allowances let PLAN, ROADMAP and the stack homes keep saying which project
  comes next and what it runs on (accepted at the go, 2026-10-30).

- **Devshop history stays.** The devshop's own fixture, harness and test repos are devshop
  history and keep their PR numbers. So do the devshop's own PRs, commits and ids (L-n, W10.n,
  F-…), and v1 devshop paths as of `v1-final`.
- **Paths the devshop defines stay.** That covers what `runtime/project-files.txt`, the stack homes
  and the templates name (`scripts/deploy.sh`, `wrangler.jsonc`), and generic files every project
  has (`CLAUDE.md`, `TODOS.md`). A path that carries the project's name goes too: a v1 path such
  as `kit/notes/projects/<name>.md` is cited by its shape.
- **Quoted owner words keep their wording.** Where a quote in ROADMAP, a spec or the notes holds a
  project name, the name is swapped for its description in square brackets, so the edit shows.
- **Merged specs are left as they are.** The reviewer takes the one spec file a change touches as
  its spec, so a change that edits merged specs can't be reviewed. The merged specs keep their
  website PR numbers (about a dozen, no names and no product detail), as do the fixture
  `tests/fixtures/change-metrics-pr7` and its test. Changed after the go: the owner chose this
  option: "1" (owner, 2026-10-30); rejected: three follow-up PRs, one per merged spec. The original
  plan was to reword merged specs outside their AC items.
- **Files that projects copy.** A file that projects keep a copy of
  (`runtime/project-files.txt`) gets comment-only edits, and they reach projects with the next
  devshop release.
- **The CLAUDE.md change.** One new bullet goes under § Rules, next to the identifiers bullet. The
  identifiers bullet loses its "A project's name plus enough context to explain a change is fine"
  clause and is otherwise unchanged.
- **Git history is not touched.** D-12 (revisited 2026-10-11) accepts project names and details
  already in history and drops the "owner reads the notes" gate before going public. So after this
  change the current tree complies, but history, merged commit subjects and merged PR bodies still
  hold the old text. The owner keeps D-12: "keep, don't reopen" (owner, 2026-10-28).
- **No mechanical check; this stays a prose rule.**
  - Most of the problem is feature and spec names, and no pattern matches those without listing
    them, which would put them in this repo.
  - A grep for the names would need the names in this repo, which the rule now forbids.
  - The one generic shape, "<word> PR <n>", is noisy. The devshop's own fixture, harness and "on
    PR n" citations match it about 140 times.
  - The sweep's evidence is the greps in the PR body instead.

  The owner agreed: "yes" (owner, 2026-10-28).

- **The change report names no detail.** The PR body and the hand-over message list each changed
  file with the kind of detail removed and a line count. They don't repeat removed names, because
  the rule covers PR text too.

## Acceptance items

- **AC-1** `CLAUDE.md` § Rules has one bullet on other projects. It says a project is never named,
  only described. It allows the description, the role, the stack and the distilled lesson, and it
  forbids:
  - PR and issue numbers;
  - feature, screen, spec, table and function names, and paths that carry them;
  - quotes from the project;
  - descriptions of its product or users.

  It covers commit messages and PR text. The identifiers bullet no longer says "A project's name
  plus enough context to explain a change is fine" — verified by review: read both bullets.

- **AC-2** A case-insensitive `git grep` for either of the two project names (hyphen, space,
  underscore or no separator) finds nothing in the tree. The command is in the PR body, not in this
  repo, since it holds the names.
- **AC-3** `git grep -n -i -E "website('s)? +PRs?\b" -- . ':!specs/' specs/other-projects-detail.md`
  finds nothing (merged specs excluded, owner 2026-10-30).
- **AC-4** Every PR number left in the tree outside the merged specs and the `change-metrics-pr7`
  fixture and its test belongs to the devshop or its fixture, harness or test repos — verified by
  review: read every line of `git grep -n -i -E "PRs? *#?[0-9]+" -- . ':!specs/'` and this spec.
- **AC-5** Every line the sweep changed, and every line outside the merged specs that names one of
  the three descriptions, carries only what the AC-1 bullet allows — verified by review: read the
  PR diff and `git grep -n -i -E "pilot web app|website" -- . ':!specs/'` against the bullet.
- **AC-6** No lesson is lost. `kit/notes/revamp/lessons.md` keeps its 62 `### L-` headings with
  the same ids and titles, each with a rule and a **Why**, and every "Considered, not carried" entry
  keeps its id and reason — verified by review: diff the heading list and read the changed Why
  blocks.
- **AC-7** These passages in `lessons.md` describe the new citation style (the description and the
  shape, no PR numbers or spec paths):
  - the intro;
  - the Sources notes;
  - L-01;
  - the sources table.

  Verified by review: read those passages.

- **AC-8** No merged spec changes — verified by review: the diff of `specs/` touches only this
  spec.
- **AC-9** `docs/README.md` lists this spec, and `tests/run.sh` passes.

## Out of scope

- Rewriting git history, or editing merged PR titles and bodies on GitHub (D-12).
- A lint check or test for the rule (Decisions).
- The other rules in CLAUDE.md.
