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
