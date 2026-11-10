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

- **Each item adds its own file; anything that lists, counts or versions the items is derived from
  them, never edited by hand:** two branches that each append a line at the end of the same list
  still conflict in git (adjacent edits), so one shared manifest moves the conflict into one file
  instead of removing it. One file per item in a directory (or a manifest a branch never edits by
  appending, see Q1), with the tile list, the shell list, the README line and the version built
  from it, leaves nothing shared to edit. Rejected: a single hand-appended manifest as the end
  state (proposed, Claude, 2026-11-10; Q1)
- **The rules live in one new guideline, `runtime/guidelines/parallel.md`,** which `ak:build` § 2
  loads for any change that adds an item to a collection (a page, a game, a route, a finding), and
  `ak:split` § 2 points to when slices each add an item (the first such slice sets up the per-item
  layout and the derived lists). Rejected: repeating the rules in both skills (proposed, Claude,
  2026-11-10)
- **A version is a hash of what it versions,** computed at build time (e.g. the service worker's
  cache version from the shell files' contents), never a number a branch bumps (proposed, Claude,
  2026-11-10)
- **Decisions go in the item's own spec,** whose `## Decisions` section is already one file per
  change; a project keeps no shared append-only decisions log. Rejected: a new `decisions/<item>.md`
  file per item, as a second home for the same thing (proposed, Claude, 2026-11-10; Q3)
- **Finding IDs can't collide: `F-<YYYY-MM-DD>-<slug>`,** the date the row is logged and a
  2-to-5-word kebab-case slug of what was noticed (`F-2026-11-10-shared-list-conflicts`); the
  devshop's rows the same (no `NEW`). Two sessions that pick the same date and slug noticed the same
  thing, which the match-first rule already makes one row. The rule "next free number, checked
  against the latest main; on a clash, renumber" goes from the template and its spec. Existing IDs
  stay as they are (`F-NEW-<n>`, `F-<n>`), since notes, lessons and the roadmap cite them; nothing
  parses them. Rejected: renumbering every row; a random suffix (unreadable) (proposed, Claude,
  2026-11-10; Q2)
- **Rows still conflict when two branches append to the table's end;** the template says to insert
  a new row at its place in ID order (dates, then slugs), which spreads same-day rows apart, and the
  conflict that is left is resolved by keeping both rows. Whether GitHub honours a `merge=union`
  attribute on `FINDINGS.md`, which would remove it, is untested (proposed, Claude, 2026-11-10; Q4)
- **`R-<n>` roadmap IDs stay sequential:** only the owner adds entries, one records PR at a time,
  so they don't race (proposed, Claude, 2026-11-10)
- **A new check, `runtime/scripts/count-check.py`,** placed in projects as `scripts/count-check.py`
  (a devshop copy, `runtime/project-files.txt`) and run by `check-fast.sh` when the project declares
  a collection in its `COLLECTIONS` list: it fails when a test file states the collection's current
  item count as a literal in a count assertion. It is a heuristic and is called feedback, not a
  wall (proposed, Claude, 2026-11-10; Q5)
- **In this PR, `ROADMAP.md`'s R-21 row is marked Done with PR #191** (R-21 had no PR of its own
  to do it; asked by the devshop session that runs R-21 to R-23 in order) and R-22's row Done with
  this PR (the spec template's rule). This task's first instruction was not to edit `ROADMAP.md`
  because sibling sessions ran in parallel; they now run one at a time (Q6)

## Acceptance items

- **AC-1** `runtime/guidelines/parallel.md` exists, is listed in `runtime/guidelines/README.md`,
  and says: a branch adding an item adds its own file and edits no shared list; the list, shell
  list, README list line, counts and versions are derived from the items at build or test time; a
  version is a hash of what it versions; a test or spec states the rule over a collection ("a tile
  per item") and never its current count; decisions go in the item's spec, not a shared log
- **AC-2** `runtime/skills/build/SKILL.md` § 2 loads `parallel.md` for a change that adds an item to
  a collection, and `runtime/skills/split/SKILL.md` § 2 says the first slice that adds an item sets
  up the per-item layout and the derived lists, linking `parallel.md`
- **AC-3** `runtime/templates/spec.md`'s acceptance-items comment says an item over a collection
  states the rule, not the current count
- **AC-4** `runtime/templates/findings.md` and `specs/findings-and-roadmap.md` give the ID as
  `F-<YYYY-MM-DD>-<slug>` with the slug's form, say existing numbered IDs stay, say where a new row
  goes (ID order) and how a leftover conflict is resolved (keep both rows), and no longer say "next
  free number" for findings
- **AC-5** `count-check.py <collection> <tests-path>...` exits 1 and names file and line for each
  test line that asserts the collection's current count as a literal, in each of these forms:
  `toHaveLength(N)`, `toHaveCount(N)`, `.length).toBe(N)` / `.toEqual(N)`, `.length === N` /
  `== N`, `.count()).toBe(N)`, `assert len(…) == N`, `assertEqual(len(…), N)`; a known-bad fixture
  per form is in its test
- **AC-6** `count-check.py` exits 0 on the same forms when the count comes from the collection
  (`toHaveLength(items.length)`), when the literal is a different number, and on a literal N
  outside a count assertion
- **AC-7** A collection is a directory (its item count is the number of entries in it, dot-files
  skipped) or a JSON file holding an array (its length); `count-check.py` exits 2, never 0, on a
  missing collection, a JSON file that doesn't parse or isn't an array, a missing tests path, or no
  test files under the paths
- **AC-8** `runtime/templates/check-fast.sh` runs `count-check.py` for each entry of a
  `COLLECTIONS` list (empty by default, which runs nothing and says so); `count-check.py` is in
  `runtime/project-files.txt` and `runtime/project-contract.txt`, and the contract test passes
- **AC-9** The mutants of `count-check.py`'s detection (each assertion form dropped, the count
  compared off by one, the exit-2 paths turned into passes) are each killed by its test
- **AC-10** `FINDINGS.md`'s new row for anything this change logs uses the new ID form, and no
  existing row's ID changes — verified by review: the diff of `FINDINGS.md`
- **AC-11** `ROADMAP.md`'s R-21 row reads `Done, PR #191` and R-22's reads Done with this PR's
  number, and no other row changes — verified by review: the diff of `ROADMAP.md`

## Out of scope

- Changing any project's own files (its landing page, tests, service worker, README or decisions
  log): that happens in the project, from the guideline
- A generator for the derived lists or the hashed version: that is the project's build, in its
  stack
- Renumbering existing finding IDs, or changing `R-<n>` roadmap IDs
- A check on specs' wording that states a count (guidance only, AC-3)
- Merge drivers or `.gitattributes` changes, until Q4's experiment
