## Gate 11: convention

**Verdict: PASS.** No convention violations found. The diff (`origin/main..HEAD`, linear, 0 behind) satisfies every devshop convention checked.

### 1. Closing-trackers convention (`CLAUDE.md § Closing TODO/ROADMAP entries when a fix ships`) — PASS

- **PLAN row deleted**: the `merge-devshop-worktree-hooks` row is gone from `PLAN.md § Planned (v0)` (the rest of the table is whitespace re-padded by prettier after the row removal — no other rows changed).
- **kit/TODOS.md entry deleted**: the `/ak-merge-devshop` + worktree convention entry (l.486–492, the full (a)–(d) option block) is removed.
- **Conditional → imperative-present rewrites, all in this PR**:
  - `CLAUDE.md § Parallel work` bullet rewritten from "Pre-commit hooks do NOT fire in a fresh worktree … skips every gate" to "Pre-commit hooks fire in-worktree only after the recipe's `pnpm install`" + cross-ref to the Phase 2 gitleaks net.
  - `kit/docs/guide/security.md:58` rewritten from "Pre-commit hooks fire identically in worktrees" to "fire in worktrees once the worktree-add recipe's `pnpm install` has run … the `/ak-merge-devshop` Phase 2 gitleaks gate is the unconditional net."
  - `merge-devshop SKILL.md § Phase 2` prose (l.939–947) rewritten from "still fire on the feature-branch commit" to "fire … **where husky is installed** — `/devshop`, or a worktree after the recipe's `pnpm install`" + the unconditional-gitleaks-gate explanation.
- **Stale-prose grep clean**: `grep -rn "do NOT fire\|fire identically\|hooks don.t fire\|claims the opposite"` over `CLAUDE.md` / `kit/` / `.claude/skills/` returns 2 hits, both acceptable:
  - `kit/FRICTION-LOG.md:91` — the entry **title** ("Pre-commit hooks don't fire in linked worktrees …, silently skipping every gate"). Describes the tracked issue; the entry body directly below is `Status: shipped (b)+(d)`. Titles legitimately name the historical symptom.
  - `kit/FRICTION-LOG.md:175` — the third-hypothesis cross-reference, rewritten in this PR to read "husky's `.husky/_` is regenerated only by `pnpm install` … **since shipped (b)+(d): the worktree-add recipe now installs hooks and Phase 2 nets the squash delta with gitleaks**." Install-step-fixed posture, not a false-safety-net belief.
  - The old false claims were removed: the diff deletes "actively claims the opposite (\"All pre-commit hooks fire identically\")" from the Impact line and "asserts \"All pre-commit hooks fire identically\"" from the Detail line.
- **FRICTION-LOG rewritten, not deleted** (per D6 — (c) genuinely unshipped): `Status: shipped (b)+(d) … (c) … remains an optional follow-up`; the full "Candidate fixes (operator picks)" list is collapsed to a single residual (c) stub; `Promotion target` reduced to "(c) session-start `.husky/_` warning → `kit/ROADMAP.md` if/when picked up. (b)+(d) shipped." No "candidate fixes (pick one)" framing retained.

### 2. Commit + PR text style (`conventions.md § Commit + PR Text Style`) — PASS

- The 9 commit subjects lead with a verb / describe the observable change (`scan squash delta for secrets at merge`, `install husky hooks in worktree recipe`, `correct worktree hook-firing claims`, `pin Phase 2 gitleaks gate presence + order`, `close trackers for the shipped worktree-hooks fix`).
- **≤72-char + jargon check is not enforced per-commit at this surface.** The convention's "Where the rule fires" table explicitly marks per-commit messages as "(not enforced per-commit — judged at squash/PR-push time on the rolled-up surface)." This branch lands via `/ak-merge-devshop`, which composes a fresh squash subject that IS the gated surface (Phase 0.4.5 `DEVSHOP_HYGIENE_SURFACE=squash`). The three subjects over 72 chars (85 / 78 / 73) are long only because of the `merge-devshop-worktree-hooks` feature-scope prefix; they are intermediate and superseded by the squash subject. No violation at this gate.
- "pin **Phase 2** gitleaks gate presence + order" — "Phase 2" here names the real `/ak-merge-devshop § Phase 2` code section under test (a concrete, named location), not pipeline meta-narrative; distinct from the convention's "Phase 2 expansion" jargon example. Acceptable.

### 3. CLAUDE.md edit hygiene — PASS

- The `§ Parallel work` recipe-append (`&& (cd .worktrees/<topic> && pnpm install)`) + bullet-rewrite is a Known-Footgun / convention-posture update (per spec Gotcha 4 + D5) — correctly classified for the Layer-2 `devshop.claudeMdClassification` gate at commit time.
- **"Three load-bearing traps" count still matches**: the sub-bullet list under that claim has exactly 3 bullets (origin/main base · pre-commit hooks fire after install · merging is worktree-aware). The hooks bullet was rewritten in place, not added/removed — count invariant holds.

### 4. No new untested scripts — PASS

- `git diff --name-status -- 'kit/scripts/**.sh'` returns empty. No new hook/kit scripts; the (d) change is SKILL.md prose mirroring `.husky/pre-commit:29` verbatim, and the test surface is two bats `@test`s in `util-ak-merge-devshop.bats § Section G`.

### 5. Spec/skill cross-references resolve — PASS

- `CLAUDE.md` bullet → `.claude/skills/devshop/merge-devshop/SKILL.md § Phase 2`: target exists (`## Phase 2: Squash on the feature branch`, l.933).
- `security.md:58` → `/ak-merge-devshop` Phase 2 gitleaks gate: matches the inserted gate.
- FRICTION-LOG references (`CLAUDE.md § Parallel work via linked worktrees`, `.husky/`, `kit/scripts/session-start.sh`) all resolve.

### Tests

`kit/tests/lib/bats-core/bin/bats kit/tests/util-ak-merge-devshop.bats` → 106/106 green, including the two new gates (test 103 presence, test 104 ordering-before-commit). No code-changing fix was made by this gate, so no re-run beyond confirmation was required.

## Dismissals

- **Per-commit subject length > 72 chars (3 commits: 85 / 78 / 73)** — dismissed. `conventions.md § Commit + PR Text Style` "Where the rule fires" table marks per-commit messages as not enforced per-commit; the gated surface is the `/ak-merge-devshop` squash subject (composed fresh at merge). Length is driven by the mandatory feature-scope prefix.
- **`kit/docs/guide/claude-md.md` + `kit/docs/guide/workflow.md` appear in the diff but are not in the spec's file-list** — dismissed as incidental prettier reformatting. The changes are pure markdown-emphasis normalization (`*text*` → `_text_`) and table-column re-padding triggered when prettier ran on the touched files; no semantic content change, no scope creep.
- **`CLAUDE.md` gstack-footgun bullet `**Never edit `…`**`→`**Never edit** `…`` (last commit)** — dismissed. Prettier-stability fix (bold marker can't wrap a code span containing `**`); cosmetic, no semantic change, explained by its commit subject.
- **FRICTION-LOG.md:91 / :175 stale-prose grep hits** — dismissed (see point 1): the :91 hit is the entry title naming the historical symptom (body is `shipped`); the :175 hit is the rewritten cross-ref already in install-step-fixed posture.
