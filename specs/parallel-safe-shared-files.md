# Parallel branches stop conflicting on shared lists and counters

**Go:** pending

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

Each decision below is Claude's proposal of 2026-11-10, awaiting the owner's answer at the go.

- **The lists, counts and versions are derived from the items, never edited by hand.** The
  manifest's own shape is the owner's choice: (a) one manifest file, as asked, which still
  conflicts when two branches append to its end (adjacent lines), but in one file whose resolution
  is "keep both"; or (b) one file per item in a directory, which leaves nothing shared to edit.
  Claude proposes (b) where the stack allows it, (a) otherwise
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
- **This supersedes one decision of `specs/findings-and-roadmap.md`** ("Parallel sessions: … the
  next free `F-` or `R-` number"): that spec's line gains a note that F- IDs follow this spec from
  2026-11-10, and keeps its R- half. **`R-<n>` roadmap IDs stay sequential:** only the owner adds
  entries, one records PR at a time, so they don't race
- **A new check, `runtime/scripts/count-check.py`,** runs in the project's fast tier: in required
  CI, so a wall's input, held to the bar of every project-facing check (a known-bad input per form,
  mutants killed, exit 2 on what it can't read). It is a heuristic over single lines, so a line it
  misreads can carry the marker `count-check: allow` in a comment, which the reviewer sees in the
  diff. It is placed only where needed: an `optional` devshop copy in `runtime/project-files.txt`
  (`scripts/count-check.py`). `check-fast.sh` is a seed, so an existing project gets its new
  `COLLECTIONS` block as a template diff at its next upgrade
- **This PR also marks `ROADMAP.md`'s R-21 row `Done, PR #191`,** which PR #191 didn't do itself,
  and R-22's row Done with this PR, as the spec template's rule says. Asked by the devshop session
  that runs R-21 to R-23 one at a time; this task's first brief said not to edit `ROADMAP.md`
  because the three ran in parallel then. The owner confirms or drops it at the go

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
- **AC-4** `runtime/templates/findings.md` and `specs/findings-and-roadmap.md` give the finding ID
  as `F-<YYYY-MM-DD>-<slug>` with the slug's form and its no-identifiers rule, say existing IDs
  stay, say where a new row goes and how a duplicate ID and a leftover conflict are resolved, no
  longer say "next free number" for findings, and keep the `R-<n>` rule unchanged — verified by
  review: the two diffs
- **AC-5** `count-check.py --tests PATH... COLLECTION...` exits 1 and names the file and line of
  each line under the PATHs that asserts a collection's current item count N as a number literal,
  in each of these forms: `toHaveLength(N)`, `toHaveCount(N)`, `.length).toBe(N)`,
  `.length).toEqual(N)`, `.length === N`, `.length == N`, `N === ….length`, `.count()).toBe(N)`,
  `assert.equal(….length, N)`, `assert.strictEqual(….length, N)`, `assert len(…) == N`,
  `N == len(…)`, `assertEqual(len(…), N)`; `tests/count-check.test.sh` feeds a known-bad file per
  form
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
- **AC-11** A row this change adds to `FINDINGS.md` uses the new ID form, and no existing row's ID
  changes — verified by review: the diff of `FINDINGS.md`
- **AC-12** If the owner keeps the roadmap decision: `ROADMAP.md`'s R-21 row reads `Done, PR #191`,
  R-22's reads Done with this PR's number, and no other row changes — verified by review: the diff
  of `ROADMAP.md`

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
