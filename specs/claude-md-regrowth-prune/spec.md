<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: claude-md-regrowth-prune -->
<!-- date: 2026-05-29 -->

# Spec: claude-md-regrowth-prune (devshop)

**Sources:**

- `kit/ROADMAP.md § CLAUDE.md hygiene` — original scope (deliverables A + B). **Already shipped 2026-05-27** (squash `f875263`); this PR completes the under-delivered prune + closes the stale trackers.
- `specs/claude-md-hygiene/` — the SHIPPED 2026-05-27 build (do NOT touch; historical record). Its Task 3 "Audit sweep" promised to "relocate ~9k of regrowth" but only deleted/condensed 4 entries (~2.1k). The remaining regrowth-prune is this PR.
- `PLAN.md` row `claude-md-hygiene` (Planned v0, Lev 3.6) — stale; closed by this PR.
- `kit/docs/guide/claude-md.md` — the shipped inclusion rule + 3-class taxonomy + routing table this audit APPLIES (not re-created here).
- `kit/scripts/commit-hooks/check-claude-md-classification.sh` — Layer B prevention gate (landed 2026-05-27).

**Provenance / staleness finding (Phase 0.6):** the `claude-md-hygiene` ROADMAP
entry (surfaced 2026-05-27) describes work that already shipped: deliverable B
(convention + 3-layer enforcement) via commits `5d09515` / `f875263` / `1d343bf`;
deliverable A's architecture migration trimmed devshop CLAUDE.md 39.5k→22.3k on
2026-05-18. The file then **regrew 22.3k → 30.0k (~36%)** over 2026-05-18→05-26
as new features added orientation to existing sections. The 2026-05-27 build's
audit-sweep task was supposed to relocate that regrowth but under-delivered
(~2.1k of a claimed ~9k). The operator chose ("Fresh prune-audit first") to
(1) complete the regrowth prune against the now-shipped taxonomy and (2) close
the stale trackers.

This PR is a conservative prune of the **devshop** CLAUDE.md + reciprocal guide
repoints + tracker closure. It does NOT touch any project CLAUDE.md (different
repos, unreachable from `/devshop`), nor the shipped `specs/claude-md-hygiene/`
artifacts.

---

## Product update

Infra/docs-only devshop change — no end-user surface. Collapsed shape.

### Headline + Detail (combined)

Infrastructure update — no user-visible change in this PR. Completes the
devshop `CLAUDE.md` regrowth prune the 2026-05-27 hygiene build under-delivered:
relocates devshop-internal reference content now duplicated in guide docs
(Session Start hook internals, two-repos shipping procedure, locked-file
mechanics, a now-loud-caught footgun) to its canonical home, repoints the
reciprocal cross-references so no canonical-home pointer dangles, and closes
the stale `claude-md-hygiene` tracker entries whose work already shipped.

---

## Decisions (resolved at spec time)

Resolved in Phase 0 with the operator. Phase 1 preserves these verbatim.

### D1: Prune methodology

**Decision:** Apply the shipped Layer C rubric from `claude-md.md` (VERIFIED /
CHALLENGE / RELOCATE). Move only RELOCATE-grade + operator-confirmed CHALLENGE
entries.

**Rationale:** Dogfoods the convention this feature shipped; no parallel methodology.

### D2: Hook-bridging guard (load-bearing)

**Decision:** A convention that reaches *project* sessions via the SessionStart
force-inject STAYS in devshop CLAUDE.md even when a guide duplicates it —
`kit/docs/guide/*.md` is NOT auto-loaded in project sessions. So Confidence
Calibration, TODO Protocol, Commit+PR style, Closing-TODO convention all STAY.

**Rationale:** Over-pruning silently removes guidance from every project session.
`claude-md.md` blesses devshop CLAUDE.md carrying "L1 conventions that bridge via
the hook."

### D3: Non-Negotiables loud-failure list

**Decision:** Keep.

**Rationale:** `claude-md.md` explicitly sanctions a Non-Negotiables section
listing loud cases "for posture."

### D4: "Never commit directly to main" footgun (now loud-caught)

**Decision:** Trim to a one-line pointer; preserve only the non-loud residual
("don't propose a GitHub PR on devshop").

**Rationale:** `check-branch-not-main.sh` (PreToolUse) + the husky branch guard
make the bulk loud-self-teaching; the PR-on-devshop nuance is the residual silent trap.

### D5: `### Session Start` section

**Decision:** Trim the hook-internals detail (PROPAGATION.md generation,
`.devshop-version` comparison, `from-devshop.sh`) to a short pointer, and
**repoint `kit/docs/guide/architecture.md:192`** which currently cites
`/devshop/CLAUDE.md § Session Start` as the mechanism home → point to
`hooks.md`/`architecture.md` instead. Verify the mechanism detail survives in
those guides before deleting from CLAUDE.md.

**Rationale:** Reciprocal edit required — can't trim without relocating the
canonical-home pointer, or the pointer dangles.

### D6: home-os project CLAUDE.md prune

**Decision:** Out of scope — different repo, unreachable from `/devshop`. Leave
for a home-os `/ak-build` guided by the `claude-md.md` recipe.

**Rationale:** Can't edit home-os from here.

### D7: Tracker closure

**Decision:** Delete the `claude-md-hygiene` PLAN row + `kit/ROADMAP.md §
CLAUDE.md hygiene` section + unwind every cross-reference, per `CLAUDE.md §
Closing TODO/ROADMAP when a fix ships`. Rewrite any conditional prose the entry
spawned to present tense.

**Rationale:** Both deliverables shipped; the trackers are stale and would be
re-cited as "still pending" in future sessions.

### D8: Layer-B prevention-gate trailer gap

**Decision:** Verify lightly whether the classification gate fired on the two
post-gate CLAUDE.md commits (`412f20b`, `8cdda99`) that carry no
`Claude-MD-Classification:` trailer. If it's a real hole, **file to
`kit/TODOS.md`** — do NOT expand this PR into a Layer-B rewrite.

**Rationale:** The "do we have machinery" question surfaced a possible gate/
trailer-recording gap, but debugging Layer B is a separate, potentially large
investigation. Keep this PR scoped to the prune + closure.

---

<!-- /ak-spec (Phase 1) expanded the file from here. The Product update +
     Decisions sections above are verbatim from the Phase 0 skeleton.
     This is devshop-self-mode: no METRICS.md, test surface is bats. -->

## Core user story

N/A — devshop docs-only prune. No user-facing flow added or modified. The
"observable change" is a smaller always-loaded `CLAUDE.md` and no dangling
cross-references; both are verified by inspection + grep, not a qa-walk.

## Render conditions

N/A — no UI. Pure markdown edits to devshop docs + trackers.

## In scope

Apply the shipped Layer C rubric from `kit/docs/guide/claude-md.md` (VERIFIED /
CHALLENGE / RELOCATE) to the **devshop** `CLAUDE.md` only. The current file is
30,008 chars / 222 lines. Verdict legend:

- **VERIFIED** — content passes the inclusion rule (silent-failure trap) OR
  bridges to project sessions via the SessionStart force-inject (D2). Stays.
- **RELOCATE** — devshop-internal reference/procedure that project sessions
  never need AND a guide already owns the canonical version. Trim to a one-line
  pointer; verify the detail survives in the target first.
- **CHALLENGE** — borderline; the reduction is condense-not-relocate (the
  toolchain now teaches the bulk loudly, only a residual silent nuance stays).

### Per-candidate classification table

| # | CLAUDE.md section | Current | Verdict | Destination / disposition | Reciprocal edit needed |
|---|---|---|---|---|---|
| C1 | `### Session Start` (hook-internals para: `PROPAGATION.md` generation, `.devshop-version` comparison, `from-devshop.sh`, `/ak-sync-from-devshop`) | ~13 lines | **RELOCATE** | Trim the sync-drift/PROPAGATION mechanics to a one-line pointer. Keep the project-vs-devshop injection contract (it is the hook's load-bearing behavior) + the "self-sufficient project CLAUDE.md" design-principle para (D2 — bridges to project sessions). | **YES (D5).** The full mechanism is NOT yet in any guide — hooks.md:26 has only a one-line table row. **Must relocate the PROPAGATION.md / `.devshop-version` / `from-devshop.sh` detail into `kit/docs/guide/architecture.md` (or hooks.md) FIRST**, then repoint the two inbound cites: `architecture.md:192` and `conventions.md:876`, both of which name `/devshop/CLAUDE.md § Session Start` as the mechanism home. |
| C2 | `### Two repos, two commit flows` (3-step shipping recipe + worktree-add recipe + submodule-step rationale) | ~19 lines | **RELOCATE** | Trim the recipe prose (3-step flow, `git worktree add … origin/main` recipe, submodule-step "why") to pointers at `workflow.md` + merge-devshop SKILL. **KEEP the genuine silent traps**: stash-then-commit clean-tree trip, the "explicit `origin/main` base is load-bearing" worked-bite warning, the `AskUserQuestion`-on-non-main-base rule. | workflow.md already owns the shipping model + worktree/squash mechanics (workflow.md:296, :369, :371, :488). Verify the worktree-add + submodule recipe survives there before trimming; if a unique detail (the `GIT_CMD` array, the submodule-libs bats failure) lives ONLY in CLAUDE.md, lift it to workflow.md first. |
| C3 | `### Claude Code Configuration` (locked-file mechanics: root-owned copies, sticky bit, `sudo nano` to edit) | ~8 lines | **RELOCATE** | Trim locked-file mechanics to a one-line pointer at `security.md § Authoring locked files`. KEEP the two non-mechanics residuals: "custom slash commands go in `.claude/commands/`" + "personal overrides in `.claude/settings.local.json` (gitignored)" — these are orientation, not duplicated procedure. | security.md § Authoring locked files (line 223) + the locked-file list (lines 28–49) already own the mechanics. Verify "root-owned files can still be `git add`-ed" survives there; lift if not. |
| C4 | `### Known Footguns` → "Never commit directly to main" entry | ~1 long para | **CHALLENGE → condense** (D4) | Condense to a one-line pointer preserving ONLY the residual silent trap: "Do not propose creating a GitHub PR on devshop — devshop lands via `/ak-merge-devshop`." Drop the two-layer-enforcement narrative (`check-branch-not-main.sh` PreToolUse + husky branch guard) — both are LOUD-caught, self-teaching at violation. | Mechanism detail already in `hooks.md` (branch-guard) + security.md. Verify the TOCTOU worked-incident (`ef6db18`, 2026-05-20) survives in hooks.md before dropping it here; if not, it is historical context that may simply be dropped per claude-md.md ("one-off historical context → delete"). |
| C5 | All other sections (Context Loading, Philosophy, Implementation Approach, Non-Negotiables, Confidence Calibration, TODO Protocol, Closing-TODO, Commit+PR style, Naming, Quick Reference, gstack, Design System, remaining Known Footguns) | — | **VERIFIED — stay** | No change. D2/D3 keep the project-bridging conventions (Confidence Calibration, TODO Protocol, Commit+PR style, Closing-TODO) and the Non-Negotiables posture list even though guides duplicate them — `kit/docs/guide/*.md` is NOT auto-loaded in project sessions. The Known Footguns silent traps stay by the inclusion rule. | None. |

### Tracker closure (D7)

| Tracker | Location | Action |
|---|---|---|
| ROADMAP § | `kit/ROADMAP.md:364–418` ("CLAUDE.md hygiene — what belongs in always-loaded context…") | **Delete the whole section** (both deliverables A + B shipped 2026-05-27). |
| PLAN row | `PLAN.md:81` (`claude-md-hygiene` Planned v0, Lev 3.6) | **Delete the row.** |
| PLAN Notes pointer | `PLAN.md:81` Notes cell → `kit/ROADMAP.md § CLAUDE.md hygiene` | Removed with the row. |
| BUILD-LOG entry | `BUILD-LOG.md:69` (`claude-md-hygiene (2026-05-27)`) | **KEEP** — backward-looking shipped record, not a stale forward tracker. |
| `claude-md.md` / docs-review Section E refs | various | **KEEP** — these reference the shipped *convention* (the hygiene gate), not the tracker entry. |

### Gate-coverage finding (D8)

Light-verify confirmed during Phase 0/1: commits `412f20b` and `8cdda99` each
modified `CLAUDE.md` (diffstat `CLAUDE.md | 2 +-` — a content modification, not
a pure deletion) yet carry **no `Claude-MD-Classification:` trailer**. By the
Layer-B contract (`check-claude-md-classification.sh` fires on any staged
CLAUDE.md edit that adds/modifies content), those commits should have required
a classification bypass. This is a candidate Layer-B coverage hole. Per D8:
**file it to `kit/TODOS.md`** (devshop, fix-soon) as a standalone investigation
— do NOT expand this PR into a Layer-B rewrite. The TODOS entry is the only
machinery change this PR makes; everything else is pure markdown prune.

## Out of scope

- **Any project `CLAUDE.md`** (home-os etc.) — different repos, unreachable from
  `/devshop` (D6). Left for a project-side `/ak-build` guided by the
  `claude-md.md` recipe.
- **The shipped historical artifact set at `specs/claude-md-hygiene/`** — a
  different directory; do NOT touch. Historical record of the 2026-05-27 build.
- **Re-creating or amending the `claude-md.md` convention / 3-class taxonomy /
  routing table** — this PR APPLIES it, does not re-author it.
- **Fixing the Layer-B gate hole** (D8) — filed to `kit/TODOS.md`, not fixed
  here.
- **Any VERIFIED section in C5** — no edits to project-bridging conventions or
  silent-failure footguns.

## Files to create/modify

| File | Change |
|---|---|
| `CLAUDE.md` (devshop) | C1 trim Session Start hook-internals → pointer; C2 trim Two-repos recipe → pointers (keep traps); C3 trim Claude Code Configuration locked-file mechanics → pointer; C4 condense "Never commit directly to main" footgun → one-line residual. Net: pure-deletion / pointer-substitution edits. |
| `kit/docs/guide/architecture.md` | (C1 reciprocal) If the Session Start mechanism detail is not already present, relocate it here first; repoint line 192's `/devshop/CLAUDE.md § Session Start` cite to the new mechanism home. |
| `kit/docs/guide/conventions.md` | (C1 reciprocal) Repoint line 876's `/devshop/CLAUDE.md § Session Start` cite to the relocated mechanism home. |
| `kit/docs/guide/hooks.md` | (C1/C4 reciprocal, conditional) Receiving home for Session Start mechanism and/or the branch-guard TOCTOU incident IF not already present. Verify-before-trim. |
| `kit/docs/guide/workflow.md` | (C2 reciprocal, conditional) Receiving home for any worktree-add / submodule-step detail that lives ONLY in CLAUDE.md today. |
| `kit/docs/guide/security.md` | (C3 reciprocal, conditional) Confirm locked-file mechanics + "root-owned files can still be `git add`-ed" survive; lift if a unique detail lives only in CLAUDE.md. |
| `kit/ROADMAP.md` | Delete § CLAUDE.md hygiene (lines 364–418). |
| `PLAN.md` | Delete the `claude-md-hygiene` Planned row (line 81). |
| `kit/TODOS.md` | (D8) Add a fix-soon entry for the Layer-B classification-gate coverage hole on `412f20b` / `8cdda99`. |

**No new files.** No code, no tests authored (devshop docs-only).

## Tests

Devshop test surface is **bats** (`kit/tests/`). There is no METRICS.md and no
vitest/Playwright. Posture for this PR:

- **`check-claude-md-classification.sh` (Layer B) passes trivially.** Every
  CLAUDE.md edit in this PR is a deletion or a deletion-plus-shorter-pointer —
  pure reductions. The gate only blocks *additions/modifications that add
  content*; reducing CLAUDE.md is always allowed (no classification bypass
  trailer needed). The one-line pointers that replace trimmed paragraphs are
  net-negative content, so they do not trip the gate. **Confirm at commit time**
  the staged CLAUDE.md diff is reduction-only; if any pointer line reads as a
  *net addition* the gate may fire — classify it then.
- **The real test concern is not a new bats spec — it is no broken cross-refs +
  relocated content actually landing in its target guide.** Verification is
  grep-based, run in Task 4:
  - No remaining `/devshop/CLAUDE.md § Session Start` cite points at content
    that was trimmed out (both `architecture.md:192` and `conventions.md:876`
    must resolve to the new mechanism home).
  - No new dangling `§ <section>` pointer inside CLAUDE.md or its inbound
    referrers.
  - Each RELOCATE's detail is present in its destination guide BEFORE the
    CLAUDE.md copy is deleted (verify-before-delete, not delete-then-hope).
- **Existing bats suite must stay green.** Run `pnpm turbo run test` (or the
  devshop bats target) before marking done — a docs prune should not move any
  test, but `structural-invariants.bats` / `manifest-lifecycle.bats` assert on
  doc wiring and must be confirmed unaffected.
- **No bats spec is added.** There is no deterministic check that "a pointer
  resolves to live content" worth encoding as a one-off test; the cross-ref
  audit is a Task-4 grep sweep, and the Layer-C convention's own enforcement
  (docs-review Section E) is the durable downstream guard.

## Task order

Maps to the 5 Phase-2 tasks already mirrored in the live tracker. Flat list (≤15).

1. **Layer-C classification sweep + verify-before-trim survey.** Walk the four
   RELOCATE/CHALLENGE candidates (C1–C4). For each, confirm whether the target
   guide already owns the canonical detail; record per-candidate "survives /
   must-lift-first" in a scratch finding. Also re-confirm the D8 trailer gap on
   `412f20b` / `8cdda99`. No edits yet — this is the survey that de-risks the
   verify-before-delete invariant.
2. **C1: Session Start.** Relocate the hook-internals mechanism detail into its
   guide home (architecture.md/hooks.md) if Task 1 found it missing; trim the
   CLAUDE.md paragraph to a pointer; **repoint `architecture.md:192` AND
   `conventions.md:876`**. Commit.
3. **C2 + C3 + C4 in one logical prune commit** (or split if cleaner): trim
   Two-repos recipe to pointers (keep traps), trim Claude Code Configuration
   locked-file mechanics to a pointer, condense "Never commit directly to main"
   footgun to its one-line residual. Lift any CLAUDE.md-only detail to its guide
   first. Commit.
4. **Verify-no-loss + fix broken cross-refs.** Grep sweep: no dangling
   `§ Session Start` / `§ <trimmed-section>` cites anywhere; every relocated
   detail present in its target; run the bats suite green. File the D8 Layer-B
   finding to `kit/TODOS.md`. Commit (TODOS entry + any cross-ref fixes).
5. **Close trackers (D7).** Delete `kit/ROADMAP.md § CLAUDE.md hygiene`
   (364–418); delete the `PLAN.md` Planned row (81); confirm no other live
   pointer treats the entry as pending. Commit.

## Gotchas

- **Verify-before-delete is load-bearing (D5).** The Session Start mechanism
  (`PROPAGATION.md` generation, `.devshop-version` comparison, `from-devshop.sh`)
  is NOT currently in any guide — hooks.md:26 carries only a one-line table row.
  Deleting it from CLAUDE.md before relocating it loses the only copy. Relocate
  first, repoint cites, THEN trim.
- **Two inbound cites, not one.** D5 names `architecture.md:192` but
  `conventions.md:876` ALSO cites `/devshop/CLAUDE.md § Session Start` (for "the
  conditional logic"). Both must repoint or one dangles.
- **Keep the traps inside RELOCATE sections.** C2's section mixes recipe (move)
  with genuine silent traps (stash-then-commit clean-tree trip, "explicit
  `origin/main` base is load-bearing", the non-main-base `AskUserQuestion` rule).
  Trim the recipe, KEEP the traps — they fail the loud-failure test and bridge
  to worktree work.
- **D4 is condense, not relocate.** "Never commit directly to main" keeps its
  one-line PR-on-devshop residual (the silent nuance); only the loud-caught
  two-layer-enforcement narrative goes. Don't delete the whole entry.
- **The pointer must not become a net addition.** A replacement pointer longer
  than the text it replaces could flip `check-claude-md-classification.sh` to
  "content added." Keep pointers terse; if one reads as an addition, classify it
  with the bypass trailer rather than fighting the gate.
- **BUILD-LOG stays; ROADMAP+PLAN go.** The shipped BUILD-LOG entry is a
  backward record (keep). Only the forward trackers (ROADMAP §, PLAN row) close.
- **Worktree paths.** All work is in `/devshop/.worktrees/claude-md-hygiene`;
  the Bash tool resets cwd to `/devshop` between calls — use absolute paths or
  re-`cd` each command. The canonical `kit/scripts/**` tree is deny-ruled, but
  worktree copies of `kit/docs/**` are editable.

## Acceptance

- [ ] Devshop `CLAUDE.md` is net-smaller; C1–C4 trimmed per the table; every
      VERIFIED section (C5) unchanged.
- [ ] Session Start hook-internals mechanism lives in a guide
      (architecture.md/hooks.md); CLAUDE.md carries only a pointer.
- [ ] `architecture.md:192` AND `conventions.md:876` repoint away from
      `/devshop/CLAUDE.md § Session Start` to the relocated mechanism home; no
      dangling `§ Session Start` cite remains.
- [ ] C2 traps (stash-clean-tree, `origin/main`-base, non-main-base ask) and
      C3 residuals (`.claude/commands/`, `settings.local.json`) preserved; only
      the duplicated recipe/mechanics trimmed.
- [ ] C4 "Never commit directly to main" condensed to its one-line
      PR-on-devshop residual.
- [ ] `kit/ROADMAP.md § CLAUDE.md hygiene` deleted; `PLAN.md` `claude-md-hygiene`
      Planned row deleted; no live pointer still treats the work as pending.
      BUILD-LOG entry untouched.
- [ ] D8 Layer-B coverage-hole finding filed to `kit/TODOS.md`; this PR does NOT
      attempt the Layer-B fix.
- [ ] `check-claude-md-classification.sh` passes (reduction-only edits); full
      bats suite green; no new broken cross-references anywhere in `kit/docs/`.
- [ ] No project `CLAUDE.md` and no `specs/claude-md-hygiene/` artifact touched.
