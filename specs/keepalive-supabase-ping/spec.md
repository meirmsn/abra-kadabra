<!-- generated-by: /ak-build Phase 0 (skeleton — /ak-spec will expand) -->
<!-- feature: keepalive-supabase-ping -->
<!-- date: 2026-05-24 -->

# Spec: keepalive-supabase-ping

**Sources:**

- `kit/TODOS.md` § Keepalive workflow pings Vercel but not Supabase — primary scope
- `template/.github/workflows/keepalive.yml` — canonical edit target
- Prior spec `specs/sync-show-first-confirm/spec.md` — style/structure reference

Template keepalive workflow pings Supabase PostgREST directly and runs twice weekly, preventing free-tier auto-pause on quiet projects.

---

## Product update

### Headline (user-facing)

Keepalive workflow now pings Supabase directly and runs twice weekly, preventing auto-pause on quiet projects.

### Detail (team-facing)

Template `keepalive.yml` gains a second step that hits the Supabase PostgREST health endpoint (`/rest/v1/`) with the anon key, registering as API activity. Cron bumped from weekly to twice-weekly (Mon + Thu) for margin against Supabase's 7-day inactivity window. Existing Vercel ping retained.

---

## Decisions (resolved at spec time)

3 `/ak-spec`-time decisions resolved in Phase 0 with the user. Recorded below
so Phase 1 preserves them verbatim and a crashed Phase 1 resumes without
re-asking.

### D1: Which Supabase endpoint to ping

**Decision:** PostgREST health endpoint (`/rest/v1/`) with anon key.

**Rationale:** Minimal permissions; any 2xx registers as API activity on Supabase's inactivity tracker. The anon key is public-tier (not secret material).

### D2: Cron frequency

**Decision:** Twice-weekly: `0 9 * * 1,4` (Monday + Thursday at 09:00 UTC).

**Rationale:** Single missed Monday under the old weekly schedule leaves zero margin against Supabase's 7-day inactivity window. Mon + Thu spreads the pings ~3-4 days apart, tolerating one missed run.

### D3: Supabase credentials storage

**Decision:** GitHub Variables named `SUPABASE_PROD_URL` and `SUPABASE_PROD_ANON_KEY` (not Secrets, and not the CI-scoped `SUPABASE_URL`/`SUPABASE_ANON_KEY` which point at localhost for test isolation).

**Rationale:** The anon key and URL are public/anon-tier — not secret material. Variables are simpler to configure and visible in logs for debugging. Must use prod-specific names because `vars.SUPABASE_URL` is set to `http://127.0.0.1:54321` for CI credential isolation (per CLAUDE.md § CI Credential Isolation); the keepalive runs on a bare runner with no local stack.

---

## Core user story

N/A — CI workflow template change; no user flow added or modified.

---

## In scope

1. **Add a Supabase PostgREST ping step** to `template/.github/workflows/keepalive.yml`:
   - New step after the existing "Ping production" step.
   - `curl -s -o /dev/null -w "%{http_code}" "${{ vars.SUPABASE_PROD_URL }}/rest/v1/" -H "apikey: ${{ vars.SUPABASE_PROD_ANON_KEY }}"`.
   - Emit `::warning::` on non-2xx status (same pattern as the existing Vercel ping step).
   - Step name: `Ping Supabase`.

2. **Bump cron schedule** from `0 9 * * 1` (weekly Monday) to `0 9 * * 1,4` (twice-weekly Monday + Thursday).

3. **Retain the existing Vercel ping step** unchanged — it is still useful for detecting Vercel-side outages.

4. **Update the cron comment** to reflect the new schedule: `# Every Monday and Thursday at 9am UTC`.

## Out of scope

- Existing project `.github/workflows/keepalive.yml` files (home-os, lalista) — those are scaffold-once files not auto-synced. The TODOS entry already documents them as separate edit targets; they will be updated via `/ak-build` from each project's worktree or manually.
- Supabase auth/management API pings — PostgREST is sufficient to register API activity.
- Alerting or notification on ping failure — `::warning::` annotation is adequate for keepalive.

## Files to create/modify

| File | Action | What changes |
| ---- | ------ | ------------ |
| `template/.github/workflows/keepalive.yml` | modify | Add `Ping Supabase` step; bump cron to `0 9 * * 1,4`; update comment |
| `kit/tests/template-keepalive-yml-shape.bats` | create | Structural assertions for the keepalive workflow |

## Tests

Bats test file: `kit/tests/template-keepalive-yml-shape.bats`

Assertions (following the `template-ci-yml-shape.bats` pattern — pure file-content checks, no real runner):

1. **`template keepalive.yml exists`** — file presence guard.
2. **`cron schedule is twice-weekly (Mon + Thu)`** — grep for `0 9 * * 1,4`.
3. **`Ping production step exists`** — existing step retained.
4. **`Ping Supabase step exists`** — new step present.
5. **`Supabase ping uses vars.SUPABASE_PROD_URL`** — prod-specific variable, not CI's localhost-scoped `SUPABASE_URL`.
6. **`Supabase ping uses vars.SUPABASE_PROD_ANON_KEY`** — same prod-specific check.
7. **`Supabase ping hits /rest/v1/ endpoint`** — correct PostgREST path.
8. **`Supabase ping emits warning on non-2xx`** — `::warning::` pattern present in the Supabase step.
9. **`step order: Ping production before Ping Supabase`** — line-number ordering assertion (same pattern as `template-ci-yml-shape.bats § canonical order`).

## Gotchas

- **`vars.SUPABASE_PROD_*` not `vars.SUPABASE_*`**: CI's `SUPABASE_URL` points at localhost for test isolation. The keepalive runs on a bare runner — must use prod-specific variable names. D3 already resolves this.
- **Curl `-o /dev/null`**: the PostgREST schema listing response body can be large; discard it. Only the HTTP status code matters for keepalive.
- **Supabase inactivity window is 7 days, not 14**: confirmed from the 2026-05-24 warning email. Mon + Thu spacing (~3-4 days apart) tolerates exactly one missed run.

---

## Task order

1. Update `template/.github/workflows/keepalive.yml` — add Supabase ping step + bump cron schedule
2. Add bats test `kit/tests/template-keepalive-yml-shape.bats` validating the workflow structure
