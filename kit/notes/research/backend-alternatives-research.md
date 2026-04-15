# Backend Alternatives Research

> **Key reference**: [Deploy Supabase on Hetzner with Coolify](https://community.hetzner.com/tutorials/coolify-supabase-deploy)

Research conducted 2026-04-05. Context: evaluating whether Supabase is the right default backend for the devshop repo, and what alternatives exist for cost-conscious solo devs building multiple projects.

---

## Current Stack: Supabase (Hosted)

lalista uses Supabase with: PostgreSQL (7 migrations, RLS policies), Auth (Sign in with Apple), Edge Functions (Deno — NLP via Claude), Realtime channels, generated TypeScript types.

### Free Tier Limitations

- No custom domain (Pro-only)
- No database branching / PR previews (Pro-only, $25/mo)
- No point-in-time recovery
- Additional projects: free on free tier, $10/mo each on Pro
- 500 MB database, 1 GB file storage, 50k MAU auth

### Pro Tier ($25/mo per project)

- Database branching (per-PR preview databases)
- Custom domain
- 8 GB database, 100 GB file storage
- Daily backups, PITR (7 days)
- Each additional project: $10/mo

---

## Alternative 1: Neon + Auth.js + Vercel Functions

**The most interesting alternative for new projects.**

Neon is serverless Postgres with database branching as a core feature — available on the free tier. This solves the staging/preview problem that Supabase charges $25/mo for.

| Component                   | Replaces                | Cost                                      |
| --------------------------- | ----------------------- | ----------------------------------------- |
| Neon (serverless Postgres)  | Supabase DB             | Free (0.5 GB storage, branching included) |
| Auth.js (Next.js)           | Supabase Auth           | Free (self-managed)                       |
| Vercel serverless functions | Supabase Edge Functions | Free tier                                 |
| Ably or SSE                 | Supabase Realtime       | Ably free: 1M messages/mo                 |
| Drizzle ORM or Prisma       | `supabase gen types`    | Free                                      |

**Pros:**

- Free database branching — per-PR preview databases at $0
- Postgres-compatible — existing SQL knowledge transfers
- No vendor lock-in on any individual piece
- Vercel functions are natural since you're already on Vercel
- Drizzle/Prisma have excellent TypeScript type generation

**Cons:**

- 3-4 services to assemble vs Supabase's all-in-one
- Auth.js requires more setup than Supabase Auth (you configure providers, callbacks, session management)
- Realtime requires a separate service (Ably, Pusher, or custom SSE)
- No equivalent of Supabase's auto-generated REST API (PostgREST) — you write API routes yourself
- More integration surface = more things to break

**Best for:** New projects where staging/branching matters and you don't need realtime out of the box.

---

## Alternative 2: AWS Amplify Gen 2

**Not recommended for this use case.**

Amplify Gen 2 is TypeScript-first and has good sandbox/preview environments, but:

- Default database is DynamoDB (NoSQL) — Postgres is "bring your own" (Aurora/RDS/Neon)
- GraphQL is mandatory for the data layer — no REST option
- Total vendor lock-in (DynamoDB + AppSync + Cognito + Lambda)
- Cost is unpredictable — pay-per-use across 6+ AWS services
- Orphaned resources from preview environments hit AWS account quotas
- Local dev requires cloud sandbox (deploys to AWS per change), not instant local stack
- Known pain point: Next.js SSR build size limit of 220 MB

**Cost:** Likely $0-5/month within free tiers for small project, but AWS billing is inherently unpredictable. Some free tiers expire after 12 months.

**Best for:** Teams already deep in AWS ecosystem or needing enterprise features (SAML, AppSync offline sync).

---

## Alternative 3: PocketBase (Self-Hosted)

Single Go binary with SQLite, auth, realtime, and REST API. Deploy on a $3-5/mo VPS.

**Pros:**

- Dead simple — one binary, one file database
- Very cheap ($3-5/mo VPS)
- Built-in auth, realtime, REST API
- Admin dashboard included
- Active development, growing community

**Cons:**

- SQLite, not Postgres — existing SQL migrations don't port
- No RLS equivalent (uses collection-level rules instead)
- No edge functions — server-side logic is Go extensions or JavaScript hooks
- Limited ecosystem compared to Supabase/Postgres
- Questionable for multi-user concurrent write patterns
- You maintain the server

**Best for:** Simple CRUD apps, prototypes, or projects where you want maximum simplicity and minimal cost.

---

## Alternative 4: Firebase

**Pros:** Generous free tier, realtime built-in, auth built-in, Google scale.

**Cons:**

- NoSQL (Firestore) — completely different data model, SQL migrations useless
- Vendor lock-in worse than Supabase
- No database branching equivalent
- Pricing can spike unpredictably at scale

**Best for:** Mobile-first apps that need offline sync (Firestore's strength), or if you're already in the Google Cloud ecosystem.

---

## Alternative 5: Convex

Reactive backend-as-a-service. Different paradigm — not traditional REST/SQL.

**Pros:**

- Built-in realtime (reactive by default)
- Built-in preview deployments
- TypeScript-native
- Free tier generous

**Cons:**

- Completely different data model (not SQL, not document — reactive functions)
- Young ecosystem
- Total vendor lock-in
- Not Postgres — can't reuse SQL knowledge or migrations

**Best for:** Apps where reactivity is the core feature and you're OK with a new paradigm.

---

## Self-Hosting Supabase

### Architecture

Full stack is **12 Docker containers** (~4 GB RAM idle):

| Service            | Idle RAM    | Role                         |
| ------------------ | ----------- | ---------------------------- |
| PostgreSQL         | ~350 MB     | Core database                |
| Kong (API gateway) | ~2.5 GB (!) | Routes all external requests |
| PostgREST          | ~116 MB     | Auto-generated REST API      |
| GoTrue (auth)      | ~9 MB       | Authentication               |
| Realtime           | ~211 MB     | WebSocket broadcasts         |
| Storage            | ~40 MB      | File management              |
| Studio (dashboard) | ~72 MB      | Admin UI                     |
| postgres-meta      | ~59 MB      | DB management API for Studio |
| Analytics/Logflare | ~525 MB     | Log analytics                |
| Vector             | ~40 MB      | Log pipeline                 |
| imgproxy           | small       | Image transformations        |
| Edge Runtime       | ~21 MB      | Deno-based functions         |

Kong at 2.5 GB idle is the biggest offender — multiple community reports suggest memory leak.

### Minimal Stack

Strip to essentials: PostgreSQL + PostgREST + GoTrue + Kong. Remove Studio, Analytics, Vector, imgproxy, Edge Runtime, Realtime, Storage, postgres-meta. Gets down to ~1-2 GB RAM idle.

### Hosting Costs

| Provider          | Spec                       | Monthly Cost | Notes                                |
| ----------------- | -------------------------- | ------------ | ------------------------------------ |
| **Hetzner CPX21** | 3 vCPU, 4 GB RAM           | ~€8/mo       | Tight for full stack, OK for minimal |
| **Hetzner CPX31** | 4 vCPU, 8 GB RAM           | ~€15/mo      | Comfortable for full stack           |
| **Hetzner CCX13** | 2 dedicated vCPU, 8 GB RAM | ~€20/mo      | Better for sustained load            |
| **DigitalOcean**  | 4 vCPU, 8 GB RAM           | ~$48/mo      | More expensive than Hetzner          |
| **Railway**       | Usage-based                | ~$30-60/mo   | Convenient but pricier               |

### Managed Options

- **[Coolify](https://coolify.io/docs/services/supabase)**: Free, open-source PaaS with first-class Supabase support. Handles Docker orchestration, SSL via Caddy, basic monitoring. Best "easy button" — see [Hetzner tutorial](https://community.hetzner.com/tutorials/coolify-supabase-deploy).
- **[Elestio](https://elest.io/open-source/supabase)**: Fully managed self-hosted Supabase starting at $14/mo.
- **[SupaScale](https://www.supascale.app)**: Upgrade management tool for self-hosted Supabase.

### What You Gain

- No per-project costs — run multiple projects on one server
- More resources than the $25/mo Pro plan
- Full control over data and infrastructure

### What You Lose (Cloud-Only Features)

- Database branching (no PR preview databases)
- Automated backups / PITR (DIY pg_dump)
- Full dashboard features (email templates, OAuth config done via env vars)
- Auto-upgrades
- Auto-scaling

### What You Take On

- TLS termination (Caddy/Nginx reverse proxy)
- Backup cron jobs (pg_dump)
- Security patching and secret rotation
- Manual upgrades every few months
- Server monitoring
- Network security (only expose Kong publicly)

### Biggest Pain Points (Community Reports)

1. **Database migrations don't auto-apply on upgrade.** Postgres Docker image only runs init scripts on first boot. New migrations in updated images silently don't apply to existing deployments. #1 complaint.
2. **No upgrade changelog or compatibility matrix.** You reverse-engineer which service versions work together from the docker-compose.yml in the repo.
3. **Kong memory usage.** ~2.5 GB idle with suspected memory leaks.
4. **Analytics/Logflare is problematic.** Resource-hungry, often fails to start. Most self-hosters disable it.
5. **External Postgres is painful.** Using RDS or Cloud SQL instead of the bundled Postgres takes weeks of customizing migration files and role grants.
6. **Email templates require container rebuilds.** No dashboard editor in self-hosted.
7. **Studio has limited functionality** compared to cloud dashboard.

**Quote from 3-year self-hoster:** _"Very much feels like a bunch of stuff hacked together with no cohesion."_

### Multiple Projects on One Instance

Not designed for it. Options:

- Separate Docker Compose stacks on different ports (multiplies resources — 12 containers per project)
- Schema-based separation within one Postgres (works for personal projects, not secure isolation)
- Coolify can manage multiple Supabase stacks on one server

On a 16 GB Hetzner box (~€30/mo), you could run 2-3 stripped-down stacks.

### CLI with Self-Hosted

Works via `--db-url` flag:

```bash
supabase db push --db-url postgres://postgres:PASSWORD@your-server:5432/postgres
supabase gen types typescript --db-url postgres://postgres:PASSWORD@your-server:5432/postgres --schema public
```

What doesn't work well: anything assuming Supabase Cloud APIs (project management, branching, some `functions deploy` workflows).

---

## Cost Comparison Summary

Monthly cost for a typical personal project (<100 users):

| Stack                          | Cost               | Staging Story          | Complexity            |
| ------------------------------ | ------------------ | ---------------------- | --------------------- |
| Supabase free                  | $0                 | Local only             | Low                   |
| Supabase Pro                   | $25                | Branching (per-PR)     | Low                   |
| Neon + Auth.js + Vercel        | $0                 | Free branching         | Medium                |
| Self-hosted Supabase (Hetzner) | €15                | Deploy second instance | High                  |
| Self-hosted via Coolify        | €15 + Coolify free | Deploy second instance | Medium                |
| Self-hosted via Elestio        | $14+               | Deploy second instance | Low-Medium            |
| PocketBase on Fly.io           | $0-3               | Deploy second instance | Low                   |
| AWS (RDS + Cognito + Lambda)   | $0-15              | Separate environments  | High                  |
| Firebase                       | $0                 | N/A                    | Medium                |
| Convex                         | $0                 | Built-in previews      | Medium (new paradigm) |

---

## Recommendation

**For lalista (existing project):** Stay on Supabase free tier. Migration cost to any alternative is too high — 7 migrations, RLS policies, edge functions, auth, realtime all built on Supabase.

**For the devshop repo (future projects):**

- Default to Supabase (lowest complexity, all-in-one)
- Document Neon + Auth.js as the recommended alternative for projects needing free database branching
- Self-host Supabase via Coolify + Hetzner when running 3+ projects and per-project costs become the concern
- Keep devshop backend-agnostic in structure so switching is possible

**When to self-host:** When monthly Supabase bills exceed ~€15/mo (i.e., you have 2+ projects on Pro, or one project outgrows free tier limits). At that point, one Hetzner box replaces multiple paid projects.
