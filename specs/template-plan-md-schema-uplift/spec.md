<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: template-plan-md-schema-uplift -->
<!-- date: 2026-05-23 -->

# Spec: template-plan-md-schema-uplift

**Sources:**

- `kit/TODOS.md` § [v0] Update `template/PLAN.md` schema — primary scope
- `PLAN.md` § Planned (v0) row `template-plan-md-schema-uplift` — PLAN entry
- `.claude/skills/ak-spec/SKILL.md § Step 4` — Planned→Active flip contract

(Rewrite `template/PLAN.md` from the old 3-column simple schema to the devshop's
rich 8-column Lev-scored schema so new projects scaffold with priority-scored
planning out of the box.)

---

## Product update

### Headline (user-facing)

New projects get the full priority-scored planning table out of the box — leverage
formula, dependency tracking, and source pointers included.

### Detail (team-facing)

Rewrite `template/PLAN.md` from the old 3-column simple schema (`# / Feature /
Notes`) to the devshop's rich 8-column Lev-scored schema (`Feature / Hook / Impact
/ Risk / Cost / Lev / Deps / Source`). Drop `## Bundling cheatsheet`
(project-overkill). Adapt Source pointers to project-side files
(`PRODUCT-ROADMAP.md` / `TODOS.md`). Verify `/ak-spec § Step 4` Planned→Active
flip is compatible. Include per-project migration recipe in the commit body.

---

## Decisions (resolved at spec time)

6 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Include Bundling cheatsheet in template?

**Decision:** No — drop it.

**Rationale:** TODOS entry explicitly says "overkill for project-side planning";
projects rarely have enough concurrent rows to bundle.

### D2: Include "How to add entries" prose block?

**Decision:** Yes — include it.

**Rationale:** The column definitions (Feature, Hook, Impact, Risk, Cost, Lev,
Deps, Source) need explanation for the project operator who reads PLAN.md cold.
Without the prose, the 8-column table is inscrutable.

### D3: Adapt Source column pointers for project context?

**Decision:** Yes — point at `PRODUCT-ROADMAP.md` / `TODOS.md`.

**Rationale:** Projects store long-form context in project-side files, not devshop
kit paths.

### D4: Keep Lev formula + rating scale table?

**Decision:** Yes — identical to devshop.

**Rationale:** The formula is the load-bearing part; changing it means devshop and
project PLAN.md speak different languages.

### D5: Include per-project migration recipe?

**Decision:** Recipe in commit message only — no migration script.

**Rationale:** PLAN.md is `[scaffold-once]` so `from-devshop.sh` won't propagate.
Only 2 projects (lalista, home-os) need manual one-time rewrite. Recipe goes in
the commit body's `**Existing projects:**` block.

### D6: Does /ak-spec Step 4 need changes?

**Decision:** No — verify only.

**Rationale:** Step 4 moves a row from Planned → Active as `Branch / Spec / Hook`.
The rich Planned columns (Impact, Risk, Cost, Lev, Deps, Source) are dropped on
transition — correct because Active rows don't need scoring.

---

## In scope

- Rewrite `template/PLAN.md` (~47 → ~75 lines) with rich 8-column schema
- Adapt all project-specific references (Source pointers → `PRODUCT-ROADMAP.md` / `TODOS.md`)
- Keep Lev formula, rating scale, Deps glyphs, lifecycle rules identical to devshop
- Drop `## Bundling cheatsheet`
- Verify `/ak-spec § Step 4` compatibility (read-only check, expect no changes)
- Per-project migration recipe in commit body (`**Existing projects:**` block)

## Out of scope

- Bundling cheatsheet for projects
- Migration script (only 2 projects; manual rewrite)
- Changes to `/ak-spec § Step 4` (verified compatible as-is)
- Actually migrating lalista or home-os PLAN.md (separate per-project commits)

## Task order

1. Rewrite `template/PLAN.md` to rich schema
2. Verify `/ak-spec § Step 4` compatibility
3. Compose migration recipe in commit body

## Tests

No tests — this is a docs-only template change. The pre-commit docs-coverage
hook validates the commit.
