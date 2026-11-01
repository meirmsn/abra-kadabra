# Discipline guidelines

One file per discipline, `<discipline>.md` (for example `frontend.md`, `backend.md`, `data.md`,
`ui.md`, `security.md`). The `build` skill reads the guideline for each discipline a change
touches, and the project's own rules win on conflict (TARGET § L3 Build 2). They start from the
harvest's engineering lessons (Build 8, [lessons.md](../../kit/notes/revamp/lessons.md)).

- [`design.md`](design.md): what a product looks like, read with `ui.md` by every change that
  changes what a page renders (there is no "design" discipline; `build` names it): `DESIGN.md`
  first, what enforces what, the surface, the placeholder rule, components and motion, done, never
  ([spec](../../specs/design-guideline.md)).
- [`ui.md`](ui.md): every user interface: responsive, light and dark with a toggle, the control
  contract, starting from [`runtime/templates/ui/`](../templates/ui/) and checked by its two
  scripts. Proven by [`tests/ui-tokens-check.test.sh`](../../tests/ui-tokens-check.test.sh) and
  [`tests/ui-render-check.test.sh`](../../tests/ui-render-check.test.sh).
