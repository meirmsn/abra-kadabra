### [domain: docs] [section: A] [severity: medium]
**File**: (commit) 4d33ca1 — template/apps/web/next.config.ts
**What**: Commit touches a propagation-relevant surface (`template/**`) but its body carries no `**Existing projects:**` migration block.
**Why**: Per `kit/docs/guide/conventions.md § Existing-Project Migration Block`, any commit touching `template/**` must carry the block even when no migration is needed — the "no migration needed" variant tells the reader the author considered the question. The body says "Comment-only, no behavior change" but does not use the canonical block shape; a reader scanning for the block on a template-touching commit finds none.
**Fix**: Low-stakes here (comment-only header edit; template still ships no CSP block, so there is genuinely nothing for existing projects to migrate). Acceptable to leave for this docs-only feature, but the canonical fix at squash time is to add to the `/ak-merge-devshop` squash body: `**Existing projects:** template/apps/web/next.config.ts change is a comment-only header touch-up; the template ships no CSP block. No project-side migration needed.` The squash-surface hygiene reviewer (Phase 0.4.5) will require this block since the squash diff touches `template/**` — so it gets caught and satisfied there regardless.

### [domain: docs] [section: B] [severity: low]
**Why**: Adequacy — VERIFIED. The `conventions.md § CSP` sub-section names the symptom (blank `<img>`, CSP report only, no thrown error), the root cause (strict scheme matching; `https:` token does not cover the local-stack `http` origin), and the mitigation (derive every Supabase-bound directive from the trimmed `$NEXT_PUBLIC_SUPABASE_URL`, compute once). The `supabase-ssr-boilerplate.md § Pattern 2` body + code excerpt is substantive: the spread-IIFE returning `string[]` correctly computes `supabaseUrl`/`supabaseWs` once and emits both `connect-src` and `img-src` from the same origin, with a load-bearing comment warning against deleting the appended `${supabaseUrl}`. Not a stub edit. (Recorded as low/informational, not a defect.)

### [domain: docs] [section: C] [severity: low]
**Why**: Cross-doc coherence — VERIFIED. The heading rename (`Pattern 2: CSP connect-src builder handles BOTH https→wss and http→ws` → `Pattern 2: CSP connect-src and img-src builders derive from the Supabase origin`) was repointed everywhere: the in-doc Contents TOC, the routing-index anchor in `README.md` (new slug `#pattern-2-csp-connect-src-and-img-src-builders-derive-from-the-supabase-origin` matches the GitHub slug of the renamed heading exactly), and the template header cross-ref. A repo-wide grep for the OLD anchor slug (`pattern-2-csp-connect-src-builder-handles-both`) returns zero hits across `kit/docs/` and `.claude/skills/` — no dangling references. The `conventions.md § CSP` cross-ref `§ Pattern 2` resolves. No contradiction with non-touched reference docs. (Recorded as low/informational, not a defect.)

### [domain: docs] [section: D] [severity: low]
**Why**: No `Docs-Coverage-Bypass:` trailers in range. Nothing to escalate.

### [domain: docs] [section: E] [severity: n/a]
**Why**: CLAUDE.md hygiene (Section E) is project-mode only; this is devshop self-mode (`$GIT_ROOT == /devshop`). Skipped per the skill's mode gate. CLAUDE.md was not touched by the feature range.

---
Note on range: orchestrator default `origin/main..HEAD` was polluted because `origin/main` (1d343bf) advanced past this branch's merge-base (b174a11) — `1d343bf` is the unrelated commit also responsible for the known pre-existing bats failure. The audit was scoped to the true feature range `b174a11..HEAD` (merge-base..HEAD), which isolates the 7 CSP-feature files. Findings above are against that clean range.

docs summary: high=0 medium=1 low=0
