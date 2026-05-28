## Gate 11: convention (adapted — devshop)

- Result: pass

Devshop convention checks for this prose-only change:
- **SKILL.md frontmatter** — intact (name: ak-build, version: 2.0.0, description). The block was inserted at the body (after the intro, before `## Architecture`), not in the frontmatter.
- **No new shell scripts** — diff touches no `kit/scripts/**`, so no script-structure / new-bats-file requirement.
- **Guide-doc routing** — `workflow.md` is already linked in the routing index; the `routing-link-resolution.bats` + `structural-invariants.bats` suites pass at HEAD (included in Gate 2d's 1525-test run).
- **Bats coverage for the change** — the change ships its own regression guard (util-ak-build-skill.bats Section E).
- **Conventional commits** — all 5 branch commits use conventional `type(scope):` subjects describing the observable change.

## Dismissals

None
