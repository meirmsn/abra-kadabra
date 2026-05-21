# Audit 1 — Docs review

**Range**: `origin/main..HEAD` (1 commit, `8d72c61`)
**Feature dir**: `specs/dcg-investigation-findings`
**Mode**: devshop self (`$GIT_ROOT` = `/devshop/.worktrees/dcg-investigation`, devshop worktree)

## Scope of diff

Single file: `kit/TODOS.md` (+16 -6). One TODO entry updated — the
DCG `core.git:push-force-short` investigation entry. The diff replaces the
"Investigation goal" subsection with completed findings (extracted regex,
named root cause, upstream repo URL, reordered fix candidates with the
upstream patch promoted to option (a)) and rewrites the closing codification
line to add the `session-followups` session as a co-source.

## Section A — Coverage

`kit/TODOS.md` is in the explicit no-firing carve-out list (per skill rubric:
"Carve-outs (no firing): kit/notes/**, kit/ROADMAP.md, **kit/TODOS.md**,
kit/docs/CHANGELOG.md, kit/version, kit/tests/**, kit/docs/** itself"). No
source code, hook, script, skill, or template surface touched. Coverage
trigger does not fire. **No coverage findings.**

## Section B — Adequacy

The entry is substantive — not a stub. Specifically:

- **Named mechanism with empirical verification** (per the new
  `session-followups` rubric the diff itself codifies elsewhere). The entry
  cites a specific extraction method (`strings /usr/local/bin/dcg`), names
  the upstream repo (`Dicklesworthstone/destructive_command_guard`), and
  prints the regex shape (`git\s+(?:\S+\s+)*push\s+.*-f\b`). Auditor ran
  the verification:
  - `gh repo view Dicklesworthstone/destructive_command_guard` → returns
    repo with description "The Destructive Command Guard (dcg) is for
    blocking dangerous git and shell commands from being executed by
    agents." URL is real.
  - `strings /usr/local/bin/dcg | grep push-force` → confirms
    `push-force-long` regex literally `git\s+(?:\S+\s+)*push\s+.*--force(?![-a-z])`
    and `push-force-any` regex literally
    `git\s+(?:\S+\s+)*push\s+.*(?:--force|--force-with-lease|-f\b)` —
    both match TODOS.md verbatim. `push-force-short` token is present
    in the binary; the inferred `.*-f\b` shape is structurally identical
    to the two siblings (TODOS.md correctly hedges with "approximately").
  - `dcg test 'git push origin main && rm -f /tmp/x.txt'` → BLOCKED
    (false-positive minimal reproducer reproduces as documented).
  - `dcg test 'git push -f origin main'` → BLOCKED (true positive holds).
  - `dcg test 'git push origin --delete fix/x'` → ALLOWED (non-force
    command correctly unaffected).
- **Cross-references resolve**: `/ak-merge-devshop § Phase 4.2` cited as
  the workaround host is present in `.claude/skills/devshop/merge-devshop/SKILL.md`
  line 57 + line 999 (the "DCG `push-force-short` false-positive on
  chained `-f` flags" callout). Citation valid.
- **Fix candidates are actionable**: option (a) names the exact patch
  (`.*` → `[^;&|\n]*`), the three target rule names, and the verification
  matrix; option (b) names the proposed script path + the hook-chain
  restructuring blocker; option (c) names the revisit trigger.
- **No stub edits**: every changed line carries new information; no
  whitespace-only / link-reflow churn.
- **No dangling references**: no new section headings asserted that don't
  exist; the binary path `/usr/local/bin/dcg` is real (`which dcg`
  confirms).

**No adequacy findings.**

## Section C — Cross-doc coherence

- No renamed or deleted files in range — no stale-path sweep needed.
- The entry's claim that `push-force-short` false-positives on chained
  `-f` flags is consistent with the existing `merge-devshop` SKILL.md
  line 999 callout, the `/ak-merge-devshop` description in
  `kit/docs/guide/workflow.md` line 477 ("Phase 4.2's teardown runs as
  separate Bash calls per step to dodge DCG's `push-force-short`
  false-positive on chained `-f` flags"), and CLAUDE.md's gstack
  third-party-upstream-wrapper pattern (option (b) explicitly applies
  the "design a devshop-side wrapper" recipe to dcg, modulo dcg's
  PreToolUse position).
- The entry's assertion that "in-place patching the binary is not viable"
  (DCG ships as a stripped ARM ELF) is consistent with what `which dcg`
  + `file` would show on the installed binary — no contradiction with
  any other doc.

**No coherence findings.**

## Section D — Bypass trailer audit

`git log --format='%B' origin/main..HEAD` → no `Docs-Coverage-Bypass:`
trailers in range.

No Docs-Coverage-Bypass trailers in range.

## Section E — CLAUDE.md hygiene

Skipped — devshop self-mode. (Per skill rubric: "Mode: project (skip in
devshop mode).")

## Verdict

Clean — no docs findings.

high=0 medium=0 low=0
