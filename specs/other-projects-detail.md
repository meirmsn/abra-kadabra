# Other projects appear here by name and lesson only

**Go:** pending

## Intent

The owner (2026-10-28): "sharpen the no-identifiers rule in CLAUDE.md. Today the rule bans URLs,
database refs, team slugs, monitoring ids, owner/repo slugs, GitHub handles, email addresses and
session links, and then says 'A project's name plus enough context to explain a change is fine.'
That last clause lets the revamp notes carry details of my other projects that I don't want in a
public repo: kit/notes/revamp/lessons.md cites lalista and home-os PRs by number and names their
features and internal spec files (about 77 lines); LOG.md and W10-v2.md have a few more."

What they asked for:

1. A clearer rule in one CLAUDE.md bullet. It says what about another project may be written here
   (its name and the lesson distilled from it) and what may not (its PR numbers, feature and spec
   names, and anything that describes its product rather than the devshop's lesson).
2. A sweep of `kit/notes/revamp/`, and anywhere else `git grep` finds these shapes, that rewrites
   each hit to comply. Each lesson stays and the project detail goes. What changed is reported as
   one list.
3. A call on whether a mechanical check is worth it or this stays a prose rule.

## Decisions

- **Where the line is.** For a project the devshop serves, the repo may hold:
  - its name;
  - its role in the devshop's plan: pilot, paused, frozen, which milestone;
  - the stack and platform it runs on, as far as the devshop needs them to choose a stack home or
    a wall (Next.js, Supabase, Cloudflare, iOS);
  - the lesson, stated as the devshop's rule, with evidence reduced to shape and count ("twice in
    one project, both caught by review", "4 PRs across 2 projects", "5 CI cycles");
  - generic technical facts the lesson rests on, which are true of the tool and not of the
    project (a Tailwind v4 token override, a Postgres `ALTER TYPE … ADD VALUE` transaction rule).

  The repo may never hold:
  - its PR or issue numbers;
  - the names of its features, screens, specs, files, tables, RPCs or functions;
  - quotes from its documents or PRs;
  - anything that says what its product does or how its users use it.

  The reason for the line: the devshop needs only the lesson and enough stack context to act on it,
  and everything past that describes the owner's product. Rejected: removing project names
  altogether. The plan, the stack homes and ROADMAP are organised around which real project comes
  next, and the owner allowed names. (Proposed; the owner's go confirms it.)

- **The rule is one new bullet under § Rules, next to the identifiers bullet.** That bullet loses
  its "A project's name plus enough context to explain a change is fine" clause, because the new
  bullet replaces it. The identifiers bullet stays as it is otherwise.
- **The devshop's own PR numbers, commits and lesson ids stay.** "PR #50", L-73 and W10.3.2 are
  devshop history, not another project's. Generic file names that every project has
  (`CLAUDE.md`, `TODOS.md`) may appear without the project's path or contents. A path that
  carries a feature or spec name (`specs/<feature>/review.md`) may not.
- **Only the current tree changes.** Git history, merged commit subjects and the bodies of merged
  PRs on GitHub still hold the old text. Rewriting history is a force-push to `main`, which
  CLAUDE.md and the wall forbid, so this change logs it as a FINDINGS row for the owner to decide
  on.
- **No mechanical check; this stays a prose rule.**
  - A grep for "<project> PR <n>" would catch only the PR-number shape, about 71 lines today. The
    bulk of the problem is feature and spec names, which no pattern can match without listing
    them, and listing them would put them in this repo.
  - The check would also need the owner's project names in devshop config, while CLAUDE.md says
    project config lives in the project.
  - A check would need its known-bad test and mutant run, which costs more than the one shape it
    catches is worth.
  - The sweep's evidence is a `git grep` recorded in the PR body instead.
  - (Proposed; the owner's go confirms it.)
- **The change report names no detail.** The PR body lists each changed file with the kind of
  detail removed and a line count. It does not repeat the removed names, because the rule covers PR
  bodies too.

## Acceptance items

- **AC-1** `CLAUDE.md` § Rules has one bullet on other projects. It allows a project's name, its
  role in the plan, its stack as far as the devshop needs it, and the distilled lesson. It forbids
  PR and issue numbers, feature, screen, spec, file, table and function names, quotes from the
  project, and descriptions of its product or users, and it says this covers commit messages and PR
  text. The identifiers bullet no longer says "A project's name plus enough context to explain a
  change is fine".
- **AC-2** `git grep -n -i -E "(lalista|home-os)('s)? +(PRs?|issues?) *#?[0-9]"` finds nothing,
  and `git grep -n -i -E "PRs? *#?[0-9]+"` finds no line in `kit/notes/revamp/lessons.md` whose PR
  number belongs to another project.
- **AC-3** Every line in the tree that names lalista or home-os carries only what the AC-1 bullet
  allows — verified by review: read every line of `git grep -n -i -E "lalista|home-os"` against
  the bullet.
- **AC-4** No lesson is lost. `kit/notes/revamp/lessons.md` still has the same 62 `### L-` headings
  with the same ids and titles, and each still has a rule and a **Why** with evidence.
- **AC-5** `lessons.md`'s Sources notes and L-01 describe the new citation style (project name
  and shape, no PR numbers or spec paths) instead of "home-os PR n" and "`specs/<feature>/…`".
- **AC-6** `FINDINGS.md` has a row, following the findings template, saying that git history and
  merged PR text still hold other-project detail and that the owner decides what to do about it.
- **AC-7** The PR body lists each changed file with the kind of detail removed and its line count.
  It names no removed feature, spec or PR number.
- **AC-8** `tests/run.sh` passes.

## Out of scope

- Rewriting git history, or editing merged PR titles and bodies on GitHub (the AC-6 finding).
- A lint check or test for the rule (Decisions).
- Removing project names, roles or stack mentions that the bullet allows.
- The other rules in CLAUDE.md.
