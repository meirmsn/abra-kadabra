# Parallel work on shared lists and shared code

Read by every change that adds an item to a collection: a page, a game, a route, a menu entry, a
cache entry ([spec](../../specs/parallel-safe-shared-files.md)); and by every change that turns
out to need a change to shared code ([spec](../../specs/shared-changes-first.md)). Several
sessions often work at once, one branch each, merged one at a time. A file every branch edits
conflicts on every branch after each merge. GitHub then runs no CI on the conflicted PRs, and each
fix costs a round of merging `main` and running CI again. Once, ten branches of one project each
conflicted in the same six places. The rules below leave a branch nothing shared to edit, and
land what must be shared first.

## One file per item, everything else derived

- **A branch that adds an item adds the item's own file and edits no hand-kept list.** Keep the
  collection as a directory with one file per item where the stack allows it (a page per file, an
  entry per JSON file). Where it doesn't, keep one manifest file. Two branches that append to its
  end still conflict there, on adjacent lines, but only there, and the fix is to keep both lines.
- **What lists, counts or versions the items is derived from them** at build or test time:
  the landing page's tiles, a service worker's shell list, the README's list line, a sitemap, a
  menu. None of these is a second copy a branch edits by hand.
- **A version is a hash of what it versions,** computed at build time (a service worker's cache
  version from the shell files' contents), never a number a branch bumps. Two branches never pick
  the same next number, because there isn't one.
- **The README describes the collection and links where it is listed,** instead of repeating its
  items on one line.

## Tests and specs state the rule, not the count

- A test over a collection takes its expected count from the collection (`toHaveLength(items.length)`),
  never the number today (`toHaveLength(8)`). Each new item would otherwise break the older items'
  tests, on branches that didn't touch them.
- A spec's acceptance item states the rule ("one tile per item"), never the current count. A count
  in an older spec goes stale with the next item.
- **The count check:** a project lists its collections in `scripts/check-fast.sh`'s `COLLECTIONS`
  (a directory, a `.json` array, or `<file>.json#<key>`) and places `scripts/count-check.py` from
  the devshop's `runtime/scripts/`. The fast tier then fails a test line that states a listed
  collection's current count in a count assertion. It reads single lines, so a line it misreads
  carries the comment `count-check: allow`, which the reviewer sees in the diff.

## Records

- **Decisions go in the item's own spec** (its `## Decisions`), which is already one file per
  change. A project keeps no shared, append-only decisions log. One that has a log stops appending
  to it and leaves it as history.
- **Finding IDs can't collide:** `F-<YYYY-MM-DD>-<slug>`, as the findings template says.

## Slices

When `ak:split` plans slices that each add an item, the first such slice sets up the layout (the
directory or manifest, the derived lists and the hashed version) and the `COLLECTIONS` entry, so
every later slice only adds a file.

## Shared changes go first, in their own PR

**Shared** is code, config or a test that more than one item, page or feature uses, or that every
branch's CI runs: a `shared/` directory, a layout, a helper, a test over all items. Once, a prompt
every item used shipped inside one item's PR, and every other branch had to adapt its tests.

- **A feature that turns out to need a shared change stops there.** Raise it with the owner as a
  spec change (`ak:intent` step 5). On a yes it is its own change: its own spec and go, or, with no
  real choice in it, a bug fix whose failing test is the spec. The fix to a shared or flaky test
  is one too ([flaky-tests.md](flaky-tests.md)).
- **The same session builds it,** on its own branch cut from a freshly fetched `main`, after
  committing the feature branch's work. Its PR tells the owner it should merge before the PRs that
  wait on it.
- **The waiting feature PR isn't shipped until the shared PR has merged;** then its branch merges
  `main` once and ships.
- **A shared change already pushed on a feature branch moves out** with a revert commit there,
  never a rebase or force-push.
- **The owner declines the separate PR:** the shared change stays in the feature PR, and the PR's
  body says so.
