# W7 — gstack upgrade

From vendored 0.15.1.0 to a pinned ≥ 1.91.13 (D-07). Do it in one branch with the
adaptations, smoke-tested through pre-ship → ship on the fixture (V4).
Findings: F-GS-01..08, F-SEC-18 (unpinned clone).
Status markers: `[ ]` `[~]` `[x]` `[!]` `[-]`.

## W7.1 Pinned upgrade — P1 · M3 · M

- [ ] **W7.1.1** Upgrade in a worktree off `origin/main`; `./setup` non-interactive with Playwright step skipped (devshop provides browsers); refuse/neutralise setup's `~/.claude/settings.json` hook edits (F-GS-08) — V4
- [ ] **W7.1.2** Pin `/ak-new-project` (or the W4.2 installer) to the same version/SHA (F-SEC-18) — V3
- [ ] **W7.1.3** Re-verify `/autoplan` in a session with a SessionStart hook (F-GS-04) — V4
- [ ] **W7.1.4** Update `kit/ROADMAP.md` gstack entry (stale 1.55 target) — V1

## W7.2 router-shim for `/cso` v3 — P1 · M3 · S

- [ ] **W7.2.1** Rewrite `cso-to-dismissals` against v3 findings (confidence/evidence state, new storage path); fixture JSON tests (F-GS-02) — V2

## W7.3 `/ship` interplay — P1 · M3 · S

- [ ] **W7.3.1** Choose: accept `v$NEW_VERSION ` title prefix in Phase 4.3 verification, or have `/ak-build` create the PR itself and use `/ship` for test/bump/push only; keep `/ship` redaction scan (F-GS-03) — V4

## W7.4 Remove obsolete workarounds — P2 · M3 · S

- [ ] **W7.4.1** Drop `GSTACK_STATE_DIR` split-brain handling (single `GSTACK_STATE_ROOT`/`GSTACK_HOME`), drop `~/.gstack/projects` symlink after one release; update ops.md (F-GS-05) — V4
- [ ] **W7.4.2** Re-test Chromium autodetect; remove `chromium-1208` symlink step if obsolete — V4

## W7.5 Link missing skills; fix design path — P1 · M3 · S

- [ ] **W7.5.1** Link `design-shotgun`, `design-html`, `context-save`, `context-restore`, `health`, `learn` (or whatever the install model exposes); `/ak-spec` reads `designs/*/finalized.html` (F-GS-06) — V2 wiring test

## W7.6 Decide overlaps — P2 · M3 · S

- [ ] **W7.6.1** For each pair decide adopt / keep / wrap and record: `/ak-handoff`↔`/context-save`, `/ak-status`↔welcome-back, `/ak-spec`↔`/spec`, tests audit↔`/test-audit`, docs audit↔`/ship` docs audit, design-conformance↔DESIGN.md format + 61 checks (F-GS-07) — V1 decision record
