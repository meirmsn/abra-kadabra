# Migrations

Schema-mutating changes to a Supabase project ride two boundaries: the migration files on disk, and the deploy workflow that pushes them. This guide collects the rules that apply across both — defaults applied at scaffold time, FK-cascade discipline, Realtime publication wiring, and the SSR + E2E patterns codified from production incidents.

## Contents

- [Supabase Hardening Defaults](#supabase-hardening-defaults)
  - [ON DELETE on `auth.users` FK references](#on-delete-on-authusers-fk-references)
  - [Realtime publication setup](#realtime-publication-setup)
  - [SSR + E2E boilerplate canonical patterns](#ssr--e2e-boilerplate-canonical-patterns)

## Supabase Hardening Defaults

What `/ak-new-project` Step 17b applies to every new Supabase project, and why:

| Setting                    | Default (free-tier)     | Hardened                           | Rationale                                                                                                                                                |
| -------------------------- | ----------------------- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `password_min_length`      | 6                       | 8                                  | 6 is below published password-policy floors (NIST 800-63B minimum is 8). Non-breaking for new projects; existing users are grandfathered.                |
| `security_captcha_enabled` | `false`                 | `true` (if secret provided)        | CAPTCHA blocks automated signup abuse (credential stuffing, spam-account creation). Interactive because it needs an hCaptcha secret per project.         |
| `site_url`                 | `http://localhost:3000` | production URL                     | Every email-based auth flow (password recovery, magic link, email change, signup confirm) redirects via `site_url`. Stale `localhost` = silent breakage. |
| `uri_allow_list`           | empty                   | prod + Vercel wildcard + localhost | Supabase rejects auth redirects outside this list. Must include the Vercel preview-deploy wildcard so PR previews can exercise the full auth flow.       |

Not touched (intentional):

- `rate_limit_email_sent` stays at the free-tier default (2/hour). Raising requires custom SMTP (per-project decision, production-launch concern).
- `disable_signup` stays `false`. Invite-code alternative is a separate roadmap item (`kit/ROADMAP.md § v1 § Invite-code signup control`).

### ON DELETE on `auth.users` FK references

Any schema table that references `auth.users(id)` MUST specify the `ON DELETE` action explicitly — `CASCADE`, `SET NULL` (column must be nullable), or `RESTRICT`. Never leave it implicit.

Postgres defaults to `NO ACTION`, which silently blocks user deletion as soon as any dependent row exists. Supabase's Authentication UI surfaces this as the opaque "Database error deleting user" — the operator's only recourse is to go hunt down every FK and delete the dependent rows manually, or change the constraint (which requires DDL, which requires another migration).

Recommended defaults by column meaning:

- **`added_by` / audit columns** → `ON DELETE SET NULL` (preserve history, lose attribution).
- **Tight ownership columns** (row doesn't make sense without the user) → `ON DELETE CASCADE`.
- **Rare case: must keep row AND must have a user** → `ON DELETE RESTRICT` (forces an explicit decision at user-deletion time; worst UX but most explicit).

Every schema reviewer and `/ak-pre-ship` migration gate should reject a migration where a `references auth.users(id)` lacks an explicit `ON DELETE` clause — it's a latent bug, not a design choice.

### Realtime publication setup

Any table that needs cross-session Realtime delivery (`subscribeTo<X>` helpers, `postgres_changes` events) MUST be added to the `supabase_realtime` publication explicitly via a migration:

```sql
alter publication supabase_realtime add table <table_name>;
-- ROLLBACK:
-- alter publication supabase_realtime drop table <table_name>;
```

Older Supabase CLI versions auto-included `FOR ALL TABLES`; newer versions don't always. Without the explicit migration, subscribers stay connected but never receive INSERT/UPDATE/DELETE events from other sessions — the cross-session feature looks like it's working until you actually test it from a second browser/session and notice nothing arrives. Lalista PR 26 surfaced this gap; codified pattern in `kit/docs/guide/supabase-ssr-boilerplate.md § Pattern 4`.

### SSR + E2E boilerplate canonical patterns

For projects scaffolded by `/ak-new-project` with Supabase + Next.js + Playwright, **5 canonical patterns** live in `kit/docs/guide/supabase-ssr-boilerplate.md`. Apply verbatim at scaffold time (Step 12) — each was codified from a real production incident; paraphrasing the patterns silently breaks them. Patterns covered:

1. `.trim()` defense at every `process.env.NEXT_PUBLIC_*` read site (Vercel/GitHub/`.env` whitespace fat-finger defense)
2. CSP `connect-src` builder with `^http(s?)://` → `ws$1://` (handles prod + local-stack symmetrically)
3. E2E `helpers/admin-client.ts` with the 5 canonical exports (`adminClient`, `anonClient`, `userIdFromSignIn`, `isLocalSupabase`, `localSupabaseSkipReason`)
4. Realtime publication setup migration (the rule directly above)
5. WebKit form-state hydration race workaround for Playwright `mobile` E2E tests

**See also:** `kit/docs/guide/conventions.md § Deploy Boundaries` for the migration-vs-app deploy race and the schema-additive-vs-schema-mutating split.
