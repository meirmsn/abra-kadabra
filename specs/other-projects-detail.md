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
    one project, both caught by review", "4 PRs across 2 projects");
  - generic technical facts that are true of the tool, not of the project (a Tailwind v4 token
    override, a Postgres `ALTER TYPE … ADD VALUE` transaction rule).

  The repo may never hold:
  - its PR or issue numbers;
  - the names of its features, screens, specs, tables, RPCs or functions;
  - file paths that carry a feature or spec name;
  - quotes from its documents or PRs;
  - anything that says what its product does or how its users use it.

  The reason for the line: the devshop needs the lesson and enough stack context to act on it, and
  the rest describes the owner's product. Rejected: removing project names altogether. PLAN, the
  stack homes and ROADMAP are organised around which real project comes next.

  The role and stack allowances go beyond "its name and the lesson". They are proposed, and the
  owner confirms them at the go.

- **"Other project" means every project the devshop serves.** That is lalista, home-os and the
  owner's website (M2), which is cited the same way ("website PR n") in `runtime/stacks/cloudflare/`,
  `specs/`, both FINDINGS files and the revamp notes. The devshop's own fixture, harness and test
  repos are devshop history and keep their PR numbers. So do the devshop's own PRs, commits and
  ids (L-n, W10.n, F-…), and v1 devshop paths as of `v1-final`.
- **Paths the devshop defines stay.** That covers what `runtime/project-files.txt`, the stack homes
  and the templates name (`scripts/deploy.sh`, `wrangler.jsonc`), and generic files every project
  has (`CLAUDE.md`, `TODOS.md`). The project's feature and spec paths go.
- **Merged specs and files that projects copy.** A merged spec is reworded outside its AC items only,
  so its recorded go and items stay true. A file that projects keep a copy of
  (`runtime/project-files.txt`) gets comment-only edits, and they reach projects with the next
  devshop release.
- **The CLAUDE.md change.** One new bullet goes under § Rules, next to the identifiers bullet. The
  identifiers bullet loses its "A project's name plus enough context to explain a change is fine"
  clause and is otherwise unchanged.
- **Git history is not touched.** D-12 (revisited 2026-10-11) accepts project names and details
  already in history and drops the "owner reads the notes" gate before going public. So after this
  change the current tree complies, but history, merged commit subjects and merged PR bodies still
  hold the old text. Whether the owner's new wish reopens D-12 is the owner's call, raised at the
  go. This change does not reopen it.
- **No mechanical check; this stays a prose rule.**
  - Most of the problem is feature and spec names, and no pattern matches those without listing
    them, which would put them in this repo.
  - The one shape a pattern can catch, "<word> PR <n>", is noisy. The devshop's own fixture,
    harness and "on PR n" citations match it about 140 times.
  - After the sweep, a project-name version (`lalista|home-os|website` + "PR") would find
    nothing. It would only catch a regression of the PR-number shape, and it would need the
    owner's project names in devshop config.
  - The sweep's evidence is the greps in the PR body instead. (Proposed; the owner confirms at the
    go.)
- **The change report names no detail.** The PR body and the hand-over message list each changed
  file with the kind of detail removed and a line count. They don't repeat removed names, because
  the rule covers PR text too.

## Acceptance items

- **AC-1** `CLAUDE.md` § Rules has one bullet on other projects. It allows the name, the role,
  the stack and the distilled lesson. It forbids:
  - PR and issue numbers;
  - feature, screen, spec, table and function names, and paths that carry them;
  - quotes from the project;
  - descriptions of its product or users.

  It covers commit messages and PR text. The identifiers bullet no longer says "A project's name
  plus enough context to explain a change is fine" — verified by review: read both bullets.

- **AC-2** `git grep -n -i -E "(lalista|home-os|website)('s)? +PRs?\b"` finds nothing.
- **AC-3** Every PR number left in the tree belongs to the devshop or its fixture, harness or test
  repos — verified by review: read every line of `git grep -n -i -E "PRs? *#?[0-9]+"`.
- **AC-4** Every line the sweep changed, and every line that still names lalista, home-os or the
  website, carries only what the AC-1 bullet allows — verified by review: read the PR diff and
  `git grep -n -i -E "lalista|home-os|website"` against the bullet.
- **AC-5** No lesson is lost. `kit/notes/revamp/lessons.md` keeps its 62 `### L-` headings with
  the same ids and titles, each with a rule and a **Why**, and every "Considered, not carried" entry
  keeps its id and reason — verified by review: diff the heading list and read the changed Why
  blocks.
- **AC-6** These passages in `lessons.md` describe the new citation style (project name and shape,
  no PR numbers or spec paths) instead of "home-os PR n" and "`specs/<feature>/…`":
  - the intro;
  - the Sources and home-os notes;
  - L-01;
  - the sources table.

  Verified by review: read those passages.

- **AC-7** Merged specs keep their **Go:** line and AC items unchanged — verified by review: the
  diff of `specs/` touches no `**Go:**` or `**AC-` line except in this spec.
- **AC-8** `docs/README.md` lists this spec, and `tests/run.sh` passes.

## Out of scope

- Rewriting git history, or editing merged PR titles and bodies on GitHub (D-12).
- A lint check or test for the rule (Decisions).
- Removing project names, roles or stack mentions that the bullet allows.
- The other rules in CLAUDE.md.
