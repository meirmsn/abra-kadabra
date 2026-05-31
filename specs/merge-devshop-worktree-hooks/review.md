<!-- review for merge-devshop-worktree-hooks — assembled at Phase 3.3 (devshop mode) -->

# Pre-ship review — merge-devshop-worktree-hooks

Devshop gate set: 6 dispatched (docs-check, fast-job-local, simplify, convention, docs-and-tests-review/Audit 1, review) + 13 pre-composed carve-outs. Assembled 2026-05-31T02:08:33Z.

## Gate 1: docs-check

- Result: pass

The diff pairs every code/skill surface with docs. The `merge-devshop SKILL.md`
Phase 2 change is paired with `kit/docs/guide/workflow.md` (gate documentation)
and the `CLAUDE.md` § Parallel work recipe + bullet. The per-commit
`check-docs-coverage-devshop.sh` gate passed on all 6 task commits. Tracker
edits (PLAN/TODOS/FRICTION-LOG) and `specs/` are non-coverage surfaces.

## Dismissals

None

## Gate 2: metrics-check

- Result: n/a (devshop-self-mode: no METRICS.md in devshop)

## Dismissals

None

## Gate 2b: rls-coverage

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 2c: slow-job-lifecycle

- Result: n/a (devshop-self-mode: no slow-job CI)

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass

Full bats suite (`kit/tests/`): 1572 passed, 0 failed. The two new Section G
tests (gitleaks-gate presence + ordering-before-commit) are green and were
mutation-verified at Phase 2.5 (each fails if the gate is removed/reordered).
This is devshop-self-mode — bats is the test surface, not turbo.

## Dismissals

None

## Gate 2e: migration-rollback-roundtrip

- Result: n/a (devshop-self-mode: no migrations)

## Dismissals

None

## Gate 2f: changed-tests-local

- Result: n/a (devshop-self-mode: bats run in Gate 2d covers this)

## Dismissals

None

## Gate 2g: advisor-clean

- Result: n/a (devshop-self-mode: no supabase)

## Dismissals

None

## Gate 3: responsive-theme

- Result: n/a (devshop-self-mode: no UI surface)

## Dismissals

None

## Gate 4: simplify

**Result: pass** — no genuine over-complexity to simplify.

Scope per the gate brief: only two real code surfaces in this devshop-self diff
(the rest is prose/docs/markdown + deliberately-explicit orchestration bash).

### Surface 1 — gitleaks gate bash block (`merge-devshop/SKILL.md § Phase 2`)

```bash
if [ -n "$WORKTREE_PATH" ]; then
  ( cd "$WORKTREE_PATH" && gitleaks protect --staged --redact )
else
  gitleaks protect --staged --redact
fi
```

As simple as it can be while staying correct. The cwd-pin is load-bearing
(spec Gotcha 2: running from `/devshop` while the squash lives in a worktree
scans `/devshop`'s index — on `main`, empty staged delta — and false-passes).
The only candidate simplification — collapsing both branches to
`( cd "${WORKTREE_PATH:-/devshop}" && gitleaks ... )` — was rejected: it
hardcodes a `/devshop` literal that the rest of Phase 2 deliberately derives via
`GIT_CMD` / `--git-common-dir`, and forces a `cd` on the non-worktree path where
the squash cwd is already correct. That trades clarity + the orchestration's
path-derivation discipline for a one-line save. Net: leave the explicit if/else.

### Surface 2 — two new bats `@test` blocks (`util-ak-merge-devshop.bats § Section G`)

- Presence test: single `awk '/^## Phase 2:/,/^## Phase 3:/' | grep -qE` —
  minimal, matches the file's existing grep-assertion style verbatim.
- Ordering test: extracts line numbers via `grep -n | head -1 | cut -d: -f1`
  for both anchor lines and compares. This is the standard "X before Y" idiom
  and is consistent with the rest of the suite. Not convoluted.

Full suite re-run after review: `kit/tests/util-ak-merge-devshop.bats` → 106/106
green (incl. the two new tests, 103 + 104). No edits applied — nothing to fix.

## Dismissals

- Collapse the gitleaks if/else to `cd "${WORKTREE_PATH:-/devshop}"` — rationale: hardcodes a `/devshop` literal the surrounding Phase 2 orchestration intentionally derives via `GIT_CMD`/`--git-common-dir`, and forces a `cd` on the path where cwd is already correct; a one-line save at the cost of clarity + path-derivation discipline. Keep explicit.
- Orchestration-skill prose bash + doc/markdown prose — rationale: out of /simplify scope per the gate brief (read by an agent, not executed as a golfed script); readable prose is not "complex code."

## Gate 5: docs-and-tests-review (see Audit 1 below)

- Result: pass (high=0 medium=0 low=4). Full findings in the `## Audit 1` section at the foot of this file.

## Dismissals

None

## Gate 6: review

Read-only code review of `git diff origin/main..HEAD` on `feat/merge-devshop-worktree-hooks`,
against `specs/merge-devshop-worktree-hooks/spec.md`. Focus: the one behavioral change —
the Phase 2 gitleaks compensating gate in `.claude/skills/devshop/merge-devshop/SKILL.md` —
plus the doc-accuracy corrections.

**Verdict: 1 medium + 2 low findings. No high-severity issues. The core gate logic is
empirically correct.**

### Empirical verification performed

I re-derived (did not trust prose) the two load-bearing claims with throwaway-repo experiments:

- **cwd-pinning is correct AND necessary.** Built a parent repo + linked worktree, staged a
  private-key secret in the _worktree_ index, then ran `gitleaks protect --staged` from each cwd:
  - from the **worktree** cwd → `leaks found: 1`, exit **1** (HALT) ✓
  - from the **main repo** cwd → exit **0** (false-pass) — the worktree's staged delta is invisible there
    This confirms Gotcha 2 / the SKILL prose: from `/devshop` while the squash lives in a worktree,
    `--staged` scans `/devshop`'s (empty, on-`main`) index and false-passes. The `( cd "$WORKTREE_PATH"
&& gitleaks … )` subshell is the correct and required pin. The `WORKTREE_PATH` empty → `/devshop`
    branch is correct for the legacy direct-checkout path (squash index lives in `/devshop`).
- **Exit-code → halt is real.** A finding exits non-zero; a clean re-scan exits 0. Idempotence on
  re-run (scrub + re-invoke Phase 2) holds: the gate is a pure read of the staged index with no
  side effects, so after the operator removes the secret the re-scan passes and `commit -F` proceeds.
- **Invocation matches `.husky/pre-commit:29` verbatim** (`gitleaks protect --staged --redact`) and
  shares `.gitleaks.toml` via the common git dir — confirmed by inspection. Same binary (8.30.1).
- **bats suite green**: all 106 tests pass, including the two new Section G tests (103, 104).

### Halt-contract correctness

The prose contract is sound. After the `reset --soft "$ANCHOR"` the index holds exactly the squash
delta; the gate runs on that index; the inline comment (l.1018–1021) states plainly "On non-zero exit
(a finding): HALT — do NOT run the commit below," names the scrub recipe, and asserts idempotent re-run.
The follow-up paragraph (l.1026–1038) re-states the rationale and the cwd pin. An agent following the
skill would not run `commit -F` after a finding — the halt is stated at the decision point, not buried.

### Ordering / placement

Within the `## Phase 2:` → `## Phase 3:` range there is exactly one `"${GIT_CMD[@]}" commit -F` and the
gitleaks lines precede it, so the bats `head -1` ordering assertion is unambiguous. The gate is correctly
positioned **after** the rename-symlink collision block and **before** `commit -F`, matching D3/spec.

### Findings

**[MEDIUM] The ff-merge fallback bypasses the new gitleaks gate, contradicting the stated "even from
an off-convention worktree" invariant.**
When the rename-plus-symlink collision block fires (l.984–1005) and the operator picks "Proceed with
ff-merge," the agent is instructed to "skip the rest of Phase 2, proceed to Phase 3's `git merge --ff-only`
path." I confirmed Phase 3's ff-merge path (SKILL.md l.1207+, the two `git merge --ff-only` lines) runs
**no** gitleaks scan. So on the ff-merge branch the new gate never executes. The ff-merge lands the branch's
N constituent commits as-is — and those commits were gitleaks-gated _only if_ authored where husky was
installed. The exact scenario this PR's gate is built to net — an **off-convention worktree that skipped
`pnpm install`** (so its in-worktree pre-commit hooks, including gitleaks, never armed) — is precisely the
scenario where the constituent commits were **never** secret-scanned. If such a worktree _also_ hits a
rename-symlink collision, a secret in worktree history reaches `main` unscanned via ff-merge.
Three docs now assert the unqualified invariant "a secret can't reach `main` even from an off-convention
worktree" (SKILL.md l.1032–1034, `security.md:58` "unconditional net," `workflow.md` `/ak-merge-devshop`
row). That invariant is **true on the squash path** (the dominant path) but **false on the ff-merge fallback**.
Probability is low (requires off-convention worktree AND a rename-symlink collision), and the primary fix
(b) plus the squash-path gate (d) cover the dominant cases — but the absolute "unconditional / can't reach
main" phrasing overstates the guarantee. Either (i) add the gitleaks scan to the ff-merge fallback before
Phase 3 ff-merges, or (ii) soften the three "unconditional net" claims to scope them to the squash path and
note the ff-merge corner. Not auto-fixed (HALT-ON-FIND gate) — surfaced for the operator to choose.

**[LOW] The COLLISIONS block has no bash-level short-circuit before the gitleaks gate.**
As literal bash, after the `if [ -n "$COLLISIONS" ]; then … fi` block (which ends with comment-only
`# On ff-merge: skip … / # On cancel: exit.`) control falls through to the gitleaks gate and `commit -F`.
The "skip the rest of Phase 2" behavior lives entirely in the `# AskUserQuestion` comment — it is agent-
interpreted orchestration, not executed control flow. This is consistent with how the rest of the skill is
written (the file is prose an agent runs, not a script), so it is not a defect per se, but a literal-bash
reader could momentarily read the fence as "collision detected → still scan → still commit." A one-line
`# (agent: on the ff-merge branch, do NOT fall through to the gitleaks gate / commit below)` at the gate
would remove the ambiguity. Cosmetic.

**[LOW] Incidental markdown-formatting churn outside the declared spec scope.**
The diff carries prettier/markdownlint normalizations not in the spec's "Files to modify" intent:
`*italic*` → `_italic_` across `kit/docs/guide/claude-md.md` (5 spots) and SKILL.md (`*still*` → `_still_`),
and two `**Never edit `…`**` → `**Never edit** `…``rewrites in`CLAUDE.md`(the gstack-edit footgun + the`§ gstack` bullet). The CLAUDE.md rewrites are arguably *correct* fixes — bold markers (`**`) wrapping a
code span that itself contains `**` (`.claude/skills/gstack/\*\*`) break emphasis parsing — so moving the bold
boundary outside the code span is a legitimate repair. All are formatting-only; I verified no semantic content
changed on any of these lines. Flagged only because they widen the blast radius of a "one behavioral change"
PR beyond what the spec enumerated; harmless to keep.

### Non-findings verified clean

- **PLAN.md closure**: only the `merge-devshop-worktree-hooks` row removed; remaining 32-line churn is pure
  prettier table-column re-alignment after the longest row dropped, plus one normalized blank line before
  `## Bundling cheatsheet` (single blank, well-formed). No other rows altered in content. ✓
- **kit/TODOS.md**: the `/ak-merge-devshop` + worktree (a)–(d) entry deleted; no dangling refs. ✓
- **FRICTION-LOG.md**: entry rewritten to `Status: shipped (b)+(d); (c) optional follow-up`, candidate-fixes
  list collapsed to the single residual (c) stub, "actively claims the opposite" doc-drift framing dropped
  (now accurate, since the docs were corrected). The sibling "CLAUDE.md classification at squash boundary"
  entry's cross-ref was correctly updated to note (b)+(d) shipped. ✓ The `<TBD — Phase 4.0 fills>` merge-SHA
  placeholder is expected at review time (filled at merge).
- **Doc-accuracy corrections accurate against code**: CLAUDE.md bullet, SKILL.md Phase 2 prose (l.939–947),
  and `security.md:58` all now describe the install-step-dependent + Phase-2-gitleaks-net posture. No residual
  "fire identically" / "do NOT fire" / "All pre-commit hooks fire identically" absolutes remain anywhere
  (grep-verified across CLAUDE.md, kit/docs/guide/, SKILL.md, FRICTION-LOG.md). The only inaccuracy is the
  "unconditional" over-claim captured in the MEDIUM above.
- **bats tests pin the contract, not tautological**: test 103 fails if the gitleaks line is deleted; test 104
  fails if the gate is moved after `commit -F`. Grep-against-skill-prose is the right granularity for a skill
  file and matches the file's existing 100+ test style. Robust (awk range bounds `^## Phase 2:`/`^## Phase 3:`
  are real headers; single `commit -F` in range makes `head -1` safe).

## Dismissals

- **"`( cd … )` subshell doesn't persist cwd to the later `commit -F`"** — not a bug. The `commit -F` runs
  via `"${GIT_CMD[@]}"` (which is `git -C "$WORKTREE_PATH"` when set), not via inherited cwd, so the subshell
  scoping the gitleaks `cd` is exactly right: gitleaks needs the cwd pin (it has no `-C`-equivalent that reads
  the worktree index here), while git ops are pinned by `-C`. Two correct mechanisms, deliberately different.
- **"gitleaks should use `--source`/`-C` instead of a `cd` subshell"** — `gitleaks protect --staged` resolves
  the repo/index from cwd; the subshell is the idiomatic pin and matches how husky invokes it (from repo root).
  No cleaner flag-based form exists for staged-index scanning in 8.30.1. n/a.
- **"two `gitleaks protect --staged` lines (if/else branches) — ordering test could match the wrong one"** —
  both branches precede `commit -F`; `head -1` takes the first, which is still before commit. No ambiguity. n/a.
- **`<TBD>` merge-SHA placeholder in FRICTION-LOG** — expected at review time; Phase 4.0 fills it at merge.
  Not a finding.

## Focused fix log

- **[MEDIUM] ff-merge fallback bypassed the gitleaks gate** → FIXED in commit
  `a7058e4`. Phase 3's ff-merge path now recomputes $ANCHOR before
  `checkout main` and runs `gitleaks git --redact --log-opts "$ANCHOR..$BRANCH"`(cwd-pinned) before`git merge --ff-only`, halting on a finding — so the
  gate is genuinely unconditional across both squash and ff-merge paths.
  Empirically verified (exit 1 on a Stripe key in range, 0 clean). Pinned by
  bats tests 106 + 107.
- **[LOW] cwd-subshell not pinned by a test** (from Gate 5) → FIXED in
  `a7058e4`, bats test 105.
- **[LOW] COLLISIONS block bash short-circuit clarity** → noted; the skill is
  agent-read orchestration prose and the "skip the rest of Phase 2" comment is
  adequate in context. No change. (proceed)
- **[LOW] incidental prettier/markdownlint churn** → semantically inert
  formatting; the two `**Never edit**` gstack repairs are correct. No change.
  (proceed)

Net: 1 medium + 1 low fixed (commit a7058e4); 2 lows noted-and-proceed. 0 pending.

## Gate 7: /cso

- Result: blocked (n/a per scope: devshop-self-mode — no auth boundary, no RLS, no third-party APIs; security boundary is the pre-commit hook gauntlet itself)

## Dismissals

None

## Gate 8: /design-review

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface)

## Dismissals

None

## Gate 8b: design-conformance

- Result: n/a (devshop-self-mode: no DESIGN.md)

## Dismissals

None

## Gate 9: /qa

- Result: blocked (n/a per scope: devshop-self-mode — no UI surface; bats invariants are the test surface and run in Gate 2d)

## Dismissals

None

## Gate 10: /benchmark

- Result: blocked (n/a per scope: devshop-self-mode — no perf surface)

## Dismissals

None

## Gate 10b: preflight-final

- Result: n/a (devshop-self-mode: bats recheck in Gate 2d covers this)

## Dismissals

None

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

## Audit 1: pre-ship (2026-05-30)

<!-- audited-at: 167664419e0d805ff309c7a02fbc474665d4f1ca -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=4

### Docs findings

- [low] CLAUDE.md:80 — the worktree-add recipe now ends `&& (cd .worktrees/<topic> && pnpm install)`; the inline gloss explains husky `.husky/_` + node_modules, but the three-step compound has no failure-isolation note — if `pnpm install` fails the worktree still exists with unarmed hooks. Non-blocking: the new Phase 2 gitleaks net covers the residual secret-leak path. Coverage adequate.
- [low] .claude/skills/devshop/merge-devshop/SKILL.md:54-66 — the new Phase 2 gitleaks prose is thorough (cwd-pin rationale, `--staged` == squash-delta, `.husky/pre-commit:29` mirror, off-convention dependency) but does not name which `.gitleaks.toml` the worktree resolves beyond "shares the parent's config via the common git dir." Verified accurate (root `.gitleaks.toml` exists; no worktree-local override possible). Adequate as written.

Coverage: the new gitleaks gate (d) is documented in all four operator/agent lookup surfaces — SKILL.md Phase 2 (home, with halt-and-scrub recovery), CLAUDE.md § Parallel work + § Known Footguns bullets (ambient symptom+pointer), workflow.md `/ak-merge-devshop` skill-table row, security.md:58. Lookup coverage complete.

Doc-accuracy corrections: COMPLETE. Grep for stale false-safety-net phrasings ("fire identically", unqualified "still fire on the feature-branch commit", "All pre-commit hooks fire", "hooks do NOT fire in a fresh worktree") returns ZERO hits across CLAUDE.md, kit/docs/, .claude/skills/. The prior CLAUDE.md Known-Footgun "hooks do NOT fire in a fresh worktree" bullet, the SKILL.md "still fire on the feature-branch commit" claim, and security.md:161 "fire identically in worktrees" were each rewritten to the install-dependent + Phase-2-gitleaks-net posture. No stale claim left behind.

Internal consistency: FRICTION-LOG entry, CLAUDE.md (two bullets), SKILL.md Phase 2, workflow.md row, security.md all describe one coherent posture — (b) install arms in-worktree hooks; (d) Phase 2 gitleaks is the unconditional net. The adjacent FRICTION-LOG "classification gate doesn't re-fire at squash boundary" entry was threaded to reference shipped (b)+(d) so it no longer contradicts. No internal inconsistency in any touched doc.

### Tests findings

- [low] kit/tests/util-ak-merge-devshop.bats:220 — presence + ordering tests pin gate-exists and halt-before-commit (the load-bearing behavior), but neither pins the cwd-pin subshell `( cd "$WORKTREE_PATH" && … )` nor `--redact`. A prose edit that dropped the cwd-pin (the subtle false-pass risk SKILL.md flags as "load-bearing") would not be caught. Low: docs surface, prose explains the pin at length, both tests mutation-verified at Phase 2.5. A worktree-cwd assertion would tighten the net.
- [low] kit/tests/util-ak-merge-devshop.bats:229 — the ordering test couples to the exact `GIT_CMD[@]` commit-`-F` invocation form; the `[ -n "$commit_line" ]` guard makes a future-refactor miss fail loudly rather than silently pass, so the coupling is acceptably defensive. No change required.

Coverage adequacy: both new tests adequately pin the new behavior (gate presence in the Phase 2 range, halt-before-commit ordering). Scope is correct — the `awk '/^## Phase 2:/,/^## Phase 3:/'` range bounds the gate (verified: gate under `## Phase 2:` at SKILL.md:933, before `## Phase 2.5:` at :1078). Non-empty guards prevent a vacuous pass. Both run green (ok 103, ok 104). The (b) `pnpm install` recipe change is prose-only with no executable surface, so no dedicated test is the right call. No skipped tests, no LLM/edge-boundary surface in range.

### Bypass trailer audit

- 223082e Docs-Coverage-Bypass: "skills surface (merge-devshop SKILL.md) — paired guide docs were updated EARLIER in this same feature branch … re-editing them now would be redundant padding" — VERIFIED. The bypass reason names workflow.md (updated commit 79a0eb3) + CLAUDE.md (commit f887c8e) as the canonical homes already carrying the Phase 2 gitleaks prose, lists grep-verified NOT-AFFECTED guide docs, and the commit's actual surface (SKILL.md's own internal Phase 2 prose + security.md:58) is a self-contained doc-accuracy correction. Cross-checked: workflow.md row + CLAUDE.md bullets do carry the new prose; security.md was itself substantively edited in this commit. Reason is specific and accurate.

## Phase 3 → 4 advance log

### 2026-05-31T02:08:33Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T02:08:33Z -->

### 2026-05-31T02:08:33Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T02:08:33Z -->

### 2026-05-31T02:08:33Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T02:08:33Z -->

### 2026-05-31T02:08:33Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-31T02:08:33Z -->

## Audit 2: manual (2026-05-30)

<!-- audited-at: dbfaa4de31977aa48ee6b82e3880b9639e5f868e -->
<!-- range: 7e3767d36300..dbfaa4de3197 -->

findings: high=0 medium=0 low=3

Merge-time re-audit (`/ak-merge-devshop` Phase 1.1). The explicit `--range` spans the FULL feature delta; the substantive new surface since Audit 1 (stamp 1676644, clean high=0 med=0 low=4) is the Phase 3 ff-merge gitleaks gate (`a7058e4`), its 3 new bats tests, the gate evidence (`d12ea39`), and the BUILD-LOG entry (`dbfaa4d`). Audit 1's MEDIUM (ff-merge fallback bypassed the gitleaks gate) is RESOLVED by code at `a7058e4` — the "unconditional / can't reach main even from an off-convention worktree" claim is now accurate across all surfaces, not squash-only.

### Docs findings

- [low] BUILD-LOG.md:7 — quality-gates line reports "1575 passed" vs review.md Gate 2d's "1572 passed"; the +3 is the three new ff-merge Section G tests added post-Audit-1 (internally consistent, 1575 is the correct count at HEAD). Count-drift note across audit artifacts, not a defect.
- [low] .claude/skills/devshop/merge-devshop/SKILL.md:1281-1298 — Phase 3 ff-merge gate prose is thorough (ANCHOR-recompute-before-checkout, `protect --staged` vs `gitleaks git` subcommand split, cwd-pin, halt contract) and `--log-opts`/`--redact` were empirically verified against gitleaks 8.30.1; like Phase 2 it names the shared `.gitleaks.toml` only via "the common git dir" without restating no worktree-local override exists. Parity with Audit 1's adequacy note, not a regression.

Coverage: the Phase 3 ff-merge gate (a7058e4) is documented in every operator/agent lookup surface — SKILL.md Phase 3 (home + halt-and-scrub recovery), the Phase 2 cross-ref comment ("see Phase 3's ff-merge gitleaks gate"), workflow.md `/ak-merge-devshop` row (both paths scan: `protect --staged` squash / `gitleaks git` ff-merge), security.md:58 "unconditional net," BUILD-LOG Summary, and the CLAUDE.md § Parallel work bullet's Phase-2-net cross-ref. The `.claude/skills/**/SKILL.md` rubric row (→ workflow.md OR CLAUDE.md) is satisfied (both updated).

Adequacy: named-mechanism empirical verification performed — `gitleaks git --log-opts` + `--redact` confirmed present in the installed binary (8.30.1) via `gitleaks git --help`; the doc's claimed invocation is real. The Audit 1 over-claim MEDIUM is resolved by code (a7058e4), not by softening prose; the three docs asserting "unconditional / can't reach main" (SKILL.md:1045-1050, security.md:58, workflow.md row) are accurate at HEAD.

Cross-doc coherence: stale-prose sweep (`do NOT fire | fire identically | hooks don't fire | All pre-commit hooks fire | claims the opposite`) over CLAUDE.md + kit/docs/ + .claude/skills/devshop/ returns ZERO hits. The two kit/FRICTION-LOG.md hits are the historical entry title (body = `Status: shipped (b)+(d)`) and a rewritten install-step-fixed cross-ref — both expected. Cross-ref `CLAUDE.md → SKILL.md § Phase 2` resolves (anchor SKILL.md:933). No renamed/deleted files in range. Phase 2 ↔ Phase 3 ↔ workflow.md ↔ security.md ↔ BUILD-LOG describe one coherent posture; no contradiction.

CLAUDE.md hygiene (Section E): skipped (devshop self-mode). In-range CLAUDE.md edit (§ Parallel work bullet rewrite + two gstack prettier-stability repairs) is a posture update + semantically-inert formatting fix; no inclusion-rule regression.

### Tests findings

- [low] kit/tests/util-ak-merge-devshop.bats:877-887 — the Phase 3 ordering test extracts the ff-merge anchor via `grep -nE 'git merge --ff-only "$BRANCH"' | head -1`, but that pattern matches TWICE in the `## Phase 3:`→`## Phase 4:` range (SKILL.md:1300 code line + SKILL.md:1310 recovery-prose sentence). `head -1` lands on the code line only because the code precedes the prose; the gitleaks scan (1294) is before both, so the assertion is correct at HEAD but relies on incidental ordering, not a guard. The sibling Phase 2 ordering test (104) is robust (single `commit -F` in range). Tighten to a unique code-form anchor (e.g. trailing `# ff main` comment). Non-blocking — test 106 already pins the load-bearing "gate exists" invariant.

Coverage (devshop rubric, `.claude/skills/devshop/**/SKILL.md` → util-bats): the Phase 3 ff-merge gate (a7058e4) is covered by 3 new Section G tests, all green (ok 105/106/107): 105 cwd-pin (closes Audit 1's [low] kit/tests:220 — dropping the subshell now fails a test), 106 history-scan presence (`gitleaks git --redact --log-opts "$ANCHOR..$BRANCH"`; awk bounds verified — Phase 3/4 headers real + unique, single in-range match), 107 ordering-before-ff-merge (see [low] above). The (b) `pnpm install` recipe change is prose-only with no executable surface — no dedicated test is the right call.

Quality: the 5 Section G tests use grep-against-skill-prose at the right granularity for a SKILL.md, with non-empty guards (`[ -n "$..._line" ]`) so a future refactor fails loudly rather than silently green. No `.only`, no skipped tests, no LLM/edge/realtime/RLS surface in range (devshop self-mode). Full suite green: 109/109 (util-ak-merge-devshop.bats), 1575/0 across kit/tests/.

### Bypass trailer audit

- 223082e Docs-Coverage-Bypass: "skills surface (merge-devshop SKILL.md) — paired guide docs were updated EARLIER in this same feature branch … re-editing them now would be redundant padding" — VERIFIED. (Re-harvested because the explicit `--range` predates Audit 1's stamp; already VERIFIED in Audit 1.) The named canonical homes — workflow.md `/ak-merge-devshop` row (79a0eb3) + CLAUDE.md § Parallel work bullet (f887c8e) — do carry the new Phase 2 gitleaks prose at HEAD; the commit's own surface (SKILL.md internal Phase 2 prose + security.md:58) is a self-contained doc-accuracy correction. Reason specific and accurate.
- No `Tests-Coverage-Bypass:` trailers in range. (none)
