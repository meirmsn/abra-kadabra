## Gate 1: docs-check

**Scope**: Does the diff (template keepalive.yml + bats test) make any existing doc stale or require a new doc entry?

### Docs checked

| Doc | Keepalive-relevant content | Stale after this diff? |
| --- | --- | --- |
| `kit/docs/guide/ops.md` line 398 | Parenthetical: `PRODUCTION_URL` "(used by `keepalive.yml`)" — format divergence note | No — still accurate; the existing Vercel ping step still uses `vars.PRODUCTION_URL` |
| `kit/docs/guide/ops.md` lines 118-126 | GH Variables table — `SUPABASE_URL` = `http://127.0.0.1:54321`, `SUPABASE_ANON_KEY` = local-stack JWT | No — table correctly describes what the GH Variables hold. See implementation concern below. |
| `kit/docs/guide/security.md` line 91 | CI Credential Isolation — `SUPABASE_URL` GH Variable = local-stack | No — still accurate |
| `CLAUDE.md` | No keepalive-specific content | N/A |
| `kit/docs/guide/conventions.md` | No keepalive-specific content | N/A |
| `kit/docs/OVERVIEW.md` | No keepalive-specific content | N/A |

### Finding: implementation-level variable mismatch (not a docs defect)

The keepalive workflow's new Supabase ping step uses `vars.SUPABASE_URL` and `vars.SUPABASE_ANON_KEY`. Per the documented GH Variable layout (`ops.md` table, `security.md` line 91, `/ak-new-project` SKILL.md lines 562-564), these variables hold **local-stack** values (`http://127.0.0.1:54321` + default JWT) — not the prod Supabase URL. The keepalive workflow runs on a bare `ubuntu-latest` runner with no local Supabase stack, so the curl would hit `127.0.0.1:54321` (connection refused), emit a `::warning::`, and **not actually prevent Supabase auto-pause**.

The workflow should reference `vars.SUPABASE_PROD_URL` (which holds the prod URL per `/ak-new-project` SKILL.md line 573) or introduce a dedicated variable. This is an implementation concern to surface to the operator, not a docs staleness finding — the docs are correct about what the variables hold.

### New doc entry needed?

No. The keepalive workflow is a simple CI workflow whose behavior is self-documenting in the YAML file. No existing guide section describes keepalive behavior in prose that would need updating. The TODOS entry (`kit/TODOS.md` lines 10-19) captures rationale and will be closed in Phase 4.0.

### Verdict

**pass** — no existing docs are stale; no new doc entry required. The variable mismatch is an implementation concern (surfaced above for the operator) rather than a documentation gap.

## Dismissals

None
