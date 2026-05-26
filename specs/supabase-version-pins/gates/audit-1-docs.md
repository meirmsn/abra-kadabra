# Docs Review — Audit 1

**Range**: `origin/main..HEAD` (1 commit: `19c4cc4`)
**Mode**: devshop

## Findings

### [domain: docs] [section: A] [severity: medium]
**File**: (commit body of `19c4cc4`)
**What**: Missing `**Existing projects:**` migration block in commit body
**Why**: The commit touches propagation-relevant surfaces (`template/.devcontainer/Dockerfile`, `template/.devcontainer/compose.yml`, `template/.devcontainer/supabase-runner/Dockerfile`, `template/.devcontainer/checksums.sha256`, `.devcontainer/Dockerfile`, `.devcontainer/checksums.sha256`, `.devcontainer/devcontainer.json`) — all `[locked]` in `kit/manifest.txt`. Per `kit/docs/guide/conventions.md § Existing-Project Migration Block`, the block is required even when the auto-sync mechanism handles propagation (the "no migration needed" variant tells the reader the author considered the question). A rebuild is needed for the new Dockerfile checksum mechanism + version bump to take effect.
**Fix**: Amend the commit body (or add in the squash message at merge time) with: `**Existing projects:** Dockerfile, compose.yml, checksums.sha256, supabase-runner/Dockerfile, and devcontainer.json are [locked] in kit/manifest.txt; init-devshop.sh refreshes them on rebuild. Rebuild the devcontainer to pick up the new Supabase CLI version (2.98.2) and self-verifying checksum mechanism. No other project-side migration needed.`

## Section B — Adequacy

No findings. Both `kit/docs/guide/ops.md` and `kit/docs/guide/security.md` updates are substantive: ops.md documents the version-pin mechanism with compose.yml interpolation shape + override path; security.md documents the per-tool checksum model split (hardcoded vs self-verifying) and the trust-model equivalence claim. Template README and devshop README trim is appropriate — replaced verbose explainer content with concise non-obvious-details format.

## Section C — Cross-doc coherence

No findings. The old security.md claim ("Update version + checksum in same commit") has been correctly narrowed to git-delta/dcg/gitleaks. No stale cross-references to the old blanket checksum convention found in CLAUDE.md or other guide docs. No renamed or deleted files in the diff.

## Section D — Bypass trailer audit

No `Docs-Coverage-Bypass:` trailers in range.

## Section E — CLAUDE.md hygiene

Skipped (devshop mode).

## Summary

high=0 medium=1 low=0
