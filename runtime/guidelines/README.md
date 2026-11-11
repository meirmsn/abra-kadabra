# Discipline guidelines

One file per discipline, `<discipline>.md` (for example `frontend.md`, `backend.md`, `data.md`,
`ui.md`, `security.md`). The `build` skill reads the guideline for each discipline a change
touches, and the project's own rules win on conflict (TARGET § L3 Build 2). They start from the
harvest's engineering lessons (Build 8, [lessons.md](../../kit/notes/revamp/lessons.md)).

- [`design.md`](design.md): what a product looks like, read with `ui.md` by every change that
  changes what a page renders (there is no "design" discipline; `build` names it): `DESIGN.md`
  first, what enforces what, the surface, the placeholder rule, components and motion, done, never
  ([spec](../../specs/design-guideline.md)).
- [`flaky-tests.md`](flaky-tests.md): a CI failure in a test the change doesn't touch: never
  re-run, the cause reproduced and fixed in its own PR that merges first, how to find the cause,
  where to look first and what a fix never does ([spec](../../specs/shared-changes-first.md)).
- [`parallel.md`](parallel.md): every change that adds an item to a collection (a page, a game, a
  route), and a change that needs shared code changed (it goes first, in its own PR): one file per
  item, the lists, counts and versions derived from them, tests and specs that state the rule and
  not the count, the count check that enforces it, and shared changes first
  ([spec](../../specs/parallel-safe-shared-files.md),
  [spec](../../specs/shared-changes-first.md); proven by
  [`tests/count-check.test.sh`](../../tests/count-check.test.sh)).
- [`ui.md`](ui.md): every user interface: responsive, light and dark with a toggle, the control
  contract, starting from [`runtime/templates/ui/`](../templates/ui/) and checked by its three
  scripts. Proven by [`tests/ui-tokens-check.test.sh`](../../tests/ui-tokens-check.test.sh),
  [`tests/ui-render-check.test.sh`](../../tests/ui-render-check.test.sh) and
  [`tests/ui-design-md-check.test.sh`](../../tests/ui-design-md-check.test.sh).
