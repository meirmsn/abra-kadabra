# Parallel branches stop conflicting on shared lists and counters

**Go:** "go" (owner, 2026-11-10)

## Intent

Picks up roadmap entry R-22 (source: F-NEW-161). A project ran parallel sessions, one feature branch
each, merged one at a time. After every merge, every other branch conflicted with `main`, always in
the same shared files: the landing page's item list, a site test that hard-codes the item count (and
acceptance tests asserting it, so each new item broke older items' tests and left older specs'
wording stale), the service worker's version and shell list, the README's list line, one
append-only decisions log, and `FINDINGS.md`'s sequential IDs (four branches each took the same
next ID). GitHub runs no CI on a conflicted PR, and sessions held lines back to dodge conflicts.
Root cause: shared lists and counters edited by hand on every branch.

The owner's candidates: the list and shell list generated from one manifest, tests that derive the
count from it and a version derived from a hash; finding IDs that can't collide (e.g. a date plus
a slug) in the findings template and its spec, and what that means for the devshop's own
`FINDINGS.md`; a decisions file per item instead of one shared log. The devshop owns the rules,
templates, skills and checks; the project's own files change in the project, not here.

## Decisions

Each decision below is Claude's proposal of 2026-11-10, with the answers the managing devshop
session gave the same day to Claude's questions; the owner's go approves them as written.

- **The lists, counts and versions are derived from the items, never edited by hand.** The
  manifest is one file per item in a directory where the stack allows it, which leaves nothing
  shared to edit; otherwise one manifest file, which still conflicts when two branches append to
  its end (adjacent lines), but only there, resolved by keeping both. Rejected: one manifest
  everywhere, as it keeps the shared edit F-NEW-161 is about
- **The rules live in one new guideline, `runtime/guidelines/parallel.md`,** which `ak:build` § 2
  loads for a change that adds an item to a collection (a page, a game, a route), and `ak:split`
  § 2 links when slices each add an item: the first such slice sets up the layout and the derived
  lists. Rejected: repeating the rules in both skills
- **A version is a hash of what it versions,** computed at build time (e.g. a service worker's
  cache version from the shell files' contents), never a number a branch bumps
- **Decisions go in the item's own spec,** whose `## Decisions` section is already one file per
  change. A project with a shared decisions log stops appending to it and leaves it as history.
  Rejected: a new decisions file per item, as a second home for the same thing
- **Finding IDs can't collide: `F-<YYYY-MM-DD>-<slug>`,** the date the row is logged and a
  2-to-5-word lowercase kebab-case slug of what was noticed (`F-2026-11-10-shared-list-conflicts`),
  for projects and the devshop alike (no `NEW`). In the devshop, a slug describes, never names,
  another project or its features, as every devshop text does (CLAUDE.md). A duplicate ID found when
  merging `main`: the same thing becomes one row with both sightings; a different thing gets a word
  added to the incoming row's slug. Existing IDs stay as they are (`F-NEW-<n>`, `F-<n>`), since
  notes, lessons and the roadmap cite them, and nothing parses them. Rejected: renumbering every
  row; a random suffix (unreadable)
- **Where a new row goes:** after the existing rows, in ID order among the dated rows, so rows of
  different days don't touch. Two rows that still land side by side conflict in git; the
  resolution is "keep both". Whether GitHub honours a `merge=union` attribute, which would remove
  that conflict, is untested and stays out of this change
- **The record tables are kept compact, outside the formatter (changed after the go):** Prettier
  pads every column of a Markdown table to its longest cell, so a row with a longer ID or text
  rewrites every row, and the first dated ID rewrote all of `FINDINGS.md`'s. `FINDINGS.md` and
  `ROADMAP.md` go in `.prettierignore`, and their table rows are written compact (`| a | b |`, one
  space beside each pipe), so a row never touches another; both are compacted once in this PR, a
  formatting-only diff. The findings and roadmap templates tell projects the same, and a lint
  check holds the devshop's two files to it. Rejected: keeping the formatter (any longer cell still
  rewrites the table); a list instead of a table (it reopens the row format of 2026-10-16). Owner,
  2026-11-10, choosing option A of three: "A"
- **This supersedes one decision of `specs/findings-and-roadmap.md`** ("Parallel sessions: … the
  next free `F-` or `R-` number") for `F-` IDs, and leaves its `R-` half; that spec stays as it
  was, as the record of 2026-10-16, and the findings template carries the rule. Changed after the
  go: the reviewer takes the one spec file a change touches as its spec, so a note there made the
  review could-not-run. Rejected: a separate PR for the note. Owner, 2026-11-10, choosing option 1
  of two: "1" **`R-<n>` roadmap IDs stay sequential:** only the owner adds
  entries, one records PR at a time, so they don't race
- **A new check, `runtime/scripts/count-check.py`,** runs in the project's fast tier: in required
  CI, so a wall's input, held to the bar of every project-facing check (a known-bad input per form,
  mutants killed, exit 2 on what it can't read). It is a heuristic over single lines, so a line it
  misreads can carry the marker `count-check: allow` in a comment, which the reviewer sees in the
  diff, and its failure message names the marker. It blocks: a check that only warns gets
  ignored, and the marker is the safety valve. It is placed only where needed: an `optional` devshop copy in `runtime/project-files.txt`
  (`scripts/count-check.py`). `check-fast.sh` is a seed, so an existing project gets its new
  `COLLECTIONS` block as a template diff at its next upgrade
- **This PR also marks `ROADMAP.md`'s R-21 row `Done, PR #191`,** which PR #191 didn't do itself,
  and R-22's row Done with this PR, as the spec template's rule says. Asked by the devshop session
  that runs R-21 to R-23 one at a time; this task's first brief said not to edit `ROADMAP.md`
  because the three ran in parallel then
- **`merge=union` on `FINDINGS.md` is logged, not changed:** a `low` row with the new ID form, to
  watch whether GitHub honours it

## Acceptance items

- **AC-1** `runtime/guidelines/parallel.md` exists, is listed in `runtime/guidelines/README.md`,
  and says: a branch adding an item edits no hand-kept shared list; the item list, shell list,
  README list line, counts and versions are derived from the items at build or test time; a
  version is a hash of what it versions; a test or spec states the rule over a collection ("one
  tile per item") and never its current count; decisions go in the item's spec, not a shared log;
  how the project declares a collection for `count-check.py` — verified by review: the file and
  its index line
- **AC-2** `runtime/skills/build/SKILL.md` § 2 loads `parallel.md` for a change that adds an item to
  a collection, and `runtime/skills/split/SKILL.md` § 2 says the first slice that adds an item sets
  up the layout and the derived lists, linking `parallel.md` — verified by review: the two diffs
- **AC-3** `runtime/templates/spec.md`'s acceptance-items comment says an item over a collection
  states the rule, not the current count — verified by review: the diff
- **AC-4** `runtime/templates/findings.md` gives the finding ID
  as `F-<YYYY-MM-DD>-<slug>` with the slug's form and its no-identifiers rule, says existing IDs
  stay, says where a new row goes and how a duplicate ID and a leftover conflict are resolved, no
  longer says "next free number" for findings, and `runtime/templates/roadmap.md` keeps the
  `R-<n>` rule unchanged — verified by review: the two diffs
- **AC-5** `count-check.py --tests PATH... COLLECTION...` exits 1 and names the file and line of
  each line under the PATHs that asserts a collection's current item count N as a number literal,
  in each of these forms: `toHaveLength(N)`, `toHaveCount(N)`, `.length).toBe(N)`,
  `.length).toEqual(N)`, `.length === N`, `.length == N`, `N === ….length`, `.count()).toBe(N)`,
  `assert.equal(….length, N)`, `assert.strictEqual(….length, N)`, `assert len(…) == N`,
  `N == len(…)`, `assertEqual(len(…), N)`, and the message names the `count-check: allow` marker
  as the fix for a misread line; `tests/count-check.test.sh` feeds a known-bad file per form
- **AC-6** `count-check.py` exits 0 when those forms take the count from the collection
  (`toHaveLength(items.length)`), when the literal is another number, on N outside a count
  assertion, and on a flagged line that carries `count-check: allow`
- **AC-7** A COLLECTION is a directory (N is its entries, files and subdirectories, dot-entries
  skipped), a `.json` file holding an array (N is its length), or `<file>.json#<key>`, an array
  under that top-level key. A collection of fewer than 2 items passes and says it is too small to
  check. The PATHs are read as `spec-check.py --tests` reads them (every file below a directory;
  `node_modules` and dot-directories skipped). `count-check.py` exits 2, never 0, on a missing
  collection, a JSON file that doesn't parse, a JSON value or key that isn't an array, a missing
  PATH, no files under the PATHs, or no COLLECTION
- **AC-8** `runtime/templates/check-fast.sh` has a `COLLECTIONS` list, empty by default, which runs
  nothing and says so; when it has entries it runs `scripts/count-check.py` over `TEST_DIRS` and
  them. `tests/check-fast-template.test.sh` shows both: the empty list's message, and a declared
  collection with a known-bad test failing the tier
- **AC-9** Each mutant of `count-check.py` is killed by `tests/count-check.test.sh`: each assertion
  form dropped, the count off by one, the too-small threshold moved, the allow marker ignored, each
  exit-2 path turned into a pass
- **AC-10** `count-check.py` is in `runtime/project-files.txt` as an `optional` devshop copy and in
  `runtime/project-contract.txt`, and `tests/contract-check.test.sh` passes
- **AC-11** `FINDINGS.md` gains a `low` row, in the new ID form, on whether GitHub honours
  `merge=union`, and no existing row's ID changes — verified by review: the diff of `FINDINGS.md`
- **AC-12** `ROADMAP.md`'s R-21 row reads `Done, PR #191`,
  R-22's reads Done with this PR's number, and no other row changes — verified by review: the diff
  of `ROADMAP.md`

- **AC-13** `scripts/table-rows-check.py FILE...` exits 1 and names the file and line of each table
  row with two or more spaces beside a pipe, exits 0 on compact rows, and exits 2, never 0, on a
  missing file or a file with no table; `tests/table-rows-check.test.sh` feeds it a padded row
  and kills its mutants
- **AC-14** `scripts/lint.sh` runs `table-rows-check.py` over `FINDINGS.md` and `ROADMAP.md`, both
  are in `.prettierignore`, and both hold only compact rows; `runtime/templates/findings.md` and
  `runtime/templates/roadmap.md` say to keep the file out of the formatter and write rows compact

## Out of scope

- Changing any project's own files (its landing page, tests, service worker, README or decisions
  log): that happens in the project, from the guideline
- A generator for the derived lists or the hashed version: that is the project's build, in its
  stack
- Renumbering existing finding IDs, or changing `R-<n>` roadmap IDs
- A check on specs' wording that states a count (the template's guidance only, AC-3)
- Counts held in a named constant, assertions over several lines, and shell tests' `-eq`: the check
  reads single lines in the forms of AC-5
- Merge drivers or `.gitattributes` changes
