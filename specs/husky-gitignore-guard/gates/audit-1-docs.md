### [domain: docs] [section: A] [severity: low]

**File**: template/.gitignore:84
**What**: The diff touches `template/**` (a `[sync]` file per `kit/manifest.txt:58`), which the devshop coverage rubric maps to `kit/docs/guide/{architecture,security,ops}.md` — none of which were staged. But this is a one-line `.gitignore` entry suppressing husky's auto-generated `_/` runtime dir; no guide doc enumerates `.gitignore` contents, and `architecture.md § File lifecycle` documents manifest _annotations_, not individual ignore lines. The change introduces no new mechanism, surface, or behavior with a guide-doc home.
**Why**: Literal `template/**`→guide trigger fires, but there is no genuine destination doc for "ignore husky's runtime dir." Recorded as informational, not a coverage gap — the self-explanatory 4-line comment block lives inline in the file itself, which is the correct home for this rationale.
**Fix**: No action required. If a future reader wants a pointer, `kit/docs/guide/architecture.md § File lifecycle` is the nearest home, but adding one would be over-documentation for a self-explanatory inline-commented gitignore line.

---

Notes (informational, not findings):

- **Existing-Project Migration Block (Section A): PRESENT and correct.** The commit touches a propagation-relevant surface (`template/**`), so a block is required. The body carries a well-formed Variant A ("no migration needed") block: correctly identifies `template/.gitignore` as `[sync]` in `kit/manifest.txt`, explains `from-devshop.sh` delivers the new line on next sync, and notes home-os already added the line project-locally during its v1.36.0 sync. No finding.

- **Adequacy (Section B): all commit-body claims verified.**
  - `template/.gitignore` is `[sync]` — confirmed `kit/manifest.txt:58` (`.gitignore [sync]`).
  - `prepare: husky` + husky v9 — confirmed `template/package.json:18` (`"prepare": "husky"`) and `:25` (`"husky": "^9.0.0"`).
  - `.husky/_/` line landed at HEAD — confirmed `template/.gitignore:91`.
  - Husky-v9 self-ignore-via-nested-`.husky/_/.gitignore` claim and half-initialized-state rationale are accurate to husky v9 behavior.

- **Coherence (Section C): clean.** No renamed/deleted files in range. No reference docs touched, so no contradictions introduced. Existing husky references across `kit/docs/**` all concern the committed hooks (`.husky/pre-commit` / `pre-push` / `prepare-commit-msg`); none reference the `_/` runtime dir, so the new ignore contradicts nothing.

- **Section D (bypass trailers): No Docs-Coverage-Bypass trailers in range.**

- **Section E (CLAUDE.md hygiene): skipped — devshop mode.**
