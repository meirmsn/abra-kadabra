### [domain: docs] [section: A] [severity: medium]

**File**: kit/hooks/bats-format-progress (new) + .husky/pre-commit
**What**: Commit a78640f touches `kit/hooks/**` (new bats-format-progress formatter + .husky/pre-commit rewrite) without updating `kit/docs/guide/hooks.md` or `CLAUDE.md`. Bypass trailer claims "no hook contract change" but the commit adds a new file under `kit/hooks/` and rewrites the bats invocation shape in `.husky/pre-commit` (from awk-based progress to `--formatter` + `--report-formatter tap` dual-output). `hooks.md` step 5 still describes plain `bats kit/tests/` with no mention of the custom formatter or dual-output shape.
**Why**: Coverage gap — a future reader of `hooks.md` step 5 won't know about the custom formatter, the `--report-formatter tap` secondary output, or the `bats-format-progress` file's existence.
**Fix**: Add a parenthetical or sub-bullet to `hooks.md` step 5 (line 136) noting the custom progress formatter (`kit/hooks/bats-format-progress`) and the dual-output mode. One sentence suffices.

### [domain: docs] [section: A] [severity: medium]

**File**: a78640f (kit/hooks/bats-format-progress), 7a132f8 (template/supabase/seed.sql + kit/manifest.txt), ca42f4d (kit/scripts/preship/supabase-bootstrap.sh)
**What**: Three commits touch propagation-relevant surfaces (`kit/hooks/**`, `template/**`, `kit/manifest.txt`, `kit/scripts/**`) without an `**Existing projects:**` block in their commit bodies. Per `kit/docs/guide/conventions.md § Existing-Project Migration Block`, every devshop commit that touches a propagation-relevant surface requires the block even when the answer is "no migration needed".
**Why**: Missing migration-block coverage. Specifically: (1) `a78640f` adds `kit/hooks/bats-format-progress` (symlinked into projects via `.devshopkit/`) — projects get it automatically, but the block should say so; (2) `7a132f8` adds `template/supabase/seed.sql` as `[scaffold-once]` — existing projects won't get it from `from-devshop.sh`; the block should provide a per-project migration recipe; (3) `ca42f4d` modifies `kit/scripts/preship/supabase-bootstrap.sh` (symlinked) — projects get it automatically, block should confirm.
**Fix**: Amend convention compliance in a follow-up commit or note in `kit/TODOS.md`. Most urgently, `7a132f8`'s `[scaffold-once]` seed.sql needs a migration recipe telling existing projects to copy the template seed into their `supabase/seed.sql` and run `pnpm db:reset`.

### [domain: docs] [section: B] [severity: medium]

**File**: .claude/skills/devshop/build/SKILL.md:533
**What**: Stale forward-reference within a diff-touched file. Line 533 says "Phase 7 uses Detail in the ready-for-review comment" but the same diff (commit c4db7c4) removes the Phase 7.2 ready-for-review comment entirely, replacing it with terminal-only output at Phase 7.2 (now titled "Print the handoff to the terminal"). The routing claim no longer matches the SKILL.md's own Phase 7 section.
**Why**: Adequacy — a reader following the Product update routing chain hits a dangling forward-reference to a feature the same file removed.
**Fix**: Update line 533 to remove the "Phase 7 uses Detail in the ready-for-review comment" clause. The routing chain is now: Phase 4.1 (PR body) + Phase 5.6 (BUILD-LOG) + `/ak-go-live` Step 6 (deploy comment).

### [domain: docs] [section: C] [severity: medium]

**File**: kit/docs/guide/workflow.md:297
**What**: Cross-doc stale reference. workflow.md line 297 describes Phase 7 as posting "a ready-for-review comment" and says it "leads with `spec.md § Product update § Detail` verbatim". The SKILL.md diff removes this comment (Phase 7.2 now says "No 'Ready for review' comment — the PR being open IS the notification"). workflow.md was not updated.
**Why**: Coherence — workflow.md's Phase 7 description contradicts the SKILL.md's new Phase 7 behavior. A reader consulting workflow.md would expect a PR comment that no longer gets posted.
**Fix**: Rewrite workflow.md line 297 to match the new behavior: Phase 7 prints a terminal handoff only; no PR comment is posted.

### [domain: docs] [section: C] [severity: medium]

**File**: kit/docs/guide/workflow.md:285
**What**: Cross-doc stale reference. workflow.md line 285 (Phase 4.1 description) says "Phase 7 uses Detail in the ready-for-review comment" as part of the downstream routing chain. This routing claim is now stale.
**Why**: Coherence — same root cause as the workflow.md:297 finding; the routing chain description in the Phase 4.1 paragraph also references the removed comment.
**Fix**: Remove the "Phase 7 uses Detail in the ready-for-review comment" clause from the routing chain at line 285.

### [domain: docs] [section: C] [severity: medium]

**File**: kit/docs/guide/conventions.md:441,493
**What**: Cross-doc stale references. conventions.md line 441 says "Phase 7 ready-for-review comment" in the product-update routing description, and line 493 has a routing table row "Phase 7 ready-for-review comment | Detail". Both reference a feature removed by the SKILL.md diff. conventions.md was not touched.
**Why**: Coherence — the canonical Product update routing table in conventions.md lists a downstream surface that no longer exists.
**Fix**: Delete the "Phase 7 ready-for-review comment" row from the routing table at line 493, and remove the corresponding clause from the prose at line 441.

### [domain: docs] [section: C] [severity: low]

**File**: kit/docs/guide/workflow.md:312
**What**: Cross-doc stale reference. workflow.md line 312 (`/ak-go-live` pending-tasks pre-flight) references `## Pre-ship audit trail` and `## Ready for review` as comment headings to parse. The SKILL.md diff renamed the audit comment heading from `## Pre-ship audit trail` to `## Pre-ship audit` and removed the `## Ready for review` comment entirely.
**Why**: Coherence — `/ak-go-live`'s pre-flight description references two PR comment headings that no longer match the shapes the SKILL.md now produces.
**Fix**: Update workflow.md line 312 to reference `## Pre-ship audit` (new heading) and remove the `## Ready for review` reference.

### Section D — Bypass trailer audit

Six `Docs-Coverage-Bypass:` trailers harvested in range:

1. **a78640f** — "guide/hooks.md (no hook contract change — setsid is a test fix, not a hook behavior change)": **ESCALATE** — the commit adds a new file (`kit/hooks/bats-format-progress`) and rewrites `.husky/pre-commit`'s bats invocation from awk-piped TAP to `--formatter`+`--report-formatter` dual-output. This is more than "a test fix"; the hook's observable output shape changed. Already captured as Section A finding above.
2. **7a132f8** — "architecture.md already documents the scaffold-once lifecycle; ops.md already documents the seed shape requirement": **VERIFIED** — both cross-references confirmed (architecture.md line 87 covers `[scaffold-once]`; ops.md line 222 covers the template seed pattern). The bypass is valid for doc coverage but the missing `**Existing projects:**` block is a separate Section A finding.
3. **ca42f4d** — "guide/ops.md references the script's output shapes but not its internal verification strategy — the fallback is an implementation detail": **VERIFIED** — ops.md line 211 references the script's output shapes; the GoTrue admin API fallback is internal.
4. **c4db7c4** — SKILL.md edits (Phase 3.0 preflight, Phase 4.1 body, Phase 6 audit, Phase 7 comment removal): **DEFER** — bypass claims "guide/workflow.md does not reference these PR body sections" but workflow.md DOES reference the ready-for-review comment behavior (line 297) and the routing chain (line 285). Cross-doc coherence findings already captured in Section C.
5. **195c2df** — SKILL.md Phase 4.1 forbidden-section check: **VERIFIED** — mechanical gate; no guide doc references the verification block's grep patterns.
6. **e14fd42** — test-only changes: **VERIFIED** — kit/tests/ carve-out applies.

### Section E — CLAUDE.md hygiene

Devshop mode — Section E skipped per skill spec (project mode only).
