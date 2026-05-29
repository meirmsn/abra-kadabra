### [domain: docs] [section: B] [severity: low]

**File**: kit/FRICTION-LOG.md:186
**What**: The `git ls-remote` friction entry cites edit target `.claude/skills/devshop/clean-branches/SKILL.md`, which does not exist. The `/ak-clean-branches` skill is defined at `.claude/commands/ak-clean-branches.md`.
**Why**: Named-path verification (Section B) — a cited "Edit target" path that does not resolve at HEAD. Carried over verbatim from the pre-existing `kit/TODOS.md` entry this range migrated (the wrong path was present once at base `8aa012c`, not newly authored). FRICTION-LOG is an observation ledger and this pointer is advisory, not a load-bearing operator instruction — hence low, not medium. Worth fixing so the future promotion lands the edit in the right place.
**Fix**: Change `.claude/skills/devshop/clean-branches/SKILL.md` → `.claude/commands/ak-clean-branches.md` (Phase 1 remote enumeration).

### [domain: docs] [section: B] [severity: low]

**File**: kit/FRICTION-LOG.md:147
**What**: The visual-evidence-deferral friction entry cites edit target `kit/docs/guide/adversarial-review.md`, which does not exist. Adversarial review is documented in `kit/docs/guide/hooks.md § Adversarial review`.
**Why**: Named-path verification (Section B) — a cited "Edit target" path that does not resolve at HEAD. Carried over verbatim from the pre-existing `kit/TODOS.md` entry this range migrated (the wrong path was present once at base `8aa012c`, not newly authored). Advisory pointer in the observation ledger, not load-bearing — hence low. (Secondary nit in the same entry: "Gate 4/Gate 13" reflects the historical home-os-PR-#19 gate numbering; current `pre-ship/SKILL.md § Gate 4` is `/simplify`. This is acceptable as a description of the PR-#19-era state and is not flagged separately.)
**Fix**: Change `kit/docs/guide/adversarial-review.md` → `kit/docs/guide/hooks.md § Adversarial review` (add screenshot/E2E deferrals to the extra-scrutiny list).

---

**Verified clean (no findings):**

- **Section A — Coverage**: range touches only carve-out/non-source surfaces (`kit/TODOS.md`, `kit/FRICTION-LOG.md`, `PLAN.md`, `BUILD-LOG.md`, `.gitignore`, and this feature's own `specs/` artifacts). No `kit/scripts/**`, `kit/hooks/**`, `template/**`, `.devcontainer/**`, `.claude/skills/**/SKILL.md`, or `kit/manifest.txt` touched, so no surface→doc coverage trigger fires. Existing-Project Migration Block requirement does not apply (no propagation-relevant surface in range). No `Docs-Coverage-Bypass:` trailers in range.
- **Section C — Coherence**: no reference doc (`CLAUDE.md`, `kit/docs/guide/*.md`, `kit/docs/OVERVIEW.md`, `kit/docs/FAQ.md`) was touched, so no cross-doc contradiction introduced. No renamed/deleted files in range. Deleted `kit/TODOS.md` entries leave no stale cross-references: the `sandbox-qa-close-gap` cross-ref was removed with its parent entry; the `3633daa` template-strip cross-ref was preserved correctly. Reference docs carry no stale anchors into the moved entries (grep for `PR #27`/`PR #28`/`host-resource` across guide docs: none). `prTextHygieneReason` references across the repo point at the check-type/engine, not the moved TODOS entry — correctly left untouched (noted in spec.md:309). `FRICTION-LOG` location references in reference docs intact.
- **Section D — Bypass trailers**: No `Docs-Coverage-Bypass:` trailers in range. No `CLAUDE-MD-Bypass:` trailers in range.
- **Section E — CLAUDE.md hygiene**: skipped (project mode only; this is devshop self-mode, `$GIT_ROOT == /devshop`). For the record, CLAUDE.md is byte-identical at base `8aa012c` and HEAD `cdee790` (30261 bytes) — untouched by this range.

**Cross-checks confirmed:**

- `kit/ROADMAP.md` NOT touched (verified via `git diff --name-only`).
- PLAN.md virtiofs row Source pointer (`kit/TODOS.md § /ak-merge-devshop Phase 2 / Phase 1.0 — mechanize the virtiofs phantom-rebase fallback`) resolves to `kit/TODOS.md:53`.
- All other paths cited in the new FRICTION-LOG entries resolve at HEAD: `kit/notes/projects/home-os.md`, `kit/scripts/commit-hooks/check-claude-md-classification.sh`, `.claude/skills/devshop/merge-devshop/SKILL.md`, `kit/docs/guide/claude-md.md § Enforcement` (line 92), `kit/notes/roadmap/subagent-cleanup-pattern.md`, `kit/ROADMAP.md § PR-description staleness check` (line 857), `.claude/skills/devshop/pre-ship/SKILL.md`, `.claude/skills/devshop/build/SKILL.md` (Phase 5.9 / Phase 6).
- `.gitignore` addition (`.claude/scheduled_tasks.lock`) is correctly commented and scoped.
