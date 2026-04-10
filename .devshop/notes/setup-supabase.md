# Supabase Setup

## Environment strategy

**For early-stage / solo dev: one remote project is fine.**

The tradeoff ladder:

| Setup                             | When to add it                                                                                     |
| --------------------------------- | -------------------------------------------------------------------------------------------------- |
| Single remote project             | Starting out — simple, low overhead                                                                |
| Local emulator (`supabase start`) | Once you're iterating on schema frequently — fast resets, no internet needed, no risk to prod data |
| Staging remote project            | Once you have real users who'd be hurt by a bad migration or downtime                              |

For lalista right now: single remote is correct. Add local emulator when schema work picks up.

What you have now (single remote):

- Simple — one place to check, no sync issues
- Works great for solo dev or small team in early stage
- Caveat: you're testing against prod data and any schema mistake affects real users

When people add more environments:

- Local emulator (supabase start) — lets you iterate on schema/migrations fast without internet, run migrations and reset freely, no risk to prod data. Good to add once you're
  doing active schema work
- Staging remote project — separate Supabase project you push to before prod. Worth adding when you have real users and can't afford to break them with a bad migration

Practical recommendation for lalista right now:

- Keep the single remote for now — it's fine
- Add a local emulator once you start iterating on the schema a lot (it's just supabase init + supabase start)
- Staging can wait until you have users who'd be hurt by downtime

---

## Auth vs. your tables

Supabase Auth is a completely separate service from your `public` schema tables.

- **`auth.users`** — built-in, Supabase-managed, exists automatically in every project. Sign up/login works with zero migrations.
- **`public.*`** (stores, households, list_entries, etc.) — your tables, created only when migrations are applied.

This is why you can create an account and log in before running any migrations, but anything that touches your app data (Settings, adding items, etc.) will fail until you push them.

---

## Applying migrations

The migration SQL lives in `supabase/migrations/` but must be explicitly applied to the actual database — it doesn't happen automatically. The error "Could not find the table 'public.X' in the schema cache" means PostgREST doesn't know the table exists, i.e. migrations haven't been run.

### One-time CLI setup (do this once per dev machine / container)

```bash
supabase init                            # creates supabase/config.toml
# supabase login                           # browser OAuth to supabase.com
supabase link --project-ref <ref>        # find ref in Dashboard → Settings → General
```

### About `supabase login`

Instead of running `supabase login` (which requires a browser OAuth flow and is lost on every container rebuild), use a **Personal Access Token**:

1. Generate one at Supabase Dashboard → Account → Access Tokens
2. Add `SUPABASE_ACCESS_TOKEN=sbp_xxxx` to `.devcontainer/.env`

The CLI picks it up automatically — no `supabase login` ever needed. The token persists across rebuilds because `.devcontainer/.env` is a file on your Mac (bind mount), not inside the container.

If you do use `supabase login` instead: it prints a URL + one-time code to the terminal (no browser needed inside the container — open the URL on your Mac). Token saves to `~/.config/supabase/access-token`, which is lost on rebuild.

### Push migrations

```bash
supabase db push
```

Runs all files in `supabase/migrations/` in order against the linked remote project.

### Push functions

```bash
supabase functions deploy
supabase functions deploy add-item
supabase functions deploy add-item --no-verify-jwt (see TODO redeploy-add-item-without-no-verify-jwt)
```

### Alternative: Supabase Dashboard SQL editor

If CLI isn't available, paste and run each migration file manually in Dashboard → SQL Editor (in order: 001, 002, 003).

---

## Supabase CLI in the dev container

The CLI is installed as a system binary in the Dockerfile (same pattern as `git-delta`). Version is pinned via a build ARG.

To update the version:

1. Check latest at https://github.com/supabase/cli/releases
2. Update `SUPABASE_CLI_VERSION` in `.devcontainer/devcontainer.json`
3. Rebuild the container

### Firewall

The dev container firewall allowlists by IP. Two Supabase endpoints need to be reachable:

| Endpoint                                   | Used by                           | How it's allowed                   |
| ------------------------------------------ | --------------------------------- | ---------------------------------- |
| `api.supabase.com`                         | `supabase login`, `supabase link` | Static entry in `init-firewall.sh` |
| `aws-0-us-west-2.pooler.supabase.com:5432` | `supabase db push` (via pooler)   | Static entry in `init-firewall.sh` |

### Check login status

```bash
supabase projects list   # lists your projects if logged in; errors if not
```

If you see "Access token not provided", run `supabase login` to re-authenticate.
