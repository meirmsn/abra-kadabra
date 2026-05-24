## Gate 11: convention

**Outcome: pass**

Checked 2026-05-24. Devshop-mode convention check for `keepalive-supabase-ping`.

### Checks performed

1. **Bats test file exists and passes** -- `kit/tests/template-keepalive-yml-shape.bats` present with 9 assertions, all pass (verified via vendored bats runner).
2. **Bats test follows repo patterns** -- shebang `#!/usr/bin/env bats`, `load helpers/setup`, `DEVSHOP="$(git rev-parse --show-toplevel)"` setup, pure file-content checks (no runner needed). Matches `template-ci-yml-shape.bats` reference.
3. **Conventional commits** -- all 5 commits on branch use conventional-commit format (`feat`, `fix`, `chore` prefixes with scopes). All subjects <= 72 chars. All carry `Co-Authored-By:` trailer.
4. **Spec structure** -- `specs/keepalive-supabase-ping/spec.md` has all required sections: `## Product update` (Headline + Detail), `## Decisions`, `## In scope`, `## Out of scope`, `## Tests`, `## Gotchas`, `## Task order`.
5. **TODOS entry updated** -- `kit/TODOS.md` entry for "Keepalive workflow pings Vercel but not Supabase" updated with correct `SUPABASE_PROD_URL` + `SUPABASE_PROD_ANON_KEY` variable names.
6. **Existing projects block** -- present in the feat commit body (`46689b9`), names `home-os` and `lalista` as affected scaffold-once projects. Notes stale variable names (`SUPABASE_URL`/`SUPABASE_ANON_KEY` instead of the corrected `SUPABASE_PROD_*`) in the intermediate commit, but this is a squash-merge branch -- the squash body will be composed fresh by `/ak-merge-devshop` Phase 0.3 with the corrected names.
7. **PLAN.md entry** -- `keepalive-supabase-ping` in Planned table with Lev scoring (16.0), Source pointer to `kit/TODOS.md`, all columns filled.
8. **No `.ts`/`.tsx` files** -- 3-line header convention not applicable (YAML + bats only).
9. **No metrics needed** -- CI workflow template change, not a user-facing feature.

## Dismissals

None
