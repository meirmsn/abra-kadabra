Clean — no docs findings.

<!--
Audit notes (devshop self-mode, range origin/main..HEAD):
- Diff is tracker-only: .gitignore, PLAN.md, kit/FRICTION-LOG.md, kit/TODOS.md +
  this feature's own specs/ artifacts (spec.md, tasks.md). No source, scripts,
  hooks, SKILL.md, template, or .devcontainer surfaces touched.
- Section A (coverage): kit/TODOS.md + kit/FRICTION-LOG.md are explicit devshop
  carve-outs (no surface→doc trigger fires). PLAN.md + .gitignore carry no
  surface→doc trigger. No propagation surfaces touched, so the Existing-Project
  Migration Block requirement is n/a. No coverage finding.
- Section B (adequacy): all cited paths in new FRICTION-LOG entries + the PLAN.md
  virtiofs-rebase-auto-switch Source pointer verified to exist at HEAD
  (check-claude-md-classification.sh, merge-devshop/SKILL.md, claude-md.md,
  home-os.md, path-classifier.sh, workflow.md, subagent-cleanup-pattern.md,
  ROADMAP.md). The PLAN.md Source pointer resolves to a live
  kit/TODOS.md § /ak-merge-devshop Phase 2 / Phase 1.0 section.
- Section C (coherence): no renamed/deleted files in range; kit/ROADMAP.md
  untouched (0 changes); FRICTION-LOG schema + ## Open/## Resolved structure
  intact (8 entries). No stale/dangling cross-references introduced.
- Section D (bypass trailers): no Docs-Coverage-Bypass: trailers in range.
- Section E (CLAUDE.md hygiene): project-mode only — skipped in devshop
  self-mode. CLAUDE.md not touched in range regardless.
-->
