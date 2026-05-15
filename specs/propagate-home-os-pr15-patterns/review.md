# Review — propagate-home-os-pr15-patterns

## Audit 1: manual (2026-05-14)

<!-- audited-at: 8460c01794086f6e20e5331a801673645333151a -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=1 low=1

### Docs findings

- [low] `kit/docs/guide/conventions.md:273` — Cross-reference `hooks.md § check-template-propagation.sh` points at a table-row label, not an actual heading. The new entry sits inside the guards table under `## Full Hook Chain Detail`; there is no H2/H3 named `check-template-propagation.sh`. Fix: rewrite as `hooks.md § Full Hook Chain Detail` — the `check-template-propagation.sh` row. (Other docs cross-refs in this codebase — e.g. CLAUDE.md → `hooks.md § Dismissal Log` — point at real H2s.)

### Tests findings

- [medium] `kit/tests/template-ci-yml-shape.bats` — The 5 baked-in fixes added to the commented-out `slow:` stub in `template/.github/workflows/ci.yml` (chromium+webkit install, step-level env mapping, quote-strip sed, `apps/web/test-results` artifact path, `supabase_edge_runtime` cold-start retry) AND the workflow-level `push: branches: [main]` flip (replacing `branches-ignore: [main]`) are NOT pinned by the existing structural test. The premise of this branch — "bake the canonical shape into the stub so the uncomment ritual is just 'strip every leading # '" — is undone if a future tidy-up silently drops a line. Fix: add 6 assertions (positive pins + a regression guard against `branches-ignore: [main]`) following the existing test's pattern (positive `grep -E ... assert_success` + negative `grep -E ... assert_failure`). Medium because regression only affects future scaffolds + uncomments; live lalista/home-os ci.yml have their own per-project tests.

### Bypass trailer audit

- `7ac4688` Docs-Coverage-Bypass: "One-line defensive `chown -R node:node /home/node/.claude/projects` ... grep zero matches across all 11 catalog docs" — **VERIFIED**. Enumeration was substantive (per-doc grep-verified zero-match attestations); init-devshop.sh edit is a bootstrap implementation detail with no documented behavior shift. FAQ.md mentions `/home/node/.claude/projects/-workspace/memory/` at line 84 but says nothing about ownership of that path. Bypass remains valid at HEAD.

### Findings detail

#### Docs

```
### [domain: docs] [section: C] [severity: low]
**File**: kit/docs/guide/conventions.md:273
**What**: Cross-reference "See `kit/docs/guide/hooks.md § check-template-propagation.sh` for the mechanic" points at a table-row label, not an actual heading. The guards table in hooks.md lives under `## Full Hook Chain Detail` and the new row sits inside that table; there is no H2 or H3 named `check-template-propagation.sh`.
**Why**: A reader following the § anchor convention expects to land on a heading by that name. The closest existing convention in this codebase (e.g. `hooks.md § Dismissal Log (...)` from CLAUDE.md:127) points at real H2 headings; this new cross-ref breaks that pattern.
**Fix**: Change conventions.md text to `hooks.md § Full Hook Chain Detail` — the `check-template-propagation.sh` row.
```

#### Tests

```
### [domain: tests] [section: A] [severity: medium]
**File**: kit/tests/template-ci-yml-shape.bats
**What**: The 5 baked-in fixes added to the commented-out `slow:` stub on this branch — (1) `playwright install --with-deps chromium webkit`, (2) step-level `${{ env.* }}` mapping per test step, (3) `sed -E 's/="(.*)"$/=\1/'` quote-strip before `>> $GITHUB_ENV`, (4) artifact upload path including `apps/web/test-results/`, (5) `supabase_edge_runtime` cold-start retry — AND the workflow-level `push: branches: [main]` flip (replacing `branches-ignore: [main]`) are NOT pinned by template-ci-yml-shape.bats.
**Why**: The premise of "bake the canonical shape into the commented stub so the uncomment ritual is 'strip every leading # ' rather than 'fill in the blanks'" is undone if a future tidy-up / refactor PR silently drops one of these lines. Next project to scaffold + uncomment would lose the fix and re-discover the bug. The propagation nudge added on this branch closes the lalista→devshop gap going forward, but it doesn't protect the template's own stub from internal regression.
**Fix**: Add 6 assertions (5 positive pins + 1 regression guard against `branches-ignore: [main]`) to template-ci-yml-shape.bats following the existing pattern.
```

## Audit 2: manual (2026-05-14)

<!-- audited-at: cc475f6cf605f90271e2686abd7ffef10fa15842 -->
<!-- range: 8460c01..HEAD -->

findings: high=0 medium=0 low=0

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)

### Status

Audit-2 confirms Audit-1's medium + low findings are both addressed:

- **medium (tests)** closed: 7 new structural assertions added to `kit/tests/template-ci-yml-shape.bats` pinning the 5 baked-in slow-job fixes + workflow-level `push: branches: [main]` shape (with `branches-ignore: [main]` regression guard). `bats template-ci-yml-shape.bats` → 31/31 pass.
- **low (docs)** closed: `kit/docs/guide/conventions.md:273` cross-reference now points at `hooks.md § Full Hook Chain Detail` — the `check-template-propagation.sh` row. Anchor grep-verified at hooks.md:104.
