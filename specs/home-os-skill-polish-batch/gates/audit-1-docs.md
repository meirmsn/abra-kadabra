### [domain: docs] [section: A] [severity: medium]
**File**: kit/docs/guide/hooks.md:198
**What**: New SHA-enumeration short-circuit on the project-mode PR-text-hygiene check (added in `kit/hooks/pre-push.sh` lines 119-152) is undocumented in the canonical pre-push contract. § 3 (Husky pre-push) line 187 still describes the check as fired "on every non-trivial push," and the "Short-circuits" subsection at lines 198-202 lists exactly 3 short-circuits (detached HEAD / branch deletions / devshop-main / project trivial-commit) — the new "PR body enumerates every commit SHA (full or ≥7-char abbrev) → PASS without LLM call" path is not in the list.
**Why**: hooks.md is the canonical reference for "when does pre-push block, when does it pass" — an operator reading the contract today would not be able to predict the actual behavior (a non-trivial push with a fresh PR body now passes silently without the adversarial review the doc says fires). New short-circuits in load-bearing gates belong in the contract.
**Fix**: Add a fourth bullet under § 3 "Short-circuits" enumerating the SHA-enumeration fast-path (project-mode; non-trivial push; PR body contains every `origin/main..HEAD` commit SHA as full or ≥7-char abbreviation; PASS without invoking `adversarial-review.sh prTextHygieneReason`). Also append a one-line note to the "PR text hygiene" row in the project-mode table at line 187 ("Fast path: PR body enumerating every commit SHA short-circuits the LLM call — see § Short-circuits"). Cross-reference `kit/tests/util-pre-push.bats § B3` for the test coverage that pins the contract.

### [domain: docs] [section: B] [severity: low]
**File**: specs/home-os-skill-polish-batch/spec.md:48,97,99,202,243,256,269
**What**: Spec.md uses "Step 12.5" throughout (Product update body, D3 decision, file table, task order, gotchas, acceptance grep) but the actual implementation landed at "Step 12.6" (per commit `8b7c2b3` body: "Step 12.6 chosen instead of '12.5' (the spec's wording) because Step 12.5 already exists in SKILL.md (Supabase SSR boilerplate)"). All four cross-ref doc updates (CLAUDE.md, FAQ.md, architecture.md, conventions.md) correctly point at Step 12.6.
**Why**: spec.md is the permanent record of what was decided + what shipped; future readers tracing the home-os-skill-polish-batch row from PLAN.md to spec to commit will see a "Step 12.5" claim that contradicts the live skill (which has a pre-existing Step 12.5 for Supabase SSR boilerplate at line 975 and a new Step 12.6 at line 988 for the docs-fill). The commit message captures the rationale but the spec's body / table / acceptance grep all retain the stale number.
**Fix**: One-pass `sed -i 's/Step 12.5/Step 12.6/g' specs/home-os-skill-polish-batch/spec.md`, then re-verify the acceptance grep at line 269 still describes the closure verification correctly (the grep itself looked for "Step 18" — those hits are now Step 12.6 / Step 12.5 distinct). Per § Closing TODO / ROADMAP entries when a fix ships, the spec should reflect the as-shipped state, not the as-planned state.

### [domain: docs] [section: D] [severity: low]
**File**: (none — range-level finding)
**What**: No `Docs-Coverage-Bypass:` trailers in range. Harvest legitimately returns zero rows.
**Why**: N/A — informational.
**Fix**: No action.
