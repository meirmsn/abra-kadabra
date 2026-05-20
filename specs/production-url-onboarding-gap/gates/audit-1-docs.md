### [domain: docs] [section: C] [severity: medium]
**File**: kit/ROADMAP.md:655-656
**What**: The v1 entry "Test-coverage hook scope" still cites `template/.devcontainer/init-prod-url.sh` and `template/.devcontainer/refresh-allowed-ips.sh` as "zero bats coverage" examples motivating the hook-scope extension — but HEAD ships `kit/tests/template-production-url-firewall.bats` (21 assertions) covering exactly those two scripts.
**Why**: Stale tracker prose violates `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships` ("rewrite docs that described the prior constraint from conditional prose to imperative present tense; unwind every cross-reference in the same PR"). Future sessions reading the v1 entry will be told zero coverage exists on scripts that now have 21 assertions — and may re-derive a justification for the v1 work that no longer matches reality. The hook-scope point itself remains valid (template/.devcontainer/*.sh is still outside the Layer 1 hook's filter); only the worked examples need refreshing.
**Fix**: In the same PR, either (a) replace the two stale bullet examples with a different `template/.devcontainer/*.sh` that genuinely lacks coverage (e.g., `init-host-env.sh` if applicable) plus a forward-pointing note that the prod-URL pair was the codification trigger, or (b) collapse the two bullets into a single past-tense lesson ("`init-prod-url.sh` + `refresh-allowed-ips.sh` shipped 2026-05-09 with zero bats coverage; tests landed retroactively on <SHA> via `kit/tests/template-production-url-firewall.bats` — the hook-scope gap that allowed the initial miss is still open"). Option (b) preserves the historical trigger while imperative-present-tensing the current state.

### [domain: docs] [section: C] [severity: low]
**File**: kit/docs/guide/workflow.md:310
**What**: The `## Step 6 → Production health probe` bullet still describes the HTTP 000 path as a binary "firewall-IP-rotation — devcontainer connectivity issue, prod is probably fine" outcome. HEAD's `/ak-go-live § Step 1.5` now splits 000 into a tri-state Mode A/B/C classifier (paste-and-rebuild / rebuild-only / refresh-script).
**Why**: The workflow guide is a pipeline-overview-grain doc, not the operational ground truth — at its level the binary description remains directionally accurate (000 = in-container, not prod). But a teammate reading workflow.md as the canonical Step 6 summary will not learn that the SKILL.md now routes per Mode-A/B/C, and may search for stale references when they hit the new prompt. Coherence drift, not a correctness bug.
**Fix**: Append one half-sentence at the end of the bullet: "...; HTTP 000 splits further into Mode A/B/C per `/ak-go-live § Step 1.5` to disambiguate `.env`-unset vs rebuild-pending vs Vercel IP rotation." Low priority — workflow.md is descriptive overview, the canonical recipe lives in SKILL.md.

### Section D — Bypass trailer audit

No `Docs-Coverage-Bypass:` trailers in range.

### Section E — CLAUDE.md hygiene

Skipped in devshop self-mode (Section E is project-mode only per skill spec).

---

**Sections A and B**: Clean. The diff updates exactly the surfaces it needs to:

- `.claude/skills/devshop/go-live/SKILL.md` is the canonical home for the Step 1.5 tri-state diagnostic + the Mode A in-session escape hatch (Fix 2 + Fix 3 from the deleted ROADMAP entry) — landing operational logic in the skill where it fires, per `kit/docs/OVERVIEW.md § Key Conventions` ("Detail lives closest to where it's used").
- `.claude/skills/devshop/new-project/SKILL.md § Step 13` is the canonical home for the three-step paste-rebuild-verify operator block (Fix 1) — landing onboarding-time guidance at the step that produces the URL.
- `kit/ROADMAP.md` deletion of the 117-line `PRODUCTION_URL onboarding gap` section is the correct closing action per `CLAUDE.md § Closing TODO / ROADMAP entries when a fix ships`; the durable operational content survives in `kit/docs/guide/ops.md § Known Footguns § Firewall IP rotation` (two-file design, `fakeowner` rationale, `init-prod-url.sh` role) which was already comprehensive and required no edit.
- `PLAN.md` worked-example replacement (`production-url-onboarding-gap` → `db-hardening-template-lift`) is a clean unwinding of the row + the example that cited it.
- `kit/tests/template-production-url-firewall.bats` is a new test file with no surface→doc trigger (carve-out: `kit/tests/**`).

Cross-references verified: `/ak-new-project § Step 13` resolves; `/ak-go-live § Step 1.5` resolves; `/devshop/CLAUDE.md § Known Footguns § Firewall IP rotation` resolves (and the Mode C path correctly defers to it); the `template/.devcontainer/{refresh-allowed-ips,init-prod-url}.sh` paths cited in the new bats file exist at HEAD; ops.md's coverage of `init-prod-url.sh` + the two-file design is consistent with the new skill prose.

No coverage gap requiring `Docs-Coverage-Bypass:` — every load-bearing surface change has a paired doc edit.
