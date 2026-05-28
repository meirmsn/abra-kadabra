# Audit 2 — Docs review

Range: `8a4869afa882c4f8a9358e789e9473208e607492..b1cc8d775eba8e5185a36d7126c86cd990575c83`
Mode: devshop self-mode (`$GIT_ROOT = /devshop` worktree, branch `fix/propagation-block-enforcement`)
Re-audit after fixes for Audit 1's medium (doc coherence) + low (test gap).

## Findings

Clean — no docs findings.

## Verification notes (not findings)

Audit 1's single medium (doc coherence) is resolved. Verified all three docs
now enumerate dimension (d) as squash-surface-only and the lockstep line is
corrected:

- **`.claude/skills/devshop/merge-devshop/SKILL.md` §0.4.5 (L534-545)** — squash
  surface now reads "judges (a) + (b), skips (c) ..., AND adds (d) propagation-
  block presence — squash-surface-only". Lockstep line corrected: "The shared
  (a)/(b) rule wording lives in one place ... so those dimensions move in
  lockstep across both surfaces; (c) is PR-only and (d) is squash-only."
- **`CLAUDE.md` :115 (pre-push footgun bullet)** — devshop-side clause now reads
  "judges (a) accuracy + (b) readability + (d) propagation-block presence
  (squash-surface-only: FAILs when the squash diff touches `template/**` /
  `kit/scripts/**` / `kit/hooks/**` / `.devcontainer/**` / `manifest.txt` and the
  body carries no `**Existing projects:**` block ...) ... skips (c)".
- **`kit/docs/guide/conventions.md` § Existing-Project Migration Block §
  Enforcement (L562-570)** — rewritten from "not enforced per-commit" to the
  three-layer model (1: squash time / Phase 0.4.5 dimension (d); 2: release time
  / `propagation-entry.sh` WARN; 3: audit time / `/ak-docs-review` Section A),
  with the "catch absence, never decide need" caveat preserved.

The three docs are mutually coherent.

Empirical verification (Section B named-mechanism checks):

- Surface regex is byte-identical between `adversarial-review.sh:357` and
  `propagation-entry.sh:51`: `^(template/|kit/scripts/|kit/hooks/|\.devcontainer/)|(^|/)manifest\.txt$`.
  Matches the surface list enumerated in all three docs.
- Marker regex matches between the dimension-(d) precompute
  (`adversarial-review.sh:359` → `^\*\*Existing projects:\*\*`) and the
  extractor (`propagation-entry.sh:32` → `^\*\*Existing projects:\*\*`); the
  code comment at `adversarial-review.sh:355` ("Marker matches propagation-
  entry.sh's extractor exactly") is verified true.

Cross-reference anchors resolve in both directions:

- SKILL.md §0.4.5 → `conventions.md § Existing-Project Migration Block §
  Enforcement layer 1` (exists at conventions.md:516, layer 1 at L566). ✓
- CLAUDE.md:115 → same `§ Enforcement`. ✓
- conventions.md layer 1 → `/ak-merge-devshop Phase 0.4.5` (SKILL.md:522
  header) + Phase 0.5 approval gate. ✓

Section A (coverage): both touched scripts (`kit/scripts/adversarial-review.sh`,
`kit/scripts/propagation-entry.sh`) have matching doc edits; the HEAD commit
carries an `**Existing projects:** none — <why>` block, so the existing-project
migration-block coverage requirement is satisfied. No coverage finding.

Section D (bypass trailers): No Docs-Coverage-Bypass trailers in range.

Section E (CLAUDE.md hygiene): skipped — devshop mode.

`specs/propagation-block-enforcement/{review.md,gates/audit-1-*.md}` in the
range are Audit 1 audit-trail artifacts, not feature docs — excluded from
review per scope.
