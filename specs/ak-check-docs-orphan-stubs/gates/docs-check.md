## Gate 1: docs-check

- Result: pass

Deterministic docs-coverage check (devshop self-mode). Verified that every source
surface in the diff (`origin/main...HEAD`) is paired with a substantive,
accurate doc update.

### Source surfaces touched

- `kit/scripts/preship/audit-tracker-only.sh` (new) — tracker-only range
  classifier helper.
- `.claude/skills/devshop/check-docs-and-tests/SKILL.md` (modified) — Step 1
  wires a tracker-only short-circuit before the substep-6 review.md scaffold.

### Doc pairing — `kit/docs/guide/workflow.md`

Both surfaces are documented by the workflow.md note added in this branch. Two
distinct, substantive additions (not a stub):

1. **Phase 5.8 prose** — the existing 5.8 paragraph now states: "Step 1 first
   runs `kit/scripts/preship/audit-tracker-only.sh "$RANGE"` and short-circuits
   (exit 0, no scaffold, no sub-skill dispatch) when the range is tracker-only
   — so a doc-only / tracker-only delta does not manufacture an orphan
   `review.md` stub." Accurately names the helper, the exit-0 contract, the
   "no scaffold / no sub-skill dispatch" behavior, and the orphan-stub
   motivation.
2. **Devshop Skill Map table row** (`/ak-check-docs-and-tests`) — adds a
   **Tracker-only short-circuit** clause naming the helper path, enumerating
   the tracker set (PLAN/TODOS/BUILD-LOG/PRODUCT-ROADMAP/DEPS-WATCH `.md`,
   `kit/{TODOS,ROADMAP,notes,version}`, `kit/docs/CHANGELOG.md`,
   `kit/FRICTION-LOG.md`), and explicitly noting guide docs + tests are
   deliberately excluded ("those ARE auditable") — which matches the helper's
   `case` arms and its header comment exactly. Describes the exit-0 print +
   no-scaffold/no-dispatch/no-append behavior and the orphan-stub fix.

### Accuracy cross-check (doc vs. code)

- Tracker set in the doc matches the `case` patterns in
  `audit-tracker-only.sh` (lines 57-66) verbatim.
- "guide docs + tests deliberately excluded" matches the helper's
  "Deliberately NOT trackers" comment (lines 25-27).
- Exit-code semantics (0 short-circuit / 1 audit / 64 usage) in the helper
  header align with the doc's stated 0-short-circuit / fall-through-to-audit
  behavior.
- The SKILL.md Step 1 edit (substep 5 short-circuit precedes substep 6
  scaffold) is the behavior the workflow note describes.

The helper is `kit/scripts/preship/**` — a script-internal classifier whose
operator-facing contract is the workflow.md note + the SKILL.md Step 1 prose;
no additional standalone doc surface is required.

## Dismissals

None
