<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: context-aware-guideline-routing -->
<!-- date: 2026-05-10 -->

# Spec: context-aware-guideline-routing

**Sources:**

- `kit/ROADMAP.md § Context-aware guideline routing for /ak-spec and /ak-implement` (lines 1708–1806) — primary scope and decision-list source
- `PLAN.md § Planned § Row 3` — backlog pointer + cost estimate
- `kit/docs/guide/README.md` — flat ToC, the file to promote into the routing index
- `kit/docs/guide/conventions.md` — 877-line mega-file (69 H2 sections), semantic-split candidate per D3
- `kit/docs/guide/*.md` (all 13 guides) — audit input
- `.claude/skills/ak-spec/SKILL.md` — Step 1.5 insertion target (D5)
- `.claude/skills/ak-implement/SKILL.md` line 26 — hardcoded `read conventions.md` replacement target (D6)
- `kit/docs/guide/workflow.md` — orientation paragraph target
- lalista PR 54 (2026-05-08) — surfacing incident that motivated the entry
- Prior spec `specs/ak-go-live-arm-a-preflight/spec.md` — style + structure reference

Promote `kit/docs/guide/README.md` from flat ToC to a recursive routing index, add per-file ToCs to every guide, surface natural section neighbors via `**See also:**` footers, and patch `/ak-spec` + `/ak-implement` to consult the routing index against each spec's Files + Decisions. End state: when an implementer's spec or diff touches a known pattern (PWA, RLS, optimistic mutation, custom-domain swap), the relevant guide section + skill suggestion auto-fires — replacing today's hardcoded "read conventions.md" with task-shaped retrieval.

---

## Decisions (resolved at spec time)

Nine `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without re-asking.

### D1: No new tier — restructure existing material

**Decision:** Do NOT introduce a new "insight" or "profile" tier. Existing `kit/docs/guide/*.md` files remain the substance. The PR's work is **routing into them precisely** and **improving their internal navigability**.

**Rationale:** Eliminates lift-and-drift risk, avoids two-locations-for-one-rule, and adds no new file format to maintain. A "persona" / "hat" emerges automatically from the set of routing matches a spec triggers — no separate persona file needed. The user explicitly rejected lifting substance into new tiers: "why not use existing files (with some regrouping if needed)?"

### D2: Recursive ToC depth — adaptive

**Decision:** Layer 1 (routing index in `kit/docs/guide/README.md`) and Layer 2 (per-file ToC at the top of every routed guide) are always present. Layer 3 (sub-ToC within a section) is added only where the audit flags it useful — long section (>~100 lines) **and** the H3s are independently routable. No uniform depth forced.

**Rationale:** "Not creating levels when not needed is wise" — forcing uniform depth invites spurious sub-ToCs on short, single-concept sections.

### D3: Regrouping aggressiveness — Medium-plus (audit-gated)

**Decision:** Audit phase outputs (a) a relocation list — sections clearly mis-filed across guides — AND (b) a `conventions.md` semantic-split candidate list — natural section clusters that could become standalone guides. Both lists go to the user for individual approval (Task 2 user gate) before any file moves or splits land. Cross-ref rewrites land in the same commit as each move/split (devshop convention from `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`). No forced splits; conventions.md splits happen only where natural groupings exist (the audit confirms ≥3 cohesive sections per candidate split).

**Rationale:** The user's framing — "split conventions into semantic groups if they exist already on parts of the guide" — explicitly allows splits when obvious, but per-decision rather than as a blanket directive. Medium-plus catches obvious misfilings + obvious split opportunities without ballooning the diff.

### D4: Routing-row target types — three uniformly

**Decision:** Routing rows can target one of three types, in priority order:

1. `(file, anchor)` tuple — most common; points at a specific H2/H3 anchor in a guide.
2. Skill invocation — e.g., "consider running `/cso`" when the trigger matches "security-boundary touched."
3. Full-file pointer — rare; only when whole-file relevance is the actual signal (e.g., `notifications.md` for ntfy setup).

**Rationale:** Unifies the three buckets the user originally floated (insights / profiles / skills) into one routing system. A "hat" emerges from the union of matches a spec triggers, instead of needing a separate persona file. The routing index becomes the single source of "what fires on this change."

### D5: `/ak-spec` patch surface — new Step 1.5

**Decision:** Add a new Step 1.5 to `/ak-spec` SKILL.md, between source discovery (Step 2 `cat $DESIGN_DOC`, `cat $TEST_PLAN`, etc.) and spec writing. The step parses the spec's tentative Files-to-touch + tentative Decisions, consults the routing index, and encodes matched gotchas as explicit Decisions in the spec being written.

**Rationale:** Spec-time encoding turns routing into a **before** intervention — the implementer reads the spec which already names the gotcha, instead of discovering it mid-task. Mirrors the existing convention where `/ak-spec` Phase 0 of `/ak-build` already resolves decisions before code is written.

### D6: `/ak-implement` patch surface — Step 1 swap

**Decision:** Replace `.claude/skills/ak-implement/SKILL.md` line 26's hardcoded `Before starting: read kit/docs/guide/conventions.md` with: parse spec → look up routing matches against Files + Decisions → read matched `(file ToC → section)` pairs → follow `**See also:**` footers where scope-relevant.

**Rationale:** Defense in depth — if `/ak-spec` Step 1.5 missed a trigger, `/ak-implement` Step 1's routing lookup catches it. Two-pass safety mirrors the existing pre-ship adversarial pattern (`/ak-pre-ship` Gate 5 is the third pass at audit time).

### D7: BATS coverage — three invariants

**Decision:** Three invariants enforced by BATS in `kit/tests/`:

1. **Link resolution**: every routing-row link resolves to a real anchor in a real guide file. No broken targets.
2. **Routing completeness**: every guide in `kit/docs/guide/*.md` is either listed in the routing index OR explicitly tagged "out-of-routing" (e.g., `macos-host-setup.md`, `architecture.md`). No silent omission.
3. **Real-world grounding**: at least 3 routing-row trigger signals fire on at least one existing lalista spec (`/workspace/specs/*/spec.md`). Catches triggers that look reasonable but never match real specs.

**Rationale:** Stops routing-row drift on guide-section renames, prevents "we forgot to route this guide" silent regression, and validates that triggers aren't synthetic.

### D8: Lalista CLAUDE.md gotcha lift — out of scope (PR-B)

**Decision:** Lifting any lalista CLAUDE.md gotcha to a devshop guide is **out of scope** for this PR. Task 12 of this PR files a new `kit/ROADMAP.md` entry: "PR-B: lalista CLAUDE.md gotcha audit + lift into routing system." PR-B uses the routing system this PR ships.

**Rationale:** Keeps this PR under ~5h with a clean stopping point. PR-B becomes meaningful only after this PR's mechanism exists, so the dependency is unidirectional. Matches the original `kit/ROADMAP.md § Context-aware guideline routing` entry's "splittable into two PRs" recommendation.

### D9: Repository + branch

**Decision:** Work happens in `/devshop`, branch `feature/context-aware-guideline-routing`. Verified at Phase 0 entry: devshop was on `main`, clean tree, no existing branch or PR with this name.

**Rationale:** Per the user's original "on devshop" instruction. The work touches devshop guides, devshop skill SKILL.md files, devshop `kit/ROADMAP.md`, and devshop BATS tests — entirely devshop-scoped. No `/workspace` changes.

---

<!-- /ak-spec (Phase 1) expands the file from here: In scope, Screens (n/a — no
     UI), Data model changes (n/a), API contracts (n/a), Offline behavior (n/a),
     Metrics (likely no new events), Files to create/modify, Tests, Dependencies,
     Task order, Gotchas, Acceptance / rollout / rollback. The Decisions section
     above stays verbatim. -->

## In scope

This PR delivers the structural mechanism only; the lalista-side gotcha lift happens in PR-B (per D8).

- **Routing index promotion** — `kit/docs/guide/README.md` evolves from flat ToC to a routing table keyed by triggering signal (file-path globs + spec-keyword matches → `(file, anchor)` / skill / full-file target per D4). Alphabetical ToC is preserved below the routing index for orientation. Initial row count: ~10–15 from the ROADMAP entry's proposed set, expanded by audit findings.
- **Per-file ToCs** — every guide listed in the routing index gets a Layer 2 ToC at the top (per D2). Layer 3 sub-ToCs added only where audit flags long-section + H3-routable (no uniform-depth force).
- **`**See also:**` footers** — appended to guide sections that have natural transitive-discovery neighbors. Conservative initial pass — only the high-confidence pairs identified by the audit. Subsequent thickening passes can land later.
- **Audit deliverable** — Phase 2 Task 1 produces `specs/context-aware-guideline-routing/audit.md`. The audit file enumerates: (a) per-guide fires-on signals, (b) See-also targets, (c) relocation candidates, (d) `conventions.md` semantic-split candidate list. It is the artifact the Task 2 user gate reviews; relocations and splits land only on user approval.
- **Two skill patches** — `/ak-spec` gains Step 1.5 (D5: spec-time routing consultation that encodes matched gotchas as Decisions); `/ak-implement` swaps line 26 (D6: routing lookup over Files + Decisions; reads matched sections + See-also chains). Both patches must remain robust on projects that haven't yet adopted the routing convention — see Gotchas.
- **BATS coverage** — three invariants per D7 (link resolution, routing completeness, real-world grounding), new tests under `kit/tests/`.
- **`workflow.md` paragraph** — paired one-paragraph reference in `kit/docs/guide/workflow.md § Devshop Skill Map` (or adjacent), per the docs-coverage hook contract; pointer to SKILL.md as canonical source.
- **ROADMAP close-out + PR-B filing** — Task 12 strikes the shipped portion of `kit/ROADMAP.md § Context-aware guideline routing` per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`, and files a new entry: "PR-B: lalista CLAUDE.md gotcha audit + lift into routing system."

**Out of scope (explicit):**

- Lifting any lalista CLAUDE.md gotcha to a devshop guide (PR-B, per D8).
- Forced `conventions.md` splits — splits land only where the audit's proportionality test confirms ≥3 cohesive sections per candidate split (D3) AND the user approves at the Task 2 gate.
- Thick / exhaustive See-also chains across every section — initial pass is conservative (high-confidence pairs only). Thickening pass is a deferred ROADMAP item, not this PR.
- Generating the routing index from a script or front-matter scan — initial routing rows are authored by hand at audit time; deriving them programmatically is a follow-up worth its own design decision.
- Telemetry on routing-hit / routing-miss rates (see Metrics).

## Screens

n/a — docs + skills PR, no UI.

## Data model changes

n/a — no DB.

## API contracts

n/a — no runtime API surfaces touched. The internal "contract" is the markdown structure of the routing index + See-also footers (verified by BATS, see Tests).

## Offline behavior

n/a.

## Metrics

n/a — no new `METRICS.md` events. The routing system is a build-time / read-time mechanism inside the devshop tooling; no user-facing event surface. (Telemetry on routing-hit rates would be interesting evidence for future passes, but adds METRICS-tracking scope that doesn't pay off until PR-B's content lift has landed — defer.)

## Files to create / modify

### Modified

| Path                                                 | Expected edit shape                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `kit/docs/guide/README.md`                           | Promote to routing index. New top section "Routing for `/ak-spec` and `/ak-implement`" — table with Trigger / Guide-section / Notes columns. Existing alphabetical ToC preserved below the routing table for orientation. Add explicit "Out-of-routing" list for guides like `architecture.md` per D7.                                                                                                                              |
| `kit/docs/guide/conventions.md`                      | Add Layer 2 ToC at top. Apply relocations + splits per Task 2 approvals (see Created column below for any splits that produce new files). Add See-also footers to relocated / kept sections. **Likely** splits — finalized at audit time, not pre-decided here.                                                                                                                                                                     |
| `kit/docs/guide/hooks.md`                            | Layer 2 ToC. See-also footers per audit.                                                                                                                                                                                                                                                                                                                                                                                            |
| `kit/docs/guide/latency-feedback.md`                 | Layer 2 ToC. See-also footers (likely points at `ops.md § PWA` for iOS input-zoom + `conventions.md § Database queries` for PostgREST error-first inside Tier A2).                                                                                                                                                                                                                                                                  |
| `kit/docs/guide/local-supabase-compose-isolation.md` | Layer 2 ToC. See-also footers per audit.                                                                                                                                                                                                                                                                                                                                                                                            |
| `kit/docs/guide/notifications.md`                    | Layer 2 ToC. (Possibly no See-also targets — full-file routing per D4.)                                                                                                                                                                                                                                                                                                                                                             |
| `kit/docs/guide/ops.md`                              | Layer 2 ToC. Multi-row routing target (per-H2-section addressing). See-also footers (PWA ↔ latency-feedback; Custom domain ↔ PWA cross-origin redirect).                                                                                                                                                                                                                                                                            |
| `kit/docs/guide/security.md`                         | Layer 2 ToC. See-also footers (Auth boundaries → supabase-ssr-boilerplate § Edge fn auth).                                                                                                                                                                                                                                                                                                                                          |
| `kit/docs/guide/supabase-ssr-boilerplate.md`         | Layer 2 ToC. See-also footers (forms-touch-both pattern → testing.md + latency-feedback.md).                                                                                                                                                                                                                                                                                                                                        |
| `kit/docs/guide/testing.md`                          | Layer 2 ToC. See-also footers.                                                                                                                                                                                                                                                                                                                                                                                                      |
| `kit/docs/guide/workflow.md`                         | Layer 2 ToC. Plus the paired one-paragraph reference (D5+D6 routing surface) — placed under the section that documents the implementation phase (`§ Devshop Skill Map` or `§ Step 4: /ak-build § Phase 1` — exact insertion point chosen at write time).                                                                                                                                                                            |
| `kit/docs/guide/architecture.md`                     | **Out of routing** — but receives a Layer 2 ToC anyway for in-file navigability, plus an "Out of routing index — read on first project setup" banner at the top so the BATS routing-completeness check (D7) passes.                                                                                                                                                                                                                 |
| `kit/docs/guide/macos-host-setup.md`                 | **Out of routing** — banner + Layer 2 ToC same as architecture.md.                                                                                                                                                                                                                                                                                                                                                                  |
| `.claude/skills/ak-spec/SKILL.md`                    | Insert new "Step 1.5: Consult routing index" between Step 1 (METRICS.md check) and current Step 2 (source discovery). Bash block: parse tentative Files + Decisions → grep routing rows → read matched sections → encode triggered gotchas in the new spec's Decisions block. Bump `version` in frontmatter.                                                                                                                        |
| `.claude/skills/ak-implement/SKILL.md`               | Replace the `**Before starting**: read kit/docs/guide/conventions.md …` paragraph (lines 25–26) with routing-lookup prose: parse spec → look up routing matches against Files + Decisions → read matched `(file, anchor)` pairs → follow See-also where scope-relevant. **Fallback**: when routing lookup yields zero matches, fall back to reading `conventions.md` (preserves behavior on pre-adoption projects). Bump `version`. |
| `kit/ROADMAP.md`                                     | Strike shipped portion of `§ Context-aware guideline routing for /ak-spec and /ak-implement` per `/devshop/CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`. Add `**Status:**` line. File new entry "PR-B: lalista CLAUDE.md gotcha audit + lift into routing system" pointing back at this PR.                                                                                                                         |
| `PLAN.md`                                            | Phase 1 already flipped Row 3 → Active. Phase 5 removes the Active row after merge.                                                                                                                                                                                                                                                                                                                                                 |
| `BUILD-LOG.md`                                       | Phase 5 appends shipped entry.                                                                                                                                                                                                                                                                                                                                                                                                      |

### Created

| Path                                                                     | Expected shape                                                                                                                                                                                                                                                                                                                        |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `specs/context-aware-guideline-routing/audit.md`                         | Phase 2 Task 1 output. Four lists: (a) per-guide fires-on signals, (b) See-also pair candidates, (c) relocation candidates, (d) `conventions.md` semantic-split candidates with proportionality verdict per D3. The artifact Task 2 user gate reviews.                                                                                |
| `specs/context-aware-guideline-routing/tasks.md`                         | Written by Phase 2 (`/ak-implement`).                                                                                                                                                                                                                                                                                                 |
| `specs/context-aware-guideline-routing/review.md`                        | Written by Phase 3 (`/ak-pre-ship`).                                                                                                                                                                                                                                                                                                  |
| `kit/tests/routing-link-resolution.bats`                                 | BATS — D7 invariant 1 (every routing-row link resolves).                                                                                                                                                                                                                                                                              |
| `kit/tests/routing-completeness.bats`                                    | BATS — D7 invariant 2 (every guide is routed OR explicitly out-of-routing).                                                                                                                                                                                                                                                           |
| `kit/tests/routing-real-world-grounding.bats`                            | BATS — D7 invariant 3 (≥3 trigger signals fire on at least one lalista spec at `/workspace/specs/*/spec.md`). **Cross-boundary fixture**: reads `/workspace`; skipped with explicit reason when mount absent.                                                                                                                         |
| **0–3 new guide files** under `kit/docs/guide/` if conventions.md splits | Names + count finalized by Task 2 audit-approval gate. Candidate names: `migrations.md`, `database-queries.md`, `runtime-validation.md`. Each new file: extracted body verbatim from `conventions.md` + Layer 2 ToC + See-also footer + new routing-index entry + cross-ref rewrite in `conventions.md` left-behind one-line pointer. |

## Tests

Three BATS invariants per D7. All live under `kit/tests/`, follow the pattern of existing devshop BATS suites (`guard-*.bats`, `preship-*.bats`), and run in CI.

### Test 1 — `kit/tests/routing-link-resolution.bats`

**Setup:** parse `kit/docs/guide/README.md` and extract every `(file, anchor)` link in the routing index (anchors are `#`-suffixes on markdown links, e.g., `ops.md#pwa`).

**Assertion:** for each `(file, anchor)`, assert (1) `kit/docs/guide/<file>` exists, and (2) the anchor resolves to an actual H2/H3 in the target file (slugified-header match: GitHub's anchor algorithm — lowercase, spaces → `-`, drop punctuation). Skill-invocation rows (e.g., "consider `/cso`") assert that the named skill exists at `.claude/skills/<name>/SKILL.md`. Full-file rows just assert the file exists.

**Fixtures:** None beyond the live `kit/docs/guide/` tree and `.claude/skills/` tree. Test fails on guide-section renames that didn't update the routing index — the load-bearing drift catch.

### Test 2 — `kit/tests/routing-completeness.bats`

**Setup:** enumerate `kit/docs/guide/*.md` (excluding `README.md`). Parse the routing index for routed file names AND parse the "Out-of-routing" list for explicitly-tagged files.

**Assertion:** every guide file appears in **exactly one** of (routed, out-of-routing). Failure modes caught: (a) a new guide ships without being routed and without being explicitly excluded, (b) a guide is double-listed (routed + out-of-routing), (c) a removed guide is still referenced by the index.

**Fixtures:** None.

### Test 3 — `kit/tests/routing-real-world-grounding.bats`

**Setup:** discover `/workspace/specs/*/spec.md` (lalista's specs). The test file path crosses the `/workspace` boundary — this is a fixture-mount concern: `/workspace` is mounted in the devcontainer per `architecture.md`, but is not guaranteed in every CI environment.

**Assertion:** for ≥3 distinct routing-row trigger signals, find at least one lalista spec whose Files + Decisions sections contain a matching token (file-glob match OR keyword match). The 3-signal floor catches synthetic / over-specific triggers; a hand-authored row that no real spec ever triggers is a smell.

**Skip protocol:** if `/workspace` is not mounted (no `/workspace/specs/` directory), the test calls `skip` with the explicit reason `"/workspace not mounted — cross-boundary grounding check requires devcontainer fixture"`. **Critical**: skip, do not silently pass. The skip-with-reason is intentional — CI will run from the devcontainer where /workspace IS mounted; an environment that lacks it gets a loud skip message in the report, not a green tick.

**Fixtures:** the live lalista specs at `/workspace/specs/*/spec.md`. The test is read-only over that tree.

## Dependencies

None. This PR is foundational for PR-B (lalista CLAUDE.md gotcha lift) but is itself unblocked. No DB migration, no edge-function deploy, no auth-config change. Safe to merge any time.

## Task order

12 tasks, ordered by dependency. Task 2 is the user gate (audit approval); every other task is implementer-executable.

| #   | Task                                                                                                                                                                                                                                                                                                                                                              | Files touched                                                                                                                 | Paired tests                                                                                                             |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| 1   | **Audit pass over `kit/docs/guide/*.md`** — read every guide, build the four lists (fires-on signals per guide, See-also candidates, relocation candidates, `conventions.md` split candidates with proportionality verdict). Output: `specs/context-aware-guideline-routing/audit.md`.                                                                            | `specs/context-aware-guideline-routing/audit.md` (created)                                                                    | n/a — audit doc is review input, not test target                                                                         |
| 2   | **USER GATE — review relocations + splits** — present audit.md's relocation list and split list to user; collect approve/reject per item. STOP-and-wait gate. Records decisions in `audit.md` itself (Approved / Rejected column).                                                                                                                                | `specs/context-aware-guideline-routing/audit.md` (annotated with approvals)                                                   | n/a — gate, not code                                                                                                     |
| 3   | **Execute approved section relocations + splits** — apply Task 2 approvals: move sections across guides, split `conventions.md` into 0–3 new guide files (only those approved). Each move/split commit also rewrites cross-refs (devshop convention). Left-behind in `conventions.md` is a one-line pointer (the "substance lives in topic-specific guide" rule). | `kit/docs/guide/conventions.md`, 0–3 new `kit/docs/guide/<new>.md` files, cross-ref rewrites across other guides              | Test 1 (link resolution) — new anchors must resolve once landed. Run after each commit.                                  |
| 4   | **Add per-file ToCs to routed guides** — Layer 2 ToCs at the top of every guide (routed + out-of-routing both get them; out-of-routing also gets the "Out of routing index" banner). Layer 3 sub-ToCs added only where audit flagged useful (per D2).                                                                                                             | All 13 guides under `kit/docs/guide/` (touches each)                                                                          | Test 1 — anchors generated by ToCs must match the headers they point at.                                                 |
| 5   | **Promote `kit/docs/guide/README.md` to routing index** — author the routing table (Trigger / Section / Notes columns). Author the "Out-of-routing" list. Keep the alphabetical ToC below for orientation.                                                                                                                                                        | `kit/docs/guide/README.md`                                                                                                    | Tests 1 + 2 — link resolution + completeness both fire here.                                                             |
| 6   | **Add See-also footers** — append `**See also:**` footers to guide sections per the audit's approved pair list. Conservative initial pass (high-confidence pairs only).                                                                                                                                                                                           | Guides touched: `latency-feedback.md`, `ops.md`, `security.md`, `supabase-ssr-boilerplate.md`, `testing.md`, others per audit | Test 1 — See-also links resolve.                                                                                         |
| 7   | **Patch `/ak-spec` — add Step 1.5** — new step between Step 1 (METRICS) and current Step 2 (sources). Bash block: parse tentative Files + Decisions → grep routing rows → read matched sections → encode triggered gotchas in the new spec's Decisions section. Bump SKILL.md version.                                                                            | `.claude/skills/ak-spec/SKILL.md`                                                                                             | Self-review the prose (no BATS — agent-executable prose, per the pattern in `specs/ak-go-live-arm-a-preflight/spec.md`). |
| 8   | **Patch `/ak-implement` — Step 1 swap** — replace the hardcoded `Before starting: read conventions.md` paragraph (lines 25–26) with routing-lookup prose. **Fallback path**: routing-lookup zero matches → read `conventions.md` (preserves pre-adoption behavior). Bump SKILL.md version.                                                                        | `.claude/skills/ak-implement/SKILL.md`                                                                                        | Self-review the prose.                                                                                                   |
| 9   | **BATS — routing-row links resolve** — write `kit/tests/routing-link-resolution.bats` per Test 1 above.                                                                                                                                                                                                                                                           | `kit/tests/routing-link-resolution.bats` (created)                                                                            | This task IS the test.                                                                                                   |
| 10  | **BATS — every guide in routing OR out-of-routing** — write `kit/tests/routing-completeness.bats` per Test 2.                                                                                                                                                                                                                                                     | `kit/tests/routing-completeness.bats` (created)                                                                               | This task IS the test.                                                                                                   |
| 11  | **BATS — triggers fire on real lalista specs** — write `kit/tests/routing-real-world-grounding.bats` per Test 3. Implement the `/workspace` mount-detect + skip-with-reason guard.                                                                                                                                                                                | `kit/tests/routing-real-world-grounding.bats` (created)                                                                       | This task IS the test.                                                                                                   |
| 12  | **`workflow.md` paragraph + ROADMAP close-out + PR-B entry** — paired paragraph in `kit/docs/guide/workflow.md`; strike shipped portion of `kit/ROADMAP.md § Context-aware guideline routing` and add Status line; file new `kit/ROADMAP.md § PR-B` entry pointing back at this PR.                                                                               | `kit/docs/guide/workflow.md`, `kit/ROADMAP.md`                                                                                | n/a — prose-only.                                                                                                        |

Tasks 1 → 2 are sequential (audit informs the user gate). Tasks 3 → 5 are sequential within their group (splits land before the routing index that references new anchors). Tasks 4, 6, 7, 8 can land in parallel after Task 5. Tasks 9, 10, 11 land after the content they test exists. Task 12 lands last (records what shipped).

## Gotchas

- **Routing-row drift on guide-section rename.** Hand-authored routing rows decay the moment a guide section's H2/H3 is renamed without a paired routing-index update. **Mitigation**: BATS Test 1 (link-resolution) catches every drift case. Add a `kit/docs/guide/README.md` line in the routing-table preamble: "Section anchors are tested — BATS will fail on rename without index update."

- **Cross-boundary BATS test reading `/workspace/specs/*.md`.** Test 3 reads outside `/devshop`. Risk: in a CI environment that doesn't mount `/workspace`, the test silently passes (no specs found → loop body never runs → exit 0) or silently fails. **Mitigation**: explicit `skip` with reason when `/workspace/specs/` is absent, never silent. Document the cross-boundary in the BATS file header comment. Acceptable because /workspace is mounted in the devcontainer that runs the slow-job CI per `architecture.md`.

- **Recursive ToC ergonomics — Layer 3 drift.** A Layer 3 sub-ToC inside a long section drifts the moment the section's H3s are renamed (no anchor → invisible to BATS, since Test 1 only resolves links in README.md's routing index, not in-page ToCs). **Mitigation**: either (a) keep Layer 3 sub-ToCs script-generated (`scripts/regen-toc.sh` reading the file's H3s) and run on a pre-commit hook OR (b) commit to manual review of in-page ToCs on every H3-rename PR. Phase 2 picks one based on whether the audit flags ≥3 sections needing Layer 3 (proportionality: don't script-generate for a single Layer 3 case). Default for this PR if the audit finds 0–2 Layer 3 cases: manual review, document the convention in `kit/docs/guide/README.md`.

- **Patching `/ak-implement`'s "read conventions.md" line affects ALL consuming projects.** The devshop's SKILL.md files are read by every project that runs `/ak-implement`. If a project has not yet adopted the routing convention (no `kit/docs/guide/README.md` routing index — they have the older flat ToC), the new lookup logic would yield zero matches and read nothing. **Mitigation**: fallback path is mandatory. The patched Step 1 wording must read literally something like: "Look up routing matches; if zero matches, fall back to reading `kit/docs/guide/conventions.md` as before." Test 1 + 2 only run in devshop CI, not in consuming projects, so the fallback is the runtime safety net there.

- **`/ak-spec` Step 1.5 fires at spec-write time, but Files-to-touch is a prediction.** The Files section in a spec is the author's best guess; actual implementation often touches different files. **Mitigation**: Step 1.5's trigger heuristics must be forgiving — file-globs preferred over exact paths (`apps/web/app/(auth)/**` not `apps/web/app/(auth)/sign-in/page.tsx`), and keyword matches against the Decisions section catch concept-touched-via-different-path cases (e.g., a non-monorepo project's auth at `app/auth/**`). Document this in Step 1.5's prose so future skill authors don't accidentally tighten the heuristic.

- **`conventions.md` split risks breaking external links.** Lalista's CLAUDE.md and other project-level docs link to `conventions.md § X` anchors. A split moves those anchors to a new file → external links break. **Mitigation**: for every split section, leave a one-line pointer behind in `conventions.md` ("_X — see `<new-file>.md`._") so external links still resolve (they hit the pointer, follow the human-readable redirect). Same pattern as `§ Cross-skill awareness` already uses for `latency-feedback.md`.

- **Audit-doc proportionality drift.** `audit.md` enumerates fires-on signals for every guide; the routing index also enumerates the same signals (as triggers). Risk: audit.md and routing-index drift over time. **Mitigation**: audit.md is a Phase-2 artifact, NOT canonical post-merge. After this PR ships, `kit/docs/guide/README.md`'s routing index is the single source of truth. `audit.md` is preserved as historical record of the user-gate decisions but is explicitly tagged "Historical audit — see `kit/docs/guide/README.md` for current routing" at the top.

- **The audit reads 13 guides — context budget.** Phase 2 Task 1 is the audit pass. Reading all 13 guides + composing four lists could blow context if done in one pass. **Mitigation**: Task 1 may decompose into sub-tasks (one guide-batch at a time, each writing into audit.md incrementally). The `tasks.md` artifact records this if it happens. Acceptable because Task 2's user gate doesn't run until audit.md is complete — incremental composition is invisible to the gate.

## Acceptance / rollout / rollback

### Acceptance criteria (PR done when ALL are true)

1. `kit/docs/guide/README.md` contains a routing-index table with **≥10 rows** (the ROADMAP's proposed-initial-rows count is the floor; audit findings can expand).
2. `kit/docs/guide/README.md` contains an explicit "Out-of-routing" list with **≥2 entries** (`architecture.md`, `macos-host-setup.md` at minimum; `workflow.md` flagged per the audit).
3. Every guide listed in `kit/docs/guide/*.md` has a Layer 2 ToC at the top (verified visually + by Test 2's completeness check).
4. `.claude/skills/ak-spec/SKILL.md` contains a `## Step 1.5: Consult routing index` section between Step 1 and Step 2 (current).
5. `.claude/skills/ak-implement/SKILL.md` line 26's hardcoded `Before starting: read conventions.md` is replaced by routing-lookup prose with a documented fallback path.
6. All three BATS tests pass green (`bats kit/tests/routing-*.bats`).
7. `specs/context-aware-guideline-routing/audit.md` is committed (the user-gate audit trail).
8. `kit/ROADMAP.md § Context-aware guideline routing` has its shipped portion struck per `/devshop/CLAUDE.md § Closing TODO`; a new `§ PR-B: lalista CLAUDE.md gotcha audit + lift` entry exists pointing back at this PR's merge SHA.
9. `kit/docs/guide/workflow.md` references the new routing surface in one paragraph (paired-doc contract).
10. `PLAN.md § Active` row removed; `BUILD-LOG.md` entry appended (Phase 5 handles this).

### Rollout

Standard `/ak-go-live` flow. No special considerations:

- No DB migration → no migration-sequencing risk.
- No edge function → no out-of-band deploy step.
- No env vars / auth config → no Supabase dashboard touch needed.
- Vercel deploys the (n/a — no front-end) — this is a docs+skills PR, the front-end is untouched.

**One soft consideration**: after merge, future `/ak-spec` and `/ak-implement` invocations will use the new routing system. Existing in-flight feature branches that already have a spec.md written under the old `/ak-spec` will not re-run Step 1.5 — they'd need a re-run to pick up the routing system. Document this in the PR body's "After-merge note" so chapter authors know their already-in-progress specs are unaffected (this is desirable — don't re-write live specs mid-flight).

### Rollback

`git revert <merge SHA>` is safe. No DB, no runtime state, no external service config — the entire change is markdown + SKILL.md prose + BATS tests. Revert restores the previous flat-ToC README.md, the old `/ak-spec` and `/ak-implement` SKILL.md, the old `conventions.md` shape (including any split sections, which would re-merge). BATS tests revert with the rest.

If the routing system proves problematic in practice (e.g., agents systematically misuse the routing-row triggers), the rollback path is full-revert + re-design rather than incremental fix — the structural unit is the whole routing system.

**Adoption signal**: PR-B (lalista CLAUDE.md gotcha lift) is the load-test. If PR-B successfully lifts ≥3 lalista gotchas into routed guide sections that fire on appropriate spec triggers, the routing system is validated. If PR-B finds the routing too coarse / too fine to encode real gotchas, learnings feed back into a routing-v2 iteration.
