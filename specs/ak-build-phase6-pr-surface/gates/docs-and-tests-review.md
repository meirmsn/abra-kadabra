## Gate 5: docs-and-tests-review

Range audited: `origin/main..HEAD` (8 commits). Devshop self-mode — test surface
is bats (`kit/tests/`), no METRICS/UI. Change: `/ak-build` Phase 6 stops posting
the gate-table audit comment (results stay in committed `review.md`), Part D Gate A
becomes autonomous (3-way classify: Accurate / Edit-and-self-resolve / Escalate,
operator prompt on the Escalate rung only), a cross-reference sweep across sibling
skills + guide docs, and updated/added bats coverage.

### DOCS

**Sweep completeness — verified clean.** The D3 consistency sweep is thorough.
`build/SKILL.md`: heading (`## Phase 6: Verify the PR surface`), top-of-file mode
line, architecture diagram, exit-checklist wording, the `gh pr comment` block + its
"intentionally concise" preamble + the count-computation snippet, and ~20 prose
"posts the audit comment / renders in" refs all reframed to "records in `review.md` /
validates the PR body." Sibling skills updated coherently: `spec/SKILL.md:373`,
`conventions.md:445`+`:488`, `docs-review`, `tests-review`, `pre-ship`, `go-live`,
`workflow.md:304`, `FAQ.md`, `OVERVIEW.md`, `claude-md.md` all carry the new Gate A
"autonomous" framing. No surviving doc frames Phase 6 as *posting* a comment or
Gate A as *always asking* the operator. Repo-wide grep for `Gate A.*operator
confirmation` / `Gate A (operator)` returns zero hits outside this feature's own
spec. Historical "PRs that pre-date the comment's removal" refs in `go-live` and
`workflow.md` are correct framing, not findings.

#### LOW-1 — `spec/SKILL.md:232` still lists "Phase 7 ready-for-review comment" as a downstream surface (severity: low)

The Product-update downstream-surfaces enumeration reads: "Single source-of-truth
for the PR body's `## Product update` section, BUILD-LOG ... fields, `/ak-build`
**Phase 7 ready-for-review comment**, and `/ak-go-live` Step 6 deployed-to-prod
comment." Phase 7 posts NO comment — `build/SKILL.md` Phase 7.2 states "No 'Ready
for review' comment — the PR being open IS the notification" and prints a terminal
handoff only. The phrasing is a stale present-tense routing claim, not a historical
ref.

Why surfaced (not purely pre-existing noise): this PR's own diff *corrected the
exact parallel enumeration* in `kit/tests/util-product-update-blurb.bats` (header:
dropped "Phase 7 ready-for-review comment (Detail)", replaced with "(Phase 7 prints
a terminal handoff, not a PR comment ...)"), AND the author edited `spec/SKILL.md`
in the same commit (line 373, the Gate A framing). So the diff touched both the file
and the sibling enumeration that this line mirrors, leaving the two out of sync. The
correct fix is to drop the "Phase 7 ready-for-review comment" clause here too (Phase
7's surface is a terminal handoff, not a routed blurb destination).

Scope note: strictly this is Phase-7-comment-removal residue from a *prior* PR (per
this spec's own framing: "the body + Phase 7 comment were already removed; Phase 6
was missed"), so it sits just outside this PR's D3 scope (Phase-6 audit-comment
framing). It is genuinely low. But CLAUDE.md § "Closing TODO / ROADMAP entries when
a fix ships" / the partial-cleanup principle that *motivates this very PR* argues for
folding the one-clause fix in, since the author was in the file and the parallel bats
line.

### TESTS

**New behavior is fully pinned and non-vacuous.** All 39 bats pass; the 3
new/rewritten assertions each provably FAIL against `origin/main`:

- `Phase 6 Part D Gate A is autonomous; Gate B is the automated cross-check`
  (rewritten line 164): greps `Gate A.*autonomous` + `**Accurate**` +
  `**Edit-and-self-resolve**` + `**Escalate**` within the Part D region. On
  `origin/main` the region had `Gate A.*operator confirmation` and zero
  `Gate A.*autonomous` → would fail. Pins both the autonomous framing and all three
  outcome rungs. ✓
- `Phase 6 Gate A escalation is the only operator prompt` (new): greps `ONLY
  operator prompt` in the `/Gate A — autonomous/,/^## Phase 7/` range. Zero matches
  on `origin/main` → would fail. Pins the escalation-only contract (the single
  surviving `AskUserQuestion`). ✓
- `Phase 6 posts no audit-trail PR comment` (new): asserts `! grep gh pr comment` in
  the `/^## Phase 6/,/^## Phase 7/` range. `origin/main` had 3 `gh pr comment`
  occurrences in that range → would fail. Correctly scoped to the *comment* verb so
  the legitimate `gh pr edit --body-file` body-fix calls in Parts A/B don't
  false-positive; the sole remaining `gh pr comment` in the skill (Phase 5.5
  CI-failure escalation, SKILL.md:2200) sits BEFORE `## Phase 6` so the awk range
  correctly excludes it. ✓

The Gate-B assertions (warn-not-block, awk-parses-spec.md) and the Phase 7.2
no-comment assertions are retained and still green. No new behavior in the diff is
left unpinned: the three behavioral deltas (Gate A autonomous / escalation-only
prompt / Phase 6 posts nothing) each have a dedicated, non-vacuous assertion. No
coverage was deleted — one assertion rewritten to track the new contract, two added.

### Dismissals

- **`build/SKILL.md:3007` "After the comment posts, echo the handoff..."** —
  internally contradicts the line 3 lines above ("No 'Ready for review' comment").
  Dismissed as out-of-scope + pre-existing: `git blame` dates it to 2026-04-20
  (the prior Phase-7-comment-removal PR's residue), it is Phase 7 territory (not
  Phase 6 / Gate A), and this PR's diff does not touch the Phase 7.2 body. Noted for
  a future Phase-7 cleanup, not a finding against this range. (Sibling of LOW-1; if
  LOW-1 is fixed, fold this one-word leftover in too.)
- **`conventions.md:445` "/ak-go-live Step 6 deployed-to-prod comment"** — verified
  CORRECT, not stale: `go-live/SKILL.md:592` does post `gh pr comment ... ## Deployed
  to production`. No finding.
- **Historical "audit / ready-for-review comments on PRs that pre-date their
  removal" refs** (`go-live/SKILL.md:267`, `workflow.md:321`/`:323`) — legitimate
  backward-compat framing for the `/ak-go-live` pending-tasks scan and the
  backfill script; explicitly the kind of historical reference the audit brief
  flags as correct. No finding.
- **CHANGELOG.md "audit" hits** — release-history entries; immutable log, n/a.

findings: high=0 medium=0 low=1

## Resolution

- The one LOW (`spec/SKILL.md` still listing "Phase 7 ready-for-review comment"
  as a blurb downstream surface) was fixed by the orchestrator in `04b5c27`
  (mechanical/obvious: same dangling-reference family, file already in scope) —
  removed both spots + the matching `grep -q 'Phase 7'` bats assertion. bats
  39/39 green after. Net: high=0 medium=0 low=0 pending.
