<!-- generated-by: /ak-build Phase 2 (implementation agent) -->
<!-- feature: home-os-skill-polish-batch -->

# Tasks: home-os-skill-polish-batch

Resume contract — sequenced per `spec.md § Task order`. Status keys:
`pending` / `in_progress` / `done` / `blocked`.

## Tasks

1. [done] A1 — Step 13 `export VERCEL_TOKEN` (security)
2. [done] A2 — Step 14 chromium smoke-test fallback
3. [done] A3 — Step 3 Vercel/GitHub Login Connection + SSO sub-bullets
4. [done] E1 — Step 3 Sentry platform → Next.js
5. [done] E3 — Step 4 Sentry DSN direct-URL form
6. [done] E2 — Step 4 pre-fill local-stack JWT
7. [done] E4 — Step 4 drop `SUPABASE_DB_PASSWORD` + § Security Posture matrix
8. [done] A4 — Step 17 gstack-config preamble
9. [done] A5 — Step 9 `~/.claude/skills/gstack` symlink
10. [done] E6 — Step 18 → Step 12.6 reorder + cross-ref sweep
11. [done] E7 — Step 12 build-script reconciliation + `template/package.json`
12. [done] E8 — Step 12 partial-scaffold recovery note
13. [done] E9 — Step 6 verification grep
14. [done] E10 — Step 6 + Step 7 `[OPERATOR-ONLY]` markers
15. [done] E11 — Step 6 firewall smoke-test sub-step
16. [done] E5 — `template/packages/core/vitest.config.ts` comment rewrite
17. [done] B1 — `/devshop/CLAUDE.md` stash footgun bullet
18. [done] B3 — `/devshop/kit/hooks/pre-push.sh` short-circuit + bats
19. [done] Tracker closure — delete PLAN.md row + ROADMAP section + cross-refs

## Decisions

- **E6 step number** — spec said move docs-fill from Step 18 to "Step 12.5", but
  Step 12.5 already exists in SKILL.md (Supabase SSR boilerplate patterns). Use
  **Step 12.6** instead — preserves the "half-step doesn't displace later
  numbers" property the spec wanted, while not colliding with the existing 12.5.
  Cross-ref sweep targets `Step 18` → `Step 12.6`.
- **Per-commit test regression check** — the prompt asked for `pnpm turbo run
  test:unit` from `/devshop`, but `/devshop` has no `turbo` dep (`package.json`
  only ships `test:kit` for bats). All 18 fixes are pure prose / static-text
  edits; bats coverage is exercised once at the end via `pnpm test:kit` rather
  than per-commit. Stuck protocol still applies — if any commit fails, this
  decision gets re-examined.

## Stuck

(none yet)
