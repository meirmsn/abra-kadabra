# Migrations

Schema-mutating changes to a Supabase project ride two boundaries: the migration files on disk, and the deploy workflow that pushes them. This guide collects the rules that apply across both — defaults applied at scaffold time, FK-cascade discipline, Realtime publication wiring, and the SSR + E2E patterns codified from production incidents.

## Contents

- [Supabase Hardening Defaults](#supabase-hardening-defaults)
  - [ON DELETE on `auth.users` FK references](#on-delete-on-authusers-fk-references)
  - [Realtime publication setup](#realtime-publication-setup)
  - [SSR + E2E boilerplate canonical patterns](#ssr--e2e-boilerplate-canonical-patterns)
- [Load-bearing SQL invariants and sentinel comments](#load-bearing-sql-invariants-and-sentinel-comments)
  - [Why `for update` matters here — Postgres EvaluatePlanQual (EPQ) semantics](#why-for-update-matters-here--postgres-evaluateplanqual-epq-semantics)
- [DB constraint as loud structural backstop for application-layer business rules](#db-constraint-as-loud-structural-backstop-for-application-layer-business-rules)
- [seed.sql gotrue compatibility — required text columns + matching auth.identities](#seedsql-gotrue-compatibility--required-text-columns--matching-authidentities)
- [Postgres enum extension — DROP+CREATE pattern (NOT `ALTER TYPE ADD VALUE`)](#postgres-enum-extension--dropcreate-pattern-not-alter-type-add-value)

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

## Load-bearing SQL invariants and sentinel comments

When a SQL block's correctness depends on a specific clause that's easy to remove during a "simplifying" cleanup (an explicit `for update`, a `where used_at is null`, a `select … into strict`, an `on conflict do nothing`), pair the clause with a sentinel comment AND a pure-file grep test that asserts both are present.

```sql
-- LOAD-BEARING(do-not-remove): FOR UPDATE — Postgres EPQ semantics back the single-use guarantee
update tokens set used_at = now()
  where id = (
    select id from tokens
      where token = p_token and used_at is null
      for update
  )
  returning id;
```

The grep test lives next to the migration's integration test and asserts the sentinel comment + the load-bearing clause both still appear in the migration file. The integration test validates the runtime semantic (concurrent-write race, FK enforcement under load); the pure-file test catches the upstream code-change risk where a reviewer or formatter strips the clause without re-running integration.

Sentinel format: `LOAD-BEARING(do-not-remove)` followed by `—` and a one-line explanation of why removing the clause silently breaks the invariant. The explanation is the part future-you reads when re-encountering the comment cold.

### Why `for update` matters here — Postgres EvaluatePlanQual (EPQ) semantics

Single-use-token guarantees under READ COMMITTED rely on EPQ. When T2 blocks on T1's row lock and T1 commits (setting `used_at = now()`), T2's EPQ re-applies the WHERE clause (including `used_at IS NULL`) to the now-updated row. The predicate fails, T2 returns zero rows, and the wrapper's `not found` branch fires — exactly the desired outcome.

Removing the `for update` would silently break this: T1 and T2 both see `used_at IS NULL` at SELECT time, both commit, and the token grants access twice. The pure-file grep test catches the textual removal; the integration test (two concurrent transactions racing the same token) catches the runtime regression if the test gets stripped too.

## DB constraint as loud structural backstop for application-layer business rules

When an application-layer rule ("a user can only be in one household") needs to hold even under concurrent two-tab races, the application check is necessary but not sufficient. Add a DB-level UNIQUE / CHECK / EXCLUDE constraint as the loud-over-silent structural backstop, and map its error code at the wrapper boundary back to the same typed error the application check raises.

```sql
-- application check fires the typed error in the common case (P0001 raise)
-- DB constraint catches the two-tab race
alter table household_members
  add constraint household_members_one_per_user_v0 unique (user_id);
```

```ts
// wrapper boundary maps both signals to the same typed error
if (err.code === 'P0001' && err.message.includes('already in a household')) {
  throw new AlreadyInHouseholdError();
}
if (
  err.code === '23505' &&
  err.message.includes('household_members_one_per_user_v0')
) {
  throw new AlreadyInHouseholdError();
}
```

Reserve the unique-violation errcode (`23505`) exclusively for the literal DB constraint signal — don't use it as a generic "already exists" check at the application layer. Mixing the two collapses the distinction the two-layer defense is built to preserve.

## seed.sql gotrue compatibility — required text columns + matching auth.identities

Recent gotrue versions (v2.188+) scan four `auth.users` text columns into Go `string` (not `*string` / `sql.NullString`):

- `email_change`
- `recovery_token`
- `confirmation_token`
- `email_change_token_new`

Any seed row that leaves these NULL trips a driver scan error on every read — `auth.admin.listUsers()` and `/auth/v1/token` both return 500 `Database error querying schema`. gotrue's own signup path inserts `''` for these; seed rows must match.

Additionally, gotrue's `listUsers` + token endpoints expect every user to have at least one row in `auth.identities` with `provider = 'email'` and `provider_id = user.id::text`. A user row without a paired identity row fails the same endpoints with the same shape.

Canonical seed row shape:

```sql
insert into auth.users (id, email, encrypted_password, email_confirmed_at,
  email_change, recovery_token, confirmation_token, email_change_token_new, ...)
values (
  '...', 'alice@example.com', crypt('password', gen_salt('bf')), now(),
  '', '', '', '', ...
);

insert into auth.identities (id, user_id, provider, provider_id, identity_data, last_sign_in_at)
values (
  gen_random_uuid(), '<user_id>', 'email', '<user_id>',
  jsonb_build_object('sub', '<user_id>', 'email', 'alice@example.com'),
  now()
);
```

Verify after any seed change with `pnpm db:reset && curl <auth-url>/auth/v1/admin/users -H 'Authorization: Bearer <service-role>'` — must return a JSON users array, not 500. The constraint is enforced at runtime by the auth server, not by Postgres — the only forcing function is the smoke check.

## Postgres enum extension — DROP+CREATE pattern (NOT `ALTER TYPE ADD VALUE`)

**Don't use `alter type <enum> add value <new>` in a Supabase migration.** The statement is rejected by Postgres when executed inside a transaction block, and **the Supabase migration applier wraps each `.sql` file in an implicit transaction during `supabase start` / `supabase db reset` / `supabase migration up`**. The failure is silent — the `Applying migration X` log line emits regardless, and `supabase gen types --local` reflects whatever the apply step _intended_ (so the schema-type-drift gate still passes) — but `pg_enum` doesn't actually contain the new value. The first runtime `INSERT` with the new value fails with:

```
22P02 invalid input value for enum <type>: "<new-value>"
```

…with no breadcrumb back to the migration that should have added it.

Home-os hit this on PR #15 during slow-job rollout. The author had isolated the `ADD VALUE` into its own file 006a, assuming the per-file transaction wrapping was the gotcha. It wasn't — even alone in a file, the applier wraps in a transaction.

### Canonical pattern: rename → recreate → recast → drop

```sql
-- Migration NNN — extend <enum> with the '<new>' value.
--
-- `ALTER TYPE ... ADD VALUE` cannot run in a transaction (Postgres
-- restriction), and the Supabase migration applier wraps each .sql file
-- in an implicit transaction. Use the standard rename + recreate +
-- recast workaround — every statement is transaction-safe and the column
-- data round-trips cleanly because the new type is a superset of the
-- old in matching order.

alter type public.<enum> rename to <enum>_old;

create type public.<enum> as enum (
  -- Original values from the prior enum definition, IN ORDER.
  '<existing-1>',
  '<existing-2>',
  -- New value(s):
  '<new>'
);

-- ALTER COLUMN TYPE rejects columns with a DEFAULT that references the
-- old type — drop the default, recast, then restore the default against
-- the new type. Repeat per (table, column) using the enum.
alter table public.<table> alter column <col> drop default;
alter table public.<table>
  alter column <col> type public.<enum>
  using <col>::text::public.<enum>;
alter table public.<table>
  alter column <col> set default '<original-default>'::public.<enum>;

drop type public.<enum>_old;

-- ROLLBACK:
-- alter type public.<enum> rename to <enum>_new;
-- create type public.<enum> as enum (
--   '<existing-1>', '<existing-2>'   -- without the new value
-- );
-- alter table public.<table> alter column <col> drop default;
-- alter table public.<table>
--   alter column <col> type public.<enum>
--   using <col>::text::public.<enum>;
-- alter table public.<table> alter column <col> set default '<original-default>'::public.<enum>;
-- drop type public.<enum>_new;
```

### Pre-merge verification (do not skip)

The CI schema-type-drift gate is **not** a forcing function here — it can pass on a stale enum because `gen types --local` reflects intent rather than `pg_enum` truth in some CLI versions. The forcing function is an actual `INSERT` of the new value in the slow-job E2E. **Add the new-value insert assertion to the same PR** that adds the migration so the failure surfaces immediately rather than waiting for downstream code to trigger it.

### Dependencies — function-resolution timing

PL/pgSQL is lazy-compiled. Functions that reference the enum by literal value (`'<existing-1>'::public.<enum>` in a function body) re-bind at first call after the recreate — they work without redefinition. Functions that reference the enum by name as a parameter type (`function_name(p public.<enum>)`) MAY need redefinition; check by listing dependent functions via `pg_depend` before running the recreate in a prod-shaped DB.

### Why not just edit the original `create type` migration?

If the project is pre-launch and the original `create type` migration hasn't been deployed to any environment that retains state (no prod, no preview branches with persistent DBs), editing the original migration to include the new value is simpler — there's no need for a recreate dance. The DROP+CREATE pattern is for the common case where the original migration has already been applied somewhere and can't be retroactively changed.
