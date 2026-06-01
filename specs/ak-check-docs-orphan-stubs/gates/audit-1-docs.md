Clean — no docs findings.

<!-- Reviewer notes (not findings; recorded for audit trail):
- Section A (coverage): diff touches kit/scripts/preship/** (rubric → pre-ship/SKILL.md OR kit/docs/guide/*) and .claude/skills/**/SKILL.md (rubric → workflow.md OR CLAUDE.md). Both satisfied by kit/docs/guide/workflow.md (skill-map row + Phase 5.8 prose, both naming audit-tracker-only.sh). VERIFIED.
- Existing-project migration block: kit/scripts/preship/** is NOT in the trigger surface set (template/**, kit/hooks/**, .devcontainer/**, kit/manifest.txt, [locked]/[sync] files) — block not required. No finding.
- Section B (adequacy): workflow.md edits are substantive (new short-circuit clause + skill-map cell rewrite). Cited helper path kit/scripts/preship/audit-tracker-only.sh exists at HEAD. Tracker-set enumeration in the skill-map cell matches the helper's case-glob exactly (PLAN/TODOS/BUILD-LOG/PRODUCT-ROADMAP/DEPS-WATCH .md, kit/{TODOS,ROADMAP,notes,version}, kit/docs/CHANGELOG.md, kit/FRICTION-LOG.md; guide docs + tests excluded). VERIFIED.
- Section C (coherence): no renames/deletes in range. No stale refs to the removed kit/TODOS.md orphan-stub entry remain in kit/docs/ or CLAUDE.md. The closed TODO entry was deleted in the same branch that ships the fix (b0675f4), satisfying CLAUDE.md § Closing TODO entries. VERIFIED.
- friction-log entry's "Promotion target" proposes a future CLAUDE.md § Known Footguns note on the destructive DEVSHOP-override trap; FRICTION-LOG is intake (not a committed to-do), so the un-applied CLAUDE.md note is NOT a coverage gap. No finding.
- Section E (CLAUDE.md hygiene): devshop self-mode — Section E is project-mode-only; skipped.
-->

### Section D — Bypass trailer audit

- `bcfd847` Docs-Coverage-Bypass: "Bug-fix to existing helper … narrows the diff-failure direction, not the documented short-circuit semantics, so no doc text changes" — **VERIFIED**. The fix (exit 1 on unresolvable range) changes the diff-failure direction inside an already-documented helper; workflow.md already names audit-tracker-only.sh and the short-circuit semantics are unchanged. Per-doc NOT-AFFECTED claims confirmed by grep (audit-tracker-only present only in workflow.md; zero matches in pre-ship/SKILL.md, conventions/hooks/architecture/security/ops). Load-bearing and valid.
- `34c7d55` Docs-Coverage-Bypass: "File-mode correction only (755->644) … a mode-bit fix carries no behavior change requiring new docs" — **VERIFIED**. Mode-bit-only change; no behavior delta. Confirmed: `git ls-files -s` shows 100644 at HEAD. Valid.

No `CLAUDE-MD-Bypass:` trailers in range.
