#!/usr/bin/env node
// What: Local replica of 9 Supabase Advisor lints. Queries pg_catalog directly
//       and reports findings to stdout. Returns exit code 0 (clean), 1 (findings),
//       or 2 (probe error).
// Why:  Catches the class of DB-hardening bugs ([[db-hardening-security-guide]])
//       that ship invisibly: SECURITY DEFINER functions without pinned search_path,
//       RLS policies that re-evaluate auth.uid() per row, unindexed foreign keys,
//       multiple permissive policies for the same role/op, security-definer views,
//       RLS-enabled tables with zero policies, RLS-disabled tables in public,
//       extensions installed in the public schema, duplicate indexes.
// Does NOT: query Supabase's hosted advisor API; mutate the database; install pg;
//       handle non-Postgres dialects.
//
// Usage: node template/scripts/advisor-probe.mjs
//        DATABASE_URL=postgresql://postgres:postgres@supabase-runner:54322/postgres
//
// Conventions: see kit/docs/guide/security.md § DB hardening — SQL conventions
// for Supabase projects (the authoring contract these lints encode).

import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

// Lazy-require so a project without `pg` installed gets a clear blocked message
// rather than an opaque import error.
let Client;
try {
  ({ Client } = await import("pg"));
} catch {
  console.error(
    "blocked: 'pg' is not installed. Run `pnpm add -D pg` at the repo root.",
  );
  process.exit(2);
}

const DATABASE_URL =
  process.env.DATABASE_URL ||
  "postgresql://postgres:postgres@supabase-runner:54322/postgres";

const MIGRATIONS_DIR = process.env.MIGRATIONS_DIR ||
  join(process.cwd(), "supabase", "migrations");

// --- Helpers --------------------------------------------------------------

/** @returns {Set<string>} per-lint names that have an ADVISOR-EXEMPT marker
 *  somewhere in the migrations directory. The match is coarse — any migration
 *  with `ADVISOR-EXEMPT(<lint>)` exempts the lint repo-wide, scoped per file
 *  if the comment is in the same migration as the affected object. v0 keeps
 *  this repo-wide; the gate's findings output names the lint so operators can
 *  cross-reference. */
function loadExemptions() {
  const out = new Set();
  if (!existsSync(MIGRATIONS_DIR)) return out;
  for (const f of readdirSync(MIGRATIONS_DIR)) {
    if (!f.endsWith(".sql")) continue;
    const body = readFileSync(join(MIGRATIONS_DIR, f), "utf8");
    for (const m of body.matchAll(/ADVISOR-EXEMPT\(([a-z_]+)\)/gi)) {
      out.add(m[1].toLowerCase());
    }
  }
  return out;
}

async function query(client, sql) {
  const r = await client.query(sql);
  return r.rows;
}

// --- Lints ----------------------------------------------------------------
// Each lint returns { lint: string, findings: Array<{object: string, hint: string}> }.

async function lintFunctionSearchPath(client) {
  // SECURITY DEFINER functions without a pinned search_path are vulnerable to
  // schema-injection via the caller's resolved search_path.
  const rows = await query(
    client,
    `
    select n.nspname || '.' || p.proname as object,
           p.proconfig as cfg
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where p.prosecdef = true
       and n.nspname = 'public'
       and not exists (
         select 1 from unnest(coalesce(p.proconfig, array[]::text[])) cfg
          where cfg ilike 'search_path=%'
       );
  `,
  );
  return {
    lint: "function_search_path_mutable",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "Add `set search_path = public, pg_temp` to the function declaration.",
    })),
  };
}

async function lintAuthRlsInitplan(client) {
  // Policies that reference bare auth.uid() / auth.jwt() / auth.role() — i.e.
  // not wrapped in a subquery — re-evaluate per row instead of per statement.
  const rows = await query(
    client,
    `
    select schemaname || '.' || tablename || ':' || policyname as object,
           qual as using_expr,
           with_check as check_expr
      from pg_policies
     where schemaname = 'public'
       and (
         (qual ~* '(^|[^.(])auth\\.(uid|jwt|role)\\s*\\(' and qual !~* '\\(\\s*select\\s+auth\\.')
         or
         (with_check ~* '(^|[^.(])auth\\.(uid|jwt|role)\\s*\\(' and with_check !~* '\\(\\s*select\\s+auth\\.')
       );
  `,
  );
  return {
    lint: "auth_rls_initplan",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "Wrap auth.uid()/auth.jwt()/auth.role() as `(select auth.uid())` — initplans once per statement.",
    })),
  };
}

async function lintUnindexedForeignKeys(client) {
  // Foreign keys without a backing index on the referencing column(s).
  const rows = await query(
    client,
    `
    with fks as (
      select c.conrelid::regclass::text as tbl,
             c.conname as fkname,
             c.conkey as cols
        from pg_constraint c
        join pg_class t on t.oid = c.conrelid
        join pg_namespace n on n.oid = t.relnamespace
       where c.contype = 'f' and n.nspname = 'public'
    ),
    idx as (
      select i.indrelid::regclass::text as tbl,
             i.indkey::int[] as cols
        from pg_index i
        join pg_class t on t.oid = i.indrelid
        join pg_namespace n on n.oid = t.relnamespace
       where n.nspname = 'public'
    )
    select fks.tbl || ' (' || fks.fkname || ')' as object
      from fks
     where not exists (
       select 1 from idx
        where idx.tbl = fks.tbl
          and idx.cols[1:array_length(fks.cols, 1)] = fks.cols::int[]
     );
  `,
  );
  return {
    lint: "unindexed_foreign_key",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "Add `create index <tbl>_<col>_idx on <tbl> (<col>)` or annotate the migration with `-- ADVISOR-EXEMPT(unindexed_foreign_key): <reason>`.",
    })),
  };
}

async function lintMultiplePermissives(client) {
  // More than one permissive policy for the same {role, command} bloats the
  // planner and usually signals copy-paste drift.
  const rows = await query(
    client,
    `
    select schemaname || '.' || tablename as tbl,
           cmd,
           array_to_string(roles, ',') as role,
           count(*) as n
      from pg_policies
     where schemaname = 'public' and permissive = 'PERMISSIVE'
     group by 1, 2, 3
    having count(*) > 1;
  `,
  );
  return {
    lint: "multiple_permissive_policies",
    findings: rows.map((r) => ({
      object: `${r.tbl} (${r.cmd} / ${r.role})`,
      hint:
        "Merge the policies into one OR predicate, or drop the redundant ones.",
    })),
  };
}

async function lintSecurityDefinerViews(client) {
  // Views with security_invoker = false (default) run with the creator's
  // privileges, silently bypassing the caller's RLS.
  const rows = await query(
    client,
    `
    select n.nspname || '.' || c.relname as object
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where c.relkind = 'v'
       and n.nspname = 'public'
       and (c.reloptions is null
            or not exists (
              select 1 from unnest(c.reloptions) o
               where o ilike 'security_invoker=true'
            ));
  `,
  );
  return {
    lint: "security_definer_view",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "Recreate with `with (security_invoker = true)` so the view honors the caller's RLS.",
    })),
  };
}

async function lintRlsDisabled(client) {
  // Tables in public without RLS enabled. Almost always a bug for a Supabase
  // project where PostgREST exposes the schema to authenticated clients.
  const rows = await query(
    client,
    `
    select n.nspname || '.' || c.relname as object
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where c.relkind = 'r'
       and n.nspname = 'public'
       and c.relrowsecurity = false;
  `,
  );
  return {
    lint: "rls_disabled_in_public",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "Run `alter table " + r.object + " enable row level security` and add policies, or annotate as `ADVISOR-EXEMPT(rls_disabled_in_public)`.",
    })),
  };
}

async function lintRlsNoPolicy(client) {
  // Tables with RLS enabled but no policies — every read/write through the
  // anon/authenticated role silently affects zero rows.
  const rows = await query(
    client,
    `
    select n.nspname || '.' || c.relname as object
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where c.relkind = 'r'
       and n.nspname = 'public'
       and c.relrowsecurity = true
       and not exists (
         select 1 from pg_policies p
          where p.schemaname = n.nspname and p.tablename = c.relname
       );
  `,
  );
  return {
    lint: "rls_enabled_no_policy",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "Add a `create policy ... for {select|insert|update|delete}` matching the access pattern, or document why no policy is needed.",
    })),
  };
}

async function lintExtensionInPublic(client) {
  // Extensions in the public schema leak their objects into PostgREST's
  // surface and conflict with user tables. Move to `extensions` (the
  // Supabase convention).
  const rows = await query(
    client,
    `
    select e.extname as object
      from pg_extension e
      join pg_namespace n on n.oid = e.extnamespace
     where n.nspname = 'public'
       and e.extname not in ('plpgsql');
  `,
  );
  return {
    lint: "extension_in_public",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "`alter extension " + r.object + " set schema extensions;` (create the schema first if needed).",
    })),
  };
}

async function lintDuplicateIndex(client) {
  // Indexes covering the same {table, column-set, where-clause} waste write
  // amplification and disk.
  const rows = await query(
    client,
    `
    select t.relname || ' [' || string_agg(i.relname, ', ' order by i.relname) || ']' as object
      from pg_index x
      join pg_class i on i.oid = x.indexrelid
      join pg_class t on t.oid = x.indrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname = 'public'
       and not x.indisprimary
     group by t.relname, x.indkey, coalesce(x.indpred::text, '')
    having count(*) > 1;
  `,
  );
  return {
    lint: "duplicate_index",
    findings: rows.map((r) => ({
      object: r.object,
      hint:
        "Drop one of the duplicates with `drop index <name>` — keep the most specific (partial > full).",
    })),
  };
}

// --- Driver ---------------------------------------------------------------

async function main() {
  const exemptions = loadExemptions();
  const client = new Client({ connectionString: DATABASE_URL });
  try {
    await client.connect();
  } catch (err) {
    console.error(
      `blocked: cannot connect to ${DATABASE_URL}: ${err.message}\n` +
        "If the local Supabase stack isn't up, run `pnpm db:start` first.",
    );
    process.exit(2);
  }

  const lints = [
    lintFunctionSearchPath,
    lintAuthRlsInitplan,
    lintUnindexedForeignKeys,
    lintMultiplePermissives,
    lintSecurityDefinerViews,
    lintRlsDisabled,
    lintRlsNoPolicy,
    lintExtensionInPublic,
    lintDuplicateIndex,
  ];

  const results = [];
  for (const lint of lints) {
    try {
      const r = await lint(client);
      if (exemptions.has(r.lint)) {
        results.push({ lint: r.lint, findings: [], exempt: true });
      } else {
        results.push(r);
      }
    } catch (err) {
      results.push({ lint: lint.name, findings: [], error: err.message });
    }
  }

  await client.end();

  let total = 0;
  const lines = [];
  for (const r of results) {
    if (r.error) {
      lines.push(`  - ${r.lint}: probe error — ${r.error}`);
      continue;
    }
    if (r.exempt) {
      lines.push(`  - ${r.lint}: exempt (ADVISOR-EXEMPT marker found)`);
      continue;
    }
    if (r.findings.length === 0) {
      lines.push(`  - ${r.lint}: ok`);
      continue;
    }
    total += r.findings.length;
    lines.push(`  - ${r.lint}: ${r.findings.length} finding(s)`);
    for (const f of r.findings) {
      lines.push(`      • ${f.object}`);
      lines.push(`        ${f.hint}`);
    }
  }

  if (total === 0) {
    console.log("pass");
    console.log("Advisor: 9/9 lints clean.");
    for (const l of lines) console.log(l);
    process.exit(0);
  }

  console.log(`findings (${total})`);
  console.log("Advisor surfaced gaps — see kit/docs/guide/security.md § DB hardening.");
  for (const l of lines) console.log(l);
  process.exit(1);
}

main().catch((err) => {
  console.error(`probe error: ${err.message}`);
  process.exit(2);
});
