<!-- audited-at: 22061912d1dcb5708ad8cd4ae20434423c3b693d -->

# Review — triage-todos-to-friction-log

## Router Summary

- Mode: devshop-self-mode (6 gates dispatched, 13 carve-outs).
- Dispatched: docs-check=pass, fast-job-local(bats 1568/1568)=pass, /simplify=pass, /review=pass, convention=findings(1) LOW, docs-and-tests-review=see ## Audit 1 below.
- LLM-mediated carve-outs (structural blocked): Gate 7 /cso, Gate 8 /design-review, Gate 9 /qa, Gate 10 /benchmark — see ## Phase 3 → 4 advance log.
- Low finding (convention): two intermediate commit subjects exceed 72 chars; squash-moot (the /ak-merge-devshop squash subject is the reviewer-facing surface). Note + proceed.
- Dismissals: none.

## Gate 1: docs-check

- Result: pass

Diff touches only tracker files (`kit/TODOS.md`, `kit/FRICTION-LOG.md`,
`PLAN.md`, `.gitignore`) + this feature's own `specs/` artifacts. No devshop
tooling surface changed (no `kit/scripts/**`, `kit/hooks/**`, `.claude/skills/**`,
`template/**`), so the "every tooling change ships doc updates" rule is n/a. The
change IS documentation (tracker hygiene). Reference docs (`kit/docs/guide/*.md`,
`OVERVIEW.md`, `CLAUDE.md`) need no update — the friction-log workflow they
describe is unchanged; this is its first invocation, not a contract change.

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

## Gate 4: /simplify

- Result: pass

No executable code in the range — diff is tracker/docs only (kit/TODOS.md, kit/FRICTION-LOG.md, PLAN.md, .gitignore + specs/ artifacts). The change is itself a net simplification: it lifts six verbose TODOS entries (subagent-drift, prTextHygiene false-positive, git-ls-remote garble, visual-evidence deferrals, doc/bats-test drift, Mac host-resource hypothesis) into compact FRICTION-LOG entries that reference the long-form notes rather than restating them, and reduces the rest to version-tagged one-liners. Verified no residual cross-tracker duplication remains (e.g. subagent-drift now lives once in FRICTION-LOG, pointing at kit/notes/roadmap/subagent-cleanup-pattern.md). The `*`→`_` emphasis swaps are Prettier normalization. Nothing to simplify in trackers.

## Dismissals

None

## Gate 6: /review

- Result: pass

Reviewed `git diff origin/main..HEAD` (7 commits) with the /review code-review lens. Scope is exactly as stated — a pure tracker/docs change, no source/SQL/auth/trust-boundary/conditional-side-effect code.

**Scope confirmation (a):** `git diff --name-only` returns only `.md` files + `.gitignore` — `PLAN.md`, `kit/FRICTION-LOG.md`, `kit/TODOS.md`, `specs/triage-todos-to-friction-log/{spec,tasks}.md`, `.gitignore`. Filtering out `.md` and `.gitignore` leaves zero files. No executable, config, or schema surface touched.

**(a) Secrets/tokens:** Scanned the full diff and all changed docs for real credential patterns (`ghp_`/`gho_`/`ghs_`/`github_pat_`, JWTs `eyJ…`, PEM headers, AWS `AKIA…`, OpenAI `sk-…`, Supabase `sbp_…`, 64-hex, `password=`/`secret=`, `service_role…key=`). Zero matches. The `${TOKEN}` / `$TOKEN` / `DEVSHOP_GITHUB_TOKEN=$TOKEN` strings in the "`git ls-remote` garbled output" friction entry are shell variable _names_ describing the bug, not literal secret values — correct and not a leak.

**(b) .gitignore rule:** Added `.claude/scheduled_tasks.lock` (single exact relative path, with an explanatory comment "Scheduler runtime lock"). `git check-ignore -v` confirms it matches `/devshop/.claude/scheduled_tasks.lock` precisely. Not a glob, not a directory-ignore — scoped to exactly the transient lock file, not over-broad. The lock file exists on disk (114 bytes) and is correctly untracked.

**(c) Diff matches stated intent:**

- **7 entries → friction log:** Exactly 7 new `### ` headings added under `kit/FRICTION-LOG.md § Open` (Mac host-resource, Layer-B squash gap, doc/SKILL grep-test drift, visual-evidence rubber-stamp, prTextHygiene false-reject, subagent drift, ls-remote garbled). Each carries the full schema (Score/Impact/Count/Status/First seen/Sessions/Symptom/Detail/Promotion target), sorted by Score desc. The 7 corresponding `[ ]` items were removed from `kit/TODOS.md`. Match confirmed.
- **Driver entry deleted:** Commit `218e65b` removes the "Triage TODOs vs FRICTION-LOG" driver entry from `kit/TODOS.md` alongside the 7 demotions (80 deletions, no additions). Confirmed.
- **virtiofs → PLAN:** `virtiofs-rebase-auto-switch` inserted as the first body row of `PLAN.md § Planned (v0)` (Lev 8.0). The Planned-v0 table column widths were reflowed to accommodate it — cosmetic whitespace only, no other rows changed in content. Confirmed.
- **Version tags applied:** Remaining `kit/TODOS.md` open items gained `[vN]` tags (`[v0]`/`[v1]`/`[v+]`) per the triage buckets. No content changes to those entries beyond the tag suffix.
- **Nothing unexpected bundled:** spec.md + tasks.md are new artifact files for this feature (expected). The only other deltas are Markdown emphasis-style normalizations (`*x*` → `_x_`) in FRICTION-LOG.md prose — incidental formatter touch, harmless. No stray code, no unrelated tracker edits.

No correctness, reuse, or efficiency findings apply (no logic in scope). No security findings. Diff is clean and matches intent.

## Dismissals

None

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

- Result: findings (1)

**Commit subjects — conventional-commit + readability (`git log origin/main..HEAD --oneline`)**: All 7 subjects use valid conventional-commit types (`docs:`/`chore:`) with scopes and describe the observable change (e.g. "demote 7 premature items to friction log", "promote virtiofs phantom-rebase auto-switch to v0", "version-tag remaining open entries per triage buckets"). PARTIAL — two subjects exceed the ≤72-char readability limit from `kit/docs/guide/conventions.md § Commit + PR Text Style`:

- `chore(triage-todos-to-friction-log): branch baseline — capture triage intake + ignore scheduler lock` — **102 chars**
- `chore(todos): demote 7 premature items to friction log; delete triage driver` — **76 chars**
  These are already-committed history on the branch; the squash subject produced at `/ak-merge-devshop` Phase 0.3 is the reviewer-facing surface that the pre-push `prTextHygieneReason` engine judges, so the over-length per-commit subjects do not block. Flagged as a readability finding only. The other 5 subjects are ≤72.

**FRICTION-LOG.md entry schema + ordering (`kit/FRICTION-LOG.md` top-of-file rules)**: PASS. The branch added 7 new entries (matching the "seed 7 demoted TODOs" commit). All 8 Open-section entries carry the full 9-field schema (Score / Impact / Count / Status / First seen / Sessions / Symptom / Detail / Promotion target) — verified programmatically, zero missing fields. Scores are sorted descending: 4, 4, 3, 3, 3, 3, 2, 1 (ties broken by impact then recency, consistent with the Ordering rule). Each Score equals `impact × count`. `## Resolved` section present and empty ("_None yet._").

**PLAN.md virtiofs row — "How to add entries" column contract**: PASS.

- Hook: `/ak-merge-devshop auto-detects the virtiofs phantom-rebase flake and auto-switches to the merge fallback` = **104 chars** ≤ 120. OK.
- Source: `` `kit/TODOS.md` `` `§` `/ak-merge-devshop` Phase 2 / Phase 1.0 — mechanize the virtiofs phantom-rebase fallback`— correct shape (file path in its own code span +`§`separator + heading text). Source heading >70 chars so the truncation rule applies; truncated at the first`—`-bearing parenthetical, and the cited text resolves to exactly 1 match in `kit/TODOS.md`. OK.
- Lev: M impact (3) × S risk (2) ÷ S cost-divisor (0.75) = **8.0**, matches the cell. Table is sorted by Lev descending (8.0, 3.6, 3.6, 3.2, 2.4, 2.4, 0.7). OK.

**kit/TODOS.md version tags — documented `[vN]` form**: PASS. The branch's added/changed tag lines use only `[v0]`, `[v1]`, `[v+]` (diff-of-added-lines: 8×`[v0]`, 15×`[v1]`, 6×`[v+]`). Pre-existing `[v0.2]` and `[v0+]` tags are NOT introduced by this branch and are explicitly sanctioned by the file's own header comment ("Tag with [v0.2], [v1] etc."). `[v+]` is the established "future/unscheduled" tier already in use across the file. No malformed tags introduced.

**No SKILL.md / shell-script / guide-doc changes**: CONFIRMED. `git diff origin/main..HEAD --name-only` is tracker/docs/spec only: `.gitignore`, `PLAN.md`, `kit/FRICTION-LOG.md`, `kit/TODOS.md`, `specs/triage-todos-to-friction-log/{spec,tasks}.md`. No `*SKILL.md`, no `*.sh`, no `kit/docs/guide/**`. The SKILL-frontmatter and new-script-needs-bats convention checks are correctly n/a.

## Dismissals

None

## Gate 2d: fast-job-local

- Result: pass

Ran `bats kit/tests/` at HEAD (22061912d1dcb5708ad8cd4ae20434423c3b693d): **1568/1568 ok, 0 failures**.
Devshop-self-mode: bats is the deterministic test gate (not turbo). Suite also
passed on every pre-commit and during Phase 2.5 verification at this same HEAD.

## Dismissals

None

## Audit 1: pre-ship (2026-05-29)

<!-- audited-at: 22061912d1dcb5708ad8cd4ae20434423c3b693d -->
<!-- range: origin/main..HEAD -->

findings: high=0 medium=0 low=0

Tracker-only change (`.gitignore`, `PLAN.md`, `kit/FRICTION-LOG.md`,
`kit/TODOS.md` + this feature's own `specs/` artifacts). No source, scripts,
hooks, SKILL.md, template, or `.devcontainer` surfaces — the carve-out class
that `/ak-docs-review § Section A` + the docs-coverage hooks already exempt and
that owes no new test coverage. Both Layer-2 reviews returned clean.

### Docs findings

- (none)

### Tests findings

- (none)

### Bypass trailer audit

- (none)

## Phase 3 → 4 advance log

### 2026-05-29T20:09:19Z — Gate 7: /cso

**Gate:** Gate 7: /cso
**Reason:** devshop-self-mode — gate structurally inapplicable; no auth boundary, no RLS, no third-party APIs
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T20:09:19Z -->

### 2026-05-29T20:09:19Z — Gate 8: /design-review

**Gate:** Gate 8: /design-review
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T20:09:19Z -->

### 2026-05-29T20:09:19Z — Gate 9: /qa

**Gate:** Gate 9: /qa
**Reason:** devshop-self-mode — gate structurally inapplicable; no UI surface; bats invariants run in Gate 2d
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T20:09:19Z -->

### 2026-05-29T20:09:19Z — Gate 10: /benchmark

**Gate:** Gate 10: /benchmark
**Reason:** devshop-self-mode — gate structurally inapplicable; no perf surface
**Follow-up tracker:** n/a — structural; no tooling gap to close

<!-- adversarial-review-stamp: blockedGateOverride STRUCTURAL @ 2026-05-29T20:09:19Z -->

## Audit 2: manual (2026-05-29)

<!-- audited-at: cdee79006695146fb2fd22b475501b9f7603e1d5 -->
<!-- range: 8aa012c242878900dedf80b76b7d3c24d8d3c394..cdee79006695146fb2fd22b475501b9f7603e1d5 -->

findings: high=0 medium=0 low=2

(/ak-merge-devshop Phase 1.1 re-audit over the full rebased branch range. Both
low findings were pre-existing stale "Edit target" path pointers carried verbatim
from the old kit/TODOS.md entries into kit/FRICTION-LOG.md — **both fixed in the
same commit as this audit record** (see Docs findings).)

### Docs findings

- [low] kit/FRICTION-LOG.md (ls-remote entry) — Edit-target path `.claude/skills/devshop/clean-branches/SKILL.md` does not resolve → corrected to `.claude/commands/ak-clean-branches.md`. FIXED.
- [low] kit/FRICTION-LOG.md (visual-evidence entry) — Edit-target path `kit/docs/guide/adversarial-review.md` does not resolve → corrected to `kit/docs/guide/hooks.md § Adversarial review`. FIXED.

### Tests findings

- (none)

### Bypass trailer audit

- (none)
