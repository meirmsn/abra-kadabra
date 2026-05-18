<!-- gstack-plan: kit/ROADMAP.md § Canonical product-update blurb -->
<!-- generated-by: ad-hoc devshop /ak-build (no gstack plan; ROADMAP entry is the spec) -->
<!-- date: 2026-05-17 -->

# Spec: product-update-pr-section

**Sources:**

- `kit/ROADMAP.md § Canonical product-update blurb across PR body / BUILD-LOG / deploy comments` — primary scope (deleted at ship time per the close-out convention; pre-ship snapshot lives in git history at `feat/product-update-pr-section`'s base commit).
- Pattern observed: home-os PR #27 (2026-05-17) — eng-shaped Summary + 400-word BUILD-LOG entry forced post-deploy re-derivation of the product story.

## Product update

### Headline (user-facing)

Every shipped PR now writes one product story that lands the same way everywhere — the PR body, the build log, the ready-for-review comment, the deploy comment — instead of three eng-flavored re-derivations.

### Detail (team-facing)

Adds a canonical `## Product update` section to spec.md with two named sub-sections — Headline (1–2 sentences, marketing-grade, zero eng vocabulary) and Detail (1–4 sentences, team-facing, light eng OK). The PR body's lead section is renamed from `## Summary` to `## Engineering details` and `## Product update` (both blurbs) becomes the first content after the H1. BUILD-LOG gains a sibling `Headline:` field and `Summary:` is repointed at Detail. Phase 7 ready-for-review uses Detail; `/ak-go-live` Step 6 deployed-to-prod uses Headline as lede + Detail as context. Phase 0.2.6 lints Headline for forbidden eng vocabulary (backticked identifiers, snake_case, PascalCase components, RPC suffixes, migration numbers, route paths, cross-PR refs); Phase 6 Part D pairs Gate A (operator confirms both blurbs against the diff) with Gate B (automated claim-vs-diff cross-check via noun-extraction + audience-shape mismatch detection). Both gates are advisory; the operator is the decision.

## Scope

Implemented in this PR:

- **`/ak-spec` SKILL.md**: required `## Product update` section in the spec template (Headline + Detail sub-sections, edge-case shapes, forbidden-vocabulary contract for Headline, downstream-routing notes). Quality-checklist item added.
- **`/ak-build` SKILL.md**:
  - Phase 0.2: both blurbs surface as first named bullets of Scope preview.
  - Phase 0.2.6: new — Headline forbidden-vocabulary auto-lint before preview (advisory; rewrites + notes).
  - Phase 0.3: spec.md skeleton template includes `## Product update` section so Phase 1's expansion preserves it.
  - Phase 4.1: pre-composes title + `## Product update` (verbatim from spec) + `## Engineering details` (renamed from `## Summary`). Stashed at `/tmp/ship-product-update.md` + `/tmp/ship-engineering-details.md`.
  - Phase 4.2: `/ship` handoff directive carries the new ordering (Product update first, Engineering details second).
  - Phase 4.3: verifies the body shape post-`/ship`.
  - Phase 4.0 / 5.6 BUILD-LOG entry: new `Headline:` field (verbatim from spec Headline), `Summary:` repointed at Detail.
  - Phase 5.3.5: new drift signal #5 — product-blurb stale check (noun-coverage on new files since /ship + Headline/Detail audience-shape mismatch).
  - Phase 6 Part D: new — Gate A (operator confirms blurbs vs diff) + Gate B (automated claim-vs-diff cross-check). Inlined logic; no separate script.
  - Phase 7: ready-for-review uses Detail blurb verbatim.
- **`/ak-go-live` SKILL.md Step 6**: deployed-to-prod comment uses Headline as lede + Detail as context.
- **`CLAUDE.md` § Commit + PR text style**: updated to describe the two-section PR body (Product update + Engineering details).
- **`kit/docs/guide/conventions.md` § Commit + PR Text Style**: new "PR body structure" subsection, new "Product update style" subsection, new "Body / Engineering details style" rename, routing-table update.
- **`kit/docs/guide/workflow.md`**: new "Phase 4.1 — Product update section leads the PR body" paragraph; Phase 6 description names Part D + Gate A/B; Phase 7 mentions Detail lede; BUILD-LOG description names Headline + Summary fields.
- **`kit/tests/util-product-update-blurb.bats`**: 37 tests covering ak-spec contract, ak-build wiring across phases, ak-go-live Step 6, behavioral runs of the Phase 0.2.6 lint regex set, and noun-extraction / audience-shape mismatch heuristics.
- **`PLAN.md`**: row moved from `## Planned` to `## Active`.
- **`kit/ROADMAP.md`**: source entry deleted (closing convention).

Deferred (per ROADMAP cost/risk notes):

- **Gate C** — live post-deploy product-blurb attestation via browse daemon. Defer to a v1 sibling entry; reuse canary skill's existing browse-daemon usage when scoped.
- **CHANGELOG aggregation** — `/document-release` consumes Headline strings. This PR creates the inputs; aggregation is downstream.

## Tests

Bats: `kit/tests/util-product-update-blurb.bats` — 37 tests passing locally against `feat/product-update-pr-section` HEAD.

## Out of scope

- A separate `kit/scripts/product-update-check.sh` helper. Logic is inlined in SKILL.md instead (kept the convention self-contained; bats tests validate the inlined heuristic). Original /tmp draft remains available if a future PR consolidates it.
- Template `BUILD-LOG.md` / `PLAN.md` stub edits — the stubs are sealed placeholders that the skill writes into at runtime; no convention reference lived there to update.
- Project-side adoption — this PR ships the devshop convention; the next project running `/ak-build` exercises it end-to-end and surfaces any rough edges.
