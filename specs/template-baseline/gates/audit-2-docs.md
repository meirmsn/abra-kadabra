### [domain: docs] [section: C] [severity: low]
**File**: .claude/skills/devshop/new-project/SKILL.md:822
**What**: Step 12 narrative paragraph still reads "Supabase SSR middleware with Pattern 1 `.trim()` defense" — names "middleware" as the architectural component shipped by the template. Three paragraphs later (line 855) the same skill now correctly identifies the file as `proxy.ts` ("rename of `middleware.ts`"). The closure-fix commit (220ccad) addressed 855 + 1390 but did not sweep this earlier occurrence in the Step 12 framing paragraph.
**Why**: Borderline ambiguity, not load-bearing contradiction — "middleware" here can be read as the architectural role (the Next.js edge layer concept) which legitimately lives in `proxy.ts`. But the closure-protocol convention (`conventions.md § Closing TODO / ROADMAP entries when a fix ships`) mandates unwinding EVERY cross-reference, and the commit message for 220ccad asserts "this commit closes the four" — the implicit claim is the rename PR's cross-ref unwind is complete. An operator reading Step 12 top-down hits "Supabase SSR middleware" first and may expect a `middleware.ts` file; the disambiguation at 855 lands two paragraphs later. Severity stays `low` because the file name is clarified in the same step, but flagging for completeness so the operator can decide whether to (a) tighten 822 to "Supabase SSR proxy" / "Supabase SSR edge layer", or (b) accept the role-vs-file distinction as good-enough and leave 822 alone.
**Fix**: Optional. If tightening, replace "Supabase SSR middleware with Pattern 1 `.trim()` defense" with "Supabase SSR proxy (`proxy.ts`) with Pattern 1 `.trim()` defense". If accepting, no edit needed and this finding can be dismissed at the next pre-ship gate.

### [domain: docs] [section: C] [severity: low]
**File**: kit/docs/guide/hooks.md:150
**What**: `check-docs-coverage-project.sh` row in `## Layer 1 vs Layer 2` table still lists `middleware.ts` as the Always-loaded trigger filename — should be `proxy.ts` (or `proxy.ts` / `middleware.ts` for transition projects). Same shape as the audit-1 medium finding on `kit/docs/guide/conventions.md:747` (which the operator explicitly deferred), but this row was not flagged in audit-1 and was not touched by the closure-fix commit (220ccad).
**Why**: This is the partner-doc to the deferred conventions.md:747 trigger row — `hooks.md § Layer 1 vs Layer 2` table is the operator's quick-reference for what each pre-commit hook checks, and the trigger globs here must agree with the script's actual behavior + the conventions.md source-of-truth. The operator's deferral of conventions.md:747 implicitly applies to this row too (same class of fix; both are project-side coverage-trigger doc references), so flagging at `low` rather than `medium` to mirror the deferral intent. If/when the operator picks up the conventions.md medium, this row should be fixed in the same commit.
**Fix**: Replace `apps/*/app/**/page.tsx / layout.tsx / route.ts / middleware.ts` with `apps/*/app/**/page.tsx / layout.tsx / route.ts / proxy.ts / middleware.ts` (matches the post-closure shape already on `kit/docs/guide/README.md:106`). One-line edit; co-ship with the conventions.md:747 fix when the operator picks it up.

### [domain: docs] [section: D] [severity: low]
**File**: (range-wide bypass trailer harvest)
**What**: No `Docs-Coverage-Bypass:` or `CLAUDE-MD-Bypass:` trailers in range.
**Why**: The closure-fix commit (220ccad) called out the 2 deferred medium findings in its commit body prose rather than via the formal bypass-trailer mechanism. Acceptable — the prose record is durable in `git log` and the deferral rationale is explicit ("operator chose 'just the 4 high' for this re-audit cycle"). Recorded for completeness; no escalation.
**Fix**: None. Future deferrals could use the formal trailer for machine-harvestability, but prose-in-commit-body is equivalent for audit-trail purposes when the deferred-finding set is small + explicitly enumerated.

---

**Audit-1 closure verification** (informational, not a finding):

- ops.md:26 (audit-1 high #1) — CLOSED. Now reads `apps/web/proxy.ts (Supabase SSR session check; renamed from middleware.ts in Next 16)`.
- README.md:51, 55, 73, 106 (audit-1 high #2) — CLOSED. All four lines now use `proxy.ts (or legacy apps/web/middleware.ts)` transitional shape; Pattern-8 anchor link at line 73 regenerated to `pattern-8-proxy-allow-list-authed-bypass-carve-out-for-recovery-flows` (matches the renamed heading in supabase-ssr-boilerplate.md).
- SKILL.md:854, 1388 (audit-1 high #3) — CLOSED. Line 855 (was 854) now reads "proxy.ts — the Next 16 rename of middleware.ts"; line 1390 (was 1388) now reads "apps/web/proxy.ts (or legacy apps/web/middleware.ts)". Note: a third occurrence at line 822 was missed — flagged as the first audit-2 finding above.
- next.config.ts:10 (audit-1 high #4) — CLOSED. `// Does NOT:` header now correctly states CSP headers belong in THIS file via the Pattern 2 connect-src builder, fixing both stale claims (wrong filename + wrong file role).

**Section A coverage**: The closure-fix commit (220ccad) is a pure cross-ref unwind — no new behavior, no new surfaces. Coverage rubric does not fire (the `.claude/skills/**/SKILL.md` → workflow.md OR CLAUDE.md trigger and `template/**` → architecture/security/ops trigger both apply to behavior-introducing changes; this commit only edits prose to match already-shipped files). No new Section A findings.

**Section B adequacy**: All four audit-1 closure edits are substantive — they replace stale paths with correct paths, preserve transitional shape where it aids migration (proxy.ts / middleware.ts both listed where readers may be on either side), and regenerate one URL anchor that the rename broke. No stub-edit findings.

**Section E**: devshop mode — skipped per skill instructions (CLAUDE.md hygiene gate is project-mode-only).
