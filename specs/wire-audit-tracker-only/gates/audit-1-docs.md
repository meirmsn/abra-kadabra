Clean — no docs findings.

---

Audit context (informational, not a finding):

- Range: bf1cb7acfba628b16c12bc62893e2c66dce660a8..4f336fa (single commit 4f336fa).
- Mode: devshop self-mode ($GIT_ROOT == /devshop). Section E (CLAUDE.md hygiene) is project-mode only — skipped.
- Diff: one line in kit/tests/structural-invariants.bats — adds basename `audit-tracker-only.sh` to the `infra_scripts` allow-list.
- Section A (Coverage): the sole touched file is under `kit/tests/**`, an explicit carve-out — no doc-coverage firing. No script/template/hook/skill/manifest surface touched, so no doc edit required and the Existing-Project Migration Block requirement does not trigger.
- Section B (Adequacy): no reference docs touched; nothing to judge.
- Section C (Coherence): no renames/deletions; no reference docs touched; nothing to contradict.
- Section D (Bypass trailers): No Docs-Coverage-Bypass trailers in range.
- CLAUDE.md size stable (+0 bytes this audit window; 24801 → 24801).

Empirical verification of the commit's claims (all confirmed):

- Script exists at `kit/scripts/preship/audit-tracker-only.sh` (the allow-list test resolves basenames recursively under kit/scripts/, so the preship/ subfolder is covered).
- Invoked by a skill, not a hook: `.claude/skills/ak-check-docs-and-tests/SKILL.md:109` calls `bash kit/scripts/preship/audit-tracker-only.sh "$RANGE"`; no reference in settings.json, kit/hooks/, or .husky/ — legitimately not hook-wired, matching the allow-list's intent.
- Cited siblings `check-llm-mediated-na.sh` and `roster-check.sh` also live in kit/scripts/preship/ — accurate.
- Has test coverage: kit/tests/util-audit-tracker-only.bats.
