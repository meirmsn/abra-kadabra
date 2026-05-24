## Gate 5: docs-and-tests-review

<!-- audited-at: be6cc95eaadc6da5ec79e3662e0a394b82f7808f -->

**Outcome: findings**

findings: high=0 medium=1 low=1

Commit range: `origin/main..HEAD` (5 commits). Audited 2026-05-24.

---

### Docs coverage

1. **[medium] `ops.md` GH Variables table missing `SUPABASE_PROD_ANON_KEY` row.** The canonical env-var lookup table at `kit/docs/guide/ops.md` lines 118-125 lists `SUPABASE_PROD_URL` but omits `SUPABASE_PROD_ANON_KEY`. The keepalive workflow now depends on this variable (`vars.SUPABASE_PROD_ANON_KEY` in the Ping Supabase step). The variable is already documented in `/ak-new-project` SKILL.md (line 694), but ops.md is the canonical "which GH Variables exist and what they mean per surface" index -- operators looking up variable requirements will miss it. Pre-existing gap widened by this diff (previously only deploy-adjacent; now also keepalive).

   **Fix**: Add a `SUPABASE_PROD_ANON_KEY` row to the ops.md table between `SUPABASE_PROD_URL` and `SENTRY_DSN`, with columns: `prod anon key (keepalive + deploy)` | `_(piped to NEXT_PUBLIC_SUPABASE_ANON_KEY at Step 13)_` | description matching the existing `SUPABASE_PROD_URL` row pattern.

2. **ops.md line 398 (`PRODUCTION_URL` used by `keepalive.yml`)** -- still accurate. The existing Vercel ping step retains `vars.PRODUCTION_URL`. No update needed.

3. **security.md line 91 ("deploy workflows consume `SUPABASE_PROD_URL`")** -- still technically accurate (scoped to "deploy workflows"). The keepalive workflow is not a deploy workflow; it consumes `SUPABASE_PROD_URL` + `SUPABASE_PROD_ANON_KEY` for a health-check ping, not for deployment. No update required, but the medium finding above (ops.md table) is the right place to close the documentation gap.

4. **No other guide docs reference keepalive behavior that would be stale from this diff.** `notifications.md` line 72 uses "keep alive" in a different context (Safari PWA). CLAUDE.md has no keepalive references.

### Tests coverage

5. **9 bats assertions adequately pin the new behavior.** Coverage map:
   - File existence (test 1)
   - Cron schedule value (test 2)
   - Both step names present (tests 3, 4)
   - Prod-specific variable names used (tests 5, 6)
   - Correct PostgREST endpoint path (test 7)
   - Warning emission scoped to Supabase step block (test 8)
   - Step ordering (test 9)

   All 9 pass. No missing structural assertions identified for the scope of changes.

### Test quality

6. **[low] Tests 5-6 verify positive case only despite promising negative.** Test names say `(not vars.SUPABASE_URL)` and `(not vars.SUPABASE_ANON_KEY)` but the assertions only `grep -q` for the correct variable name -- they do not assert the absence of the wrong name. A regression where someone adds BOTH variable names would pass. Unlikely in practice (the wrong name would be a second curl invocation pointing at localhost), and the positive assertion is the load-bearing one. Cosmetic gap.

7. **Test 8 correctly scopes `::warning::` grep to the Supabase step block** using sed range extraction, avoiding false-positive matching from the production step. Good technique.

8. **Test 9 (step order) uses line-number comparison** -- meaningful structural assertion, not just pattern matching.

9. **All tests are pure file-content checks** (no real GitHub Actions runner, no network). Matches the `template-ci-yml-shape.bats` reference pattern. Deterministic and fast.

---

## Dismissals

None
