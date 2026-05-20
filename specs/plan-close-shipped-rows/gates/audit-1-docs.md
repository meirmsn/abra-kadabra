### [domain: docs] [section: B] [severity: low]

**File**: PLAN.md:72
**What**: `home-os-skill-polish-batch` Hook column now ~166 chars, exceeding the documented ≤120-char cap (PLAN.md L17).
**Why**: The consolidation that folded the bottom-section absorbed-bundle note into the Hook column ("19 fixes across sub-bundles A (5) + B (2) + E (11); A1 + E4 are security (token leak + .env hygiene); D deferred to 3rd-project trigger (do not re-split)") pushed past the table-author convention this very file documents. Consistency nit — the column still renders fine, but the rule no longer self-applies.
**Fix**: Either tighten the Hook to ≤120 chars (e.g., drop the parenthetical security gloss + the "do not re-split" — both are recoverable from ROADMAP), OR relax the cap in the L17 convention to accept "≤120 chars (or ≤200 when consolidating absorbed-bundle metadata)". No-action is also acceptable; flagged as low because the cap is author-discretion guidance, not a hard rule.

---

**Section D — Bypass trailer audit**: No Docs-Coverage-Bypass trailers in range.

**Section E — CLAUDE.md hygiene**: Skipped (devshop self-mode; Section E is project-mode only per skill spec).

**Summary**: `high=0 medium=0 low=1`
