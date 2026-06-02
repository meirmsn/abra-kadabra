# Tasks — skill-operational-claude-md-routing

## T1 — Relocate operational mechanic — done

- `21588ff` refactor(claude-md): relocate root-cause fix mechanic into ak-build skill
- CLAUDE.md § Implementation Approach shrunk to one-line value kernel + pointers.
- `devshop-mode.md` gained § Phase 0 fix-assessment (the relocated mechanic).
- conventions.md § Root-cause over bandaid repointed at the skill.
- Dogfood: the live classification reviewer PASSED the kernel-shrink (existing
  rule already accepted "relocated to the owning skill").

## T2 — skill-operational routing destination — done

- `1654a52` docs(claude-md-guide): add skill-operational routing destination
- claude-md.md: new routing-table row (skill-operational → owning SKILL.md),
  reference-class destination clause names SKILL.md, reachability-split callout.

## T3 — Enforce in the gate + test — done

- `c90bd3d` feat(claude-md-gate): enforce skill-operational routing in the classification gate
- Hook BLOCK guidance + header name the skill destination.
- adversarial-review.sh rule 15(c) (skill file must be staged) + 15(f)
  skill-operational sub-test.
- bats Test 5 pins the guidance; full guard suite green (12/12).
- hooks.md classification-gate entry documents the sub-test.

## Decisions (judgment calls made during implementation)

- **D3 applied as a routing destination, not a 4th class** — reused the existing
  3-class taxonomy; skill-operational is `reference`-class whose canonical home
  is a SKILL.md. Less churn, reuses the reachability test.
- **Doc-coverage pairing**: kit/scripts/\*\* edits paired with hooks.md (satisfies
  both `commit-hooks` and `scripts` surface groups); the routing/taxonomy doc
  (claude-md.md) shipped in T2.
- **No 4th bats assertion for the reviewer rule** — the reviewer (`claude -p`)
  isn't unit-testable in bats; the hook's guidance text is the testable surface,
  pinned by Test 5. Rule 15 changes are prose in the live-reviewed prompt.
