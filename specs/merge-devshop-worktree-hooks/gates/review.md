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
