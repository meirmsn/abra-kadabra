# Audit 1 — Docs findings

> Devshop self-mode audit. GIT_ROOT = /devshop/.worktrees/claude-md-condense
> (linked worktree of the devshop repo — treated as devshop self-mode, NOT
> project mode).
> Range: cc48f91a68444b874ab6b7ade77dc6fd3cf44033..8e0e1a0ea32805164c23214debe6a420630e34b6
> Files touched: CLAUDE.md, PLAN.md, kit/ROADMAP.md, kit/TODOS.md,
> kit/docs/guide/claude-md.md, kit/scripts/adversarial-review.sh
> Renames/deletes: none. Bypass trailers (Docs-Coverage / CLAUDE-MD): none.
> Section E (CLAUDE.md hygiene) is project-mode-only per the skill; in devshop
> self-mode the broader latitude of `kit/docs/guide/claude-md.md § What
> CLAUDE.md typically contains` applies, but since the change's purpose IS
> CLAUDE.md hygiene/condensation, the inclusion-rule + reachability-split lens
> was still applied to the condensed sections (see "Reachability check" below).

## Coverage (Section A)

`kit/scripts/adversarial-review.sh` (a `kit/scripts/**.sh` surface) was touched
and `CLAUDE.md` + `kit/docs/guide/claude-md.md` are both in the same range —
coverage rubric satisfied (script change → `CLAUDE.md` OR any
`kit/docs/guide/*.md`). The script change (new gate dimension f) and the new
guide section (§ Reachability split) document the same concept and reference
each other — strong, mutually-consistent coverage.

PLAN.md / kit/ROADMAP.md / kit/TODOS.md are explicit carve-outs (no firing).

## Adequacy (Section B)

- The new `claude-md.md § Reachability split` is substantive (not a stub):
  defines the inline-vs-relocate split, gives a worked one-liner example, states
  the "would this bite before I opened the guide?" test, and explains *why*
  Known Footguns entries are symptom+first-action+pointer. Mutually consistent
  with the new gate dimension (f) in `adversarial-review.sh`, which restates the
  same test in reviewer-prompt form and correctly scopes itself (only FAIL a
  trap that inlines a recipe a guide owns/should-own).
- **Relocation-pointer targets all verified to pre-exist at HEAD** (the central
  risk for this kind of condensation — relocated detail dangling):
  - `kit/docs/guide/ops.md § gstack runtime state` — exists at ops.md:344.
    Section contains the full relocated detail: `GSTACK_HOME`/`GSTACK_STATE_DIR`
    split-brain, the `~/.gstack/projects` symlink, the `.gitignore` re-include
    pattern, and the existing-project backfill recipe. Nothing the CLAUDE.md
    gstack block dropped is missing from the target.
  - `kit/docs/guide/workflow.md` (worktree + merge mechanics) — 23 `worktree`
    mentions + 8 `squash` mentions present; the full shipping/merge model the
    CLAUDE.md "Parallel work" block delegates to is there.
  - `kit/FRICTION-LOG.md` (worktree-hooks "Fix options" pointer) — worktree
    entry present; the CLAUDE.md "Fix options: kit/FRICTION-LOG.md" pointer
    resolves.
- Cross-references inside the touched guide (`adversarial-review.sh` →
  `claude-md.md § Reachability split`) resolve: the heading exists at
  claude-md.md:17.

## Cross-doc coherence (Section C)

- The CLAUDE.md "Parallel work via linked worktrees" condensation preserves the
  pre-commit-hooks-don't-fire-in-worktrees trap that the same range's TODOS.md /
  FRICTION-LOG entries describe — no contradiction between the condensed
  CLAUDE.md claim ("don't trust an in-worktree commit as gate-verified", gated
  at merge-squash time) and the tracker entry's fuller statement of the same.
- The ROADMAP.md edit (moving the `## v1` header up so the PWA-SW + worktree
  entries sit under it) is a structural fix, not a claim change. The `## v1`
  header now appears exactly once (was being re-introduced below; the diff moves
  it above the PWA entry and deletes the lower copy). Coherent.
- No renamed/deleted files in range → no stale-path sweep needed.

## Findings

### [domain: docs] [section: A] [severity: low]
**File**: (commit d6ae19c body — `kit/scripts/adversarial-review.sh`)
**What**: The commit editing `kit/scripts/adversarial-review.sh` (a
propagation-relevant `kit/scripts/**` surface) carries no `**Existing
projects:**` block.
**Why**: The existing-project-migration-block rule (devshop rubric) asks any
commit touching `kit/scripts/**` to state migration posture even when none is
needed. Severity is downgraded from the rubric default (medium) to **low**
because: (a) `adversarial-review.sh` is locked infra that init-devshop.sh
refreshes on rebuild, so the "no migration needed" variant trivially applies;
and (b) the new gate dimension only affects devshop-side CLAUDE.md reviews — it
has no project-repo runtime effect at all. A no-op statement, worth one line for
completeness but not load-bearing.
**Fix**: In the squash/commit body add: `**Existing projects:**
adversarial-review.sh is locked infra refreshed by init-devshop.sh on rebuild;
the new CLAUDE.md-review gate dimension applies devshop-side only. No
project-side migration needed.`

## Reachability / first-action-preservation check (devshop CLAUDE.md lens)

The change's stated risk is that condensation drops a load-bearing first-action.
Reviewed each condensed section against the (system-reminder-provided) HEAD
CLAUDE.md body:

- **gstack section**: retains `/browse` directive, the `cd .claude/skills/gstack
  && ./setup` first-action, and the NEVER-edit-gstack prohibition (with its
  first-action "stop — file upstream OR build a wrapper") before pointing to
  `ops.md § gstack runtime state` for runtime-state mechanics. First action
  preserved — PASS.
- **Parallel worktrees**: retains the full `git worktree add … origin/main &&
  … submodule update --init --recursive` command, the load-bearing `origin/main`
  warning + AskUserQuestion-on-non-main rule, AND the
  hooks-don't-fire-in-worktree trap with its first-action ("don't trust an
  in-worktree commit as gate-verified") before delegating worked-bite + merge
  mechanics to workflow.md. First action preserved — PASS. (Note: this is a net
  *addition* of a load-bearing trap vs the base, not a drop.)
- **Two repos / shipping flow**: keeps both repo paths, the `.devshopkit`
  symlink fact, and the full devshop shipping-flow command sequence. No
  first-action lost — PASS.
- **Implementation Approach / Context Loading / TODO Protocol / friction
  intake**: trims redundant phrasing only ("deduped + counted" parenthetical
  dropped because the skill owns dedup; "lessons land here first … promoted …
  when they earn it" retained). No routing rule or first-action dropped — PASS.
- **Screenshots / browse / Supabase-key / stash-vanish footguns**: each keeps
  its symptom + first-action + pointer shape; condensation removed only recipe
  prose now owned by the cited guide. PASS.

No load-bearing first-action was stripped; the condensation is self-consistent
with the reachability-split principle the same change codifies.

## Summary

high=0 medium=0 low=1

One low finding (missing no-op `**Existing projects:**` block on the
script-touching commit — devshop-side-only effect, not load-bearing). All
relocation pointers verified to resolve to pre-existing content in the owning
guides (ops.md § gstack runtime state, workflow.md worktree/merge mechanics,
FRICTION-LOG worktree entry); no dangling references; no cross-doc
contradictions; the reachability-split codification (guide section + gate
dimension f) is internally coherent; and the CLAUDE.md condensation preserved
every first-action while *adding* the worktree-hooks trap.
