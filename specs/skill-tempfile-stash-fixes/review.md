# Review — skill-tempfile-stash-fixes

## Audit 1: manual (2026-05-20)

<!-- audited-at: ee7855a65dcd970f9c22f979ae7d776a19c975e4 -->
<!-- range: 00a339ccb0f57ef1cbccca81aa1540ab8bc9079c..ee7855a65dcd970f9c22f979ae7d776a19c975e4 -->

findings: high=0 medium=0 low=3

### Docs findings

### [domain: docs] [section: A] [severity: low]
**File**: kit/docs/guide/hooks.md (not touched in range)
**What**: The new silent-stash-drop recovery recipe (`git fsck --no-reflogs` + case-filter for stash-shaped subjects + `git stash apply <SHA>`) lives ONLY inside `.claude/skills/devshop/merge-devshop/SKILL.md § Known limitations § Operator stashes can vanish silently mid-merge`. It is NOT discoverable from `kit/docs/guide/hooks.md` (the canonical home for husky / lint-staged / stash behavior), nor cross-referenced from CLAUDE.md § Known Footguns alongside the existing "Never discard unrelated dirty files" entry that already covers stash usage.
**Why**: Per devshop rubric, `.claude/skills/**/SKILL.md` edits require a paired `kit/docs/guide/workflow.md` OR `CLAUDE.md` touch. Neither was staged. The recovery recipe is generalizable knowledge (lint-staged dropping stashes affects any commit, not just `/ak-merge-devshop`); a future operator hitting the same symptom from a different code path (a manual commit on a feature branch, a `/ak-build` Phase 4 commit) would not find the recipe by searching the guides. Operator triage flow on a vanished stash is "grep the guides for stash recovery" — currently returns nothing. Severity **low** rather than medium because (a) the TODO entry explicitly flags root-cause investigation as still pending — the recipe is a backstop, not the canonical fix; (b) the worked incident commit message + the TODO entry both name the recipe location explicitly, so reflection from a prior incident finds it; (c) the recipe is two grep-hits away (`grep -r 'fsck --no-reflogs' .claude/skills/`). Acceptable to defer the guide lift until root-cause investigation lands and the canonical fix shape is known.
**Fix**: Defer. When the root-cause-investigation TODO closes (kit/TODOS.md line ~388 in this range — "Operator stashes vanish silently"), the shipping PR for that fix should ALSO lift the recovery recipe from SKILL.md into `kit/docs/guide/hooks.md § Practical recipes` (new subsection: "Recovering a vanished stash") and add a one-line CLAUDE.md § Known Footguns pointer. If the root cause isn't found within ~30 days, lift the recipe to hooks.md preemptively rather than leave it skill-buried indefinitely.

### [domain: docs] [section: B] [severity: low]
**File**: .claude/skills/devshop/merge-devshop/SKILL.md:929-936 (the new "Prevention" paragraph)
**What**: The prevention paragraph ends "Operator stashes made BEFORE invoking the skill are still at risk if lint-staged fires during the merge — operators with critical WIP should commit (even to a throwaway branch) rather than stash." This is correctly actionable guidance, but the surrounding hypothesis paragraph ("Hypothesis: the `.husky/pre-commit` hook's `lint-staged` step uses `git stash` for its own backup, and certain failure / interrupt modes drop the operator's named stash") asserts the lint-staged interaction WITHOUT a citation to where that mechanism is verifiable. The TODO entry explicitly flags this as "needs reproduction with `GIT_TRACE=1` + `lint-staged --debug` to confirm".
**Why**: Adequacy rule: "named-section claims verified by grep". The hypothesis is presented as the working theory but the reader can't follow the claim chain — there's no link to lint-staged docs, `.husky/pre-commit` source, or the package.json lint-staged config block. A future operator (or future Claude) reading this could over-trust the hypothesis as confirmed. Severity **low** because (a) the language IS hedged with "hypothesis" + "certain failure / interrupt modes"; (b) the prevention guidance is correct REGARDLESS of whether the hypothesis pans out (don't autostash + commit-WIP-to-throwaway-branch is good advice either way); (c) the TODO entry explicitly defers root-cause confirmation.
**Fix**: Optional. When the root-cause TODO closes, update this subsection to either (a) confirm the lint-staged mechanism and add a `package.json` line-pointer + `.husky/pre-commit` line-pointer; or (b) revise the hypothesis if the investigation finds a different root cause. No edit needed now.

### [domain: docs] [section: C] [severity: low]
**File**: kit/TODOS.md (new entry: "Operator stashes vanish silently during /ak-merge-devshop")
**What**: The new TODO entry's "Edit targets" line names `package.json` lint-staged `stash: false` config as a likely candidate. Cross-doc coherence check: there is no existing `package.json` lint-staged section documented in `kit/docs/guide/hooks.md` or any other guide — the `stash: false` knob is a real lint-staged config option, but the TODO doesn't link to lint-staged docs and there's no devshop-side documentation of the current lint-staged config that the candidate fix would amend.
**Why**: Future-Claude reading this TODO will need to grep for the lint-staged config block to understand what `stash: false` would change. Cross-doc coherence isn't violated (no contradiction with reference docs) but the entry could be more grep-friendly. Severity **low** because (a) the TODO is explicitly flagged as investigation-pending; (b) the candidate fix is one of two listed alternatives, not a committed direction; (c) `pnpm exec lint-staged` IS named in hooks.md:130 — a future investigator can chain from there.
**Fix**: When this TODO is picked up for implementation, the implementing commit should add the actual `package.json` lint-staged config block to `kit/docs/guide/hooks.md § Commit Flow` (the lint-staged step description currently elides the config). No edit needed in this audit's scope.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
