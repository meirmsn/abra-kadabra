# Docs Review — Audit 2

**Range**: `a917e9d..HEAD` (2 commits: `3fa5636`, `7eac1c7`)
**Feature**: `kit-scripts-deny-rule-investigation`
**Date**: 2026-05-23

## Section A — Coverage

No coverage findings. The only non-spec file touched is `.claude/settings.json` (removed 2 relative deny lines). This change aligns the committed file to the state already described in `kit/docs/guide/security.md` — the docs described the target (absolute-only patterns); the fix brings the file into conformance. No doc update required.

## Section B — Adequacy

No reference docs were touched in this range. Nothing to assess.

## Section C — Cross-doc coherence

Verified all cross-doc claims against HEAD state:

- `kit/docs/guide/security.md:52-53` code block shows only `Edit(/devshop/kit/scripts/**)` + `Write(/devshop/kit/scripts/**)` — matches `.claude/settings.json` lines 79-80. Coherent.
- `kit/docs/guide/security.md:58` claims "deny patterns use absolute paths" and "Removing the relative patterns and keeping only absolute ones makes enforcement deterministic" — matches HEAD. Coherent.
- `kit/docs/guide/security.md:58` cross-references `specs/kit-scripts-deny-rule-investigation/spec.md` — file exists and is tracked. Coherent.
- `kit/docs/guide/security.md:104` claims "two absolute-path deny patterns" — matches HEAD. Coherent.
- `CLAUDE.md:119` claims `/devshop/kit/scripts/**` deny with "(canonical tree only — worktree copies are intentionally editable)" — matches HEAD (no relative patterns remain). Coherent.
- `kit/docs/guide/security.md:222` Authoring locked files section lists `/devshop/kit/scripts/**` with "(canonical tree only — worktree copies are editable)" — matches HEAD. Coherent.

No renamed or deleted files in range. No stale-reference sweep needed.

## Section D — Bypass trailer audit

No Docs-Coverage-Bypass trailers in range.

## Section E — CLAUDE.md hygiene

Skipped — devshop mode (Section E is project-mode only).

## Summary

Clean — no docs findings.

The two high-severity findings from Audit 1 (settings.json relative deny patterns contradicting docs) are resolved: commit `7eac1c7` removed the relative patterns, and all doc claims now match the actual `.claude/settings.json` at HEAD.
