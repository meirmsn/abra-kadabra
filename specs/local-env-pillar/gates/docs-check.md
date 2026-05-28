## Gate 1: docs-check

- Result: pass

### Checklist

1. **New scripts documented in conventions.md** -- `local-env-health.sh` has a dedicated subsection at `kit/docs/guide/conventions.md` line 262 under "Local Pre-Push Test Gates". `roster-check.sh` and `check-llm-mediated-na.sh` are internal SKILL.md mechanisms (no direct operator invocation), documented inline in `SKILL.md` at their call sites. This matches the existing pattern: `supabase-bootstrap.sh`, `advisor-clean.sh`, etc. are documented at their appropriate level.

2. **SKILL.md wiring internally consistent** -- All three script invocations in SKILL.md match the actual script interfaces:
   - `local-env-health.sh check` / `recover` matches the script's `case` dispatch (line 250).
   - `roster-check.sh <preflight-sink> <gates-dir> <hero-dir>` matches the 3-arg signature (line 25-28).
   - `check-llm-mediated-na.sh <review.md path>` matches the 1-arg signature (line 27).

3. **migrations.md addition properly structured** -- TOC entry at line 16 links correctly to `## Cross-migration FK rollback patterns` at line 298. Four patterns documented with SQL examples. Cross-reference to the existing "Postgres enum extension" section is implicit via TOC proximity.

4. **No stale cross-references** -- The deleted ROADMAP entry ("Local environment as the single verification surface") has zero remaining references in kit/, CLAUDE.md, or .claude/. The deleted TODOS entry ("Codify regression coverage for /ak-build Phase 3->4 LLM-mediated-n/a awk halt grep") has zero remaining references. Both confirmed via grep.

5. **hooks.md / workflow.md** -- Neither file referenced the roster check or inline awk block before; no updates needed. The new scripts are operational internals of SKILL.md Phase 3, not hook-layer or workflow-layer concepts.

## Dismissals

None
