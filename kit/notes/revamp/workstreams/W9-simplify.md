# W9 — Simplify & delete

Remove what the new foundation made unnecessary — only after the replacement is
verified and every project has migrated (D-09, D-11). Each deletion: confirm in
D-11, delete, run the full suite + fixture dogfood (V4).
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W9.1 Retire superseded v1 machinery — P2 · M5 · M

- [ ] **W9.1.1** Symlink injection + `[sync]` rsync model + `.devshop-version`-as-record (replaced by W4.2) — after last project migrated
- [ ] **W9.1.2** `/ak-merge-devshop` push-to-main path (replaced by W4.6)
- [ ] **W9.1.3** `/ak-handoff` if `/context-save` adopted (W7.6)
- [ ] **W9.1.4** Root-owned copies / sticky-bit model if retired by D-02/W4.4

## W9.2 Remove CLAUDE.md-placement machinery — P2 · M5 · S

Finding: F-DOC-05.

- [ ] **W9.2.1** Replace 253-line guide + Sonnet classification gate + classification notes with a 10-line rule in CLAUDE.md and a size check — V2

## W9.3 Slim process artifacts — P2 · M5 · S

Finding: F-DOC-06.

- [ ] **W9.3.1** Gate results: one machine-readable file per run (from W6.4.2), no per-gate n/a markdown files; `review.md` = human summary only — V2
- [ ] **W9.3.2** Decide retention for historical `specs/*/gates/` (archive branch or keep) — V1

## W9.4 Evaluate first-party replacements — P2 · M5 · S

Findings: F-SEC-19. Opportunities: O-02, O-05.

- [ ] **W9.4.1** Bash sandbox (bubblewrap) locally/cloud: does it replace parts of dcg/deny rules? measured trial — V4
- [ ] **W9.4.2** `prompt`/`agent` hook types vs remaining reviewer check-types — V4

## W9.5 Size targets met — P2 · M5 · S

- [ ] **W9.5.1** Re-run W0.2 baseline; compare to targets; record in LOG — V1
